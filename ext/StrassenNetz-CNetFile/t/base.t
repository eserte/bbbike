#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

my $root;
BEGIN { $root = "../.." }
use lib ($root, "$root/lib");
use lib @lib::ORIG_INC;

use Strassen::Core;
use StrassenNetz::CNetFileDist;

use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 20;

GetOptions("v" => sub {
	       no warnings 'once';
	       $StrassenNetz::CNetFile::VERBOSE = 1;
	       $StrassenNetz::VERBOSE = 1;
	   })
    or die "usage: $0 [-v]";

$Strassen::Util::cacheprefix = "test_b_de";

my $strfile = "$root/t/data-test/strassen";
my $s = Strassen->new($strfile);
my $net = StrassenNetz->new($s);
isa_ok $net, 'StrassenNetz';
$net->use_data_format($StrassenNetz::FMT_MMAP);
isa_ok $net, 'StrassenNetz::CNetFile';
{
    my $c1 = $net->can("make_net"); # workaround Test.pm DWIMery
    my $c2 = \&StrassenNetz::CNetFile::make_net;
    is $c1, $c2;
}
{
    my $c1 = $net->can("reachable");
    my $c2 = \&StrassenNetz::CNetFile::reachable;
    is $c1, $c2;
}
$net->make_net;
pass "No failure while running make_net";

{
    keys %{ $net->{Net} };
    my($k,$v) = each %{ $net->{Net} };
    ok defined $k, 'key on each initialization defined';
    ok defined $v, 'value on each initialization defined';

    my $keys = scalar keys %{ $net->{Net} };
    cmp_ok $keys, ">", 0, 'have keys';
    #warn $keys;

    my($k2,$v2) = each %{ $net->{Net}{$k} };
    ok defined $k2, 'key on each on 2nd level hash defined';
    ok defined $v2, 'value on each on 2nd level hash defined';

    cmp_ok scalar keys %{ $net->{Net}{$k} }, ">", 0, 'have keys in 2nd level hash';

}


{
    my $c1 = '9229,8785';
    my $c2 = '9227,8890';
    my $non_exists_c1 = '987654321,123456789';

    my $common_diag = sub { diag "Test may fail if test data $strfile changes around Dudenstr." };

    ok exists $net->{Net}->{$c1}, 'existence check, 1st level'
	or $common_diag->();
    my $v = $net->{Net}->{$c1};
    isa_ok $v, 'HASH';
    ok exists $net->{Net}->{$c1}->{$c2}, 'existence check, 2nd level'
	or $common_diag->();
    ok exists $v->{$c2}, 'existence check through intermediate variable'
	or $common_diag->();
    my $dist = $v->{$c2};
    cmp_ok $dist, '>=', 100, 'expexted dist'
	or $common_diag->();
    cmp_ok $dist, '<=', 110
	or $common_diag->();

    is $net->{Net}->{$c2}->{$c1}, $dist, 'same distance for other way around'
	or $common_diag->();

    ok !exists $net->{Net}->{$non_exists_c1}, 'non-existence check, 1st level';
    ok !exists $net->{Net}->{$c1}->{$non_exists_c1}, 'non-existence check, 2nd level';
}

__END__
