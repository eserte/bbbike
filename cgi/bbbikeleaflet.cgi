#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use CGI;

my $htmldir = "$FindBin::RealBin/../html";
my $htmlfile = "$htmldir/bbbikeleaflet.html";

my $q = CGI->new;
print $q->header('text/html; charset=utf-8');

my $leaflet_dist = $q->param('leafletdist') || '';
my $enable_upload = $q->param('upl') || 0;
my $enable_accel = $q->param('accel') || 0;
my $use_osm_de_map = $q->param('osmdemap') || 0;

if ($enable_accel && !$enable_upload) { # no sense to enable accelerometer without upload functionality
    $enable_upload = 1;
}

my $use_old_url_layout = $q->url(-absolute => 1) =~ m{/cgi/bbbikeleaflet};
my($bbbike_htmlurl, $bbbike_imagesurl);
if ($use_old_url_layout) {
    $bbbike_htmlurl = "/bbbike/html";
    $bbbike_imagesurl = "/bbbike/images";
} else {
    $bbbike_htmlurl = "/BBBike/html";
    $bbbike_imagesurl = "/BBBike/images";
}

open my $fh, $htmlfile
    or die "Can't open $htmlfile: $!";
binmode $fh, ':utf8';
binmode STDOUT, ':utf8';
my $state_upload;
while(<$fh>) {
    if (m{\Q<!-- IF UPLOAD ENABLED -->}) {
	$state_upload = 'enabled';
	next;
    } elsif (m{\Q<!-- IF UPLOAD DISABLED -->}) {
	$state_upload = 'disabled';
	next;
    } elsif (m{\Q<!-- END UPLOAD -->}) {
	undef $state_upload;
	next;
    }

    if ($state_upload) {
	if ($state_upload eq 'enabled' && !$enable_upload) {
	    next;
	} elsif ($state_upload eq 'disabled' && $enable_upload) {
	    next;
	}
    }

    if (m{(.*)\Q<!-- FIX URL LAYOUT -->\E}) {
	my $line = $1;
	if ($line !~ s{(src=")}{$1$bbbike_htmlurl/}) {
	    $line =~ s{(href=")}{$1$bbbike_htmlurl/};
	}
	print $line, "\n";
	next;
    }

    if (m{(.*)\Q<!-- FIX IMAGES URL LAYOUT -->\E}) {
	my $line = $1;
	if ($line !~ s{(src=")}{$1$bbbike_imagesurl/}) {
	    $line =~ s{(href=")}{$1$bbbike_imagesurl/};
	}
	print $line, "\n";
	next;
    }

    if ($leaflet_dist eq 'biokovo') {
	s{\Qhttp://bbbike.de/leaflet/dist\E}{http://192.168.1.5/~eserte/leaflet/dist};
    }

    print $_;
    if (m{\Q//--- INSERT GEOJSON HERE ---}) {
	if ($q->param('coordssession')) {
	    require BBBikeApacheSessionCounted;
	    if (my $sess = BBBikeApacheSessionCounted::tie_session($q->param('coordssession'))) {
		$q->param(coords => $sess->{routestringrep});
	    } else {
		print qq{alert("Die Session ist abgelaufen.");\n};
	    }
	}
	if ($q->param('coords')) {
	    require BBBikeGeoJSON;
	    require Route;
	    my $route = Route->new_from_cgi_string(join("!", $q->param('coords')));
	    my $json = BBBikeGeoJSON::route_to_geojson_json($route);
	    print "initialRouteGeojson = $json;\n";
	}
    }

    if (m{\Q//--- INSERT DEVEL CODE HERE ---}) {
	print "enable_upload = " . ($enable_upload ? 'true' : 'false') . ";\n";
	print "enable_accel = " . ($enable_accel ? 'true' : 'false') . ";\n";
	print "use_osm_de_map = " . ($use_osm_de_map ? 'true' : 'false') . "\n";
    }
}

__END__
