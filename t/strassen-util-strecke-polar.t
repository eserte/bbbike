#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

sub is_between ($$$;$);

plan tests => 8;

use Strassen::Util;

is_between(Strassen::Util::strecke_polar([13.385900,52.484977], [13.370897,52.485033]),
	   1015, 1017, 'strecke_polar');
is_between(Strassen::Util::strecke_s_polar('13.385900,52.484977', '13.370897,52.485033'),
	   1015, 1017, 'strecke_s_polar');

is_between(Strassen::Util::strecke_s_polar('13.385901,52.484986', '13.385768,52.476229'),
	   973, 975, 'strecke_s_polar, vertical');
is_between(Strassen::Util::strecke_s_polar('13.38588,52.484383', '13.376757,52.478189'),
	   924, 926, 'strecke_s_polar, diagonal');

sub is_between ($$$;$) {
    my($got,$exp_from,$exp_to,$testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res1 = cmp_ok($got, ">=", $exp_from, (defined $testname ? "$testname (lower bound)" : ()));
    my $res2 = cmp_ok($got, "<=", $exp_to,   (defined $testname ? "$testname (upper bound)" : ()));
    $res1 && $res2;
}
