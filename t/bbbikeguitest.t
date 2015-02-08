#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

if (!$ENV{BBBIKE_TEST_GUI}) {
    require Test::More;
    Test::More::plan(skip_all => 'Set BBBIKE_TEST_GUI to run test');
}

use FindBin;
$ENV{BBBIKE_GUI_TEST_MODULE} = 'BBBikeGUITest';
chdir "$FindBin::RealBin/.." or die $!;
exec $^X, '-It', 'bbbike', '-public';

__END__
