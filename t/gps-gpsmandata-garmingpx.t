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

use_ok('GPS::GpsmanData::GarminGPX');

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('Kopfsteinpflaster'), 'user:7684';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('user:7684'), 'Kopfsteinpflaster';

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('Bridge'), 'bridge';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('bridge'), 'Bridge';

is GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name('City (Medium)'), 'medium_city';
is GPS::GpsmanData::GarminGPX::gpsman_symbol_to_garmin_symbol_name('medium_city'), 'City (Medium)';

__END__
