# -*- perl -*-

#
# $Id: BBBikeExp.pm,v 1.10 2002/07/13 20:48:26 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# BBBike-Experimente

# in package main

use Strassen;
use strict;
use vars qw(%exp_str_drawn %exp_str %str_color
	    %exp_p_drawn %exp_p %p_color %p_name_draw
	    %exp_known_grids
	    $plotpoint_draw_sub $plotstr_draw_sub
	    $coord_system_obj $coord_system
	    %outline_color %p_draw
	    $c $pp_color $lowmem $net
	    %line_width $scale $verbose
	    $xadd_anchor_type $yadd_anchor_type
	    @orte_coords $place_category
	    $orientation $no_make_net $environment
	   );

my(@defs_str, @defs_p, @defs_p_o);
if ($coord_system eq 'standard') {
    if ($lowmem) {
	@defs_str = (['s', 'strassen'],
		     ['l', 'landstrassen'],
		    );
    } else {
	if ($environment eq 'novacom') {

	    @defs_str = (['s', 'strassen'],
			 ['w', 'wasserstrassen'],
			 ['u', 'ubahn'],
			 ['b', 'sbahn'],
			 );
	    @defs_p = (['u', 'ubahnhof'],
		       ['b', 'sbahnhof'],
		       );

	} else {

	    @defs_str = (['s', 'strassen'],
			 ['w', 'wasserstrassen'],
			 ['l', 'landstrassen'],
			 ['f', 'flaechen'],
			 ['u', 'ubahn'],
			 ['b', 'sbahn'],
			 ['r', 'rbahn'],
			 ['qs', 'qualitaet_s'],
			 ['ql', 'qualitaet_l'],
			 );
	    @defs_p = (['u', 'ubahnhof'],
		       ['b', 'sbahnhof'],
		       ['r', 'rbahnhof'],
		       ['lsa', 'ampeln'],
		       );
	    @defs_p_o = (['o', 'orte']); # Extra-Wurst wegen plotorte()
	}

    }
} else {
    @defs_str = (['s', 'strassen-orig']);
}
my @defs_str_abk = map { $_->[0] } @defs_str;
my @defs_p_abk   = map { $_->[0] } @defs_p;
my @defs_p_o_abk = map { $_->[0] } @defs_p_o;

bbbikeexp_init();

sub bbbikeexp_init {
    %exp_str_drawn = ();
    %exp_p_drawn = ();
    %exp_known_grids = ();
    foreach my $def (@defs_str) {
	if (!$exp_str{$def->[0]}) {
	    $exp_str{$def->[0]} = new Strassen $def->[1];
	    $exp_str{$def->[0]}->make_grid(UseCache => 1);
	}
    }
    foreach my $def (@defs_p, @defs_p_o) {
	if (!$exp_p{$def->[0]}) {
	    $exp_p{$def->[0]} = new Strassen $def->[1];
	    $exp_p{$def->[0]}->make_grid(UseCache => 1);
	}
    }
    make_net(-l_add => 1) if !defined $net and !$no_make_net;
    my($x1,$y1,$x2,$y2) = $c->get_corners;
    plotstr_on_demand
      (anti_transpose($x1,$y1),
       anti_transpose($x2,$y2));
}

