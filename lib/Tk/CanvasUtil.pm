# -*- perl -*-

#
# $Id: CanvasUtil.pm,v 1.17 2007/04/23 21:03:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::CanvasUtil;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.17 $ =~ /(\d+)\.(\d+)/);

use Tk::Canvas;

=head1 NAME

Tk::CanvasUtil - additional method for the standard Canvas widget

=head1 SYNOPSIS

    use Tk::CanvasUtil;

=head1 WIDGET METHODS

The Tk::CanvasUtil pollutes the Tk::Canvas namespace and defines some
methods for the Canvas widget. Note that for some of the new methods
it is necessary to have a defined C<scrollregion>.

=over 4

=cut

package
    Tk::Canvas;

=item is_visible($x,$y)

Return true if ($x,$y) is currently visible in canvas.

=cut

sub is_visible {
    my($c, $x, $y) = @_;
    my($minx, $miny, $maxx, $maxy) = $c->get_corners;
    $x >= $minx && $x <= $maxx && $y >= $miny && $y <= $maxy;
}

=item get_center

Return ($x,$y) of the current center of the canvas.

=cut

sub get_center {
    my $c = shift;
    my(@xview) = $c->xview;
    my(@yview) = $c->yview;
    my(@scrollregion) = ($Tk::VERSION == 800.017
			 ? $c->cget(-scrollregion)
			 : @{$c->cget(-scrollregion)});
    (($xview[0] + ($xview[1]-$xview[0])/2) * ($scrollregion[2]-$scrollregion[0])
     + $scrollregion[0],
     ($yview[0] + ($yview[1]-$yview[0])/2) * ($scrollregion[3]-$scrollregion[1])
     + $scrollregion[1]);
}

=item get_corners

Return the corners of the visible part of the canvas as a list:
(minx, miny, maxx, maxy).  This will not work if the scrollregion is
smaller than the visible region.

=cut

if (!defined &Tk::Canvas::get_corners) { # defined in Tk804
    *get_corners = sub {
	my $c = shift;
	$c->view_to_coords($c->xview, $c->yview);
    }
}

=item view_to_coords($xv1,$xv2,$yv1,$yv2)

Convert the result of xview/yview to coordinates. See comment in
C<get_corners>. The result is the list ($x1,$y1,$x2,$y2). (Please note
that the order is not the same as in the argument list! This is too
make it easier to pass the arguments from xview and yview and to use
the result in a scrollregion configuration.)

=cut

sub view_to_coords {
    my($c,$xv1,$xv2,$yv1,$yv2) = @_;
    my(@scrollregion) = ($Tk::VERSION == 800.017
			 ? $c->cget(-scrollregion)
			 : @{$c->cget(-scrollregion)});
    my $width  = ($scrollregion[2]-$scrollregion[0]);
    my $height = ($scrollregion[3]-$scrollregion[1]);
    ($xv1 * $width + $scrollregion[0],
     $yv1 * $height + $scrollregion[1],
     $xv2 * $width + $scrollregion[0],
     $yv2 * $height + $scrollregion[1],
    );
}

=item center_view($x1,$y1[,%args])

Move canvas so that ($x1,$y1) is in the center of the canvas. If the
C<-seeview> option of the canvas is set, then this method will be used
for moving the canvas instead of the standard C<see_view> method.
C<%args> are optional and will be passed to the C<-seeview> method.

=cut

sub center_view {
    my($c, $x, $y, %args) = @_;
    my(@xview) = $c->xview;
    my(@yview) = $c->yview;
    my($xwidth) = $xview[1]-$xview[0];
    my($ywidth) = $yview[1]-$yview[0];
    my @scrollregion = ($Tk::VERSION == 800.017
			? $c->cget(-scrollregion)
			: @{$c->cget(-scrollregion)});
    my $see_view = ($c->{Configure}{-seeview} ? $c->{Configure}{-seeview} : 'see_view');
    if (!defined $x || !defined $y) {
	$c->$see_view(0.5, 0.5, %args);
    } else {
	$c->$see_view
	    (
	     ($x-$scrollregion[0])/($scrollregion[2]-$scrollregion[0])
	     - $xwidth/2,
	     ($y-$scrollregion[1])/($scrollregion[3]-$scrollregion[1])
	     - $ywidth/2,
	     %args
	    );
    }
}

