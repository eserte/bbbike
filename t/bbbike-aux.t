#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Test::More;

my $bbbike_aux_t = "$FindBin::RealBin/../../bbbike-aux/t";
if (!-d $bbbike_aux_t) {
    plan skip_all => "$bbbike_aux_t does not exist, nothing to test here";
    exit 0;
}

my @tests = glob("$bbbike_aux_t/*.t");
if (!@tests) {
    plan skip_all => "No tests found in $bbbike_aux_t";
    exit 0;
}

plan tests => scalar @tests;
for my $test (@tests) {
    my @cmd = ($^X, $test);
    open my $ofh, "-|", @cmd
	or die "@cmd failed: $!";
    my $out = join '', <$ofh>;
    my $res = close $ofh;
    ok $? == 0, "@cmd"
	or diag "@cmd failed with $out";
}

__END__
