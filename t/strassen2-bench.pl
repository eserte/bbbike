#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen2-bench.pl,v 1.4 2003/10/09 07:26:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Compare some splitting methods for a bbd line

use Benchmark;
use strict;
use Test;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use Strassen::Util;
use BBBikeUtil qw(sqr);

*doit = (defined &Benchmark::cmpthese ? \&Benchmark::cmpthese : \&Benchmark::timethese);

BEGIN { plan tests => 2 }

my $coord1_s = "1234,5678";
my $coord2_s = "5678,1234";
my $coord1_a = [1234,5678];
my $coord2_a = [5678,1234];
#  my $coord1_i = pack("l2", 1234, 5678);
#  my $coord2_i = pack("l2", 5678, 1234);

ok(Strassen::Util::strecke($coord1_a, $coord2_a),
   Strassen::Util::strecke_s($coord1_s, $coord2_s));
ok(Strassen::Util::strecke($coord1_a, $coord2_a),
   strecke_s2($coord1_s, $coord2_s));
#  ok(Strassen::Util::strecke($coord1_a, $coord2_a),
#     Strassen::Util::strecke_i($coord1_i, $coord2_i));

doit(-1,
     {'coord_s'  => sub { Strassen::Util::strecke_s($coord1_s, $coord2_s) },
      'coord_s2' => sub { strecke_s2($coord1_s, $coord2_s) },
      'coord_a'  => sub { Strassen::Util::strecke($coord1_a, $coord2_a) },
#      'coord_i'  => sub { Strassen::Util::strecke_i($coord1_i, $coord2_i) },
     }
    );

sub strecke_s2 {
    my $inx1 = index($_[0], ",");
    my $inx2 = index($_[1], ",");
    CORE::sqrt(sqr(substr($_[0],0,$inx1)-substr($_[1],0,$inx2)) +
	       sqr(substr($_[0],$inx1+1)-substr($_[1],$inx2+1)));
}

__END__

Ergebnisse mit perl5.8.0:

Benchmark: running coord_a, coord_s, coord_s2 for at least 1 CPU seconds...
   coord_a:  1 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 55352.36/s (n=57947)
   coord_s:  1 wallclock secs ( 1.04 usr +  0.00 sys =  1.04 CPU) @ 27883.79/s (n=28973)
  coord_s2:  1 wallclock secs ( 1.07 usr +  0.00 sys =  1.07 CPU) @ 39564.15/s (n=42346)
            Rate  coord_s coord_s2  coord_a
coord_s  27884/s       --     -30%     -50%
coord_s2 39564/s      42%       --     -29%
coord_a  55352/s      99%      40%       --

Mit dem neueren Strassen::Util::strecke_s (**2 statt sqr) bekomme ich andere
Ergebnisse:

Benchmark: running coord_a, coord_s, coord_s2 for at least 1 CPU seconds...
   coord_a:  1 wallclock secs ( 1.02 usr +  0.00 sys =  1.02 CPU) @ 67236.15/s (n=68812)
   coord_s:  1 wallclock secs ( 1.02 usr +  0.00 sys =  1.02 CPU) @ 46772.76/s (n=47869)
  coord_s2:  1 wallclock secs ( 1.07 usr +  0.00 sys =  1.07 CPU) @ 39564.15/s (n=42346)
            Rate coord_s2  coord_s  coord_a
coord_s2 39564/s       --     -15%     -41%
coord_s  46773/s      18%       --     -30%
coord_a  67236/s      70%      44%       --

======================================================================
More results under RedHat 8.0, Intel Pentium 4 2.4MHz, perl 5.8.0

Benchmark: running coord_a, coord_s, coord_s2 for at least 1 CPU seconds...
   coord_a:  1 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 400773.27/s (n=404781)
   coord_s:  1 wallclock secs ( 1.11 usr + -0.01 sys =  1.10 CPU) @ 284350.00/s (n=312785)
  coord_s2:  2 wallclock secs ( 1.01 usr +  0.00 sys =  1.01 CPU) @ 227103.96/s (n=229375)
             Rate coord_s2  coord_s  coord_a
coord_s2 227104/s       --     -20%     -43%
coord_s  284350/s      25%       --     -29%
coord_a  400773/s      76%      41%       --
