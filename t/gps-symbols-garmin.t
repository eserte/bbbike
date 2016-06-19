#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Test::More 'no_plan';

use GPS::Symbols::Garmin;

######################################################################
# non-portable mapping
my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };
my $mapping = GPS::Symbols::Garmin::get_symbol_to_img();
my $has_gpsman_directory = !grep { m{NOTE: no gpsman/gmicons directory found, no support for Garmin symbols} } @warnings;
isa_ok $mapping, 'HASH';

SKIP: {
    skip "No gpsman directory detected", 1
	if !$has_gpsman_directory;
    like $mapping->{'bridge'}, qr{gmicons/bridge15x15\.gif$};
}

like $mapping->{'user:7681'}, qr{misc/garmin_userdef_symbols/(bike2014/BBBike01|bike2008/001)\.bmp$}, 'private garmin icon';

my $gpsman_rc_directory = GPS::Symbols::Garmin::gpsman_rc_directory();
if (defined $gpsman_rc_directory) {
    ok $has_gpsman_directory, 'gpsman_rc_directory should exist';
} else {
    ok !$has_gpsman_directory, 'gpsman_rc_directory should not exist';
}

######################################################################
# portable mapping
my $portable_mapping = GPS::Symbols::Garmin::get_symbol_to_img(portable => 1);
isa_ok $portable_mapping, 'HASH';

SKIP: {
    skip "No gpsman directory detected", 1
	if !$has_gpsman_directory;
    like $portable_mapping->{'bridge'}, qr{^\$GPSMANDIR/gmicons/bridge15x15\.gif$};
}

like $portable_mapping->{'user:7681'}, qr{^\$BBBIKEDIR/misc/garmin_userdef_symbols/(bike2014/BBBike01|bike2008/001)\.bmp$}, 'use variable $BBBIKEDIR';

__END__
