#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use utf8;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc", # for ExtractBBBikeOrg.pm
	);

use File::Temp qw(tempdir);
use Test::More 'no_plan';

use ExtractBBBikeOrg;

my $ebo = ExtractBBBikeOrg->new;
isa_ok $ebo, 'ExtractBBBikeOrg';

{
    my $extract_de_dir = tempdir(TMPDIR => 1, CLEANUP => 1);
    open my $ofh, ">:encoding(UTF-8)", "$extract_de_dir/README.txt" or die $!;
    print $ofh <<EOF;
...
Diese BBBike Karte wurde erzeugt am: Mon Sep 18 18:58:29 UTC 2017
BBBike Kartenstil:  ()
GPS Rechteck Koordinaten (lng,lat): 10.044,50.854 x 10.633,51.125
Script URL: https://extract3.bbbike.org/?sw_lng=10.044&sw_lat=50.854&ne_lng=10.633&ne_lat=51.125&format=bbbike-perltk.zip&city=Eisenach&lang=de
Name des Gebietes: Eisenach
...
EOF
    close $ofh or die $!;

    is $ebo->get_dataset_title($extract_de_dir), 'Eisenach', 'expected value from de README.txt';
}

{
    my $extract_en_dir = tempdir(TMPDIR => 1, CLEANUP => 1);
    open my $ofh, ">:encoding(UTF-8)", "$extract_en_dir/README.txt" or die $!;
    print $ofh <<EOF;
...
This Garmin map was created on: Tue May  9 21:12:41 UTC 2017
Garmin map style: osm
GPS rectangle coordinates (lng,lat): 4.732,45.665 x 5.134,45.834
Script URL: https://extract.bbbike.org/?sw_lng=4.732&sw_lat=45.665&ne_lng=5.134&ne_lat=45.834&format=garmin-osm.zip&coords=4.757%2C45.679%7C5.134%2C45.665%7C5.121%2C45.789%7C4.923%2C45.831%7C4.773%2C45.834%7C4.732%2C45.763&city=Lyon
Name of area: Lyon
...
EOF
    close $ofh or die $!;

    is $ebo->get_dataset_title($extract_en_dir), 'Lyon', 'expected value from en README.txt';
}


__END__
