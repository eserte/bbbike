# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1999, 2000, 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/
#

package Tk::LayerEditorCore;

use strict;
use vars qw($layereye $VERSION);

use Tk::DragDrop;
use Tk::DropSite;

{
    package Tk::DragDrop;
no strict 'refs';
BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::unimport = sub { };
    }
}
no warnings 'redefine';
sub Tk::DragDrop::StartDrag
{
 my $token = shift;
 my $w     = $token->parent;
#warn "$token $w <<<";
 unless ($w->{'Dragging'})
  {
   my $e = $w->XEvent;
   my $X = $e->X;
   my $Y = $e->Y;
#   my $was = $token->{'XY'};
#     if ($was)
#      {
#       my $dx = $was->[0] - $X;
#       my $dy = $was->[1] - $Y;
#       if (sqrt($dx*$dx+$dy*$dy) > $token->cget('-delta'))
#        {
#         unless ($token->Callback('-startcommand',$token,$e))
#          {
#           delete $token->{'XY'};
#           $w->{'Dragging'} = $token;
#           $token->MoveToplevelWindow($X+OFFSET,$Y+OFFSET);
#           $token->raise;
#           $token->deiconify;
#           $token->FindSite($X,$Y,$e);
#          }
#        }
#      }
#     else
#      {
#     $token->{'XY'} = [$X,$Y];
	unless ($token->Callback('-startcommand',$token,$e)) {
     $w->{'Dragging'} = $token;
     $token->MoveToplevelWindow($X+OFFSET,$Y+OFFSET);
     $token->raise;
     $token->deiconify;
     $token->FindSite($X,$Y,$e);
 }
#    }
  }
}
}

$VERSION = '0.14';

sub CommonPopulate {
    my($w, $args) = @_;

    my $c = $w->Scrolled('Canvas', -scrollbars => 'osoe',
			 -relief => 'sunken',
			 -bd => 2,
			 -width => "4c",
			 -height => "6c",
			 -takefocus => 0,
			 -xscrollincrement => 5,
			 -yscrollincrement => 5,
			)->pack(-expand => 1, -fill => 'both');
    $c->afterIdle(sub { $c->configure(-background => 'white') });
    $w->Advertise('canvas' => $c);

    $layereye = $w->Photo(-file => Tk::findINC("Tk", "layereye.gif"))
	unless defined $layereye;

    my $dnd_source;
    $dnd_source = $c->DragDrop
      (-event => '<ButtonPress-1>',
       -sitetypes => ['Local'],
       -startcommand => sub { StartDrag($dnd_source, $w) },
      );
    $dnd_source->bindtags([$dnd_source, ref $dnd_source, ".", "all"]);
    $dnd_source->bind('<Any-KeyPress>' => [sub { Done($w) }]);
    $dnd_source->bind('<Any-Motion>',sub { myDrag($dnd_source) });

    $c->DropSite(-droptypes => ['Local'],
		 -dropcommand => [sub { Drop($w, @_) }],
		 -motioncommand => [ sub { Motion($w, @_) }]);

    $c->bind('layeronoff', '<ButtonPress-1>' => sub { toggle_visibility($w) });
    foreach (qw(layeronfoff layeritem)) {
	$c->bind($_, '<Any-Enter>' => [$w, '_hand_cursor_on']);
	$c->bind($_, '<Any-Leave>' => [$w, '_hand_cursor_off']);
    }

#XXX    $c->Tk::bind('<B1-Motion>' => sub { $w->check_autoscroll });

}

sub CommonConfigSpecs {
    (-visibilitychange  => ['CALLBACK',undef,undef,undef],
     -orderchange       => ['CALLBACK',undef,undef,undef],
    );
}

sub _hand_cursor_on {
    my $w = shift;
    my $c = $w->Subwidget("canvas");
    $w->{OrigCursor} = $c->cget(-cursor);
    $c->configure(-cursor => "hand2");
}

sub _hand_cursor_off {
    my $w = shift;
    my $c = $w->Subwidget("canvas");
    $c->configure(-cursor => $w->{OrigCursor});
}

sub reorder {
    my($w, $elem, $newpos) = @_;
    my $swap_elem = $w->{Items}[$elem];
    splice @{$w->{Items}}, $elem, 1;
    if ($elem < $newpos) {
	$newpos--;
    }
    splice @{$w->{Items}}, $newpos, 0, $swap_elem;
    $w->add(@{$w->{Items}});
    $w->Callback(-orderchange => $w, $w->{Items});
}

