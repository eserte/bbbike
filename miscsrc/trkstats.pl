#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2020,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../miscsrc",
	);

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
	   "force-update!" => \my $force_update,
	   "filter-vehicle=s" => \my $filter_vehicle,
	   'inject-plugin=s@' => \my @inject_plugins,
	  )
    or die qq{usage: $0 [--quiet] [--force-update] [--filter-vehicle ...] [--inject-plugin "/path/to/plugin Package::function"] --destdir directory trkfile ...\n};

if (!$destdir) {
    die "Please specify --destdir for generated stats files.\n";
}

my @inject_functions;
for my $inject_plugin (@inject_plugins) {
    my($file, $function) = split /\s+/, $inject_plugin, 2;
    require $file;
    if (!defined &$function) {
	die "$file did not provide function $function";
    }
    push @inject_functions, \&$function;
}

my $areas = MultiStrassen->new("$BBBIKEDIR/data/berlin_ortsteile", "$BBBIKEDIR/data/potsdam");
my $places = MultiStrassen->new("$BBBIKEDIR/data/orte", "$BBBIKEDIR/data/orte2");

for my $f (@ARGV) {
    my $dest = "$destdir/" . basename($f) . '.yml';
    next if !$force_update && (-s $dest && -M $dest < -M $f);
    unless ($quiet) { warn "$dest\n" }
    my $g = GPS::GpsmanData::Any->load($f);
    my $s = GPS::GpsmanData::Stats->new($g, areas => $areas, places => $places);
    $s->run_stats(
		  with_nightride => 1,
		  missing_vehicle_fallback => 1,
		  missing_route_area_fallback => \&missing_route_area_fallback,
		 );
    my $dump = $s->human_readable;
    if ($filter_vehicle) {
	$dump = filter_vehicle($dump);
    }
    for my $inject_function (@inject_functions) {
	$inject_function->($dump, $f);
    }
    DumpFile "$dest~", $dump;
    rename "$dest~", $dest
	or die "Error renaming $dest~ to $dest: $!";
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
	$new_dump->{max_datetime} = $max_datetime;
	$new_dump->{min_datetime} = $min_datetime;
	$new_dump->{dist} = $new_dump->{per_vehicle_stats}->{bike}->{dist};
	# XXX vvv should also be filtered!
	$new_dump->{route} = $dump->{route};
	$new_dump->{route_areas} = $dump->{route_areas};
	# XXX ^^^
	$new_dump->{tags} = $dump->{tags};
    }
    $new_dump;
}

{
    my $rg_osm;

    sub missing_route_area_fallback {
	my($lon,$lat) = @_;

	if (!$rg_osm) {
	    require ReverseGeocoding;
	    $rg_osm = ReverseGeocoding->new('osm');
	}

	my $res = $rg_osm->find_closest("$lon,$lat", 'area');
	$res;
    }
}

__END__
