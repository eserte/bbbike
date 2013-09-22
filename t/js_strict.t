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
	use IPC::Run;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no IPC::Run and/or Test::More modules\n";
	exit;
    }
}

use JSTest;

check_js_interpreter_or_exit;

my @js_files = (
		"$FindBin::RealBin/../html/bbbike_result.js",
		"$FindBin::RealBin/../html/bbbike_start.js",
		"$FindBin::RealBin/../html/bbbike_util.js",
		"$FindBin::RealBin/../html/sprintf.js",
	       );

plan tests => scalar @js_files;

for my $js_file (@js_files) {
    is_strict_js $js_file;
}

__END__
