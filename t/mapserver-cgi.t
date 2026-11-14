#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use JSON::PP qw(encode_json);
use Test::More;

use BBBikeTest;

plan skip_all => "CGI.pm needed for tests" if !eval { require CGI; 1 };
plan 'no_plan';

use_ok 'BBBikeMapserver';

no warnings 'qw'; # comma in qw

for my $def (
    [
	[[qw(-1,2 34,5)]],
	'-1,2!34,5',
	'-1,2 34,5',
	'-1,2;34,5',
    ],
    [
	[[qw(1.3,2 34,-5.2)]],
	'1.3,2!34,-5.2',
	'1.3,2 34,-5.2',
	'1.3,2;34,-5.2',
    ]
) {
    my($expected, @coordses_val) = @$def;
    for my $coords_val (@coordses_val) {
	my $ms = BBBikeMapserver->new_from_cgi(CGI->new({coords => $coords_val}));
	is_deeply $ms->{MultiCoords}, $expected, "passes for '$coords_val' and " . encode_json($expected);
    }
}

{
    my $ms = BBBikeMapserver->new_from_cgi(CGI->new({coords => "1,2 3,4\nfoo"}));
    is_deeply $ms->{MultiCoords}, [[qw(1,2)]], 'invalid coords param';
}

for my $def (
    ['1,2',                       [[qw(1,2)]]],
    [['1,2', '-3,4'],             [[qw(1,2 -3,4)]]],
    [[['1,2', '-3,4', '5.1,-6']], [[qw(1,2 -3,4 5.1,-6)]]],
    [['1,2', "3,4\nfoo", '5,6'],  [[qw(1,2 5,6)]]],
) {
    my($in, $out) = @$def;
    my $ms = BBBikeMapserver->new;
    $ms->set_coords($in);
    is_deeply $ms->{MultiCoords}, $out, 'set_coords(' . (ref $in ? encode_json($in) : $in) .') -> ' . encode_json($out);
}
