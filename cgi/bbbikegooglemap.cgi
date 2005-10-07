#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.cgi,v 1.5 2005/10/07 07:40:00 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 # für Radzeit:
	 "$FindBin::RealBin/../BBBike",
	 "$FindBin::RealBin/../BBBike/lib",
	);
use CGI qw(:standard);
use Karte;
use Karte::Polar;

my @polylines_polar;
my @wpt;

for my $coords (param("coords")) {
    my(@coords) = split /[!;]/, $coords;
    my(@coords_polar) = map {
	my($x,$y) = split /,/, $_;
	join ",", $Karte::Polar::obj->standard2map($x,$y);
    } @coords;
    push @polylines_polar, \@coords_polar;
}

for my $wpt (param("wpt")) {
    my($name,$coord) = split /[!;]/, $wpt;
    my($x,$y) = split /,/, $coord;
    ($x, $y) = $Karte::Polar::obj->standard2map($x,$y);
    push @wpt, [$x,$y,$name];
}

print header;
print get_html(\@polylines_polar, \@wpt);

sub get_html {
    my($paths_polar, $wpts) = @_;

    my($centerx,$centery);
    if ($paths_polar && @$paths_polar) {
	($centerx,$centery) = map { sprintf "%.5f", $_ } split /,/, $paths_polar->[0][0];
    } elsif ($wpts && @$wpts) {
	($centerx,$centery) = map { sprintf "%.5f", $_ } $wpts->[0][0], $wpts->[0][1];
    }

    my $zoom = 3;

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
  <head>
    <script src="http://maps.google.com/maps?file=api&v=1&key=ABQIAAAAidl4U46XIm-bi0ECbPGe5hR1DE4tk8nUxq5ddnsWMNnWMRHPuxTzJuNOAmRUyOC19LbqHh-nYAhakg" type="text/javascript"></script>
  </head>
  <body>
    <div id="map" style="width: 600px; height: 500px"></div>
    <script type="text/javascript">
    //<![CDATA[

    function createMarker(point, html_name) {
	var marker = new GMarker(point);
        var html = "<b>" + html_name + "</b>";
	GEvent.addListener(marker, "click", function() {
	    marker.openInfoWindowHtml(html);
	});
	return marker;
    }

    function setwpt(x,y) {
        map.recenterOrPanToLatLng(new GPoint(x, y));
    }
    
    var map = new GMap(document.getElementById("map"), [G_SATELLITE_TYPE]);
    map.addControl(new GLargeMapControl());
    map.addControl(new GMapTypeControl());
    map.centerAndZoom(new GPoint($centerx, $centery), $zoom);

EOF
    for my $path_polar (@$paths_polar) {
	my $route_js_code = <<EOF;
    var route = new GPolyline([
EOF
	$route_js_code .= join(",\n",
			       map {
				   my($x,$y) = split /,/, $_;
				   sprintf 'new GPoint(%.5f, %.5f)', $x, $y;
			       } @$path_polar
			      );
	$route_js_code .= q{], "#ff0000", 10);};

	$html .= <<EOF;
$route_js_code
    map.addOverlay(route);
EOF
    }

    for my $wpt (@$wpts) {
	my($x,$y,$name) = @$wpt;
	my $html_name = escapeHTML($name);
	$html .= <<EOF;
    var point = new GPoint($x,$y);
    var marker = createMarker(point, "$html_name");
    map.addOverlay(marker);
EOF
    }

    $html .= <<EOF;

    //]]>
    </script>
    <div id="wpt">
EOF
    for my $wpt (@$wpts) {
	my($x,$y,$name) = @$wpt;
	$html .= qq{<a href="#map" onclick="setwpt($x,$y);return true;">$name</a><br />\n};
    }
    $html .= <<EOF;
    </div>
  </body>
</html>
EOF
}
__END__
