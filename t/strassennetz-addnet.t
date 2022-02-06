#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 $FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Storable qw(dclone);

use Strassen::Core;
use Strassen::Strasse;
use Strassen::StrassenNetz;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan 'no_plan';

use BBBikeTest qw(using_bbbike_test_data eq_or_diff);
using_bbbike_test_data;

my $s = Strassen->new('strassen');
my $net = StrassenNetz->new($s);
$net->make_net;

my $orig_net = dclone $net;

my $pos = 0;
my $first_record = $s->get_obj($pos);
my @c = @{ $first_record->[Strassen::COORDS] };
my $c0 = [split /,/, $c[0]];
my $c1 = [split /,/, $c[1]];
my($newx,$newy) = ($c0->[0]+3, $c0->[1]-3);
$net->add_net($pos, [$newx,$newy], $c0, $c1);

{
    my($res) = $net->search("$newx,$newy", $c[0]);
    eq_or_diff $res, [[$newx,$newy],$c0], 'found expeced route with new coordinate as start';
}

{
    my($res) = $net->search($c[1], "$newx,$newy");
    eq_or_diff $res, [$c1,[$newx,$newy]], 'found expeced route with new coordinate as goal';
}

{
    my($res) = $net->search($c[0], $c[1]);
    eq_or_diff $res, [$c0,[$newx,$newy],$c1], 'found expeced route with new coordinate in between';
    my(@path) = $net->route_info(Route => $res);
    is $path[0]->{Street}, $first_record->[Strassen::NAME], 'correct name was set to added street segments';
}

$net->del_add_net;
is_deeply $net, $orig_net, 'original net was restored after del_add_net'; # eq_or_diff could/would show the whole data structure
