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
    my($pos,$rueckwaerts) = $net->nearest_street("-99999999,-99999999", "9999999,9999999");
    ok !defined $pos, 'We have no result';
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

__END__
