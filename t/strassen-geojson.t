#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

#use File::Temp qw(tempfile);
use Test::More;

use Strassen;
use Strassen::GeoJSON;

plan 'no_plan';

{
    my $test_strassen_file = "$FindBin::RealBin/data-test/strassen";
    my $s = Strassen->new($test_strassen_file);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson();

    my $s2_geojson = Strassen::GeoJSON->new;
    $s2_geojson->geojsonstring2bbd($geojson);

    is_deeply $s2_geojson->{data}, $s->{data}, 'roundtrip check with data-test/strassen';
}

{
    my $test_ampeln_file = "$FindBin::RealBin/data-test/ampeln";
    my $s = Strassen->new($test_ampeln_file);
    my $s_geojson = Strassen::GeoJSON->new($s);
    my $geojson = $s->bbd2geojson();

    my $s2_geojson = Strassen::GeoJSON->new;
    $s2_geojson->geojsonstring2bbd($geojson);

    is_deeply $s2_geojson->{data}, $s->{data}, 'roundtrip check with data-test/ampeln';
}
