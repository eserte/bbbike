#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

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

plan tests => 3;

use_ok 'BBBikeUtil', 'bbbike_root';

my $bbbike_root = bbbike_root();
ok(-d $bbbike_root, 'Got a bbbike root directory');
is(realpath(dirname(dirname($0))), $bbbike_root, "Expected value for bbbike root (t is subdirectory)");

__END__
