#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";

use Cwd qw(realpath);
use File::Basename qw(dirname);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 3 + 7 + 6;

use_ok 'BBBikeUtil', 'bbbike_root';

my $bbbike_root = bbbike_root();
ok(-d $bbbike_root, 'Got a bbbike root directory');
is($bbbike_root, realpath(dirname(dirname(realpath($0)))), "Expected value for bbbike root (t is subdirectory)");

{
    is(BBBikeUtil::s2hms(0),     "0:00:00", "s2hms checks");
    is(BBBikeUtil::s2hms(1),     "0:00:01");
    is(BBBikeUtil::s2hms(59),    "0:00:59");
    is(BBBikeUtil::s2hms(60),    "0:01:00");
    is(BBBikeUtil::s2hms(3599),  "0:59:59");
    is(BBBikeUtil::s2hms(3600),  "1:00:00");
    is(BBBikeUtil::s2hms(36000),"10:00:00");
}

{
    is(BBBikeUtil::m2km(1234,3,2), '1.230 km', 'm2km checks');
    is(BBBikeUtil::m2km(1239,3,2), '1.230 km', 'kaufmaennisches Runden not done here'); # XXX maybe it should?
    is(BBBikeUtil::m2km(1239,3),   '1.239 km', 'without sigdig');
    is(BBBikeUtil::m2km(1239,2),   '1.24 km',  'without sigdig, rounding by sprintf');
    is(BBBikeUtil::m2km(5,3,2),    '0.005 km', 'significant though below two digits');
    is(BBBikeUtil::m2km(50,3,1),   '0.050 km');
}

__END__
