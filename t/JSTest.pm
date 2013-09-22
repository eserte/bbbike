# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package JSTest;

use strict;
use vars qw($VERSION @EXPORT $JS_INTERPRETER);
$VERSION = '0.01';

use Exporter 'import';
@EXPORT = qw(
		check_js_interpreter check_js_interpreter_or_exit
		run_js run_js_e run_js_f is_strict_js $JS_INTERPRETER
	   );

use BBBikeUtil qw(is_in_path);

$JS_INTERPRETER = 'js' if !defined $JS_INTERPRETER;

my $redeclaration_warning_seen;

sub check_js_interpreter () {
    is_in_path $JS_INTERPRETER;
}

# Creates a "skip_all" plan and exits if no JS could be found
sub check_js_interpreter_or_exit () {
    if (!check_js_interpreter) {
	Test::More::plan(skip_all => "A js interpreter '$JS_INTERPRETER' is missing");
	exit 0;
    }

    my $res = eval { run_js(q{print("yes!")}) };
    if ($res ne "yes!\n") {
	Test::More::plan(skip_all => "It seems that $JS_INTERPRETER exists, but it cannot be run...");
	exit 0;
    }
}

# Adds one test
sub is_strict_js ($) {
    my $file = shift;
    my @cmd = ($JS_INTERPRETER, "-strict", $file);
    my $all_out;
    require IPC::Run;
    my $res = IPC::Run::run(\@cmd, ">&", \$all_out);
    if (!$res) {
	Test::More::fail("@cmd failed: $?");
    } else {
	Test::More::ok($all_out eq '', "No error or warning in $file")
	    or Test::More::diag($all_out);
    }
}

sub run_js_e ($) {
    my $cmd = shift;
    open my $fh, "-|", $JS_INTERPRETER, "-e", $cmd
	or die $!;
    local $/ = undef;
    my $res = <$fh>;
    close $fh
	or die $!;
    $res;
}

sub run_js_f ($) {
    my $cmd = shift;
    require File::Temp;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(SUFFIX => ".js", UNLINK => 1)
	or die "Can't create temporary file: $!";
    print $tmpfh $cmd;
    close $tmpfh
	or die $!;

    open my $fh, "-|", $JS_INTERPRETER, "-f", $tmpfile
	or die $!;
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