=item center_view2($x1,$y1,$x2,$y2)

Move canvas so that ($x1,$y1) is in the center of the canvas. Also,
the canvas is moved towards ($x2,$y2). If the C<-seeview> option of
the canvas is set, then this method will be used for moving the canvas
instead of the standard C<see_view> method.

=cut

sub center_view2 {
    my($c, $x1, $y1, $x2, $y2) = @_;
    my(@scrollregion) = ($Tk::VERSION == 800.017
			 ? $c->cget(-scrollregion)
			 : @{$c->cget(-scrollregion)});
    my($x1t, $y1t, $x2t, $y2t) =
      (($x1-$scrollregion[0])/($scrollregion[2]-$scrollregion[0]),
       ($y1-$scrollregion[1])/($scrollregion[3]-$scrollregion[1]),
       ($x2-$scrollregion[0])/($scrollregion[2]-$scrollregion[0]),
       ($y2-$scrollregion[1])/($scrollregion[3]-$scrollregion[1]),
      );
    my $airx = 50/($scrollregion[2]-$scrollregion[0]);
    my $airy = 50/($scrollregion[3]-$scrollregion[1]);
    my(@xview) = $c->xview;
    my(@yview) = $c->yview;
    my($xwidth) = $xview[1]-$xview[0];
    my($ywidth) = $yview[1]-$yview[0];
    my($xdelta, $ydelta) = (0, 0);
    if ($x1t-$x2t > $xwidth/2) { $xdelta -= $xwidth/2 - $airx }
    if ($x2t-$x1t > $xwidth/2) { $xdelta += $xwidth/2 - $airx }
    if ($y1t-$y2t > $ywidth/2) { $ydelta -= $ywidth/2 - $airy }
    if ($y2t-$y1t > $ywidth/2) { $ydelta += $ywidth/2 - $airy }
    my $see_view = ($c->{Configure}{-seeview} ? $c->{Configure}{-seeview} : 'see_view');
    $c->$see_view($x1t - $xwidth/2 + $xdelta, $y1t - $ywidth/2 + $ydelta);
}

=item see($x,$y,[$x2,$y2])

Move canvas so that ($x,$y) is visible. If ($x2,$y2) is specified,
then canvas is moved towards this coordinate.

=cut

sub see {
    my($c, $x, $y, $x2, $y2) = @_;
    if (defined $x2 && defined $y2) {
	$c->center_view2($x, $y, $x2, $y2);
    } else {
	$c->center_view($x, $y);
    }
}

=item see_view($x,$y)

Move canvas view to the specified view numbers (0..1).

=cut

sub see_view {
    my($c, $tox, $toy) = @_;
    $c->xview('moveto' => $tox);
    $c->yview('moveto' => $toy);
}

=item set_cursor(...)

This is the same as

    $canvas->configure(-cursor => ...)

Unfortunately, if the argument to the C<-cursor> option is complex (an
array reference), then you cannot get the value back with C<cget>
(this is a perl/Tk bug). See C<get_cursor>.

=cut

sub set_cursor {
    my($c, $arg) = @_;
    $c->configure(-cursor => $arg);
    $c->{_Cursor_} = $arg;
}

=item get_cursor

Return the cursor value of the canvas. See also C<set_cursor>.

=cut

sub get_cursor {
    my($c) = @_;
    if (exists $c->{_Cursor_}) {
	$c->{_Cursor_};
    } else {
	$c->cget(-cursor);
    }
}

=item load_canvas($file)

Load canvas items which are previously saved by save_canvas.

=cut

sub load_canvas {
    my($c, $file) = @_;
    require Storable;
    my $items = Storable::retrieve($file);
    if ($items) {
	foreach my $item (@$items) {
	    my($type,$coordref,$configref) = @$item;
	    eval {
		$c->create($type, @$coordref, map { ($_->[0] => $_->[1]) } @$configref);
	    }; warn $@ if $@;
	}
    }
}

=item save_canvas($file, ...)

Save canvas items to the file $file. The serialization is done using
Storable. If no further arguments are given, then all canvas items are
saved. If the next argument is a subroutine reference, then this will
be used as a filter. Otherwise, the arguments are used as arguments
for the find() method of the Canvas object.

=cut

