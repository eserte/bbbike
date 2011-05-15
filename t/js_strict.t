#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeUtil qw(is_in_path);

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

sub is_strict_js ($);

my $js_interpreter = 'js';

if (!is_in_path($js_interpreter)) {
    plan skip_all => "$js_interpreter is missing";
    exit 0;
}

my $res = eval { run_js(q{print("yes!")}) };
if ($res ne "yes!\n") {
    plan skip_all => "It seems that $js_interpreter exists, but it cannot be run...";
    exit 0;
}

my @js_files = (
		"$FindBin::RealBin/../html/bbbike_result.js",
		"$FindBin::RealBin/../html/bbbike_start.js",
		"$FindBin::RealBin/../html/bbbike_util.js",
		"$FindBin::RealBin/../html/google2brb.js",
		"$FindBin::RealBin/../html/sprintf.js",
	       );

plan tests => scalar @js_files;

for my $js_file (@js_files) {
    is_strict_js $js_file;
}

sub is_strict_js ($) {
    my $file = shift;
    my @cmd = ($js_interpreter, "-strict", $file);
    my $all_out;
    my $res = IPC::Run::run(\@cmd, ">&", \$all_out);
    if (!$res) {
	fail "@cmd failed: $?";
    } else {
	ok $all_out eq '', "No error or warning in $file"
	    or diag $all_out;
    }
}

sub run_js {
    my $cmd = shift;
    open my $fh, "-|", $js_interpreter, "-e", $cmd
	or die $!;
    local $/ = undef;
    my $res = <$fh>;
    close $fh
	or die $!;
    $res;
}

__END__
