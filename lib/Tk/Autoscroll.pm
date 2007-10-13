# -*- perl -*-

#
# $Id: Autoscroll.pm,v 1.14 2006/09/10 08:39:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2001,2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Autoscroll;
use strict;
use vars qw($VERSION @default_args);

my $count = 0;
my $prefix = "Autoscroll";

$VERSION = sprintf "%d.%02d", q$Revision: 1.14 $ =~ /(\d+)\.(\d+)/;

sub import {
    if (defined $_[1] and $_[1] eq 'as_default') {
	local $^W = 0;
	eval q{
	    use Tk::Widget;
	    package # hide from CPAN indexer
		Tk::Widget;
	    # XXX better solution!!!!!!
	    sub Scrolled
	      {
		  my ($parent,$kind,%args) = @_;
		  my @args = Tk::Frame->CreateArgs($parent,\%args);
		  my $name = delete $args{'Name'};
		  push(@args,'Name' => $name) if (defined $name);
		  my $cw = $parent->Frame(@args);
		  @args = ();
		  foreach my $k ('-scrollbars',map($_->[0],$cw->configure))
		    {
			push(@args,$k,delete($args{$k})) if (exists $args{$k})
		    }
		  my $w  = $cw->$kind(%args);
		  %args = @args;
		  $cw->ConfigSpecs('-scrollbars' => ['METHOD','scrollbars','Scrollbars','se'],
				   '-background' => [$w,'background','Background'],
				   '-foreground' => [$w,'foreground','Foreground'],
				  );
		  $cw->AddScrollbars($w);
		  $cw->Default("\L$kind" => $w);
		  Tk::Autoscroll::Init($w, @Tk::Autoscroll::default_args);
		  $cw->Delegates('bind' => $w, 'bindtags' => $w);
		  $cw->ConfigDefault(\%args);
		  $cw->configure(%args);
		  return $cw;
	      }
	};
	warn $@ if $@;
    }
}

# XXX Maybe it's possible to make this module into a tk widget for
# deriving???

sub Init {
    my $w = shift;
    my(%args) = @_;
    $w = _get_real_widget($w);

    my $trigger = delete $args{'-trigger'} || '<ButtonPress-2>';
    my $stop_trigger = delete $args{'-stoptrigger'};

    foreach my $cmd (qw(beforestart afterstart beforestop afterstop)) {
	$w->{$prefix . '_' . $cmd} =
	  delete $args{"-" . $cmd . "command"};
    }
    $w->{$prefix . '_Middle'} = delete $args{-middle};
    $w->Tk::bind($trigger   => sub { Start($w, %args) });
    # XXX shouldn't delete the motion binding, if there is already one
    $w->Tk::bind('<Motion>' => sub { });
    if ($stop_trigger) {
	$w->Tk::bind($stop_trigger => sub { Stop($w) });
    }
    my $top = $w->toplevel;
    $top->{$prefix .'_Permanent'}{Trigger} = $trigger;
}

sub Reset {
    my $w = shift;
    $w = _get_real_widget($w);
    # XXX Maybe restore old binding
    my $top = $w->toplevel;
    $w->Tk::bind($top->{$prefix . '_Permanent'}{Trigger} => sub { });
    # XXX there are probably other widgets using autoscroll, so don't delete it
    #delete $top->{$prefix . '_Top'};
}

sub configure {
    # XXX change -trigger and -speed
}

# stop autoscrolling
sub Stop {
    my $w = shift;
    my $top = $w->toplevel;
    if ($top->{$prefix}) {
	return unless _call_command('beforestop', $w, $top);
	$top->{$prefix}{Rep}->cancel;
	$top->{$prefix}{Marker}->destroy;
	# 2 problems:
	# 1) using complicated cursor ['...', '...']
	# 2) switching -cursor while in Autoscroll mode
	# Restore old cursor
	$top->configure(-cursor => $top->{$prefix}{OldCursor});
	# Restore old scrollincrements, if any
	eval {
	    if (exists $top->{$prefix}{XScrollInc}) {
		$w->configure(-xscrollincrement 
			      => $top->{$prefix}{XScrollInc});
	    }
	    if (exists $top->{$prefix}{YScrollInc}) {
		$w->configure(-yscrollincrement 
			      => $top->{$prefix}{YScrollInc});
	    }
	};
	# Restore old toplevel binding for trigger
	$top->Tk::bind($top->{$prefix . '_Permanent'}{Trigger}
		       => $top->{$prefix}{OldBinding});
	delete $top->{$prefix};
	_call_command('afterstop', $w, $top);
    }
}

