#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
no warnings 'qw';
use FindBin;
use lib (
	 "$FindBin::RealBin/..", 
	 "$FindBin::RealBin/../lib", 
	 $FindBin::RealBin,
	);

use Route ();
use Route::Simplify ();
use Strassen ();
use Strassen::StrassenNetz ();

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeTest qw(using_bbbike_test_data);

using_bbbike_test_data;

plan 'no_plan';

my $s = Strassen->new("strassen");
my $s_net = StrassenNetz->new($s);
$s_net->make_net;
my $comments_net = StrassenNetz->new(Strassen->new("comments_path"));
$comments_net->make_net_cat(-net2name => 1,
			    -multiple => 1,
			    -obeydir => 1);

{
    my @path = map { [ split /,/ ] } qw(15420,12178 15361,12071 15294,11964 15317,11953);
    my $simplified_route = Route::simplify_for_gps(Route->new_from_realcoords(\@path), -streetobj => $s, -netobj => $s_net);
    ok $simplified_route or do {
	require Data::Dumper; diag(Data::Dumper->new([$simplified_route],[qw()])->Indent(1)->Useqq(1)->Dump); # XXX
    };
}

__END__
