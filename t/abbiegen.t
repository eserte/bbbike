#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
    $^W = 0; # cease "Possible attempt to separate words with commas"
}

my @test_defs = (
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
		 # straight on; previously caused "nan" because of
		 # floating point inaccuracies
		 [qw/r 0 12960,8246 12918,8232 12792,8190/],
		 [qw/r 0 12792,8190 12918,8232 12960,8246/],
		 # umkehren
		 [qw/u 180 1131,12193 631,13750 1131,12193/],
		 ## XXX TODO: what should be the correct result here?
		 ## XXX 90° does not feel right...
		 [qw/r 90 0,0 0,0 100,0/],
		);

plan tests => @test_defs * 4;

foreach my $def (@test_defs) {
    my $dir = shift @$def;
    my $angle = shift @$def;

    my($got_dir, $got_angle) = Strassen::Util::abbiegen_s(@$def);
    is($got_dir, $dir);
    is_approx_angle($got_angle, $angle);

    my(@p) = map {[split /,/]} @$def;
    ($got_dir, $got_angle) = Strassen::Util::abbiegen(@p);
    is($got_dir, $dir);
    is_approx_angle($got_angle, $angle);
}

sub is_approx_angle {
    my($a1, $a2) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    cmp_ok(abs($a1-$a2), "<", 1);
}

__END__
