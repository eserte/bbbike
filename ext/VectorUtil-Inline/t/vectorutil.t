#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutil.t,v 1.7 2003/08/30 20:32:36 eserte Exp $
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

BEGIN { plan tests => 7+10000 }

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
