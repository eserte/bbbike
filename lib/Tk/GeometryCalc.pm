# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::GeometryCalc;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.01';

use Exporter qw(import);

@EXPORT_OK = qw(crop_geometry parse_geometry_string GEOMETRY_X GEOMETRY_Y GEOMETRY_WIDTH GEOMETRY_HEIGHT);

use constant GEOMETRY_X      => 0;
use constant GEOMETRY_Y      => 1;
use constant GEOMETRY_WIDTH  => 2;
use constant GEOMETRY_HEIGHT => 3;

# crops the array in $want_extends to the limits in $extends
sub crop_geometry {
    my($top, $want_extends, $extends) = @_;

    # right/bottom limits
    my $x = $want_extends->[GEOMETRY_X] =~ /^-/ ?
	$top->screenwidth - $want_extends->[GEOMETRY_WIDTH] + $want_extends->[GEOMETRY_X] :
	    $want_extends->[GEOMETRY_X];
    my $y = $want_extends->[GEOMETRY_Y] =~ /^-/ ?
	$top->screenheight - $want_extends->[GEOMETRY_HEIGHT] + $want_extends->[GEOMETRY_Y] :
	    $want_extends->[GEOMETRY_Y];

    if ($x < $extends->[GEOMETRY_X]) {
	$want_extends->[GEOMETRY_X] = $extends->[GEOMETRY_X];
    }
    if ($y < $extends->[GEOMETRY_Y]) {
	$want_extends->[GEOMETRY_Y] = $extends->[GEOMETRY_Y];
    }
    if ($x + $want_extends->[GEOMETRY_WIDTH] > $extends->[GEOMETRY_WIDTH]) {
	$want_extends->[GEOMETRY_X] = 0;
	$want_extends->[GEOMETRY_WIDTH] = $extends->[GEOMETRY_WIDTH];
    }
    if ($y + $want_extends->[GEOMETRY_HEIGHT] > $extends->[GEOMETRY_HEIGHT]) {
	$want_extends->[GEOMETRY_Y] = 0;
	$want_extends->[GEOMETRY_HEIGHT] = $extends->[GEOMETRY_HEIGHT];
    }
}

sub parse_geometry_string {
    my $geometry = shift;
    my @extends = (0, 0, 0, 0);
    if ($geometry =~ /([-+]?\d+)x([-+]?\d+)/) {
	$extends[GEOMETRY_WIDTH] = $1;
	$extends[GEOMETRY_HEIGHT] = $2;
    }
    if ($geometry =~ /([-+]\d+)([-+]\d+)/) {
	$extends[GEOMETRY_X] = $1;
	$extends[GEOMETRY_Y] = $2;
    }
    @extends;
}

1;

__END__
