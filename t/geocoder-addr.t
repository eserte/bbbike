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

sub check_geocoding ($$$);
sub check_parse_string ($$);

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
}

check_parse_string "Dudenstraße 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstr. 24", { str => "Dudenstraße", hnr => "24" };
check_parse_string "Dudenstraße 24, Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin" };
check_parse_string "Dudenstraße 24, Berlin, 10965", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };
check_parse_string "Dudenstraße 24, 10965 Berlin", { str => "Dudenstraße", hnr => "24", city => "Berlin", zip => "10965" };

sub check_geocoding ($$$) {
    my($in_street, $expected_street, $bbox) = @_;
    my $res = $geocoder->geocode(location => $in_street);
    ok $res, "got a result for <$in_street>";
    if (ref $expected_street eq 'Regexp') {
	like $res->{display_name}, $expected_street;
    } else {
	is $res->{display_name}, $expected_street;
    }
    my($x1,$y1,$x2,$y2) = split /[, ]/, $bbox;
    ($x1,$x2) = ($x2,$y1) if $x1 > $x2;
    ($y1,$y2) = ($y2,$y1) if $y1 > $y2;
    my($lon, $lat) = @{$res}{qw(lon lat)};
    ok $lon >= $x1 && $lon <= $x2 && $lat >= $y1 && $lat <= $y2, 'lon/lat within bounding box'
	or diag "Got lon=$lon lat=$lat, not within $bbox";
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

__END__
