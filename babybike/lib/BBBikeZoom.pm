# -*- perl -*-

#
# $Id: BBBikeZoom.pm,v 1.14 2003/08/24 23:30:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeZoom;
use base qw(Tk::Frame);
Construct Tk::Widget 'BBBikeZoom';
use strict;

sub ClassInit {
    my($class,$mw) = @_;
    $mw->bind($class,'<Up>'=>'up');
    $mw->bind($class,'<Down>'=>'down');
    $mw->bind($class,'<Left>'=>'left');
    $mw->bind($class,'<Right>'=>'right');
    $class;
}

sub Populate {
    my($w,$args) = @_;
    $args->{-takefocus} = 1;
    $w->gridColumnconfigure(0, -weight => 1);
    $w->gridRowconfigure(0, -weight => 1);

    my $c = $w->Component("Canvas" => "Canvas",
			  -highlightthickness => 0,
			  -takefocus => 0,
			 )->grid(-column => 0, -row => 0,
				 -sticky => "esnw");
    $c->CanvasBind("<1>" => sub {
		       my($c) = @_;
		       my $ev = $c->XEvent;
		       $w->Callback(-command => $w, $ev->x, $ev->y);
		   });

    $w->optionAdd("*CrsrButton*Pad", 0);
    $w->optionAdd("*CrsrButton*highlightThickness", 0);

    $w->Component("Button", "UpLeft", -class => "CrsrButton",
		  -text => "\\",
		  -command => [$w, 'upleft'])->place(-x => 0, -y => 0,
						     -anchor => "nw", -in => $c);
    $w->Component("Button", "UpRight", -class => "CrsrButton",
		  -text => "/",
		  -command => [$w, 'upright'])->place(-relx => 1, -y => 0,
						      -anchor => "ne", -in => $c);
    $w->Component("Button", "DownLeft", -class => "CrsrButton",
		  -text => "/",
		  -command => [$w, 'downleft'])->place(-x => 0, -rely => 1,
						       -anchor => "sw", -in => $c);
    $w->Component("Button", "DownRight", -class => "CrsrButton",
		  -text => "\\",
		  -command => [$w, 'downright'])->place(-relx => 1, -rely => 1,
							-anchor => "se", -in => $c);

    $w->Component("Button", "Up", -class => "CrsrButton",
		  -text => "^",
		  -command => [$w, 'up'])->place(-relx => 0.5, -y => 0,
						 -anchor => "n", -in => $c);
    $w->Component("Button", "Down", -class => "CrsrButton",
		  -text => "v",
		  -command => [$w, 'down'])->place(-relx => 0.5, -rely => 1,
						   -anchor => "s", -in => $c);
    $w->Component("Button", "Left", -class => "CrsrButton",
		  -text => "<",
		  -command => [$w, 'left'])->place(-x => 0, -rely => 0.5,
						   -anchor => "w", -in => $c);
    $w->Component("Button", "Right", -class => "CrsrButton",
		  -text => ">",
		  -command => [$w, 'right'])->place(-relx => 1, -rely => 0.5,
						    -anchor => "e", -in => $c);

    my $bf = $w->Frame->grid(-column => 0, -row => 1);
    $w->Advertise(ZoomOut =>
		  $bf->Button(-text => "-", -padx => 0, -pady => 0,
			      -command => [$w, 'zoom_out']
			     )->pack(-side => "left")
		 );
    $w->Advertise(ZoomIn =>
		  $bf->Button(-text => "+", -padx => 0, -pady => 0,
			      -command => [$w, 'zoom_in']
			     )->pack(-side => "left")
		 );
    $w->Advertise(Close =>
		  $bf->Button(-text => "Close", -padx => 0, -pady => 0,
			      -command => sub {
				  $w->Callback(-closecmd);
			      },
			     )->pack(-side => "left", -anchor => "e")
		 );

    $w->ConfigSpecs
	(-master => ['PASSIVE', 'master', 'Master', undef],
	 -width => [$c],
	 -height => [$c],
	 -streets => ['METHOD', 'streets', 'Streets', undef],
	 -route => ['PASSIVE', 'route', 'Route', undef],
	 -cookedstreets => ['METHOD', 'cookedStreets', 'CookedStreets', undef],
  	 -transpose => ['PASSIVE'],
	 -antitranspose => ['PASSIVE'],
	 -closecmd => ['CALLBACK', 'closeCmd', 'CloseCmd', [$w, 'destroy']],
	 -font => ['PASSIVE', 'font', 'Font', 'Helvetica -8'],
	 -restrict  => ['PASSIVE'],
	 -ignore  => ['PASSIVE'],
	 -createline  => ['PASSIVE', undef, undef, $c->can('createLine')],
	 -createpoint => ['PASSIVE', undef, undef, $c->can('createText')],
	 -predrawcmd => ['CALLBACK', 'predrawCmd', 'PreDrawCmd', undef],
	 -postdrawcmd => ['CALLBACK', 'postdrawCmd', 'PostDrawCmd', undef],
	 -command => ['CALLBACK', 'command', 'Command', undef],
	);
}

