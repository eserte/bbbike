# -*- perl -*-

#
# $Id: BBBikeExp.pm,v 1.22 2004/06/10 23:01:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# BBBike-Experimente

package BBBikeExp;

use vars qw($setup_done);

package main;

use Strassen;
use strict;
use vars qw(%exp_str_drawn %exp_str
	    %exp_p_drawn %exp_p %exp_p_subs
	    %exp_known_grids $exp_master);
use vars qw($xadd_anchor $yadd_anchor @extra_tags $ignore);
use BBBikeGlobalVars;

# @defs_p_o @defs_p_o_abk
use vars qw(@defs_str @defs_p
	    @defs_str_abk
	    @defs_p_abk
	    @defs_p_subs_abk
	   );

sub BBBikeExp::bbbikeexp_setup {
    @defs_str = ();
    @defs_p = ();
#    @defs_p_o = ();
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
			     ['hs', 'handicap_s'],
			     ['hl', 'handicap_l'],
			    );
		@defs_p = (['u', 'ubahnhof'],
			   ['b', 'sbahnhof'],
			   ['r', 'rbahnhof'],
			   ['lsa', 'ampeln'],
			  );
#XXX		@defs_p_o = (['o', 'orte']); # Extra-Wurst wegen plotorte()
	    }

	}
    } elsif ($coord_system eq 'berlinmap') {
	@defs_str = (['s', 'strassen-orig'],
		     ['w', 'wasserstrassen-orig'],
		     ['l', 'landstrassen-orig'],
		     ['f', 'flaechen-orig'],
		     ['u', 'ubahn-orig'],
		     ['b', 'sbahn-orig'],
		     ['r', 'rbahn-orig'],
		     ['qs', 'qualitaet_s-orig'],
		     ['hs', 'handicap_s-orig'],
		    );
	@defs_p = (['u', 'ubahnhof-orig'],
		   ['b', 'sbahnhof-orig'],
		   #['r', 'rbahnhof'],
		   ['lsa', 'ampeln-orig'],
		  );
	#@defs_p_o = (['o', 'orte-orig']); # Extra-Wurst wegen plotorte()
    } elsif ($coord_system eq 'brbmap') { # XXX brbmap geht noch nicht...
	@defs_str = (['l', 'landstrassen-orig'],
		     ['w', 'wasserumland-orig'],
		     ['f', 'flaechen-orig'],
		     ['r', 'rbahn-orig'],
		     ['ql', 'qualitaet_l-orig'],
		     ['hl', 'handicap_l-orig'],
		    );
#	@defs_p_o = (['o', 'orte-orig']); # Extra-Wurst wegen plotorte()
	@defs_p = (['o', 'orte-orig']);
    } else {
	die "Nothing to do for coord_system $coord_system";
    }
    @defs_str_abk = map { $_->[0] } @defs_str;
    @defs_p_abk   = map { $_->[0] } @defs_p;
#    @defs_p_o_abk = map { $_->[0] } @defs_p_o;

    $BBBikeExp::setup_done = 1;
}

sub BBBikeExp::bbbikeexp_empty_setup {
    @defs_str = ();
    @defs_p = ();
#    @defs_p_o = ();
    @defs_str_abk = map { $_->[0] } @defs_str;
    @defs_p_abk   = map { $_->[0] } @defs_p;
#    @defs_p_o_abk = map { $_->[0] } @defs_p_o;

    $BBBikeExp::setup_done = 1;
}

# XXX for now "-orig" has to be specified unlike in other functions
# like main::plotstr
sub BBBikeExp::bbbikeexp_add_data {
    my($type, $abk, $file_or_object) = @_;
    my $file;
    if (!UNIVERSAL::isa($file_or_object, "Strassen")) {
	$file = $file_or_object;
	if (!defined $file) {
	    if ($type eq 'str' && $str_file{$abk}) {
		$file = $str_file{$abk};
	    } elsif ($type eq 'p' && $p_file{$abk}) {
		$file = $p_file{$abk};
	    } else {
		die "No file for $type/$abk defined";
	    }
	} else {
	    if ($type eq 'str') {
		$str_file{$abk} = $file;
	    } else {
		$p_file{$abk} = $file;
	    }
	}
    } else {
	($file) = $file_or_object->file; # XX what about multiple files
	if ($type eq 'str') {
	    $exp_str{$abk} = $file_or_object;
	} else {
	    $exp_p{$abk} = $file_or_object;
	}
    }

    if ($type eq 'str') {
	my $def = [$abk, $file];
	push @defs_str, $def;
	push @defs_str_abk, $abk;
	BBBikeExp::draw_streets($def);
	if (!defined $exp_master) {
	    $exp_master = $exp_str{$abk};
	}
    } elsif ($type eq 'p') {
	my $def = [$abk, $file];
	push @defs_p, $def;
	push @defs_p_abk, $abk;
	BBBikeExp::draw_points($def);
	if (!defined $exp_master) {
	    $exp_master = $exp_p{$abk};
	}
    } else {
	die "type has to be either str or p, not $type";
    }
    %exp_known_grids = (); # to force redraw
    BBBikeExp::bbbikeexp_redraw_current_view();
    $BBBikeExp::mode = 1;
}

