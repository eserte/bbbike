#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbd2mapservhtml.pl,v 1.19 2007/03/07 22:14:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Create a HTML-Formular from bbd data. The HTML form will redirect to
# MapServer using the specified data for a new (route) layer.

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen::Core;
use Strassen::Util;
use Object::Iterate qw(iterate);
use Getopt::Long;
use BBBikeVar;
use CGI qw();

my $bbbike_url = $BBBike::BBBIKE_DIRECT_WWW;
my $email = $BBBike::EMAIL;
my @layers;
my($width, $height);
my $mapscale;
my $center_spec;
my $do_center_nearest;
my $partialhtml;
my $do_linklist;
my $do_headlines;
my $preferalias;

my $save_cmdline = "$0 @ARGV";

if (!GetOptions("bbbikeurl=s" => \$bbbike_url,
		"email=s" => \$email,
		"local!" => sub {
		    $bbbike_url = "http://www/~eserte/bbbike/cgi/bbbike.cgi";
		},
		"local-radzeit!" => sub {
		    $bbbike_url = "http://radzeit/cgi-bin/bbbike.cgi";
		},
		'layer=s@' => \@layers,
		'initmapext=s' => sub {
		    ($width, $height) = split /x/, $_[1];
		},
		'mapscale=s' => sub {
		    my $scale = $_[1];
		    $scale =~ s{^1:}{};
		    if ($scale !~ /^\d+$/) {
			die "-mapscale must be a number or 1:number";
		    }
		    $width = $height = $scale/5;
		},
		'center=s' => \$center_spec,
		'centernearest!' => \$do_center_nearest,
		'partialhtml!' => \$partialhtml,
		'linklist!' => \$do_linklist,
		'preferalias!' => \$preferalias,
		'headlines!' => \$do_headlines,
	       )) {
    require Pod::Usage;
    Pod::Usage::pod2usage(2);
}

if (!@layers) {
    push @layers, qw(sbahn wasser flaechen grenzen orte fragezeichen);
}

my $bbd_file = shift || "-";
my $s;
if ($bbd_file =~ /\.bbr$/) {
    require Route;
    require Route::Heavy;
    $s = Route::as_strassen($bbd_file);
} else {
    $s = Strassen->new($bbd_file, UseLocalDirectives => 1);
}

my $center;
if (defined $center_spec && $center_spec ne "") {
    if ($center_spec =~ /^city=(.*)/) {
	my($city,$country) = split /_/, $1, 2;
	require Geography;
	my $geo = Geography->new($city, $country);
	$center = $geo->center;
    } elsif ($center_spec =~ /\d+,.*\d/) {
	$center = $center_spec;
    } else {
	die "Cannot understand -center specification <$center_spec>";
    }
}

my $html_header = <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"> <!-- -*-html-*- -->
<html><head>
<title>Mapserver/BBBike</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rev="made" href="mailto:$email" />
<link rel="stylesheet" type="text/css" href="style.css" />
EOF
if (!$do_linklist) {
    $html_header .= <<EOF;
<script type="text/javascript"><!--
function autosubmit() {
  var frm = document.forms[0];
  frm.submit();
}
function hidesubmitbutton() {
  if (document.getElementById) {
    var sb = document.getElementById("submitbutton");
    if (sb) {
      sb.style.visibility = "hidden";
    }
  }
}
// --></script>
EOF
}
$html_header .= <<EOF;
</head>
<body @{[ $do_linklist ? '' : 'onload="autosubmit()"' ]}>
EOF

my $html;

if ($do_linklist) {
    my @html;
    $s->init;

    my $last_section;
    my $current_display_name;
    my @current_lines;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] };
	push @current_lines, $r->[Strassen::COORDS];

	if (!defined $current_display_name) {
	    if ($preferalias) {
		$current_display_name = $s->get_directive->{alias}->[0] || $r->[Strassen::NAME];
	    } else {
		$current_display_name = $r->[Strassen::NAME] || $s->get_directive->{alias}->[0];
	    }
	}

	if ($do_headlines) {
	    my $current_section = $s->get_directive->{section}->[0];
	    if ($current_section) {
		if (!defined $last_section || $current_section ne $last_section) {
		    push @html, "<h2>" . CGI::escapeHTML($current_section) . "</h2>";
		    $last_section = $current_section;
		}
	    }
	}

	my $next_r = $s->peek;
	unless ($next_r && @{$next_r->[Strassen::COORDS]} &&
		$r->[Strassen::NAME] eq $next_r->[Strassen::NAME]) {
	    my @coords = lines_to_coords(@current_lines);

	    push @html, generate_single_html(coords => \@coords,
					     (defined $center ? (center => find_nearest_to_center(\@current_lines, $center)) : ()),
					     label => $current_display_name,
					     submitlabel => " >> ",
					    );
	    @current_lines = ();
	    undef $current_display_name;
	}
    }

    $html = join("\n", @html);
} else {
    my @lines;
    iterate {
	push @lines, $_->[Strassen::COORDS()];
    } $s;

    my @coords = lines_to_coords(@lines);

    $html = generate_single_html(coords => \@coords,
				 (defined $center ? (center => find_nearest_to_center(\@lines, $center)) : ()),
				 label => undef,
				 submitlabel => "Zum Mapserver",
				);
				 
}