sub streets {
    my($w) = shift;
    if (@_) {
	my @s = @{ $_[0] };
	$w->{Configure}{-streets} = \@s;
	$w->afterIdle
		(sub {
#  		 my $anti_transpose = $w->cget(-antitranspose);
#  		 my($x0,$y0) = $anti_transpose->(0,0);
#  		 my($x1,$y1) = $anti_transpose->($w->cget(-width),
#  						 $w->cget(-height));
		     foreach my $s (@s) {
			 $s->make_grid(UseCache => 1,
				       Exact => 1,
#  			       GridWidth => abs($x1-$x0),
#  			       GridHeight => abs($y1-$y0),
				      );
		     }
	     })
    }
    $w->{Configure}{-streets};
}

sub cookedstreets {
    my($w) = shift;
    if (@_) {
	$w->{Configure}{-streets} = [@{ $_[0] }];
    }
    $w->{Configure}{-streets};
}

sub draw {
    my($w,%args) = @_;
    my $c = $w->Subwidget("Canvas");
    $c->delete("all");
    if ($args{-extents}) {
	$w->{Extents} = [@{ $args{-extents} }];
    }
    my($x1,$y1,$x2,$y2) = @{ $w->{Extents} };
    my($width, $height) = ($c->cget(-width), $c->cget(-height));

    $w->Callback(-predrawcmd => $w);

    my $transpose = sub {
	(($_[0]-$x1)/($x2-$x1)*$width,
	 ($_[1]-$y2)/($y1-$y2)*$height);
    };
    $w->configure(-transpose => $transpose);
    my $antitranspose = sub {
	($_[0]/$width*($x2-$x1)+$x1,
	 $_[1]/$height*($y1-$y2)+$y2);
    };
    $w->configure(-antitranspose => $antitranspose);

    my $font = $w->cget(-font);

    my $create_line  = $w->cget(-createline);
    my $create_point = $w->cget(-createpoint);
    my $restrict = $w->cget(-restrict);
    my $ignore = $w->cget(-ignore);

    my $draw_general_line = sub {
	my($p_ref, $r) = @_;
	$create_line->($c, @$p_ref, -tags => "s-".$r->[Strassen::CAT()]);
    };

    my $draw_general_point = sub {
	my($x1,$y1,$text) = @_;
	my($tx1,$ty1) = $transpose->($x1,$y1);
	$text =~ s/\s+\(.*$//;
	$create_point->($c,$tx1,$ty1,-text => $text, -font => $font);
    };

    my @s = @{ $w->cget('-streets') };
    foreach my $s (@s) {
	my %seen_pos;
	my(@grids) = $s->get_new_grids($x1, $y1, $x2, $y2);
	foreach my $grid (@grids) {
	    next if !exists $s->{Grid}{$grid};
	    foreach my $strpos (@{ $s->{Grid}{$grid} }) {
		next if $seen_pos{$strpos};
		$seen_pos{$strpos}=1;
		my $r = $s->get($strpos);
		next if $restrict && !$restrict->{$r->[Strassen::CAT]};
		next if $ignore   && $ignore->{$r->[Strassen::CAT]};
		if (@{ $r->[Strassen::COORDS()] } == 1) {
		    $draw_general_point->(split(/,/, $r->[Strassen::COORDS()][0]), $r->[Strassen::NAME()]);
		} else {
		    my(@p);
		    foreach my $p (@{ $r->[Strassen::COORDS()] }) {
			push @p, $transpose->(split /,/, $p);
		    }
		    $draw_general_line->(\@p, $r);
		}
	    }
	}
    }

    my $route = $w->cget('-route');
    if ($route) {
	$route->init;
	while(1) {
	    my $r = $route->next;
	    last if !@{$r->[Strassen::COORDS()]};
	    my(@p);
	    foreach my $p (@{ $r->[Strassen::COORDS()] }) {
		push @p, $transpose->(split /,/, $p);
	    }
	    $draw_general_line->(\@p, $r);
	}
    }

    $w->Callback(-postdrawcmd => $w);
}

sub center {
    my($w, $x,$y) = @_;
    my @extents = @{ $w->{Extents} };
    my $width  = $extents[2]-$extents[0];
    my $height = $extents[3]-$extents[1];
    $w->draw(-extents => [$x-$width/2,$y-$height/2,
			  $x+$width/2,$y+$height/2]);
}

sub _updown_extents {
    my($w, $sign, $extents) = @_;
    $extents = $w->{Extents} if !$extents;
    my @extents = @{ $extents };
    my $diff = ($extents[1]-$extents[3])/2;
    $extents[1] += ($diff*$sign);
    $extents[3] += ($diff*$sign);
    \@extents;
}

sub _leftright_extents {
    my($w, $sign, $extents) = @_;
    $extents = $w->{Extents} if !$extents;
    my @extents = @{ $extents };
    my $diff = ($extents[0]-$extents[2])/2;
    $extents[0] += ($diff*$sign);
    $extents[2] += ($diff*$sign);
    \@extents;
}

sub up {
    my $w = shift;
    $w->draw(-extents => $w->_updown_extents(-1));
}

sub down {
    my $w = shift;
    $w->draw(-extents => $w->_updown_extents(+1));
}

sub left {
    my $w = shift;
    $w->draw(-extents => $w->_leftright_extents(+1));
}

sub right {
    my $w = shift;
    $w->draw(-extents => $w->_leftright_extents(-1));
}

sub upleft {
    my $w = shift;
    my $extents = $w->_updown_extents(-1);
    $w->draw(-extents => $w->_leftright_extents(+1, $extents));
}

sub upright {
    my $w = shift;
    my $extents = $w->_updown_extents(-1);
    $w->draw(-extents => $w->_leftright_extents(-1, $extents));
}

sub downleft {
    my $w = shift;
    my $extents = $w->_updown_extents(+1);
    $w->draw(-extents => $w->_leftright_extents(+1, $extents));
}

sub downright {
    my $w = shift;
    my $extents = $w->_updown_extents(+1);
    $w->draw(-extents => $w->_leftright_extents(-1, $extents));
}

sub zoom_in {
    my $w = shift;
    my @extents = @{ $w->{Extents} };
    my $width = $extents[2]-$extents[0];
    my $height = $extents[3]-$extents[1];
    $extents[0]+=$width/4;
    $extents[2]-=$width/4;
    $extents[1]+=$height/4;
    $extents[3]-=$height/4;
    $w->draw(-extents => \@extents);
}

sub zoom_out {
    my $w = shift;
    my @extents = @{ $w->{Extents} };
    my $width = $extents[2]-$extents[0];
    my $height = $extents[3]-$extents[1];
    $extents[0]-=$width/2;
    $extents[2]+=$width/2;
    $extents[1]-=$height/2;
    $extents[3]+=$height/2;
    $w->draw(-extents => \@extents);
}

1;

__END__
