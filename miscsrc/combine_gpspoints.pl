#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: combine_gpspoints.pl,v 1.3 2002/02/05 14:47:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use GPS::GpsmanData;
use File::Basename;
use Getopt::Long;

my @files = @ARGV;
my @wpt_files;
my @trk_files;
my $dest_wpt;
my $dest_trk;

if (!GetOptions("destwpt=s" => \$dest_wpt,
		"desttrk=s" => \$dest_trk)) {
    die "usage: $0 [-destwpt ...] [-desttrk ...] [*.wpt ...] [*.trk ...]
";
}

if (@files) {
    @wpt_files = grep { /\.wpt$/ } @files;
    @trk_files = grep { /\.trk$/ } @files;

    if (@wpt_files && !defined $dest_wpt) {
	die "Destination file for combined waypoints is missing (-destwpt)";
    }

    if (@trk_files && !defined $dest_trk) {
	die "Destination file for combined tracks is missing (-desttrk)";
    }

} else {
    local $^W = 0; # sort num
    @wpt_files = sort { basename($a) <=> basename($b) } glob("$FindBin::RealBin/../misc/gps_data/*commented.wpt");
    @trk_files = sort { basename($a) <=> basename($b) } glob("$FindBin::RealBin/../misc/gps_data/*.trk");
    $dest_wpt = "$FindBin::RealBin/../misc/gps_data/_combined.wpt";
    $dest_trk = "$FindBin::RealBin/../misc/gps_data/_combined.trk";
}

{
    my @gps;
    my $nr = 1;
    foreach my $f (@wpt_files) {
	$gps[$nr] = new GPS::GpsmanData;
	$gps[$nr]->load($f);
	if ($nr > 1) {
	    $gps[1]->merge($gps[$nr], -addtoken => "$nr-");
	}
    } continue {
	$nr++;
    }
    $gps[1]->write($dest_wpt);
}

{
    my @gps;
    my $nr = 1;
    foreach my $f (@trk_files) {
	next if basename($f) !~ /^\d/;
	$gps[$nr] = new GPS::GpsmanData;
	$gps[$nr]->load($f);
	if ($nr > 1) {
	    $gps[1]->merge($gps[$nr]);
	}
	$nr++;
    }
    $gps[1]->write($dest_trk);
}

__END__
