#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassenutil-bench.pl,v 1.4 2003/10/09 07:26:11 eserte Exp $
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
use strict;
use Test;
use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeUtil qw(sqr);

*doit = (defined &Benchmark::cmpthese ? \&Benchmark::cmpthese : \&Benchmark::timethese);

BEGIN { plan tests => 2 }

my $val = 2;

ok(sqr($val), $val**2);
ok(sqr($val), $val*$val);

doit(-1,
     {"sqr"  => sub { my $res = sqr($val) },
      "exp"  => sub { my $res = $val**2 },
      "mult" => sub { my $res = $val*$val },
     }
    );
__END__

FreeBSD 4.x, Intel Celeron 466 MHz, perl 5.8.0

Benchmark: running exp, mult, sqr for at least 1 CPU seconds...
       exp:  2 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 934848.96/s (n=978670)
      mult:  1 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 731621.25/s (n=765916)
       sqr:  2 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 231980.56/s (n=244667)
         Rate  sqr mult  exp
sqr  231981/s   -- -68% -75%
mult 731621/s 215%   -- -22%
exp  934849/s 303%  28%   --

======================================================================
More results under RedHat 8.0, Intel Pentium 4 2.4MHz, perl 5.8.0

Benchmark: running exp, mult, sqr for at least 1 CPU seconds...
       exp:  1 wallclock secs ( 1.14 usr + -0.03 sys =  1.11 CPU) @ 3389672.97/s (n=3762537)
      mult:  2 wallclock secs ( 1.01 usr + -0.01 sys =  1.00 CPU) @ 4645588.00/s (n=4645588)
       sqr:  1 wallclock secs ( 1.03 usr +  0.00 sys =  1.03 CPU) @ 1027823.30/s (n=1058658)
          Rate  sqr  exp mult
sqr  1027823/s   -- -70% -78%
exp  3389673/s 230%   -- -27%
mult 4645588/s 352%  37%   --
