# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::RealBin/..";

use Test::More;

use Karte::UTM qw(ConvertDatum DegreesToGKK GKKToDegrees DegreesToUTM UTMToDegrees);

plan tests => 16;

check(53,13,"WGS 84", 4567136, 5875088);
my($clat,$clong) = ConvertDatum(53,13,"WGS 84", "Potsdam", "DDD");
check($clat,$clong,"Potsdam", 4567242, 5874643);

{
    my($zone, $hemisphere, $easting, $northing) = DegreesToUTM(53.5,13.5,"ELD 79");
    is $zone, 33, 'DegreesToUTM zone';
    is $hemisphere, 'U';
    is $easting, 400500;
    is $northing, 5929067;
}
{
    my($y,$x) = UTMToDegrees(qw(33 U 400500 5929067), "ELD 79");
    cmp_ok abs($y-53.5), '<', 0.0000007, 'northing in UTMToDegrees call';
    cmp_ok abs($x-13.5), '<', 0.000005,  'easting in UTMToDegrees call';
}


sub check {
    my($lat, $long, $datum,
       $expected_easting, $expected_northing) = @_;
    my($zone, $easting, $northing) = DegreesToGKK($lat,$long,$datum);
    is $zone, 4, "zone for datum $datum";
    is $easting, $expected_easting, "easting for datum $datum";
    is $northing, $expected_northing, "northing for datum $datum";
    my($lat1,$long1) = GKKToDegrees($zone, $easting, $northing, $datum);
    my($zone1, $easting1, $northing1) = DegreesToGKK($lat1,$long1,$datum);
    is $easting, $easting1, "easting - roundtrip ok";
    is $northing, $northing1, "northing - roundtrip ok";
}

__END__
