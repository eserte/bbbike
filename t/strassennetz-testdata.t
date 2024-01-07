#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use utf8;
use FindBin;
use lib (
	 $FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Strassen::Core;
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

use BBBikeTest qw(using_bbbike_test_data);
using_bbbike_test_data;

my $s = Strassen->new("strassen");
my $net = StrassenNetz->new($s);
$net->make_net;

{
    my($pos,$rueckwaerts) = $net->nearest_street("8982,8781", "9063,8935");
    is $s->get($pos)->[Strassen::NAME], 'Methfesselstr.', 'easy nearest_street call: both points known';
    is $rueckwaerts, 0, '... not rueckwaerts';
}

{
    my($pos,$rueckwaerts) = $net->nearest_street("9063,8935", "8982,8781");
    ok defined $pos, 'We have a result';
    is $s->get($pos)->[Strassen::NAME], 'Methfesselstr.', 'easy nearest_street call: both points known';
    is $rueckwaerts, 1, '... but rueckwaerts';
}

{
    my($pos,$rueckwaerts) = $net->nearest_street("8982,8781", "9064,8935");
    ok defined $pos, 'We have a result';
    is $s->get($pos)->[Strassen::NAME], 'Methfesselstr.', 'slightly more difficult: 2nd point not known';
    is $rueckwaerts, 0, '... not rueckwaerts';
}

{
    my($pos,$rueckwaerts) = $net->nearest_street("9064,8935", "8982,8781");
    ok defined $pos, 'We have a result';
    is $s->get($pos)->[Strassen::NAME], 'Methfesselstr.', 'slightly more difficult: 1st point not known';
    is $rueckwaerts, 1, '... but rueckwaerts';
}

{
    my $inv_pos1 = "-99999999,-99999999";
    my $inv_pos2 = "9999999,9999999";
    my($pos,$rueckwaerts) = $net->nearest_street($inv_pos1, $inv_pos2);
    ok !defined $pos, 'We have no result';
    ok !exists $net->{Net}->{$inv_pos1}, 'no autovivify of invalid position 1';
    ok !exists $net->{Net}->{$inv_pos2}, 'no autovivify of invalid position 2';
}

{
    local $StrassenNetz::VERBOSE = 1;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my($pos,$rueckwaerts) = $net->nearest_street("-99999999,-99999999", "9999999,9999999");
    like "@warnings", qr{Kann weder .* noch .* in Net2Name finden}, 'expected warning';
}

{
    # degenerate case: here any street in a crossing might be the correct one
    # also the $rueckwaerts flag is useless here
    my($pos,$rueckwaerts) = $net->nearest_street("9227,8890", "9227,8890");
    ok defined $pos, 'We have a result';
    is $s->get($pos)->[Strassen::NAME], 'Mehringdamm', 'does not crash if both points are the same';
}

{
    # split street names tests
    no warnings 'qw';
    {
	# Palisadenstr. -> Straße der Pariser Kommune
	my @path = map { [split/,/] } qw(12632,12630 12843,12567 12866,12582 12891,12549 12878,12430);
	my @route = $net->route_to_name(\@path);
	is @route, 2;
	is $route[0]->[StrassenNetz::ROUTE_NAME], 'Palisadenstr.';
	is $route[1]->[StrassenNetz::ROUTE_NAME], 'Straße der Pariser Kommune', 'split street names (southwards case)';
    }

    {
	# Weidenweg -> Friedenstr.
	my @path = map { [split/,/] } qw(13025,12523 12891,12549 12866,12582 12859,12593 12773,12683 12690,12769);
	my @route = $net->route_to_name(\@path);
	is @route, 2;
	is $route[0]->[StrassenNetz::ROUTE_NAME], 'Weidenweg';
	is $route[1]->[StrassenNetz::ROUTE_NAME], 'Friedenstr.', 'split street names (northwards)';
    }

    {
	# Friedenstr. -> Weidenweg
	my @path = map { [split/,/] } qw(12690,12769 12773,12683 12859,12593 12866,12582 12891,12549 13025,12523);
	my @route = $net->route_to_name(\@path);
	is @route, 3;
	is $route[0]->[StrassenNetz::ROUTE_NAME], 'Friedenstr.';
	is $route[1]->[StrassenNetz::ROUTE_NAME], 'Straße der Pariser Kommune', 'split street names (south-eastwards case, both names)';
	is $route[2]->[StrassenNetz::ROUTE_NAME], 'Weidenweg';
    }

    {
	# Straße der Pariser Kommune -> Palisadenstr.
	my @path = map { [split/,/] } qw(12878,12430 12891,12549 12866,12582 12843,12567 12632,12630);
	my @route = $net->route_to_name(\@path);
	is @route, 3;
	is $route[0]->[StrassenNetz::ROUTE_NAME], 'Straße der Pariser Kommune';
	is $route[1]->[StrassenNetz::ROUTE_NAME], 'Friedenstr.', 'split street names (north-westwards case, both names)';
	is $route[2]->[StrassenNetz::ROUTE_NAME], 'Palisadenstr.';
    }
}

__END__
