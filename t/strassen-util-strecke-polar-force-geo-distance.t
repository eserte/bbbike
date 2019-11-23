#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Getopt::Long;

if (!eval { require Devel::Hide; 1 }) {
    require Test::More;
    Test::More::plan(skip_all => "Need Devel::Hide for this test");
}

if (!eval { require Geo::Distance; 1 }) {
    require Test::More;
    Test::More::plan(skip_all => "Useless to run this test without Geo::Distance installed");
}

if ($INC{"GIS/Distance.pm"}) {
    require Test::More;
    Test::More::plan(skip_all => "Geo::Distance implemented with GIS::Distance --- cannot run this test");
}

$ENV{DEVEL_HIDE_PM} = 'GIS::Distance GIS::Distance::Fast';
my @cmd = ($^X, "-MDevel::Hide", "$FindBin::RealBin/strassen-util-strecke-polar.t");
system @cmd; # does all the plan and testing

__END__
