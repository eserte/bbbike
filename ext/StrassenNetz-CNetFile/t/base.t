#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use Cwd;
BEGIN { $root = "../.." }
use lib ($root, "$root/lib", "$root/data");
use lib @lib::ORIG_INC;

use Strassen::Core;
use StrassenNetz::CNetFileDist;

use strict;
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

plan tests => 11;

GetOptions("v" => sub {
	       no warnings 'once';
	       $StrassenNetz::CNetFile::VERBOSE = 1;
	       $StrassenNetz::VERBOSE = 1;
	   })
    or die "usage: $0 [-v]";

my $s = Strassen->new("strassen");
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


__END__