sub add {
    my($w, @elem) = @_;
    my $x = $layereye->width + 4;
    my $layereye_height = $layereye->height;
    my $y = 2;
    my $max_width = 0;
    my $c = $w->Subwidget('canvas');
    $c = $c->Subwidget('canvas');
    $c->delete('all');
    my @y;
    my @p;
    my $i = 0;
    foreach my $e (@elem) {
	my $p = $e->{'Image'};
	push @y, $y;
	push @p, $p;
	my $onid = $c->createImage
	  (2, $y,
	   -image => $layereye, -anchor => 'nw',
	   -tags => ['layeronoff', "layeronoff-$i", "layeron-$i"]);
	my $offid = $c->createRectangle
	  (2, $y, 2+$layereye->width, $y+$layereye_height,
	   -outline => 'white',
	   -fill => 'white',
	   -tags => ['layeronoff', "layeronoff-$i", "layeroff-$i"]);
	if ($e->{Visible}) {
	    $c->raise($onid, $offid);
	} else {
	    $c->raise($offid, $onid);
	}
	my $p_height = 0;
	my $p_width = 0;
	if ($p) {
	    $c->createImage($x, $y,
			    -image => $p, -anchor => 'nw',
			    -tags => ['layeritem', "layeritem-$i", 'layerimage', "layerimage-$i"]);
	    $p_height = $p->height;
	    $p_width = $p->width;
	}
	$y += _max($p_height, $layereye_height) + 2*2;
	if ($p_width > $max_width) {
	    $max_width = $p_width;
	}
	$i++;
    }
    push @y, $y;

    # center images
    for my $image_item ($c->find(withtag => 'layerimage')) {
	my $p = $c->itemcget($image_item, '-image');
	if ($p->width < $max_width - 1) {
	    my($x, $y) = $c->coords($image_item);
	    $c->coords($image_item, $x + ($max_width-$p->width)/2, $y);
	}
    }

    $max_width += $x + 6; # extra border

    $i = 0;
    my $txt_width = 0;
    foreach my $e (@elem) {
	my $l = $e->{'Text'};
	my $id = $c->createText($max_width, $y[$i],
				-text => $l, -anchor => 'nw',
				-tags => ['layeritem', "layeritem-$i"]);
	my $this_width;
	eval {
	    $this_width = $c->fontMeasure($c->itemcget($id, -font), $l);
	};
	if ($@ || !defined $this_width) { # for 402.xxx compatibility
	    $this_width = 12;
	}
	if ($this_width > $txt_width) {
	    $txt_width = $this_width;
	}
	$i++;
    }
    $max_width = $max_width + $txt_width + 2;
    $c->configure(-scrollregion => [0,0,$max_width,$y]);
#XXX what's that?    $c->bind('layeritem', '<ButtonPress-1>' => [\&MoveLayer, $c]);
    $w->{'ItemsY'} = \@y;
    $w->{'ItemsImage'} = \@p;
    $w->{'Items'} = \@elem;
}

sub StartDrag {
    my $token = shift;
    my $top = shift;
#warn "start drag $token $top";
    my $w = $token->parent;
    delete $token->{'XY'};
    my $e = $w->XEvent;
    my $X = $w->canvasx($e->X);
    my $Y = $w->canvasy($e->Y);
    my(@t) = $w->gettags('current');
    return 1 if (!@t || $t[0] ne 'layeritem' || $t[1] !~ /^layeritem-(\d+)/);
    my $inx = $1;
    $top->{'DragItem'} = $inx;
    if ($top->{'ItemsImage'}[$inx]) {
	$token->configure(-image => $top->{'ItemsImage'}[$inx]);
    } else {
	$token->configure(-image => undef,
			  -text => $top->{Items}[$inx]->{Text});
    }
    $w->{'Dragging'} = $token;
    $token->MoveToplevelWindow($X,$Y);
    $token->raise;
    $token->deiconify;
    $token->FindSite($X,$Y,$e);
    $token->idletasks; # seems to be necessary to position to $X/$Y
}

sub Motion {
    my $top = shift;
    my($wx, $wy) = @_;
    my $c = $top->Subwidget('canvas');
    my($cx, $cy) = ($c->canvasx($wx), $c->canvasy($wy));
    my $inx = get_item($top, $c, $cy);
    return unless defined $inx;
    my $y_ref = $top->{ItemsY};
    my $line_pos;
    if (!defined $y_ref->[$inx+1] ||
	($y_ref->[$inx+1]-$y_ref->[$inx])/2+$y_ref->[$inx] > $cy) {
	$line_pos = $y_ref->[$inx];
	$top->{After} = $inx;
    } else {
	$line_pos = $y_ref->[$inx+1];
	$top->{After} = $inx+1;
    }
    $c->delete('bar');
    $c->createLine(0, $line_pos-2, 100, $line_pos-2, -tags => 'bar');

    return if $c->{ScrollLock};

    my $set_scroll_lock = sub {
	$c->{ScrollLock} = $c->after
	    (100, sub { undef $c->{ScrollLock} });
    };

    my $real_c = $c->Subwidget("canvas");
    my $real_canvas_width  = $real_c->width;
    my $real_canvas_height = $real_c->height;
    my $pad = 10;
    if ($cx < $pad && $c->canvasx(0) >= 5) {
	$c->xview(scroll => -1, 'units');
	$set_scroll_lock->();
    }
    if ($cy < $pad && $c->canvasy(0) >= 5) {
	$c->yview(scroll => -1, 'units');
	$set_scroll_lock->();
    }
    if ($cx > $real_canvas_width-$pad) {
	$c->xview(scroll => +1, 'units');
	$set_scroll_lock->();
    }
    if ($cy > $real_canvas_height-$pad) {
	$c->yview(scroll => +1, 'units');
	$set_scroll_lock->();
    }
}

