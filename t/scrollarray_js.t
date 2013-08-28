#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Tests for the javascript class ScrollArray

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

use JSTest;

check_js_interpreter_or_exit;


plan 'no_plan';

chdir "$FindBin::RealBin/../html";

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(3); print(sa.get_val(0) + "," + sa.get_val(1) + "," + sa.get_val(2))';
    chomp(my $res = run_js($script));
    is $res, "null,null,null", 'empty array';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(3); print(sa.as_array().join(":"))';
    chomp(my $res = run_js($script));
    is $res, "", 'empty array, as_array';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(3); sa.push("1"); sa.push("2"); print(sa.as_array().join(":"))';
    chomp(my $res = run_js($script));
    is $res, "1:2", 'before fillup, as_array';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(3); sa.push("1"); sa.push("2"); sa.push("3"); print(sa.get_val(0) + "," + sa.get_val(1) + "," + sa.get_val(2))';
    chomp(my $res = run_js($script));
    is $res, "1,2,3", 'before overflow';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(3); sa.push("1"); sa.push("2"); sa.push("3"); print(sa.as_array().join(":"))';
    chomp(my $res = run_js($script));
    is $res, "1:2:3", 'before overflow, as_array';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(2); sa.push("1"); sa.push("2"); sa.push("3"); print(sa.get_val(0) + "," + sa.get_val(1))';
    chomp(my $res = run_js($script));
    is $res, "2,3", 'after overflow';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(2); sa.push("1"); sa.push("2"); sa.push("3"); print(sa.as_array().join(":"))';
    chomp(my $res = run_js($script));
    is $res, "2:3", 'after overflow, as_array';
}

{
    my $script = 'load("scrollarray.js"); sa = new ScrollArray(2); sa.push("1"); sa.push("2"); sa.push("3"); sa.empty(); print(sa.as_array().join(":"))';
    chomp(my $res = run_js($script));
    is $res, "", 'after calling empty()';
}

__END__
