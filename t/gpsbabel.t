#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: gpsbabel.t,v 1.6 2008/02/06 19:42:12 eserte Exp $
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
	print "1..0 # skip: no Test::More and/or File::Temp modules\n";
	exit;
    }
}

my $real_tests = 9;
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
	is_point_near($s2->get(0)->[Strassen::COORDS]->[0],
		      $s->get(0)->[Strassen::COORDS]->[0], "Expected first coordinate");
	is_point_near($s2->get($s2->count-1)->[Strassen::COORDS]->[-1],
		      $s->get($s->count-1)->[Strassen::COORDS]->[-1], "Expected last coordinate");

	unlink $gpxfile unless $keep;
    }

}

sub is_point_near {
    my($p1,$p2,$testname) = @_;
    my($x1,$y1) = split /,/, $p1;
    my($x2,$y2) = split /,/, $p2;
    ok(abs($x1-$x2) <= 1 && abs($y1-$y2) <= 1, $testname)
	or diag("$p1 is not near $p2");
}

__END__
