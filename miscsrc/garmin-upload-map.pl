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
use lib ("$ENV{HOME}/src/bbbike", "$ENV{HOME}/src/bbbike/lib");
use GPS::BBBikeGPS::MountedDevice;
use Cwd 'realpath';

my $dir_or_url = shift
    or die "Directory or URL?";
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
    $dir = realpath glob("$tmpdir/planet*");
} else { 
    $dir = realpath $dir;
}

my $name;
open my $fh, "$dir/README.txt" or die $!;
while(<$fh>) {
    if (/Name des Gebietes: (.*)/) {
	$name = $1;
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
	 system("ls", "-al", $dir);
	 system("cp", $srcimg, "$dir/garmin/$destimg");
	 if ($? != 0) {
	     warn "Copyting $srcimg -> garmin/$destimg failed";
	 }
	 system("ls", "-al", "$dir/garmin/$destimg");
     },
     garmin_disk_type => "card"
    );

__END__

=pod

Copy extracted extracts (optionally download it) from
extract.bbbike.org to garmin card, automatically determine file name
from readme file.

=cut
