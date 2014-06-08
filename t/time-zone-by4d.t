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

is Time::Zone::By4D::get_timezone(13.5,52.5,time), 'Europe/Berlin', 'in Berlin';
is Time::Zone::By4D::get_timezone(-3.702393,40.417678,time), 'Europe/Berlin', 'in Madrid';
is Time::Zone::By4D::get_timezone(21.011353,52.227799,time), 'Europe/Berlin', 'in Warszawa';
is Time::Zone::By4D::get_timezone(4.839478,45.769439,time), 'Europe/Berlin', 'in Lyon';
is Time::Zone::By4D::get_timezone(16.438637,43.507974,time), 'Europe/Berlin', 'in Split';

{
    eval { Time::Zone::By4D::get_timezone(0,51.5,time) };
    like $@, qr{No support for location};
}

{
    eval { Time::Zone::By4D::get_timezone(13.5,52.5,100_000_000) };
    like $@, qr{Don't know how to get time zone before 1981};
}

__END__
