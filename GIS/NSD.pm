# -*- perl -*-

#
# $Id: NSD.pm,v 1.3 2001/11/17 14:04:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# http://www.nws.noaa.gov/pub/stninfo/nsd_cccc.txt
# Also distributed with tkGeoMap.
# A list of weather stations.

package GIS::NSD;

use strict;
use vars qw($VERSION);
$VERSION = "0.01";

######################################################################

package GIS::NSD::Record;

if (eval 'use fields qw(icao_location wmo_block wmo_station
                        city state country wmo_region
                        lat long upper_air_lat upper_air_long
                        elevation upper_air_elevation rsbn_indicator
                       ); $] >= 5.006') {
    eval <<'EOF';
sub new {
    my GIS::NSD::Record $self = shift;
    unless (ref $self) {
        $self = fields::new($self);
    }
    $self;
}
EOF
    warn $@ if $@;
} else {
    eval <<'EOF';
sub new { bless {}, $_[0] }
EOF
    warn $@ if $@;
}

=head2 _position_to_decimal()

Recalculate positions to decimal degrees.

=cut

sub _position_to_decimal {
    my $self = shift;
    foreach my $pos (qw/lat long upper_air_lat upper_air_long/) {
	next if !defined $self->{$pos} || $self->{$pos} eq '';
	if ($self->{$pos} =~ /^(\d+)-(\d+)\s*(-(\d*)\s*)?(.)$/) {
	    $self->{$pos} = $1 + $2/60;
	    if (defined $4) {
		local $^W = 0;
		$self->{$pos} += $3/3600;
	    }
	    if ($5 =~ /^[SW]$/) {
		$self->{$pos} = -$self->{$pos};
	    }
	} else {
	    warn "Can't parse $self->{$pos}";
	}
    }
}

######################################################################

package GIS::NSD;

sub new {
    my($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    if ($args{-file}) {
	$self->{File} = $args{-file};
    }

    $self;
}

sub read_file {
    my $self = shift;
    open(F, $self->{File})
	or die "Can't open $self->{File}: $!";
    $self->{Data} = [];
    while(<F>) {
	chomp;
	my $row = new GIS::NSD::Record;
	@{$row}{qw(icao_location wmo_block wmo_station city state country
		   wmo_region lat long upper_air_lat upper_air_long
		   elevation upper_air_elevation rsbn_indicator)} =
		       split /;/;
	$row->_position_to_decimal;
	push @{ $self->{Data} }, $row;
    }
    close F;
    $self->{Data};
}

sub find_by_wmo_station_index {
    my($self, $wmo_station_index) = @_;
    my($block_number, $station_number) = $wmo_station_index =~ /^(..)(...)$/;
    if (!defined $block_number) {
	die "Can't parse WMO station index $wmo_station_index";
    }
    foreach my $d (@{ $self->{Data} }) {
	if ($d->{wmo_block} eq $block_number &&
	    $d->{wmo_station} eq $station_number) {
	    return $d;
	}
    }
    undef;
}

return 1 if caller;

package main;

my $nsd = new GIS::NSD
    -file => "/usr/local/src/tkGeoMap/data/places/nsd_cccc.txt";
$nsd->read_file;
for (@{$nsd->{Data}}) {
    use Data::Dumper;
    print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" 
	. Data::Dumper->Dumpxs([$_],[]);
}

__END__
