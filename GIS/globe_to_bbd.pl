#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: globe_to_bbd.pl,v 1.3 2000/07/26 00:18:36 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data");
use GIS::Globe;
use Karte;
use Getopt::Long;
use Strassen;
use strict;

my $only_berlin = 0;
GetOptions("berlin!" => \$only_berlin);

Karte::preload("Standard", "Polar");
my $std = new Karte::Standard;
my $pol = new Karte::Polar;

my $gis = new GIS::Globe -file => "$FindBin::RealBin/../misc/globe/berlin";
$gis->read_files;

my($from_x, $to_x);
my($from_y, $to_y);

if ($only_berlin) {
    my($min_x, $max_x, $min_y, $max_y) = get_berlin_borders();
    my($min_polar_x, $min_polar_y) = $std->map2map($pol, $min_x, $min_y);
    my($max_polar_x, $max_polar_y) = $std->map2map($pol, $max_x, $max_y);
    my($min_inx_x, $min_inx_y)     = $gis->polar_to_index($min_polar_x,
							  $min_polar_y);
    my($max_inx_x, $max_inx_y)     = $gis->polar_to_index($max_polar_x,
							  $max_polar_y);

    $from_x = min($min_inx_x, $max_inx_x);
    $from_y = min($min_inx_y, $max_inx_y);

    $to_x = max($min_inx_x, $max_inx_x);
    $to_y = max($min_inx_y, $max_inx_y);

} else {
    ($from_x, $to_x) = (0, $gis->{Header}{number_of_columns}-1);
    ($from_y, $to_y) = (0, $gis->{Header}{number_of_rows}-1);
}

for my $y ($from_y .. $to_y) {
    for my $x ($from_x .. $to_x) {
	my($h, $polar_x, $polar_y) = $gis->get_data_by_index($x, $y);
	if (defined $h) {
	    my($std_x,$std_y) = $pol->map2map($std, $polar_x, $polar_y);
	    print "$h\tX $std_x,$std_y\n";
	}
    }
}

sub get_berlin_borders {
    my $s = new Strassen "berlin";
    my($min_x, $max_x, $min_y, $max_y);
    while(1) {
	my $ret = $s->next;
	last if !@{$ret->[1]};
	for (@{$ret->[1]}) {
	    my($x,$y) = split /,/;
	    $min_x = $x if !defined $min_x || $x < $min_x;
	    $max_x = $x if !defined $max_x || $x > $max_x;
	    $min_y = $y if !defined $min_y || $y < $min_y;
	    $max_y = $y if !defined $max_y || $y > $max_y;
	}
    }
    ($min_x, $max_x, $min_y, $max_y);
}

# REPO BEGIN
# REPO NAME max /home/e/eserte/src/repository 
# REPO MD5 cb5508697ccc4e13310c7c8848d48052
=head2 max(...)

Return maximum value.

=cut

sub max {
    my $max = $_[0];
    foreach (@_[1..$#_]) {
	$max = $_ if $_ > $max;
    }
    $max;
}
# REPO END

# REPO BEGIN
# REPO NAME min /home/e/eserte/src/repository 
# REPO MD5 6c10863fe5f2cd682c411b802912d26c
=head2 min(...)

Return minimum value.

=cut

sub min {
    my $min = $_[0];
    foreach (@_[1..$#_]) {
	$min = $_ if $_ < $min;
    }
    $min;
}
# REPO END

__END__
