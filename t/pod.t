#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test::More;
	use Test::Pod;
	1;
    }) {
	print "1..0 # skip no Test::More and/or Test::Pod module\n";
	exit;
    }
}

plan 'no_plan';

chdir "$FindBin::RealBin/.." or die $!;
for (<doc/*.pod README README.english>) {
    pod_file_ok $_
}

__END__
