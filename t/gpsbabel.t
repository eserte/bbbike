#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsbabel.t,v 1.1 2008/01/29 22:17:29 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use BBBikeTest qw(gpxlint_file xmllint_file);
use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempfile);
	1;
    }) {
	print "1..0 # skip: no Test::More and/or File::Temp modules\n";
	exit;
    }
}

my $real_tests = 2;
plan tests => 2 + $real_tests;

use_ok("GPS::Gpsbabel");
my $gpsb = GPS::Gpsbabel->new;
isa_ok($gpsb, "GPS::Gpsbabel");

SKIP: {
    skip("gpsbabel is not available", $real_tests)
	if !$gpsb->gpsbabel_available;

    my $s = Strassen->new("$FindBin::RealBin/../data/comments_scenic");

    {
	my(undef, $gpxfile) = tempfile(UNLINK => 1,
				       SUFFIX => ".gpx");
	$gpsb->strassen_to_gpsbabel($s, "gpx", $gpxfile, as => "track");
	gpxlint_file($gpxfile, "track gpx file converted from strassen using gpsbabel", schema_version => "1.0");
    }

    {
	my(undef, $gpxfile) = tempfile(UNLINK => 1,
				       SUFFIX => ".gpx");
	$gpsb->strassen_to_gpsbabel($s, "gpx", $gpxfile, as => "route");
	gpxlint_file($gpxfile, "route gpx file converted from strassen using gpsbabel", schema_version => "1.0");
    }
}
__END__
