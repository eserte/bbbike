#!/usr/bin/perl
# -*- perl -*-

#
# $Id: treffpunkte.cgi,v 1.6 2007/06/02 11:53:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use CGI qw(:standard);
use strict;
use FindBin;
use lib ("$FindBin::RealBin/../..");
use BBBikeCGIUtil;

our $DEBUG;

my @l = localtime;

my($year) = url() =~ /(2\d\d\d)/;
if (!$year) {
    warn "Cannot determine year from URL " . url() . ", should not happen, try fallback...";
    $year = $l[5]+1900;
}

$DEBUG = param("debug") if defined param("debug");

if (param("center")) {
    show_point();
} else {
    show_list();
}

sub show_list {
    my $sort = param("sort") || "time";

    print header, start_html(-title => "Treffpunkte der Sternfahrt $year",
			     -style=>{-src=> '/BBBike/html/bbbike.css'},
			    ), h1("Treffpunkte der Sternfahrt $year");

    print p;

    print "Sortiert nach: ";

    if ($sort eq "name") {
	my $qq = CGI->new(query_string);
	$qq->param("sort", "time");
	print a({-href => BBBikeCGIUtil::my_self_url($qq)}, "Zeit");
    } else {
	print b("Zeit")." | ";
    }

    if ($sort eq 'time') {
	my $qq = CGI->new(query_string);
	$qq->param("sort", "name");
	print a({-href => BBBikeCGIUtil::my_self_url($qq)}, "Treffpunkt");
    } else {
	print " | ".b("Treffpunkt");
    }

    print p, ul;

    push_INC();
    require Strassen::Core;
    my $s = Strassen->new("$FindBin::RealBin/treffpunkte$year.bbd");
    $s->init;
    my @list;
    while(1) {
	my $ret = $s->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	my $qq = CGI->new(query_string);
	$qq->param("center", $ret->[Strassen::COORDS()][0]);
	push @list, [$ret->[Strassen::NAME()], BBBikeCGIUtil::my_self_url($qq)];
    }
    if ($sort eq "name") {
	for (@list) {
	    (my $s = $_->[0]) =~ s/(.*\d+\.\d+\s+Uhr)\s+//;
	    my $time = $1;
	    my $zusatz;
	    if ($s =~ s/^((?:[US]-)?(?:Bhf\.|Bahnhof|Hbhf\.|Hbf\.))\s+//) {
		$zusatz = $1;
	    }
	    $_->[0] = $s . ($zusatz ? " ($zusatz)" : "") . ": $time";
	}
	@list = sort { $a->[0] cmp $b->[0] } @list;
    } else { # "time"
	@list = map  { $_->[1] }
	        sort { $a->[0] <=> $b->[0] }
		map  {
		    (my $line = $_->[Strassen::NAME()]) =~ s{^ca\.\s*}{};
		    my($H,$M) = $line =~ m{^(\d+)\.(\d+)};
		    if (!defined $H) {
			warn "Can't parse $line";
		    }
		    my $secs = $H*3600 + $M*60;
		    [$secs, $_];
		} @list
    }
    print join "\n", map { <<EOF } @list;
<li><a href="$_->[1]">$_->[0]</a>
EOF

    print p({-class=>"graphfootnote"}, "Alle Angaben ohne Gewähr. Änderungen sind möglich.");

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

    my $bbbikeurl = $BBBike::BBBIKE_DIRECT_WWW;
    if ($ENV{SERVER_NAME} eq 'radzeit.herceg.de') {
	$bbbikeurl = "http://radzeit.herceg.de/cgi-bin/bbbike.cgi";
    }
    my @args = 
	(-bbbikeurl => $bbbikeurl,
	 -bbbikemail => $BBBike::EMAIL,
	 -scope => "all,region",
	 -queryableroute => 1,
	 -layers => $layers,
	 -center => param("center"),
	 -markerpoint => param("center"),
	 -width => $width,
	 -height => $height,
	 -mapname => "sternfahrt$year",
	 #-debug => 10,
	);
    warn "Args for start_mapserver: <@args>\n" if $DEBUG;
    $ms->start_mapserver(@args);
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