# Hacky because of the non-orig/orig confusion. Otherwise nice:
sub BBBikeExp::bbbikeexp_add_data_by_subs {
    my($type, $abk, %subs) = @_;
    my($s, $nonorig_s);
    if ($subs{init}) {
	($s, $nonorig_s) = $subs{init}->();
    }
    if ($type eq 'str') {
	die "NYI";
# 	my $def = [$abk, $file];
# 	push @defs_str, $def;
# 	push @defs_str_abk, $abk;
# 	BBBikeExp::draw_streets($def);
# 	if (!defined $exp_master) {
# 	    $exp_master = $exp_str{$abk};
# 	}
    } elsif ($type eq 'p') {
	my $def = [$abk, undef];
	push @defs_p, $def;
	push @defs_p_subs_abk, $abk;
	$exp_p{$abk} = $nonorig_s;
	BBBikeExp::draw_points($def);
	$exp_p{$abk}->make_grid(UseCache => 1);
	if (!defined $exp_master) {
	    $exp_master = $exp_p{$abk};
	}
	%{$exp_p_subs{$abk}} = %subs;
    } else {
	die "type has to be either str or p, not $type";
    }
    %exp_known_grids = (); # to force redraw
    BBBikeExp::bbbikeexp_redraw_current_view();
    $BBBikeExp::mode = 1;
}

sub BBBikeExp::bbbikeexp_remove_data {
    my($type, $abk) = @_;
    if ($type eq 'str') {
	my $i = 0;
	for (@defs_str) {
	    if ($_->[0] eq $abk) {
		splice @defs_str, $i, 1;
		splice @defs_str_abk, $i, 1;
		last;
	    }
	    $i++;
	}
	$str_draw{$abk} = 0;
	delete $exp_str_drawn{$abk};
	if (defined $exp_master && $exp_master eq $exp_str{$abk}) {
	    undef $exp_master;
	}
	delete $exp_str{$abk};
	# XXX no! main::plot("str", $abk, -draw => 0);
    } elsif ($type eq 'p') {
	my $i = 0;
	for (@defs_p) {
	    if ($_->[0] eq $abk) {
		splice @defs_p, $i, 1;
		splice @defs_p_abk, $i, 1;
		last;
	    }
	    $i++;
	}
	$p_draw{$abk} = 0;
	delete $exp_p_drawn{$abk};
	if (defined $exp_master && $exp_master eq $exp_p{$abk}) {
	    undef $exp_master;
	}
	delete $exp_p{$abk};
	# XXX no! main::plot("p", $abk, -draw => 0);
    } else {
	warn "Unknown abk=$abk";
    }

    if (!defined $exp_master) {
	warn "XXX master deleted, disable BBBikeExp mode!!!";
	$BBBikeExp::mode = 0;
    }
    if (!keys %exp_p && !keys %exp_str) {
	$BBBikeExp::mode = 0;
    }
}

sub BBBikeExp::draw_streets {
    my $def = shift;
    if (!$exp_str{$def->[0]}) {
	# XXX make better test
	if ($def->[1] eq 'landstrassen-orig') {
	    my $new_s = Strassen->new;
	    $new_s->{RebuildCode} = sub {
		$new_s->{Data} = [];
		my $s = Strassen->new($def->[1]);
		$new_s->{Modtime} = $s->{Modtime};
		$s->init;
		while(1) {
		    my $r = $s->next;
		    last if !@{ $r->[Strassen::COORDS()] };
		    for my $c (@{ $r->[Strassen::COORDS()] }) {
			$c =~ s/^B//;
		    }
		    $new_s->push($r);
		}
		$new_s;
	    };
	    $new_s->{DependentFiles} = [$def->[1]];
	    $new_s->{RebuildCode}->();
	    $exp_str{$def->[0]} = $new_s;
	} else {
	    $exp_str{$def->[0]} = new Strassen $def->[1];
	}
    } else {
	$exp_str{$def->[0]}->reload;
    }
    $exp_str{$def->[0]}->make_grid(UseCache => 1);
    $str_draw{$def->[0]} = 1;
    $str_outline{$def->[0]} = 0;
    if ($def->[0] =~ /^L\d+/) {
	std_str_binding($def->[0]);
    }
}

