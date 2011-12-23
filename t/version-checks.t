#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

sub banner ($);

plan 'no_plan';

pass 'Version checks following'; # This is a dummy test to force at least one test

if (eval { require Cairo; 1 }) {
    cmp_ok(Cairo->version, ">=", 10808, 'Cairo >= 1.8.8')
	or banner <<EOF;
libcairo2 version @{[ Cairo->version_string ]} detected, but
at least 1.8.8 should be installed because of rendering
problems (e.g. missing png transparency).
EOF
}

sub banner ($) {
    my $msg = shift;
    diag "*" x 70;
    for (split /\n/, $msg) {
	diag "* $_";
    }
    diag "*" x 70;
}

__END__