my $html_footer = "";
if (!$do_linklist) {
    $html_footer .= <<EOF;
<script><!--
  hidesubmitbutton();
 //--></script>
EOF
}
$html_footer .= <<EOF;
</body></html>
<!--
     This file was generated with

EOF
$html_footer .= "  " . CGI::escapeHTML($save_cmdline) . "\n";
$html_footer .= <<EOF;

     on @{[ scalar localtime ]}
-->
EOF

print $html_header if !$partialhtml;
print $html;
print $html_footer if !$partialhtml;

sub find_nearest_to_center {
    my($lines_ref, $center) = @_;
    my $nearest_c;
    my $nearest_dist;
    for my $c (map { @$_ } @$lines_ref) {
	my $dist = Strassen::Util::strecke_s($center, $c);
	if (!defined $nearest_dist || $dist < $nearest_dist) {
	    $nearest_c = $c;
	    $nearest_dist = $dist;
	}
    }
    $nearest_c;
}

sub lines_to_coords {
    my(@lines) = @_;
    # XXX instead of int() should something like best_accuracy be used
    my @coords =
	map {
	    join "!", map {
		join ",", map { int } split /,/, $_
	    } @$_
	} @lines; # "!" for older bbbike.cgi
    @coords;
}

sub generate_single_html {
    my(%args) = @_;

    my @coords = @{ delete $args{coords} };
    my $center = delete $args{center};
    my $label = delete $args{label};
    my $submitlabel = delete $args{submitlabel};

    die "usage? " . join(" ", %args) if keys %args;

    my $html = <<EOF;
<form style='margin-bottom:0px;' action="$bbbike_url" method="post">
 <input type="hidden" name="imagetype" value="mapserver" />
EOF
    for my $coords (@coords) {
	$html .= <<EOF;
 <input type="hidden" name="coords" value="$coords" />
EOF
    }
    for my $layer (@layers) {
	$html .= <<EOF;
 <input type="hidden" name="draw" value="$layer" />
EOF
    }
    if (defined $center) {
	$html .= <<EOF;
 <input type="hidden" name="center" value="$center" />
EOF
    }
    if (defined $width && defined $height) {
	$html .= <<EOF;
 <input type="hidden" name="width" value="$width" />
 <input type="hidden" name="height" value="$height" />
EOF
    }

    if (defined $label) {
	$html .= "\n" . CGI::escapeHTML($label);
    } 
    $html .= <<EOF;
 <input id="submitbutton" type="submit" value="@{[ CGI::escapeHTML($submitlabel) ]}" />
</form>
EOF

    return $html;
}

__END__

=head1 NAME

bbd2mapservhtml.pl - create a mapserver route from a bbd or bbr file

=head1 SYNOPSIS

    bbd2mapservhtml [-bbbikeurl url] [-email email]
		    [-[no]local | -local-radzeit]
                    [-layer layername [-layer ...]]
                    [-initmapext {width}x{height}] [-mapscale scale]
		    [-center x,y] [-centernearest]
		    [-partialhtml] [-linklist] [-preferalias]
		    [file]

=head1 DESCRIPTION

=over

=item -local

Use a local mapserver URL instead of the official one from BBBikeVar

=item -local-radzeit

Use another local mapserver URL (similar to the official at "radzeit").

=item -layer

Specify the initial set of layers. This option may be given multiple
times.

=item -initmapext I<width>xI<height>

Set the initial extents (in real life meters) of the map.

=item -mapscale I<scale>

=item -mapscale 1:I<scale>

Set the initial extents via a scale number (e.g. 1:20000 or just
20000). Note that B<-mapscale> and B<-initmapext> cannot be specified
together.

=item -center I<...>

Center the map. The argument to center may be one of the following:

=over

=item I<x>,I<y>

Center to the specified BBBike standard coordinate.

=item C<city=>I<city_country>

Center to the preferred center of the specified city. A sample city
specification: C<Berlin_DE>. See the L<Geography> module/directory for
available cities.

=back

If the C<-center> option is not given, then center to the first point
in the bbd file resp. the first point of a street record in linklist
more.

=item -centernearest

In conjunction with the C<-center> option: center to the nearest point
in the route from the specified center.

=item -partialhtml

Output partial html without HTML head, body start and end tags. This
option is useful for automatic inclusion into a pre-made html page.

=item -linklist

Create a link list with one street per line.

=item -headlines

Create headlines from "section" blocks.

=item -preferalias

In a linklist, prefer the alias name (set in bbd files with the "#:
alias" directive) over the street name.

=back

If I<file> is not given, then read from standard input.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<cmdbbbike>, L<bbd>

=cut

