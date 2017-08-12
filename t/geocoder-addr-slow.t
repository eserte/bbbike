#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Getopt::Long;

my $doit = !!$ENV{BBBIKE_LONG_TESTS};

GetOptions("doit" => \$doit)
    or die "usage: $0 [--doit]\n";

if (!$doit) {
    require Test::More;
    Test::More::plan(skip_all => "Skipped without BBBIKE_LONG_TESTS set");
}
if (!eval { require Devel::Hide; 1 }) {
    require Test::More;
    Test::More::plan(skip_all => "Need Devel::Hide for this test");
}

$ENV{DEVEL_HIDE_PM} = 'Tie::Handle::Offset';
my @cmd = ($^X, "-MDevel::Hide", "$FindBin::RealBin/geocoder-addr.t");
system @cmd; # does all the plan and testing

__END__
