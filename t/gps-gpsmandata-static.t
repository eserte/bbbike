#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

# Test non-methods in GPS::GpsmanData

use strict;

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Test::More 'no_plan';

use_ok 'GPS::GpsmanData';

{
    my $lat_ddd = 52.5;
    my $lon_ddd = 13.5;

    my($lat_dms, $lon_dms) = GPS::GpsmanData::convert_lat_long_to_gpsman_DMS($lat_ddd, $lon_ddd);
    is $lat_dms, 'N52 30 00.0';
    is $lon_dms, 'E13 30 00.0';

    my $new_lat_ddd = GPS::GpsmanData::convert_DMS_to_DDD($lat_dms);
    my $new_lon_ddd = GPS::GpsmanData::convert_DMS_to_DDD($lon_dms);

    is $new_lat_ddd, $lat_ddd, 'roundtrip ddd -> dms -> ddd for latitude';
    is $new_lon_ddd, $lon_ddd, 'roundtrip ddd -> dms -> ddd for longitude';
}

{
    my $lat_ddd = 42.643931;
    my $lon_ddd = 18.115032;

    my($lat_dms, $lon_dms) = GPS::GpsmanData::convert_lat_long_to_gpsman_DMS($lat_ddd, $lon_ddd);
    is $lat_dms, 'N42 38 38.1';
    is $lon_dms, 'E18 06 54.1';

    local $TODO = "Fails because of too much rounding";
    # the exact values are
    #    'N42 38 38.1516'
    #    'E18 06 54.1146'
    # only with these values the roundtrip works
    #
    # XXX either dump more digits in convert_lat_long_to_gpsman, or
    # accept inaccuracies here (approx. after the fifth digit)

    my $new_lat_ddd = GPS::GpsmanData::convert_DMS_to_DDD($lat_dms);
    my $new_lon_ddd = GPS::GpsmanData::convert_DMS_to_DDD($lon_dms);

    is $new_lat_ddd, $lat_ddd, 'roundtrip ddd -> dms -> ddd for latitude';
    is $new_lon_ddd, $lon_ddd, 'roundtrip ddd -> dms -> ddd for longitude';
}


__END__
