#!/usr/bin/perl
# -*- perl -*-

#
# $Id: treffpunkte.cgi,v 1.3 2004/06/10 21:55:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use CGI qw(:standard);
use strict;

if (param("center")) {
    show_point();
} else {
    show_list();
}

sub show_list {
    print header, start_html(-title => "Treffpunkte der Sternfahrt 2004",
			     -style=>{-src=> 'http://www.radzeit.de/BBBike/html/bbbike.css'},
			    ), h1("Treffpunkte der Sternfahrt 2004"), "<ul>";
    push_INC();
    require Strassen::Core;
    my $s;
    eval {
	# XXX del This is obsoleted...
	$s = Strassen->new("$FindBin::RealBin/treffpunkte2004-corrected.bbd");
    };
    if (!$s) {
	$s = Strassen->new("$FindBin::RealBin/treffpunkte2004.bbd");
    }
    $s->init;
    my @list;
    while(1) {
	my $ret = $s->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	my $qq = CGI->new(query_string);
	$qq->param("center", $ret->[Strassen::COORDS()][0]);
	push @list, [$ret->[Strassen::NAME()], $qq->self_url];
    }
    my $sort = param("sort") || "time";
    if ($sort eq "name") {
	for (@list) {
	    (my $s = $_->[0]) =~ s/(.*\d+\.\d+\s+Uhr)\s+//;
	    my $time = $1;
	    my $zusatz;
	    if ($s =~ s/^((?:[US]-)?(?:Bhf\.|Bahnhof))\s+//) {
		$zusatz = $1;
	    }
	    $_->[0] = $s . ($zusatz ? " ($zusatz)" : "") . ": $time";
	}
	@list = sort { $a->[0] cmp $b->[0] } @list;
    }
    print join "\n", map { <<EOF } @list;
<li><a href="$_->[1]">$_->[0]</a>
EOF

    print p;

    if ($sort eq "name") {
	my $qq = CGI->new(query_string);
	$qq->param("sort", "time");
	print a({-href => $qq->self_url}, "Sortiert nach Zeit");
    } else {
	my $qq = CGI->new(query_string);
	$qq->param("sort", "name");
	print a({-href => $qq->self_url}, "Sortiert nach Treffpunkt");
    }

    print end_html;
}

sub show_point {
    push_INC();
    require BBBikeMapserver;
    require BBBikeVar;

    my $ms = BBBikeMapserver->new;
    $ms->read_config("$FindBin::RealBin/../../cgi/bbbike.cgi.config");
    my $layers = [qw(bahn gewaesser flaechen grenzen orte markerlayer
		     faehren sternfahrt treffpunkte)];
    my($width,$height) = (3000,3000);
    my($x,$y) = split /,/, param("center");
    if ($x < -1450 || $x > 19050 ||
	$y < 2850  || $y > 19550) {
	($width, $height) = (6000,6000);
    }

    $ms->start_mapserver
	(-bbbikeurl => $BBBike::BBBIKE_WWW,
	 -bbbikemail => $BBBike::EMAIL,
	 -scope => "",
	 -queryableroute => 1,
	 -layers => $layers,
	 -center => param("center"),
	 -markerpoint => param("center"),
	 -width => $width,
	 -height => $height,
	 -mapname => "sternfahrt2004",
	);
}

# XXX do not hardcode!
sub push_INC {
    require FindBin;
    push @INC, ("$FindBin::RealBin/../..",
		"$FindBin::RealBin/../../lib",
		"/home/e/eserte/src/bbbike",
		"/home/e/eserte/src/bbbike/lib",
		"/usr/local/apache/radzeit/BBBike",
		"/usr/local/apache/radzeit/BBBike/lib",
	       );
}

