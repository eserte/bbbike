# -*- perl -*-

#
# $Id: EmptyCanvasMap.pm,v 1.15 2004/10/13 07:09:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package EmptyCanvasMap;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Frame);

Construct Tk::Widget 'EmptyCanvasMap';

sub Populate {
    my($w, $args) = @_;

    # XXX optimized for handhelds
    (my $path = $w->PathName) =~ s/^.//;
    $w->optionAdd("*$path*Button*Pad", 0);
    $w->optionAdd("*$path*Scrollbar*width", 9);

    my $f = $w->Frame;
    $f->Button(-text => "+",
	       -command => [$w, 'zoom_in'])->pack(-side => "left");
    $f->Button(-text => "-",
	       -command => [$w, 'zoom_out'])->pack(-side => "left");
    $f->Button(-text => "x",
	       -command => [$w, 'clear'])->pack(-side => "left");

    my $c = $w->Scrolled("Canvas", -scrollbars => "osoe");
    my $real_c = $c->Subwidget("scrolled");
    $w->Advertise(Canvas => $real_c);

    $f->pack(-side => "bottom", -fill => "x");
    $c->pack(-fill => "both", -expand => 1);

    # to help cursor navigation on handhelds:
    $real_c->focus;

    $w->Delegates(DEFAULT => $real_c);

    $w->ConfigSpecs
	(
	 -scale => ['PASSIVE', undef, undef, 10],
	 -drawscale => ['PASSIVE', undef, undef, 1],
	 DEFAULT => [$real_c],
	);
}

sub adjust_scrollregion {
    my $w = shift;
    my $c = $w->Subwidget("Canvas");
    if ($c->find("all") >= 2) {
	$c->configure(-scrollregion => [$c->bbox("all")]);
	$w->draw_scale;
    }
}

sub get_transpose {
    my $w = shift;
    my $code = sub {
	my($x,$y) = @_;
	my $scale = $w->{Configure}{-scale};
	($x/$scale, -$y/$scale);
    };
    $code;    
}

sub zoom_in {
    shift->zoom(2);
}

sub zoom_out {
    shift->zoom(0.5);
}

sub zoom {
    my($w, $amount) = @_;
    my $c = $w->Subwidget("Canvas");
    $w->configure(-scale => $w->cget(-scale)/$amount);
    $w->scale("all", 0, 0, $amount, $amount);
    $w->adjust_scrollregion;
}

sub clear {
    my $w = shift;
    my $c = $w->Subwidget("Canvas");
    $c->delete("all");
    $w->draw_scale;
}

sub draw_scale {
    my $w = shift;
    return if !$w->cget(-drawscale);
    my $c = $w->Subwidget("Canvas");
    $c->delete("scale");
    my $transpose = $w->get_transpose;
    return if !$transpose;
    my($x0,$y0) = $transpose->(0,0);
    my($x1,$y1) = $transpose->(1000,0);
    my $x_pad = 5;
    my $y_pad = 3;
    my $x_delta = abs($x1-$x0);

    $c->createLine($c->canvasx($c->Width - $x_pad - $x_delta),
		   $c->canvasy($c->Height - $y_pad),
		   $c->canvasx($c->Width - $x_pad),
		   $c->canvasy($c->Height - $y_pad),
		   -fill => "blue",
		   -width => 3,
		   -tags => "scale",
		  );
}

1;

__END__
