#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");
use BBBikeTest qw(check_gui_testing);
check_gui_testing;
use Time::HiRes ();

$ENV{BBBIKE_GUI_TEST_MODULE} = 'BBBikeGUITest';
chdir "$FindBin::RealBin/.." or die $!;
$ENV{LC_ALL} = $ENV{LANG} = 'en_US.UTF-8';
$ENV{BBBIKE_TEST_STARTTIME} = Time::HiRes::time();
exec $^X, '-It', 'bbbike', '-public';

__END__
