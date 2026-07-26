#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeTest qw(image_ok);

plan 'no_plan';

chdir "$FindBin::RealBin/../images" or die $!;
for (glob("*.*")) {
    next if /\.(svg|xcf)$/;
    next if /\.xpm$/; # XXX xpmtoppm cannot handle the color "opaque"
    image_ok($_, $_);
}

__END__
