#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: karte_utm.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";
use Karte::UTM qw(ConvertDatum DegreesToGKK GKKToDegrees);

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	my $ok = 1;
	*ok = sub {
	    my($got, $expected) = @_;
	    if ($got ne $expected) {
		print "not ";
	    }
	    print "ok " . ($ok++) . "\n";
	};
	*plan = sub {
	    my(%args) = @_;
	    print "1 .. $args{tests}\n";
	};
    }
}

BEGIN { plan tests => 10 }

print "# check WGS 84\n";
check(53,13,"WGS 84", 4567136, 5875088);
print "# check Potsdam\n";
my($clat,$clong) = ConvertDatum(53,13,"WGS 84", "Potsdam", "DDD");
check($clat,$clong,"Potsdam", 4567242, 5874643);

sub check {
    my($lat, $long, $datum,
       $expected_easting, $expected_northing) = @_;
    my($zone, $easting, $northing) = DegreesToGKK($lat,$long,$datum);
    ok($zone, 4);
    ok($easting, $expected_easting);
    ok($northing, $expected_northing);
    my($lat1,$long1) = GKKToDegrees($zone, $easting, $northing, $datum);
    my($zone1, $easting1, $northing1) = DegreesToGKK($lat1,$long1,$datum);
    ok($easting, $easting1);
    ok($northing, $northing1);
}

__END__
