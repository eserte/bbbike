#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin, "$FindBin::RealBin/..";

use Test::More;

use BBBikeUtil qw(bbbike_root);
use BBBikeTest qw(eq_or_diff gpxlint_string);

sub count_trksegs ($);
sub count_trkpts ($);
sub require_datetime_iso8601 (&);
sub require_geo_distance (&);

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

plan 'no_plan';

my @script = ($^X, bbbike_root . '/miscsrc/gpx2gpx');

my $src_gpx = <<'EOF';
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="fit2gpx by Matjaz Rihtar" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.cluetrust.com/XML/GPXDATA/1/0 http://www.cluetrust.com/Schemas/gpxdata10.xsd" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:gpxtrx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" xmlns:gpxwpx="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxdata="http://www.cluetrust.com/XML/GPXDATA/1/0">
 <metadata>
  <name>Test track</name>
 </metadata>
 <trk>
  <name>Test track 1</name>
  <trkseg>
   <trkpt lat="49.8986634" lon="10.8956448">
    <ele>244.0</ele>
    <time>2000-01-01T07:09:43Z</time>
    <extensions>
     <gpxtpx:TrackPointExtension>
      <gpxtpx:hr>89</gpxtpx:hr>
     </gpxtpx:TrackPointExtension>
    </extensions>
   </trkpt>
   <trkpt lat="49.8986560" lon="10.8956409">
    <ele>244.0</ele>
    <time>2000-01-01T07:09:45Z</time>
    <extensions>
     <gpxtpx:TrackPointExtension>
      <gpxtpx:hr>88</gpxtpx:hr>
     </gpxtpx:TrackPointExtension>
    </extensions>
   </trkpt>
   <trkpt lat="52.5043101" lon="13.4680467">
    <ele>246.2</ele>
    <time>2000-01-01T11:49:17Z</time>
    <extensions>
     <gpxtpx:TrackPointExtension>
      <gpxtpx:hr>87</gpxtpx:hr>
     </gpxtpx:TrackPointExtension>
    </extensions>
   </trkpt>
  </trkseg>
 </trk>
 <extensions>
  <gpxdata:lap>
   <gpxdata:index>1</gpxdata:index>
  </gpxdata:lap>
  <gpxdata:lap>
   <gpxdata:index>2</gpxdata:index>
   <gpxdata:calories>15</gpxdata:calories>
  </gpxdata:lap>
 </extensions>
</gpx>
EOF
ok gpxlint_string($src_gpx), 'source GPX looks valid';
is count_trksegs($src_gpx), 1, 'source GPX has just one trkseg';

{
    ok !(run [@script, '--invalid-option'], '2>', \my $stderr), 'error on invalid option';
    like $stderr, qr{Unknown option: invalid-option}, 'expected error message';
}

my $unchanged_dest_gpx;
{
    ok run [@script], '<', \$src_gpx, '>', \$unchanged_dest_gpx;
    ok gpxlint_string($unchanged_dest_gpx);
}

require_datetime_iso8601 {
    ok run [@script, '--trkseg-split-by-time-gap=86400'], '<', \$src_gpx, '>', \my $dest_gpx;
    eq_or_diff $dest_gpx, $unchanged_dest_gpx, 'no change because time delta is too large';
};

require_geo_distance {
    ok run [@script, '--trkseg-split-by-dist-gap=1000000'], '<', \$src_gpx, '>', \my $dest_gpx;
    eq_or_diff $dest_gpx, $unchanged_dest_gpx, 'no change because distance is too large';
};

require_datetime_iso8601 {
    ok run [@script, '--trkseg-split-by-time-gap=60'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 2, 'now there are two trksegs';

    ok run [@script, '--trkseg-split-by-time-gap=60'], '<', \$dest_gpx, '>', \my $dest2_gpx;
    eq_or_diff $dest2_gpx, $dest_gpx, 'no change, already split';
};

require_geo_distance {
    ok run [@script, '--trkseg-split-by-dist-gap=1000'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 2, 'now there are two trksegs';
    is count_trkpts($dest_gpx), 3, 'but still there are all three trkpts';

    ok run [@script, '--trkseg-split-by-dist-gap=1000'], '<', \$dest_gpx, '>', \my $dest2_gpx;
    eq_or_diff $dest2_gpx, $dest_gpx, 'no change, already split';
};

## trkpts-delete tests
# delete middle point -> two trksegs
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[gpx:time="2000-01-01T07:09:45Z"]'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 2, 'now there are two trksegs';
    is count_trkpts($dest_gpx), 2, 'one trkpt is gone';
}

# delete first point
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[gpx:time="2000-01-01T07:09:43Z"]'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 1, 'still one trkseg (deleted point on front)';
    is count_trkpts($dest_gpx), 2, 'one trkpt is gone';
}

# delete last point
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[gpx:time="2000-01-01T11:49:17Z"]'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 1, 'still one trkseg (deleted point at end)';
    is count_trkpts($dest_gpx), 2, 'one trkpt is gone';
}

# no match -> no change
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[gpx:time="1999-01-01T11:49:17Z"]'], '<', \$src_gpx, '>', \my $dest_gpx;
    (my $src_gpx = $src_gpx) =~ s{<gpx.*>}{<gpx>}; # XXX unfortunately this operation changes the order of attributes in the root element, so for simplicity delete them before running eq_or_diff
    $dest_gpx                =~ s{<gpx.*>}{<gpx>};
    eq_or_diff $dest_gpx, $src_gpx, 'no change';
}

# delete first two points with str-le
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[str-le(gpx:time,"2000-01-01T07:09:45Z")]'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 1, 'still one trkseg (deleted two points on front)';
    local $TODO = "for some reason the str-le function returns only node, not two";
    is count_trkpts($dest_gpx), 1, 'two trkpts are gone';
}

# delete first two points with str-ge & str-le
{
    ok run [@script, '--trkpts-delete=//gpx:trkpt[str-ge(gpx:time,"2000-01-01T00:00:00Z") and str-le(gpx:time,"2000-01-01T07:09:45Z")]'], '<', \$src_gpx, '>', \my $dest_gpx;
    ok gpxlint_string($dest_gpx);
    is count_trksegs($dest_gpx), 1, 'still one trkseg (deleted two points on front)';
    is count_trkpts($dest_gpx), 1, 'two trkpts are gone';
}

sub count_trksegs ($) {
    my $gpx = shift;
    my $count = 0;
    while ($gpx =~ /<trkseg>/g) {
	$count++;
    }
    $count;
}

sub count_trkpts ($) {
    my $gpx = shift;
    my $count = 0;
    while ($gpx =~ /<trkpt( |>)/g) {
	$count++;
    }
    $count;
}

sub require_datetime_iso8601 (&) {
    my $code = shift;
    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	skip "Requires DateTime::Format::ISO8601", 1
	    if !eval { require DateTime::Format::ISO8601; 1 };
	$code->();
    }
}

sub require_geo_distance (&) {
    my $code = shift;
    local $Test::Builder::Level = $Test::Builder::Level+1;
 SKIP: {
	skip "Requires Geo::Distance", 1
	    if !eval { require Geo::Distance; 1 };
	$code->();
    }
}

__END__
