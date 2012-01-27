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

open my $fh, $htmlfile
    or die "Can't open $htmlfile: $!";
binmode $fh, ':utf8';
while(<$fh>) {
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
