#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use Benchmark;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
use strict;
use Getopt::Long;

my $usexs = 0;
my $usecache = 0;

if (!GetOptions("xs!" => \$usexs,
		"cache!" => \$usecache,
	       )) {
    die "usage: $0 [-[no]xs] [-[no]cache] iter";
}

if ($usexs) {
    eval 'use BBBikeXS'; die $@ if $@;
}

my $s = MultiStrassen->new("strassen", "landstrassen", "landstrassen2");
my $iter = shift || 10;

timethese($iter,
	  {
	   makenet => sub {
	       my $net = StrassenNetz->new($s);
	       $net->make_net_classic(UseCache => $usecache);
	   },
	  });
__END__

Results under RedHat 8.0, Intel Pentium 4 2.4MHz, perl 5.8.0

With BBBikeXS, without cache:
Benchmark: timing 10 iterations of makenet...
   makenet:  6 wallclock secs ( 6.29 usr +  0.08 sys =  6.37 CPU) @  1.57/s (n=10)

Without BBBikeXS, without cache:
Benchmark: timing 10 iterations of makenet...
   makenet: 12 wallclock secs (11.29 usr +  0.07 sys = 11.36 CPU) @  0.88/s (n=10)

With BBBikeXS, with cache (I think UseCache is ignored in this case):
Benchmark: timing 10 iterations of makenet...
   makenet:  6 wallclock secs ( 6.29 usr +  0.05 sys =  6.34 CPU) @  1.58/s (n=10)

Without BBBikeXS, with cache:
Benchmark: timing 10 iterations of makenet...
   makenet:  6 wallclock secs ( 5.83 usr +  0.11 sys =  5.94 CPU) @  1.68/s (n=10)
