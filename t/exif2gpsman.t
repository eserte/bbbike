#!/usr/bin/perl -w
# -*- cperl -*-

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib", $FindBin::RealBin;

use File::Temp;
use Test::More;

if (!eval { require Image::ExifTool; 1 }) {
    plan skip_all => 'Image::ExifTool needed for exif2gpsman';
}
if (!eval { require DateTime::Format::ISO8601; 1 }) {
    plan skip_all => 'DateTime::Format::ISO8601 needed for exif2gpsman';
}

use GPS::GpsmanData;

plan 'no_plan';

my @test_images;

for my $gps_info (
		  [51.509865, "N", 0.118092, "W", 20, '2023:02:10 12:34:46'],
		  [51.509965, "N", 0.118192, "W", 21, '2023:02:10 12:34:56'],
		 ) {
    my($lat, $lat_ref, $lon, $lon_ref, $alt, $dt) = @$gps_info;
    my $exifTool = Image::ExifTool->new();

    my $test_image = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.JPG', TMPDIR => 1);
    binmode($test_image);
    # see https://stackoverflow.com/a/30290754/2332415
    my @image_hex = qw(
			  FF D8 FF E0 00 10 4A 46 49 46 00 01 01 01 00 48 00 48 00 00
			  FF DB 00 43 00 FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
			  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
			  FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
			  FF FF FF FF FF FF FF FF FF FF C2 00 0B 08 00 01 00 01 01 01
			  11 00 FF C4 00 14 10 01 00 00 00 00 00 00 00 00 00 00 00 00
			  00 00 00 00 FF DA 00 08 01 01 00 01 3F 10
		     );
    $test_image->print(pack('H2' x scalar(@image_hex), @image_hex));
    $test_image->close;

    $exifTool->SetNewValue('GPSLatitude',     $lat);
    $exifTool->SetNewValue('GPSLatitudeRef',  $lat_ref);
    $exifTool->SetNewValue('GPSLongitude',    $lon);
    $exifTool->SetNewValue('GPSLongitudeRef', $lon_ref);
    $exifTool->SetNewValue('GPSAltitude',     $alt);
    $exifTool->SetNewValue('GPSDateTime',     $dt);

    $exifTool->WriteInfo("$test_image");

    push @test_images, $test_image;
}

my $output_file = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.trk', TMPDIR => 1);
my @cmd = ($^X, "$FindBin::RealBin/../miscsrc/exif2gpsman", "-vehicle", "bike", "-brand", "racingbike", (map { "$_" } @test_images), "-o", "$output_file");
system @cmd;
is $?, 0, "Success with @cmd"
    or do {
	$File::Temp::KEEP_ALL = 1;
	diag "Keep temporary files: @test_images";
    };
ok -f "$output_file", "output file exists";

my $gpsman = GPS::GpsmanData->new;
$gpsman->load("$output_file");
is $gpsman->TrackAttrs->{'srt:vehicle'}, 'bike', '-vehicle set';
is $gpsman->TrackAttrs->{'srt:brand'}, 'racingbike', '-brand set';

is scalar(@{ $gpsman->Track }), 2, 'two trackpoints';

is $gpsman->Track->[0]->Latitude, 51.509865, 'expected latitude';
is $gpsman->Track->[0]->Longitude, -0.118092, 'expected longitude';
is $gpsman->Track->[0]->Altitude, 20, 'expected altitude';
is $gpsman->Track->[0]->Comment, "10-Feb-2023 12:34:46", 'expected datetime';

is $gpsman->Track->[1]->Latitude, 51.509965, 'expected latitude of 2nd trackpoint';
