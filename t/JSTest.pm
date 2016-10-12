# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012,2015,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package JSTest;

use strict;
use vars qw($VERSION @EXPORT @JS_INTERPRETERS);
$VERSION = '0.03';

use Exporter 'import';
@EXPORT = qw(
		check_js_interpreter check_js_interpreter_or_exit
		run_js run_js_e run_js_f is_strict_js
	   );

use BBBikeUtil qw(is_in_path);

if ($ENV{BBBIKE_TEST_JS_INTERPRETER}) {
    @JS_INTERPRETERS = $ENV{BBBIKE_TEST_JS_INTERPRETER};
} else {
    @JS_INTERPRETERS = qw(js rhino spidermonkey);
}

my $redeclaration_warning_seen;
my $js_interpreter_binary;
my $js_interpreter_impl;

sub check_js_interpreter () {
    for my $candidate (@JS_INTERPRETERS) {
	my $candidate_path = is_in_path $candidate;
	if (defined $candidate_path) {
	    # Try to guess implementation
	    my $out = `$candidate --help 2>&1`; # XXX depend on IPC::Run here?
	    if ($out =~ m{^JavaScript-C}) {
		$js_interpreter_binary = $candidate_path;
		$js_interpreter_impl = 'spidermonkey';
	    } elsif ($out =~ m{\Qjava org.mozilla.javascript.tools.shell.Main}) {
		$js_interpreter_binary = $candidate_path;
		$js_interpreter_impl = 'rhino';
	    } elsif ($out =~ m{NODE_PATH}) {
		# XXX Test scripts are currently not compatible with nodejs:
		# external file loading does not work (no load(), require() cannot be used),
		# with is not allowed, there's no print() (instead process.stdout.write() has
		# to be used
		#$js_interpreter_impl = 'nodejs';
	    } else {
		$js_interpreter_binary = $candidate_path;
		$js_interpreter_impl = 'unknown';
	    }
	    return 1 if $js_interpreter_impl;
	}
    }
    0;
}

# Creates a "skip_all" plan and exits if no JS could be found
sub check_js_interpreter_or_exit () {
    if (!check_js_interpreter) {
	Test::More::plan(skip_all => "A js interpreter (candidate/s: @JS_INTERPRETERS) is missing");
	exit 0;
    }

    my $js_prog;
    if ($js_interpreter_impl eq 'nodejs') {
	$js_prog = q{process.stdout.write("yes!\n")};
    } else {
	$js_prog = q{print("yes!")};
    }

    my $res = eval { run_js($js_prog) };
    if ($res ne "yes!\n") {
	Test::More::plan(skip_all => "It seems that a js interpreter $js_interpreter_binary exists, but it cannot be run...");
	exit 0;
    }
}

# Adds one test
sub is_strict_js ($) {
    my $file = shift;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    my @cmd = ($js_interpreter_binary, ($js_interpreter_impl eq 'nodejs' ? '--use_strict' : '-strict'), $file);
    my $all_out;
    require IPC::Run;
    my $res = IPC::Run::run(\@cmd, ">&", \$all_out);
    if (!$res) {
	Test::More::fail("@cmd failed: $?")
	    or Test::More::diag($all_out);
    } else {
	Test::More::ok($all_out eq '', "No error or warning in $file")
	    or Test::More::diag($all_out);
    }
}

sub run_js_e ($) {
    my $cmd = shift;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    open my $fh, "-|", $js_interpreter_binary, "-e", $cmd
	or die $!;
    local $/ = undef;
    my $res = <$fh>;
    close $fh
	or die $!;
    $res;
}

sub run_js_f ($) {
    my $cmd = shift;
    local $Test::Builder::Level = $Test::Builder::Level+1;
    require File::Temp;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => ".js", UNLINK => 1)
	or die "Can't create temporary file: $!";
    print $tmpfh $cmd;
    close $tmpfh
	or die $!;

    my @cmd = $js_interpreter_binary;
    if ($js_interpreter_impl ne 'nodejs') {
	push @cmd, '-f';
    }
    push @cmd, $tmpfile;
    open my $fh, '-|', @cmd
	or die "Error while running @cmd: $!";
    local $/ = undef;
    my $res = <$fh>;
    close $fh
	or die $!;

    unlink $tmpfile;

    $res;
}

# Default to -f, because rhino, Debian's default js interpreter,
# cannot handle whitespace in the -e argument correctly. See
# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=661277
# FreeBSD's spidermonkey is fine.
# 
# The rhino problem was fixed in the debian version 1.7R4-1
BEGIN { *run_js = \&run_js_f }

1;

__END__