sub BBBikeExp::draw_points {
    my $def = shift;
    if (!$exp_p{$def->[0]}) {
	$exp_p{$def->[0]} = new Strassen $def->[1];
    } else {
	$exp_p{$def->[0]}->reload;
    }
    $exp_p{$def->[0]}->make_grid(UseCache => 1);
    $p_draw{$def->[0]} = 1;
    if ($def->[0] =~ /^L\d+/) {
	std_p_binding($def->[0]);
    }
}

sub BBBikeExp::bbbikeexp_init {
    if (!$BBBikeExp::setup_done) {
	bbbikeexp_setup();
    }

    %exp_str_drawn = ();
    %exp_p_drawn = ();
    %exp_known_grids = ();
    foreach my $def (@defs_str) {
	BBBikeExp::draw_streets($def);
    }
    foreach my $def (@defs_p) { #, @defs_p_o) {
	BBBikeExp::draw_points($def);
    }
#XXX needed here???    make_net(-l_add => 1) if !defined $net and !$no_make_net;

    $exp_master = $exp_str{'s'} if !defined $exp_master;

    BBBikeExp::bbbikeexp_redraw_current_view();
    $BBBikeExp::mode = 1;
}

sub BBBikeExp::bbbikeexp_redraw_current_view {
    my($x1,$y1,$x2,$y2) = $c->get_corners;
    BBBikeExp::plotstr_on_demand
	    (anti_transpose($x1,$y1),
	     anti_transpose($x2,$y2));
}

sub BBBikeExp::bbbikeexp_clear {
    %exp_str_drawn = ();
    %exp_p_drawn = ();
    %exp_known_grids = ();
    foreach my $def (@defs_str) {
	delete $exp_str{$def->[0]};
	$c->delete($def->[0]);
	$str_draw{$def->[0]} = 0;
    }
    foreach my $def (@defs_p) { #, @defs_p_o) {
	delete $exp_p{$def->[0]};
	$c->delete($def->[0]);
	$p_draw{$def->[0]} = 0;
    }
    $c->delete("pp");

    $BBBikeExp::mode = 0;
}

sub BBBikeExp::bbbikeexp_reload {
    my $redraw_needed = 0;

    foreach my $def (@defs_str) {
	my $abk = $def->[0];
	if (!$exp_str{$abk}->is_current) {
	    warn "Reload str-$abk...\n";
	    $exp_str{$abk}->reload;
	    $exp_str_drawn{$abk} = {};
	    $c->delete($abk);
	    $redraw_needed++;
	}
    }
    foreach my $def (@defs_p) {
	my $abk = $def->[0];
	if (!$exp_p{$abk}->is_current) {
	    warn "Reload p-$abk...\n";
	    $exp_p{$abk}->reload;
	    $exp_p_drawn{$abk} = {};
	    $c->delete($abk);
	    $redraw_needed++;
	}
    }

    if ($redraw_needed) {
	%exp_known_grids = ();
	BBBikeExp::bbbikeexp_redraw_current_view();
    }
}

sub BBBikeExp::bbbikeexp_reload_all {
    bbbikeexp_clear();
    %exp_str = ();
    %exp_p = ();
    bbbikeexp_init();
}

