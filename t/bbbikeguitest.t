#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");
use BBBikeTest qw(check_gui_testing);
check_gui_testing;

$ENV{BBBIKE_GUI_TEST_MODULE} = 'BBBikeGUITest';
chdir "$FindBin::RealBin/.." or die $!;
exec $^X, '-It', 'bbbike', '-public';

__END__
