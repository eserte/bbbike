#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mapserver_setcoord.cgi,v 1.12 2007/03/18 18:45:30 eserte Exp $
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
use CGI::Carp;

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
    # XXX Vielleicht das hier konfigurierbar machen: wenn false,
    # dann hat der User die Möglichkeit, seine Preferenzen einzustellen
    # und sich die Routenliste anzugucken. Wenn true wird die Route
    # sofort im Mapserver gezeichnet.
    $q2->param("pref_seen", "true");
    $q2->param("startc", param("startc"));
    $q2->param("zielc", param("zielc"));
    $q2->param("layer", param("layer")) if defined param("layer");
    if (!grep { $_ eq 'route' } $q2->param("layer")) {
	$q2->append(-name => "layer", -values => ["route"]);
    }
    $q2->param("mapext", param("imgext")) if defined param("imgext");
    push_INC();
    require BBBikeMapserver;
    my $scope; $scope = BBBikeMapserver::scope_by_map(param("map"))
	if defined param("map");
    $q2->param("scope", $scope)
	if defined $scope;
    # XXX Delete more params... or use -pass mode?
    $q2->delete($_) for (qw(img.x img.y map zoomdir zoomsize mode
			    orig_mode orig_zoomdir imgxy imgext));
    my $bbbikeurl = param("bbbikeurl") || "http://www/~eserte/bbbike/cgi/bbbike.cgi";
    print redirect("$bbbikeurl?" . $q2->query_string);
} elsif ($set eq 'start') {
    push_INC();
    require BBBikeMapserver;
    require FindBin; $FindBin::RealBin = $FindBin::RealBin; # peacify -w
    my $ms = BBBikeMapserver->new(-tmpdir => "/tmp"); # XXX do not hardcode
    $ms->read_config("$FindBin::RealBin/bbbike.cgi.config");

    my @layers;
    my $q2 = CGI->new(query_string());
    if (!grep { $_ eq 'route' } $q2->param("layer")) {
	@layers = ($q2->param("layer"), "route");
    }

    require File::Basename;
    my $mapname;
    if (param("map")) {
	$mapname = File::Basename::basename(param("map"));
	$mapname =~ s{-(?:brb|b|inner-b|wide|p)(\.map)}{$1};
	$mapname =~ s{\..*}{};
    }
    $ms->start_mapserver(-passparams => 1,
			 -mapname => $mapname,
			 -start => param("startc"),
			 (@layers ? (-layers => \@layers) : ()),
			);
} else { # pass
    push_INC();
    require BBBikeVar;
    require FindBin; $FindBin::RealBin = $FindBin::RealBin; # peacify -w
    $BBBike::BBBIKE_MAPSERVER_URL = $BBBike::BBBIKE_MAPSERVER_URL; # peacify -w
    do "$FindBin::RealBin/bbbike.cgi.config";
    if (!defined $mapserver_prog_url) {
	warn "Fallback to standard Mapserver URL";
	$mapserver_prog_url = $BBBike::BBBIKE_MAPSERVER_URL;
    }
    print redirect($mapserver_prog_url . "?" . query_string());
}

# XXX do not hardcode!
sub push_INC {
    require FindBin;
    push @INC, ("$FindBin::RealBin/..",
		"/home/e/eserte/src/bbbike",
		"/usr/local/apache/radzeit/BBBike",
		"/var/www/domains/radzeit.de/www/BBBike",
	       );
}
