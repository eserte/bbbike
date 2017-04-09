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
    DumpFile $dest, $s->human_readable;
}

__END__
