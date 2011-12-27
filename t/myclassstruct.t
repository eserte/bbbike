#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 19;

{
    {
	package A;
	use myclassstruct qw(a b c);
    }
    {
	package SubA;
	use myclassstruct qw(d);
	use base 'A';
    }

    my $A = A->new;
    isa_ok $A, 'A';
    is $A->a, undef, 'Unset member is undef';
    is $A->a(123), $A, 'Mutator access returns object';
    is $A->a, 123, 'Accessor returns correct value';
    eval { $A->d };
    isnt $@, '', 'Invalid accessor';
    is $A->a(1)->b(2)->c(3), $A;
    is $A->a, 1, 'Return value after chained usage';
    is $A->b, 2;
    is $A->c, 3;

    my $B = A->new(a => 3, b => 2, c => 1);
    isa_ok $B, 'A';
    is $B->a, 3, 'Initialization worked';
    is $B->b, 2;
    is $B->c, 1;

    my $C = eval { A->new(d => "invalid") };
    like $@, qr{Can't locate object method}, 'Method is invalid';
    ok !defined $C, 'No object constructed';

    my $SubA = SubA->new(a => 1, d => 4711);
    isa_ok $SubA, 'A';
    isa_ok $SubA, 'SubA';
    is $SubA->a, 1;
    is $SubA->d, 4711;
}

__END__
