# -*- perl -*-

#
# $Id: CanvasExt.pm,v 1.1 1999/12/12 14:41:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::CanvasExt;
use strict;
use vars qw($direction_arrow_diameter
	    $direction_arrow_shape);

$direction_arrow_diameter = 30;
$direction_arrow_shape    = [6,6,3];

sub _crop_vector {
    my($x1,$y1, $x2,$y2, $dist) = @_;
    my $len = sqrt(($x2-$x1)*($x2-$x1) + ($y2-$y1)*($y2-$y1));
    my($xd,$yd) = ($x1+($x2-$x1)*$dist/$len,
		   $y1+($y2-$y1)*$dist/$len);
    ($xd, $yd);
}

package
  Tk::Canvas;
use Tk::Canvas;

# Hiermit kann man Richtungpfeile (wie auf Verkehrsschildern) malen.
# siehe auch misc/richtungspfeilstudie.pl
sub createDirectionArrow {
    my($c, @args) = @_;

    my(@linedef);
    while(@args) {
	if (ref $args[0] eq 'ARRAY') {
	    push @linedef, shift @args;
	} else {
	    last;
	}
    }
    my(%args) = @args;

    my $diameter = $args{-diameter}
      || $Tk::CanvasExt::direction_arrow_diameter;
    my $radius = $diameter/2;
    my($midx, $midy) = split(/,/, $linedef[0]->[1]);
    if (!exists $args{-arrowshape}) {
	$args{-arrowshape} = $Tk::CanvasExt::direction_arrow_shape;
    }

    my %ovalargs;
    $ovalargs{-fill}
      = delete $args{-background} if exists $args{-background};
    $ovalargs{-outline}
      = delete $args{-outline} if exists $args{-outline};

    $c->createOval($midx-$radius,$midy-$radius,$midx+$radius,$midy+$radius,
		   %ovalargs,
		   -width => 1,
		  );

    foreach my $def (@linedef) {
	my($x1,$y1, $x2,$y2, $x3,$y3) = map { split(/,/, $def->[$_]) } (0..2);
	$c->createLine(Tk::CanvasExt::_crop_vector($x2,$y2,$x1,$y1,$radius-2),
		       Tk::CanvasExt::_crop_vector($x2,$y2,$x1,$y1,2),
		       Tk::CanvasExt::_crop_vector($x2,$y2,$x3,$y3,$radius-2),
		       -arrow => "last",
		       %args,
		      );
    }

}

1;

__END__
