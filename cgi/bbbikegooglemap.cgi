#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2005,2006,2007,2008,2009,2010,2011,2012 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeGooglemap;

use strict;
use FindBin;
BEGIN {
    if (($ENV{SERVER_NAME}||'') =~ m{\Quser.cs.tu-berlin.de}) {
	use lib "/home/eserte/lib/site_perl";
    }
}
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
use BBBikeCGI::Util qw();
use BBBikeVar;
use BrowserInfo;
use Karte;
use Karte::Polar;

sub new { bless {}, shift }

sub run {
    my($self) = @_;

    local $CGI::POST_MAX = 2_000_000;

    my $coordsystem = param("coordsystem") || "bbbike";
    my $converter;
    if ($coordsystem =~ m{^(wgs84|polar)$}) {
	$converter = \&polar_converter;
	$coordsystem = 'polar';
    } else { # bbbike or standard
	$converter = \&bbbike_converter;
    }
    my $convert_xy   = sub { join ",", $converter->(split /,/, $_[0]) };
    my $split_coords = sub { split /[!;]/, $_[0] };
    my $convert_all  = sub { map { $convert_xy->($_) } $split_coords->($_[0]) };

    my $convert_wpt = sub {
	my($coord, $name);
	if ($_ =~ /[!;]/) {
	    ($name, $coord) = split /[!;]/, $_, 2;
	} else {
	    ($name, $coord) = ("", $_);
	}
	$coord = $convert_xy->($coord);
	[$coord, $name];
    };

    my @coords = map { [$convert_all->($_)] } param('coords');
    my @wpt    = map { $convert_wpt->($_) } param('wpt');

    if (param("wpt_or_trk")) {
	my $wpt_or_trk = trim(param("wpt_or_trk"));
	if ($wpt_or_trk =~ / /) {
	    push @coords, [map { $convert_xy->($_) } split / /, $wpt_or_trk];
	} else {
	    push @wpt, map { $convert_wpt->($_) } param('wpt_or_trk');
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

	    my $gpx = eval { Strassen->new_by_magic_or_suffix($tmpfile, name => "Uploaded GPX file") };
	    if (!$gpx) {
		if (param('debug')) {
		    warn "ERROR: gpxfile upload of file '$filename' failed. Detailed error: $@";
		} else {
		    my($err) = $@ =~ m{^(.*)};
		    warn "ERROR: gpxfile upload of file '$filename' failed. Short error: $err";
		}
		(my $short_err_msg = $@) =~ s{ at \S+ line \d+\.}{};
		$self->{errormessageupload} = "Ungültiges Datenformat. Gültige Datenformate sind u.a. .gpx, .kml und .kmz.\nDetaillierte Fehlermeldung:\n$short_err_msg";
	    } else {
		$gpx->init;
		my $gpx_converter = $gpx->get_conversion(-tomap => 'polar');
		while (1) {
		    my $r = $gpx->next;
		    if (!$r || !UNIVERSAL::isa($r->[Strassen::COORDS()], "ARRAY")) {
			warn "Parse error in line " . $gpx->pos . ", skipping...";
			next;
		    }
		    my @c = @{ $r->[Strassen::COORDS()] };
		    last if !@c;
		    @c = map { $gpx_converter->($_) } @c if $gpx_converter;
		    if (@c == 1) { # treat as waypoint
			push @wpt, [ $c[0], $r->[Strassen::NAME()] ];
		    } else {
			push @coords, \@c;
		    }
		}
	    }
	}
    }

    my @polylines_polar = @coords;
    my @polylines_polar_feeble = map { [$convert_all->($_)] } param('oldcoords');

    my $zoom = param("zoom");
    $zoom = 17-3 if !defined $zoom;

    my $autosel = param("autosel") || "";
    $self->{autosel} = $autosel && $autosel ne 'false' ? "true" : "false";

    my $maptype = param("maptype") || "";
    $self->{maptype} = ($maptype =~ /hybrid/i ? 'G_HYBRID_MAP' :
			$maptype =~ /normal/i ? 'G_NORMAL_MAP' :
			$maptype =~ /osm-mapnik/i ? 'mapnik_map' :
			#$maptype =~ /osm-tah/i    ? 'tah_map' :
			$maptype =~ /osm-cycle/i  ? 'cycle_map' :
			$maptype =~ /bbbike_mapnik/i  ? 'bbbike_mapnik_map' :
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
	($centerx,$centery) = map { sprintf "%.5f", $_ } split /,/, $wpts->[0][0];
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
	 '83.169.19.137'      => 'ABQIAAAACNG-XP3VVgdpYda6EwQUyhSIqv_shXeYhPRHJYvhhlve40RasBRI6WpGYyWT9EJigb4eNrqNhQkqSQ',
	 'bbbike.lvps176-28-19-132.dedicated.hosteurope.de' => 'ABQIAAAACNG-XP3VVgdpYda6EwQUyhR1a2Mn5lCCKUDYSFfuCVGW4Ye_FhRhw_1E4wz6JOkiJ2PLXtE3mf_NbQ',
	 'bbbike.lvps83-169-19-137.dedicated.hosteurope.de' => 'ABQIAAAACNG-XP3VVgdpYda6EwQUyhQzU4FpitV0WsqI42ZHyXuB_4og4xSjtsqjECenvg7m7jSSPGu1rc1w4A',
	 'user.cs.tu-berlin.de' => 'ABQIAAAACNG-XP3VVgdpYda6EwQUyhSBtzeMHRPjsDce2pdCviKWsp6ivRQM5jfqAYX2iYe9oBJyTM_QLOjtZw',

        'bbbike.org' =>
'ABQIAAAAX99Vmq6XHlL56h0rQy6IShRC_6-KTdKUFGO0FTIV9HYn6k4jEBS45YeLakLQU48-9GshjYiSza7RMg',
        'www.bbbike.org' =>
'ABQIAAAAX99Vmq6XHlL56h0rQy6IShRC_6-KTdKUFGO0FTIV9HYn6k4jEBS45YeLakLQU48-9GshjYiSza7RMg',
        'dev.bbbike.org' =>
'ABQIAAAAX99Vmq6XHlL56h0rQy6IShQGl2ahQNKygvI--_E2nchLqmbBhxRLXr4pQqVNorfON2MgRTxoThX1iw',
        'devel.bbbike.org' =>
'ABQIAAAAX99Vmq6XHlL56h0rQy6IShSz9Y_XkjB4bplja172uJiTycvaMBQbZCQc60GoFTYOa5aTUrzyHP-dVQ',
        'localhost' =>
'ABQIAAAAX99Vmq6XHlL56h0rQy6IShT2yXp_ZAY8_ufC3CFXhHIE1NvwkxTN4WPiGfl2FX2PYZt6wyT5v7xqcg',

	);
    my $full = URI->new(BBBikeCGI::Util::my_url(CGI->new, -full => 1));
    my $fallback_host = "bbbike.de";
    my $host_port = eval { $full->host } || $fallback_host;
    my($host, $port);
    if ($host_port =~ m{^(.*):(\d+)$}) {
	($host, $port) = ($1, $2);
    } else {
	$host = $host_port;
	$port = 80;
    }
    my $google_api_key = $google_api_keys{$host} || $google_api_keys{$fallback_host};
    my $cgi_reldir = dirname($full->path);
    my $is_beta = $full =~ m{bbikegooglemap2.cgi};

    my $bbbikeroot = "/BBBike";
    my $get_public_link = sub {
	BBBikeCGI::Util::my_url(CGI->new(), -full => 1);
    };
    if ($host eq 'bbbike.dyndns.org') {
	$bbbikeroot = "/bbbike";
    } elsif ($host =~ m{bbbike\.org}) {
	$bbbikeroot = "";
    } elsif ($host eq "localhost" || $host eq '127.0.0.1') {
	$bbbikeroot = "/bbbike";
	$get_public_link = sub {
	    my $link = BBBikeCGI::Util::my_url(CGI->new(), -full => 1);
	    $link =~ s{localhost(:?:\d+)?$bbbikeroot/cgi}{bbbike.de/cgi-bin};
	    $link;
	};
    }

    # assume that osm is always updated
    my $osm_copyright_year = ((localtime)[5])+1900;
    # ... and so is bbbike data
    my $bbbike_copyright_year = ((localtime)[5])+1900;

    my $is_msie6 = do {
	my $bi = BrowserInfo->new;
	$bi->{user_agent_name} eq 'MSIE' && $bi->{user_agent_version} < 7;
    };

    my $use_v3 = $is_beta;

    my $html = <<EOF;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
  <head>
    <title>BBBike data presented with Googlemap</title>
    <link rel="stylesheet" type="text/css" href="$bbbikeroot/html/bbbike.css"><!-- XXX only for radzeit/hosteurope -->
    <link type="image/gif" rel="shortcut icon" href="$bbbikeroot/images/bbbike_google.gif"><!-- XXX only for radzeit/hosteurope -->
EOF
    if ($use_v3) {
	$html .= <<EOF;
    <script src="http://maps.google.com/maps/api/js?sensor=false" type="text/javascript"></script>
EOF
    } else {
	$html .= <<EOF;
    <script src="http://www.google.com/jsapi?key=$google_api_key" type="text/javascript"></script>
    <script type="text/javascript">
      google.load("maps", "2");
    </script>
EOF
    }
    $html .= <<EOF;
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
        html,body     { height:100%; }
    --></style>
    <meta name="msapplication-config" content="none">
  </head>
  <body onload="init()" @{[ $use_v3 ? "" : 'onunload="GUnload()"' ]} class="nonWaitMode">
    <div id="map" style="width:100%; height:75%; min-height:500px;"></div>
EOF
    my $js = <<EOF;
    <script type="text/javascript">
    //<![CDATA[

    var isBBBikeBeta = @{[ $is_beta ? "true" : "false" ]};
    var useV3 = @{[ $use_v3 ? "true" : "false" ]};

    var routeLinkLabel = "Link to route: ";
    var routeLabel = "Route: ";
    var commonSearchParams    = "&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=;referer=bbbikegooglemap;output_as=xml";
    var commonWebSearchParams = "&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&scope=;referer=bbbikegooglemap";
    var routePostParam = "";

    var addRoute = [];
    var undoRoute = [];
    var addRouteOverlay;
    var addRouteOverlay2;

    var userWpts = [];

    var searchStage = 0;

    var isGecko = navigator && navigator.product == "Gecko" ? true : false;
    var isMSIE6 = @{[ $is_msie6 ? "true" : "false" ]};
    var dragCursor = isGecko ? '-moz-grab' : 'url("$bbbikeroot/images/moz_grab.gif"), auto';

    var startIcon, startGoalIconShadow, goalIcon;
    if (useV3) {
        startIcon = new google.maps.MarkerImage("$bbbikeroot/images/flag2_bl_centered.png",
						new google.maps.Size(32,32),
						null,
						new google.maps.Point(16,16));
        goalIcon = new google.maps.MarkerImage("$bbbikeroot/images/flag_ziel_centered.png",
						new google.maps.Size(32,32),
						null,
						new google.maps.Point(16,16));
	startGoalIconShadow = new google.maps.MarkerImage("$bbbikeroot/images/flag_shadow.png",
						new google.maps.Size(45,24),
						null,
						new google.maps.Point(16,16));
    } else {
        startIcon = new GIcon(G_DEFAULT_ICON, "$bbbikeroot/images/flag2_bl_centered.png");
        startIcon.iconAnchor = new GPoint(16,16);
        startIcon.iconSize = new GSize(32,32);
        startIcon.shadow = "$bbbikeroot/images/flag_shadow.png";
        startIcon.shadowSize = new GSize(45,24);
        goalIcon = new GIcon(G_DEFAULT_ICON, "$bbbikeroot/images/flag_ziel_centered.png");
        goalIcon.iconAnchor = new GPoint(16,16);
        goalIcon.iconSize = new GSize(32,32);
        goalIcon.shadow = "$bbbikeroot/images/flag_shadow.png";
        goalIcon.shadowSize = new GSize(45,24);
    }
    var currentPointMarker = null;
    var currentTempBlockingMarkers = [];

    function createMarker(point, html_name) {
        var html = "<b>" + html_name + "</b>";
	var marker;
	if (useV3) {
	    marker = new google.maps.Marker({position:point})
	    var infowindow = new google.maps.InfoWindow({
		content: html
	    });
	    google.maps.event.addListener(marker, 'click', function() {
		infowindow.open(map, marker);
	    });
	} else {
	    marker = new GMarker(point);
	    GEvent.addListener(marker, "click", function() {
	        marker.openInfoWindowHtml(html);
	    });
	}
	return marker;
    }

    function removeTempBlockingMarkers() {
	for(var i = 0; i < currentTempBlockingMarkers.length; i++) {
	    if (useV3) {
		currentTempBlockingMarkers[i].setMap(null);
	    } else {
	        map.removeOverlay(currentTempBlockingMarkers[i]);
	    }
	}
	currentTempBlockingMarkers = [];
    }

    function setwpt(x,y) {
        map.panTo(new GLatLng(y, x));
    }

    function setwptAndMark(x,y) {
	var pt = new GLatLng(y, x);
	map.panTo(pt);
	if (currentPointMarker) {
	    if (useV3) {
		currentPointMarker.setMap(null);
	    } else {
	        map.removeOverlay(currentPointMarker);
	    }
	    currentPointMarker = null;
	}
	currentPointMarker = useV3 ? new google.maps.Marker({position:pt}) : new GMarker(pt);
	if (useV3) {
	    currentPointMarker.setMap(map);
	} else {
	    map.addOverlay(currentPointMarker);
	}
    }
    
    function showCoords(point, message) {
        var latLngStr = message + formatPoint(point);
        document.getElementById("message").innerHTML = latLngStr;
    }

    function formatPoint(point) {
	var s = sprintf("%.6f,%.6f", useV3 ? point.lng() : point.x, useV3 ? point.lat() : point.y);
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
	if (useV3) {
	    if (currentMode == "search") {
		map.setOptions({disableDoubleClickZoom:true});
	        if (searchStage == 0) {
		    map.setOptions({draggableCursor:'url("$bbbikeroot/images/start_ptr.png"), url("$bbbikeroot/images/flag2_bl.png"), ' + dragCursor});
	        } else {
	    	    map.setOptions({draggableCursor:'url("$bbbikeroot/images/ziel_ptr.png"), url("$bbbikeroot/images/flag_ziel.png"), ' + dragCursor});
	        }
	    } else {
		map.setOptions({disableDoubleClickZoom:false});
	        if (currentMode == "addroute" || currentMode == "addwpt") {
	    	    map.setOptions({draggableCursor:"default"});
	        } else {
	            map.setOptions({draggableCursor:dragCursor});
	        }
	        document.getElementById("wpt").innerHTML = "";
	    }
	} else {
	    var dragObj = map.getDragObject();
            if (currentMode == "search") {
	        map.disableDoubleClickZoom();
	        if (searchStage == 0) {
		    dragObj.setDraggableCursor('url("$bbbikeroot/images/start_ptr.png"), url("$bbbikeroot/images/flag2_bl.png"), ' + dragCursor);
	        } else {
	    	    dragObj.setDraggableCursor('url("$bbbikeroot/images/ziel_ptr.png"), url("$bbbikeroot/images/flag_ziel.png"), ' + dragCursor);
	        }
            } else {
	        map.enableDoubleClickZoom();
	        if (currentMode == "addroute" || currentMode == "addwpt") {
	    	    dragObj.setDraggableCursor("default");
	        } else {
	            dragObj.setDraggableCursor(dragCursor);
	        }
	        document.getElementById("wpt").innerHTML = "";
            }
	}

	if (!isMSIE6) {
	    var editboxDiv = document.getElementById("editbox");
	    if (editboxDiv) {
	        if (currentMode == "addroute" || currentMode == "addwpt") {
	            editboxDiv.style.visibility = "visible";
	        } else {
	            editboxDiv.style.visibility = "hidden";
	        }
	    }
        }
    }

    function addCoordsToRoute(point) {
	var currentMode = getCurrentMode();
	if (currentMode != "addroute") {
	    return;
	}
	if (addRoute.length > 0) {
	    var lastPoint = addRoute[addRoute.length-1];
	    if (useV3) {
		if (point.equals(lastPoint)) {
		    return;
		}
	    } else {
	        if (lastPoint.x == point.x && lastPoint.y == point.y)
		    return;
	    }
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
		addRouteLink = routeLinkLabel + "@{[ $get_public_link->() ]}?zoom=" + map.getZoom() + "&coordsystem=polar" + "&maptype=" + mapTypeToString() + "&wpt_or_trk=";
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
	    if (useV3) {
		addRouteOverlay.setMap(null);
	    } else {
		map.removeOverlay(addRouteOverlay);
	    }
	    addRouteOverlay = null;
	}
	if (!addRoute.length) {
	   return;
	}
	if (addRoute.length == 1) {
	    addRouteOverlay = useV3 ? new google.maps.Marker({position:addRoute[0]}) : new GMarker(addRoute[0]);
	} else {
	    if (useV3) {
		addRouteOverlay = new GPolyline({path:addRoute,strokeColor:'#0000ff',strokeOpacity:0.34,strokeWeight:4,clickable:false});
	    } else {
	        var opts = {}; // GPolylineOptions
	        opts.clickable = false;
	        addRouteOverlay = new GPolyline(addRoute, null, null, null, opts);
	    }
	}
	if (useV3) {
	    addRouteOverlay.setMap(map);
	} else {
	    map.addOverlay(addRouteOverlay);
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
		    var point = new GLatLng(xy[1], xy[0]);
	    	    var marker = createMarker(point, text);
		    if (useV3) {
			marker.setMap(map);
		    } else {
			map.addOverlay(marker);
		    }
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
	wptHTML += "<a href=\\"javascript:searchRouteInBBBike()\\">gleiche Suche in BBBike</a><br />\\n";
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
	var marker = useV3 ? new google.maps.Marker({position:point}) : new GMarker(point);
	var preHtml = '<form>Kommentar:<br/><textarea id="userWptComment" cols="25" rows=4">';
	var postHtml = '</textarea></form><br/><a href="javascript:deleteUserWpt(' + userWpt.index + ')">Waypoint löschen</a>';
	var html = preHtml + postHtml;
	var htmlElem = document.createElement("div");
	htmlElem.innerHTML = html;
	var textarea = htmlElem.getElementsByTagName("textarea")[0];
	userWpt.textarea = textarea;
	marker.bindInfoWindow(htmlElem);
	if (useV3) {
	    marker.setMap(map);
	} else {
	    map.addOverlay(marker);
	}
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
		if (useV3) {
		    overlay.setMap(null);
		} else {
		    map.removeOverlay(overlay);
		}
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
	if        ((useV3  && map.getMapTypeId() == google.maps.MapTypeId.ROADMAP) ||
		   (!useV3 && map.getCurrentMapType() == G_NORMAL_MAP)) {
	    mapType = "normal";
	} else if ((useV3  && map.getMapTypeId() == google.maps.MapTypeId.HYBRID) ||
		   (!useV3 && map.getCurrentMapType() == G_HYBRID_MAP)) {
	    mapType = "hybrid";
	} else if ((useV3  && map.getMapTypeId() == "Mapnik") ||
		   (!useV3 && map.getCurrentMapType() == mapnik_map)) {
	    mapType = "osm-mapnik";
	// } else if ((useV3  && map.getMapTypeId() == "T\@H") ||
	// 	   (!useV3 && map.getCurrentMapType() == tah_map)) {
	//     mapType = "osm-tah";
	} else if ((useV3  && map.getMapTypeId() == "Cycle") ||
		   (!useV3 && map.getCurrentMapType() == cycle_map)) {
	    mapType = "osm-cycle";
	} else if ((useV3  && map.getMapTypeId() == "BBBike") ||
		   (!useV3 && map.getCurrentMapType() == bbbike_mapnik_map)) {
	    mapType = "bbbike_mapnik";
	} else {
	    mapType = "satellite";
	}
	return mapType;
    }

    function showLink(point, message) {
	var mapType = mapTypeToString();
        var latLngStr = message + "@{[ $get_public_link->() ]}?zoom=" + map.getZoom() + "&wpt=" + formatPoint(point) + "&coordsystem=polar" + "&maptype=" + mapType + "&mapmode=" + getCurrentMode();
        document.getElementById("permalink").innerHTML = latLngStr;
    }

    function checkSetCoordForm() {
	var wpt_or_trk_value = document.googlemap.wpt_or_trk.value;
	if (wpt_or_trk_value == "") {
	    alert("Bitte Koordinaten eingeben (z.B. im WGS84-Modus: 13.376431,52.516172)");
	    return false;
	}
	if (wpt_or_trk_value.match(/^([-+]?\\d+(?:\\.\\d+)?),([-+]?\\d+(?:\\.\\d+)?)\$/)) {
	    if (document.googlemap.coordsystem[0].checked) { // polar
	        if (Math.abs(RegExp.\$1) > 180 || Math.abs(RegExp.\$2) > 90) {
		    alert("Ungültiger Wert für Longitude/Latitude, gültig wäre z.B. 13.376431,52.516172");
		    return false;
		}
	    } else {
		if (Math.abs(RegExp.\$1) > 1000000 || Math.abs(RegExp.\$2) > 1000000) {
		    alert("Zu großer Wert für Rechts/Hochwert");
		    return false;
		}
	    }
	} else {
	    alert("Bitte Koordinaten im Format 13.376431,52.516172 eingeben.");
	    return false;
	}
	setZoomInForm();
	return true;	
    }

    function setZoomInForm() {
	document.googlemap.zoom.value = map.getZoom();
    }

    function setZoomInUploadForm() {
	document.upload.zoom.value = map.getZoom();
    }

    function waitMode() {
	document.getElementsByTagName("body")[0].className = "waitMode";
    }

    function nonWaitMode() {
        document.getElementsByTagName("body")[0].className = "nonWaitMode";
    }

    function getSearchCoordParams(startPoint, goalPoint) {
	if (useV3) {
            return "startc_wgs84=" + startPoint.lng() + "," + startPoint.lat() + "&zielc_wgs84=" + goalPoint.lng() + "," + goalPoint.lat();
	} else {
	    return "startc_wgs84=" + startPoint.x + "," + startPoint.y + "&zielc_wgs84=" + goalPoint.x + "," + goalPoint.y;
	}
    }

    function searchRoute(startPoint, goalPoint) {
        var searchCoordParams = getSearchCoordParams(startPoint, goalPoint);
	var requestLine =
	    "@{[ $cgi_reldir ]}/bbbike.cgi?" + searchCoordParams + commonSearchParams;
	var routeRequest = useV3 ? new XMLHttpRequest() : GXmlHttp.create();
	routeRequest.open("GET", requestLine, true);
	routeRequest.onreadystatechange = function() {
	    showRouteResult(routeRequest);
	};
	waitMode();
	routeRequest.send(null);
    }

    function searchRouteInBBBike() {
        var searchCoordParams = getSearchCoordParams(startPoint, goalPoint);
	var url =
	    "@{[ $cgi_reldir ]}/bbbike.cgi?" + searchCoordParams + commonWebSearchParams;
	location.href = url;
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
	    	var p = new GLatLng(xy[1],xy[0]);
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

    function onClick(p1, p2) {
	var point = useV3 ? p1.latLng : p2;
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
	    // XXX hack to avoid empty searches, this happens if the user does a double click in search/edit mode
	    if (useV3) {
		if (point.equals(startPoint)) {
		    return;
		}
	    } else {
		if (startPoint.x == point.x && startPoint.y == point.y) {
		    return;
		}
	    }
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
	    if (useV3) {
		startOverlay.setMap(null);
	    } else {
	        map.removeOverlay(startOverlay);
	    }
	    startOverlay = null;
	}
	startPoint = point;
	if (useV3) {
	    startOverlay = new GMarker({position:startPoint,icon:startIcon,shadow:startGoalIconShadow,clickable:false});
	    startOverlay.setMap(map);
	} else {
	    var startOpts = {icon:startIcon, clickable:false}; // GMarkerOptions
	    startOverlay = new GMarker(startPoint, startOpts);
	    map.addOverlay(startOverlay);
	}
    }

    function setGoalMarker(point) {
	removeGoalMarker();
	goalPoint = point;
	if (useV3) {
	    goalOverlay = new GMarker({position:goalPoint,icon:goalIcon,shadow:startGoalIconShadow,clickable:false});
	    goalOverlay.setMap(map);
	} else {
	    var goalOpts = {icon:goalIcon, clickable:false}; // GMarkerOptions
	    goalOverlay = new GMarker(goalPoint, goalOpts);
	    map.addOverlay(goalOverlay);
	}
    }

    function removeGoalMarker() {
	if (goalOverlay) {
	    if (useV3) {
		goalOverlay.setMap(null);
	    } else {
		map.removeOverlay(goalOverlay);
	    }
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
        var http = useV3 ? new XMLHttpRequest() : GXmlHttp.create();
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
	if (useV3) {
	    waitMode();
	    var geocoder = new google.maps.Geocoder();
	    geocoder.geocode({address:address, bounds:map.getBounds(), region:"de"}, geocodeResultV3);
	} else {
	    var geocoder = new GClientGeocoder();
	    geocoder.setViewport(map.getBounds());
	    geocoder.setBaseCountryCode("de");
	    waitMode();
	    geocoder.getLatLng(address, geocodeResultV2);
	}
        return false;
    }

    function geocodeResultV2(point) {
	nonWaitMode();
	if (!point) {
	    alert("Adresse nicht gefunden");
	} else {
	    setwptAndMark(point.x, point.y);
	}
    }

    function geocodeResultV3(results, status) {
	nonWaitMode();
	if (status == google.maps.GeocoderStatus.OK) {
	    map.setCenter(results[0].geometry.location);
	    setwptAndMark(results[0].geometry.location.lng(),results[0].geometry.location.lat());
	} else {
	    alert("Adresse nicht gefunden. " + status);
	}
    }

    function updateCopyrights() {
        if (map.getMapTypeId() == "BBBike") {
 	    copyrightNode.innerHTML = 'Kartendaten &copy; $bbbike_copyright_year <a href="http://bbbike.de/cgi-bin/bbbike.cgi/info=1">Slaven Rezi&#x107;</a>';
        } else if (map.getMapTypeId() == "Mapnik" ||
                   map.getMapTypeId() == "T\@H" ||
                   map.getMapTypeId() == "Cycle") {
 	    copyrightNode.innerHTML = 'Kartendaten &copy; $osm_copyright_year <a href="http://www.openstreetmap.org/">OpenStreetMap</a> Contributors';
        } else {
 	    copyrightNode.innerHTML = "";
        }
    }

    if (useV3) {
        var myOptions = {
            zoom: $zoom,
            center: new GLatLng($centery, $centerx),
            mapTypeId: $self->{maptype}
        };
        var map = new google.maps.Map(document.getElementById("map"), myOptions);

        // Create div for showing copyrights.
        copyrightNode = document.createElement('div');
        copyrightNode.id = 'copyright-control';
        copyrightNode.style.fontSize = '11px';
        copyrightNode.style.fontFamily = 'sans-serif';
        copyrightNode.style.margin = '0 2px 2px 0';
        copyrightNode.style.whiteSpace = 'nowrap';
        copyrightNode.index = 0;
        map.controls[google.maps.ControlPosition.BOTTOM_RIGHT].push(copyrightNode);
        google.maps.event.addListener(map, 'idle', updateCopyrights);
        google.maps.event.addListener(map, 'maptypeid_changed', updateCopyrights);

    } else if (GBrowserIsCompatible()) {
        var map = new GMap2(document.getElementById("map"));
	//map.disableDoubleClickZoom();
	map.enableScrollWheelZoom()
        map.addControl(new GLargeMapControl());
        map.addControl(new GMapTypeControl());
        map.addControl(new GOverviewMapControl ());
    } else {
        document.getElementById("map").innerHTML = '<p class="large-error">Sorry, your browser is not supported by <a href="http://maps.google.com/support">Google Maps</a></p>';
    }

    // additional maps
    if (useV3) {
	var mapnik_map = new google.maps.ImageMapType({
            getTileUrl:GetTileUrl_Mapnik,
        	tileSize:new google.maps.Size(256, 256),
        	isPng:true,
        	name:"Mapnik",
		maxZoom:19
	});
        map.mapTypes.set("Mapnik", mapnik_map);

	// var tah_map = new google.maps.ImageMapType({
        //     getTileUrl:GetTileUrl_TaH,
        // 	tileSize:new google.maps.Size(256, 256),
        // 	isPng:true,
        // 	name:"T\@H",
	// 	maxZoom:19
	// });
        // map.mapTypes.set("T\@H", tah_map);

	var cycle_map = new google.maps.ImageMapType({
            getTileUrl:GetTileUrl_Cycle,
        	tileSize:new google.maps.Size(256, 256),
        	isPng:true,
        	name:"Cycle",
		maxZoom:19
	});
        map.mapTypes.set("Cycle", cycle_map);

        var bbbike_mapnik_map = new google.maps.ImageMapType({
            getTileUrl:GetTileUrl_bbbike_mapnik,
        	tileSize:new google.maps.Size(256, 256),
        	isPng:true,
        	name:"BBBike",
		maxZoom:19
        });
        map.mapTypes.set("BBBike", bbbike_mapnik_map);

        map.setOptions({mapTypeControlOptions:{mapTypeIds:[google.maps.MapTypeId.ROADMAP,
							   google.maps.MapTypeId.SATELLITE,
							   google.maps.MapTypeId.HYBRID,
							   "BBBike",
							   "Cycle",
							   "Mapnik",
							   // "T\@H"
							  ]}});
    } else {
        var copyright = new GCopyright(1,
            new GLatLngBounds(new GLatLng(-90,-180), new GLatLng(90,180)), 0,
            '(<a rel="license" href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>)');
        var copyrightCollection =
            new GCopyrightCollection('Kartendaten &copy; $osm_copyright_year <a href="http://www.openstreetmap.org/">OpenStreetMap</a> Contributors');
        copyrightCollection.addCopyright(copyright);
    
        var tilelayers_mapnik = new Array();
        tilelayers_mapnik[0] = new GTileLayer(copyrightCollection, 0, 18);
        tilelayers_mapnik[0].getTileUrl = GetTileUrl_Mapnik;
        tilelayers_mapnik[0].isPng = function () { return true; };
        tilelayers_mapnik[0].getOpacity = function () { return 1.0; };
        var mapnik_map = new GMapType(tilelayers_mapnik,
            new GMercatorProjection(19), "Mapnik",
            { urlArg: 'mapnik', linkColor: '#000000' });
        map.addMapType(mapnik_map);
    
        // var tilelayers_tah = new Array();
        // tilelayers_tah[0] = new GTileLayer(copyrightCollection, 0, 17);
        // tilelayers_tah[0].getTileUrl = GetTileUrl_TaH;
        // tilelayers_tah[0].isPng = function () { return true; };
        // tilelayers_tah[0].getOpacity = function () { return 1.0; };
        // var tah_map = new GMapType(tilelayers_tah,
        //     new GMercatorProjection(19), "T\@H",
        //     { urlArg: 'tah', linkColor: '#000000' });
        // map.addMapType(tah_map);
    
        var tilelayers_cycle = new Array();
        tilelayers_cycle[0] = new GTileLayer(copyrightCollection, 0, 18);
        tilelayers_cycle[0].getTileUrl = GetTileUrl_Cycle;
        tilelayers_cycle[0].isPng = function () { return true; };
        tilelayers_cycle[0].getOpacity = function () { return 1.0; };
        var cycle_map = new GMapType(tilelayers_cycle,
            new GMercatorProjection(19), "Cycle",
            { urlArg: 'cycle', linkColor: '#000000' });
        map.addMapType(cycle_map);
    
        var bbbikeCopyright = new GCopyright(1,
            new GLatLngBounds(new GLatLng(-90,-180), new GLatLng(90,180)), 0,
            '(<a rel="license" href="http://bbbike.sourceforge.net/bbbike/doc/README.html#LIZENZ">GPL</a>)');
        var bbbikeCopyrightCollection =
            new GCopyrightCollection('Kartendaten &copy; $bbbike_copyright_year <a href="http://bbbike.de/cgi-bin/bbbike.cgi/info=1">Slaven Rezi&#x107;</a>');
        bbbikeCopyrightCollection.addCopyright(bbbikeCopyright);
    
        var tilelayers_bbbike_mapnik = new Array();
        tilelayers_bbbike_mapnik[0] = new GTileLayer(bbbikeCopyrightCollection, 0, 18);
        tilelayers_bbbike_mapnik[0].getTileUrl = GetTileUrl_bbbike_mapnik;
        tilelayers_bbbike_mapnik[0].isPng = function () { return true; };
        tilelayers_bbbike_mapnik[0].getOpacity = function () { return 1.0; };
        var bbbike_mapnik_map = new GMapType(tilelayers_bbbike_mapnik,
            new GMercatorProjection(19), "BBBike",
            { urlArg: 'bbbike_mapnik', linkColor: '#000000' });
        if (isBBBikeBeta) {
            map.addMapType(bbbike_mapnik_map);
        }
    }

    //// no, I prefer hybrid
    //map.setMapType(mapnik_map);

    function GetTileUrl_Mapnik(a, z) {
	// select a random server
	var list = ["a", "b", "c"];
	var server = list [ parseInt( Math.random() * list.length ) ];
	return "http://" + server + ".tile.openstreetmap.org/" + z + "/" + a.x + "/" + a.y + ".png";
    }

    // function GetTileUrl_TaH(a, z) {
    //     return "http://tah.openstreetmap.org/Tiles/tile/" +
    //                 z + "/" + a.x + "/" + a.y + ".png";
    // }

    function GetTileUrl_Cycle(a, z) {
	// select a random server
	var list = ["a", "b", "c"];
	var server = list [ parseInt( Math.random() * list.length ) ];
	return "http://" + server + ".tile.opencyclemap.org/cycle/" + z + "/" + a.x + "/" + a.y + ".png";
    }

    function GetTileUrl_bbbike_mapnik(a, z) {
	// select a random server
	var list = ["a", "b", "c"];
	var server = list [ parseInt( Math.random() * list.length ) ];

	if (false) {
	    return "http://" + server + ".tile.bbbike.org/osm/mapnik/"        + z + "/" + a.x + "/" + a.y + ".png";
	} else {
	    return "http://" + server + ".tile.bbbike.org/osm/mapnik-german/" + z + "/" + a.x + "/" + a.y + ".png";
	}
    }

    if (!useV3 && GBrowserIsCompatible() ) {
	map.setCenter(new GLatLng($centery, $centerx), $zoom, $self->{maptype});
	new GKeyboardHandler(map);
    }

    GEvent.addListener(map, (useV3 ? "dragend" : "moveend"), function() {
        var center = map.getCenter();
	showCoords(center, 'Center of map: ');
	showLink(center, 'Link to map center: ');
    });

    // *** BEGIN DATA ***
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
				       sprintf 'new GLatLng(%.5f, %.5f)', $y, $x;
				   } @$path_polar
				  );
	    $route_js_code .= qq{], "$color", $width};
	    if (defined $opacity) {
		$route_js_code .= qq{, $opacity};
	    }
	    $route_js_code .= qq{);};

	    $js .= <<EOF;
