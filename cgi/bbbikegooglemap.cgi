#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.cgi,v 2.36 2009/04/04 11:14:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005,2006,2007,2008 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
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
use File::Basename qw(dirname);
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
    my @polylines_polar_feeble;
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

	    my $gpx = Strassen->new($tmpfile, name => "Uploaded GPX file");
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

    for my $def (['coords',    \@polylines_polar],
		 ['oldcoords', \@polylines_polar_feeble],
		) {
	my($cgiparam, $polylines_ref) = @$def;

	for my $coords (param($cgiparam)) {
	    my(@coords) = split /[!;]/, $coords;
	    my(@coords_polar) = map {
		my($x,$y) = split /,/, $_;
		join ",", $converter->($x,$y);
	    } @coords;
	    push @$polylines_ref, \@coords_polar;
	}
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

    my $mapmode = param("mapmode") || "";
    ($self->{initial_mapmode}) = $mapmode =~ m{^(search|addroute|browse|addwpt)$};
    $self->{initial_mapmode} ||= "";

    my $center = param("center") || "";

    $self->{converter} = $converter;
    $self->{coordsystem} = $coordsystem;

    print header;
    print $self->get_html(\@polylines_polar, \@polylines_polar_feeble, \@wpt, $zoom, $center);
}

sub bbbike_converter {
    my($x,$y) = @_;
    local $^W; # avoid non-numeric warnings...
    $Karte::Polar::obj->standard2map($x,$y);
}

sub polar_converter { @_[0,1] }

