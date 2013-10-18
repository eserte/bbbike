#!/usr/bin/perl
# -*- mode:perl;coding:iso-8859-1; -*-

use strict;
use FindBin;
use lib $FindBin::RealBin;
use utf8;

use File::Basename qw(basename);
use File::Temp qw(tempfile);
use Getopt::Long;
use HTML::Entities ();
#use Imager;

use Typ2Legend::XPM;

sub usage (;$);

my $output_dir;
my $force;
my @ignore;
my @keep;
my @nopngheuristic; # This is somewhat ugly, it is doing two things: turning on png transparency heuristics and defining examples where the heuristics shouldn't be applied
my @noprefer15;
my $title;
my $encoding = 'utf-8';
GetOptions("o=s"       => \$output_dir,
	   "f"         => \$force,
	   'ignore=s@' => sub { push @ignore, split /,/, $_[1] },
	   'keep=s@'   => sub { push @keep,   split /,/, $_[1] },
	   'nopngheuristic=s@' => sub { push @nopngheuristic, split /,/, $_[1] },
	   'noprefer15=s@' => sub { push @noprefer15, split /,/, $_[1] },
	   'encoding=s' => \$encoding,
	   'title=s'   => \$title,
	  )
    or usage;
$output_dir or usage "-o is mandatory";