sub BBBikeExp::plotstr_on_demand {
    my($x1, $y1, $x2, $y2) = @_;

    return if !$exp_master;

    my(@grids) = $exp_master->get_new_grids
      ($x1, $y1, $x2, $y2,
       KnownGrids => \%exp_known_grids);
    my $something_new = 0;
    my $places_new = 0;
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
	    if (exists $line_dash{$abk}) {
		if ($Tk::VERSION >= 800.016) {
		    $use_stippleline = 2; # new dash code
		} else {
		    $use_stippleline = 1;
		    require Tk::StippleLine;
		}
	    }

	    my $label_spaceadd = ''; # XXX?
	    my $transpose = \&transpose;
	    my $conv = $exp_str{$abk}->get_conversion;
	    my $draw_sub = eval $plotstr_draw_sub;
	    die $@ if $@;

	    foreach my $grid (@grids) {
		if ($exp_str{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for str/$abk: $grid\n" if $verbose;
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
	    next if $abk eq 'o';
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
	    my $label_spaceadd = ''; # XXX?

	    my $transpose = \&transpose;
	    my $conv = $exp_p{$abk}->get_conversion;
	    my $draw_sub = eval $plotpoint_draw_sub;
	    die $@ if $@;

	    foreach my $grid (@grids) {
		if ($exp_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for p/$abk: $grid\n" if $verbose;
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
	    plot_symbol($c, $abk);
	}

	if (0) {
	my $municipality = 0;
#	foreach my $abk (@defs_p_o_abk) {
	foreach my $abk (@defs_p_abk) {
	    next if $abk ne 'o';
	    my $type = $abk;
	    my $label_tag = uc($type);
	    my $name_o = $p_name_draw{$abk};
	    my %args;
	    my %no_overlap_label;
	    my @orte_coords_labeling;
	    my $do_outline_text = 0;
 	    my $coordsys = $coord_system_obj->coordsys;

	    my $transpose = \&transpose;
	    my $conv = $exp_p{$abk}->get_conversion;
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
    } else {
#	foreach my $abk (@defs_p_o_abk) {
	foreach my $abk (@defs_p_abk) {
	    next if $abk ne 'o';
	    plotplaces_pre_a(-type => $abk,
			     -strdata => $exp_p{$abk},
			    );
	    plotplaces_pre2();
	    my $i = 0;

	    foreach my $grid (@grids) {
		if ($exp_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid: $grid\n" if $verbose;
		    #XXX del: $something_new++;
		    foreach my $strpos (@{ $exp_p{$abk}->{Grid}{$grid} }) {
			if (!$exp_p_drawn{$abk}->{$strpos}) {
			    my $r = $exp_p{$abk}->get($strpos);
			    $i = $strpos+1; # XXX warum +1?
			    plotplaces_draw($r);
			    $exp_p_drawn{$abk}->{$strpos}++;
			    $places_new++;
			}
		    }
		}
	    }
	}
    }

	foreach my $abk (@defs_p_subs_abk) {
	    my $draw_sub = $exp_p_subs{$abk}->{draw};
	    my $i = 0;
	    foreach my $grid (@grids) {
		my($gx,$gy) = split /,/, $grid;
		$gx-=5; $gy-=0;
		warn $grid; $grid = "$gx,$gy"; warn $grid;
		if ($exp_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for p/$abk: $grid\n" if $verbose;
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
	    # XXX oder später?
	    $exp_p_subs{$abk}->{post_draw}->()
		if $exp_p_subs{$abk}->{post_draw};
	}
    }

    if ($something_new || $places_new) {
	restack_delayed();
	delayed_sub(sub {
			$c->itemconfigure('pp',
					  -capstyle => 'round',
					  -width => 5,
					  -fill => $pp_color,
					 );
			if(0) {
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
		    } elsif ($places_new) {
			plotplaces_post();
}
		    },
		    -name => 'itemconfigurepp',
		   );
    }
}

# Zeichnet Orte --- next generation
{
    my $c = $c;
    my($std, $transpose, $municipality, $type, $label_tag, $orte, $lazy,
       $coordsys, %args);
    my $i;
    my($place_category, $name_o, $progress_hack, $diffed_orte,
       @orte_coords_labeling, $next_meth, $anzahl_eindeutig, $do_outline_text,
       $conv);

    sub plotplaces_pre {
	(%args) = @_;

	$type         = $args{-type} || 'o';
	$label_tag    = uc($type);
	if (exists $args{Canvas}) {
	    $c = $args{Canvas};
	    $std = 0;
	} else {
	    $std = 1;
	}

	# evtl. alte Koordinaten löschen
	if (!$args{FastUpdate}) {
	    $c->delete($type);
	    $c->delete($label_tag);
	}

	delete $pending{"replot-p-$type"};

	if ($std && !$p_draw{$type}) {
	    undef $p_obj{$type};
	    if ($main::exp_p{$type}) {
		bbbikeexp_remove_data("p", $type);
	    }
	    return 0;
	}

	$orte = _get_orte_obj($type);

	$lazy = defined $args{-lazy} ? $args{-lazy} : $lazy_plot;
	if ($std && $lazy) {
	    bbbikeexp_add_data("p", $type, $orte);
	    return 0;
	}

	1;
    }

    sub plotplaces_pre_a {
	my(%args) = @_;
	$type = $args{-type} || 'o';
	$label_tag = uc($type);
	$orte = $args{-strdata};
    }

    sub plotplaces_pre2 {
	if (exists $args{Canvas}) {
	    $transpose = ($show_overview_mode eq 'brb'
			  ? \&transpose_small
			  : \&transpose_medium);
	} else {
	    $transpose = \&transpose;
	}

	$municipality = $args{-municipality};

	$coordsys = $coord_system_obj->coordsys;

	$place_category = (exists $args{PlaceCategory}
			   ? $args{PlaceCategory} : $place_category);
	$name_o        = (exists $args{NameDraw}
			  ? $args{NameDraw}     : $p_name_draw{$type});
	$progress_hack = ($name_o && $no_overlap_label{$type});

	$diffed_orte = 0;
	if (($edit_mode || $edit_normal_mode) && $args{FastUpdate}) {
	    my($new_orte, $todelref) = $orte->diff_orig(-clonefile => 1);
	    if (!defined $new_orte) {
		warn "Not using diff output" if $verbose;
		$c->delete($type); # evtl. alte Koordinaten löschen
		$c->delete($label_tag);
	    } else {
		warn "Using diff output" if $verbose;
		# XXX not used due to lack of tag $type-$i
		#foreach (@$todelref) {
		#    $c->delete("$type-$_");
		#}
		$orte = $new_orte;
		$diffed_orte = 1;
	    }
	}

	if ($no_overlap_label{$type}) {
	    $orte->init;
	    $next_meth = 'next';
	} else {
	    # in diesem Fall sollten die größeren Orte _später_ d.h. über
	    # den kleineren gezeichnet werden
	    $orte->set_last;
	    $next_meth = 'prev';
	}
	$anzahl_eindeutig = $orte->count;
	$do_outline_text = $do_outline_text{$type};

	$conv = $orte->get_conversion;

	$i = 0; # counter
    }

    sub plotplaces_draw {
	my $ret = shift;
	my $cat = $ret->[Strassen::CAT];
	my($name, $add) = split(/\|/, $ret->[Strassen::NAME]);
	my($xx,$yy);
	$_ = $ret->[Strassen::COORDS][0];
	$_ = $conv->($_) if $conv;

	# XXX duplicated from $parse_coords_code
	if (!$edit_mode) {
	    ($xx, $yy) = split /,/, $_;
	} elsif ($edit_mode &&
		 /([A-Za-z]+)?(-?[\d\.]+),(-?[\d\.]+)$/) {
	    # XXX Verwendung von data/BASE (hier und überall)
	    my $this_coordsys = (defined $1 ? $1 : '');
	    if ($this_coordsys eq $coordsys ||
		(!($this_coordsys ne '' || $coordsys ne 'B'))) {
		($xx, $yy) = ($2, $3);
	    } else {
		# the hard way: convert it
		$this_coordsys = 'B' if $this_coordsys eq '';
		($xx,$yy) = $Karte::map_by_coordsys{$this_coordsys}->map2map($coord_system_obj, $2, $3);
	    }
	} else {
	    return;
	}
	# ^^^

	if (defined $xx) {
	    my($tx, $ty) = $transpose->($xx, $yy);
	    my $fullname = ($add ? $name . " " . $add : $name);
	    return if ($place_category && $place_category ne "auto" && $cat < $place_category);
	    my $point_item;
	    if (!$municipality) {
		$point_item = $c->createLine
		    ($tx, $ty, $tx, $ty,
		     -tags => [$type, $fullname, $label_tag."P$cat"],
		    );
	    }
	    if ($name_o) {
		my $text = ($args{Shortname}
			    ? $name
			    : $fullname);
		my(@tags) = ($label_tag, "$label_tag$cat");
		if ($orientation eq 'portrait' && $Tk::VERSION >= 800) {
		    require Tk::RotFont;
		    # XXX geht nicht...
		    Tk::RotFont::createRotText
			    ($c, $tx, $ty-4,
			     -text => $text,
			     -rot => 3.141592653/2,
			     #-font => get_orte_label_font($cat),
			     -font => $rot_font_sub->(100+$cat*12),
			     -tags => \@tags,
			    );
		} elsif ($no_overlap_label{$type} && !$municipality) {
		    push(@orte_coords_labeling,
			 [$text, $tx, $ty, $cat, $point_item]);
		} else {
		    if ($do_outline_text) {
			outline_text
			    ($c,
			     $tx+4,
			     $ty,
			     -text => $text,
			     -tags => \@tags,
			     -anchor => 'w',
			     -justify => 'left',
			     -fill => '#000080',
			     -font => get_orte_label_font($cat),
			    );
		    } else {
			$c->createText($tx, $ty,
				       -text => $label_spaceadd{'o'} . $text,
				       -tags => \@tags,
				      );
		    }
		}
	    }
	}
    }

    sub plotplaces_post {
	$c->itemconfigure($type,
			  -capstyle => $capstyle_round,
			  -width => 5,
			  -fill => '#000080',
			 );
	if ($name_o) {
	    if ($no_overlap_label{$type}) {
		# nach Kategorie sortieren
		@orte_coords_labeling
		  = sort { $b->[3] <=> $a->[3] } @orte_coords_labeling;
		my $i = 0;
		foreach my $ort_def (@orte_coords_labeling) {
		    $progress->Update($i/$anzahl_eindeutig*.5+0.5)
		      if $i % 80 == 0;
		    $i++;
		    my($text, $tx, $ty, $cat, $point_item) = @$ort_def;
		    my $font = get_orte_label_font($cat);
		    my(@tags) = ($label_tag, "$label_tag$cat");
		    if (!draw_text_intelligent($c, $tx, $ty,
					       -text => $text,
					       -font => $font,
					       -tags => \@tags,
					       -abk  => $label_tag,
					      )) {
			if ($cat <= $place_category+1) {
			    $c->delete($point_item);
			} else {
			    my $anchor = 'w';
			    $c->createText
			      ($tx+$xadd_anchor_type->{'o'}{$anchor},
			       $ty+$yadd_anchor_type->{'o'}{$anchor},
			       -text => $text,
			       -font => $font,
			       -tags => \@tags,
			       -anchor => $anchor,
			       -justify => 'left',
			      );
			}
		    }
		}
	    }
	    if (!$no_overlap_label{$type} && !$municipality &&
		!$do_outline_text) {
		$c->itemconfigure($label_tag,
				  -anchor => 'w', -justify => 'left');
	    }
	    if ($orientation eq 'landscape' &&
		!$do_outline_text) {
		$c->itemconfigure($label_tag,
				  -font => get_orte_label_font(2));
	    }
	    if ($municipality) {
		$c->itemconfigure($label_tag, -fill => '#7e7e7e');
	    } elsif (!$do_outline_text) {
		$c->itemconfigure($label_tag, -fill => '#000080');
	    }
	    if ($orientation eq 'landscape' &&
		!$do_outline_text) {
		unless ($args{'AllSmall'}) {
		    # wichtigere Orte bekommen eine größere Schrift
		    foreach my $category (3, 4, 5, 6) {
			$c->itemconfigure
			  ("$label_tag$category",
			   -font => get_orte_label_font($category));
		    }
		}
	    }
	}

	if (!($edit_mode || $edit_normal_mode) && !$municipality) {
	    change_place_visibility($c);
	}

	if (($edit_mode || $edit_normal_mode) and !$diffed_orte) {
	    warn "Try to copy original data" if $verbose;
	    my $r = $orte->copy_orig;
	    warn "Returned $r" if $verbose;
	}
    }

    sub plotplaces {
	my(%args) = @_;

	my $ret = plotplaces_pre(%args);
	return if !$ret;

	destroy_delayed_restack();
	IncBusy($top);
	$progress->Init(-dependents => $c,
			-label => 'orte');
	eval {
	    plotplaces_pre2();

	    while(1) {
		my $ret = $orte->$next_meth();
		last if !@{$ret->[Strassen::COORDS]};
		$progress->Update($i/$anzahl_eindeutig*($progress_hack ? 0.5 : 1))
		    if $i % 80 == 0;
		$i++;
		plotplaces_draw($ret);
	    }

	    plotplaces_post();

	    if ($std) {
		restack_delayed();
	    }
	};
	if ($@) {
	    status_message($@, 'err');
	}
	$progress->Finish;
	DecBusy($top);
    }
}
warn "Load of BBBikeExp done!";

1;

__END__