sub get_html {
    my($self, $paths_polar, $feeble_paths_polar, $wpts, $zoom, $center) = @_;

    my $converter = $self->{converter};
    my $coordsystem = $self->{coordsystem};

    my($centerx,$centery);
    if ($center) {
	($centerx,$centery) = map { sprintf "%.5f", $_ } split /,/, $center;
    } elsif ($paths_polar && @$paths_polar) {
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
	 'bbbike2.radzeit.de' => "ABQIAAAAJEpwLJEnjBq8azKO6edvZhTVOBsDIw_K6AwUqiwPnLrAK56XrRT9Hcfdh86z8Tt62SrscN1BOkEPUg",
	 'bbbike.dyndns.org'  => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hSLqR5A2UGypn5BXWnifa_ooUsHQRSCfjJjmO9rJsmHNGaXSFEFrCsW4A",
	 # temporary
	 'srand.de'	      => "ABQIAAAAJEpwLJEnjBq8azKO6edvZhSaoDeIPWe_eenmgYXVZinATdYRPhRaxtajxwqk10x-j6wAGQPTERtEEQ",
	 'www.srand.de'	      => "ABQIAAAAJEpwLJEnjBq8azKO6edvZhQcuFdDaAeyxk8HEJsg2LO6FXA-0BSfij-GORz-Y3oODCTRrbrFTCsdpw",
	 # Versehen, Host existiert nicht:
	 'slaven1.bbbike.de'  => "ABQIAAAAidl4U46XIm-bi0ECbPGe5hRQAqip6zVbHiluFa7rPMSCpIxbfxQLz2YdzoN6O1jXFDkco3rJ_Ry2DA",
	 '78.47.225.30'	      => "ABQIAAAACNG-XP3VVgdpYda6EwQUyhTTdIcL8tflEzX084lXqj663ODsaRSCKugGasYn0ZdJkWoEtD-oJeRhNw",
	 'bbbike.de'	      => 'ABQIAAAACNG-XP3VVgdpYda6EwQUyhRfQt6AwvKXAVZ7ZsvglWYeC-xX5BROlXoba_KenDFQUtSEB_RJPUVetw',
	);
    my $full = URI->new(BBBikeCGIUtil::my_url(CGI->new, -full => 1));
    my $fallback_host = "bbbike.de";
    my $host = eval { $full->host } || $fallback_host;
    my $google_api_key = $google_api_keys{$host} || $google_api_keys{$fallback_host};
    my $cgi_reldir = dirname($full->path);
    my $is_beta = $full =~ m{bbikegooglemap2.cgi};

    my $bbbikeroot = "/BBBike";
    my $get_public_link = sub {
	BBBikeCGIUtil::my_url(CGI->new(), -full => 1);
    };
    if ($host eq 'bbbike.dyndns.org') {
	$bbbikeroot = "/bbbike";
    } elsif ($host =~ m{srand\.de}) {
	$bbbikeroot = dirname(dirname($full->path));
    } elsif ($host eq 'localhost') {
	$bbbikeroot = "/bbbike";
	$get_public_link = sub {
	    my $link = BBBikeCGIUtil::my_url(CGI->new(), -full => 1);
	    $link =~ s{localhost$bbbikeroot/cgi}{bbbike.de/cgi-bin};
	    $link;
	};
    }

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
  <head>
    <title>BBBike data presented with Googlemap</title>
    <link rel="stylesheet" type="text/css" href="$bbbikeroot/html/bbbike.css"><!-- XXX only for radzeit -->
    <link type="image/gif" rel="shortcut icon" href="$bbbikeroot/images/bbbike_google.gif"><!-- XXX only for radzeit -->
<!--    <script src="http://maps.google.com/maps?file=api&v=2&key=$google_api_key" type="text/javascript"></script>-->
    <script src="http://maps.google.com/jsapi?key=$google_api_key" type="text/javascript"></script>
    <script type="text/javascript">
      google.load("maps", "2");
    </script>
    <script src="$bbbikeroot/html/sprintf.js" type="text/javascript"></script>
    <script src="$bbbikeroot/html/bbbike_util.js" type="text/javascript"></script>
    <style type="text/css"><!--
        .sml          { font-size:x-small; }
	.rght	      { text-align:right; }
	#permalink    { color:red; }
	#addroutelink { color:blue; }
	.boxed	      { border:1px solid black; padding:3px; }
	#commentlink  { background-color:yellow; }
	body.nonWaitMode * { }
	body.waitMode *    { cursor:wait; }
    --></style>
  </head>
  <body onload="init()" onunload="GUnload()" class="nonWaitMode">
    <div id="map" style="width: 100%; height: 500px"></div>
    <script type="text/javascript">
    //<![CDATA[

    var routeLinkLabel = "Link to route: ";
    var routeLabel = "Route: ";
    var commonSearchParams = "&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=;output_as=xml;referer=bbbikegooglemap";
    var routePostParam = "";

    var addRoute = [];
    var undoRoute = [];
    var addRouteOverlay;
    var addRouteOverlay2;

    var userWpts = [];

    var searchStage = 0;

    var isGecko = navigator && navigator.product == "Gecko" ? true : false;
    var dragCursor = isGecko ? '-moz-grab' : 'url("$bbbikeroot/images/moz_grab.gif"), auto';

    var startIcon = new GIcon(G_DEFAULT_ICON, "$bbbikeroot/images/flag2_bl_centered.png");
    startIcon.iconAnchor = new GPoint(16,16);
    startIcon.iconSize = new GSize(32,32);
    var goalIcon = new GIcon(G_DEFAULT_ICON, "$bbbikeroot/images/flag_ziel_centered.png");
    goalIcon.iconAnchor = new GPoint(16,16);
    goalIcon.iconSize = new GSize(32,32);
    var currentPointMarker = null;
    var currentTempBlockingMarkers = [];

    function createMarker(point, html_name) {
	var marker = new GMarker(point);
        var html = "<b>" + html_name + "</b>";
	GEvent.addListener(marker, "click", function() {
	    marker.openInfoWindowHtml(html);
	});
	return marker;
    }

    function removeTempBlockingMarkers() {
	for(var i = 0; i < currentTempBlockingMarkers.length; i++) {
	    map.removeOverlay(currentTempBlockingMarkers[i]);
	}
	currentTempBlockingMarkers = [];
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

    function currentModeChange() {
        var currentMode = getCurrentMode();
	var dragObj = map.getDragObject();
        if (currentMode == "search") {
	    if (searchStage == 0) {
		dragObj.setDraggableCursor('url("$bbbikeroot/images/start_ptr.png"), url("$bbbikeroot/images/flag2_bl.png"), ' + dragCursor);
	    } else {
		dragObj.setDraggableCursor('url("$bbbikeroot/images/ziel_ptr.png"), url("$bbbikeroot/images/flag_ziel.png"), ' + dragCursor);
	    }
        } else {
	    if (currentMode == "addroute" || currentMode == "addwpt") {
		dragObj.setDraggableCursor("default");
	    } else {
	        dragObj.setDraggableCursor(dragCursor);
	    }
	    document.getElementById("wpt").innerHTML = "";
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
	updateRoute();
    }

    function deleteLastPoint() {
	if (addRoute.length > 0) {
	    addRoute.length = addRoute.length-1;
	    updateRoute(); 
	}
    }

    function resetRoute() {
	undoRoute = addRoute;
	addRoute = [];
	updateRoute();
	removeTempBlockingMarkers();
    }

    function doUndoRoute() {
	addRoute = undoRoute;
	undoRoute = [];
	updateRoute();
	removeTempBlockingMarkers();
    }

    function resetOrUndoRoute() {
        if (addRoute.length == 0 && undoRoute.length != 0) {
	    doUndoRoute();
	} else {
	    resetRoute();
	}
    }

    function setDeleteRouteLabel() {
	var routeDelLink = document.getElementById("routedellink");
	if (addRoute.length == 0 && undoRoute.length != 0) {
	    routeDelLink.innerHTML = "Route wiederherstellen";
	} else {
	    routeDelLink.innerHTML = "Route löschen"; // see also HTML label!
	}
    }

    function updateRoute() {
	updateRouteDiv(); 
	updateRouteOverlay();
	if ($self->{autosel}) {
	    updateRouteSel();
	}
	setDeleteRouteLabel();
    }

    function updateRouteDiv() {
	var addRouteText = "";
	var addRouteLink = "";
	routePostParam = "";
	for(var i = 0; i < addRoute.length; i++) {
	    if (i == 0) {
		addRouteText = routeLabel;
		addRouteLink = routeLinkLabel + "@{[ $get_public_link->() ]}?zoom=" + map.getZoomLevel() + "&coordsystem=polar" + "&maptype=" + mapTypeToString() + "&wpt_or_trk=";
	    } else if (i > 0) {
		addRouteText += " ";
		addRouteLink += "+";
		routePostParam += " ";
	    }
	    var formattedPoint = formatPoint(addRoute[i]);
	    addRouteText += formattedPoint;
	    addRouteLink += formattedPoint;
	    routePostParam += formattedPoint;
	}

	document.getElementById("addroutelink").innerHTML = addRouteLink;
        document.getElementById("addroutetext").innerHTML = addRouteText;

	updateCommentlinkVisibility();
    }

    function updateCommentlinkVisibility() {
	// XXX To be precise, this should also check if any of the userWpts
	// XXX is non-null.
	if (addRoute.length > 0 || userWpts.length > 0) {
	  document.getElementById("commentlink").style.display = "block";
	} else {
	  document.getElementById("commentlink").style.display = "none";
	}

	if (userWpts.length > 0) {
	  document.getElementById("hasuserwpts").style.visibility = "inherit";
	} else {
	  document.getElementById("hasuserwpts").style.visibility = "hidden";
	}
    }

    function updateRouteOverlay() {
	if (addRouteOverlay) {
	    map.removeOverlay(addRouteOverlay);
	    addRouteOverlay = null;
	}
	if (!addRoute.length) {
	   return;
	}
	if (addRoute.length == 1) {
	    addRouteOverlay = new GMarker(addRoute[0]);
	} else {
	    var opts = {}; // GPolylineOptions
	    opts.clickable = false;
	    addRouteOverlay = new GPolyline(addRoute, null, null, null, opts);
	}
	map.addOverlay(addRouteOverlay);

	if (false) { // experiment: draw geodesic lines
	    if (addRouteOverlay2) {
		map.removeOverlay(addRouteOverlay2);
		addRouteOverlay2 = null;
	    }
	    var opts = {}; // GPolylineOptions
	    opts.geodesic = true;
	    addRouteOverlay2 = new GPolyline(addRoute, '#ff0000', null, null, opts);
	    map.addOverlay(addRouteOverlay2);
	}
    }

    function updateTempBlockings(resultXml) {
	removeTempBlockingMarkers()
        var affectingBlockings = resultXml.documentElement.getElementsByTagName("AffectingBlocking");
	if (affectingBlockings && affectingBlockings.length) {
            for(var i = 0; i < affectingBlockings.length; i++) {
		var affectingBlocking = affectingBlockings[i];
	        var llhs = affectingBlocking.getElementsByTagName("LongLatHop")
		if (llhs && llhs.length) {
		    var xy = llhs[0].getElementsByTagName("XY")[0].textContent.split(",");
		    var text = "";
		    var textElements = affectingBlocking.getElementsByTagName("Text");
		    if (textElements && textElements.length) {
			text = textElements[0].textContent;
		    }
		    var point = new GPoint(xy[0], xy[1]);
	    	    var marker = createMarker(point, text);
		    map.addOverlay(marker);
		    currentTempBlockingMarkers[currentTempBlockingMarkers.length] = marker;
		}
	    }
        }
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
	wptHTML += "Gesamtlänge: " + pointElements[pointElements.length-1].getElementsByTagName("TotalDistString")[0].textContent + "<br />\\n";
	wptHTML += "<a href=\\"javascript:wayBack()\\">Rückweg</a><br />\\n";
	document.getElementById("wpt").innerHTML = wptHTML;
    }

    function updateRouteSel() {
	return; // XXX the selection code does not really work
	// See http://use.perl.org/~grink/journal/37262?from=rss for alternatives.
	// Keywords: clipboard selection copying security reasons

	var routeDiv = document.getElementById("addroutetext").firstChild;
	var range = document.createRange();
	range.setStart(routeDiv, routeLabel.length);
	range.setEnd(routeDiv, routeDiv.length);
	var s = window.getSelection();
	s.removeAllRanges();
	s.addRange(range);
    }

    function addUserWpt(point) {
	var userWpt = { index:userWpts.length };
	var marker = new GMarker(point);
	var preHtml = '<form>Kommentar:<br/><textarea id="userWptComment" cols="25" rows=4">';
	var postHtml = '</textarea></form><br/><a href="javascript:deleteUserWpt(' + userWpt.index + ')">Waypoint löschen</a>';
	var html = preHtml + postHtml;
	var htmlElem = document.createElement("div");
	htmlElem.innerHTML = html;
	var textarea = htmlElem.getElementsByTagName("textarea")[0];
	userWpt.textarea = textarea;
	marker.bindInfoWindow(htmlElem);
	map.addOverlay(marker);
	userWpt.overlay = marker;
	userWpt.latLng = marker.getLatLng();
	userWpts[userWpts.length] = userWpt;
	updateCommentlinkVisibility();
    }

    function deleteUserWpt(i) {
        var userWpt = userWpts[i];
	if (userWpt) {
	    var overlay = userWpt.overlay;
	    if (overlay) {
	        map.removeOverlay(overlay);
	        userWpt.overlay = null;
	    }
            userWpts[i] = null;
	}
	// XXX should call updateCommentlinkVisibility()
	// XXX once it can handle single deleted waypoints
    }

    function deleteAllUserWpts() {
	for(var i in userWpts) {
	    deleteUserWpt(i);
	}
	userWpts = [];
	updateCommentlinkVisibility();
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
        var latLngStr = message + "@{[ $get_public_link->() ]}?zoom=" + map.getZoomLevel() + "&wpt=" + formatPoint(point) + "&coordsystem=polar" + "&maptype=" + mapType;
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

    function waitMode() {
	document.getElementsByTagName("body")[0].className = "waitMode";
    }

    function nonWaitMode() {
        document.getElementsByTagName("body")[0].className = "nonWaitMode";
    }

    function searchRoute(startPoint, goalPoint) {
	var requestLine =
	    "@{[ $cgi_reldir ]}/bbbike.cgi?startpolar=" + startPoint.x + "x" + startPoint.y + "&zielpolar=" + goalPoint.x + "x" + goalPoint.y + commonSearchParams;
	var routeRequest = GXmlHttp.create();
	routeRequest.open("GET", requestLine, true);
	routeRequest.onreadystatechange = function() {
	    showRouteResult(routeRequest);
	};
	waitMode();
	routeRequest.send(null);
    }

    function showRouteResult(request) {
	if (request.readyState == 4) {
	    nonWaitMode();
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
	    updateTempBlockings(xml);
	    updateWptDiv(xml);
	    setDeleteRouteLabel();
	}
    }

    var startOverlay = null;
    var startPoint = null;
    var goalOverlay = null;
    var goalPoint = null;

    function onClick(overlay, point) {
	var currentMode = getCurrentMode();
	if (currentMode == "addroute") {
	    showCoords(point, 'Center of map: ');
	    showLink(point, 'Link to map center: ');
	    addCoordsToRoute(point,true);
	    // XXX should the point also be centered or not?
	    return;
	} else if (currentMode == "addwpt") {
	    addUserWpt(point);
	    return;
	} else if (currentMode != "search") {
	    return;
	}
	if (searchStage == 0) { // set start
	    removeGoalMarker();
	    setStartMarker(point);
	    searchStage = 1;
	    currentModeChange();
	} else if (searchStage == 1) { // set goal
	    setGoalMarker(point);
	    searchStage = 0;
	    currentModeChange();
	    searchRoute(startPoint, goalPoint);
	}
    }

    function wayBack() {
        var tmp = startPoint;
	startPoint = goalPoint;
	goalPoint = tmp;
	tmp = startOverlay;
	startOverlay = goalOverlay;
	goalOverlay = tmp;
        setStartMarker(startPoint);
	setGoalMarker(goalPoint);
	searchRoute(startPoint, goalPoint);
    }

    function setStartMarker(point) {
        if (startOverlay) {
	    map.removeOverlay(startOverlay);
	    startOverlay = null;
	}
	startPoint = point;
	var startOpts = {icon:startIcon, clickable:false}; // GMarkerOptions
	startOverlay = new GMarker(startPoint, startOpts);
	map.addOverlay(startOverlay);
    }

    function setGoalMarker(point) {
	removeGoalMarker();
	goalPoint = point;
	var goalOpts = {icon:goalIcon, clickable:false}; // GMarkerOptions
	goalOverlay = new GMarker(goalPoint, goalOpts);
	map.addOverlay(goalOverlay);
    }

    function removeGoalMarker() {
	if (goalOverlay) {
	    map.removeOverlay(goalOverlay);
	    goalOverlay = null;
	}
    }

    function init() {
        var frm = document.forms.commentform;
        get_and_set_email_author_from_cookie(frm);
        var initial_mapmode = "$self->{initial_mapmode}";
	if (initial_mapmode) {
	    var elem = document.getElementById("mapmode_" + initial_mapmode);
	    if (elem) {
		elem.checked = true;
		currentModeChange();
	    }
	}
    }

    function send_via_post() {
        var http = GXmlHttp.create(); // new XMLHttpRequest();
        var frm = document.forms.commentform;
        http.open('POST', "@{[ $cgi_reldir ]}/mapserver_comment.cgi", false);
        http.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        var comment = frm.comment.value;
	var postContent = "author="+encodeURIComponent(frm.author.value)+"&"+
                          "email="+encodeURIComponent(frm.email.value)+"&"+
      	                  "comment="+encodeURIComponent(comment)+"&"+
			  "routelink="+encodeURIComponent(document.getElementById("addroutelink").innerHTML)+"&"+
      	                  "encoding=utf-8";
	for(var u_i in userWpts) {
	    var userWpt = userWpts[u_i];
	    if (userWpt) {
		var wptComment = "";
		if (userWpt.textarea) {
		    wptComment = userWpt.textarea.value;
		    wptComment = wptComment.replace(/!/, "."); // XXX hackish...
		}
		postContent += "&" + "wpt." + u_i + "=" + encodeURIComponent(wptComment + "!" + userWpt.latLng.lng() + "," + userWpt.latLng.lat());
	    }
	}
	if (routePostParam != "") {
	    postContent += "&" + "route=" + encodeURIComponent(routePostParam);
	}
        http.send(postContent);
        var strResult=http.responseText;
        if (http.status != 200) {
          strResult = "Die Übertragung ist mit dem Fehlercode <" + http.status + "> fehlgeschlagen.\\n\\n" + strResult;
        }
        var answerBoxDiv = document.getElementById("answerbox");
        var answerDiv = document.getElementById("answer");
        answerBoxDiv.style.visibility = "visible";
        answerDiv.innerHTML=strResult;
	close_commentform();
    }
  
    function close_answerbox() {
        var answerDiv = document.getElementById("answer");
        var answerBoxDiv = document.getElementById("answerbox");
        answerBoxDiv.style.visibility = "hidden";
        answerDiv.innerHTML = "";
    }

    function close_commentform() {
        var frm = document.forms.commentform;
        frm.style.visibility = "hidden";
    }

    function show_comment() {
	close_answerbox();
        var commentformDiv = document.getElementById("commentform");
        commentformDiv.style.visibility = "visible";
    }

    function doGeocode() {
        var address = document.geocode.geocodeAddress.value;
        if (address == "") {
            alert("Bitte Adresse angeben");
            return false;
        }
	var geocoder = new GClientGeocoder();
	geocoder.setViewport(map.getBounds());
	geocoder.setBaseCountryCode("de");
	waitMode();
	geocoder.getLatLng(address, geocodeResult);
        return false;
    }

    function geocodeResult(point) {
	nonWaitMode();
	if (!point) {
	    alert("Adresse nicht gefunden");
	} else {
	    setwptAndMark(point.x, point.y);
	}
    }

    if (GBrowserIsCompatible() ) {
        var map = new GMap(document.getElementById("map"));
	map.disableDoubleClickZoom();
        map.addControl(new GLargeMapControl());
        map.addControl(new GMapTypeControl());
        map.addControl(new GOverviewMapControl ());
 	map.setMapType($self->{maptype});
        map.centerAndZoom(new GPoint($centerx, $centery), $zoom);
	new GKeyboardHandler(map);
    } else {
        document.getElementById("map").innerHTML = '<p class="large-error">Sorry, your browser is not supported by <a href="http://maps.google.com/support">Google Maps</a></p>';
    }

    GEvent.addListener(map, "moveend", function() {
        var center = map.getCenterLatLng();
	showCoords(center, 'Center of map: ');
	showLink(center, 'Link to map center: ');
    });

EOF
    for my $def ([$feeble_paths_polar, '#ff00ff', 5,  0.4],
		 [$paths_polar,        '#ff0000', 10, undef],
		) {
	my($paths_polar, $color, $width, $opacity) = @$def;

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
	    $route_js_code .= qq{], "$color", $width};
	    if (defined $opacity) {
		$route_js_code .= qq{, $opacity};
	    }
	    $route_js_code .= qq{);};

	    $html .= <<EOF;
$route_js_code
    map.addOverlay(route);
EOF
	}
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

<div id="commentlink" class="boxed" style="display:none;">
  <a href="#" onclick="show_comment(); return false;">Kommentar zu Route und Waypoints senden</a>
</div>

<div style="float:left; width:45%; margin-top:0.5cm; ">

<form name="mapmode" class="boxed" method="get">
 <table border="0">
   <tr style="vertical-align:top;">
    <td><input onchange="currentModeChange()" 
	       id="mapmode_browse"
               type="radio" name="mapmode" value="browse" checked /></td>
    <td><label for="mapmode_browse">Scrollen/Bewegen/Zoomen</label></td>
   </tr>
   <tr style="vertical-align:top;">
    <td><input onchange="currentModeChange()" 
	       id="mapmode_search"
               type="radio" name="mapmode" value="search" /></td>
    <td><label for="mapmode_search">Mit Mausklicks Start- und Zielpunkt festlegen</label></td>
   </tr>
   <tr style="vertical-align:top;">
    <td><input onchange="currentModeChange()" 
	       id="mapmode_addroute"
               type="radio" name="mapmode" value="addroute" /></td>
    <td><label for="mapmode_addroute">Mit Maus<span style="color:red;">klicks</span> eine Route erstellen</label><br/><!-- XXX remove colored "klicks" some time -->
        <a href="javascript:deleteLastPoint()">Letzten Punkt löschen</a>
        <a href="javascript:resetOrUndoRoute()" id="routedellink">Route löschen</a></td>
   </tr>
EOF
    if ($is_beta) {
	$html .= <<EOF;
   <tr style="vertical-align:top;">
    <td><input onchange="currentModeChange()" 
	       id="mapmode_addwpt"
               type="radio" name="mapmode" value="addwpt" /></td>
    <td><label for="mapmode_addwpt">Waypoints erstellen</label><br/>
        <a href="javascript:deleteAllUserWpts()">Alle Waypoints löschen</a></td>
   </tr>
EOF
    }
    $html .= <<EOF;
 </table>
</form>

<form name="upload" onsubmit='setZoomInUploadForm()' class="boxed" style="margin-top:0.3cm; " method="post" enctype="multipart/form-data">
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

<form name="geocode" onsubmit='return doGeocode()' class="boxed" style="margin-top:0.5cm; margin-left:10px; width:45%; float:left;">
  <table style="width:100%;">
    <colgroup><col width="0*" /><col width="1*" /><col width="0*" /></colgroup>
    <tr>
      <td>Adresse:</td>
<!-- first width is needed for firefox, 2nd for seamonkey -->
      <td style="width:100%;"><input style="width:100%;" name="geocodeAddress" /></td>
      <td><button>Zeigen</button></td>
    </tr>
  </table>
</form>
 
<form name="googlemap" onsubmit='return checkSetCoordForm()' class="boxed" style="margin-top:0.3cm; margin-left:10px; width:45%; float:left;">
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  <input type="hidden" name="autosel" value="@{[ $self->{autosel} ]}" />
  <input type="hidden" name="maptype" value="@{[ $self->{maptype} ]}" />
  <label>Koordinate(n) (x,y bzw. lon,lat): <input name="wpt_or_trk" size="17" /></label>
  <button>Zeigen</button>
  <br />
  <div class="sml">
    Koordinatensystem:<br />
    <label><input type="radio" name="coordsystem" value="polar" @{[ $coordsystem eq 'polar' ? 'checked' : '' ]} /> WGS84-Koordinaten (DDD)</label>
    <label><input type="radio" name="coordsystem" value="bbbike" @{[ $coordsystem eq 'bbbike' ? 'checked' : '' ]} /> BBBike</label>
  </div>
  
</form>

<form id="commentform" style="position:absolute; top:20px; left: 20px; border:1px solid black; padding:4px; background:white; visibility:hidden;">
  <table>
    <tr><td>Kommentar zur Route:</td><td> <textarea cols="40" rows="4" name="comment"></textarea></td></tr>
    <tr id="hasuserwpts" style="visibility:hidden;"><td colspan="2">(Kommentare für Waypoints werden angehängt)</td></tr>
    <tr><td>Dein Name:</td><td><input name="author"></td></tr>
    <tr><td>Deine E-Mail:</td><td> <input name="email"></td></tr>
    <tr><td></td><td><a href="#" onclick="send_via_post(); return false;">Senden</a>
                     <a href="#" onclick="close_commentform(); return false;">Abbrechen</a>
                 </td></tr>
  </table>
</form>

<div style="position:absolute; top:20px; left: 20px; border:1px solid black; padding:4px; background:white; visibility:hidden;" id="answerbox">
  <a href="#" onclick="close_answerbox(); return false;">[x]</a>
  <div id="answer"></div>
</div>

<table width="100%" style="clear:left;">
 <tr>
  <td colspan="3">
      <p class="ftr">
       <a id="bbbikemail" href="mailto:$BBBike::EMAIL">E-Mail</a> |
       <a id="bbbikeurl" href="$BBBike::BBBIKE_DIRECT_WWW">BBBike</a> |
       <a href="@{[ $cgi_reldir ]}/mapserver_address.cgi?usemap=googlemaps">Adresssuche</a>
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

# hrefify($text)
# Create <a href="...">...</a> tags around things which look like URLs
# and HTML-escape everything else.

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

# trim($string)
# Trim starting and leading white space and squeezes white space to a
# single space.

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

=head1 DESCRIPTION

=head2 CGI Parameters

=over

=item C<coordsystem=>I<coordsystem>

Currently only C<bbbike> (standard BBBike coord system, default) and
C<polar> (WGS84 coordinates) are allowed.

=item C<wpt_or_trk=>I<...>

A waypoint or a track. Track points are separated with spaces. XXX

=item C<wpt=>I<name>C<!>I<lon>C<,>I<lat>

Set waypoint with the specified name on lon/lat and center map to this
waypoint.

=item C<coords=>I<...>

Display a track XXX

=item C<oldcoords=>I<...>

Display an alternative track with a feeble color XXX

=item C<gpxfile=>I<...>

Upload parameter for a GPX file.

=item C<zoom=>I<...>

Set zoom value (use standard Google Maps zoom values).

=item C<autosel=true>I<|>C<false>

Automatically update the OS selection if set to true. Does not work
yet!

=item C<maptype=hybrid>I<|>C<normal>I<|>C<satellite>

Set initial type of map (by default: satellite).

=item C<$mapmode=search>I<|>C<addroute>I<|>C<browse>I<|>C<addwpt>

Set initial mapmode to: search (route search mode activated), addroute
(adding points to routes activated), browse (just browsing the map is
activated), addwpt (adding waypoint activated). The default is browse.

=item C<center=>I<lon>C<,>I<lat>

Center to map to the specified point. If not set, then the first coord
from the track, or the first waypoint, or the center of Berlin will be
used.

=back

=cut

# rsync -e "ssh -2 -p 5022" -a ~/src/bbbike/cgi/bbbikegooglemap.cgi root@bbbike.de:/var/www/domains/radzeit.de/www/cgi-bin/bbbikegooglemap2.cgi
