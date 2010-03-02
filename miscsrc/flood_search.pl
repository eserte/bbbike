#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: flood_search.pl,v 1.16 2007/04/24 18:49:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Flood search
# Description (de): Flood search
package BBBikeFloodSearchPlugin;

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use vars qw($net_type $show_rings $circle_unit);
$net_type = "s" if !defined $net_type;
$show_rings = 0 if !defined $show_rings;
$circle_unit = "km" if !defined $circle_unit;

use your qw(%main::map_mode_callback $main::Radiobutton $main::net
	    %main::do_flag %main::penalty_subs);

use base qw(BBBikePlugin);
use Strassen::Util;
use Strassen::SimpleSearch qw(simple_search);
use BBBikeUtil qw(s2hm);

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    $main::map_mode_callback{$pkg} = \&activate;
    add_button();
    if (!grep { $_ eq "flood" } @main::normal_stack_order) {
	push @main::normal_stack_order, "flood";
    }
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    if ($main::map_mode eq $pkg &&
	$main::map_mode_deactivate) {
	$main::map_mode_deactivate->();
    
}
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }

    BBBikePlugin::remove_menu_button($pkg."_menu");

    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $Radiobutton = $main::Radiobutton;
    my $b;
    # XXX Custom Cursor setzen
    my %radio_args =
	(-variable => \$main::map_mode,
	 -value => __PACKAGE__,
	 -command => \&main::set_map_mode,
	);
    $b = $mf->$Radiobutton
	(-text => "FS",
	 #main::image_or_text($salesman_photo, 'Salesman'),
	 %radio_args,
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "Flood search")
	if $main::balloon;

    my $ein_ausblenden_menuitems =
	[[Radiobutton => "Alles",
	  -variable => \$show_rings,
	  -value => 0,
	  -command => sub { update_ring_visibility() },
	 ]];
    for my $ring (2, 3, 4, 5, 7, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150) {
	push @$ein_ausblenden_menuitems,
	    [Radiobutton => "Alle $ring km",
	     -variable => \$show_rings,
	     -value => $ring,
	     -command => sub { update_ring_visibility() },
	    ];
    }
	       
    BBBikePlugin::place_menu_button
	    ($mmf,
	     [[Button => "~Delete", -command => sub { delete_flood_lines() }],
	      [Radiobutton => "Nur Straßen",
	       -variable => \$net_type,
	       -value => "s",
	      ],
	      [Radiobutton => "Straßen und Bahnen",
	       -variable => \$net_type,
	       -value => "s_b",
	      ],
	      "-",
	      [Radiobutton => "km",
	       -variable => \$circle_unit,
	       -value => "km",
	      ],
	      [Radiobutton => "Minuten",
	       -variable => \$circle_unit,
	       -value => "min",
	      ],
	      "-",
	      [Cascade => "Ein-/ausblenden",
	       -menuitems => $ein_ausblenden_menuitems,
	      ],
	      "-",
	      [Button => "Dieses Menü löschen",
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	     -title => "Flood Search",
	     -topmenu => [Radiobutton => 'Flood Search mode',
			  %radio_args,
			 ],
	    );
}

sub update_ring_visibility {
    if ($show_rings == 0) {
	$main::c->itemconfigure("flood", -state => "normal");
    } else {
	my $dist = $show_rings;
	$main::c->itemconfigure("flood", -state => "hidden");
	while($dist < 600) { # max. 10 hours
	    $main::c->itemconfigure("flood-$dist", -state => "normal");
	    $dist += $show_rings;
	}
    }
}

sub activate {
    $main::map_mode = __PACKAGE__;
    $main::map_mode_deactivate = \&deactivate;
    main::std_transparent_binding("flood");
    main::status_message("Start-Koordinate setzen", "info");
}

sub deactivate {
}

sub delete_flood_lines {
    $main::c->delete("flood");
    $main::c->delete("start_flag");
}

sub button {
    my $c = $main::c;
    my $net = $main::net;
    my $e = $c->XEvent;
    my($cx,$cy) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my($x,$y) = main::anti_transpose($cx,$cy);
    my $start_coord = $net->fix_coords("$x,$y");
    {
	my($x,$y) = main::transpose(split /,/, $start_coord);
	local $main::do_flag{'start'} = 1;
	main::set_flag("start", $x, $y, 0);
    }
    # XXX Rückmeldung fehlt, dass die Suche jetzt läuft
    flood_search($c, $net, $start_coord);
    main::status_message("Start-Koordinate setzen", "info");
    return 1;
}

sub flood_search {
    my($c, $net, $act_coord) = @_;

    if (!defined &transpose) {
	*transpose = \&main::transpose;
    }

    $c->delete("flood");

    my($start_x,$start_y) = split /,/, $act_coord;

    my $last_circle = 0;
    my @circle_coords;

    my($max_gap) = Strassen::Util::strecke([transpose(0,0)],
					   [transpose(5000,0)],
					  );

    my $adjust_dist_text =
	($circle_unit eq 'km'
	 ? sub { $_[0] }
	 : sub {
	     my $dist = shift;
	     my $time = $dist*1000 / (main::get_active_speed()/3.6);
	     s2hm($time);
	 }
	);

    my $draw_circle = sub {
	my $circle = shift;
	if (!defined $circle || !$circle_coords[$circle]) {
	    warn "\$circle not defined!!!";
	    return;
	}
	my @cs;
	my($lastx,$lasty);
	for my $def (sort { $a->[2] <=> $b->[2] } @{ $circle_coords[$circle] }) {
	    my($x,$y) = transpose($def->[0], $def->[1]);
	    if (defined $lastx &&
		Strassen::Util::strecke([$lastx,$lasty],[$x,$y])<$max_gap) {
		push @{$cs[-1]}, $x, $y;
	    } else {
		push @cs, [$x,$y];
	    }
	    ($lastx,$lasty) = ($x,$y);
	}
	if (Strassen::Util::strecke([@{$cs[0]}[0,1]],
				    [@{$cs[-1]}[-2,-1]])<$max_gap) {
	    push @{$cs[-1]}, @{$cs[0]}[0,1];
	}
	for my $cdef (@cs) {
	    my $entf = $circle;
	    my $fill = ($entf % 10 == 0 ? "#b00000" :
			$entf %  5 == 0 ? "#00b000" :
			"black");
	    if (@$cdef == 2) {
		@$cdef = (@$cdef, @$cdef);
	    }
	    $c->createLine(@$cdef, -fill => $fill,
			   -tags => ["flood","flood-circle","flood-$entf"]);
	    my $label_dist;
	    for(my $coord_i = 0; $coord_i < $#$cdef; $coord_i+=2) {
		if ($coord_i > 0) {
		    $label_dist += Strassen::Util::strecke
			([@{$cdef}[$coord_i, $coord_i+1]],
			 [@{$cdef}[$coord_i-2, $coord_i-1]],
			);
		}
		if (!defined $label_dist || $label_dist > 300) {
		    my @args = ($cdef->[$coord_i],$cdef->[$coord_i+1],
				-anchor => "w",
				-text => $adjust_dist_text->($entf),
				-fill => $fill,
				-tags => ["flood", "flood-text","flood-$entf"]);
		    if (defined &main::outline_text) {
			#warn "@args";
			main::outline_text($c, @args);
		    } else {
			$c->createText(@args);
		    }
		    $label_dist = 0;
		}
	    }
	}
    };

    my $adjust_dist = sub {
	my($dist, $act_coord, $neighbor) = @_;
	while(my($k,$v) = each %main::penalty_subs) {
	    $dist = $v->($dist, $neighbor, $act_coord);
	}
	$dist;
    };

    # XXX configurable
    my $CIRCLE_DELTA = 1000; # XXX ($circle_unit eq 'km' ? 1000 : 1000*16);

    simple_search
	($net, $act_coord, undef,
	 adjustdist => $adjust_dist,
	 callback => sub {
	     my($new_act_coord, $new_act_dist, $act_coord, $PRED, $CLOSED, $OPEN) = @_;
	     if (exists $PRED->{$new_act_coord} && int($CLOSED->{$PRED->{$new_act_coord}}/$CIRCLE_DELTA) != int($new_act_dist/$CIRCLE_DELTA)) { # XXX mehrere Sprünge checken
		 my $len = Strassen::Util::strecke_s($PRED->{$new_act_coord}, $new_act_coord);
		 $len = $adjust_dist->($len, $new_act_coord, $PRED->{$new_act_coord});
		 my @new_dist;
		 ### klappt nicht
		 #  	    if ($len > 2000) {
		 #  		my $steps = int($len/$CIRCLE_DELTA);
		 #  		my $dist = (int($CLOSED{$PRED{$new_act_coord}}/$CIRCLE_DELTA)+1)*$CIRCLE_DELTA;
		 #  		for (1..$steps) {
		 #  		    push @new_dist, $dist;
		 #  		    $dist += $CIRCLE_DELTA;
		 #  		}
		 #  	    }
		 push @new_dist, $new_act_dist;
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\@new_dist],[])->Indent(1)->Useqq(1)->Dump if @new_dist>1;

		 for my $new_dist (@new_dist) {
		     my $rest = $new_dist%$CIRCLE_DELTA;
		     my($x1,$y1) = split /,/, $PRED->{$new_act_coord};
		     my($x2,$y2) = split /,/, $new_act_coord;
		     my($x, $y) = ($x2-($x2-$x1)*$rest/$len,
				   $y2-($y2-$y1)*$rest/$len);

		     push @{ $circle_coords[int($new_dist/$CIRCLE_DELTA)] },
			 [$x,$y, atan2($start_y-$y, $start_x-$x)];
		 }

		 if (1) {
		     if (int($new_act_dist/$CIRCLE_DELTA) > $last_circle+1) {
			 $draw_circle->($last_circle+1);
			 update_ring_visibility();
			 $c->update;
			 $last_circle++;
		     }
		 }
	     }
	 },
	);
}

