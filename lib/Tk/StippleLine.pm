# -*- perl -*-

#
# $Id: StippleLine.pm,v 1.3 1999/08/31 21:40:58 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (c) 1995-1998 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::StippleLine;

$VERSION = '0.04';

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(createStippleLine createStippleLine1);

use constant PI      => atan2(1,1) * 4;
use constant CAKE_SW => (-7*PI/8, -5*PI/8);
use constant CAKE_S  => (-5*PI/8, -3*PI/8);
use constant CAKE_SE => (-3*PI/8, -1*PI/8);
use constant CAKE_E  => (-1*PI/8, PI/8);
use constant CAKE_NE => (   PI/8, 3*PI/8);
use constant CAKE_N  => ( 3*PI/8, 5*PI/8);
use constant CAKE_NW => ( 5*PI/8, 7*PI/8);

sub pollute {
    local $^W = 0;
    package Tk::Canvas;
    *createStippleLine1 = \&Tk::StippleLine::createStippleLine1;
    *createStippleLine  = \&Tk::StippleLine::createStippleLine;
}

sub createStippleLine1 {
    my($c, $x1, $y1, $x2, $y2, %args) = @_;
    my $r = -atan2($y2-$y1, $x2-$x1);
    $args{-stipple} = '@' . Tk->findINC(get_stipple($r));
    $c->createLine($x1, $y1, $x2, $y2, %args);
}

sub createStippleLine {
    my($c, @args) = @_;
    my(@coords) = (shift @args, shift @args, shift @args, shift @args);
    my %args;
    while (@args) {
	if ($args[0] =~ /^[-+]?\d+/) {
	    push @coords, shift @args;
	} else {
	    %args = @args;
	    last;
	}
    }
    if (scalar(@coords)%2 != 0) {
	die "Not an even number of coordinates";
    }
    for(my $i=0; $i<=$#coords-3;$i+=2) {
	createStippleLine1($c, @coords[$i..$i+3], %args);
    }
}

*create1 = \&createStippleLine1;
*create  = \&createStippleLine;

sub get_stipple {
    my($r) = @_;
    if (($r >= (CAKE_NE)[0] and $r <= (CAKE_NE)[1]) ||
	($r >= (CAKE_SW)[0] and $r <= (CAKE_SW)[1])) {
	'grid045.xbm';
    } elsif (($r >= (CAKE_N)[0] and $r <= (CAKE_N)[1]) ||
	     ($r >= (CAKE_S)[0] and $r <= (CAKE_S)[1])) {
	'grid090.xbm';
    } elsif (($r >= (CAKE_NW)[0] and $r <= (CAKE_NW)[1]) ||
	     ($r >= (CAKE_SE)[0] and $r <= (CAKE_SE)[1])) {
	'grid135.xbm';
    } else {
	'grid000.xbm';
    }
}

1;
