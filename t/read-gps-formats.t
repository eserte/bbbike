#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: read-gps-formats.t,v 1.7 2006/01/28 16:57:53 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Route;
use Strassen::Core;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my $v;
my $miscdir = "$FindBin::RealBin/../misc";
my $gpsmandir = "$miscdir/gps_data";
my $datadir = "$FindBin::RealBin/../data";
my $mapserverdir = "$FindBin::RealBin/../mapserver/brb/data";
my $isdir = "$FindBin::RealBin/..//projects/infrasystem/data/transfer";

GetOptions("v!" => \$v) or die "usage!";

my @gps_formats       = (
			 ["$miscdir/mps_examples/BERNAU~1.MPS", "MPS"],
			 ["$miscdir/gps_examples/G7toWin_ASCII.txt", "G7toWin_ASCII"],
			 ["$miscdir/gps_examples/20000510.tracks", "Unknown1"],
			 
			 ["$miscdir/ovl_resources/ulamm/berlin-dresden1.ovl", "Ovl", "ASCII"],
			 ["$miscdir/ovl_resources/d2_obdg.ovl", "Ovl", "Binary 2.0"],
			 ## Other ovl files tested seperately in ovl.t
			 #["$miscdir/ovl_resources/various_from_net/bb02.ovl", "Ovl", "Binary 3.0"],
			 # TODO: ["$miscdir/ovl_resources/various_from_net/10_um_die_hohe_reuth.ovl", "Ovl", "Binary 4.0"],
			);
my @strassen_formats  = (
			 ["$gpsmandir/20040114.trk", "GPSman track"],
			 ["$gpsmandir/20040123.wpt", "GPSman waypoints"],
			 ["$isdir/IS_strassen.MID", "MapInfo"],
			 ["$mapserverdir/strassen.shp", "ESRI"],
			 ["$datadir/strassen", "bbd"],
			 ["$miscdir/e00/germany/hsline.e00", "e00"],
			 ["$miscdir/ovl_resources/ulamm/berlin-dresden1.ovl", "Ovl"], # may be used as route or strassen
			);

plan tests => 2*@gps_formats + @strassen_formats;

for my $def (@gps_formats) {
    my($file, $fmt, $extra_info) = @$def;
    $extra_info = !$extra_info ? "" : " ($extra_info)";
    print STDERR "$file ($fmt)...\n" if $v;
 SKIP: {
	my $tests = 2;
	skip("File $file not available", $tests) if !-f $file;
	my $ret = Route::load($file);
	ok($ret && $ret->{RealCoords} &&
	   ref $ret->{RealCoords} eq 'ARRAY' &&
	   ref $ret->{RealCoords}->[0] eq 'ARRAY',
	   "Format $fmt$extra_info with file $file (Route)");
	is($ret->{Type}, $fmt);
    }
}

for my $def (@strassen_formats) {
    my($file, $fmt) = @$def;
    print STDERR "$file ($fmt)...\n" if $v;
 SKIP: {
	my $tests = 1;
	skip("File $file not available", $tests) if !-f $file;
	my $s = eval { Strassen->new($file) };
	my $err = $@;
	ok($s && scalar @{ $s->data }, "Format $fmt with file $file (Strassen)")
	    or diag "Exception: $@";
    }
}

__END__