return 1 if caller;

require Strassen::Core;
require Strassen::StrassenNetz;
eval 'use BBBikeXS'; warn $@ if $@;
require Tk;
require Tk::CanvasUtil;
require Object::Iterate;
eval 'use Tk::Autoscroll';
require BBBikeTrans;

use vars qw($scale);
$scale = 1;
old_create_transpose_subs();
*transpose = \&transpose_ls_slow;

my $mw = MainWindow->new;
$mw->geometry("1000x700+0+0");
my $c = $mw->Scrolled("Canvas")->pack(-fill => "both", -expand => 1);
eval { Tk::Autoscroll::Init($c) };

my $s = Strassen->new("strassen");
my $net = StrassenNetz->new($s);
$net->make_net;
$net->make_sperre("gesperrt");

my $draw_streets = 1;
if ($draw_streets) {
    Object::Iterate::iterate(sub {
	for my $i (1 .. $#{$_->[Strassen::COORDS()]}) {
	    $c->createLine(transpose(split(/,/,$_->[Strassen::COORDS()][$i-1])),
			   transpose(split(/,/,$_->[Strassen::COORDS()][$i])), -fill => "white");
	}
    }, $s);
}

#my $start_coord = "14598,11245"; # Sonntagstr.
my $start_coord = shift || "8982,8781"; # Dudenstr.

if ($draw_streets) {
    $c->configure(-scrollregion => [$c->bbox("all")]);
} else {
    $c->configure(-scrollregion => [-18689,-6686,33575,28095]);
}
$c->update;
my($cx,$cy) = transpose(split(/,/,$start_coord));
$c->see($cx,$cy);

flood_search($c, $net, $start_coord);

Tk::MainLoop();


__END__
