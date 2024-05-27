#!/usr/bin/perl -w
# -*- cperl -*-

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib", $FindBin::RealBin;

use Test::More 'no_plan';

use BBBikeTest qw(eq_or_diff);

use BBBikeAdvanced;

# expected by BBBikeAdvanced.pm to be loaded
use Karte;
use Karte::Standard;
use Karte::Polar;

# bbbike coordinates
eq_or_diff [_find_coords("Mittlerer Stern\tHH 1111,2222 3333,4444")], [[1111,2222], [3333,4444]];

# openstreetmap, opentopomap, former qwant
eq_or_diff [_find_coords('https://www.openstreetmap.org/#map=19/52.51627/13.37770&layers=N')], [[8600,12254]];
eq_or_diff [_find_coords('https://opentopomap.org/#marker=16/52.51627/13.37770')], [[8600,12254]];
eq_or_diff [_find_coords('https://www.qwant.com/maps#map=15.38/52.51627/13.37770')], [[8600,12254]];

# openstreetmap route
eq_or_diff [_find_coords('https://www.openstreetmap.org/directions?engine=fossgis_osrm_bike&route=52.44074%2C13.58726%3B52.44275%2C13.58220')], [[23018,4108],[22669,4325]];

# geo URI
{
  local $TODO = "two coords, should probably shortcut";
  eq_or_diff [_find_coords('geo:52.51627,13.37770')], [[8600,12254]];
}

# googlemaps
eq_or_diff [_find_coords('https://www.google.com/maps/@52.5156235,13.3768881,15.29z')],   [[8546,12181]];
eq_or_diff [_find_coords('https://www.google.com/maps/@52.5156235,13.3768881,14z')],      [[8546,12181]];
eq_or_diff [_find_coords('https://www.google.com/maps/@52.5156235,13.3768881,14m/rest')], [[8546,12181]];
eq_or_diff [_find_coords('https://www.google.com/maps/place/Brandenburger+Tor/@52.5156235,13.3768881,14z/data=!4m5!3m4!1s0x47a851c655f20989:0x26bbfb4e84674c63!8m2!3d52.5162746!4d13.3777041')], [[8546,12181]];

# kartaview
eq_or_diff [_find_coords('https://kartaview.org/map/@52.51625735865977,13.37810327600232,17z')], [[8627,12253]];
eq_or_diff [_find_coords("Coordinate:\t52.51628113, 13.37769890")], [[8599,12255]];

# image with gps data in exif
SKIP: {
    skip "Image::ExifTool needed for parsing GPS position out of images", 1
	if !module_exists('Image::ExifTool');
    my $file = "$FindBin::RealBin/img/gpspostest.jpg";
    eq_or_diff [_find_coords("file://$file")], [[10925,12525]];
}

__END__
