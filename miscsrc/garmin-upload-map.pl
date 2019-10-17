#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2019 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Cwd 'realpath';
use File::Basename 'basename';
use Getopt::Long;
use List::Util 'first';
use POSIX 'strftime';

use BBBikeUtil qw(save_pwd2 bbbike_root);
use GPS::BBBikeGPS::MountedDevice;

our $VERSION = '0.05';

sub usage () {
    die "usage: @{[ basename $0 ]} [--keep] [--description ...] [--number ...] directory_or_url\n";
}

my $keep;
my $kept_file;

# for mkgmap
my $description;
my $country_name = 'DE'; # XXX make configurable
my $country_abbr = $country_name;
my $number = 1;

GetOptions(
	   'keep!' => \$keep,
	   'v' => sub {
	       print "@{[ basename $0 ]} $VERSION\n";
	       exit 0;
	   },
	   'description=s' => \$description,
	   'number=i' => \$number,
	  )
    or usage;

my $dir_or_url = shift
    or usage;
my $dir;
if ($dir_or_url =~ m{\.osm\.gz$}) {
    $dir = download_and_convert_osm($dir_or_url);
} elsif ($dir_or_url =~ m{^https?://}) {
    require File::Temp;
    require LWP::UserAgent;
    my $tmpdir = File::Temp::tempdir(CLEANUP => !$keep, TMPDIR => 1);
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->get($dir_or_url, ':content_file' => "$tmpdir/download.zip");
    $resp->is_success
	or die "Fetching $dir_or_url failed: " . $ua->status_line;
    system("cd $tmpdir && unzip download.zip");
    $dir = realpath first { -d $_ } glob("$tmpdir/*");
    $kept_file = "$tmpdir/download.zip" if $keep;
} elsif ($dir_or_url =~ m{\.zip$}) {
    require File::Temp;
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);
    my $zip_path = realpath $dir_or_url;
    {
	my $save_pwd = save_pwd2;
	chdir $tmpdir or die "Can't chdir to $tmpdir: $!";
	system 'unzip', $zip_path;
	die "'unzip $zip_path' failed" if $? != 0;
    }
    $dir = realpath first { -d $_ } glob("$tmpdir/*");
} else {
    $dir = realpath $dir_or_url;
}

my $name;
open my $fh, "$dir/README.txt"
    or die "Problem opening $dir/README.txt: $!";
while(<$fh>) {
    if (/(?:Name des Gebietes|Name of area):\s*(.*)/) {
	$name = $1;
	if ($name eq '') { # may be empty
	    $name = basename($dir);
	}
	last;
    }
}
die "Can't parse name out of README.txt" if !$name;

$name =~ s{[^A-Za-z0-9_-]}{_}g;

my $srcimg = "$dir/gmapsupp.img";
if (!-s $srcimg) {
    die "No image file $srcimg available";
}

my $destimg = "$name.img";
warn "Used name for image file: $destimg\n";

GPS::BBBikeGPS::MountedDevice->maybe_mount
    (sub {
	 my $dir = shift;
	 print STDERR "Old contents in garmin subdirectory:\n";
	 system("ls", "-l", "$dir/garmin");
	 system("cp", $srcimg, "$dir/garmin/$destimg");
	 if ($? != 0) {
	     warn "Copyting $srcimg -> garmin/$destimg failed";
	 }
	 print STDERR "New image transferred to garmin subdirectory:\n";
	 system("ls", "-al", "$dir/garmin/$destimg");
     },
     garmin_disk_type => "card"
    );

if ($kept_file) {
    print STDERR "A copy of the downloaded img can be found as $kept_file.\n";
}

