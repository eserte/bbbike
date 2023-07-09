# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";
use Karte::UTM qw(ConvertDatum DegreesToGKK GKKToDegrees DegreesToUTM UTMToDegrees);

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

BEGIN { plan tests => 16 }

print "# check WGS 84\n";
check(53,13,"WGS 84", 4567136, 5875088);
print "# check Potsdam\n";
my($clat,$clong) = ConvertDatum(53,13,"WGS 84", "Potsdam", "DDD");
check($clat,$clong,"Potsdam", 4567242, 5874643);

{
    my($zone, $hemisphere, $easting, $northing) = DegreesToUTM(53.5,13.5,"International 1924");
    ok $zone, 33;
    ok $hemisphere, 'U';
    ok $easting, 400500;
    ok $northing, 5929067;
}
{
    my($y,$x) = UTMToDegrees(qw(33 U 400500 5929067), "International 1924");
    ok abs($y-53.5) < 0.000001;
    ok abs($x-13.5) < 0.00001;
}


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
