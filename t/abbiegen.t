#!/usr/bin/perl
# -*- perl -*-

#
# $Id: abbiegen.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
    $^W = 0;
}

BEGIN { plan tests => 48 }

foreach my $def (
		 # ca. 90°
		 [qw/r 88  4281,9706 4281,10112 4650,10125 /],
		 [qw/l 88  975,425 950,1268 -43,1262/],
		 [qw/r 92  1537,1106 618,1100 637,1925/],
		 [qw/l 88  1568,1018 625,962 656,-225/],
		 [qw/r 95  662,1675 725,875 -112,887/],
		 [qw/l 83  1312,14187 1425,12837 2881,12787/],
		 [qw/l 97  -281,13581 1481,13762 1256,14725/],
		 [qw/r 97  -112,13550 1700,13687 1656,12556/],
		 # leichte Kurven
		 [qw/r 4   2362,13718 675,13650 -1268,13700/],
		 [qw/l 13  125,11681 1956,13262 3050,14750/],
		 # Spitzkehren
		 [qw/r 168 1131,12193 631,13750 893,13287/],
		 [qw/l 166 2006,13856 1687,13775 3325,13768/],
		) {
    my $dir = shift @$def;
    my $angle = shift @$def;

    my($got_dir, $got_angle) = Strassen::Util::abbiegen_s(@$def);
    ok($got_dir, $dir);
    ok(approx_angle($got_angle, $angle));

    my(@p) = map {[split /,/]} @$def;
    ($got_dir, $got_angle) = Strassen::Util::abbiegen(@p);
    ok($got_dir, $dir);
    ok(approx_angle($got_angle, $angle));
}

sub approx_angle {
    my($a1, $a2) = @_;
    (abs($a1-$a2) < 2)
}

__END__
