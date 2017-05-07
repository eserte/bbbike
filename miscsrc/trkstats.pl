#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use Cwd 'realpath';
use File::Basename 'basename';
use Getopt::Long;

use BBBikeYAML 'DumpFile';
use GPS::GpsmanData::Any;
use GPS::GpsmanData::Stats;
use Strassen::MultiStrassen;

my $BBBIKEDIR = realpath "$FindBin::RealBin/..";

GetOptions(
	   "destdir=s" => \my $destdir,
	   "q|quiet"   => \my $quiet,
	   "filter-vehicle=s" => \my $filter_vehicle,
	  )
    or die "usage: $0 [--quiet] --destdir directory trkfile ...\n";

if (!$destdir) {
    die "Please specify --destdir for generated stats files.\n";
}

my $areas = MultiStrassen->new("$BBBIKEDIR/data/berlin_ortsteile", "$BBBIKEDIR/data/potsdam");
my $places = MultiStrassen->new("$BBBIKEDIR/data/orte", "$BBBIKEDIR/data/orte2");

for my $f (@ARGV) {
    my $dest = "$destdir/" . basename($f) . '.yml';
    next if -s $dest && -M $dest < -M $f;
    unless ($quiet) { warn "$dest\n" }
    my $g = GPS::GpsmanData::Any->load($f);
    my $s = GPS::GpsmanData::Stats->new($g, areas => $areas, places => $places);
    $s->run_stats(
		  with_nightride => 1,
		  missing_vehicle_fallback => 1,
		 );
    my $dump = $s->human_readable;
    if ($filter_vehicle) {
	$dump = filter_vehicle($dump);
    }
    DumpFile $dest, $dump;
}

sub filter_vehicle {
    my $dump = shift;
    my $new_dump = {};
    if (grep { $_ eq $filter_vehicle } @{ $dump->{vehicles} || [] }) {
	my($min_datetime, $max_datetime);
	for my $chunk (@{ $dump->{chunk_stats} || [] }) {
	    if ($chunk->{vehicle} eq $filter_vehicle) {
		push @{ $new_dump->{chunk_stats} }, $chunk;
		if (!defined $max_datetime || (defined $chunk->{max_datetime} && $chunk->{max_datetime} gt $max_datetime)) {
		    $max_datetime = $chunk->{max_datetime};
		}
		if (!defined $min_datetime || (defined $chunk->{min_datetime} && $chunk->{min_datetime} lt $min_datetime)) {
		    $min_datetime = $chunk->{min_datetime};
		}
	    }
	}
	if (exists $dump->{nightride}) {
	    $new_dump->{nightride} = $dump->{nightride};
	}
	$new_dump->{per_vehicle_stats}->{bike} = $dump->{per_vehicle_stats}->{bike};
	$new_dump->{per_vehicle_stats}->{bike}->{max_datetime} = $max_datetime;
	$new_dump->{per_vehicle_stats}->{bike}->{min_datetime} = $min_datetime;
	# XXX vvv should also be filtered!
	$new_dump->{route} = $dump->{route};
	$new_dump->{route_areas} = $dump->{route_areas};
	# XXX ^^^
	$new_dump->{tags} = $dump->{tags};
    }
    $new_dump;
}

__END__
