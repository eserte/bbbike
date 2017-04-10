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
	     [22.927952,54.106465,'Suwalki/PL'],
	    ) {
    my($lon,$lat,$place) = @$def;
    is Time::Zone::By4D::get_timezone($lon,$lat,time), 'Europe/Berlin', "in $place";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1402839390), 7200, "time offset in $place (with DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1402839390), '+02:00', "time offset in $place (with DST) for ISO8601";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1387287410), 3600, "time offset in $place (without DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1387287410), '+01:00', , "time offset in $place (without DST) for ISO8601";
}

for my $def (
	     [-0.127233,51.507474,'London'],
	    ) {
    my($lon,$lat,$place) = @$def;
    is Time::Zone::By4D::get_timezone($lon,$lat,time), 'Europe/London', "in $place";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1402839390), 3600, "time offset in $place (with DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1402839390), '+01:00', "time offset in $place (with DST) for ISO8601";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1387287410),    0, "time offset in $place (without DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1387287410), '+00:00', "time offset in $place (without DST) for ISO8601";
}

for my $def (
	     [23.225956,54.414035,'Kalvarija/LT'],
	     [24.106064,56.946987,'Riga'],
	     [24.942913,60.167902,'Helsinki'],
	    ) {
    my($lon,$lat,$place) = @$def;
    is Time::Zone::By4D::get_timezone($lon,$lat,time), 'Europe/Riga', "in $place";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1402839390), 10800, "time offset in $place (with DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1402839390), '+03:00', "time offset in $place (with DST) for ISO8601";
    is Time::Zone::By4D::get_timeoffset($lon,$lat,1387287410),    7200, "time offset in $place (without DST)";
    is Time::Zone::By4D::get_iso8601_timeoffset($lon,$lat,1387287410), '+02:00', "time offset in $place (without DST) for ISO8601";
}

{
    eval { Time::Zone::By4D::get_timezone(-30,51.5,time) };
    like $@, qr{No support for location};
}

{
    eval { Time::Zone::By4D::get_timezone(13.5,52.5,100_000_000) };
    like $@, qr{Don't know how to get time zone before 1981};
}

__END__
