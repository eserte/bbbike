#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsmandata.t,v 1.4 2002/01/20 19:04:29 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

use GPS::GpsmanData;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

my $gps = new GPS::GpsmanData;
ok($gps->isa("GPS::GpsmanData"));
ok($gps->load("$FindBin::RealBin/../../misc/gps_data/1commented.wpt"));
ok(scalar @{ $gps->Waypoints } > 0);
$gps->convert_all("DDD");
ok(scalar @{ $gps->Waypoints } > 0);
$gps->create_cache;
ok(-e "$FindBin::RealBin/../../misc/gps_data/1commented.wpt.cache");

my @gps;
my $nr = 1;
foreach my $f (sort glob("$FindBin::RealBin/../../misc/gps_data/*commented.wpt")) {
    $gps[$nr] = new GPS::GpsmanData;
    ok($gps[$nr]->isa("GPS::GpsmanData"));
    ok($gps[$nr]->load($f));
    if ($nr > 1) {
	$gps[1]->merge($gps[$nr], -addtoken => "$nr-");
    }
} continue {
    $nr++;
}
$gps[1]->write("$FindBin::RealBin/../../misc/gps_data/_combined.wpt");

#use Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->Dumpxs([$gps->Waypoints],[]); # XXX


__END__
