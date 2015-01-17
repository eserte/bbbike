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

#use File::Temp qw(tempfile);
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
    my $s_geojson = Strassen::GeoJSON->new();
    $s_geojson->geojsonstring2bbd($example_geojson);
    is_deeply $s_geojson->data,
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
}
