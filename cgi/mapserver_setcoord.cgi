#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_setcoord.cgi,v 1.4 2003/06/29 10:44:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use CGI qw(:standard -oldstyle_urls);

use strict;
use vars qw($mapserver_prog_url);

my $imgwidth = 550;
my $imgheight = 550;
if (defined param("imgsize")) {
    ($imgwidth, $imgheight) = split /\s+/, param("imgsize");
}

my @imgext = split / /, param("imgext");
my $mapwidth = $imgext[2] - $imgext[0];
my $mapheight = $imgext[3] - $imgext[1];
my $set = param("coordset") || 'pass';
if ($set ne "pass") {
    param($set . "c", join(",",
			   param("img.x")/$imgwidth*$mapwidth   + $imgext[0],
			   $imgext[3] - param("img.y")/$imgheight*$mapheight));
}
if ($set eq 'ziel') {
    my $q2 = CGI->new(query_string());
    $q2->param("output_as", "mapserver");
    $q2->param("pref_seen", "true");
    $q2->param("startc", param("startc"));
    $q2->param("zielc", param("zielc"));
    $q2->param("layer", param("layer")) if defined param("layer");
    $q2->param("mapext", param("imgext")) if defined param("imgext");
    print redirect("http://www/~eserte/bbbike/cgi/bbbike.cgi?"
		   . $q2->query_string);
} elsif ($set eq 'start') {
    push_INC();
    require BBBikeMapserver;
    require FindBin; $FindBin::RealBin = $FindBin::RealBin; # peacify -w
    my $ms = BBBikeMapserver->new(-tmpdir => "/tmp"); # XXX do not hardcode
    $ms->read_config("$FindBin::RealBin/bbbike.cgi.config");
    $ms->start_mapserver(-passparams => 1,
			 -start => param("startc"));
} else { # pass
    push_INC();
    require BBBikeVar;
    require FindBin; $FindBin::RealBin = $FindBin::RealBin; # peacify -w
    do "$FindBin::RealBin/bbbike.cgi.config";
    if (!defined $mapserver_prog_url) {
	warn "Fallback to standard Mapserver URL";
	$mapserver_prog_url = $BBBike::BBBIKE_MAPSERVER_URL;
    }
    print redirect($mapserver_prog_url . "?" . query_string());
}

# XXX do not hardcode!
sub push_INC {
    push @INC, ("/home/e/eserte/src/bbbike",
		"/usr/local/apache/radzeit/BBBike",
	       );
}
