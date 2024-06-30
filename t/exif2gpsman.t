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

use BBBikeUtil qw(is_in_path);
use GPS::GpsmanData;

plan 'no_plan';

######################################################################
# image

my @test_images;
my @ios_test_images;

for my $gps_info (
		  [51.509865, "N", 0.118092, "W", 20, '2023:02:10 12:34:46'],
		  [51.509965, "N", 0.118192, "W", 21, '2023:02:10 12:34:56'],
		 ) {
    my($lat, $lat_ref, $lon, $lon_ref, $alt, $dt) = @$gps_info;

    for my $def (
	[\@test_images, 'gps'],
	[\@ios_test_images, 'device'],
    ) {
	my($test_images_arrayref, $clock_source) = @$def;

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
	if ($clock_source eq 'device') {
	    (my $dt_date = $dt) =~ s{ .*$}{}; # strip time part
	    $exifTool->SetNewValue('GPSDateStamp', $dt_date);
	} else {
	    $exifTool->SetNewValue('GPSDateTime',     $dt);
	}
	$exifTool->SetNewValue('DateTimeOriginal', $dt);

	$exifTool->WriteInfo("$test_image");

	push @$test_images_arrayref, $test_image;
    }
}

my $first_gpsman_result;
{
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

    $first_gpsman_result = $gpsman;
}

SKIP: {
    skip "IPC::Run required for ios_test_images test", 5
	if !eval { require IPC::Run; 1 };

    my $output_file = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.trk', TMPDIR => 1);
    my @cmd = ($^X, "$FindBin::RealBin/../miscsrc/exif2gpsman", (map { "$_" } @ios_test_images), "-o", "$output_file");
    my $success = IPC::Run::run(\@cmd, '2>', \my $stderr);
    ok !$success, 'expected failure because of missing GPSDateTime';
    like $stderr, qr{\QWARN: Cannot get GPSDateTime from \E.*\Q, ignoring file/frame (consider to use --fallback-device-clock)\E}, 'warning with diagnostics';
    like $stderr, qr{\QWARN: Failed to process 2/2 file(s).}, 'warning at the end';

    ok -f "$output_file", "output file exists";

    my $gpsman = GPS::GpsmanData->new;
    $gpsman->load("$output_file");
    ok !$gpsman->Track, 'no track in output file';
}

{
    my $output_file = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.trk', TMPDIR => 1);
    my @cmd = ($^X, "$FindBin::RealBin/../miscsrc/exif2gpsman", '--fallback-device-clock', (map { "$_" } @ios_test_images), "-o", "$output_file");
    system @cmd;
    is $?, 0, "Success with @cmd"
	or do {
	    $File::Temp::KEEP_ALL = 1;
	    diag "Keep temporary files: @test_images";
	};
    ok -f "$output_file", "output file exists";

    my $gpsman = GPS::GpsmanData->new;
    $gpsman->load("$output_file");

    is_deeply $gpsman->Track, $first_gpsman_result->Track, 'same track';
}

######################################################################
# video
SKIP: {
    skip "No ffmpeg available for creating test video", 1
	if !is_in_path 'ffmpeg';
    my $test_video = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.mp4', TMPDIR => 1);
    system qw(ffmpeg -y -loglevel 0 -f lavfi -i color=blue:s=1280x720 -vframes 1), "$test_video";
    skip "Creating a test video failed", 1
	if !-s "$test_video";

    my $exifTool = Image::ExifTool->new();
    $exifTool->SetNewValue('GPSLatitude',     -12.34);
    # $exifTool->SetNewValue('GPSLatitudeRef', "S"); # XXX This does not seem to work, use negative GPSLatitude instead
    $exifTool->SetNewValue('GPSLongitude',    13.45);
    $exifTool->SetNewValue('GPSLongitudeRef', "E");
    $exifTool->SetNewValue('GPSAltitude',     12345);
    $exifTool->SetNewValue('GPSDateTime',     '2020:02:29 00:01:23');
    $exifTool->WriteInfo("$test_video");

    # XXX Actually, for better testing it would be good to add another
    # XXX GPS record, but how to do this?

    my $output_file = File::Temp->new(TEMPLATE => "exif2gpsman.t.XXXXXXXX", SUFFIX => '.trk', TMPDIR => 1);
    my @cmd = ($^X, "$FindBin::RealBin/../miscsrc/exif2gpsman", "-vehicle", "pedes", "$test_video", "-o", "$output_file");
    system @cmd;
    is $?, 0, "Success with @cmd"
	or do {
	    $File::Temp::KEEP_ALL = 1;
	    diag "Keep temporary files: @test_images";
	};
    ok -f "$output_file", "output file exists";

    my $gpsman = GPS::GpsmanData->new;
    $gpsman->load("$output_file");
    is $gpsman->TrackAttrs->{'srt:vehicle'}, 'pedes', '-vehicle set';
    ok !exists $gpsman->TrackAttrs->{'srt:brand'}, '-brand not set';

    is scalar(@{ $gpsman->Track }), 1, 'one trackpoint';

    is $gpsman->Track->[0]->Latitude, -12.34, 'expected latitude';
    is $gpsman->Track->[0]->Longitude, 13.45, 'expected longitude';
    is $gpsman->Track->[0]->Altitude, 12345, 'expected altitude';
    is $gpsman->Track->[0]->Comment, "29-Feb-2020 00:01:23", 'expected datetime';
}
