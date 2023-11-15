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

use File::Temp qw(tempfile tempdir);
use Test::More;

use Strassen;
use Strassen::GeoJSON;

use BBBikeTest qw(eq_or_diff);

plan 'no_plan';

{
    my $test_strassen_file = "$FindBin::RealBin/data-test/strassen";
    my $s = Strassen->new($test_strassen_file);
    Strassen::GeoJSON->new($s);
    is ref $s, 'Strassen::GeoJSON', 'new reblesses the old Strassen object';
    isa_ok $s, 'Strassen';
    for my $bbd2geojson_args (
			      [],
			      [pretty => 0, utf8 => 0],
			      [pretty => 1],
			      [multiline => 1],
			     ) {
	my $geojson = $s->bbd2geojson(@$bbd2geojson_args);

	my $s2_geojson = Strassen::GeoJSON->new;
	$s2_geojson->geojsonstring2bbd($geojson);

	is_deeply $s2_geojson->{data}, $s->{data}, "roundtrip check with data-test/strassen (bbd2geojson args: @$bbd2geojson_args)";

	my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => ".geojson");
	print $tmpfh $geojson;
	close $tmpfh or die $!;
	my $s3_geojson = Strassen::GeoJSON->new;
	$s3_geojson->geojson2bbd($tmpfile);
	is_deeply $s3_geojson->{data}, $s->{data}, "roundtrip check with geojson2bbd-loaded data (bbd2geojson args: @$bbd2geojson_args)";
    }
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

