#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: conv_geonet_data.pl,v 1.2 2002/04/15 21:13:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin", "$FindBin::RealBin/lib");
use enum qw(:F_ RC UFI UNI DD_LAT DD_LONG DMS_LAT DMS_LONG UTM JOG
	        FC DSG PC CC1 ADM1 ADM2 DIM CC2 NT LC SHORT_FORM
	        GENERIC SORT_NAME FULL_NAME FULL_NAME_ND
	        MODIFY_DATE);
use enum qw(:D_ NAME COORD);

use Getopt::Long;
use Karte;
Karte::preload('Standard', 'Polar');
$Karte::Polar::obj = $Karte::Polar::obj;

my @data;
my %ufi; # ufi to @data index

my($maxx,$maxy,$minx,$miny);

my($dest, $desc);
my $central;
my($centralx, $centraly);
if (!GetOptions("central=s" => \$central,
		"dest=s" => \$dest,
		"desc=s" => \$desc
	       )) {
    die <<EOF;
usage: $0 [-central central] [-dest destfile.bbd] [-desc descfile.desc] file
EOF
}

my $file = shift or die "file?";

if (!$dest) {
    $dest = $file.".bbd";
}
if (!$desc) {
    $desc = $file.".desc";
}


open(F, $file) or die "Can't open $file: $!";
scalar <F>; # header
while(<F>) {
    chomp;
#    $_ = cp850__latin1($_);
    my(@f) = split /\t/;
    if (exists $ufi{$f[F_UFI]}) {
	push @{ $data[$ufi{$f[F_UFI]}]->[D_NAME] }, $f[F_FULL_NAME_ND];
    } else {
	my($x,$y) = map { int } Karte::map2standard($Karte::Polar::obj, $f[F_DD_LONG], $f[F_DD_LAT]);
	$maxx = $x if (!defined $maxx || $x > $maxx);
	$minx = $x if (!defined $minx || $x < $minx);
	$maxy = $y if (!defined $maxy || $y > $maxy);
	$miny = $y if (!defined $miny || $y < $miny);
	my $rec = [];
	push @{ $rec->[D_NAME] }, $f[F_FULL_NAME_ND];
	$rec->[D_COORD] = join(",", $x, $y);
	push @data, $rec;
	$ufi{$f[F_UFI]} = $#data;
	if (defined $central && $central eq $f[F_FULL_NAME_ND]) {
	    ($centralx,$centraly) = ($x,$y);
	}
    }
}
close F;

open(W, ">$dest") or die "Can't write to $dest: $!";
foreach my $rec (@data) {
    my $name = join("/", @{$rec->[D_NAME]});
    my $coord = $rec->[D_COORD];
    print W $name, "\t", "X ", $coord, "\n";
}
close W;

if (defined $central && !defined $centralx) {
    warn "Central point <$central> not found\n";
}

if ($desc) {
    open(D, ">$desc") or die "Can't write to file $desc: $!";
    print D "\@scrollregion = ($minx, $miny, $maxx, $maxy);\n";
    print D "\$center_on_coord = \"$centralx,$centraly\"; # $central \n"
	if defined $centralx;
    close D;
}

__END__
