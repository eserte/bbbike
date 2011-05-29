#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
BEGIN { push @INC, "$FindBin::RealBin/../../../lib" } # at end!!!
use VectorUtil;
use VectorUtil::Inline;

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
}

BEGIN { plan tests => 14+10000 }

my @p;

my $ref1 = \&VectorUtil::Inline::distance_point_line;
my $ref2 = \&VectorUtil::distance_point_line;

# XS loading worked:
ok("$ref1", "$ref2");

for my $p ([1,2,3,4,5,6],
	   [100,200,30,4000,52,61]) {
    my @p = @$p;
    ok(VectorUtil::distance_point_line_PP(@p),
       VectorUtil::distance_point_line_XS(@p));
    ok(VectorUtil::distance_point_line_PP(@p),
       VectorUtil::distance_point_line(@p));
}
{
    my @p = map { rand(40000)-20000 } (1..8);
    ok(VectorUtil::vector_in_grid_PP(@p),
       VectorUtil::vector_in_grid_XS(@p));
    ok(VectorUtil::vector_in_grid_PP(@p),
       VectorUtil::vector_in_grid(@p));
}

{
    # dealing with floating point inaccuracies (problem pointed by
    # wosch)
    my $gridx1 = 14.37 + 1.77635683940025e-15;
    ok(VectorUtil::vector_in_grid_XS(14.36346, 53.27772, 14.38895, 53.27772, $gridx1, 53.27, 14.38, 53.28),
       VectorUtil::vector_in_grid_PP(14.36346, 53.27772, 14.38895, 53.27772, $gridx1, 53.27, 14.38, 53.28));
}

{
    my($gridx1,$gridy1,$gridx2,$gridy2) = (1,1,2,2);
    for my $sub (\&VectorUtil::vector_in_grid_PP,
		 \&VectorUtil::vector_in_grid_XS,
		) {
	ok !$sub->((0.99999999,0.99999999,2.00000001,0.99999999),
		   $gridx1,$gridy1,$gridx2,$gridy2
		  );
	ok $sub->((0.99999999,0.99999999,1.99999999,1..0000001),
		  $gridx1,$gridy1,$gridx2,$gridy2
		 ); # ret=6;
    SKIP: {
	    my $dbl_epsilon = eval {
		require POSIX;
		POSIX::DBL_EPSILON();
	    };
	    skip "DBL_EPSILON not defined",1 if !$dbl_epsilon;
	    ok $sub->(($gridx1-$dbl_epsilon,$gridy1-$dbl_epsilon,$gridx1+$dbl_epsilon,$gridy2+$dbl_epsilon*2),
		      $gridx1,$gridy1,$gridx2,$gridy2
		     ); # ret=1;
	}
    }
}

for (1..5000) {
    my @p = map { rand(40000)-20000 } (1..6);
    my $diff = abs(VectorUtil::distance_point_line_PP(@p) -
		   VectorUtil::distance_point_line_XS(@p));
    ok($diff < 5e12, 1,
       "Failed with the values: @p, difference is $diff");
}

for (1..5000) {
    my @p = map { rand(40000)-20000 } (1..8);
    ok(VectorUtil::vector_in_grid_PP(@p),
       VectorUtil::vector_in_grid_XS(@p),
       "Failed for values @p");
}

if (@ARGV && $ARGV[0] eq '-bench') {
    my @p = map { rand(2000)-1000 } (1..6);
    require Benchmark;
    Benchmark::cmpthese
	    (-2,
	     {
	      'perl' => sub {
		  VectorUtil::distance_point_line(@p);
	      },
	      'c' => sub {
		  VectorUtil::Inline::distance_point_line(@p);
	      }
	     });
}

__END__

Benchmark: running c, perl for at least 2 CPU seconds...
         c:  5 wallclock secs ( 2.09 usr +  0.00 sys =  2.09 CPU) @ 323369.23/s (n=674528)
      perl:  3 wallclock secs ( 2.03 usr +  0.00 sys =  2.03 CPU) @ 19653.42/s (n=39921)
         Rate  perl     c
perl  19653/s    --  -94%
c    323369/s 1545%    --
