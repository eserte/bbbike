# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCanvasUtil;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.01';

use Exporter 'import';
@EXPORT_OK = qw(draw_bridge draw_tunnel_entrance);

use BBBikeUtil qw(pi);

sub draw_bridge {
    my($c,$cl,%args) = @_;
    my $width = $args{'-width'}||10;
    my $color = '#808080';
    my $thickness = 2; # make configurable XXX
#XXX complicated code, make nicer!
#XXX an den Enden etwas verkürzen
    for(my $i = 0; $i < $#$cl/2-1; $i++) {
	my($x1,$y1,$x2,$y2) = @{$cl}[$i*2..$i*2+3];
	my $alpha = atan2($y2-$y1,$x2-$x1);
	my $beta = $alpha - (pi)/2;
	my $delta = $width/2;
	my($dx,$dy) = ($delta*cos($beta), $delta*sin($beta));
	$c->createLine($x1+$dx,$y1+$dy,$x2+$dx,$y2+$dy,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
	$c->createLine($x1-$dx,$y1-$dy,$x2-$dx,$y2-$dy,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
    }
    {
	my $alpha = atan2($cl->[3]-$cl->[1],$cl->[2]-$cl->[0]);
	my $beta  = $alpha - (pi)/2;
	my $knick = $alpha - (pi)/4;
	my $knick2 = $alpha + (pi)/4;
	my $delta = $width/2;
	my $knick_length = $width/2;
	my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
	my($kx, $ky) = ($knick_length*cos($knick), $knick_length*sin($knick));
	my($k2x, $k2y) = ($knick_length*cos($knick2), $knick_length*sin($knick2));
	$c->createLine($cl->[0]+$dx-$k2x, $cl->[1]+$dy-$k2y,
		       $cl->[0]+$dx, $cl->[1]+$dy,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
	$c->createLine(
		       $cl->[0]-$dx, $cl->[1]-$dy,
		       $cl->[0]-$dx-$kx, $cl->[1]-$dy-$ky,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
    }

    {
	my $alpha = atan2($cl->[-1]-$cl->[-3],$cl->[-2]-$cl->[-4]);
	my $beta  = $alpha - (pi)/2;
	my $knick = $alpha - (pi)/4;
	my $knick2 = $alpha + (pi)/4;
	my $delta = $width/2;
	my $knick_length = $width/2;
	my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
	my($kx, $ky) = ($knick_length*cos($knick), $knick_length*sin($knick));
	my($k2x, $k2y) = ($knick_length*cos($knick2), $knick_length*sin($knick2));
	$c->createLine($cl->[-2]+$dx+$kx, $cl->[-1]+$dy+$ky,
		       $cl->[-2]+$dx, $cl->[-1]+$dy,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
	$c->createLine(
		       $cl->[-2]-$dx, $cl->[-1]-$dy,
		       $cl->[-2]-$dx+$k2x, $cl->[-1]-$dy+$k2y,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
    }
    
}

sub draw_tunnel_entrance {
    my($c,$cl,%args) = @_;
    my $width = $args{'-width'}||20;
    my $color = '#505050';
    my $thickness = 3;
    my $mounds = delete $args{'-mounds'} || "Tu";
#XXX complicated code, make nicer!
    if ($mounds !~ m{^_}) {
	my $alpha = atan2($cl->[3]-$cl->[1],$cl->[2]-$cl->[0]);
	my $beta  = $alpha - (pi)/2;
	my $knick = $alpha - (pi)/4;
	my $knick2 = $alpha + (pi)/4;
	my $delta = $width/2;
	my $knick_length = $width/3;
	my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
	my($kx, $ky) = ($knick_length*cos($knick), $knick_length*sin($knick));
	my($k2x, $k2y) = ($knick_length*cos($knick2), $knick_length*sin($knick2));
	$c->createLine($cl->[0]+$dx-$k2x, $cl->[1]+$dy-$k2y,
		       $cl->[0]+$dx, $cl->[1]+$dy,
		       $cl->[0]-$dx, $cl->[1]-$dy,
		       $cl->[0]-$dx-$kx, $cl->[1]-$dy-$ky,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
    }
    if ($mounds !~ m{_$}) {
	my $alpha = atan2($cl->[-1]-$cl->[-3],$cl->[-2]-$cl->[-4]);
	my $beta  = $alpha - (pi)/2;
	my $knick = $alpha - (pi)/4;
	my $knick2 = $alpha + (pi)/4;
	my $delta = $width/2;
	my $knick_length = $width/3;
	my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
	my($kx, $ky) = ($knick_length*cos($knick), $knick_length*sin($knick));
	my($k2x, $k2y) = ($knick_length*cos($knick2), $knick_length*sin($knick2));
	$c->createLine($cl->[-2]+$dx+$kx, $cl->[-1]+$dy+$ky,
		       $cl->[-2]+$dx, $cl->[-1]+$dy,
		       $cl->[-2]-$dx, $cl->[-1]-$dy,
		       $cl->[-2]-$dx+$k2x, $cl->[-1]-$dy+$k2y,
		       -width => $thickness,
		       -tags => $args{'-tags'},
		       -fill => $color,
		      );
    }
}

1;

__END__
