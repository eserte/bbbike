#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

sub is_between ($$$;$);

plan tests => 9;

use_ok 'Strassen::Util';

is(Strassen::Util::strecke([0,0],[1000,0]), 1000, 'strecke');
is(Strassen::Util::strecke([0,0],[0,1000]), 1000);
is(Strassen::Util::strecke_s('0,0','1000,0'), 1000, 'strecke_s');
is(Strassen::Util::strecke_s('0,0','0,1000'), 1000);

is_between(Strassen::Util::strecke_polar([13.385900,52.484977], [13.370897,52.485033]),
	   1015, 1017, 'strecke_polar');
is_between(Strassen::Util::strecke_s_polar('13.385900,52.484977', '13.370897,52.485033'),
	   1015, 1017, 'strecke_s_polar');

sub is_between ($$$;$) {
    my($got,$exp_from,$exp_to,$testname) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res1 = cmp_ok($got, ">=", $exp_from, (defined $testname ? "$testname (lower bound)" : ()));
    my $res2 = cmp_ok($got, "<=", $exp_to,    (defined $testname ? "$testname (upper bound)" : ()));
    $res1 && $res2;
}

__END__
