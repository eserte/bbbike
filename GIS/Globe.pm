# -*- perl -*-

#
# $Id: Globe.pm,v 1.9 2001/11/26 09:39:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# see also ..../bbbike/misc/globe/show.pl

package GIS::Globe;

use strict;
use vars qw($VERSION);
$VERSION = "0.02";

sub new {
    my($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    if ($args{-file}) {
	my $file = $args{-file};
	$self->{HeaderFile} = "$file.hdr";
	$self->{FormatFile} = "$file.fmt";
	$self->{BinaryFile} = "$file.bin";
    }

    $self;
}

# REPO BEGIN
# REPO NAME pi /home/e/eserte/src/repository 
# REPO MD5 bb2103b1f2f6d4c047c4f6f5b3fa77cd
sub _pi ()   { 4 * atan2(1, 1) } # 3.141592653
# REPO END


sub read_files {
    my $self = shift;
    $self->read_header_file;
    $self->read_format_file;
    $self->read_binary_file;
}

sub read_header_file {
    my $self = shift;
    open(F, $self->{HeaderFile})
	or die "Can't open $self->{HeaderFile}: $!";
    $self->{Header} = {};
    while(<F>) {
	chomp;
	my($k,$v) = split(/\s*=\s*/, $_, 2);
	# use old values...
	if ($k eq 'elev_m_min') { $k = 'elev_m_minimum' }
	if ($k eq 'elev_m_max') { $k = 'elev_m_maximum' }
	$self->{Header}{$k} = $v;
    }
    close F;
}

sub read_format_file {
    # NYI assume little endian
}

sub read_binary_file {
    my $self = shift;

    my $data = [];
    my $num_rows  = $self->{Header}{number_of_rows};
    my $num_cols  = $self->{Header}{number_of_columns};
    my $undef_val = $self->{Header}{elev_m_missing_flag};

    open(F, $self->{BinaryFile})
	or die "Can't open $self->{BinaryFile}: $!";
    for my $y (0 .. $num_rows-1) {
	read F, my $buf, $num_cols*2;
	my $row = [];
	for my $x (0 .. $num_cols-1) {
	    my $h = unpack("s", substr($buf, $x*2, 2));
	    if ($h == $undef_val) {
		$h = undef;
	    }
	    push @$row, $h;
	}
	push @$data, $row;
    }
    close F;

    $self->{Data} = $data;
}

sub width    { $_[0]->{Header}{number_of_columns} }
sub height   { $_[0]->{Header}{number_of_rows} }
sub gridsize { $_[0]->{Header}{grid_size} }

sub polar_to_index {
    my($self, $polar_x, $polar_y) = @_;
    my $grid = $self->{Header}{grid_size};
    my $inx_x = ($polar_x+$grid-$self->{Header}{left_map_x})  / $grid;
    my $inx_y = $self->{Header}{number_of_rows} - 
	        ($polar_y+$grid/2-$self->{Header}{lower_map_y}) / $grid;
    ($inx_x, $inx_y);
}

sub index_to_polar {
    my($self, $inx_x, $inx_y) = @_;
    my $grid = $self->{Header}{grid_size};
    my $polar_x = $inx_x*$grid + $self->{Header}{left_map_x} + $grid;
    my $polar_y = ($self->{Header}{number_of_rows}-$inx_y)*$grid +
	          $self->{Header}{lower_map_y} - $grid/2;
    ($polar_x, $polar_y);
}

=head2 get_data_by_polar($polar_x,$polar_y)

Return height, index x and index y for polar coordinates x/y.

=cut

sub get_data_by_polar {
    my($self, $polar_x, $polar_y) = @_;
    my($inx_x, $inx_y) = $self->polar_to_index($polar_x, $polar_y);
    ($self->{Data}[ $inx_y ][ $inx_x ], $inx_x, $inx_y);
}

=head2 get_data_by_index($x,$y)

Return height, polar x and polar y for data column $x and data row $y.

=cut

sub get_data_by_index {
    my($self, $inx_x, $inx_y) = @_;
    my $h = $self->{Data}[ $inx_y ][ $inx_x ];
    my($polar_x, $polar_y) = $self->index_to_polar($inx_x, $inx_y);
    ($h, $polar_x, $polar_y);
}

sub show_suggested_aspect {
    my $self = shift;
    my $w = $self->{Header}{'number_of_columns'};
    my $h = $self->{Header}{'number_of_rows'};
    my $long_w = $self->{Header}{'right_map_x'} - $self->{Header}{'left_map_x'};
    my $lat_h = $self->{Header}{'upper_map_y'} - $self->{Header}{'lower_map_y'};
    my $center_lat = $self->{Header}{'lower_map_y'} + $lat_h/2;
    my $aspect   = cos($center_lat/180*_pi);
    my $aspect_1 = 1/$aspect;
    my $change_h = int($h/$aspect);
    my $change_w = int($w/$aspect_1);
    print STDERR <<EOF
Aspect:              1 : $aspect
                     $aspect_1 : 1
Proposed dimensions: ${w}x${change_h}
                     ${change_w}x${h}
EOF
}

return 1 if caller;

package main;

eval q{
       use FindBin;
       use lib "$FindBin::RealBin/..";
       use Karte;
};
die $@ if $@;

Karte::preload(qw/Standard Polar/);
my $std   = new Karte::Standard;
my $polar = new Karte::Polar;

my $gis = new GIS::Globe
              -file => "$FindBin::RealBin/../misc/globe/berlin";
$gis->read_files;

print STDERR "Hafas coords x,y > ";
while(<STDIN>) {
    s/^\s+//; # trim leading space
    my($hafas_x,$hafas_y) = split /,/;
    my($polar_x,$polar_y) = $std->map2map($polar, $hafas_x, $hafas_y);
    print STDERR "$polar_x,$polar_y => " .
	($gis->get_data_by_polar($polar_x,$polar_y))[0] . "m\n";
    print STDERR "> ";
}

__END__
