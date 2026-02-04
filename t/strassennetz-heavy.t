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

use BBBikeTest qw(using_bbbike_test_data);

plan 'no_plan';

using_bbbike_test_data;

# Net with test data
my $s = Strassen->new("strassen");
my $s_net = StrassenNetz->new($s);
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
    # Andreas/Singer (was buggy)
    my @res = $s_net->neighbor_by_direction('12295,12197', 'w');
    is $res[0]->{coord}, '12084,12235';
    cmp_ok $res[0]->{delta}, '<', 30;
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

{
    # Katzbach/Monumenten -> Katzbach/Kreuzberg: result is Katzbach/Yorck
    my @res = $s_net->next_neighbors("8598,9074", "8598,9264");
    is $res[0]->{coord}, '8595,9495', 'best neighbor is Katzback/Yorck';
    cmp_ok $res[0]->{delta}, '<', 5, 'small angle delta';

    # next best is to the right (because of the slant of Kreuzbergstr)
    is $res[1]->{coord}, '8769,9290', 'next best is Kreuzberg/Moeckern';
    is $res[1]->{side}, 'r', 'to the right';

    # next best is to the left
    is $res[2]->{coord}, '8475,9240', 'next best is Kreuzberg curve';
    is $res[2]->{side}, 'l', 'to the left';

    # worst is backwards
    is $res[3]->{coord}, '8598,9074', 'backwards';
    cmp_ok $res[3]->{delta}, '>', 170, 'large angle delta';
}

{
    # Yorckstr. -> towards Katzbachstr.
    my($res) = $s_net->next_neighbors('8192,9619', '8595,9495');
    is $res->{coord}, '8648,9526', 'continuing on Yorck';
}

{
    # Kreuzbergstr
    my($res) = $s_net->next_neighbors('8475,9240', '8598,9264');
    is $res->{coord}, '8769,9290', 'continuing on Kreuzbergstr.';
}

{
    # Umfahrung Ostkreuz
    my($res) = $s_net->next_neighbors('14794,10844', '15263,10747');
    is $res->{coord}, '15279,10862';
    is $res->{side}, 'l';
}

{
    my $radwege_exact = Strassen->new("radwege_exact");
    my $cyclepath_net = StrassenNetz->new($s);
    $cyclepath_net->make_net_cyclepath($radwege_exact);
    my $cyclepath_ignore_RW1_net = StrassenNetz->new($s);
    $cyclepath_ignore_RW1_net->make_net_cyclepath($radwege_exact, IgnoreCyclePath => 1);
    for my $def (
	[$cyclepath_net,            'normal net'],
	[$cyclepath_ignore_RW1_net, 'ignore cycle path net'],
    ) {
	my($net, $name) = @$def;
	is $net->{Net}->{"10020,11262"}->{"9984,11270"}, 'H_Bus', "$name: secondary street with bus lane";
	is $net->{Net}->{"9984,11270"}->{"10020,11262"}, 'H',     "$name: secondary street without anything";
	is $net->{Net}->{"9229,8785"}->{"9227,8890"},    'H',     "$name: primary street without anything (still \"H\" is used)";
	is $net->{Net}->{"9133,9343"}->{"9104,9262"},    'N',     "$name: residential street";
	is $net->{Net}->{"9199,11166"}->{"9162,11286"},  'H_RW',  "$name: secondary street with cycle path or lane (here: lane)";
	if ($net == $cyclepath_net) {
	    is $net->{Net}->{"22162,1067"}->{"22208,1103"},  'H_RW',  "$name: secondary street with cycle path or lane (here: path)";
	} else {
	    is $net->{Net}->{"22162,1067"}->{"22208,1103"},  'H',  "$name: secondary street with cycle lane";
	}
    }
}

__END__
