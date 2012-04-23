#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use Strassen::Core;
use Strassen::StrassenNetz;
my $make_net = eval 'use BBBikeXS; 1' ? 'make_net_XS' : 'make_net';

plan 'no_plan';

# Important: to avoid clashes with cached original data
$Strassen::Util::cacheprefix = "test_b_de";

# Net with test data
my $s_net = StrassenNetz->new(Strassen->new("$FindBin::RealBin/data/strassen"));
$s_net->$make_net;

{
    # Duden/Methfessel -> N or 0°
    my @res_dir = $s_net->neighbor_by_direction("8982,8781", "n");
    my @res_angle = $s_net->neighbor_by_direction("8982,8781", 0);
    is scalar(@res_dir), 3, 'three neighbors';
    is $res_dir[0]->{coord}, '9063,8935', 'expected neighbor';
    cmp_ok $res_dir[0]->{delta}, "<", 30, 'expected angle delta';
    is $res_dir[0]->{side}, 'r', 'on right side';
    is_deeply \@res_angle, \@res_dir, 'N and 0 deg the same';
}

{
    # Duden/Methfessel -> NE (for testing side=l)
    my @res = $s_net->neighbor_by_direction("8982,8781", "ne");
    is $res[0]->{coord}, '9063,8935', 'expected neighbor';
    cmp_ok $res[0]->{delta}, "<", 30, 'expected angle delta';
    is $res[0]->{side}, 'l', 'on left side';
}

{
    # Duden/Methfessel -> 90°
    my @res = $s_net->neighbor_by_direction("8982,8781", 90);
    is $res[0]->{coord}, '9076,8783', 'eastern neighbor';
    cmp_ok $res[0]->{delta}, "<", 5, 'small angle delta';
    # as delta is not exactly 0°, side is not exactly ''
}

{
    # Duden/Methfessel -> 270°
    my @res_270     = $s_net->neighbor_by_direction("8982,8781", 270);
    my @res_minus90 = $s_net->neighbor_by_direction("8982,8781", -90);
    is $res_270[0]->{coord}, '8763,8780', 'western neighbor';
    is_deeply \@res_270, \@res_minus90, '270 and -90 is the same';
    cmp_ok $res_270[0]->{delta}, '<', 5, 'small angle delta';
}

{
    # non-existing point -> 
    my @res = $s_net->neighbor_by_direction("9999999,99999999", 0);
    is_deeply \@res, [], 'Non existing point';
}

{
    # non-existing direction 
    eval {$s_net->neighbor_by_direction("9999999,99999999", 'what is this?') };
    like $@, qr{Invalid direction}, 'Trapped invalid direction';
}

__END__
