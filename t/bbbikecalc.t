#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use BBBikeCalc ();

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 4;

is BBBikeCalc::localize_direction('E', 'en'), 'east';
is BBBikeCalc::localize_direction('E', 'de'), 'Osten';

is BBBikeCalc::localize_direction_abbrev('E', 'en'), 'E';
is BBBikeCalc::localize_direction_abbrev('E', 'de'), 'O';

__END__