sub download_and_convert_osm {
    my $file_or_url = shift;

    # XXX don't hardcode
    my $mkgmap = "/opt/mkgmap-r2310/mkgmap.jar";
    if (!-r $mkgmap) {
	die "mkgmap not available";
    }

    if (!defined $description) {
	die "Please specify --description";
    }

    my $is_file = $file_or_url !~ m{^https?://};
    if ($is_file) {
	$file_or_url = realpath($file_or_url);
    }

    require File::Temp;
    require LWP::UserAgent;
    my $tmpdir = File::Temp::tempdir(CLEANUP => !$keep, TMPDIR => 1);
    chdir $tmpdir
	or die "Can't chdir to $tmpdir: $!";

    my $file;
    if (!$is_file) {
	my $ua = LWP::UserAgent->new;
	$file = "download.osm.gz";
	my $resp = $ua->get($dir_or_url, ':content_file' => $file);
	$resp->is_success
	    or die "Fetching $dir_or_url failed: " . $ua->status_line;
	$file = realpath($file);
	$kept_file = $file if $keep;
    } else {
	$file = $file_or_url;
    }

    my $mapname = strftime("%d%m%y", localtime) . sprintf("%02d", $number); # XXX better mapname?

    {
	my @cmd = (
		   "java", "-Xmx1024m", "-jar", $mkgmap,
		   "--description=$description", "--mapname=$mapname",
		   "--country-name=$country_name", "--country-abbr=$country_abbr", "--copyright-message=osm",
		   "--latin1", "--net", "--route", "--draw-priority=15", "--style-file=" . bbbike_root . "/misc/mkgmap/srt-style",
		   "--index", $file,
		  );
	warn "Run '@cmd'...\n";
	system @cmd;
	if ($? != 0) {
	    die "Command '@cmd' failed";
	}
    }
    if (!-s "$mapname.img") {
	die "Creation of $mapname.img failed, file is missing";
    }
    {
	my @cmd = (
		   "java", "-Xmx1024m", "-jar", $mkgmap,
		   "--family-id=2304", # XXX don't hardcode!
		   "--family-name=OSM",
		   "--description=$description",
		   "--index",
		   "--gmapsupp", "$mapname.img",
		   bbbike_root . "/misc/mkgmap/typ/M000002a.TYP",
		  );
	warn "Run '@cmd'...\n";
	system @cmd;
	if ($? != 0) {
	    die "Command '@cmd' failed";
	}
    }
    open my $ofh, ">", "README.txt"
	or die "Can't write dummy README.txt: $!";
    print $ofh "Name of area: $description\n";
    close $ofh
	or die $!;

    return $tmpdir;
}

__END__

=head1 NAME

garmin-upload-map.pl - upload extract.bbbike.org extracts to garmin device

=head1 SYNOPSIS

There are two modes:

Download & upload:

    garmin-upload-map.pl https://download.bbbike.org/osm/extract/planet...zip

Upload already unzipped file:

    garmin-upload-map.pl /path/to/unzipped_planet_directory

Upload zip:

    garmin-upload-map.pl /path/to/unzipped_planet.zip

=head1 DESCRIPTION

Copy extracts (optionally download it) from extract.bbbike.org to
garmin card (which is automatically mounted if possible),
automatically determine file name from readme file.

Supports the Garmin and OSM XML gzip'd (C<.osm.gz>) formats. In the
case of C<.osm.gz> a conversion step on the local machine is needed
which requires the presence of C<mkgmap> (currently hardcoded to be
located in F</opt>, see source).

The option C<--keep> can be used to keep the downloaded file in a
temporary location. Only useful if URLs are used.

In the case of C<.osm.gz> the option C<--description> have to be set.
If multiple maps per day have to be stored on the Garmin device, then
the subsequent maps have to be marked with an incremented number using
the C<--number> option.

=head2 EXAMPLES

Download an extract (Garmin format) and upload it to the Garmin device:

    garmin-upload-map.pl https://download.bbbike.org/osm/extract/planet_12.781_53.069_cec469f2.osm.garmin-bbbike.de.zip

Download a .osm.gz extract and upload it to the Garmin device:

    garmin-upload-map.pl https://download.bbbike.org/osm/extract/planet_7.758_47.904_1498eb2f.osm.gz --description Freiburg

Download a 2nd file:

    garmin-upload-map.pl https://download.bbbike.org/osm/extract/planet_7.537_47.531_205e175b.osm.gz --description Basel --number 2

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 SEE ALSO

L<mkgmap(1)>.

=cut