my %ignore;
my %keep;
my %nopngheuristic;
my %noprefer15;
for my $def ([\%ignore, \@ignore],
	     [\%keep, \@keep],
	     [\%nopngheuristic, \@nopngheuristic],
	     [\%noprefer15, \@noprefer15],
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
    my @parse_xpm_lines;
    my $item;
    my $finalize_xpm_object = sub {
	if ($item->{ItemType} eq 'point') {
	    $item->{$current_xpm_key} = join("\n", @parse_xpm_lines);
	} else {
	    $item->{$current_xpm_key . "_object"} = Typ2Legend::XPM->new(\@parse_xpm_lines);
	}
	$do_parse_xpm = 0;
	@parse_xpm_lines = ();
    };
    while(<>) {
	s{\r}{};
	if ($do_parse_xpm) {
	    if (/^[}"]/) {
		chomp;
		push @parse_xpm_lines, $_;
	    } else {
		$finalize_xpm_object->();
		redo; # premature end of XPM data
	    }
	    if (/^};/) {
		$finalize_xpm_object->();
	    }
	} elsif (m{^\[(.*)\]}) {
	    my $tag = $1;
	    if ($tag eq 'end') {
		undef $in_section;
	    } else {
		$in_section = $tag;
		if ($tag =~ $item_type_qr) {
		    (my $itemtype = $1) =~ s{^_}{};
		    $item = Typ2Legend::Item->new({ItemType => $itemtype});
		    push @items, $item;
		}
	    }
	} elsif ($in_section) {
	    if ($in_section =~ $item_type_qr) {
		if (m{^(XPM|DayXPM|NightXPM)=(.*)}) {
		    $do_parse_xpm = 1;
		    $current_xpm_key = $1;
		    chomp(my $xpm_head = $2);
		    @parse_xpm_lines = $xpm_head;
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

# xpm transformation
for my $item (@items) {
    my $itemkey     = $item->itemkey;
    my $itemlongkey = $item->itemlongkey;
    if ($item->{"XPM_object"}) { # XXX Can DayXPM_object/NightXPM_object happen at this point?
	my $ret;
	if ($item->{LineWidth}) {
	    $ret = $item->{"XPM_object"}->transform(linewidth => $item->{LineWidth}, borderwidth => $item->{BorderWidth});
	} else {
	    my $noprefer15 = $noprefer15{$itemlongkey} || $noprefer15{$itemkey};
	    $ret = $item->{"XPM_object"}->transform(prefer15=>$noprefer15?0:1);
	}
	if ($ret->{'day'}) {
	    $item->{DayXPM} = $ret->{'day'}->as_string;
	}
	if ($ret->{'night'}) {
	    $item->{NightXPM} = $ret->{'night'}->as_string;
	}
	if ($ret->{'day+night'}) {
	    $item->{XPM} = $ret->{'day+night'}->as_string;
	}
	delete $item->{"XPM_object"};
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
  .daypng         { border:2px solid white; }
  .nightpng       { border:2px solid white; } /* the "black" experiment was confusing */
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
	my $itemkey     = $item->itemkey;
	my $itemlongkey = $item->itemlongkey;
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
		if ($item->{ItemType} eq 'point'
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
	    print $ofh qq{<img title="day image" class="daypng" src="$item->{DayPNG}" /> <img title="night image" class="nightpng" src="$item->{NightPNG}" />};
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

sub usage (;$) {
    my $msg = shift;
    warn $msg, "\n" if $msg;
    die <<EOF;
usage: $0 -o outputdir [-encoding ...] [-igntype ...,...] < decompiled_typ_file.TXT
EOF
}

{
    package
	Typ2Legend::Item;

    sub new {
	my($class, $item) = @_;
	bless $item, $class;
    }

    sub itemkey {
	my $self = shift;
	$self->{ItemType}.'/'.$self->{Type};
    }

    sub itemlongkey {
	my $self = shift;
	$self->{ItemType}.'/'.$self->{Type}.($self->{SubType}?"/$self->{SubType}":"");
    }
}

__END__

=head1 NAME

typ2legend.pl - create a HTML legend from a decompiled .TYP file

=head1 DESCRIPTION

This script created a HTML page together with .png images for a .TYP
file. As input a decompiled .TYP file (usually with extension .TXT)
has to be provided. See L<http://ati.land.cz/gps/typdecomp/editor.cgi>
for a .TYP file editor and decompiler.

=head1 EXAMPLES

Currently the legend for the bbbike/garmin map is best created as
such:

    perl ./miscsrc/typ2legend.pl < misc/mkgmap/typ/M000002a.TXT -f -o tmp/typ_legend -title "Legende für die BBBike-Garmin-Karte" -keep polygon/0x0a,polygon/0x0c,polygon/0x0d,polygon/0x16,polygon/0x19,polygon/0x1a,polygon/0x3c,polygon/0x4e,polygon/0x50,line/0x01,line/0x03,line/0x04,line/0x05,line/0x06,line/0x0f,line/0x13,line/0x14,line/0x1a,line/0x1c,line/0x1e,line/0x2c,line/0x2d,line/0x2e,line/0x2f,line/0x30,line/0x31,line/0x32,line/0x33,line/0x34,line/0x35,line/0x36,line/0x37,line/0x38,line/0x39,line/0x3a,line/0x3b,line/0x3c,line/0x3d,line/0x3e,line/0x3f,point/0x70,point/0x71,point/0x72/0x01,point/0x72/0x03 -nopngheuristic point/0x70/0x01,point/0x71/0x01,point/0x71/0x06 -noprefer15 line/0x13,line/0x14

The generated html file may be found in C<tmp/typ_legend/index.html>.

"keep" lists only items which are actually used in the bbd data and
converted with bbd2osm.

For OSM data the "keep" list is not necessary. Here the legend may be
created with:

    perl ./miscsrc/typ2legend.pl < misc/mkgmap/typ/M000002a.TXT -f -o tmp/typ_osm_legend -title "Legende für die OSM-Garmin-Karte" -nopngheuristic point/0x27,point/0x2f/0x08,point/0x70/0x01,point/0x71/0x01,point/0x71/0x06 -noprefer15 line/0x13,line/0x14

The generated html file may be found in C<tmp/typ_osm_legend/index.html>.

The generation commands are also in F<misc/Makefile>, look for the
C<typ-legend-all> target.

=head1 NOTES

The decompiled .TXT file from
L<http://ati.land.cz/gps/typdecomp/editor.cgi> is ambiguous. The
following color style types cannot be distinguished and may be 

=over

=item polygon: 15 vs. 8 and bitmapped line: 7 vs. 0

By default polygon 8 resp. line 0 is used. With the option
C<-noprefer15> the other color style type may be chosen.

=item polygon: 13 vs. 11 and bitmapped line: 5 vs. 3

By default polygon 11 resp. line 3 is used. There's no cmdline option
yet (but Typ2Legend::XPM has internally the option C<prefer13>).

=back

In special layers of the bbbike/garmin map the following items are
also used:

=over

=item * line/0x040 (Ampelphasen)

=item * point/0x073* (categorized fragezeichen)

=back

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<Typ2Legend::XPM>.

=cut
