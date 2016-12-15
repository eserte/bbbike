#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use POSIX qw(tzset);
use Test::More 'no_plan';

use GPS::GpsmanData;
use GPS::GpsmanData::Stats;
use Strassen::MultiStrassen;

use lib $FindBin::RealBin;
use BBBikeTest qw(eq_or_diff);

my $datadir = "$FindBin::RealBin/../data";
my $areas = MultiStrassen->new("$datadir/berlin_ortsteile", "$datadir/potsdam");
my $places = MultiStrassen->new("$datadir/orte", "$datadir/orte2");

my $gps_multi = GPS::GpsmanMultiData->new;
$gps_multi->parse(<<'EOF');
% Written by /mnt/cvrsnica/home/e/eserte/src/bbbike/miscsrc/gpx2gpsman [GPS::GpsmanData] 2016-11-07 18:51:43 +0100

!Format: DDD 1 WGS 84
!Creation: no

!T:	2016-11-04 09:14:26 Tag	colour=#FE00FE	srt:device=a GPS device	srt:vehicle=bike	srt:brand=Hollandrad
	04-Nov-2016 09:48:26	N52.4987742864	E13.4187139291	42.92
	04-Nov-2016 09:48:27	N52.4988039583	E13.4187137615	42.92
	04-Nov-2016 09:48:28	N52.4988363963	E13.4187204670	42.92
!T:	2016-11-04 09:14:26 Tag B	srt:vehicle=s-bahn
	04-Nov-2016 18:05:29	N52.5012031104	E13.3946352359	51.57
	04-Nov-2016 18:48:52	N52.5203187112	E13.4115682729	52.53
	04-Nov-2016 19:01:04	N52.5142659713	E13.4390799422	46.28
EOF

my @tzs = (undef);
if ($^O ne 'MSWin32') { # POSIX::tzset does not work with Windows
    push @tzs, ('Europe/Berlin', 'UTC', 'America/Los_Angeles');
}
for my $tz (@tzs) {
    local $ENV{TZ} = $ENV{TZ};
    if (defined $tz) {
	$ENV{TZ} = $tz;
	tzset;
    }

    my $stats_multi = GPS::GpsmanData::Stats->new($gps_multi, areas => $areas, places => $places);
    $stats_multi->run_stats;

    eq_or_diff $stats_multi->human_readable,
    {
      "avg_speed" => "4.7 km/h",
      "bbox" => [
        "13.3946352359",
        "52.4987742864",
        "13.4390799422",
        "52.5203187112"
      ],
      "chunk_stats" => [
        {
          "avg_speed" => "12.5 km/h",
          "bbox" => [
            "13.4187137615",
            "52.4987742864",
            "13.418720467",
            "52.4988363963"
          ],
          "dist" => "0.007 km",
          "duration" => "0:00:02",
          "max_datetime" => "2016-11-04T09:48:28+01:00",
          "max_speed" => "13.1 km/h",
          "min_datetime" => "2016-11-04T09:48:26+01:00",
          "min_speed" => "11.9 km/h",
          "vehicle" => "bike"
        },
        {
          "avg_speed" => "4.7 km/h",
          "bbox" => [
            "13.3946352359",
            "52.5012031104",
            "13.4390799422",
            "52.5203187112"
          ],
          "dist" => "4.396 km",
          "duration" => "0:55:35",
          "max_datetime" => "2016-11-04T19:01:04+01:00",
          "max_speed" => "9.7 km/h",
          "min_datetime" => "2016-11-04T18:05:29+01:00",
          "min_speed" => "3.3 km/h",
          "vehicle" => "s-bahn"
        }
      ],
      "dist" => "4.402 km",
      "duration" => "0:55:37",
      "max_datetime" => "2016-11-04T19:01:04+01:00",
      "max_speed" => "13.1 km/h",
      "min_datetime" => "2016-11-04T09:48:26+01:00",
      "min_speed" => "3.3 km/h",
      "per_vehicle_stats" => {
        "bike" => {
          "avg_speed" => "12.5 km/h",
          "dist" => "0.007 km",
          "duration" => "0:00:02",
          "max_speed" => "13.1 km/h",
          "min_speed" => "11.9 km/h"
        },
        "s-bahn" => {
          "avg_speed" => "4.7 km/h",
          "dist" => "4.396 km",
          "duration" => "0:55:35",
          "max_speed" => "9.7 km/h",
          "min_speed" => "3.3 km/h"
        }
      },
      "route" => [
        "13.4187139291,52.4987742864",
        "13.4115682729,52.5203187112",
        "13.4390799422,52.5142659713"
      ],
      "route_areas" => [
        "Kreuzberg",
        "Mitte",
        "Friedrichshain"
      ],
      "tags" => [],
      "vehicles" => [
        "s-bahn",
        "bike"
      ]
    }, "with TZ=" . (defined $tz ? $tz : "<undef>");
}

__END__