sub save_canvas {
    my($c, $file) = (shift, shift);
    require Storable;
    my @tags;
    if (!@_) {
	@tags = $c->find('all');
    } elsif (ref $_[0] eq 'CODE') {
	@tags = grep $_[0]->($_), $c->find('all');
    } else {
	@tags = $c->find(@_);
    }
    local $^W = 0; # because of "ne" below
    Storable::nstore
	    ([map { [$c->type($_), [$c->coords($_)],
		     [map {
			 if ($_->[3] ne $_->[4]) {
			     [$_->[0] => $_->[4]]
			 } else {
			     ()
			 }
		     } $c->itemconfigure($_)]] }
	      @tags], $file);
}

# this is like index("current"), but ignores "unselectable" items
# which matches -ignorerx or restrict to items which matches
# -restrictrx
# -tagsix: check only with the indexed element from the tags array
# not yet tested!
sub current_item {
    my($c, %args) = @_;
    my $ignore_rx = $args{-ignorerx} || '';
    my $restrict_rx = $args{-restrictrx} || '';
    my(@tags_ix) = $args{-tagsix} ? @{ $args{-tagsix} } : ();
    return $c->index("current") if $ignore_rx eq '' && $restrict_rx eq '';
    my $e = $c->XEvent;
    my($x,$y) = ($c->canvasx($e->x),$c->canvasy($e->y));
    my $start;
    my %seen;
    my $stage = 'closest';
    my @find;
    my $find_i;
    my $safe_loop = 0; # XXX
    while (1) {
	die "too many loops, please report, line " . __LINE__
	    if ($safe_loop++ > 100); # XXX
	my $find;
	if ($stage eq 'closest') {
	    ($find) = $c->find('closest', $x, $y, 0, $start);
	    if (defined $find and $find ne '') {
		if (exists $seen{$find}) {
		    $stage = 'overlapping';
		    next;
		}
	    }
	} elsif ($stage eq 'overlapping') {
	    if (!@find) {
		@find = $c->find('overlapping', $x-2, $y-2, $x+2, $y+2);
		$find_i = 0;
	    }
	    return undef if $find_i > $#find;
	    $find = $find[$find_i];
	    $find_i++;
	}
	my @tags = $c->gettags($find);
	if (@tags_ix) {
	    @tags = grep { defined } @tags[@tags_ix];
	}
	if ($restrict_rx ne '') {
	    for (@tags) {
		return $find if (/$restrict_rx/);
	    }
	    goto STAGE_INC;
	} elsif ($ignore_rx ne '') {
	    for (@tags) {
		goto STAGE_INC if (/$ignore_rx/);
	    }
	}
	return $find;
    STAGE_INC:
	if ($stage eq 'closest') {
	    $start = $find;
	    $seen{$find}++;
	}
    }
}

=item scroll_canvasxy_to_rootxy($cx,$cy,$rx,$ry)

Adjust the canvas so that the canvas coordinates $cx,$cy are at the
root coordinates $rx,$ry.

=cut

sub scroll_canvasxy_to_rootxy {
    my($c, $cx, $cy, $rx, $ry) = @_;
    # XXX -highlightthickness? -borderwidth?
    my($wx,$wy) = ($rx - $c->rootx, $ry - $c->rooty);
    my($c1x,$c1y) = ($c->canvasx($wx), $c->canvasy($wy)); # current $rx/$ry pos
    $c->scroll_pixels($cx-$c1x, $cy-$c1y);
    1;
}

sub scroll_pixels {
    my($c, $x, $y) = @_;
    my($oldxsi, $oldysi) = ($c->cget(-xscrollincrement), $c->cget(-yscrollincrement));
    $c->configure(-xscrollincrement => 1,
		  -yscrollincrement => 1);
    $c->xviewScroll($x, "units");
    $c->yviewScroll($y, "units");
    $c->configure(-xscrollincrement => $oldxsi,
		  -yscrollincrement => $oldysi);
}

=item widgetx, widgety

Opposite of canvasx and canvasy.

=cut

sub widgetx {
    my($c, $cx) = @_;
    my $c0 = $c->canvasx(0);
    $cx-$c0;
}

sub widgety {
    my($c, $cy) = @_;
    my $c0 = $c->canvasy(0);
    $cy-$c0;
}

1;

=back

=cut

__END__
