#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: ColorFlowChooser.pm,v 1.5 2002/12/26 02:17:46 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::ColorFlowChooser;
use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);
use Tk qw(Ev);
use base qw(Tk::Derived Tk::Canvas);
Construct Tk::Widget 'ColorFlowChooser';

sub Populate {
    my($w, $args) = @_;

    $w->{Color_def} = delete $args->{-colordef};
    die "Required option -colordef is missing" if !$w->{Color_def};
    $w->{Scale_def} = delete $args->{-scaledef};
    die "Required option -scaledef is missing" if !$w->{Scale_def};

    $w->{Start_x}   = delete $args->{-startx} || 0;
    $w->{Start_y}   = delete $args->{-starty} || 0;
    $w->{Bar_width} = delete $args->{-barwidth} || 20;
    $w->{Orient}    = delete $args->{-orient} || 'horiz'; # XXX NYI
    $w->{Font}      = delete $args->{-font};
    # XXX better name!
    $w->{MoveCarry} = delete $args->{-movecarry} || 0;

    $w->draw($args);
}

sub draw {
    my($w, $args) = @_;

    my @color_expanded;
    my @color_x;

    my $font = $w->{Font};
    if (!defined $font) {
	$font = $w->optionGet("font", "Font");
	if (!defined $font) {
	    die "XXX no font?";
	}
    }
    my $font_height = $w->fontMetrics($font, '-linespace');
    my $add_y = 2;

    my($start_x, $start_y, $bar_width) = ($w->{Start_x}, $w->{Start_y}, $w->{Bar_width});
    my @color_def = @{ $w->{Color_def} };
    my $bar_length = 0;

    my $x_i = $start_x;
    my $y_top = $start_y + $font_height + $add_y;

    for(my $i=0; $i<=$#color_def-2; $i+=2) {
	my($this_color, $attrib, $next_color) = @color_def[$i..$i+2];
	my(@from_rgb) = $w->rgb($this_color);
	my(@to_rgb)   = $w->rgb($next_color);

	$bar_length += $attrib->{len};

	for my $x (0 .. $attrib->{len}-1) {
	    my $new_color = sprintf "#%02x%02x%02x", map { (($to_rgb[$_]-$from_rgb[$_])*($x/$attrib->{len})+$from_rgb[$_])/256 } (0..2);
	    $color_expanded[$x_i-$start_x] = $new_color;
	    $color_x[$x_i-$start_x] = $x_i;
	    $w->createLine($x_i, $y_top, $x_i, $y_top+$bar_width,
			   -fill => $new_color);
	    $x_i++;
	}
    }

    $w->{Color_expanded} = \@color_expanded;
    $w->{Color_x} = \@color_x;
    $w->{Bar_length} = $bar_length;

    my @scaledef = @{ $w->{Scale_def} };

    for(my $i=0; $i<=$#scaledef; $i++) {
	my $x = $start_x+$bar_length*$scaledef[$i]/($scaledef[-1]-$scaledef[0]);
	$w->createLine($x, $start_y+$font_height+1, $x, $start_y+$font_height+1+$bar_width+2, -tags => ["scale", "scale-$scaledef[$i]"]);
	$w->createText($x, $start_y+$font_height, -anchor => "s", -text => $scaledef[$i], -tags => ["scale", "scale-$scaledef[$i]"]);
    }

    $w->bind("scale", "<ButtonPress-1>" =>
	     [sub {
		  my $w = shift;
		  $w->{Scale_move_x} = shift;
		  my(@tags) = $w->gettags("current");
		  $w->{Scale_active} = $tags[1];
		  (my $scale_value = $w->{Scale_active}) =~ s/scale-//;
		  my $pos;
		  for my $i (0 .. $#scaledef) {
		      if ($scale_value == $scaledef[$i]) {
			  $pos = $i;
			  last;
		      }
		  }
		  if ($w->{MoveCarry}) {
		      $w->{Scale_limits}[0] = $start_x-1;
		      $w->{Scale_limits}[1] = $start_x+$bar_length+1;
		      $w->{Scale_value} = $scale_value;
		  } else {
		      $w->{Scale_limits}[0] =
			  ($pos == 0 ?
			   $start_x-1 :
			   ($w->coords("scale-$scaledef[$pos-1]"))[0]);
		      $w->{Scale_limits}[1] =
			  ($pos == $#scaledef ?
			   $start_x+$bar_length+1 :
			   ($w->coords("scale-$scaledef[$pos+1]"))[0]);
		  }
	      }, Ev("x")]);
    $w->bind("scale", "<B1-Motion>" =>
	     [sub {
		  my($w, $x) = @_;
		  my @items = $w->find(withtag => $w->{Scale_active});
		  my $now_x = ($w->coords($w->{Scale_active}))[0];
		  foreach my $item (@items) {
		      my $delta = $x-$w->{Scale_move_x};
		      return if ($now_x+$delta >= $w->{Scale_limits}[1] ||
				 $now_x+$delta <= $w->{Scale_limits}[0]);
		      if ($w->{MoveCarry}) {
			  my $scale_value = $w->{Scale_value};
			  for my $i (0 .. $#scaledef) {
			      if ($scaledef[$i] > $scale_value) {
				  my $i2 = "scale-".$scaledef[$i];
				  my $x2 = ($w->coords($i2))[0];
				  if ($x2 < $x) {
				      $w->move($i2, $x-$x2, 0);
				  }
			      } elsif ($scaledef[$i] < $scale_value) {
				  my $i2 = "scale-".$scaledef[$i];
				  my $x2 = ($w->coords($i2))[0];
				  if ($x2 > $x) {
				      $w->move($i2, $x-$x2, 0);
				  }
			      }
			  }
		      }
		      $w->move($item, $delta, 0);
		  }
		  $w->{Scale_move_x} = $x;
	      }, Ev("x")]);
    $w->bind("scale", "<ButtonRelease-1>" =>
	     [sub {
		  undef $w->{Scale_active};
	      }, Ev("x")]);

    $args->{-width}  = $start_x + $bar_length + 5; # XXX + how many padding?
    $args->{-height} = $start_y + $font_height + $add_y + $bar_width + 2;
}

