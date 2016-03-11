#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Tests for the javascript function sprintf

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
     ['%.1f',              [12.12345],      '12.1'],
     ['%.1f',              [12.56789],      '12.6'],
     ['%.1f',              [12],            '12.0'],
     ['%.2f',              [12.1],          '12.10'],
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

__END__
