#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbd2mapservhtml.pl,v 1.3 2004/02/16 01:05:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Create a HTML-Formular from bbd data

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

my $bbbike_url = $BBBike::BBBIKE_DIRECT_WWW;
my $email = $BBBike::EMAIL;
my @layers;

if (!GetOptions("bbbikeurl=s" => \$bbbike_url,
		"email=s" => \$email,
		"local!" => sub {
		    $bbbike_url = "http://www/~eserte/bbbike/cgi/bbbike.cgi";
		},
		'layer=s@' => \@layers,
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
my @coords;
iterate {
    push @coords, @{ $_->[Strassen::COORDS()] };
} $s;
my $coords = join "!", @coords; # "!" for older bbbike.cgi

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
 <input type="hidden" name="coords" value="$coords" />

EOF
for my $layer (@layers) {
    $html .= <<EOF;
 <input type="hidden" name="draw" value="$layer" />
EOF
}

$html .= <<EOF;
 <input id="submitbutton" type="submit" value="Zum Mapserver" />
 <script><!--
  hidesubmitbutton();
 //--></script>
</form>
</body></html>
EOF

print $html;

__END__
