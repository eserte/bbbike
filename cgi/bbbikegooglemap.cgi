#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.cgi,v 1.22 2005/12/10 23:47:01 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGooglemap;

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

sub new { bless {}, shift }

sub run {
    my($self) = @_;

    local $CGI::POST_MAX = 2_000_000;

    my @polylines_polar;
    my @wpt;

    my $coordsystem = param("coordsystem") || "standard";
    my $converter;
    if ($coordsystem eq 'polar') {
	$converter = \&polar_converter;
    } else {
	$converter = \&standard_converter;
    }

    if (param("wpt_or_trk")) {
	if (param("wpt_or_trk") =~ / /) {
	    param("coords", join("!",
				 param("coords"),
				 split(/ /, param("wpt_or_trk")))
		 );
	} else {
	    param("wpt", param("wpt_or_trk"));
	}
    }

    my $filename = param("gpxfile");
    if (defined $filename) {
	(my $ext = $filename) =~ s{^.*\.}{.};
	require Strassen::Core;
	require File::Temp;
	my $fh = upload("gpxfile");
	my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
						   SUFFIX => $ext);
	while(<$fh>) {
	    print $tmpfh $_;
	}
	close $fh;
	close $tmpfh;

	my $gpx = Strassen->new($tmpfile);
	$gpx->init;
	while(1) {
	    my $r = $gpx->next;
	    last if !@{ $r->[Strassen::COORDS()] };
	    # XXX hack --- should append recognise self_or_default?
	    $CGI::Q->append(-name   => 'coords',
			    -values => [join "!", @{ $r->[Strassen::COORDS()] }],
			   );
	}
    }

    for my $coords (param("coords")) {
	my(@coords) = split /[!;]/, $coords;
	my(@coords_polar) = map {
	    my($x,$y) = split /,/, $_;
	    join ",", $converter->($x,$y);
	} @coords;
	push @polylines_polar, \@coords_polar;
    }

    for my $wpt (param("wpt")) {
	my($name,$coord);
	if ($wpt =~ /[!;]/) {
	    ($name,$coord) = split /[!;]/, $wpt;
	} else {
	    $name = "";
	    $coord = $wpt;
	}
	my($x,$y) = split /,/, $coord;
	($x, $y) = $converter->($x,$y);
	push @wpt, [$x,$y,$name];
    }

    my $zoom = param("zoom");
    $zoom = 3 if !defined $zoom;

    $self->{converter} = $converter;
    $self->{coordsystem} = $coordsystem;

    print header;
    print $self->get_html(\@polylines_polar, \@wpt, $zoom);
}

sub standard_converter {
    my($x,$y) = @_;
    $Karte::Polar::obj->standard2map($x,$y);
}

sub polar_converter { @_[0,1] }

