# -*- perl -*-

#
# $Id: Placement.pm,v 1.7 2003/01/04 15:55:57 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Placement;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub get_toplevel_regions {
    my $w = shift;
    my @win;
    $w->Walk(sub {
		 my $w = shift;
		 if ($w->isa("Tk::Toplevel") && $w->viewable &&
		     $w->state eq 'normal') {
		     push @win, {x => $w->rootx, y => $w->rooty,
				 width => $w->width, height => $w->height};
		 }
	     });
    @win;
}

sub placer {
    my($w, %args) = @_;
    my $mw = $w->MainWindow;
    my $tlparent   = $args{-toplevelparent} || $mw;
    my $scr        = $args{-screen}         || $mw;
    my $width      = $args{-width}          || $w->reqwidth;
    my $height     = $args{-height}         || $w->reqheight;
    my $pdeltax    = $args{-pdeltax}        || 20;
    my $pdeltay    = $args{-pdeltay}        || 20;
    my $usepercent = $args{-usepercent}     || 1;
    my $addx       = $args{-addx}           || 0; # for wms
    my $addy       = $args{-addy}           || 0; # for wms
    my $returnonly = $args{-returnonly}     || 0;
    my $placer     = $args{-placer}         || "clever";
    my @win = get_toplevel_regions($tlparent);
    my($x, $y) = any_placement
	(
	 $placer,
	 {width => $width, height => $height},
	 {x => $scr->rootx, y => $scr->rooty, width => $scr->width, height => $scr->height},
	 \@win, $pdeltax, $pdeltay, $usepercent,
	);
    $x += $addx;
    $y += $addy;
    if ($returnonly) {
	($x, $y);
    } else {
	$w->geometry(sprintf "+%d+%d", $x, $y);
    }
}

sub any_placement {
    my $placer = shift;
    if ($placer =~ /^clever$/i) {
	Tk::Placement::Clever::placement(@_);
    } else {
	die "Placer $placer not available";
    }
}

package Tk::Placement::Clever;

# REPO BEGIN
# REPO NAME min /home/e/eserte/src/repository 
# REPO MD5 80379d2502de0283d7f02ef8b3ab91c2

=head2 min(...)

=for category Math

Return minimum value.

=cut

