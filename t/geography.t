#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: geography.t,v 1.3 2006/02/04 16:45:02 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";
use Geography::Berlin_DE;

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

my $geo = Geography::Berlin_DE->new;
isa_ok($geo, "Geography::Berlin_DE");

is($geo->cityname, "Berlin");
like($geo->center, qr{-?\d+,-?\d+});

ok(grep { $_ eq 'Spandau' } $geo->supercityparts);
ok(grep { $_ eq 'Kreuzberg' } $geo->cityparts);
ok(grep { $_ eq 'Rosenthal' } $geo->subcityparts);

is($geo->get_supercitypart_for_citypart("Kreuzberg"),
   "Friedrichshain-Kreuzberg");
is($geo->get_supercitypart_for_any("Gatow"), "Spandau");
is($geo->get_supercitypart_for_any("Kreuzberg"), "Friedrichshain-Kreuzberg");
is($geo->get_supercitypart_for_any("Friedrichshain-Kreuzberg"), "Friedrichshain-Kreuzberg");

my @sp = $geo->get_all_subparts("Pankow");
is(scalar(@sp), 14)
    or diag "@sp";

__END__