sub get_html {
    my($self, $paths_polar, $wpts, $zoom) = @_;

    my $converter = $self->{converter};
    my $coordsystem = $self->{coordsystem};

    my($centerx,$centery);
    if ($paths_polar && @$paths_polar) {
	($centerx,$centery) = map { sprintf "%.5f", $_ } split /,/, $paths_polar->[0][0];
    } elsif ($wpts && @$wpts) {
	($centerx,$centery) = map { sprintf "%.5f", $_ } $wpts->[0][0], $wpts->[0][1];
    } else {
	require Geography::Berlin_DE;
	($centerx,$centery) = $converter->(split /,/, Geography::Berlin_DE->center());
    }

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
  <head>
    <title>BBBike data presented with Googlemap</title>
    <link rel="stylesheet" type="text/css" href="/BBBike/html/bbbike.css"><!-- XXX only for radzeit -->
    <link type="image/gif" rel="shortcut icon" href="/BBBike/images/srtbike16.gif"><!-- XXX only for radzeit -->
    <script src="http://maps.google.com/maps?file=api&v=1&key=ABQIAAAAidl4U46XIm-bi0ECbPGe5hR1DE4tk8nUxq5ddnsWMNnWMRHPuxTzJuNOAmRUyOC19LbqHh-nYAhakg" type="text/javascript"></script>
    <script src="/BBBike/html/sprintf.js" type="text/javascript"></script>
  </head>
  <body>
    <div id="map" style="width: 100%; height: 500px"></div>
    <script type="text/javascript">
    //<![CDATA[

    var addRoute = [];
    var addRouteOverlay;

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
    
    function showCoords(point, message) {
        var latLngStr = message + formatPoint(point);
        document.getElementById("message").innerHTML = latLngStr;
    }

    function formatPoint(point) {
	var s = sprintf("%.6f,%.6f", point.x, point.y);
	return s;
    }

    function getCurrentMode() {
	if (document.forms["addroute"].elements["addroute"].checked) {
	    return "addroute";
	} else {
	    return "search";
	}
    }

    function addCoordsToRoute(point) {
	var currentMode = getCurrentMode();
	if (currentMode != "addroute") {
	    return;
	}
	if (addRoute.length > 0) {
	    var lastPoint = addRoute[addRoute.length-1];
	    if (lastPoint.x == point.x && lastPoint.y == point.y)
		return;
	}
	addRoute[addRoute.length] = point;
	updateRouteDiv();
	updateRouteOverlay();
    }

    function deleteLastPoint() {
	if (addRoute.length > 0) {
	    addRoute.length = addRoute.length-1;
	    updateRouteDiv(); 
	    updateRouteOverlay(); 
	}
    }

    function resetRoute() {
	addRoute = [];
	updateRouteDiv();
	updateRouteOverlay();
    }

    function updateRouteDiv() {
	var addRouteText = "";
	for(var i = 0; i < addRoute.length; i++) {
	    if (i == 0) {
		addRouteText = "Route: ";	
	    } else if (i > 0) {
		addRouteText += " ";
	    }
	    addRouteText += formatPoint(addRoute[i]);
	}
        document.getElementById("addroutetext").innerHTML = addRouteText;
    }

    function updateRouteOverlay() {
	if (addRouteOverlay) {
	    map.removeOverlay(addRouteOverlay);
	    addRouteOverlay = null;
	}
	if (!addRoute.length)
	   return;
	addRouteOverlay = new GPolyline(addRoute);
	map.addOverlay(addRouteOverlay);
    }

    function showLink(point, message) {
        var latLngStr = message + "@{[ url(-full => 1) ]}?zoom=" + map.getZoomLevel() + "&wpt=" + formatPoint(point) + "&coordsystem=polar";
        document.getElementById("permalink").innerHTML = latLngStr;
    }

    function checkSetCoordForm() {
	if (document.googlemap.wpt_or_trk.value == "") {
	    alert("Bitte Koordinaten eingeben (z.B. im WGS84-Modus: 13.376431,52.516172)");
	    return false;
	}
	setZoomInForm();
	return true;	
    }

    function setZoomInForm() {
	document.googlemap.zoom.value = map.getZoomLevel();
    }

    function setZoomInUploadForm() {
	document.upload.zoom.value = map.getZoomLevel();
    }

    function searchRoute(startPoint, goalPoint) {
	var requestLine =
	    "http://www.radzeit.de/cgi-bin/bbbike.cgi?startpolar=" + startPoint.x + "x" + startPoint.y + "&zielpolar=" + goalPoint.x + "x" + goalPoint.y + "&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=;output_as=xml;referer=bbbikegooglemap";
	var routeRequest = GXmlHttp.create();
	routeRequest.open("GET", requestLine, true);
	routeRequest.onreadystatechange = function() {
	    showRouteResult(routeRequest);
	};
	routeRequest.send(null);
    }

    function showRouteResult(request) {
	if (request.readyState == 4) {
	    if (request.status != 200) {
	        alert("Error calculating route: " + request.statusText);
	        return;
	    }
	    resetRoute();
	    var xml = request.responseXML;
	    var line = xml.documentElement.getElementsByTagName("LongLatPath")[0];
	    var pointElements = line.getElementsByTagName("XY");
	    var points = new Array();
	    for (var i = 0; i < pointElements.length; i++) {
	    	var xy = pointElements[i].textContent.split(",");
		if (i == 0) setwpt(xy[0],xy[1]);
	    	var p = new GPoint(xy[0],xy[1]);
	    	addRoute[addRoute.length] = p;
            }
	    //updateRouteDiv();
	    updateRouteOverlay();
	}
    }

    var searchStage = 0;
    var startOverlay = null;
    var startPoint = null;
    var goalOverlay = null;
    var goalPoint = null;

    function onClick(overlay, point) {
	var currentMode = getCurrentMode();
	if (currentMode != "search") {
	    return;
	}
	if (searchStage == 0) { // set start
	    if (startOverlay) {
		map.removeOverlay(startOverlay);
		startOverlay = null;
	    }
	    if (goalOverlay) {
		map.removeOverlay(goalOverlay);
		goalOverlay = null;
	    }
	    startPoint = point;
	    startOverlay = new GMarker(startPoint);
	    map.addOverlay(startOverlay);
	    searchStage = 1;
	} else if (searchStage == 1) { // set goal
	    goalPoint = point;
	    goalOverlay = new GMarker(goalPoint);
	    map.addOverlay(goalOverlay);
	    searchStage = 0;
	    searchRoute(startPoint, goalPoint);
	}
    }

    var map = new GMap(document.getElementById("map"), [G_SATELLITE_TYPE]);
    map.addControl(new GLargeMapControl());
    map.addControl(new GMapTypeControl());
    map.centerAndZoom(new GPoint($centerx, $centery), $zoom);

    GEvent.addListener(map, "moveend", function() {
        var center = map.getCenterLatLng();
	showCoords(center, 'Center of map: ');
	showLink(center, 'Link: ');
	addCoordsToRoute(center,true);
    });

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

    GEvent.addListener(map, "click", onClick);

    //]]>
    </script>
    <div style="font-size:x-small;" id="message"></div>
    <div style="font-size:x-small;" id="permalink"></div>
    <div style="font-size:x-small;" id="addroutetext"></div>
    <div id="wpt">
EOF
    for my $wpt (@$wpts) {
	my($x,$y,$name) = @$wpt;
	next if $name eq '';
	$html .= qq{<a href="#map" onclick="setwpt($x,$y);return true;">$name</a><br />\n};
    }
    $html .= <<EOF;
    </div>

<form name="googlemap" onsubmit='return checkSetCoordForm()' style="margin-top:1cm; border:1px solid black; padding:3px;">
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  Koordinatensystem:<br />
  <label><input type="radio" name="coordsystem" value="standard" @{[ $coordsystem eq 'standard' ? 'checked' : '' ]} /> BBBike</label><br />
  <label><input type="radio" name="coordsystem" value="polar" @{[ $coordsystem eq 'polar' ? 'checked' : '' ]} /> WGS84-Koordinaten (DDD)</label><br />
  <br />
  <label>Koordinate (x,y bzw. lon,lat): <input name="wpt_or_trk" size="15" /></label><br />
  <br />
  <button>Zeigen</button>
</form>

<form name="addroute" style="margin-top:0.5cm; border:1px solid black; padding:3px;" method="post" enctype="multipart/form-data">
  <label>Mit Maus-Doppelklicks eine Route erstellen <input type="checkbox" name="addroute"  /></label>
  <a href="javascript:deleteLastPoint()">Letzten Punkt löschen</a>
  <a href="javascript:resetRoute()">Route löschen</a>
</form>

<form name="upload" onsubmit='setZoomInUploadForm()' style="margin-top:0.5cm; border:1px solid black; padding:3px;" method="post" enctype="multipart/form-data">
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  Upload einer GPX-Datei: <input type="file" name="gpxfile" />
  <br />
  <button>Zeigen</button>
</form>

<table width="100%">
 <tr>
  <td colspan="3">
      <p class="ftr">
       <a id="bbbikemail" href="mailto:slaven\@rezic.de">E-Mail</a> |
       <a id="bbbikeurl" href="http://radzeit.herceg.de/cgi-bin/bbbike.cgi">BBBike</a> |
       <a href="/cgi-bin/mapserver_address.cgi?usemap=googlemaps">Adresssuche</a>
       | <a href="http://maps.google.com/maps?ll=52.515385,13.381004&spn=0.146083,0.229288&t=k">Google Maps</a>
      </p>
  </td>
 </tr>

</table>

  </body>
</html>
EOF
}

return 1 if caller;

my $o = BBBikeGooglemap->new;
$o->run;

=head1 NAME

bbbikegooglemap.cgi - show BBBike data through Google maps

=cut

# rsync -e "ssh -2" -a ~/src/bbbike/cgi/bbbikegooglemap.cgi root@www.radzeit.de:/var/www/domains/radzeit.de/www/cgi-bin/bbbikegooglemap2.cgi