sub Drop {
    my $top = shift;
    #XXX warn "@_";
    my($x, $y) = $Tk::VERSION >= 804 ? ($_[3], $_[4]) : ($_[1], $_[2]);
    my $c = $top->Subwidget('canvas');
    my $inx = get_item($top, $c, $c->canvasy($y));
    $inx = $top->{After};
    $c->delete('bar');
    $top->reorder($top->{'DragItem'},$inx);
}

# cleanup after cancelling a drag/drop command
sub Done {
    my $top = shift;
    my $c = $top->Subwidget('canvas');
    $c->delete('bar');
}

sub get_item {
    my($top, $c, $y) = @_;
    for(my $i=0; $i < @{$top->{ItemsY}}; $i++) {
	if ($top->{ItemsY}[$i] > $y) {
	    return ($i>1 ? $i-1 : 0);
	}
    }
    return $#{$top->{ItemsY}};
}

sub toggle_visibility {
    my $w = shift;
    my $c = $w->Subwidget('canvas')->Subwidget('canvas');
    my $e = $c->XEvent;
    my($idx) = get_item($w, $c, $c->canvasy($e->y));
    return if !defined $idx;
    if ($w->{Items}[$idx]{'Visible'}) {
	$c->raise("layeroff-$idx", "layeron-$idx")
    } else {
	$c->raise("layeron-$idx", "layeroff-$idx")
    }
    $w->{Items}[$idx]{'Visible'} = !$w->{Items}[$idx]{'Visible'};
    $w->Callback(-visibilitychange,
		 $w,
		 $w->{Items}[$idx]{'Data'},
		 $w->{Items}[$idx]{'Visible'});
}

sub myDrag
{
 my $token = shift;
 my $e = $token->XEvent;
 my $rx = $e->X;
 my $ry = $e->Y;
 $token = $token->toplevel;
 $token->MoveToplevelWindow($rx+Tk::DragDrop::OFFSET,$ry+Tk::DragDrop::OFFSET);
#XXX nyi
 my $c = $token->parent;
 if ($ry < $c->rooty || $ry > $c->rooty+$c->height) {
     my $p = $c;
     while(ref($p) !~ /^Tk::LayerEditor/) {
	 die "Can't find LayerEditor parent" if $p->isa("Tk::Toplevel");
	 die "\$p is undef" if !$p;
	 $p = $p->parent;
     }
     canvas_AutoScan($c,$p,$rx-$c->rootx,$ry-$c->rooty);
 }
}

### nyi
sub canvas_AutoScan
{
 my $c  = shift;
 my $p  = shift;
 my $wx = shift;
 my $wy = shift;
 my($x0,$x1) = $c->xview;
 my($y0,$y1) = $c->yview;
 if ($wy >= $c->rooty + $c->height)
  {
   $c->yview('scroll',1,'units')
  }
 elsif ($wy < $c->rooty && $y0 > 0)
  {
   $c->yview('scroll',-1,'units')
  }
 elsif ($wx >= $c->rootx + $c->width)
  {
   $c->xview('scroll',2,'units')
  }
 elsif ($wx < $c->rootx && $x0 > 0)
  {
   $c->xview('scroll',-2,'units')
  }
 else
  {
   return;
  }
# $p->Motion($c->canvasx($x), $c->canvasy($y));
 $p->Motion($wx, $wy);
 $c->RepeatId($c->after(50,sub{canvas_AutoScan($c,$p,$wx,$wy)}));
}

# XXX implement!
#  sub check_autoscroll {
#      my $w = shift;

#      $w->{Autoscroll} = $w->repeat(20, sub {
#  				      my $e = $w->XEvent;
#  				      warn $e->x, " " ,$e->y; 
#  				  });

#      if ($w->{Autoscroll}) {
#  	$w->{Autoscroll}->cancel;
#  	undef $w->{Autoscroll};
#      }

#  }

sub expand_to_visible {
    my $self = shift;
    my $c = $self->Subwidget("canvas");
    my @bbox = $c->bbox('all');
    my $w = $c->cget('-borderwidth') + $bbox[2]-$bbox[0];
    my $h = $c->cget('-borderwidth') + $bbox[3]-$bbox[1];
    if ($w > $c->Width) {
	$c->configure(-width => $w);
    }
    if ($h > $c->Height) {
	$c->configure(-height => $h);
    }
}

sub _max { ($_[0] > $_[1] ? $_[0] : $_[1]) }

1;

__END__

=head1 NAME

Tk::LayerEditorCore - internal module for LayerEditor and LayerEditorToplevel

=head1 SYNOPSIS

  use Tk;
  use Tk::LayerEditor;
  use Tk::LayerEditorToplevel;

=head1 DESCRIPTION

This is only an internal module used by Tk::LayerEditor and
Tk::LayerEditorToplevel.

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

=head1 COPYRIGHT

Copyright (c) 1999, 2000 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Tk::Canvas(3), Tk::LayerEditor(3), Tk::LayerEditorToplevel(3).

=cut

