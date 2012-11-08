#!/usr/bin/perl

use strict;
use utf8;
use File::Basename qw(basename);
use File::Temp qw(tempfile);
use Getopt::Long;
use HTML::Entities ();
#use Imager;

sub usage (;$);

my $output_dir;
my $force;
my @ignore;
my @keep;
my @nopngheuristic; # This is somewhat ugly, it is doing two things: turning on png transparency heuristics and defining examples where the heuristics shouldn't be applied
my $title;
my $encoding = 'utf-8';
GetOptions("o=s"       => \$output_dir,
	   "f"         => \$force,
	   'ignore=s@' => sub { push @ignore, split /,/, $_[1] },
	   'keep=s@'   => sub { push @keep,   split /,/, $_[1] },
	   'nopngheuristic=s@' => sub { push @nopngheuristic, split /,/, $_[1] },
	   'encoding=s' => \$encoding,
	   'title=s'   => \$title,
	  )
    or usage;
$output_dir or usage "-o is mandatory";

my %ignore;
my %keep;
my %nopngheuristic;
for my $def ([\%ignore, \@ignore],
	     [\%keep, \@keep],
	     [\%nopngheuristic, \@nopngheuristic],
	    ) {
    %{$def->[0]} = map {
	my $type = $_;
	if ($type !~ m{^(polygon|line|point)/0x}) { die "Arguments to -ignore/-keep should be in the form polygon/0xabcd" }
	($type,1);
    } @{$def->[1]};
}

my $item_type_qr = qr{^(_polygon|_line|_point)$};

my @items;
{
    my $in_section;
    my $do_parse_xpm;
    my $current_xpm_key;
    my $parse_xpm_string_ref;
    my $item;
    while(<>) {
	s{\r}{};
	if ($do_parse_xpm) {
	    if (/^[}"]/) {
		$$parse_xpm_string_ref .= $_;
	    } else {
		if ($$parse_xpm_string_ref =~ m{^\"0 0 }) {
		    $item->{"_Incomplete"}->{$current_xpm_key} = $$parse_xpm_string_ref;
		    warn "INFO: remember incomplete 0x0 pixmap for later, item=" . _item_id($item) . "\n";
		    undef $$parse_xpm_string_ref;
		    $do_parse_xpm = 0;
		} else {
		    warn "WARN: Ignore invalid XPM, which is not a 0x0 pixmap...";
		    undef $$parse_xpm_string_ref;
		    $do_parse_xpm = 0;
		}
		redo;
	    }
	    if (/^};/) {
		$do_parse_xpm = 0;
	    }
	} elsif (m{^\[(.*)\]}) {
	    my $tag = $1;
	    if ($tag eq 'end') {
		undef $in_section;
	    } else {
		$in_section = $tag;
		if ($tag =~ $item_type_qr) {
		    (my $itemtype = $1) =~ s{^_}{};
		    $item = { ItemType => $itemtype };
		    push @items, $item;
		}
	    }
	} elsif ($in_section) {
	    if ($in_section =~ $item_type_qr) {
		if (m{^(XPM|DayXPM|NightXPM)=(.*)}) {
		    $do_parse_xpm = 1;
		    $current_xpm_key = $1;
		    $item->{$1} = $2;
		    $parse_xpm_string_ref = \$item->{$1};
		} elsif (m{^String\d+=([\dx]+),(.*)}) {
		    $item->{String}->{$1} = $2;
		} elsif (m{^Type=(.*)}) {
		    (my $type = $1) =~ s{(0x)0}{$1}; # remove leading zero
		    $item->{Type} = $type;
		} elsif (m{^(SubType|LineWidth|BorderWidth)=(.*)}) {
		    $item->{$1} = $2;
		}
	    }
	}
    }
}