if (eval { require List::Util; 1 }) {
    *min = \&List::Util::min;
} else {
    *min = sub {
	my $min = $_[0];
	foreach (@_[1..$#_]) {
	    $min = $_ if $_ < $min;
	}
	$min;
    };
}
# REPO END

# REPO BEGIN
# REPO NAME max /home/e/eserte/src/repository 
# REPO MD5 6b687abc440b6ae4b54d3e55858b10a3

=head2 max(...)

=for category Math

Return maximum value.

=cut

if (eval { require List::Util; 1 }) {
    *max = \&List::Util::max;
} else {
    *max = sub {
	my $max = $_[0];
	foreach (@_[1..$#_]) {
	    $max = $_ if $_ > $max;
	}
	$max;
    };
}
# REPO END

my $PLACEMENT_AVOID_COVER_99 = 12;
my $PLACEMENT_AVOID_COVER_95 =  6;
my $PLACEMENT_AVOID_COVER_85 =  4;
my $PLACEMENT_AVOID_COVER_75 =  1;

# Adapted from placement.c, fvwm2
#
# Original comment:
# CleverPlacement by Anthony Martin <amartin@engr.csulb.edu>
# This function will place a new window such that there is a minimum amount
# of interference with other windows.  If it can place a window without any
# interference, fine.  Otherwise, it places it so that the area of of
# interference between the new window and the other windows is minimized
#

sub placement {
    my($window_area, $screen_area, $windows, $pdeltax, $pdeltay, $use_percent) = @_;

    my $PageLeft = $screen_area->{x} - $pdeltax;
    my $test_x = $PageLeft;
    my $test_y = $screen_area->{y} - $pdeltay; # $PageTop;
    # area of interference
    my $aoi = test_fit($window_area, $screen_area, $windows,
		       $test_x, $test_y, -1,
		       $pdeltax, $pdeltay, $use_percent);
    my $aoimin = $aoi;
    my $xbest = $test_x;
    my $ybest = $test_y;

    while ($aoi != 0 && $aoi != -1) {
	if ($aoi > 0) {
	    # Windows interfere.  Try next x.
	    $test_x = get_next_x($window_area, $screen_area, $windows,
				 $test_x, $test_y,
				 $pdeltax, $pdeltay, $use_percent);
	} else {
	    # Out of room in x direction. Try next y. Reset x.
	    $test_x = $PageLeft;
	    $test_y = get_next_y($window_area, $screen_area, $windows,
				 $test_y, $pdeltay, $use_percent);
	}
	$aoi = test_fit($window_area, $screen_area, $windows,
			$test_x, $test_y,
			$aoimin, $pdeltax, $pdeltay, $use_percent);
	# I've added +0.00001 because whith my machine the < test fail with
	# certain *equal* float numbers!
	if ($aoi >= 0 && $aoi + 0.00001 < $aoimin) {
	    $xbest = $test_x;
	    $ybest = $test_y;
	    $aoimin = $aoi;
	}
    }

    (int($xbest), int($ybest));
}

sub get_next_x {
    my($window_area, $screen_area, $windows,
       $x, $y, $pdeltax, $pdeltay, $use_percent) = @_;

    my $PageLeft = $screen_area->{x} - $pdeltax;
    my $PageRight = $PageLeft + $screen_area->{width};
    my $minx_inc = $screen_area->{width} / 20;

    # Test window at far right of screen
    my $xnew = $PageRight;
    my $xtest = $PageRight - $window_area->{width};
    if ($xtest > $x) {
	$xnew = min($xnew, $xtest);
    }
    # Test the values of the right edges of every window
    for my $testw (@$windows) {
	if ($y < $testw->{height} + $testw->{y} &&
	    $testw->{y}  < $window_area->{height} + $y) {
	    $xtest = $PageLeft + $testw->{width} + $testw->{x};
	    if ($xtest > $x) {
		$xnew = min($xnew, $xtest);
	    }
	    $xtest = $PageLeft + $testw->{x} - $window_area->{width};
	    if ($xtest > $x) {
		$xnew = min($xnew, $xtest);
	    }
	}
    }
    if ($use_percent) {
	$xnew = min($xnew, $x + $minx_inc);
    }

    $xnew;
}

sub get_next_y {
    my($window_area, $screen_area, $windows, $y, $pdeltay, $use_percent) = @_;

    my $PageBottom = $screen_area->{y} + $screen_area->{height} - $pdeltay;
    my $miny_inc = ($screen_area->{height} / 20);

    # Test window at far bottom of screen
    my $ynew = $PageBottom;
    my $ytest = $PageBottom - $window_area->{height};
    if ($ytest > $y) {
	$ynew = min($ynew, $ytest);
    }
    # Test the values of the bottom edge of every window
    for my $testw (@$windows) {
	$ytest = $testw->{height} + $testw->{y};
	if ($ytest > $y) {
	    $ynew = min($ynew, $ytest);
	}
	$ytest = $testw->{y} - $window_area->{height};
	if ($ytest > $y) {
	    $ynew = min($ynew, $ytest);
	}
    }

    if ($use_percent) {
	$ynew = min($ynew, $y+$miny_inc);
    }

    $ynew;
}

sub test_fit {
    my($window_area, $screen_area, $windows,
       $x11, $y11, $aoimin, $pdeltax, $pdeltay, $use_percent) = @_;

    my $aoi = 0; # area of interference
    my $cover_factor = 1;
    my $PageRight = $screen_area->{x} + $screen_area->{width} - $pdeltax;
    my $PageBottom = $screen_area->{y} + $screen_area->{height} - $pdeltay;

    my $x12 = $x11 + $window_area->{width};
    my $y12 = $y11 + $window_area->{height};

    if ($y12 > $PageBottom) {
	# No room in y direction
	return -1;
    }
    if ($x12 > $PageRight) {
	# No room in x direction
	return -2;
    }
    for my $testw (@$windows) {

	my $x21 = $testw->{x};
	my $y21 = $testw->{y};
	my $x22 = $x21 + $testw->{width};
	my $y22 = $y21 + $testw->{height};

	if ($x11 < $x22 && $x12 > $x21 &&
	    $y11 < $y22 && $y12 > $y21) {
	    # Windows interfere
	    my $xl = max($x11, $x21);
	    my $xr = min($x12, $x22);
	    my $yt = max($y11, $y21);
	    my $yb = min($y12, $y22);
	    my $anew = ($xr - $xl) * ($yb - $yt);
	    my $avoidance_factor = 1.0; # XXX other factors...

	    if ($use_percent) {
		# normalisation
		if (($x22 - $x21) * ($y22 - $y21) != 0 &&
		    ($x12 - $x11) * ($y12 - $y11) != 0) {
		    $anew = 100 * max($anew / (($x22 - $x21) * ($y22 - $y21)),
				      $anew / (($x12 - $x11) * ($y12 - $y11)));
		    if      ($anew >= 99) {
			$cover_factor = $PLACEMENT_AVOID_COVER_99;
		    } elsif ($anew >= 95) {
			$cover_factor = $PLACEMENT_AVOID_COVER_95;
		    } elsif ($anew >= 85) {
			$cover_factor = $PLACEMENT_AVOID_COVER_85;
		    } elsif ($anew >= 75) {
			$cover_factor = $PLACEMENT_AVOID_COVER_75;
		    }
		    if ($avoidance_factor>1) {
			$avoidance_factor +=
			    ($cover_factor > 1) ? $cover_factor : 0;
		    } else {
			$avoidance_factor = $cover_factor;
		    }
		}
	    }
	    $anew *= $avoidance_factor;
	    $aoi += $anew;
	    if ($aoi > $aoimin && $aoimin != -1) {
		return $aoi;
	    }
	}
    }
    $aoi;
}

1;

__END__
