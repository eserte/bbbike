# -*- perl -*-

#
# $Id: CanvasBalloon.pm,v 1.9 2001/12/11 17:28:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998, 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::CanvasBalloon;
use Tk qw(Exists);
use Tk::Toplevel;
use strict;
use vars qw($VERSION @ISA $latency $MEMORY_LEAK_WORKAROUND);

use constant XDELTA => 7;
use constant YDELTA => 7;

$VERSION = '0.07';

Construct Tk::Widget 'CanvasBalloon';
@ISA = qw(Tk::Toplevel);

$latency = 20; # ms
$MEMORY_LEAK_WORKAROUND = 0;

sub Populate {
    my ($w, $args) = @_;

    $w->SUPER::Populate($args);

    $w->overrideredirect(1);
    $w->withdraw;
    # Only the container frame's background should be black... makes it
    # look better.
    $w->configure(-background => "black");
    my $a = $w->Frame;
    my $m = $w->Frame;
    $a->configure(-bd => 0);
    my $have_arrow = (exists $args->{'-arrow'}
		      ? delete $args->{'-arrow'}
		      : 1);
    if ($have_arrow) {
	my $al = $a->Label(-bd => 0,
			   -relief => "flat",
			   -bitmap => '@' . Tk->findINC("balArrow.xbm"));
	$al->pack(-side => "left", -padx => 1, -pady => 1, -anchor => "nw");
    }
    $m->configure(-bd => 0);
    my $ml = $m->Label(-bd => 0,
		       -padx => 0,
		       -pady => 0,
		       -text => $args->{-message});
    $w->Advertise("message" => $ml);
    $ml->pack(-side => "left",
	      -anchor => "w",
	      -expand => 1,
	      -fill => "both",
	      -padx => 10,
	      -pady => 3);
    $a->pack(-fill => "both", -side => "left");
    $m->pack(-fill => "both", -side => "left");

    $w->{'screenwidth'} = $w->screenwidth;
    $w->{'screenheight'} = $w->screenheight;

    $w->bind('<Any-Enter>' => sub {
		 $w->Pos(1);
	     });
    $w->bind('<Any-Leave>' => sub {
		 $w->Deactivate(undef, -from => 'event');
	     });

#    # append to global list of balloons
#    push(@balloons, $w);
    $w->{'popped'} = 0;
#    $w->{"buttonDown"} = 0;
#    $w->{"menu_index"} = 'none';
    $w->ConfigSpecs
      (#-installcolormap => ["PASSIVE", "installColormap", "InstallColormap", 0],
       -initwait    => ["PASSIVE", "initWait", "InitWait", 350],
       #-state => ["PASSIVE", "state", "State", "both"],
       -statusbar   => ["PASSIVE", "statusBar", "StatusBar", undef],
       -postcommand => ["CALLBACK", "postCommand", "PostCommand", undef],
       #-followmouse => ["PASSIVE", "followMouse", "FollowMouse", 0],
       -show        => ["PASSIVE", "show", "Show", 1],
       -background  => ["DESCENDANTS", "background", "Background", "#C0C080"],
       -font        => [$ml, "font", "Font",
			"-*-helvetica-medium-r-normal--*-120-*-*-*-*-*-*"],
       -borderwidth => ["SELF", "borderWidth", "BorderWidth", 1]
      );
}

sub Popup {
    my($w, $msg, $statusmsg) = @_;
    $w->Subwidget('message')->configure(-text => $msg);
    my $sb = $w->cget('-statusbar');
    if (defined $statusmsg and defined $sb and Exists($sb)) {
	$sb->configure(-text => $statusmsg);
    }
    $w->Pos;
    if (defined $w->{'delay'}) {
	$w->{'delay'}->cancel;
	undef $w->{'delay'};
    }
    if (!$w->{'popped'}) {
	$w->{'delay'} = $w->after($w->cget(-initwait),
				  sub {
				      return if !$w->cget(-show);
				      $w->deiconify;
				      $w->raise;
				      $w->{'popped'} = 1;
				  });
    }
}

sub Deactivate {
    my($w, $immediate, %args) = @_;

    if (defined $args{-from} and $args{-from} eq 'event') {
	my $cont = $w->containing($w->pointerxy);
	if (Tk::Exists($cont) and $cont->toplevel eq $w) {
	    # moving cursor over Balloon itself: don't deactivate
	    return;
	}
    }

    if ($args{-delay}) {
	$w->{delay} = $w->after($args{-delay},
				sub { undef $w->{delay};
				      $w->Deactivate;
				  });
	return;
    }

    if (defined $w->{'delay'}) {
	$w->{'delay'}->cancel;
    }
    if ($w->{'popped'}) {
	if ($immediate) {
	    $w->withdraw;
	    $w->{'popped'} = 0;
	} else {
	    $w->{'delay'}
	    = $w->after($latency, sub { $w->withdraw;
					$w->{'popped'} = 0;
				    });
	}
    }
    my $sb = $w->cget('-statusbar');
    if (defined $sb and Exists($sb)) {
	$sb->configure(-text => '');
    }
}

sub Track {
    my $w = shift;
    if ($w->{'popped'}) {
	if (defined $w->{'delay'}) {
	    $w->{'delay'}->cancel;
	}
	$w->{'delay'} = $w->after($latency, sub { $w->Pos;
						  undef $w->{'delay'};
					      });
    }
}