$route_js_code
    if (useV3) {
	route.setMap(map);
    } else {
        map.addOverlay(route);
    }
EOF
	}
    }

    for my $wpt (@$wpts) {
	my($xy,$name) = @$wpt;
	my($x,$y) = split /,/, $xy;
	#my $html_name = escapeHTML($name);
	my $html_name = hrefify($name);
	$js .= <<EOF;
    var point = new GLatLng($y,$x);
    var marker = createMarker(point, '$html_name');
    if (useV3) {
	marker.setMap(map);
    } else {
        map.addOverlay(marker);
    }
EOF
    }

    $js .= <<EOF;
    // *** END DATA ***

    GEvent.addListener(map, "click", onClick);

    //]]>
    </script>
EOF

    if ($use_v3) {
	$js =~ s{GLatLngBounds\(}{google.maps.LatLngBounds(}g;
	$js =~ s{GLatLng\(}{google.maps.LatLng(}g;
	$js =~ s{GPoint\(}{google.maps.Point(}g;
	$js =~ s{GPolyline\(}{google.maps.Polyline(}g;
	$js =~ s{GMarker\(}{google.maps.Marker(}g;
	$js =~ s{GEvent\.}{google.maps.event.}g;
	$js =~ s{GIcon\(}{google.maps.Icon(}g;
	$js =~ s{G_([^_]+)_MAP}{google.maps.MapTypeId.$1}g;
    }

    $html .= $js;
    $html .= <<EOF;
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
	my($xy,$name) = @$wpt;
	my($x,$y) = split /,/, $xy;
	next if $name eq '';
	$html .= qq{<a href="#map" onclick="setwpt($x,$y);return true;">$name</a><br />\n};
    }
    $html .= <<EOF;
    </div>

EOF
    if ($is_msie6) {
	$html .= <<EOF;
<div id="commentlink" class="boxed" style="display:none;">
  <a href="#" onclick="show_comment(); return false;">Kommentar zu Route und Waypoints senden</a>
</div>

EOF
    }
    $html .= <<EOF;
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
    <td><label for="mapmode_addroute">Mit Mausklicks eine Route erstellen</label><br/><!-- XXX remove colored "klicks" some time -->
EOF
    if ($is_msie6) {
	$html .= <<EOF;
        <a href="javascript:deleteLastPoint()">Letzten Punkt löschen</a>
        <a href="javascript:resetOrUndoRoute()" id="routedellink">Route löschen</a>
EOF
    }
    $html .= <<EOF;
     </td>
   </tr>
EOF
    if (0 && $is_beta) { # hmmm, wozu ist das gut? XXXXXXXXXXXXXXXXXXXXXXXXXXXX
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
	my $errormessageupload_html = escapeHTML($self->{errormessageupload});
	$errormessageupload_html =~ s{\n}{<br />}g;
	$html .= <<EOF;
  <div class="error">$errormessageupload_html</div>
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

<!-- should come before commentform to be lower in the layer stack -->
<div id="editbox" class="boxed" style="position:fixed; top:15px; left:85px; background:white; visibility:hidden; font-size:smaller; ">
  <a href="javascript:deleteLastPoint()">Letzten Punkt löschen</a>
  <a href="javascript:resetOrUndoRoute()" id="routedellink">Route löschen</a><br/>
  <div id="commentlink" style="display:none;">
    <a href="#" onclick="show_comment(); return false;">Kommentar zu Route und Waypoints senden</a>
  </div>
</div>

<form id="commentform" style="position:fixed; top:20px; left: 20px; border:1px solid black; padding:4px; background:white; visibility:hidden;">
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
C<polar> or C<wgs84> (WGS84 coordinates) are allowed.

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

Set zoom value. Use standard Google Maps zoom values (that is, GMap2
compatible values: 0 is the coarsest level).

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

# rsync -a ~/src/bbbike/cgi/bbbikegooglemap.cgi root@83.169.19.137:work/bbbike-webserver/BBBike/cgi/bbbikegooglemap2.cgi
