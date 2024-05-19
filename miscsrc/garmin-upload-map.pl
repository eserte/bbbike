#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2019,2021,2022,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
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

our $VERSION = '0.09';

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

my $today_short = strftime("%y%m%d", localtime); # 6 digits, used for internal garmin map name and should not be too long
my $today_long  = strftime("%Y%m%d", localtime); # used for temporary directories

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
    my $tmpdir = File::Temp::tempdir("garmin-upload-${today_long}-XXXXXXXX", CLEANUP => !$keep, TMPDIR => 1);
    my $ua = _get_ua();
    my $resp = $ua->get($dir_or_url, ':content_file' => "$tmpdir/download.zip");
    $resp->is_success
	or die "Fetching $dir_or_url failed: " . $resp->dump;
    system("cd $tmpdir && unzip download.zip");
    $dir = realpath first { -d $_ } glob("$tmpdir/*");
    $kept_file = "$tmpdir/download.zip" if $keep;
} elsif ($dir_or_url =~ m{\.zip$}) {
    require File::Temp;
    my $tmpdir = File::Temp::tempdir("garmin-upload-${today_long}-XXXXXXXX", CLEANUP => 1, TMPDIR => 1);
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

    my @mkgmap;
    if (-x '/usr/bin/mkgmap') {
	@mkgmap = ('/usr/bin/mkgmap');
    } elsif (-f '/opt/mkgmap/mkgmap.jar') {
	@mkgmap = (qw(java -Xmx1024m -jar), '/opt/mkgmap/mkgmap.jar');
    } else {
	die "Cannot find mkgmap, tried /usr/bin/mkgmap and /opt/mkgmap/mkgmap.jar\n";
    }

    if (!defined $description) {
	die "Please specify --description";
    }

    my $is_file = $file_or_url !~ m{^https?://};
    if ($is_file) {
	$file_or_url = realpath($file_or_url);
    }

    require File::Temp;
    my $tmpdir = File::Temp::tempdir("garmin-upload-${today_long}-XXXXXXXX", CLEANUP => !$keep, TMPDIR => 1);
    chdir $tmpdir
	or die "Can't chdir to $tmpdir: $!";

    my $file;
    if (!$is_file) {
	my $ua = _get_ua();
	$file = "download.osm.gz";
	my $resp = $ua->get($dir_or_url, ':content_file' => $file);
	$resp->is_success
	    or die "Fetching $dir_or_url failed: " . $resp->dump;
	$file = realpath($file);
	$kept_file = $file if $keep;
    } else {
	$file = $file_or_url;
    }

    my $mapname = $today_short . sprintf("%02d", $number); # XXX better mapname?

    {
	my @cmd = (
		   @mkgmap,
		   "--description=$description", "--mapname=$mapname",
		   "--country-name=$country_name", "--country-abbr=$country_abbr", "--copyright-message=osm",
		   "--latin1", "--net", "--route", "--draw-priority=15", "--style-file=" . bbbike_root . "/misc/mkgmap/srt-style",
		   "--housenumbers",
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
		   @mkgmap,
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

sub _get_ua {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->agent("garmin-upload-map/$VERSION LWP/$LWP::VERSION [part of BBBike]");
    $ua;
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
which requires the presence of C<mkgmap> (either install the
Debian/Ubuntu package C<mkgmap>, or download manually and make it
available as F</opt/mkgmap/mkgmap.jar>).

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

=head2 BUGS

It seems that (some versions of?) mkgmap leaves a temporary file
F<misc/mkgmap/typ/xM000002a.TYP> behind. This file may safely be
removed.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 SEE ALSO

L<mkgmap(1)>.

=cut
