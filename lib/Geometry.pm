# -*- perl -*-

#
# $Id: Geometry.pm,v 1.1 1999/12/20 21:07:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Geometry;

sub get_intersection {
    my($x1,$y1, $x2,$y2,
       $rectx1,$recty1,$rectx2,$recty2) = @_;

    # normieren
    if ($y1 > $y2) {
	($x1, $x2, $y1, $y2) = ($x2, $x1, $y2, $y1);
    }

    # obere Kante
    if ($y2 > $recty1 && $y1 < $recty1) {
	my $ix = $x1 + ($x2-$x1)/($y2-$y1)*($recty1-$y1);
	if ($ix >= $rectx1 and $ix <= $rectx2) {
	    return ($ix, $recty1);
	}
    }

    # untere Kante
    if ($y2 > $recty2 && $y1 < $recty2) {
	my $ix = $x1 + ($x2-$x1)/($y2-$y1)*($recty2-$y1);
	if ($ix >= $rectx1 and $ix <= $rectx2) {
	    return ($ix, $recty2);
	}
    }

    # normieren
    if ($x1 > $x2) {
	($x1, $x2, $y1, $y2) = ($x2, $x1, $y2, $y1);
    }

    # linke Kante
    if ($x2 > $rectx1 && $x1 < $rectx1) {
	my $iy = $y1 + ($y2-$y1)/($x2-$x1)*($rectx1-$x1);
	if ($iy >= $recty1 and $iy <= $recty2) {
	    return ($rectx1, $iy);
	}
    }

    # rechte Kante
    if ($x2 > $rectx2 && $x1 < $rectx2) {
	my $iy = $y1 + ($y2-$y1)/($x2-$x1)*($rectx2-$x1);
	if ($iy >= $recty1 and $iy <= $recty2) {
	    return ($rectx2, $iy);
	}
    }
}

1;

__END__
