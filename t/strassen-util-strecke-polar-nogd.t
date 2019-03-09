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

$ENV{DEVEL_HIDE_PM} = 'Geo::Distance::XS Geo::Distance';
my @cmd = ($^X, "-MDevel::Hide", "$FindBin::RealBin/strassen-util-strecke-polar.t");
system @cmd; # does all the plan and testing

__END__
