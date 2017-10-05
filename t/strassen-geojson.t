#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use File::Temp qw(tempfile);
use Test::More;

use Strassen;
use Strassen::GeoJSON;

plan 'no_plan';

{
    my $test_strassen_file = "$FindBin::RealBin/data-test/strassen";
    my $s = Strassen->new($test_strassen_file);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson();

    my $s2_geojson = Strassen::GeoJSON->new;
    $s2_geojson->geojsonstring2bbd($geojson);

    is_deeply $s2_geojson->{data}, $s->{data}, 'roundtrip check with data-test/strassen';

    my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".geojson");
    print $tmpfh $geojson;
    close $tmpfh or die $!;
    my $s3_geojson = Strassen::GeoJSON->new;
    $s3_geojson->geojson2bbd($tmpfile);
    is_deeply $s3_geojson->{data}, $s->{data}, 'roundtrip check with geojson2bbd-loaded data';
}

{
    my $test_ampeln_file = "$FindBin::RealBin/data-test/ampeln";
    my $s = Strassen->new($test_ampeln_file);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson();

    my $s2_geojson = Strassen::GeoJSON->new;
    $s2_geojson->geojsonstring2bbd($geojson);

    is_deeply $s2_geojson->{data}, $s->{data}, 'roundtrip check with data-test/ampeln';
}

{
    my $test_flaechen_data = <<"EOF";
#: map: polar
#:
Non-Closed Forest\tF:Forest 13.4,52.5 13.5,52.6 13.4,52.6
Closed Forest\tF:Forest 13.4,52.5 13.5,52.6 13.4,52.6 13.4,52.5
EOF
    my $s = Strassen->new_from_data_string($test_flaechen_data);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson();

    my $s2_geojson = Strassen::GeoJSON->new;
    $s2_geojson->geojsonstring2bbd($geojson);

    is_deeply $s2_geojson->{data}, $s->{data}, 'roundtrip check with area data';
}

{
    my $example_geojson = <<'EOF';
{ "type": "FeatureCollection",
  "features": [
    { "type": "Feature", "properties": { "name": "Point" },           "geometry": { "type": "Point", "coordinates": [100.0, 0.0] } }
   ,{ "type": "Feature", "properties": { "name": "LineString" },      "geometry": { "type": "LineString", "coordinates": [ [100.0, 0.0], [101.0, 1.0] ] } }
   ,{ "type": "Feature", "properties": { "name": "Polygon" },         "geometry": { "type": "Polygon", "coordinates": [ [ [100.0, 0.0], [101.0, 0.0], [101.0, 1.0], [100.0, 1.0], [100.0, 0.0] ] ] } }
   ,{ "type": "Feature", "properties": { "name": "MultiPoint" },      "geometry": { "type": "MultiPoint", "coordinates": [ [100.0, 0.0], [101.0, 1.0] ] } }
   ,{ "type": "Feature", "properties": { "name": "MultiLineString" }, "geometry": { "type": "MultiLineString", "coordinates": [
        [ [100.0, 0.0], [101.0, 1.0] ],
        [ [102.0, 2.0], [103.0, 3.0] ]
        ]
      }
    }
   ,{ "type": "Feature", "properties": { "name": "MultiPolygon" },    "geometry": { "type": "MultiPolygon", "coordinates": [
        [[[102.0, 2.0], [103.0, 2.0], [103.0, 3.0], [102.0, 3.0], [102.0, 2.0]]],
        [[[100.0, 0.0], [101.0, 0.0], [101.0, 1.0], [100.0, 1.0], [100.0, 0.0]],
         [[100.2, 0.2], [100.8, 0.2], [100.8, 0.8], [100.2, 0.8], [100.2, 0.2]]]
        ]
      }
    }
   ,{ "type": "Feature", "properties": { "name": "GeometryCollection" }, "geometry": { "type": "GeometryCollection", "geometries": [
        { "type": "Point", "coordinates": [100.0, 0.0] },
        { "type": "LineString", "coordinates": [ [101.0, 0.0], [102.0, 1.0] ] }
        ]
      }
    }
]
}
EOF

    my $expected_data = 
	[
	 "Point\tX 100,0\n",
	 "LineString\tX 100,0 101,1\n",
	 "Polygon\tF:X 100,0 101,0 101,1 100,1 100,0\n",
	 "MultiPoint\tX 100,0\n",
	 "MultiPoint\tX 101,1\n",
	 "MultiLineString\tX 100,0 101,1\n",
	 "MultiLineString\tX 102,2 103,3\n",
	 "MultiPolygon\tF:X 102,2 103,2 103,3 102,3 102,2\n",
	 "MultiPolygon\tF:X 100,0 101,0 101,1 100,1 100,0\n",
	 "MultiPolygon\tF:X 100.2,0.2 100.8,0.2 100.8,0.8 100.2,0.8 100.2,0.2\n",
	 "GeometryCollection\tX 100,0\n",
	 "GeometryCollection\tX 101,0 102,1\n",
	];
    my $s_geojson = Strassen::GeoJSON->new();
    $s_geojson->geojsonstring2bbd($example_geojson);
    is_deeply $s_geojson->data, $expected_data, 'all geojson types from string';

    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '.geojson', UNLINK => 1);
    print $tmpfh $example_geojson;
    close $tmpfh or die "Error while writing to $tmpfile: $!";

    my $s_file = Strassen->new($tmpfile);
    is_deeply $s_file->data, $expected_data, 'geojson via Strassen->new';

    my $s_file2 = Strassen::GeoJSON->new($tmpfile);
    is_deeply $s_file2->data, $expected_data, 'geojson via Strassen::GeoJSON->new';
}

