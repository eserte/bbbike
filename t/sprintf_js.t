#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Tests for the javascript function sprintf

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeUtil qw(is_in_path);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

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

my @tests =
    (['Nothing',           [],              'Nothing'],
     ['Hello %s world',    ['cruel'],       'Hello cruel world'],
     ['Hello %s %s world', ['cruel'],       undef,              ERROR => 1],
     ['%s',                ['%s'],          '%s'],
     ['%s%s%s',            [qw(A B C)],     'ABC'],
     ['%d',                ['non-numeric'], '0'],
     ['%02d',              ['0'],           '00'],
     ['%04d',              ['10'],          '0010'],
     ['%4d',               ['10'],          '  10',             TODO => 'pad fallback to space?'],
     ['%-4s',              ['10'],          '10  ',             TODO => 'pad fallback to space?'],
    );

plan tests => scalar @tests;

chdir "$FindBin::RealBin/../html";

for my $test (@tests) {
    my($fmt, $in, $out, %args) = @$test;
    my @in = @$in;

    local $TODO;
    if ($args{TODO}) { $TODO = $args{TODO} }

    my $res = eval {
	run_js(qq{function alert(msg) { quit(1); } load("sprintf.js"); print(sprintf("$fmt"} . join("", map { qq{, "$_"} } @in) . q{))});
    };
    if ($@) {
	if ($args{ERROR}) {
	    pass 'Error expected';
	    next;
	} else {
	    fail "Unexpected error: $@";
	    next;
	}
    } elsif ($args{ERROR}) {
	fail "Expected error, but got no";
	next;
    }

    chomp $res;
    if (ref $out eq 'Regexp') {
	like $res, $out;
    } else {
	is $res, $out;
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
