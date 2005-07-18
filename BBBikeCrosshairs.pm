# -*- perl -*-

#
# $Id: BBBikeCrosshairs.pm,v 1.3 2005/07/18 21:57:13 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeCrosshairs;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use vars qw(@old_bindings $angle $pd $angle_steps $pd_steps);
$angle = 0       if !defined $angle;
$pd = 0          if !defined $pd; # distance of parallel lines
$angle_steps = 1 if !defined $angle_steps;
$pd_steps = 2    if !defined $pd_steps;

use BBBikeUtil qw(pi deg2rad);

sub activate {
    my $c   = $main::c;
    my $top = $main::top;

    for my $event (qw(Motion)) {
	my $old_binding = $c->CanvasBind("<$event>");
	push @old_bindings, sub { $c->CanvasBind("<$event>" => $old_binding) };
    }
    for my $event (qw(F4 F5 Shift-F4 F6 F7 Shift-F6)) {
	my $old_binding = $top->bind("<$event>");
	push @old_bindings, sub { $top->bind("<$event>" => $old_binding) };
    }

    if (!$c->find("withtag", "crosshairs")) {
	my $sw = $c->screenwidth > $c->screenheight ? $c->screenwidth : $c->screenheight;

	my $ch1  = $c->createLine(0,0,-tags => ["crosshairs", "crosshairs1"]);
	my $ch2  = $c->createLine(0,0,-tags => ["crosshairs", "crosshairs2"]);
	my $chp  = $c->createLine(0,0,-tags => ["crosshairs", "crosshairs-parallel"], -dash => ".-");
	my $chlp = $c->createLine(0,0,-tags => ["crosshairs", "crosshairs-lastpoint"], -dash => "..");

	my $change_coords = sub {
	    my($x, $y) = @_;
	    my $cos = cos($angle);
	    my $sin = sin($angle);
	    my $cos90 = cos($angle+pi/2);
	    my $sin90 = sin($angle+pi/2);
	    $c->coords($ch1, $x + $cos  *$sw, $y - $sin  *$sw, $x - $cos  *$sw, $y + $sin  *$sw);
	    $c->coords($ch2, $x + $cos90*$sw, $y - $sin90*$sw, $x - $cos90*$sw, $y + $sin90*$sw);
	    $c->coords($chp,
		       $x + $cos*$pd - $sin*$pd,
		       $y - $sin*$pd - $cos*$pd,
		       $x - $cos*$pd - $sin*$pd,
		       $y + $sin*$pd - $cos*$pd,
		       $x - $cos*$pd + $sin*$pd,
		       $y + $sin*$pd + $cos*$pd,
		       $x + $cos*$pd + $sin*$pd,
		       $y - $sin*$pd + $cos*$pd,
		       $x + $cos*$pd - $sin*$pd,
		       $y - $sin*$pd - $cos*$pd,
		      );
	};
	my $change_coords_with_pointerxy = sub {
	    my($x, $y) = $c->pointerxy;
	    $x -= $c->rootx;
	    $y -= $c->rooty;
	    $x = $c->canvasx($x);
	    $y = $c->canvasy($y);
	    $change_coords->($x, $y);
	};

	$c->CanvasBind("<Motion>", sub {
			   my $e = $c->XEvent;
			   my($x, $y) = ($c->canvasx($e->x),$c->canvasy($e->y));
			   $change_coords->($x, $y);
			   if (@main::realcoords) {
			       my($lx,$ly) = main::transpose(@{$main::realcoords[-1]});
			       $c->coords($chlp,$lx,$ly,$x,$y);
			   } else {
			       $c->coords($chlp,0,0);
			   }
		       });
	$top->bind("<Shift-F4>" => sub {
		       $angle = 0;
		       $change_coords_with_pointerxy->();
		   });
	$top->bind("<F4>" => sub {
		       $angle += deg2rad($angle_steps);
		       $change_coords_with_pointerxy->();
		   });
	$top->bind("<F5>" => sub {
		       $angle -= deg2rad($angle_steps);
		       $change_coords_with_pointerxy->();
		   });

	$top->bind("<Shift-F6>" => sub {
		       $pd = 0;
		       $change_coords_with_pointerxy->();
		   });
	$top->bind("<F6>" => sub {
		       $pd += $pd_steps;
		       $change_coords_with_pointerxy->();
		   });
	$top->bind("<F7>" => sub {
		       $pd -= $pd_steps;
		       if ($pd < 0) {
			   $pd = 0;
		       }
		       $change_coords_with_pointerxy->();
		   });

	main::restack();
    }
}

sub deactivate {
    my $c = $main::c;
    while(my $binding = pop @old_bindings) {
	$binding->();
    }
    $c->delete("crosshairs");
}

1;

__END__
