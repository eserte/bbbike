#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutil.t,v 1.5 2002/08/07 22:47:41 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/../../../lib";
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

BEGIN { plan tests => 2+10000 }

my @p;

for my $p ([1,2,3,4,5,6],
	   [100,200,30,4000,52,61]) {
    my @p = @$p;
    ok(VectorUtil::distance_point_line(@p),
       VectorUtil::Inline::distance_point_line(@p));
}
for (1..10000) {
    my @p = map { rand(40000)-20000 } (1..6);
    my $diff = abs(VectorUtil::distance_point_line(@p) -
		   VectorUtil::Inline::distance_point_line(@p));
    ok($diff < 5e12, 1,
       "Failed with the values: @p, difference is $diff");
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
