# -*- perl -*-

#
# $Id: GpsmanDataAmpeln.pm,v 1.2 2003/08/24 23:25:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package main;

use strict;
use vars qw($VERSION @realcoords %ampeln);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use GPS::GpsmanData qw(TYPE_ROUTE);
use Karte;
use Ampelschaltung;

my $counter = "AA";
my $route_suffix = "0";

sub make_ampel_route {
    my $last;
    my $lsa = new Ampelschaltung2;
    $lsa->open("/home/e/eserte/src/bbbike/misc/ampelschaltung.txt")
	or die "Can't open ampelschaltung"; # XXX do not hardcode
    my %points = $lsa->create_points;
#XXX use also data/ampelschaltung information

    my @data;
    foreach my $i (0 .. $#realcoords) {
	my $xy = $realcoords[$i];
	my $p = "$xy->[0],$xy->[1]";
	if (exists $ampeln{$p} || $i == 0 || $i == $#realcoords) {
	    if (defined $last and $p eq $last) {
		next;
	    } else {
		$last = $p;
	    }
	    my $aver_green = "";
	    my $aver_cycle = "";
	    if (exists $points{$p}) {
		my $sum_green = 0;
		my $sum_cycle = 0;
		my $n_green = 0;
		my $n_cycle = 0;
		for my $entry (@{ $points{$p} }) {
##XXX Direction!
#  		    if ($entry->{Green}) {
#  			$sum_green += $entry->{Green};
#  			$n_green++;
#  		    }
		    if ($entry->{Cycle}) {
			$sum_cycle += $entry->{Cycle};
			$n_cycle++;
		    }
		}
		if ($n_green) {
		    $aver_green = $sum_green/$n_green;
		}
		if ($n_cycle) {
		    $aver_cycle = $sum_cycle/$n_cycle;
		}
	    }
	    my $ident = sprintf("%2d %2d%3s%s", $aver_green, $aver_cycle,
				$counter, $route_suffix);
	    my $wpt = GPS::Gpsman::Waypoint->new;
	    $wpt->Ident($ident);
	    my($px,$py) = $Karte::Polar::obj->standard2map($xy->[0],$xy->[1]);
	    $wpt->Latitude($py);
	    $wpt->Longitude($px);
	    push @data, $wpt;
	    $counter++;
	}
    }
    my $route = GPS::GpsmanData->new;
    $route->Type(TYPE_ROUTE);
    $route->Name("LSA $route_suffix");
    $route->PositionFormat("DDD");
    $route->Track(\@data);
    warn $route->as_string;
    open(OUT, ">/tmp/route.rte");
    print OUT $route->as_string;
    close OUT;

    $route_suffix++;
    if ($route_suffix >= 10) {
	$route_suffix = "A";
    }
}

1;

__END__