sub plotstr_on_demand {
    my($x1, $y1, $x2, $y2) = @_;

    my(@grids) = $exp_str{'s'}->get_new_grids
      ($x1, $y1, $x2, $y2,
       KnownGrids => \%exp_known_grids);
    my $something_new = 0;
    if (@grids) {
	foreach my $abk (@defs_str_abk) {
	    my %category_width;
	    my $default_width = get_line_width($abk) || 4;
	    #XXX skalieren...
	    {
		foreach (keys %line_width) {
		    if (/^$abk-(.*)/) {
			my $cat = $1;
			$category_width{$cat} = get_line_width($_, $scale);
		    }
		}
	    }

	    my $i;
	    my $restrict = undef; #XXX
	    my $coordsys = $coord_system_obj->coordsys;
	    my $use_stippleline = 0; # XXX Duplikat in plotstr
	    if ($abk =~ /^q[ls]$/) {
		if ($Tk::VERSION >= 800.016) {
		    $use_stippleline = 2; # new dash code
		} else {
		    $use_stippleline = 1;
		    require Tk::StippleLine;
		}
	    }

	    my $transpose = \&transpose;
	    my $draw_sub = eval $plotstr_draw_sub;
	    die $@ if $@;
	    
	    foreach my $grid (@grids) {
		if ($exp_str{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $exp_str{$abk}->{Grid}{$grid} }) {
			if (!$exp_str_drawn{$abk}->{$strpos}) {
			    my $r = $exp_str{$abk}->get($strpos);
			    $i = $strpos+1; # XXX warum +1?
			    $draw_sub->($r);
			    $exp_str_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }
	}

	foreach my $abk (@defs_p_abk) {
# 	    my %category_width;
# 	    my $default_width = get_line_width($abk) || 4;
# 	    #XXX skalieren...
# 	    {
# 		foreach (keys %line_width) {
# 		    if (/^$abk-(.*)/) {
# 			my $cat = $1;
# 			$category_width{$cat} = get_line_width($_, $scale);
# 		    }
# 		}
# 	    }
	    
 	    my $i;
 	    my $restrict = undef; #XXX
 	    my $coordsys = $coord_system_obj->coordsys;
	    my $name_draw = 0;
	    my($name_draw_tag, $name_draw_other);
	    my %no_overlap_label;

	    # XXX Duplikate in plot_point:
	    my $ubahn_length = ($abk eq 'u'
				? do { my(%a) = get_symbol_scale('u');
				       $a{-width}/2 }
				: 0);
	    # ^^^
	    my $xadd_anchor = $xadd_anchor_type->{'u'};
	    my $yadd_anchor = $yadd_anchor_type->{'u'};

	    my $transpose = \&transpose;
	    my $draw_sub = eval $plotpoint_draw_sub;
	    die $@ if $@;
	    
	    foreach my $grid (@grids) {
		if ($exp_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $exp_p{$abk}->{Grid}{$grid} }) {
			if (!$exp_p_drawn{$abk}->{$strpos}) {
			    my $r = $exp_p{$abk}->get($strpos);
			    $i = $strpos+1; # XXX warum +1?
			    $draw_sub->($r);
			    $exp_p_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }
	    plot_symbol($abk);
	}

	my $municipality = 0;
	foreach my $abk (@defs_p_o_abk) {
	    my $type = $abk;
	    my $label_tag = uc($type);
	    my $name_o = $p_name_draw{$abk};
	    my %args;
	    my %no_overlap_label;
	    my @orte_coords_labeling;

	    my $transpose = \&transpose;
	    my $draw_sub = eval $plotorte_draw_sub;
	    die $@ if $@;

	    my $i = 0;

	    foreach my $grid (@grids) {
		if ($exp_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $exp_p{$abk}->{Grid}{$grid} }) {
			if (!$exp_p_drawn{$abk}->{$strpos}) {
			    my $r = $exp_p{$abk}->get($strpos);
			    $i = $strpos+1; # XXX warum +1?
			    $draw_sub->($r);
			    $exp_p_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }
	}
    }

    if ($something_new) {
	restack_delayed();
	delayed_sub(sub {
			$c->itemconfigure('pp', 
					  -capstyle => 'round',
					  -width => 5,
					  -fill => $pp_color, 
					 );
			# die nächsten beiden sind Duplikate
			# auf plotorte()
			# Hier wird nur 'o' behandelt...
			$c->itemconfigure('o',
					  -capstyle => 'round',
					  -width => 5,
					  -fill => '#000080',
					 );
			$c->itemconfigure
			  ('O',
			   -anchor => 'w',
			   -justify => 'left',
			   -fill => '#000080',
			   ($orientation eq 'landscape'
			    ? (-font => get_orte_label_font(2))
			    : ()
			   ),
			  );
		    },
		    -name => 'itemconfigurepp',
		   );
    }
}

warn "Load of BBBikeExp done!";

1;

__END__
