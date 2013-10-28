#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use Test::More;
use File::Basename qw(basename);

# List of test files which fail for hash randomization-enabled perls,
# i.e. 5.18.x. These test scripts should probably be fixed!
my %TODO_hash_randomization = ('bbd2osm.t' => 1);

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
    my $test_basename = basename $test;
    local $TODO;
    if ($] >= 5.018 && $TODO_hash_randomization{$test_basename}) {
	$TODO = "Known test failure because of hash randomization";
    }
    my @cmd = ($^X, $test);
    open my $ofh, "-|", @cmd
	or die "@cmd failed: $!";
    my $out = join '', <$ofh>;
    my $res = close $ofh;
    ok $? == 0, "@cmd"
	or diag "@cmd failed with $out";
}

__END__