sub Start { # start autoscrolling
    my $w = shift;
    my(%args) = @_;
    my $top = $w->toplevel;
    if (!$top->{$prefix}) {
	return unless _call_command('beforestart', $w, $top);
	my $e = $w->XEvent;
	my($x, $y) = ($e->x, $e->y);
	if ($w->{$prefix . '_Middle'}) {
	    ($x, $y) = map { int $_ } ($w->width/2, $w->height/2);
	}

	my $c_dim = 10; # with even numbers the oval looks nicer...
	my $as_c = $top->Canvas(-width => $c_dim, -height => $c_dim,
				-highlightthickness => 0,
				-takefocus => 0,
				-cursor => "diamond_cross");
	$as_c->createOval(0,0,$c_dim-1,$c_dim-1,
			  -fill => "red", -outline => undef);
	$as_c->place('-x' => $x+$w->rootx-5-$top->rootx,
		     '-y' => $y+$w->rooty-5-$top->rooty);

        $top->{$prefix}{OldBinding} = 
	  $top->Tk::bind($top->{$prefix . '_Permanent'}{Trigger});
	$top->Tk::bind($top->{$prefix . '_Permanent'}{Trigger}
		       => sub { Stop($w) });

	$top->{$prefix}{Marker}    = $as_c;
	$top->{$prefix}{Coord}     = [$x, $y];
	$top->{$prefix}{OldCursor} = $top->cget(-cursor);
	eval {
	    $top->{$prefix}{XScrollInc} = $w->cget(-xscrollincrement);
	    $w->configure(-xscrollincrement => 1);
	};
	eval {
	    $top->{$prefix}{YScrollInc} = $w->cget(-yscrollincrement);
	    $w->configure(-yscrollincrement => 1);
	};

	my($speed) = (defined $args{'-speed'} ?
		      ($args{'-speed'} eq 'fast' ? 40
		       : $args{'-speed'} eq 'slow' ? 100 : 70) : 70);
	my $rep = $w->repeat
	  ($speed,
	   sub {
	       my $e = $w->XEvent;
	       my($x, $y) = ($e->x, $e->y);
	       my($oldx, $oldy) = ($top->{$prefix}{Coord}[0],
				   $top->{$prefix}{Coord}[1]
				  );
	       my($distx, $disty) = ($x-$oldx, $y-$oldy);
	       # XXX different/better unit scroll computation
	       $w->xview(scroll => $distx/10, "units");
	       $w->yview(scroll => $disty/10, "units");
	       # XXX recursive cursor definition
	       if ($x>$oldx &&
		   ($y-$oldy)<($x-$oldx)*0.4 &&
		   ($y-$oldy)>($x-$oldx)*-0.4) {
		   $top->configure(-cursor => "right_side");
	       } elsif ($x>$oldx &&
			($y-$oldy)<($x-$oldx)*2.4 &&
			($y-$oldy)>($x-$oldx)*0.4) {
		   $top->configure(-cursor => "bottom_right_corner");
	       } elsif ($x>$oldx &&
			($y-$oldy)>($x-$oldx)*-2.4 &&
			($y-$oldy)<($x-$oldx)*-0.4) {
		   $top->configure(-cursor => "top_right_corner");
	       } elsif ($x<$oldx &&
			($oldy-$y)<($oldx-$x)*0.4 &&
			($oldy-$y)>($oldx-$x)*-0.4) {
		   $top->configure(-cursor => "left_side");
	       } elsif ($x<$oldx &&
			($oldy-$y)<($oldx-$x)*2.4 &&
			($oldy-$y)>($oldx-$x)*0.4) {
		   $top->configure(-cursor => "top_left_corner");
	       } elsif ($x<$oldx &&
			($oldy-$y)>($oldx-$x)*-2.4 &&
			($oldy-$y)<($oldx-$x)*-0.4) {
		   $top->configure(-cursor => "bottom_left_corner");
	       } elsif ($y>$oldy) {
		   $top->configure(-cursor => "bottom_side");
	       } else {
		   $top->configure(-cursor => "top_side");
	       }
	       $w->idletasks;
	   });
	$top->{$prefix}{Rep} = $rep;
	_call_command('afterstart', $w, $top);
    }

}

sub _get_real_widget {
    my $w = shift;
    # Hack for scrolled widgets...
    if ($w->isa('Tk::Frame') and $w->Subwidget('scrolled')) {
	$w = $w->Subwidget('scrolled');
    }
    $w;
}

sub _call_command {
    my $type = shift;
    my $w = shift;
    if (defined $w->{$prefix . '_' . $type}) {
	my $r = $w->{$prefix . '_' . $type}->($w, @_);
	return $r;
    }
    1;
}

1;

__END__

=head1 NAME

Tk::Autoscroll - space invaders-like scrolling 

=head1 SYNOPSIS

    use Tk::Autoscroll;
    Tk::Autoscroll::Init($widget);

=head1 DESCRIPTION

This lets you enable scrolling similar to the one in Microsoft
Explorer. Press the middle mouse button and then move the mouse to
scroll the widget. A further press on the middle button stops the
scrolling.

It is also possible to use the autoscrolling feature for all
Scrolled() widgets automatically. To do so, you have to write

    use Tk::Autoscroll 'as_default';

=head1 FUNCTIONS

=head2 Init($widget, [options ...])

Possible options:

=over 4

=item -trigger

Default value is "<Button-2>"

=item -stoptrigger

An event to stop autoscrolling. Normally, this is not defined meaning
that autoscrolling will stop if Button-2 is pressed again. If
C<-stoptrigger> is set to C<E<lt>ButtonRelease-2E<gt>>, then the user
have to hold the middle button down to autoscroll and autoscrolling
will stop if the user releases the button.

=item -speed

Values are "slow", "normal" and "fast". Default value is "normal".

=item -beforestartcommand, -afterstartcommand, -beforestopcommand,
-afterstopcommand

Commands which are executed before/after beginning/ending autoscroll
operation. Note that only subroutine references are allowed, but not
perl/Tk callbacks (i.e. the [ ] notation). The "-before" callbacks
should return true, otherwise the operation is cancelled.

=back

If you want to apply any C<Init> options to all widgets when using
C<as_default>, then you can define the global variable
C<@default_args>. Example:

    @Tk::Autoscroll::default_args = (-stoptrigger => '<ButtonRelease-2>');

=head2 Reset($widget)

Remove the binding, scrolling is not possible anymore.

=head1 BUGS

The import() function could be better implemented, i.e. avoiding the
duplicate of Scrolled() definition.

Any motion binding for the widget is overwritten.

Reset() should probably restore all used bindings.

=head1 SEE ALSO

L<Tk|Tk>, L<Tk::Scrolled|Tk::Scrolled>

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (c) 1999,2001,2002 Slaven Rezic. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
