#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: dcwtobbd.pl,v 1.2 2004/03/10 21:53:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net/
#

# convert dcw data (ARC2 ?) to bbd

# Get country data from:
# http://www.maproom.psu.edu/dcw/

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use Karte;
use Getopt::Long;

my $cat = "X";
my $polar_map;
my $gdf_map; # DDD * 1_000_000
my $descfile;

if (!GetOptions("cat=s"  => \$cat,
		"polar!" => \$polar_map,
		"gdf!"   => \$gdf_map,
		"descfile=s" => \$descfile,
		)) {
    die "usage";
}

Karte::preload('Standard','Polar');

my $line;
$line = scalar <>;
if ($line !~ /^EXP/) {
    die "Excpected EXP in first line";
}
$line = scalar <>;
if ($line !~ /^ARC\s+2/) {
    die "Expected ARC version 2 data (?)";
}

my($minx,$maxx,$miny,$maxy);

my($x,$y);
my $minmax;
if ($descfile) {
    $minmax = sub {
	$minx = $x if (!defined $minx || $minx > $x);
	$miny = $y if (!defined $miny || $miny > $y);
	$maxx = $x if (!defined $maxx || $maxx < $x);
	$maxy = $y if (!defined $maxy || $maxy < $y);
    };
} else {
    $minmax = sub {};
}

while(<>) {
    chomp;
    s/^\s+//;
    my($id, undef, undef, undef, undef, undef, $no_coords) = split /\s+/;
    last if $id < 0;
    my @coords;
    while(<>) {
	chomp;
	s/^\s+//;
	my(@l) = split /\s+/;
	for(my $i=0; $i<$#l; $i+=2) {
	    if ($polar_map) {
		($x,$y) = map { $_+0 } @l[$i,$i+1];
		$minmax->();
		push @coords, "P".join(",", $x,$y);
	    } elsif ($gdf_map) {
		($x,$y) = map { $_*1_000_000 } @l[$i,$i+1];
		$minmax->();
		push @coords, "W".join(",", $x,$y);
	    } else {
		($x,$y) = map { int } $Karte::Polar::obj->map2standard(map { $_+0 } @l[$i,$i+1]);
		$minmax->();
		push @coords, join(",", $x,$y);
	    }
	}
	last if (scalar @coords >= $no_coords);
    }
    my $cat = $cat;
    if (@coords > 1 && $coords[0] eq $coords[-1]) {
	$cat = "F:$cat";
    }
    print "$id\t$cat @coords\n";
}

if ($descfile) {
    open(DESC, ">$descfile") or die "Can't write $descfile: $!";
    print DESC '@scrollregion = ' . "($minx,$miny,$maxx,$maxy)\n";
    close DESC;
}

__END__

# Sample makefile for a dataset:

#
# $Id: dcwtobbd.pl,v 1.2 2004/03/10 21:53:08 eserte Exp $
#

#BBBIKEDIR?=/oo/projekte/bbbike/bbbike-devel
BBBIKEDIR?=$(HOME)/src/bbbike

all:	normal devel

normal: landstrassen rbahn wasserstrassen flaechen orte-label

devel: landstrassen-orig rbahn-orig wasserstrassen-orig flaechen-orig orte-label-orig

landstrassen: rdline.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -cat HH > $@

rbahn: rrline.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -cat R > $@

wasserstrassen: dnnet.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -cat W > $@

flaechen: pppoly.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -cat 'F:#ffffff' > $@

#orte: orte.e00
orte-label: pppoly.e00 pppoint.e00
	cat $^ | $(BBBIKEDIR)/miscsrc/e00_to_bbd.pl -cat 3 > $@

landstrassen-orig: rdline.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -gdf -cat HH > $@

rbahn-orig: rrline.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -gdf -cat R > $@

wasserstrassen-orig: dnnet.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -gdf -cat W > $@

flaechen-orig: pppoly.e00
	< $^ $(BBBIKEDIR)/miscsrc/dcwtobbd.pl -descfile $@.desc -gdf -cat 'F:#ffffff' > $@

#orte-orig: orte.e00
orte-label-orig: pppoly.e00 pppoint.e00
#	< $^ $(BBBIKEDIR)/miscsrc/e00_tx7_to_bbd.pl -map polar > $@
# XXX not yet:
#	cat $^ | $(BBBIKEDIR)/miscsrc/e00_to_bbd.pl -cat 3 -map polar > $@