sub Pos {
    my $w = shift;
    my $force = shift;
    my($x, $y) = $w->pointerxy;
    if (!$force && defined $w->{'lastx'} && defined $w->{'lasty'}) {
	return if sqrt(($w->{'lastx'}-$x)*($w->{'lastx'}-$x) +
		       ($w->{'lasty'}-$y)*($w->{'lasty'}-$y)) < 4;
    }
    $w->idletasks;
    my($width, $height) = ($w->reqwidth, $w->reqheight);
    my $xx = ($x + XDELTA + $width > $w->{'screenwidth'}
	      ? $w->{'screenwidth'} - $width
	      : $x + XDELTA);
    my $yy = ($y + YDELTA + $height > $w->{'screenheight'}
	      ? $w->{'screenheight'} - $height
	      : $y + YDELTA);
    $w->geometry("+$xx+$yy");
    ($w->{'lastx'}, $w->{'lasty'}) = ($x, $y);
}

sub attach {
    my($w, $c, $tag_ref, %args) = @_;
    my @tags = (ref $tag_ref eq 'ARRAY' ? @$tag_ref : $tag_ref);
    my $msg = delete $args{-msg};
    my $balloonmsg = delete $args{-balloonmsg};
    my $statusmsg = delete $args{-statusmsg};
    $balloonmsg = $msg if (not defined $balloonmsg);
    $statusmsg = $msg if (not defined $statusmsg);
    foreach my $tag (@tags) {
	my($old_enter, $old_leave, $old_motion);
	if (!$MEMORY_LEAK_WORKAROUND) {
	    # It seems that there are some SV's left after a croak()
	    # in the Call_Tk function. Maybe a problem with eval?
	    eval { $old_enter  = $c->bind($tag, '<Any-Enter>') };
	    eval { $old_leave  = $c->bind($tag, '<Any-Leave>') };
	    eval { $old_motion = $c->bind($tag, '<Any-Motion>')};
	    $w->{'oldenter'}{$tag}  = $old_enter  if (defined $old_enter);
	    $w->{'oldleave'}{$tag}  = $old_leave  if (defined $old_leave);
	    $w->{'oldmotion'}{$tag} = $old_motion if (defined $old_motion);
	}
	$c->bind($tag, '<Any-Enter>'  => sub {
		     $w->Popup($balloonmsg, $statusmsg);
		     if ($old_enter) { $old_enter->Call(@_) }
		 });
	$c->bind($tag, '<Any-Leave>'  => sub {
		     $w->Deactivate(undef, -from => 'event', -delay => $latency);
		     if ($old_leave) { $old_leave->Call(@_) }
		 });
	$c->bind($tag, '<Any-Motion>' => sub {
		     $w->Track;
		     if ($old_motion) { $old_motion->Call(@_) }
		 });
    }
}

sub detach {
    my($w, $c, $tag_ref) = @_;
    my @tags = (ref $tag_ref eq 'ARRAY' ? @$tag_ref : $tag_ref);
    foreach my $tag (@tags) {
	$c->bind($tag, '<Any-Enter>'  =>
		 ($w->{'oldenter'}{$tag} ? $w->{'oldenter'}{$tag} : undef));
	$c->bind($tag, '<Any-Leave>'  =>
		 ($w->{'oldleave'}{$tag} ? $w->{'oldleave'}{$tag} : undef));
	$c->bind($tag, '<Any-Motion>' =>
		 ($w->{'oldmotion'}{$tag} ? $w->{'oldmotion'}{$tag} : undef));
	$w->_delete_internal($tag);
    }
}

sub _delete_internal {
    my($w, $tag) = @_;
    delete $w->{'oldenter'}{$tag};
    delete $w->{'oldleave'}{$tag};
    delete $w->{'oldmotion'}{$tag};
}

sub delete_and_detach {
    my($w, $c, $tag_ref) = @_;
    my @tags = (ref $tag_ref eq 'ARRAY' ? @$tag_ref : $tag_ref);
    $w->detach($c, $tag_ref);
    foreach (@tags) {
 	$c->delete($_);
    }
    $w->Deactivate; # XXX check whether deleted tag is active
}

1;
__END__

=head1 NAME

Tk::CanvasBalloon - pop up help balloons over canvas items

=head1 SYNOPSIS

  use Tk::CanvasBalloon;

  $b = $canvas->Balloon;
  $item = $canvas->createLine(0,0,100,100);
  $b->attach($canvas, $item, -msg => 'Message');

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item B<attach(>I<canvas>, I<tag_or_item>B<)>

=item B<detach(>I<canvas>, I<tag_or_item>B<)>

=item B<delete_and_detach(>I<canvas>, I<tag_or_item>B<)>

=item B<Popup(>I<msg>, I<statusmsg>B<)>

=item B<Deactivate(>[I<immediate>]B<)>

=item B<Track()>

=head1 NOTES

Tk::CanvasBalloon seems to work better with Tk800.xxx than with
Tk40x.xxx, because the tracking of Enter, Motion and Leave events is
better.

Tk800.0xx and/or perl seem to have some memory leaks. This would
appear if a lot of canvas items with balloons attached are created. To
prevent this problem, set the variable
C<$Tk::CanvasBalloon::MEMORY_LEAK_WORKAROUND> to a true value. As a
side-effect, Enter, Leave and Motion events of attached canvas item
are not remembered.

=head1 BUGS

B<attach> overwrites item bindings for Any-Enter, Any-Leave and Any-Motion.

There is now way to track deleted items from a canvas, so deleting of
attached items should be done with B<delete_and_detach>.

Tk::CanvasBalloon IS-not-A Tk::Balloon.

=back

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

=head1 COPYRIGHT

Copyright (c) 1998 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

Some code is stolen from Tk::Balloon by Rajappa Iyer
<rsi@earthling.net>.

=head1 SEE ALSO

Tk::Balloon(3), Tk::Canvas(3).

=cut
