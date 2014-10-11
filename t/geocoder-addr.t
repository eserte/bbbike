#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc", 
	);

use Test::More 'no_plan';

sub check_geocoding ($$$;$);
sub check_parse_string ($$);
sub utf8 ($);

use_ok 'GeocoderAddr';

my $geocoder = GeocoderAddr->new_berlin_addr;
isa_ok $geocoder, 'GeocoderAddr';

SKIP: {
    skip "_addr file is not available", 1
	if !$geocoder->check_availability;

    {
	my $regexp = $geocoder->build_search_regexp("Dudenstraße");
	ok $regexp;
    }

    # only street, titlecase and lowercase
    for my $str ('Dudenstraße', 'dudenstraße') {
	check_geocoding $str, qr{^Dudenstraße}, '13.370467,52.485352 13.386009,52.484715'
    }
    {
	my $dudenstr24_bbox = '13.381574,52.485224 13.382067,52.484818';
	check_geocoding "Dudenstraße 24", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstr. 24", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, Berlin", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, Berlin, 10965", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
	check_geocoding "Dudenstraße 24, 10965 Berlin", "Dudenstraße 24, 10965 Berlin", $dudenstr24_bbox;
    }

    {
	# Beginning with umlaut
	my $uederseestr1_bbox = '13.520082,52.482163 13.519437,52.482601';
	check_geocoding 'Üderseestraße 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, without utf8 flag';
	check_geocoding 'Üderseestr. 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, without utf8 flag';
	check_geocoding 'üderseestraße 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, lowercase, without utf8 flag';
	check_geocoding 'üderseestr. 1', 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, lowercase, without utf8 flag';
    }

    {
	# internal utf8 should also work
	my $uederseestr1_bbox = '13.520082,52.482163 13.519437,52.482601';
	check_geocoding utf8('Üderseestraße 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, with utf8 flag';
	check_geocoding utf8('Üderseestr. 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, without utf8 flag';
	check_geocoding utf8('üderseestraße 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'full name, lowercase, without utf8 flag';
	check_geocoding utf8('üderseestr. 1'), 'Üderseestraße 1, 10318 Berlin', $uederseestr1_bbox, 'short name, lowercase, without utf8 flag';
    }

    {
	# Another umlaut street
	my $aehrenweg10_bbox = '13.561505,52.514429 13.562112,52.514098';
	check_geocoding 'Ährenweg 10', 'Ährenweg 10, 12683 Berlin', $aehrenweg10_bbox;
	check_geocoding 'ährenweg 10', 'Ährenweg 10, 12683 Berlin', $aehrenweg10_bbox;
    }
}

check_parse_string "Dudenstraße 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstr. 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstraße 24, Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin" };
check_parse_string "Dudenstraße 24, Berlin, 10965", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };
check_parse_string "Dudenstraße 24, 10965 Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };

sub check_geocoding ($$$;$) {
    my($in_street, $expected_street, $bbox, $testname) = @_;
    $testname = defined $testname ? " ($testname)" : '';
    my $res = $geocoder->geocode(location => $in_street);
    ok $res, "got a result for <$in_street>" . $testname;
    if ($res) {
	if (ref $expected_street eq 'Regexp') {
	    like $res->{display_name}, $expected_street, "regexp check" . $testname;
	} else {
	    is $res->{display_name}, $expected_street, "equality check" . $testname;
	}
	my($x1,$y1,$x2,$y2) = split /[, ]/, $bbox;
	($x1,$x2) = ($x2,$y1) if $x1 > $x2;
	($y1,$y2) = ($y2,$y1) if $y1 > $y2;
	my($lon, $lat) = @{$res}{qw(lon lat)};
	ok $lon >= $x1 && $lon <= $x2 && $lat >= $y1 && $lat <= $y2, 'lon/lat within bounding box' . $testname
	    or diag "Got lon=$lon lat=$lat, not within $bbox" . $testname;
    } else {
	fail "No result - no further checks" . $testname for (1..2);
    }
}

sub check_parse_string ($$) {
    my($location, $expected_result) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $res = $geocoder->parse_search_string($location);
    for my $key (keys %$res) {
	delete $res->{$key} if !defined $res->{$key};
    }
    is delete($res->{location}), $location, "location check for '$location'";
    is_deeply $res, $expected_result, "parse_search_string check for '$location'";
}

sub utf8 ($) {
    my $s = shift;
    utf8::upgrade($s);
    $s;
}

__END__
