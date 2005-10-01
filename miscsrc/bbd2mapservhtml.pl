#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbd2mapservhtml.pl,v 1.14 2005/10/01 23:05:19 eserte Exp $
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
use Object::Iterate qw(iterate);
use Getopt::Long;
use BBBikeVar;
use CGI qw();

my $bbbike_url = $BBBike::BBBIKE_DIRECT_WWW;
my $email = $BBBike::EMAIL;
my @layers;
my($width, $height);
my $mapscale;
my $center;

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
		'mapscale=i' => sub {
		    $width = $height = $_[1]/5;
		},
		'center=s' => \$center,
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
    $s = Strassen->new($bbd_file);
}
my @lines;
iterate {
    push @lines, $_->[Strassen::COORDS()];
} $s;
# XXX instead of int() should something like best_accuracy be used
my @coords =
    map {
	join "!", map {
	    join ",", map { int } split /,/, $_
	} @$_
    } @lines; # "!" for older bbbike.cgi

my $html = <<EOF;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"> <!-- -*-html-*- -->
<html><head>
<title>Mapserver/BBBike</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rev="made" href="mailto:$email" />
<link rel="stylesheet" type="text/css" href="style.css" />
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
</head>
<body onload="autosubmit()">
<form action="$bbbike_url" method="post">
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

$html .= <<EOF;
 <input id="submitbutton" type="submit" value="Zum Mapserver" />
 <script><!--
  hidesubmitbutton();
 //--></script>
</form>
</body></html>
<!--
     This file was generated with

EOF
$html .= "  " . CGI::escapeHTML($save_cmdline) . "\n";
$html .= <<EOF;

     on @{[ scalar localtime ]}
-->
EOF

print $html;

__END__

=head1 NAME

bbd2mapservhtml.pl - create a mapserver route from a bbd or bbr file

=head1 SYNOPSIS

    bbd2mapservhtml [-bbbikeurl url] [-email email]
		    [-[no]local | -local-radzeit]
                    [-layer layername [-layer ...]]
                    [-initmapext {width}x{height}] [-mapscale scale]
		    [-center x,y] [file]

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

Set the initial extents via a scale number (e.g. 1:20000, only the
last part). Note that B<-mapscale> and B<-initmapext> cannot be
specified together.

=item -center I<x>,I<y>

Center the map to the specified coordinate. If not given, then center
to the first point in the bbd file.

=back

If I<file> is not given, then read from standard input.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<cmdbbbike>, L<bbd>

=cut

