# -*- perl -*-

#
# $Id: BBBikeProfil.pm,v 1.10 2003/11/16 21:15:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeProfil;
use BBBikeUtil;
use strict;
use vars qw();

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

sub new {
    bless {}, $_[0];
}

sub Show {
    my($self, $top, $context, %args) = @_;
    return if $self->{Destroyed};
    my $toplevel;
    if ($context->{ProfilToplevel} &&
	Tk::Exists($context->{ProfilToplevel})) {
	$toplevel = $context->{ProfilToplevel};
    } else {
	$toplevel = $top->Toplevel(-title => M"Profil");
	$toplevel->OnDestroy(sub { $self->{Destroyed} = 1});
	$toplevel->transient($top) if $context->{Transient};
	$context->{ProfilToplevel} = $toplevel;

	my @hooks = qw/new_route del_route/;
	foreach my $hook (@hooks) {
	    Hooks::get_hooks($hook)->add
		    (sub { $self->Show($top, $context, %args) }, "profil");
	}
	$toplevel->OnDestroy
	    (sub {
		 foreach my $hook (@hooks) {
		     Hooks::get_hooks($hook)->del("profil");
		 }
	     }
	    );
    }
    my $c;
    if ($context->{ProfilCanvas} &&
	Tk::Exists($context->{ProfilCanvas})) {
	$c = $context->{ProfilCanvas};
    } else {
	my($w, $h) = (int($top->screenwidth/3*2),
		      int($top->screenheight/6));
	$c = $toplevel->Canvas(-height => $h, -width => $w)->pack;
	$context->{ProfilCanvas} = $c;
    }

    $self->Redraw($context, %args);
}

sub Redraw {
    my($self, $context, %args) = @_;
    my $t = $context->{ProfilToplevel};
    my $c = $context->{ProfilCanvas};
    $c->delete('all');
    my $hoehe   =    $context->{Hoehe};
    my(@coords) = @{ $context->{Coords} };
    my($w, $h) = ($c->cget(-width), $c->cget(-height));
    my(@dist) = (0);
    for(my $i=0; $i<$#coords; $i++) {
	my($x1,$y1, $x2,$y2) = (@{ $coords[$i] },
				@{ $coords[$i+1] });
	my $dist = CORE::sqrt(sqr($x2-$x1)+sqr($x2-$x1));
	push @dist, $dist[$#dist] + $dist;
    }

    my $max_h;
    my $min_h;
    for(my $i=0; $i<=$#coords; $i++) {
	my($x,$y) = @{ $coords[$i] };
	if (exists $hoehe->{"$x,$y"}) {
	    my $this_hoehe = $hoehe->{"$x,$y"};
	    if (!defined $max_h || $max_h < $this_hoehe) {
		$max_h = $this_hoehe;
	    }
	    if (!defined $min_h || $min_h > $this_hoehe) {
		$min_h = $this_hoehe;
	    }
	}
    }

    if (!defined $max_h) {
	print STDERR "Es gibt keine Höheninformationen für diese Route\n";
	return;
    }

    my $x_sub = sub { int($_[0]/$dist[$#dist]*$w) };
    my $y_sub = sub { $h - int($_[0]/($max_h+10)*$h) };

    my($lastx, $lasty);
    my @etappe_coords;
    for(my $i=0; $i<=$#dist; $i++) {
	my($d) = $dist[$i];
	my($x,$y) = @{ $coords[$i] };
	push @etappe_coords, $x, $y;
	if (exists $hoehe->{"$x,$y"}) {
	    my($thisx, $thisy);
	    $thisx = $x_sub->($d);
	    $thisy = $y_sub->($hoehe->{"$x,$y"});
	    if (defined $lastx) {
		$c->createLine
		    ($lastx, $lasty, $thisx, $thisy,
		     -activefill => 'blue',
		     -tags => ["alt",
			       "alt-" . join(",",@etappe_coords),
			      ]
		    );
		@etappe_coords = ($x, $y);
	    }
	    ($lastx, $lasty) = ($thisx, $thisy);
	}
    }

    for(my $i=0; $i<=10; $i++) {
	my $thisx = int(($i/10)*$w);
	$c->createText($thisx, $h-7,
		       -text => m2km(($i/10)*$dist[$#dist], 1, 1));
    }

    my $max_y = $y_sub->($max_h);
    $c->createText(2, $max_y,
		   -anchor => 'w', -text => int($max_h) . "m");
    my $min_y = $y_sub->($min_h);
    if ($min_y - $max_y > 10) { # don't overlap
	$c->createText(2, $min_y,
		       -anchor => 'w', -text => int($min_h) . "m");
    }

    if ($Tk::VERSION > 800.018) { # dash patches, ca.
	for my $y ($max_y, $min_y) {
	    $c->createLine(25, $y, $w, $y, -dash => "..");
	}
    }

    $c->raise("alt");
    # bind <1> to mark point
    $c->bind("alt", "<1>" => sub {
		 my(@tags) = $c->gettags("current");
		 (my $coords = $tags[1]) =~ s/alt-//;
		 my @coords = split /,/, $coords;
		 my @newcoords;
		 for(my $i=0; $i<$#coords;$i+=2) {
		     push @newcoords, [ main::transpose(@coords[$i,$i+1]) ];
		 }
		 main::mark_street(-clever_center => 1,
				   -coords => [[@newcoords]]);
	     });
}

1;

__END__
