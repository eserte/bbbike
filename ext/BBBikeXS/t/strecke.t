#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strecke.t,v 1.6 2003/04/13 15:56:21 eserte Exp $
# Author: Slaven Rezic
#

use strict;
BEGIN {
    # Don't use "use lib", so we are sure that the real BBBikeXS.pm/so is
    # loaded first
    push @INC, qw(../.. ../../lib);
}
use Strassen::Util;
use BBBikeXS;
use Benchmark;
use Data::Dumper;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 12 }

my $ref_wo = \&Strassen::Util::strecke; $ref_wo = "$ref_wo";
my $ref_xs = \&Strassen::Util::strecke_XS; $ref_xs = "$ref_xs";
my $ref_pp = \&Strassen::Util::strecke_PP; $ref_pp = "$ref_pp";
ok($ref_wo, $ref_xs);
ok($ref_wo ne $ref_pp);

my $ref_wo2 = \&Strassen::Util::strecke_s; $ref_wo2 = "$ref_wo2";
my $ref_xs2 = \&Strassen::Util::strecke_s_XS; $ref_xs2 = "$ref_xs2";
my $ref_pp2 = \&Strassen::Util::strecke_s_PP; $ref_pp2 = "$ref_pp2";
ok($ref_wo2, $ref_xs2);
ok($ref_wo2 ne $ref_pp2);

my @tests = ([[1000,1234],[1234,42]],
	     [[0,0],[0,100000]],
	     [[-1000,-123],[-1234,+123]],
	     [[rand(100000),rand(100000)],[rand(100000),rand(100000)]],
	    );
for (@tests) {
    my($p1, $p2) = @$_;

    ok(abs(Strassen::Util::strecke_PP($p1, $p2) -
	   Strassen::Util::strecke_XS($p1, $p2)) < 1, 1,
       "With the values " . Dumper($p1, $p2). ": PP=" . Strassen::Util::strecke_PP($p1, $p2) . ", XS=" . Strassen::Util::strecke_XS($p1, $p2)
      );

    my $s1 = join(",",@$p1);
    my $s2 = join(",",@$p2);
    ok(abs(Strassen::Util::strecke_s_PP($s1,$s2) -
	   Strassen::Util::strecke_s_XS($s1,$s2)) < 1, 1,
       "With the values " . Dumper($s1, $s2). ": PP=" . Strassen::Util::strecke_s_PP($s1, $s2) . ", XS=" . Strassen::Util::strecke_s_XS($s1, $s2)
      );
}

{
    my($p1, $p2) = @{$tests[0]};
    my $s1 = join(",",@$p1);
    my $s2 = join(",",@$p2);
    timethese(-1,
	      {'perl'   => sub { Strassen::Util::strecke_PP($p1, $p2) },
	       'xs'     => sub { Strassen::Util::strecke_XS($p1, $p2) },
	       'perl_s' => sub { Strassen::Util::strecke_s_PP($s1, $s2) },
	       'xs_s'   => sub { Strassen::Util::strecke_s_XS($s1, $s2) },
	      });
}

__END__
