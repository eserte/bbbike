#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassenutil-bench.pl,v 1.1 2003/06/21 14:36:03 eserte Exp $
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

Benchmark: running exp, mult, sqr for at least 1 CPU seconds...
       exp:  2 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 934848.96/s (n=978670)
      mult:  1 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 731621.25/s (n=765916)
       sqr:  2 wallclock secs ( 1.05 usr +  0.00 sys =  1.05 CPU) @ 231980.56/s (n=244667)
         Rate  sqr mult  exp
sqr  231981/s   -- -68% -75%
mult 731621/s 215%   -- -22%
exp  934849/s 303%  28%   --