{
    my $test_combine_data = <<"EOF";
#: map: polar
#:
Waypoint 1\tX 13.4,52.5
Waypoint 2\tX 13.5,52.6
Waypoint 1 again\tX 13.4,52.5
EOF
    my $s = Strassen->new_from_data_string($test_combine_data);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson(combine => 1);
    is $geojson, <<'EOF', 'combine=>1';
{
   "features" : [
      {
         "geometry" : {
            "coordinates" : [
               "13.4",
               "52.5"
            ],
            "type" : "Point"
         },
         "properties" : {
            "cat" : "X",
            "name" : "Waypoint 1<br/>\nWaypoint 1 again"
         },
         "type" : "Feature"
      },
      {
         "geometry" : {
            "coordinates" : [
               "13.5",
               "52.6"
            ],
            "type" : "Point"
         },
         "properties" : {
            "cat" : "X",
            "name" : "Waypoint 2"
         },
         "type" : "Feature"
      }
   ],
   "type" : "FeatureCollection"
}
EOF

}

{
    my $example_geojson = <<'EOF';
{
   "type" : "FeatureCollection",
   "features" : [
      {
         "properties" : {
            "username" : "hinzkunz",
            "captured_at" : "2017-10-03T13:01:17.512Z",
            "unused" : "unused"
         },
         "geometry" : {
            "coordinates" : [
               [
                  13.2404591160321,
                  52.48998644499
               ],
               [
                  13.2404610705015,
                  52.4899858314651
               ]
            ],
            "type" : "LineString"
         },
         "type" : "Feature"
      }
   ]
}
EOF
    my $expected_data =
        [
	 "2017-10-03T13:01:17.512Z hinzkunz\tY 13.2404591160321,52.48998644499 13.2404610705015,52.4899858314651\n",
	];

    my $s_geojson = Strassen::GeoJSON->new();
    $s_geojson->geojsonstring2bbd($example_geojson,
				  namecb => sub { my $f = shift; join(" ", @{$f->{properties}}{qw(captured_at username)}) },
				  catcb => sub { "Y" },
				 );
    is_deeply $s_geojson->data, $expected_data, 'name/cat set with namecb/catcb';
}