sub get_mapping {
    my $w = shift;
    my $prev_x;
    my @scaledef = @{ $w->{Scale_def} };
    my @color_expanded = @{ $w->{Color_expanded} };
    my $start_x = $w->{Start_x};
    my %mapping = ();
    foreach my $item ($w->find("withtag" => "scale")) {
	my $scale_active = ($w->gettags($item))[1];
	(my $scale_value = $scale_active) =~ s/scale-//;
	next if exists $mapping{$scale_value};
	my $x = ($w->coords($item))[0];
	my $pos;
	for(my $i=0; $i<=$#scaledef; $i++) {
	    if ($scale_value == $scaledef[$i]) {
		$pos = $i;
		last;
	    }
	}
	if ($pos == 0) {
	    $prev_x = $x;
	    next;
	}
	for my $i ($scaledef[$pos-1] .. $scaledef[$pos]) {
	    my $this_x = ($x-$prev_x)*($i-$scaledef[$pos-1])/($scaledef[$pos]-$scaledef[$pos-1])+$prev_x;
	    $mapping{$i} = $color_expanded[$this_x-$start_x];
	    if (!defined $mapping{$i}) {
		$mapping{$i} = $color_expanded[-1];
	    }
	}
	$prev_x = $x;
    }
    \%mapping;
}

sub set_mapping {
    my($w, $mapping) = @_;

    my @scaledef = @{ $w->{Scale_def} };
    my %color_to_i;
    for (0 .. $#{ $w->{Color_expanded} }) {
	$color_to_i{$w->{Color_expanded}[$_]} = $_;
    }

    my $max_mapping_val;
    for my $i (@scaledef) {
	if (!exists $mapping->{$i}) {
	    if (!defined $max_mapping_val) {
		$max_mapping_val = (sort { $a <=> $b } keys %$mapping)[-1];
	    }
	    warn "Setting scale-$i to max ($max_mapping_val)\n";
	    $mapping->{$i} = $mapping->{$max_mapping_val};
	}
	my $color_i = $color_to_i{$mapping->{$i}};
	my $color_x = $w->{Color_x}[$color_i];
	for my $ci ($w->find(withtag => "scale-$i")) {
	    $w->move($ci, $color_x-($w->coords($ci))[0], 0);
	}
    }
}

return 1 if caller;

__END__
