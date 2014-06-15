#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

use Test::More 'no_plan';

use Time::Zone::By4D;

for my $def (
	     [13.5,52.5,'Berlin'],
	     [-3.702393,40.417678,'Madrid'],
	     [21.011353,52.227799,'Warszawa'],
	     [4.839478,45.769439,'Lyon'],
	     [16.438637,43.507974,'Split'],
	    ) {
    my($lon,$lat,$place) = @$def;
    is Time::Zone::By4D::get_timezone($lon,$lat,time), 'Europe/Berlin', "in $place";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1402839390), 7200, "time offset in $place (with DST)";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1387287410), 3600, "time offset in $place (without DST)";
}

{
    eval { Time::Zone::By4D::get_timezone(0,51.5,time) };
    like $@, qr{No support for location};
}

{
    eval { Time::Zone::By4D::get_timezone(13.5,52.5,100_000_000) };
    like $@, qr{Don't know how to get time zone before 1981};
}

__END__
