#!/usr/bin/perl -w
# -*- mode:perl;coding:iso-8859-1; -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib", $FindBin::RealBin);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use Getopt::Long;

use BBBikeTest qw(is_float);
use Strassen::Util qw();

plan tests => 18;

my $do_bench;
GetOptions("bench!" => \$do_bench)
    or die "usage: $0 [-bench]";

# note: additional tests in ext/VectorUtil-Inline/t
use_ok('VectorUtil', 'intersect_rectangles', 'normalize_rectangle',
       'enclosed_rectangle', 'bbox_of_polygon', 'combine_bboxes',
       'distance_point_line', 'project_point_on_line',
       'offset_line',
      );

{
    my @r = (0,0,1,1);
    is_deeply([normalize_rectangle(@r)], [@r], "Rectangle already normalized");
}

{
    my @r = (1,1,0,0);
    is_deeply([normalize_rectangle(@r)], [0,0,1,1], "Both describing points need to be swapped");
}

{
    my @r1 = (13.515757392546, 52.4391675592859,
	      13.5297615625, 52.4326147413096);
    @r1 = normalize_rectangle(@r1);

    {
	my @r2 = (13.520982,52.427651,13.530982,52.43765);
	@r2 = normalize_rectangle(@r2);
	ok(intersect_rectangles(@r1, @r2), "Intersection");
    }

    {
	my @r2 = (13.520982,52.427651,13.530982,52.43260);
	@r2 = normalize_rectangle(@r2);
	ok(!intersect_rectangles(@r1, @r2), "No intersection");
    }

    #use Tk;my$mw=tkinit;my $c=$mw->Scrolled("Canvas")->pack(qw(-fill both -expand 1));$mw->bind("<minus>" => sub { $c->scale("all",0,0,0.5,0.5);$c->configure(-scrollregion=>[$c->bbox("all")]); }); $c->createRectangle(515757,43916,529761,43261);$c->createRectangle(520982,42765,530982,43260);$c->configure(-scrollregion=>[$c->bbox("all")]);MainLoop;
}

{
    my @outer = (0,0,3,3);
    my @inner = (1,1,2,2);
    ok(enclosed_rectangle(@outer, @inner), "enclosed easy case");
}

{
    my @outer = (0,0,3,3);
    my @inner = (-1,-1,2,2);
    ok(!enclosed_rectangle(@outer, @inner), "not enclosed, intersecting");
}

{
    my @outer = (0,0,3,3);
    my @inner = (-2,-2,-1,-1);
    ok(!enclosed_rectangle(@outer, @inner), "not enclosed");
}

{
    is_deeply(bbox_of_polygon([[0,0]]), [0,0,0,0], 'bbox: one-point polygon');
    is_deeply(bbox_of_polygon([[0,0],[10,0],[0,10],[10,10]]), [0,0,10,10], 'bbox: square');
    is_deeply(bbox_of_polygon([[10,10],[10,0],[0,10],[0,0]]), [0,0,10,10], 'bbox: square backwards');
}

{
    is_deeply(combine_bboxes([-2,-3,4,5],
			     [5,6,7,8],
			     [0,0,0,0],
			    ), [-2,-3,7,8], 'combine_bboxes');
}

{
    my @point = (1,1);
    my @line = (0,0, 0,2);
    is_float distance_point_line(@point,@line), 1, 'distance_point_line check';

    my @projected_point = project_point_on_line(@point,@line);
    is_float Strassen::Util::strecke([@point], [@projected_point]), 1, 'project_point_on_line + distance';

    if ($do_bench) {
	require Benchmark;
	Benchmark::cmpthese(-1, {
				 'distance_point_line' => sub {
				     distance_point_line(@point,@line);
				 },
				 'project_point_on_line + distance' => sub {
				     my @projected_point = project_point_on_line(@point,@line);
				     Strassen::Util::strecke([@point], [@projected_point]);
				 }
				});
	## Result on FreeBSD 8.0, perl 5.8.9:
	#                                      Rate project_point_on_line + distance distance_point_line
	# project_point_on_line + distance  86993/s                               --                -31%
	# distance_point_line              125604/s                              44%                  --
    }
}

{
    my @coordlist                = (0,0, 100,0, 200,0);
    my @expected_coordlist_hin   = (0,3, 100,3, 200,3);
    my @expected_coordlist_rueck = (0,-3, 100,-3, 200,-3);
    test_offset_line(\@coordlist, 3, \@expected_coordlist_hin, \@expected_coordlist_rueck, 'offset_line, with 0° polyline');
}

{
    my @coordlist                = (0,0, 100,0, 200,100);
    my @expected_coordlist_hin   = (0,3, 100,3, 200,103);
    my @expected_coordlist_rueck = (0,-3, 100,-3, 200,-3);
    local $TODO = "Expected coords are not correct";
    test_offset_line(\@coordlist, 3, \@expected_coordlist_hin, \@expected_coordlist_rueck, 'offset_line, with 45° polyline');
}

{
    my @coordlist                = (0,0, 100,0, 100,100);
    my @expected_coordlist_hin   = (0,3, 97,3, 97,100);
    my @expected_coordlist_rueck = (0,-3, 103,-3, 103,100);
    test_offset_line(\@coordlist, 3, \@expected_coordlist_hin, \@expected_coordlist_rueck, 'offset_line, with 90° polyline');
}

{
    my @coordlist                = (0,0, 100,0, 0,0);
    my @expected_coordlist_hin   = (0,3, 97,3, 0,3);
    my @expected_coordlist_rueck = (0,-3, 103,-3, 0,-3);
    local $TODO = "Needs work!";
    test_offset_line(\@coordlist, 3, \@expected_coordlist_hin, \@expected_coordlist_rueck, 'offset_line, with 180° polyline');
}

# One test.
sub test_offset_line {
    my($coordlist, $delta, $expected_coordlist_hin, $expected_coordlist_rueck, $testname) = @_;
    my($cl_hin, $cl_rueck) = offset_line($coordlist, $delta, 1, 1);
    my @errors;
    for my $i (0 .. $#$cl_hin) {
	if (abs($cl_hin->[$i] - $expected_coordlist_hin->[$i]) > 0.01) {
	    push @errors, "hin, index=$i: got=$cl_hin->[$i], expected=$expected_coordlist_hin->[$i]\n";
	}
	if (abs($cl_rueck->[$i] - $expected_coordlist_rueck->[$i]) > 0.01) {
	    push @errors, "rueck, index=$i: got=$cl_rueck->[$i], expected=$expected_coordlist_rueck->[$i]\n";
	}
    }
    is "@errors", "", $testname;
}

__END__
