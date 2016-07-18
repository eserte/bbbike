#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Digest::MD5 qw();
use File::Basename 'basename';
use File::Glob 'bsd_glob';
use File::Temp 'tempdir';
use Getopt::Long;
use Test::More;

BEGIN {
    if (!eval q{ use IPC::Run 'run'; 1 }) {
	plan skip_all => 'IPC::Run needed for tests';
    }
}

use BBBikeUtil 'is_in_path', 'save_pwd2';

if ($^O eq 'MSWin32') {
    plan skip_all => q{Windows' convert is not ImageMagick};
}
if (!eval { require Image::ExifTool; 1 }) {
    plan skip_all => q{Image::ExifTool required for geocode_images and for generating test images};
}
if (!is_in_path('convert')) {
    plan skip_all => q{Need ImageMagick's convert for geocode_images and for generating test images};
}
if (!eval { require XML::Twig; 1 }) {
    plan skip_all => q{Need XML::Twig for generating gpsman test files};
}
if (!eval { require GPS::GpsmanData::Any; 1 }) {
    plan skip_all => qq{Prereqs for generating gpsman test files missing (GPS::GpsmanData::Any cannot load: $@};
}

plan 'no_plan';

sub generate_gpsman_trk ($$;@);
sub generate_photo ($$;@);
sub generate_xvpics_thumbnail ($);
sub generate_nonphoto ($);
sub get_directory_digests ($);

my $geocode_images = "$FindBin::RealBin/../miscsrc/geocode_images";
my @geocode_images = ($^X, $geocode_images);

GetOptions(
	   'debug!' => \my $debug,
	   'keep!'  => \my $keep,
	  )
    or die "usage: $0 [-debug] [-keep]\n";

if ($debug) {
    push @geocode_images, '-debug', '-v';
}

# XXX should not be necessary --- make some research about timezones in exif data
$ENV{TZ} = "Europe/Berlin";

{
    my $success = run [@geocode_images], '2>', \my $stderr;
    ok !$success;
    like $stderr, qr{Please specify at least one image.*usage}s;
}

my $rootdir_i = 1;

{
    my $rootdir = tempdir("geocode_images_test_".($rootdir_i++)."_XXXXXXXX", CLEANUP => 1, TMPDIR => 1);
    mkdir "$rootdir/t"; # thumbnails
    mkdir "$rootdir/i"; # images
    mkdir "$rootdir/g"; # gpstracks

    generate_photo "$rootdir/i/test-with-gpspos.jpg", ['GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'];
    generate_photo "$rootdir/i/test-without-gpspos.jpg", [DateTimeOriginal => '2016:01:02 13:34:45'];
    generate_photo "$rootdir/i/n7650.jpg", [Comment => "Nokia Mobile Phones Ltd.\nNokia7650\n24-09-2003\n12.38.55\nMode=1\n 5.06\n1.3"];
    generate_photo "$rootdir/i/unmappable-image.jpg", [DateTimeOriginal => '2015:12:31 13:34:45'];
    generate_photo "$rootdir/i/image-without-date.jpg", [];
    mkdir "$rootdir/i/.xvpics";
    generate_xvpics_thumbnail "$rootdir/i/.xvpics/thumb.jpg";
    generate_nonphoto "$rootdir/i/nonphoto.txt";
    my $photo_digests = get_directory_digests "$rootdir/i";

    generate_gpsman_trk "$rootdir/g/20160101.trk", [["2016-01-01T12:34:45Z", 12, 52], ["2016-01-01T12:35:45Z", 12.1, 52.1]], timeoffset => 1;
    generate_gpsman_trk "$rootdir/g/20160102.trk", [["2016-01-02T12:34:45Z", 13, 51], ["2016-01-02T12:35:45Z", 13.1, 51.1]], timeoffset => 1;
    generate_gpsman_trk "$rootdir/g/20030924.trk", [["2003-09-24T10:38:00Z", 13.1, 51.1], ["2003-09-24T10:39:00Z", 13.2, 51.2]], timeoffset => 2;
    my $gpstrack_digests = get_directory_digests "$rootdir/g";

    my $check_bbd_data_contents;

    {
	my @cmd = (@geocode_images, '-gpsdatadir', "$rootdir/g", '-thumbnaildir', "$rootdir/t", "-o", "$rootdir/out1.bbd", "$rootdir/i");
	my $success = run [@cmd], '2>', \my $stderr;
	ok $success, "Running '@cmd'";
	if ($debug) {
	    diag $stderr;
	}
	like $stderr, qr{^Can't parse image info from .*/i/nonphoto.txt: (Unrecognized file format|Unknown file type)}m, 'warning for non-photo'; # accept Image::Info and Image::ExifTool error messages, but currently only exiftool is used
	if ($debug) { # printed only with -v
	    like $stderr, qr{^Cannot get date from image <.*/i/image-without-date.jpg>, skipping...$}m, 'warning for photo without date';
	}
	ok -f "$rootdir/out1.bbd";

	is_deeply get_directory_digests("$rootdir/i"), $photo_digests, 'photo original directory did not change';
	is_deeply get_directory_digests("$rootdir/g"), $gpstrack_digests, 'gpstrack original directory did not change';

	my $bbd_data = do { open my $fh, "$rootdir/out1.bbd" or die $!; local $/; <$fh> };
	$check_bbd_data_contents = sub ($;@) {
	    my($bbd_data, %opts) = @_;
	    my $check_relpath = delete $opts{check_relpath};
	    die "Unhandled options: " . join(" ", %opts) if %opts;

	    my $relabspathqr = $check_relpath ? qr{} : qr{.+/};
	    
	SKIP: {
		skip "mysterious test failures (regexp problems) with 5.8.8", 3 if $] < 5.008009 && $check_relpath;
		like $bbd_data, qr{^Image: "$relabspathqr\Qi/test-without-gpspos.jpg" (2016-01-02T13:34:45) (delta=0:00) (51/13)	IMG:\E$relabspathqr\Qt/\E.*\Q.jpg -13609,-156840\E$}m, 'bbd line generated from tracks';
		like $bbd_data, qr{^Image: "$relabspathqr\Qi/test-with-gpspos.jpg" (2016-01-01T13:34:45) (delta=0:00) (53.5/13.5)	IMG:\E$relabspathqr\Qt/\E.*\Q.jpg 14665,121811\E$}m, 'bbd line generated from gps info in photo';
		like $bbd_data, qr{^Image: "$relabspathqr\Qi/n7650.jpg" (2003-09-24T12:38:55) (delta=0:00) (51.2/13.2)	IMG:\E$relabspathqr\Qt/\E.*\Q.jpg -471,-134354\E$}m, 'bbd line generated for ancient N7650';
	    }
	    like $bbd_data, qr{^# Image: "$relabspathqr\Qi/image-without-date.jpg" (not geocodable)}m, 'not geocodable (no date)';
	    like $bbd_data, qr{^# Image: "$relabspathqr\Qi/unmappable-image.jpg" (not geocodable)}m, 'not geocodable (no matching tracks)';
	};
	$check_bbd_data_contents->($bbd_data);

	{
	    my @thumbnails = bsd_glob("$rootdir/t/*");
	    is scalar(@thumbnails), 3, 'expected number of thumbnails generated';
	    for my $thumbnail (@thumbnails) {
		my $exiftool = Image::ExifTool->new;
		$exiftool->ExtractInfo($thumbnail);
		is $exiftool->GetValue('ImageWidth'), 50, "expected width of $thumbnail";
		is $exiftool->GetValue('ImageHeight'), 33, "expected height of $thumbnail";
	    }
	}
    }

    ## Test -update option
    generate_photo "$rootdir/i/newtest-with-gpspos.jpg", ['GPSLongitude#' => '12.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '52.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:03 13:34:45'];
    {
	my @cmd = (@geocode_images, '-update', '-gpsdatadir', "$rootdir/g", '-thumbnaildir', "$rootdir/t", "-o", "$rootdir/out1.bbd", "$rootdir/i");
	my $success = run [@cmd], '2>', \my $stderr;
	ok $success, "Running '@cmd'";
	if ($debug) {
	    diag $stderr;
	}

	my $new_bbd_data = do { open my $fh, "$rootdir/out1.bbd" or die $!; local $/; <$fh> };
	$check_bbd_data_contents->($new_bbd_data);
	like $new_bbd_data, qr{^Image: ".*\Q/i/newtest-with-gpspos.jpg" (2016-01-03T13:34:45) (delta=0:00) (52.5/12.5)	IMG:\E.*/t/.*\Q.jpg -51027,9379\E$}m, 'bbd line generated with -update';
    }

    ## Test -relativepaths option
    {
	my @cmd = (@geocode_images, '-update', '-relativepaths', '-gpsdatadir', "$rootdir/g", '-thumbnaildir', "$rootdir/t", "-o", "$rootdir/out-rel.bbd", "$rootdir/i");
	my $success = run [@cmd], '2>', \my $stderr;
	ok $success, "Running '@cmd'";
	if ($debug) {
	    diag $stderr;
	}

	my $bbd_data = do { open my $fh, "$rootdir/out-rel.bbd" or die $!; local $/; <$fh> };
	$check_bbd_data_contents->($bbd_data, check_relpath => 1);
    }
}

my $jpegtran_available = is_in_path('jpegtran');
if (!$jpegtran_available) {
    diag "jpegtran not available, thumbnails won't be rotated";
}
my $exiv2_available = is_in_path('exiv2');
if (!$exiv2_available) {
    diag "exiv2 not available, cannot create embedded thumbnail images";
}

for my $converter (qw(Image::GD::Thumbnail ImageMagick ImageMagick+exiftool)) {
 SKIP: {
	skip "Image::GD::Thumbnail not available", 1
	    if $converter eq 'Image::GD::Thumbnail' && !eval { require Image::GD::Thumbnail; 1 };
	skip "exiftool not available", 1
	    if $converter eq 'ImageMagick+exiftool' && !is_in_path('exiftool');

	my $rootdir = tempdir("geocode_images_test_".($rootdir_i++)."_XXXXXXXX", CLEANUP => 1, TMPDIR => 1);
	mkdir "$rootdir/t";
	mkdir "$rootdir/i";

	generate_photo "$rootdir/i/normal-orient.jpg", ['Orientation#' => 1, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'];
	generate_photo "$rootdir/i/90deg-cw.jpg", ['Orientation#' => 6, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'];
	generate_photo "$rootdir/i/180deg.jpg", ['Orientation#' => 3, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'];
	generate_photo "$rootdir/i/270deg-cw.jpg", ['Orientation#' => 8, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'];
	if ($exiv2_available) {
	    generate_photo "$rootdir/i/with-thumbnail-normal-orient.jpg", ['Orientation#' => 1, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'], add_thumbnail_image => 1;
	    generate_photo "$rootdir/i/with-thumbnail-90deg-cw.jpg", ['Orientation#' => 6, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'], add_thumbnail_image => 1;
	    generate_photo "$rootdir/i/with-thumbnail-180deg.jpg", ['Orientation#' => 3, 'GPSLongitude#' => '13.5', 'GPSLongitudeRef' => 'E', 'GPSLatitude#' => '53.5', 'GPSLatitudeRef' => 'N', DateTimeOriginal => '2016:01:01 13:34:45'], add_thumbnail_image => 1;
	}

	my @cmd = (@geocode_images, '-nogpsdatadir', '-converter', $converter, '-rel', '-thumbnaildir', "$rootdir/t", "-o", "$rootdir/out1.bbd", "$rootdir/i");
	my $success = run [@cmd], '2>', \my $stderr;
	ok $success, "Running '@cmd'";
	if ($debug) {
	    diag $stderr;
	}

	my %thumbnail_to_image;
	{
	    open my $fh, "$rootdir/out1.bbd" or die $!;
	    while(<$fh>) {
		if (my($image, $thumbnail) = $_ =~ m{Image: "(.*?)".*IMG:(\S+)}) {
		    $thumbnail_to_image{$2} = $1;
		} else {
		    warn "Unexpected: cannot parse $_";
		}
	    }
	}

	{
	    my $save_pwd2 = save_pwd2;
	    chdir $rootdir;
	    my @thumbnails = bsd_glob("t/*");
	    is scalar(@thumbnails), ($exiv2_available ? 7 : 4), 'expected number of thumbnails generated';
	    for my $thumbnail (@thumbnails) {
		my $exiftool = Image::ExifTool->new;
		$exiftool->ExtractInfo($thumbnail);
		my $original = $thumbnail_to_image{$thumbnail};
		if      (!$jpegtran_available || $original =~ m{(normal-orient.jpg|180deg.jpg)}) {
		    is $exiftool->GetValue('ImageWidth'), 50, "expected width of thumbnail for $original";
		    is $exiftool->GetValue('ImageHeight'), 33, "expected height of thumbnail for $original";
		} elsif ($thumbnail_to_image{$thumbnail} =~ m{(90deg-cw.jpg|270deg-cw.jpg)}) {
		    is $exiftool->GetValue('ImageWidth'), 33, "expected width of thumbnail for $original";
		    is $exiftool->GetValue('ImageHeight'), 50, "expected height of thumbnail for $original";
		} else {
		    die "Unexpected thumbnail $thumbnail ($thumbnail_to_image{$thumbnail}).\nMapping: " . join("\n", explain(\%thumbnail_to_image)) . "\nThumbnails: " . join("\n", explain(\@thumbnails));
		}
	    }
	}
    }
}

if ($keep) {
    diag "Keep temporary files and directories...";
    $File::Temp::KEEP_ALL = 1;
}

sub generate_gpsman_trk ($$;@) {
    my($filename, $wpts, %opts) = @_;
    # $wpts = [[iso date, lon, lat], ...]
    my @gps_gpsmandata_any_options;
    if (exists $opts{timeoffset}) {
	push @gps_gpsmandata_any_options, timeoffset => delete $opts{timeoffset};
    }
    die "Unhandled options: " . join(" ", %opts) if %opts;

    my $trk_xml = join('', map {
	my($isodate, $lon, $lat) = @$_;
	qq{<trkpt lat="$lat" lon="$lon"><ele>12.34</ele><time>$isodate</time></trkpt>};
    } @$wpts);
    open my $fh, '>', "$filename.gpx"
	or die "Can't write to $filename.gpx: $!";
    print $fh <<"EOF";
<?xml version="1.0" encoding="UTF-8" standalone="no" ?><gpx xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxx="http://www.garmin.com/xmlschemas/GpxExtensions/v3" xmlns:wptx1="http://www.garmin.com/xmlschemas/WaypointExtension/v1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1" creator="eTrex 30" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd http://www.garmin.com/xmlschemas/GpxExtensions/v3 http://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd http://www.garmin.com/xmlschemas/WaypointExtension/v1 http://www8.garmin.com/xmlschemas/WaypointExtensionv1.xsd http://www.garmin.com/xmlschemas/TrackPointExtension/v1 http://www.garmin.com/xmlschemas/TrackPointExtensionv1.xsd"><metadata><link href="http://www.garmin.com"><text>Garmin International</text></link><time>$wpts->[0]->[0]</time></metadata><trk><name>Trackname</name><extensions><gpxx:TrackExtension><gpxx:DisplayColor>Magenta</gpxx:DisplayColor></gpxx:TrackExtension></extensions><trkseg>$trk_xml</trkseg></trk></gpx>
EOF
    close $fh
	or die $!;

    system("xmllint", "-format", "$filename.gpx") if $debug;

    my $gpsman = GPS::GpsmanData::Any->load_gpx("$filename.gpx", @gps_gpsmandata_any_options);
    $gpsman->write($filename);
    unlink "$filename.gpx";
}

sub generate_photo ($$;@) {
    my($filename, $exifdata, %opts) = @_;
    my $image_mtime = delete $opts{image_mtime};
    if (!defined $image_mtime) {
	$image_mtime = time - 15*86400; # larger than $gps_track_sync_grace_time in geocode_images
    }
    my $add_thumbnail_image = delete $opts{add_thumbnail_image};
    die "Unhandled options: " . join(" ", %opts) if %opts;
    
    {
	my @cmd = ("convert", "-size", "300x200", "xc:white", $filename);
	system @cmd;
	die "Running '@cmd' failed" if $? != 0;
    }
    {
	my $exiftool = Image::ExifTool->new;
	$exiftool->ExtractInfo($filename);
	for(my $i=0; $i<$#$exifdata; $i+=2) {
	    my($k,$v) = @{$exifdata}[$i,$i+1];
	    $exiftool->SetNewValue($k => $v);
	}
	$exiftool->WriteInfo($filename);
    }
    if ($add_thumbnail_image) {
	# exiftool cannot create preview/thumbnail images (see
	# http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=5245.0 )
	# so use exiv2 instead
	if (!$exiv2_available) {
	    die "No exiv2 available, cannot create thumbnail images (should not happen!)";
	}
	my $size = '60x40';
	my $key  = 'ThumbnailImage';
	(my $thumb_filename = $filename) =~ s{(\.jpe?g)$}{-thumb$1};
	{
	    my @cmd = ('convert', '-size', $size, 'xc:white', $thumb_filename);
	    system @cmd;
	    die "Running @cmd failed" if $? != 0;
	}
	{
	    my @cmd = ('exiv2', '-i', 't', 'insert', $filename);
	    system @cmd;
	    die "Running @cmd failed" if $? != 0;
	}
	unlink $thumb_filename;
    }
    utime $image_mtime, $image_mtime, $filename;
}

sub generate_xvpics_thumbnail ($) {
    my $filename = shift;
    open my $ofh, '>', $filename
	or die "Error writing to $filename: $!";
    print $ofh <<'EOF';
P7 332
#XVVERSION:Version 3.10a Rev: 12/29/94 (jp-extension 5.3.3 + PNG patch 1.2d)
#IMGINFO:640x480 JPEG file  (9846 bytes)
#END_OF_COMMENTS
80 60 255
... binary omitted ...
EOF
    close $ofh or die $!;
}

sub generate_nonphoto ($) {
    my $filename = shift;
    open my $ofh, '>', $filename or die $!;
    print $ofh "something\n";
    close $ofh or die $!;
}

sub get_directory_digests ($) {
    my $directory = shift;
    my %digests;
    for my $file (bsd_glob("$directory/*")) {
	open my $fh, $file
	    or die $!;
	binmode $fh;
	$digests{$file} = Digest::MD5->new->addfile($fh)->hexdigest;
    }
    \%digests;
}

__END__
