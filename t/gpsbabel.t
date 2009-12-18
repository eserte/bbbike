#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsbabel.t,v 1.8 2008/08/03 09:47:38 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

use Getopt::Long;

use BBBikeTest qw(gpxlint_file xmllint_file);
use BBBikeUtil qw(file_name_is_absolute);
use Strassen::Core;

BEGIN {
    if (!eval q{
	use Test::More;
	use File::Temp qw(tempfile);
	1;
    }) {
	print "1..0 # skip no Test::More and/or File::Temp modules\n";
	exit;
    }
}

my $real_tests = 8;
plan tests => 2 + $real_tests;

my $do_usb_test;
my $debug;
my $keep;
GetOptions("usb!" => \$do_usb_test,
	   "debug!" => \$debug,
	   "keep!" => \$keep,
	  )
    or die "usage: $0 [-usb] [-debug] [-keep]";

use_ok("GPS::Gpsbabel");
my $gpsb = GPS::Gpsbabel->new;
isa_ok($gpsb, "GPS::Gpsbabel");

if ($debug) {
    $GPS::Gpsbabel::DEBUG = $GPS::Gpsbabel::DEBUG = 1;
}
if ($keep) {
    $File::Temp::KEEP_ALL = 1;
}

SKIP: {
    skip("gpsbabel is not available", $real_tests)
	if !$gpsb->gpsbabel_available;

    my $gpsbabel_path = $gpsb->gpsbabel_available;
    ok(file_name_is_absolute($gpsbabel_path),
       $gpsbabel_path . ": should be an absolute path");

    my $s = Strassen->new("$FindBin::RealBin/../data/comments_scenic");

    {
	my(undef, $gpxfile) = tempfile(UNLINK => 1,
				       SUFFIX => ".gpx");
	$gpsb->strassen_to_gpsbabel($s, "gpx", $gpxfile, as => "track");
	gpxlint_file($gpxfile, "track gpx file converted from strassen using gpsbabel", schema_version => "1.0");
	unlink $gpxfile unless $keep;
    }

    {
	my(undef, $gpxfile) = tempfile(UNLINK => 1,
				       SUFFIX => ".gpx");
	$gpsb->strassen_to_gpsbabel($s, "gpx", $gpxfile, as => "route");
	gpxlint_file($gpxfile, "route gpx file converted from strassen using gpsbabel", schema_version => "1.0");
	unlink $gpxfile unless $keep;
    }

    eval {
	$gpsb->run_gpsbabel(["-this", "-is", "-invalid"]);
    };
    my $err = $@;
    like($err, qr{A problem occurred.*gpsbabel}, "Error with run_gpsbabel");
 SKIP: {
	skip("IPC::Run needed for additional error messages", 1)
	    if !eval { require IPC::Run; 1 };
	like($err, qr{Nothing to do.*gpsbabel -h.*for command-line options}, "Additional error message");
    }

 SKIP: {
	skip("Use -usb to actually send a test route to a real Garmin device", 1)
	    if !$do_usb_test;
	$gpsb->strassen_to_gpsbabel($s, "garmin", "usb:", as => "route");
	pass("Sent route...");
    }

    {
	my(undef, $gpxfile) = tempfile(UNLINK => 1,
				       SUFFIX => ".gpx");
	$gpsb->strassen_to_gpsbabel($s, "gpx", $gpxfile, as => "track");
	my $s2 = $gpsb->convert_to_strassen_using_gpsbabel($gpxfile, title => "test title", input_format => "gpx");
	isa_ok($s2, "Strassen", "Converted data is a Strassen object");

	# This test used to simply compare the first and last
	# coordinate in the source and generated file. Unfortunately
	# gpsbabel does not preserve order when generating the gpx
	# file and there's a micture of waypoint and track points.
	# Therefore it is necessary to iterate over the generated file
	# to check for the coordinates.

	my $test_c1 = $s->get(0)->[Strassen::COORDS]->[0];
	my $test_c2 = $s->get(0)->[Strassen::COORDS]->[-1];

	my $found_coord1;
	my $found_coord2;

	$s2->init;
	while(1) {
	    my $r = $s2->next;
	    my @c = @{$r->[Strassen::COORDS]};
	    last if !@c;
	    for my $c (@c) {
		if (is_point_near($c, $test_c1)) {
		    $found_coord1++;
		}
		if (is_point_near($c, $test_c2)) {
		    $found_coord2++;
		}
		last if $found_coord1 && $found_coord2;
	    }
	}

	ok($found_coord1 && $found_coord2, "Found first and last coordinate");

	unlink $gpxfile unless $keep;
    }

}

sub is_point_near {
    my($p1,$p2) = @_;
    my($x1,$y1) = split /,/, $p1;
    my($x2,$y2) = split /,/, $p2;
    abs($x1-$x2) <= 1 && abs($y1-$y2) <= 1;
}

__END__