SKIP: {
    my %expected = (
	"No URL feature"    => undef,
	"URL feature"       => [qw(http://example.org/item1)],
	"Multi URL feature" => [qw(http://example.org/item1 http://example.org/item2)],
    );

    skip "Need JSON::XS", scalar %expected
	if !eval { require JSON::XS; 1 };

    my $test_with_urls_data = <<"EOF";
#: map: polar
#:
No URL feature\tX 13.4,52.5 13.5,52.6 13.4,52.6 13.4,52.5
#: url: http://example.org/item1
URL feature\tX 13.4,52.5 13.5,52.6 13.4,52.6
#: url: http://example.org/item1
#: url: http://example.org/item2
Multi URL feature\tX 12.4,52.5 12.5,52.6 12.4,52.6
EOF
    my $s = Strassen->new_from_data_string($test_with_urls_data, UseLocalDirectives => 1);
    my $geojson_json = Strassen::GeoJSON->new($s)->bbd2geojson;
    my $geojson = JSON::XS::decode_json($geojson_json);
    for my $feature (@{ $geojson->{features} }) {
	my $properties = $feature->{properties};
	my $name = $properties->{name};
	is_deeply $properties->{urls}, $expected{$name}, "urls for '$name'";
    }
}

SKIP: {
    my %expected = (
        "Spandauer Weihnachtsmarkt, vom 27.11.2023 bis 23.12.2023" => {'x-from' => 1700953200, 'x-until' => 1703372399 },
	"Schlosspark Charlottenburg: bei Dunkelheit geschlossen"   => {'x-from' => undef,      'x-until' => undef },
    );

    skip "Need JSON::XS", 1
	if !eval { require JSON::XS; 1 };

    my $test_with_additional_props_data = <<"EOF";
#: map: polar
#:
#: id: 36 vvv
#: x-from: 1700953200 vvv
#: x-until: 1703372399 vvv
Spandauer Weihnachtsmarkt, vom 27.11.2023 bis 23.12.2023\t2::xmas 13.4,52.5 13.5,52.6 13.4,52.6 13.4,52.5
#: x-until: ^^^
#: x-from ^^^
#: id ^^^
# 
#: id: 1811 vvv
#: x-from: undef vvv
#: x-until: undef vvv
#: tempex: night
Schlosspark Charlottenburg: bei Dunkelheit geschlossen\t2::night 13.4,52.5 13.5,52.6 13.4,52.6
#: x-until ^^^
#: x-from: ^^^
#: id ^^^
# 
EOF
    my $s = Strassen->new_from_data_string($test_with_additional_props_data, UseLocalDirectives => 1);
    my $geojson_json = Strassen::GeoJSON->new($s)->bbd2geojson;
    my $geojson = JSON::XS::decode_json($geojson_json);
    for my $feature (@{ $geojson->{features} }) {
	my $properties = $feature->{properties};
	my $name = $properties->{name};
	for my $key ('x-from', 'x-until') {
	    ok exists $properties->{$key}, "$key exists for '$name'";
	    is $properties->{$key}, $expected{$name}->{$key}, "... and has the expected value";
	}
    }
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

    {
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

 SKIP: {
	skip "No Tie::IxHash available (needed for creating non-random hashes)", 1
	    if !eval { require Tie::IxHash; 1 };
	    
	my $expected_bbd = <<EOF;
#: map: polar
#: encoding: utf-8
#:
#: url: http://www.example.com/Point
#: note: A note about Point
Point (cb modified)\tCbMod 100,0
#: url: http://www.example.com/LineString
#: note: A note about LineString
LineString (cb modified)\tCbMod 100,0 101,1
#: url: http://www.example.com/Polygon
#: note: A note about Polygon
Polygon (cb modified)\tF:CbMod 100,0 101,0 101,1 100,1 100,0
#: url: http://www.example.com/MultiPoint vvv
#: note: A note about MultiPoint vvv
MultiPoint (cb modified)\tCbMod 100,0
MultiPoint (cb modified)\tCbMod 101,1
#: note: ^^^
#: url: ^^^
#: url: http://www.example.com/MultiLineString vvv
#: note: A note about MultiLineString vvv
MultiLineString (cb modified)\tCbMod 100,0 101,1
MultiLineString (cb modified)\tCbMod 102,2 103,3
#: note: ^^^
#: url: ^^^
#: url: http://www.example.com/MultiPolygon vvv
#: note: A note about MultiPolygon vvv
MultiPolygon (cb modified)\tF:CbMod 102,2 103,2 103,3 102,3 102,2
MultiPolygon (cb modified)\tF:CbMod 100,0 101,0 101,1 100,1 100,0
MultiPolygon (cb modified)\tF:CbMod 100.2,0.2 100.8,0.2 100.8,0.8 100.2,0.8 100.2,0.2
#: note: ^^^
#: url: ^^^
#: url: http://www.example.com/GeometryCollection vvv
#: note: A note about GeometryCollection vvv
GeometryCollection (cb modified)\tCbMod 100,0
GeometryCollection (cb modified)\tCbMod 101,0 102,1
#: note: ^^^
#: url: ^^^
EOF
	my $s_geojson = Strassen::GeoJSON->new();
	$s_geojson->geojsonstring2bbd
	    (
	     $example_geojson,
	     namecb => sub { my $feature = shift; $feature->{properties}->{name} . " (cb modified)"},
	     catcb  => sub { 'CbMod' },
	     dircb  => sub { my $feature = shift; tie my %h, 'Tie::IxHash', (url => ["http://www.example.com/".$feature->{properties}->{name}], note => ["A note about ".$feature->{properties}->{name}]); \%h },
	    );
	eq_or_diff $s_geojson->as_string, $expected_bbd, 'all geojson types from string';
    }
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

######################################################################
# Test -combinemodule
{
    my $tempmoddir = tempdir("strassen-geojson-XXXXXXXX", CLEANUP => 1);
    open my $ofh, ">$tempmoddir/StrassenGeoJSONMyCombine.pm" or die $!;
    print $ofh <<'EOF';
package StrassenGeoJSONMyCombine;
sub new { bless { c2x => {} }, shift }
sub add_first {
    my($self, %args) = @_;
    my $r = delete $args{rec};
    my $feature = delete $args{feature};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    my $coordstring = join(" ", @{ $r->[Strassen::COORDS] });
    $self->{c2x}->{$coordstring} = { feature => $feature, name => [ $r->[Strassen::NAME] ] };
}
sub maybe_append {
    my($self, %args) = @_;
    my $r = delete $args{rec};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    my $coordstring = join(" ", @{ $r->[Strassen::COORDS] });
    if (my $old_val = $self->{c2x}->{$coordstring}) {
        push @{ $old_val->{name} }, $r->[Strassen::NAME];
        return 1;
    }
    return 0;
}
sub flush {
    my($self) = @_;
    while(my($coordstring, $record) = each %{ $self->{c2x} }) {
        $record->{feature}->{properties}->{name} = join("; ", @{ $record->{name} });
    }
}
1;
EOF
    close $ofh or die $!;

    my $test_combine_data = <<"EOF";
#: map: polar
#:
Waypoint 1\tX 13.4,52.5
Waypoint 2\tX 13.5,52.6
Waypoint 1 again\tX 13.4,52.5
EOF
    my $s = Strassen->new_from_data_string($test_combine_data);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = do {
        local @INC = ($tempmoddir, @INC);
        $s->bbd2geojson(combine => 1, combinemodule => 'StrassenGeoJSONMyCombine');
    };
    eq_or_diff $geojson, <<'EOF', 'combine=>1 and custom combinemodule';
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
            "name" : "Waypoint 1; Waypoint 1 again"
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

######################################################################
# Test -manipulatemodule
{
    my $tempmoddir = tempdir("strassen-geojson-XXXXXXXX", CLEANUP => 1);
    open my $ofh, ">$tempmoddir/StrassenGeoJSONMyManipulate.pm" or die $!;
    print $ofh <<'EOF';
package StrassenGeoJSONMyManipulate;
sub new { bless { }, shift }
sub manipulate_feature {
    my($self, $feature, $r, $directives) = @_;
    $feature->{properties}->{is_manipulated} = 1;
    $feature->{properties}->{name} .= " - added something using manipulatemodule";
    if ($directives->{by}) {
        $feature->{properties}->{name} .= " - by $directives->{by}->[0]";
    }
}
1;
EOF
    close $ofh or die $!;

    my $test_manipulate_data = <<"EOF";
#: map: polar
#:
Waypoint 1\tX 13.4,52.5
#: by: me
Waypoint 2\tX 13.5,52.6
EOF
    my $s = Strassen->new_from_data_string($test_manipulate_data, UseLocalDirectives => 1);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = do {
        local @INC = ($tempmoddir, @INC);
        $s->bbd2geojson(manipulatemodule => 'StrassenGeoJSONMyManipulate');
    };
    eq_or_diff $geojson, <<'EOF', 'custom manipulatemodule';
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
            "is_manipulated" : 1,
            "name" : "Waypoint 1 - added something using manipulatemodule"
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
            "is_manipulated" : 1,
            "name" : "Waypoint 2 - added something using manipulatemodule - by me"
         },
         "type" : "Feature"
      }
   ],
   "type" : "FeatureCollection"
}
EOF

}

######################################################################

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

{
    my $example_geojson = <<'EOF';
{
  "features": [],
  "type": "FeatureCollection"
}
EOF
    my $expected_data = [];
    my $s_geojson = Strassen::GeoJSON->new();
    $s_geojson->geojsonstring2bbd($example_geojson);
    is_deeply $s_geojson->data, $expected_data, 'empty geojson';
}

{
    # "name" in toplevel object used as fallback
    # utf8 handled correctly
    my $example_geojson = <<"EOF";
{ "type": "FeatureCollection",
  "features": [
    { "type": "Feature", "name" : "Point \342\202\254", "geometry": { "type": "Point", "coordinates": [100.0, 0.0] } }
  ]
}
EOF
    {
	my $expected_data = 
	    [
	     "Point \x{20ac}\tX 100,0\n",
	    ];
	my $s_geojson = Strassen::GeoJSON->new();
	$s_geojson->geojsonstring2bbd($example_geojson);
	is_deeply $s_geojson->data, $expected_data, 'geojson with fallback name and utf-8';

	my($tmpfh,$tmpfile) = tempfile(SUFFIX => '.geojson', UNLINK => 1);
	print $tmpfh $example_geojson;
	close $tmpfh or die "Error while writing to $tmpfile: $!";

	my $s_file = Strassen->new($tmpfile);
	is_deeply $s_file->data, $expected_data, 'geojson via Strassen->new';

	my $s_file2 = Strassen::GeoJSON->new($tmpfile);
	is_deeply $s_file2->data, $expected_data, 'geojson via Strassen::GeoJSON->new';
    }
}
