#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.cgi,v 1.13 2005/10/15 00:50:42 eserte Exp eserte $
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
    
    function showCoords(point, message) {
        var latLngStr = message + point.x + "," + point.y;
        document.getElementById("message").innerHTML = latLngStr;
    }

    function showLink(point, message) {
        var latLngStr = message + "@{[ url(-full => 1) ]}?zoom=" + map.getZoomLevel() + "&wpt=" + point.x + "," + point.y + "&coordsystem=polar";
        document.getElementById("permalink").innerHTML = latLngStr;
    }

    function setZoomInForm() {
	document.googlemap.zoom.value = map.getZoomLevel();
    }

    function setZoomInUploadForm() {
	document.upload.zoom.value = map.getZoomLevel();
    }

    var map = new GMap(document.getElementById("map"), [G_SATELLITE_TYPE]);
    map.addControl(new GLargeMapControl());
    map.addControl(new GMapTypeControl());
    map.centerAndZoom(new GPoint($centerx, $centery), $zoom);

    GEvent.addListener(map, "moveend", function() {
        var center = map.getCenterLatLng();
	showCoords(center, 'Center of map: ');
	showLink(center, 'Link: ');
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

    //]]>
    </script>
    <div style="font-size:x-small;" id="message"></div>
    <div style="font-size:x-small;" id="permalink"></div>
    <div id="wpt">
EOF
    for my $wpt (@$wpts) {
	my($x,$y,$name) = @$wpt;
	next if $name eq '';
	$html .= qq{<a href="#map" onclick="setwpt($x,$y);return true;">$name</a><br />\n};
    }
    $html .= <<EOF;
    </div>

<form name="googlemap" onsubmit='setZoomInForm()' style="margin-top:1cm; border:1px solid black; padding:3px;">
  <input type="hidden" name="zoom" value="@{[ $zoom ]}" />
  Koordinatensystem:<br />
  <label><input type="radio" name="coordsystem" value="standard" @{[ $coordsystem eq 'standard' ? 'checked' : '' ]} /> BBBike</label><br />
  <label><input type="radio" name="coordsystem" value="polar" @{[ $coordsystem eq 'polar' ? 'checked' : '' ]} /> WGS84-Koordinaten (DDD)</label><br />
  <br />
  <label>Koordinate (x,y bzw. lon,lat): <input name="wpt_or_trk" size="15" /></label><br />
  <br />
  <button>Zeigen</button>
</form>

<form name="upload" onsubmit='setZoomInUploadForm()' style="margin-top:1cm; border:1px solid black; padding:3px;" method="post" enctype="multipart/form-data">
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

