#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
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

open my $fh, $htmlfile
    or die "Can't open $htmlfile: $!";
binmode $fh, ':utf8';
binmode STDOUT, ':utf8';
while(<$fh>) {
    if (m{(.*)\Q<!-- FIX URL LAYOUT -->\E}) {
	my $line = $1;
	my $use_old_url_layout = $q->url(-absolute => 1) =~ m{/cgi/bbbikeleaflet};
	my $bbbike_htmlurl;
	if ($use_old_url_layout) {
	    $bbbike_htmlurl = "/bbbike/html";
	} else {
	    $bbbike_htmlurl = "/BBBike/html";
	}
	if ($line !~ s{(src=")}{$1$bbbike_htmlurl/}) {
	    $line =~ s{(href=")}{$1$bbbike_htmlurl/};
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
}

__END__
