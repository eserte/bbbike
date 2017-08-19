#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
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

use BBBikeUtil qw(save_pwd2);
use GPS::BBBikeGPS::MountedDevice;

our $VERSION = '0.02';

sub usage () {
    die "usage: @{[ basename $0 ]} directory_or_url\n";
}

GetOptions(
	   'v' => sub {
	       print "@{[ basename $0 ]} $VERSION\n";
	       exit 0;
	   },
	  )
    or usage;

my $dir_or_url = shift
    or usage;
my $dir;
if ($dir_or_url =~ m{^https?://}) {
    require File::Temp;
    require LWP::UserAgent;
    my $tmpdir = File::Temp::tempdir(CLEANUP => 1, TMPDIR => 1);
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->get($dir_or_url, ':content_file' => "$tmpdir/download.zip");
    $resp->is_success
	or die "Fetching $dir_or_url failed: " . $ua->status_line;
    system("cd $tmpdir && unzip download.zip");
    $dir = realpath first { -d $_ } glob("$tmpdir/*");
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

=cut