# xpm fixing
for my $item (@items) {
    if ($item->{"_Incomplete"}) {
	while(my($key, $val) = each %{ $item->{"_Incomplete"} }) {
	    if ($item->{LineWidth}) {
		# a line item
		my $height = $item->{LineWidth} + 2*($item->{BorderWidth}||0);
		($item->{$key} = $val) =~ s{^\"0 0 }{\"32 $height }; # turn 0x0 into 32x? pixmap
		if ($item->{BorderWidth}) {
		    _create_xpm_line_32(\($item->{$key}), "XX") for 1..$item->{BorderWidth};
		}
		_create_xpm_line_32(\($item->{$key}), "==") for 1..$item->{LineWidth};
		if ($item->{BorderWidth}) {
		    _create_xpm_line_32(\($item->{$key}), "XX") for 1..$item->{BorderWidth};
		}
	    } else {
		# a polygon item
		($item->{$key} = $val) =~ s{^\"0 0 }{\"32 32 }; # turn 0x0 into 32x32 pixmap
		_create_xpm_line_32(\($item->{$key}), "XX") for 1..32;
		$item->{$key} .= "};\n";
	    }
	}
    }
}

{
    if (-d $output_dir && $force) {
	require File::Path;
	File::Path::rmtree($output_dir);
    }
    mkdir $output_dir or die "Can't create $output_dir: $!";

    my $png_i = 0;
    my $output_html = "$output_dir/index.html";
    open my $ofh, ">", $output_html
	or die "Can't write to $output_html: $!";
    binmode $ofh, ":encoding($encoding)";
    print $ofh <<EOF;
<html>
 <head>
  <title>Legende</title>
  <meta http-equiv="content-type" content="text/html; charset=$encoding" />
  <style type="text/css"><!--
  table		  { border-collapse:collapse; }
  th,td           { border:1px solid black; padding: 1px 5px 1px 5px; }
  body		  { font-family:sans-serif; }
  .sml            { font-size: x-small; }
  --></style>
  </head>
 <body>
EOF
    if ($title) {
	print $ofh "<h1>"._htmlify($title)."</h1>\n";
    }
    print $ofh <<EOF;
  <table cellpadding="1" cellspacing="0">
   <tr>
    <th>Symbol</th>
    <th>deutsch</th>
    <th>english</th>
    <th class="sml">garmin item id</th>
   </tr>
EOF

    for my $item (@items) {
	my $itemkey     = $item->{ItemType}.'/'.$item->{Type};
	my $itemlongkey = $item->{ItemType}.'/'.$item->{Type}.($item->{SubType}?"/$item->{SubType}":"");
	next if $ignore{$itemkey} || $ignore{$itemlongkey};
	if (%keep) {
	    next if !$keep{$itemkey} && !$keep{$itemlongkey};
	}
	for my $xpm_type (qw(XPM DayXPM NightXPM)) {
	    if ($item->{$xpm_type}) {
		my $out_image = $output_dir . "/" . sprintf("%04d.png", $png_i++);
## XXX Imager does not have xpm support, surprise, surprise...
#		my $img = Imager->new;
#		$img->read(data => $item->{$xpm_type}, type => 'xpm')
#		    or die "Cannot read: " . $img->errstr;
#		$img->write(file => $out_image, type => "png")
#		    or die "Cannot write: " . $img->errstr;
		my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".xpm", UNLINK => 1)
		    or die $!;

		my $xpm_data = $item->{$xpm_type};
		# XXX Hack: it seems that the colors are swapped for line items. Fixing this.
		if ($item->{ItemType} eq 'line') {
		    $xpm_data =~ s{"(XX|==)(\s+c\s+)}{ '"' . ($1 eq 'XX' ? '==' : 'XX') . $2 }eg;
		} elsif ($item->{ItemType} eq 'point'
			 && @nopngheuristic
			 && !$nopngheuristic{$itemkey} && !$nopngheuristic{$itemlongkey}
			) { # transparent not handled correctly --- but this heuristic does not work perfectly, so can be turned off with %nopngheuristic
		    $xpm_data =~ s{("XX\s+c\s+)#[0-9a-f]+}{$1 . "none"}e;
		}

		print $tmpfh $xpm_data;
		close $tmpfh or die $!;
		system("convert", $tmpfile, $out_image);
		$? == 0 or die "Failure while converting $tmpfile to $out_image, item " . _item_name($item) . ', xpm: ' . $item->{$xpm_type};
		unlink $tmpfile;
		(my $png_type = $xpm_type) =~ s{XPM}{PNG};
		$item->{$png_type} = basename $out_image;
	    }
	}
	print $ofh "<tr><td>";
	if ($item->{PNG}) {
	    print $ofh qq{<img src="$item->{PNG}" />};
	} elsif ($item->{DayPNG}) {
	    print $ofh qq{<img src="$item->{DayPNG}" /> <img src="$item->{NightPNG}" />};
	}
	print $ofh "</td><td>";
	my $de_label = $item->{String}->{'0x02'} || '';
	my $en_label = $item->{String}->{'0x00'} || '';
	print $ofh _htmlify($de_label);
	print $ofh "</td><td>";
	print $ofh _htmlify($en_label);
	print $ofh qq{</td><td class="sml">};
	print $ofh $item->{ItemType} . "/" . $item->{Type} . ($item->{SubType} ? "/" . $item->{SubType} : "");
	print $ofh "</td></tr>\n";
    }

    print $ofh <<EOF;
  </table>
 </body>
</html>
EOF
    close $ofh
	or die "Problem while closing: $!";
}

sub _htmlify {
    HTML::Entities::encode_entities_numeric($_[0], '<>&"\200-');
}

# for debugging
sub _item_name {
    my $item = shift;
    $item->{String}->{'0x02'} || $item->{String}->{'0x00'} || '???';
}

# for debugging
sub _item_id {
    my $item = shift;
    $item->{ItemType} . "/" . $item->{Type} . ($item->{SubType} ? "/" . $item->{SubType} : "");
}

sub _create_xpm_line_32 {
    my($dataref, $colorcode) = @_;
    $$dataref .= qq{"}.($colorcode x 32) . qq{",\n};
}

sub usage (;$) {
    my $msg = shift;
    warn $msg, "\n" if $msg;
    die <<EOF;
usage: $0 -o outputdir [-encoding ...] [-igntype ...,...] < decompiled_typ_file.TXT
EOF
}

__END__

=head1 EXAMPLE

Currently the legend for the bbbike/garmin map is best created as
such:

    perl ./miscsrc/typ2legend.pl < misc/mkgmap/typ/M000002a.TXT -f -o /tmp/legend -title "Legende für die BBBike-Garmin-Karte" -keep polygon/0x0a,polygon/0x0c,polygon/0x0d,polygon/0x16,polygon/0x19,polygon/0x1a,polygon/0x3c,polygon/0x4e,polygon/0x50,line/0x01,line/0x03,line/0x04,line/0x05,line/0x06,line/0x0f,line/0x13,line/0x14,line/0x1a,line/0x1c,line/0x1e,line/0x2c,line/0x2d,line/0x2e,line/0x2f,line/0x30,line/0x31,line/0x32,line/0x33,line/0x34,line/0x35,line/0x36,line/0x37,line/0x38,line/0x39,line/0x3a,line/0x3b,line/0x3c,line/0x3d,line/0x3e,line/0x3f,point/0x70,point/0x71,point/0x72 -nopngheuristic point/0x70/0x01,point/0x71/0x01,point/0x71/0x06

"keep" lists only items which are actually used in the bbd data and
converted with bbd2osm.

In special layers of the bbbike/garmin map the following items are
also used:

* line/0x040 (Ampelphasen)

* point/0x073* (categorized fragezeichen)

=cut
