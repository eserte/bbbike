# -*- perl -*-

#
# $Id: Arrow.pm,v 1.3 1999/03/29 17:54:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::ArrowContainer;
use Tk::Frame;
use Tk::Derived;
@ISA = qw(Tk::Derived Tk::Frame);
Construct Tk::Widget 'ArrowContainer';

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);
}

sub set_active {
    my($w, $a) = @_;
    $w->{'active'} = $a;
}

sub deactivate {
    my $w = shift;
    if (Tk::Exists($w->{'active'})) {
	$w->{'active'}->deactivate;
	delete $w->{'active'};
    }
}

package Tk::Arrow;
# Widget für das Zeichnen von Pfeilen (klickbar).
use Tk::Canvas;
use Tk::Derived;
@ISA = qw(Tk::Derived Tk::Canvas);
Construct Tk::Widget 'Arrow';

sub Populate {
    my($w, $args) = @_;
    $args->{-width} = 30 unless exists $args->{-width};
    $args->{-height} = 30 unless exists $args->{-height};
    $args->{-bg} = 'grey70' unless exists $args->{-bg};
    $w->SUPER::Populate($args);
    $w->{'container'} = $w->parent;
    $w->Tk::bind('<ButtonPress-1>' => sub {
		     return if !$w->cget(-click);
		     $w->deactivate_active;
		     $w->activate;
		     $w->Callback(-command, $w);
		 });
    $w->_deactivate;
    $w->ConfigSpecs
      (
       -command      => ['CALLBACK' => 'command',    'Command',    undef],
       -id           => ['PASSIVE'  => 'id',         'Id',         undef],
       '-deactivate' => ['CALLBACK' => 'deactivate', 'Deactivate', undef],
       '-select'     => ['METHOD' => 'select', 'Select', undef],
       '-click'      => ['PASSIVE' => 'click', 'Click', 1],
      );
}

sub select {
    my $w = shift;
    if (@_) {
	my $val = shift;
	if ($val) {
	    my($width, $height) = ($w->cget(-width), $w->cget(-height));
  	    if ($^O eq 'MSWin32') {
  	        ($width,$height) = (30,30); # XXXX warum???
	    }
	    $w->createRectangle
	      ($width-4, $height-4, $width-1, $height-1,
	       -fill => 'red',
	       -tags => 'select');
	    $w->{'select'} = 1;
	} else {
	    $w->delete('select');
	    $w->{'select'} = 0;
	}
    } 
    $w->{'select'};
}

sub activate {
    my $w = shift;
    $w->configure(-bg => 'white');
    $w->{'container'}->set_active($w);
}

sub _deactivate {
    my $w = shift;
    $w->configure(-bg => 'grey70');
}
sub deactivate {
    my $w = shift;
    $w->_deactivate;
    $w->Callback('-deactivate', $w);
}

sub deactivate_active {
    my $w = shift;
    $w->{'container'}->deactivate;
}

# malt einen Pfeil mit 3 Punkten
sub draw_arrow {
    my($w, $middle, $c1, $c2, $dir) = @_;
    my($centerx, $centery) = ($w->cget(-width)/2, $w->cget(-height)/2);
    my($mx, $my)   = split(/,/, $middle);
    $w->delete('arrow');
    if (defined $c1 and defined $c2) {
	my($c1x, $c1y) = split(/,/, $c1);
	my($c2x, $c2y) = split(/,/, $c2);
	my $len1 = _strecke($c1x, $c1y, $mx, $my);
	my $len2 = _strecke($c2x, $c2y, $mx, $my);
	if ($len1 == 0 || $len2 == 0) {
	    warn "len1=$len1, len2=$len2";
	    return;
	}
	$dir = 'none' unless $dir;
	$w->createLine($centerx+($c1x-$mx)/$len1*($centerx-1),
		       $centery+($c1y-$my)/$len1*($centery-1),
		       $centerx, $centery,
		       -fill => 'black',
		       -width => 3,
		       -tags => 'arrow',
		       ($dir eq 'both' || $dir eq 'first'
			? (-arrow => 'first') : ()),
		      );
	$w->createLine($centerx, $centery,
		       $centerx+($c2x-$mx)/$len2*($centerx-1),
		       $centery+($c2y-$my)/$len2*($centery-1),
		       -fill => 'black',
		       -width => 3,
		       ($dir eq 'both' || $dir eq 'last'
			? (-arrow => 'last') : ()),
		       -tags => 'arrow',
		      );
    } else {
	$w->createLine($centerx, $centery, $centerx, $centery,
		       -fill => 'black',
		       -capstyle => 'round',
		       -width => 3,
		       -tags => 'arrow',
		      );
    }
}

# zeichnet einen Pfeil mit 2 Punkten
sub draw_arrow2 {
    my($w, $c1, $c2, $dir) = @_;
    # Mann, bin ich faul...
    my($c1x, $c1y) = split(/,/, $c1);
    my($c2x, $c2y) = split(/,/, $c2);
    my($mx) = ($c1x-$c2x)/2+$c2x;
    my($my) = ($c1y-$c2y)/2+$c2y;
    $w->draw_arrow("$mx,$my", $c1, $c2, $dir);
}

sub _strecke {
    my($x1,$y1,$x2,$y2) = @_;
    my $dx = $x2-$x1;
    my $dy = $y2-$y1;
    sqrt($dx*$dx+$dy*$dy);
}

1;
