#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: read-gps-formats.t,v 1.3 2005/04/16 18:23:32 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Route;
use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my $miscdir = "$FindBin::RealBin/../misc";
my $gpsmandir = "$miscdir/gps_data";
my $datadir = "$FindBin::RealBin/../data";
my $mapserverdir = "$FindBin::RealBin/../mapserver/brb/data";
my $isdir = "$FindBin::RealBin/..//projects/infrasystem/data/transfer";

my @gps_formats       = (
			 ["$miscdir/mps_examples/BERNAU~1.MPS", "MPS"],
			 ["$miscdir/gps_examples/G7toWin_ASCII.txt", "G7toWin_ASCII"],
			 ["$miscdir/gps_examples/20000510.tracks", "Unknown1"],
			 
			 ["$miscdir/ovl_resources/ulamm/berlin-dresden1.ovl", "Ovl"],
			);
my @strassen_formats  = (
			 ["$gpsmandir/20040114.trk", "GPSman track"],
			 ["$gpsmandir/20040123.wpt", "GPSman waypoints"],
			 ["$isdir/IS_strassen.MID", "MapInfo"],
			 ["$mapserverdir/strassen.shp", "ESRI"],
			 ["$datadir/strassen", "bbd"],
			 ["$miscdir/e00/germany/hsline.e00", "e00"],
			);

plan tests => 2*@gps_formats + @strassen_formats;

for my $def (@gps_formats) {
    my($file, $fmt) = @$def;
 SKIP: {
	my $tests = 2;
	skip("File $file not available", $tests) if !-f $file;
	my $ret = Route::load($file);
	ok($ret && $ret->{RealCoords} &&
	   ref $ret->{RealCoords} eq 'ARRAY' &&
	   ref $ret->{RealCoords}->[0] eq 'ARRAY',
	   "Format $fmt with file $file");
	is($ret->{Type}, $fmt);
    }
}

for my $def (@strassen_formats) {
    my($file, $fmt) = @$def;
 SKIP: {
	my $tests = 1;
	skip("File $file not available", $tests) if !-f $file;
	my $s = eval { Strassen->new($file) };
	ok($s && scalar @{ $s->data }, "Format $fmt with file $file");
    }
}

__END__
