#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Tests for the javascript function sprintf

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use JSTest;
use Strassen::GeoJSON;

check_js_interpreter_or_exit;

plan 'no_plan';

my $s = Strassen->new_from_data_string(<<"EOF");
#: map: polar
#:
Test\tX 13.5,52.5 13.6,52.5
EOF

my $s_geojson = Strassen::GeoJSON->new($s);
my $bbbgeojsonp = $s_geojson->bbd2geojson(bbbgeojsonp => 1, pretty => 1, utf8 => 0);

chdir "$FindBin::RealBin/../html";

my $js_code = <<"EOF";
load('json2.min.js');
function geoJsonResponse(geoJson) { initialGeoJson = geoJson; }
$bbbgeojsonp
print(JSON.stringify(initialGeoJson));
EOF

my $got = run_js_f $js_code;

is $got, <<'EOF';
{"geometry":{"coordinates":[["13.5","52.5"],["13.6","52.5"]],"type":"LineString"},"properties":{"cat":"X","name":"Test"},"type":"Feature"}
EOF

__END__
