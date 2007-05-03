#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.cgi,v 1.45 2007/05/03 22:31:31 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005,2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeGooglemap;

use strict;
use FindBin;
use lib (grep { -d }
	 ("$FindBin::RealBin/..",
	  "$FindBin::RealBin/../lib",
	  # für Radzeit:
	  "$FindBin::RealBin/../BBBike",
	  "$FindBin::RealBin/../BBBike/lib",
	 )
	);
use CGI qw(:standard);
use CGI::Carp;
use URI;
use BBBikeCGIUtil qw();
use BBBikeVar;
use Karte;
use Karte::Polar;

sub new { bless {}, shift }

sub run {
    my($self) = @_;

    local $CGI::POST_MAX = 2_000_000;

    my @polylines_polar;
    my @wpt;

    my $coordsystem = param("coordsystem") || "bbbike";
    my $converter;
    if ($coordsystem eq 'polar') {
	$converter = \&polar_converter;
    } else { # bbbike or standard
	$converter = \&bbbike_converter;
    }

    if (param("wpt_or_trk")) {
	my $wpt_or_trk = trim(param("wpt_or_trk"));
	if ($wpt_or_trk =~ / /) {
	    param("coords", join("!",
				 param("coords"),
				 split(/ /, $wpt_or_trk))
		 );
	} else {
	    param("wpt", $wpt_or_trk);
	}
    }

    my $filename = param("gpxfile");
    if (defined $filename) {
	(my $ext = $filename) =~ s{^.*\.}{.};
	require Strassen::Core;
	require File::Temp;
	my $fh = upload("gpxfile");
	if (!$fh) {
	    $self->{errormessageupload} = "Upload-Datei fehlt!";
	} else {
	    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
						       SUFFIX => $ext);
	    while (<$fh>) {
		print $tmpfh $_;
	    }
	    close $fh;
	    close $tmpfh;

	    my $gpx = Strassen->new($tmpfile);
	    $gpx->init;
	    while (1) {
		my $r = $gpx->next;
		if (!$r || !UNIVERSAL::isa($r->[Strassen::COORDS()], "ARRAY")) {
		    warn "Parse error in line " . $gpx->pos . ", skipping...";
		    next;
		}
		last if !@{ $r->[Strassen::COORDS()] };
		if (@{ $r->[Strassen::COORDS()] } == 1) { # treat as waypoint
		    # XXX hack --- should append recognise self_or_default?
		    $CGI::Q->append(-name   => 'wpt',
				    -values => $r->[Strassen::NAME()] . "!" . $r->[Strassen::COORDS()][0]
				   );
		} else {
		    # XXX hack --- should append recognise self_or_default?
		    $CGI::Q->append(-name   => 'coords',
				    -values => [join "!", @{ $r->[Strassen::COORDS()] }],
				   );
		}
	    }
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

    my $autosel = param("autosel") || "";
    $self->{autosel} = $autosel && $autosel ne 'false' ? "true" : "false";

    my $maptype = param("maptype") || "";
    $self->{maptype} = ($maptype =~ /hybrid/i ? 'G_HYBRID_MAP' :
			$maptype =~ /normal/i ? 'G_NORMAL_MAP' :
			'G_SATELLITE_MAP');

    $self->{converter} = $converter;
    $self->{coordsystem} = $coordsystem;

    print header;
    print $self->get_html(\@polylines_polar, \@wpt, $zoom);
}

sub bbbike_converter {
    my($x,$y) = @_;
    local $^W; # avoid non-numeric warnings...
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

    my %google_api_keys =
	('www.radzeit.de'     => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hR1DE4tk8nUxq5ddnsWMNnWMRHPuxTzJuNOAmRUyOC19LbqHh-nYAhakg",
	 'slaven1.radzeit.de' => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hTS_eeuTgvlotSiRSnbEXbHuw72JhQv5zsHIwt9pt-xa1jQybMfG07nnw",
	 'bbbike.radzeit.de'  => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hS6wT240HZyk82lqsABWbmUCmE0QhQkWx8v-NluR6PNjW3O3dGEjh16GA",
	 'bbbike.dyndns.org'  => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hSLqR5A2UGypn5BXWnifa_ooUsHQRSCfjJjmO9rJsmHNGaXSFEFrCsW4A",
	 # Versehen, Host existiert nicht:
	 'slaven1.bbbike.de'  => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hRQAqip6zVbHiluFa7rPMSCpIxbfxQLz2YdzoN6O1jXFDkco3rJ_Ry2DA",
	);
    my $base = URI->new(BBBikeCGIUtil::my_url(CGI->new, -base => 1));
    my $fallback_host = "bbbike.radzeit.de";
    my $host = eval { $base->host } || $fallback_host;
    my $google_api_key = $google_api_keys{$host} || $google_api_keys{$fallback_host};

    my $bbbikeroot = "/BBBike";
    if ($host eq 'bbbike.dyndns.org') {
	$bbbikeroot = "/bbbike";
    }

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
  <head>
    <title>BBBike data presented with Googlemap</title>
    <link rel="stylesheet" type="text/css" href="$bbbikeroot/html/bbbike.css"><!-- XXX only for radzeit -->
    <link type="image/gif" rel="shortcut icon" href="$bbbikeroot/images/bbbike_google.gif"><!-- XXX only for radzeit -->
    <script src="http://maps.google.com/maps?file=api&v=2&key=$google_api_key" type="text/javascript"></script>
    <script src="$bbbikeroot/html/sprintf.js" type="text/javascript"></script>
    <style type="text/css"><!--
        .sml          { font-size:x-small; }
	#permalink    { color:red; }
	#addroutelink { color:blue; }
    --></style>
  </head>
  <body onunload="GUnload()">
    <div id="map" style="width: 100%; height: 500px"></div>
    <script type="text/javascript">
    //<![CDATA[

    var routeLinkLabel = "Link to route: ";
    var routeLabel = "Route: ";

    var addRoute = [];
    var addRouteOverlay;

    var startIcon = new GIcon(G_DEFAULT_ICON, "http://bbbike.radzeit.de/BBBike/images/flag2_bl_centered.png");
    startIcon.iconAnchor = new GPoint(10,10);
    var goalIcon = new GIcon(G_DEFAULT_ICON, "http://bbbike.radzeit.de/BBBike/images/flag_ziel_centered.png");
    goalIcon.iconAnchor = new GPoint(10,10);
    var currentPointMarker = null;

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

    function setwptAndMark(x,y) {
	var pt = new GPoint(x, y);
	map.recenterOrPanToLatLng(pt);
	if (currentPointMarker) {
	    map.removeOverlay(currentPointMarker);
	}
	currentPointMarker = new GMarker(pt);
	map.addOverlay(currentPointMarker);
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
	var rb = document.forms["mapmode"].elements["mapmode"];
	for (var i = 0; i < rb.length; i++) {
	    if (rb[i].checked) {
		return rb[i].value;
	    }
	}
	return "browse"; // fallback
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
	updateRoute();
    }

    function deleteLastPoint() {
	if (addRoute.length > 0) {
	    addRoute.length = addRoute.length-1;
	    updateRoute(); 
	}
    }

    function resetRoute() {
	addRoute = [];
	updateRoute();
    }

    function updateRoute() {
	updateRouteDiv(); 
	updateRouteOverlay();
	if ($self->{autosel}) {
	    updateRouteSel();
	}
    }

    function updateRouteDiv() {
	var addRouteText = "";
	var addRouteLink = "";
	for(var i = 0; i < addRoute.length; i++) {
	    if (i == 0) {
		addRouteText = routeLabel;
		addRouteLink = routeLinkLabel + "@{[ BBBikeCGIUtil::my_url(CGI->new(), -full => 1) ]}?zoom=" + map.getZoomLevel() + "&coordsystem=polar" + "&maptype=" + mapTypeToString() + "&wpt_or_trk=";
	    } else if (i > 0) {
		addRouteText += " ";
		addRouteLink += "+";
	    }
	    addRouteText += formatPoint(addRoute[i]);
	    addRouteLink += formatPoint(addRoute[i]);
	}

	document.getElementById("addroutelink").innerHTML = addRouteLink;
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

    function updateWptDiv(resultXml) {
	var polarElements = resultXml.documentElement.getElementsByTagName("LongLatPath")[0].getElementsByTagName("XY");
	var bbbikeElements = resultXml.documentElement.getElementsByTagName("Path")[0].getElementsByTagName("XY");
	var bbbike2polar = {};
	for(var i = 0; i < polarElements.length; i++) {
	    bbbike2polar[bbbikeElements[i].textContent] = polarElements[i].textContent;
	}
	var pointElements = resultXml.documentElement.getElementsByTagName("Route")[0].getElementsByTagName("Point");
	var wptHTML = "";
	for(var i = 0; i < pointElements.length; i++) {
	    var pe = pointElements[i];
	    var bbbikeCoord = pe.getElementsByTagName("Coord")[0].textContent;
	    var polarCoord = bbbike2polar[bbbikeCoord];
	    if (polarCoord) {
		var xy = polarCoord.split(",");
		wptHTML += "<a href='#map' onclick='setwptAndMark(" + xy[0] + "," + xy[1] + ");return true;'>" + pe.getElementsByTagName("DistString")[0].textContent + " " + pe.getElementsByTagName("DirectionString")[0].textContent + " " + pe.getElementsByTagName("Strname")[0].textContent + "</a><br />\\n";
	    }
	}
	document.getElementById("wpt").innerHTML = wptHTML;
    }

    function updateRouteSel() {
	return; // XXX the selection code does not really work

	var routeDiv = document.getElementById("addroutetext").firstChild;
	var range = document.createRange();
	range.setStart(routeDiv, routeLabel.length);
	range.setEnd(routeDiv, routeDiv.length);
	var s = window.getSelection();
	s.removeAllRanges();
	s.addRange(range);
    }

    function mapTypeToString() {
	var mapType;
	if (map.getCurrentMapType() == G_NORMAL_MAP) {
	    mapType = "normal";
	} else if (map.getCurrentMapType() == G_HYBRID_MAP) {
	    mapType = "hybrid";
	} else {
	    mapType = "satellite";
	}
	return mapType;
    }

    function showLink(point, message) {
	var mapType = mapTypeToString();
        var latLngStr = message + "@{[ BBBikeCGIUtil::my_url(CGI->new(), -full => 1) ]}?zoom=" + map.getZoomLevel() + "&wpt=" + formatPoint(point) + "&coordsystem=polar" + "&maptype=" + mapType;
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
	    "http://@{[ $host ]}/cgi-bin/bbbike.cgi?startpolar=" + startPoint.x + "x" + startPoint.y + "&zielpolar=" + goalPoint.x + "x" + goalPoint.y + "&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=;output_as=xml;referer=bbbikegooglemap";
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
	    for (var i = 0; i < pointElements.length; i++) {
	    	var xy = pointElements[i].textContent.split(",");
		if (i == 0) setwpt(xy[0],xy[1]);
	    	var p = new GPoint(xy[0],xy[1]);
	    	addRoute[addRoute.length] = p;
            }
	    //updateRouteDiv();
	    updateRouteOverlay();
	    updateWptDiv(xml);
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
	    startOverlay = new GMarker(startPoint, startIcon);
	    map.addOverlay(startOverlay);
	    searchStage = 1;
	} else if (searchStage == 1) { // set goal
	    goalPoint = point;
	    goalOverlay = new GMarker(goalPoint, goalIcon);
	    map.addOverlay(goalOverlay);
	    searchStage = 0;
	    searchRoute(startPoint, goalPoint);
	}
    }

    if (GBrowserIsCompatible() ) {
        var map = new GMap(document.getElementById("map"));
        map.addControl(new GLargeMapControl());
        map.addControl(new GMapTypeControl());
        map.addControl(new GOverviewMapControl ());
 	map.setMapType($self->{maptype});
        map.centerAndZoom(new GPoint($centerx, $centery), $zoom);
    } else {
        document.getElementById("map").innerHTML = '<p class="large-error">Sorry, your browser is not supported by <a href="http://maps.google.com/support">Google Maps</a></p>';
    }

    GEvent.addListener(map, "moveend", function() {
        var center = map.getCenterLatLng();
	showCoords(center, 'Center of map: ');
	showLink(center, 'Link to map center: ');
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
	#my $html_name = escapeHTML($name);
	my $html_name = hrefify($name);
	$html .= <<EOF;
    var point = new GPoint($x,$y);
    var marker = createMarker(point, '$html_name');
    map.addOverlay(marker);
EOF
    }

    $html .= <<EOF;

    GEvent.addListener(map, "click", onClick);

    //]]>
    </script>
    <noscript>
        <p>You must enable JavaScript and CSS to run this application!</p>
    </noscript>
    <div class="sml" id="message"></div>
    <div class="sml" id="permalink"></div>
    <div class="sml" id="addroutelink"></div>
    <div class="sml" id="addroutetext"></div>
    <div class="sml" id="wpt">
EOF
    for my $wpt (@$wpts) {
	my($x,$y,$name) = @$wpt;
	next if $name eq '';
	$html .= qq{<a href="#map" onclick="setwpt($x,$y);return true;">$name</a><br />\n};
    }
    $html .= <<EOF;
    </div>

<div style="float:left; width:45%; margin-top:0.5cm; ">

<form name="mapmode" style="border:1px solid black; padding:3px; " method="get">
 <table border="0">
   <tr style="vertical-align:top;">
    <td><input id="mapmode_browse"
               type="radio" name="mapmode" value="browse" checked /></td>
    <td><label for="mapmode_browse">Scrollen/Bewegen/Zoomen</label></td>
   </tr>
   <tr style="vertical-align:top;">
    <td><input id="mapmode_search"
               type="radio" name="mapmode" value="search" /></td>
    <td><label for="mapmode_search">Mit Maus-Klicks Start- und Zielpunkt festlegen</label></td>
   </tr>
   <tr style="vertical-align:top;">
    <td><input id="mapmode_addroute"
               type="radio" name="mapmode" value="addroute" /></td>
    <td><label for="mapmode_addroute">Mit Maus-Doppelklicks eine Route erstellen</label><br/>
        <a href="javascript:deleteLastPoint()">Letzten Punkt löschen</a>
        <a href="javascript:resetRoute()">Route löschen</a></td>
   </tr>
 </table>
</form>

<form name="upload" onsubmit='setZoomInUploadForm()' style="margin-top:0.3cm; border:1px solid black; padding:3px; " method="post" enctype="multipart/form-data">
EOF
    if ($self->{errormessageupload}) {
	$html .= <<EOF;
  <div class="error">@{[ escapeHTML($self->{errormessageupload}) ]}</div>
EOF
    }
    $html .= <<EOF;
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  Upload einer GPX-Datei: <input type="file" name="gpxfile" />
  <br />
  <button>Zeigen</button>
</form>

</div>

<form name="googlemap" onsubmit='return checkSetCoordForm()' style="margin-top:0.5cm; margin-left:10px; border:1px solid black; padding:3px; width:45%; float:left;">
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  <input type="hidden" name="autosel" value="@{[ $self->{autosel} ]}" />
  <input type="hidden" name="maptype" value="@{[ $self->{maptype} ]}" />
  Koordinatensystem:<br />
  <label><input type="radio" name="coordsystem" value="bbbike" @{[ $coordsystem eq 'bbbike' ? 'checked' : '' ]} /> BBBike</label><br />
  <label><input type="radio" name="coordsystem" value="polar" @{[ $coordsystem eq 'polar' ? 'checked' : '' ]} /> WGS84-Koordinaten (DDD)</label><br />
  <br />
  <label>Koordinate(n) (x,y bzw. lon,lat): <input name="wpt_or_trk" size="15" /></label><br />
  <br />
  <button>Zeigen</button>
</form>

<table width="100%" style="clear:left;">
 <tr>
  <td colspan="3">
      <p class="ftr">
       <a id="bbbikemail" href="mailto:$BBBike::EMAIL">E-Mail</a> |
       <a id="bbbikeurl" href="$BBBike::BBBIKE_DIRECT_WWW">BBBike</a> |
       <a href="/cgi-bin/mapserver_address.cgi?usemap=googlemaps">Adresssuche</a>
       | <a href="http://maps.google.com/maps?ll=52.515385,13.381004&amp;spn=0.146083,0.229288&amp;t=k">Google Maps</a>
      </p>
  </td>
 </tr>

</table>

  </body>
</html>
EOF
    $html;
}

# REPO BEGIN
# REPO NAME hrefify /home/e/eserte/work/srezic-repository 
# REPO MD5 10b14ef52873d9c6b53d959919cbcf54

=head2 hrefify($text)

Create <a href="...">...</a> tags around things which look like URLs
and HTML-escape everything else.

=cut

sub hrefify {
    my($text) = @_;

    require HTML::Entities;
    my $enc = sub {
	HTML::Entities::encode_entities_numeric($_[0], q{<>&"'\\\\\177-\x{fffd}});
    };

    my $lastpos;
    my $ret = "";
    while($text =~ m{(.*)((?:https?|ftp)://\S+)}g) {
	my($plain, $href) = ($1, $2);
	$ret .= $enc->($plain);
	$ret .= qq{<a href="} . $enc->($href) . qq{">} . $enc->($href) . qq{</a>};
	$lastpos = pos($text);
    }
    if (!defined $lastpos) {
	$ret .= $enc->($text);
    } else {
	$ret .= $enc->(substr($text, $lastpos));
    }
    $ret;
}
# REPO END

# REPO BEGIN
# REPO NAME trim /home/e/eserte/work/srezic-repository 
# REPO MD5 ab2f7dfb13418299d79662fba10590a1

=head2 trim($string)

=for category Text

Trim starting and leading white space and squeezes white space to a
single space.

=cut

sub trim ($) {
    my $s = shift;
    return $s if !defined $s;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    $s =~ s/\s+/ /;
    $s;
}
# REPO END

return 1 if ((caller() and (caller())[0] ne 'Apache::Registry')
	     or keys %Devel::Trace::); # XXX Tracer bug

my $o = BBBikeGooglemap->new;
$o->run;

=head1 NAME

bbbikegooglemap.cgi - show BBBike data through Google maps

=cut

# rsync -e "ssh -2 -p 5022" -a ~/src/bbbike/cgi/bbbikegooglemap.cgi root@bbbike.radzeit.de:/var/www/domains/radzeit.de/www/cgi-bin/bbbikegooglemap2.cgi
