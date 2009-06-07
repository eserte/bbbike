# -*- perl -*-

#
# $Id: BBBikeLazy.pm,v 1.37 2009/06/07 21:07:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# routines for lazy drawing

package BBBikeLazy;

use vars qw($setup_done);

package main;

use Strassen;
use strict;
use vars qw(%lazy_str_drawn %lazy_str %lazy_str_args
	    %lazy_p_drawn %lazy_p %lazy_p_args %lazy_p_subs
	    %lazy_known_grids $lazy_master);
use vars qw($xadd_anchor $yadd_anchor @extra_tags $ignore);
use BBBikeGlobalVars;
use vars qw($XXX_use_old_R_symbol);

# @defs_p_o @defs_p_o_abk
use vars qw(@defs_str @defs_p
	    @defs_str_abk
	    @defs_p_abk
	    @defs_p_subs_abk
	   );

sub BBBikeLazy::bbbikelazy_setup {
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

    $BBBikeLazy::setup_done = 1;
}

sub BBBikeLazy::bbbikelazy_empty_setup {
    @defs_str = ();
    @defs_p = ();
#    @defs_p_o = ();
    @defs_str_abk = map { $_->[0] } @defs_str;
    @defs_p_abk   = map { $_->[0] } @defs_p;
#    @defs_p_o_abk = map { $_->[0] } @defs_p_o;

    $BBBikeLazy::setup_done = 1;
}

# XXX for now "-orig" has to be specified unlike in other functions
# like main::plotstr
sub BBBikeLazy::bbbikelazy_add_data {
    my($type, $abk, $file_or_object, $argsref) = @_;
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
	    $lazy_str{$abk} = $file_or_object;
	} else {
	    $lazy_p{$abk} = $file_or_object;
	}
    }

    if ($type eq 'str') {
	my $def = [$abk, $file];
	push @defs_str, $def;
	push @defs_str_abk, $abk;
	BBBikeLazy::draw_streets($def);
	if (!defined $lazy_master) {
	    $lazy_master = $lazy_str{$abk};
	}
	$lazy_str_args{$abk} = { $argsref && exists $argsref->{Width} ? (Width => $argsref->{Width}) : () };
    } elsif ($type eq 'p') {
	my $def = [$abk, $file];
	push @defs_p, $def;
	push @defs_p_abk, $abk;
	BBBikeLazy::draw_points($def);
	if (!defined $lazy_master) {
	    $lazy_master = $lazy_p{$abk};
	}

	$lazy_p_args{$abk} = {};
	if ($argsref && (exists $argsref->{Width} || exists $argsref->{NameDraw})) {
	    for my $key (qw(Width NameDraw)) {
		if (exists $argsref->{$key}) {
		    $lazy_p_args{$abk}->{$key} = $argsref->{$key};
		}
	    }
	}
    } else {
	die "type has to be either str or p, not $type";
    }

    if ($abk =~ /^L\d+/) {
	if ($type eq 'str') {
	    std_str_binding($abk);
	} elsif ($type eq 'p') {
	    std_p_binding($abk);
	}
    }

    %lazy_known_grids = (); # to force redraw
    BBBikeLazy::bbbikelazy_redraw_current_view();
    $BBBikeLazy::mode = 1;
}

# Hacky because of the non-orig/orig confusion. Otherwise nice:
sub BBBikeLazy::bbbikelazy_add_data_by_subs {
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
# 	BBBikeLazy::draw_streets($def);
# 	if (!defined $lazy_master) {
# 	    $lazy_master = $lazy_str{$abk};
# 	}
    } elsif ($type eq 'p') {
	my $def = [$abk, undef];
	push @defs_p, $def;
	push @defs_p_subs_abk, $abk;
	$lazy_p{$abk} = $nonorig_s;
	BBBikeLazy::draw_points($def);
	$lazy_p{$abk}->make_grid(UseCache => 1, -tomap => $coord_system);
	if (!defined $lazy_master) {
	    $lazy_master = $lazy_p{$abk};
	}
	%{$lazy_p_subs{$abk}} = %subs;
    } else {
	die "type has to be either str or p, not $type";
    }
    %lazy_known_grids = (); # to force redraw
    BBBikeLazy::bbbikelazy_redraw_current_view();
    $BBBikeLazy::mode = 1;
}

sub BBBikeLazy::bbbikelazy_remove_data {
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
	delete $lazy_str_drawn{$abk};
	if (defined $lazy_master && $lazy_master eq $lazy_str{$abk}) {
	    undef $lazy_master;
	}
	delete $lazy_str{$abk};
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
	delete $lazy_p_drawn{$abk};
	if (defined $lazy_master && $lazy_master eq $lazy_p{$abk}) {
	    undef $lazy_master;
	}
	delete $lazy_p{$abk};
	# XXX no! main::plot("p", $abk, -draw => 0);
    } else {
	warn "Unknown abk=$abk";
    }

    if (!defined $lazy_master) {
	warn "XXX master deleted, disable BBBikeLazy mode!!!";
	$BBBikeLazy::mode = 0;
    }
    if (!keys %lazy_p && !keys %lazy_str) {
	$BBBikeLazy::mode = 0;
    }
}

sub BBBikeLazy::draw_streets {
    my $def = shift;
    if (!$lazy_str{$def->[0]}) {
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
	    $lazy_str{$def->[0]} = $new_s;
	} else {
	    $lazy_str{$def->[0]} = new Strassen $def->[1];
	}
    } else {
	$lazy_str{$def->[0]}->reload;
    }
    $lazy_str{$def->[0]}->make_grid(UseCache => 1, -tomap => $coord_system);
    $str_draw{$def->[0]} = 1;
    $str_outline{$def->[0]} = 0;
    if ($def->[0] =~ /^L\d+/) {
	std_str_binding($def->[0]);
    }
}

sub BBBikeLazy::draw_points {
    my $def = shift;
    if (!$lazy_p{$def->[0]}) {
	$lazy_p{$def->[0]} = new Strassen $def->[1];
    } else {
	$lazy_p{$def->[0]}->reload;
    }
    $lazy_p{$def->[0]}->make_grid(UseCache => 1, -tomap => $coord_system);
    $p_draw{$def->[0]} = 1;
    if ($def->[0] =~ /^L\d+/) {
	std_p_binding($def->[0]);
    }
}

sub BBBikeLazy::bbbikelazy_init {
    if (!$BBBikeLazy::setup_done) {
	bbbikelazy_setup();
    }

    %lazy_str_drawn = ();
    %lazy_p_drawn = ();
    %lazy_known_grids = ();
    foreach my $def (@defs_str) {
	BBBikeLazy::draw_streets($def);
    }
    foreach my $def (@defs_p) { #, @defs_p_o) {
	BBBikeLazy::draw_points($def);
    }
#XXX needed here???    make_net(-l_add => 1) if !defined $net and !$no_make_net;

    $lazy_master = $lazy_str{'s'} if !defined $lazy_master;

    BBBikeLazy::bbbikelazy_redraw_current_view();
    $BBBikeLazy::mode = 1;
}

sub BBBikeLazy::bbbikelazy_redraw_current_view {
    my($x1,$y1,$x2,$y2) = $c->get_corners;
    BBBikeLazy::plotstr_on_demand
	    (anti_transpose($x1,$y1),
	     anti_transpose($x2,$y2));
}

sub BBBikeLazy::bbbikelazy_clear {
    %lazy_str_drawn = ();
    %lazy_p_drawn = ();
    %lazy_known_grids = ();
    foreach my $def (@defs_str) {
	delete $lazy_str{$def->[0]};
	$c->delete($def->[0]);
	$str_draw{$def->[0]} = 0;
    }
    foreach my $def (@defs_p) { #, @defs_p_o) {
	delete $lazy_p{$def->[0]};
	$c->delete($def->[0]);
	$p_draw{$def->[0]} = 0;
    }
    $c->delete("pp");

    $BBBikeLazy::mode = 0;
}

# XXX This only works for data which is *changed*, but not added or
# deleted data. The problem is that the grid is not rebuilt, which is
# required to get the information about any new/outdated data. But:
# rebuilding the grids would be so costly, that bbbikelazy_reload would
# be no faster than deleting and adding the whole layer. Still
# searching for a good solution...
#
# Which could be: use a diff (e.g. a modified Strassen::Core::diff_orig).
# The diff output should be used to add/delete items from the grids.
sub BBBikeLazy::bbbikelazy_reload {
    my $redraw_needed = 0;

    foreach my $def (@defs_str) {
	my $abk = $def->[0];
	next if !$lazy_str{$abk}; # XXX should not happen, but it happens
	if (!$lazy_str{$abk}->is_current) {
	    warn "Reload str-$abk...\n";
	    $lazy_str{$abk}->reload;
	    $lazy_str_drawn{$abk} = {};
	    $c->delete($abk);
	    $redraw_needed++;
	}
    }
    foreach my $def (@defs_p) {
	my $abk = $def->[0];
	next if !$lazy_p{$abk}; # XXX should not happen, but it happens
	if (!$lazy_p{$abk}->is_current) {
	    warn "Reload p-$abk...\n";
	    $lazy_p{$abk}->reload;
	    $lazy_p_drawn{$abk} = {};
	    $c->delete($abk);
	    $redraw_needed++;
	}
    }

    if ($redraw_needed) {
	%lazy_known_grids = ();
	BBBikeLazy::bbbikelazy_redraw_current_view();
    }
}

sub BBBikeLazy::bbbikelazy_reload_all {
    bbbikelazy_clear();
    %lazy_str = ();
    %lazy_p = ();
    bbbikelazy_init();
}

sub BBBikeLazy::plotstr_on_demand {
    my($x1, $y1, $x2, $y2) = @_;

    return if !$lazy_master;

    my(@grids) = $lazy_master->get_new_grids
      ($x1, $y1, $x2, $y2,
       KnownGrids => \%lazy_known_grids);
    my $something_new = 0;
    my $places_new = 0;
    if (@grids) {
	my $need_street_name_experiment_init = 1;
	foreach my $abk (@defs_str_abk) {
	    do { warn "XXX should not happen, but it happens... <$abk> does not exist in \$lazy_str, but it is referenced in \@defs_str_abk"; next } if !$lazy_str{$abk}; # XXX should not happen, but it happens
	    my $do_street_name_experiment = 0;
	    if ($str_name_draw{$abk} && $abk =~ m{^(s|l|fz)$} && eval {
		require SRTShortcuts;
		SRTShortcuts::street_name_experiment_preinit();
		SRTShortcuts::street_name_experiment_init();
		SRTShortcuts::street_name_experiment_init_strassen($lazy_str{$abk}, $abk.'-label');
		1;
	    }) {
		$do_street_name_experiment = 1;
	    }
	    my $default_width = $lazy_str_args{$abk}->{Width} || get_line_width($abk) || 4;
	    my %category_width = main::_set_category_width($abk);

	    my $i;
	    my $restrict = undef; #XXX
	    my $coordsys = $coord_system_obj->coordsys;
	    my $use_stippleline = decide_stippleline($abk);
	    my $label_spaceadd = ''; # XXX?
	    my $transpose = \&transpose;
	    my $conv = $lazy_str{$abk}->get_conversion;
	    my $draw_sub;
	    local $str_name_draw{$abk} = $str_name_draw{$abk};
	    if ($do_street_name_experiment) {
		# XXX some duplication of code in street_name_experiment()
		my $str_sub = eval $plotstr_draw_sub;
		my $label_sub = sub { my $rec = shift;
				      my $cat = $rec->[Strassen::CAT()];
				      return if $cat =~ m{::igndisp};
				      return if ($rec->[Strassen::NAME()] =~ m{\s+-\s+}); # ignore everything looking like "A - B"
				      my $use_bold = 1 if $cat =~ m{^(H|HH|B)$};
				      SRTShortcuts::street_name_experiment_one($rec->[Strassen::NAME()], $rec->[Strassen::COORDS()], $use_bold);
				  };
		$draw_sub = sub { my $r = shift;
				  $str_sub->($r);
				  $label_sub->($r);
			      };
		$str_name_draw{$abk} = 0;
	    } else {
		$draw_sub = eval $plotstr_draw_sub;
	    }
	    die $@ if $@;

	    foreach my $grid (@grids) {
		if ($lazy_str{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for str/$abk: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $lazy_str{$abk}->{Grid}{$grid} }) {
			if (!$lazy_str_drawn{$abk}->{$strpos}) {
			    my $r = $lazy_str{$abk}->get($strpos);
			    $i = $strpos;
			    $draw_sub->($r);
			    $lazy_str_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }

	    if ($something_new && $layer_active_color{$abk}) {
		$c->itemconfigure($abk, -activefill => $layer_active_color{$abk});
	    }

	    undef $draw_sub;
	}

	foreach my $abk (@defs_p_abk) {
	    next if $abk eq 'o';
	    next if !$lazy_p{$abk}; # XXX should not happen, but it happens
# 	    my %category_width;
 	    my $default_width = $lazy_p_args{$abk}->{Width} || 4;
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
	    my $name_draw = $lazy_p_args{$abk}->{NameDraw} || $p_name_draw{$abk};
	    # XXX Duplikate in plot_point: vvv
	    my $name_draw_tag = "$abk-label";
	    my $name_draw_other = ($name_draw_tag =~ /^[ubr]-label$/
				   ? [qw(u-label b-label r-label)]
				   : $name_draw_tag);
	    # XXX ^^^
	    my %no_overlap_label;
	    my $no_overlap_label;

	    # XXX Duplikate in plot_point:
	    my $rbahn_length = ($abk eq 'r' && $XXX_use_old_R_symbol
				? do { my(%a) = get_symbol_scale('r');
				       $a{-width}/2 }
				: 0);
	    # ^^^
	    my $xadd_anchor = $xadd_anchor_type->{'u'};
	    my $yadd_anchor = $yadd_anchor_type->{'u'};
	    my $label_spaceadd = ''; # XXX?

	    my $transpose = \&transpose;
	    my $conv = $lazy_p{$abk}->get_conversion;
	    my $draw_sub = eval $plotpoint_draw_sub;
	    die $@ if $@;

	    foreach my $grid (@grids) {
		if ($lazy_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for p/$abk: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $lazy_p{$abk}->{Grid}{$grid} }) {
			if (!$lazy_p_drawn{$abk}->{$strpos}) {
			    my $r = $lazy_p{$abk}->get($strpos);
			    $i = $strpos;
			    $draw_sub->($r);
			    $lazy_p_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }
	    config_symbol($c, $abk);

	    undef $draw_sub;
	}

	if (0) {
	    my $municipality = 0;
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
		my $conv = $lazy_p{$abk}->get_conversion;
		my $draw_sub = eval $plotorte_draw_sub;
		die $@ if $@;

		my $i = 0;

		foreach my $grid (@grids) {
		    if ($lazy_p{$abk}->{Grid}{$grid}) {
			warn "Drawing new grid: $grid\n" if $verbose;
			$something_new++;
			foreach my $strpos (@{ $lazy_p{$abk}->{Grid}{$grid} }) {
			    if (!$lazy_p_drawn{$abk}->{$strpos}) {
				my $r = $lazy_p{$abk}->get($strpos);
				$i = $strpos+1; # XXX warum +1?
				$draw_sub->($r);
				$lazy_p_drawn{$abk}->{$strpos}++;
			    }
			}
		    }
		}

		undef $draw_sub;
	    }
	} else {
	    foreach my $abk (@defs_p_abk) {
		next if $abk ne 'o';
		next if !$lazy_p{$abk};	# should not happen, but it happens
		plotplaces_pre_a(-type => $abk,
				 -strdata => $lazy_p{$abk},
				);
		plotplaces_pre2();
		my $i = 0;

		foreach my $grid (@grids) {
		    if ($lazy_p{$abk}->{Grid}{$grid}) {
			warn "Drawing new grid: $grid\n" if $verbose;
			foreach my $strpos (@{ $lazy_p{$abk}->{Grid}{$grid} }) {
			    if (!$lazy_p_drawn{$abk}->{$strpos}) {
				my $r = $lazy_p{$abk}->get($strpos);
				plotplaces_draw($r, $strpos+1);
				$lazy_p_drawn{$abk}->{$strpos}++;
				$places_new++;
			    }
			}
		    }
		}
	    }
	}

	foreach my $abk (@defs_p_subs_abk) {
	    my $draw_sub = $lazy_p_subs{$abk}->{draw};
	    my $i = 0;
	    foreach my $grid (@grids) {
		my($gx,$gy) = split /,/, $grid;
		$gx-=5; $gy-=0;
		warn $grid; $grid = "$gx,$gy"; warn $grid;
		if ($lazy_p{$abk}->{Grid}{$grid}) {
		    warn "Drawing new grid for p/$abk: $grid\n" if $verbose;
		    $something_new++;
		    foreach my $strpos (@{ $lazy_p{$abk}->{Grid}{$grid} }) {
			if (!$lazy_p_drawn{$abk}->{$strpos}) {
			    my $r = $lazy_p{$abk}->get($strpos);
			    $i = $strpos+1; # XXX warum +1?
			    $draw_sub->($r);
			    $lazy_p_drawn{$abk}->{$strpos}++;
			}
		    }
		}
	    }
	    # XXX oder später?
	    $lazy_p_subs{$abk}->{post_draw}->()
		if $lazy_p_subs{$abk}->{post_draw};
	}
    }

    if ($something_new || $places_new) {
	restack_delayed();
	delayed_sub(sub {
			$c->itemconfigure('pp',
					  -capstyle => 'round',
					  -width => 5,
					 );
			pp_color();
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
    my($place_category, $name_o, $no_overlap_label,
       $progress_hack, $diffed_orte,
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
	    if ($main::lazy_p{$type}) {
		bbbikelazy_remove_data("p", $type);
	    }
	    return 0;
	}

	$orte = _get_orte_obj($type);

	$lazy = defined $args{-lazy} ? $args{-lazy} : $lazy_plot;
	if ($std && $lazy) {
	    bbbikelazy_add_data("p", $type, $orte);
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
	    $transpose = ($show_overview_mode eq 'region'
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
	$no_overlap_label = (exists $args{NoOverlapLabel}
			  ? $args{NoOverlapLabel} : $no_overlap_label{$type});
	$progress_hack = ($name_o && $no_overlap_label);

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

	if ($no_overlap_label) {
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
	$i = shift;
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
		     -tags => [$type, "$xx,$yy", $fullname, $label_tag."P$cat", $type."-".($i-1)],
		    );
	    }
	    if ($name_o) {
		my $text = ($args{Shortname}
			    ? $name
			    : $fullname);
		my(@tags) = ($label_tag, "$label_tag$cat", $label_tag."-".($i-1));
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
		} elsif ($no_overlap_label && !$municipality) {
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
	    if ($no_overlap_label) {
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
	    if (!$no_overlap_label && !$municipality &&
		!$do_outline_text) {
		$c->itemconfigure($label_tag,
				  -anchor => 'w', -justify => 'left');
	    }
	    if ($municipality) {
		$c->itemconfigure($label_tag, -fill => '#7e7e7e');
	    } elsif (!$do_outline_text) {
		$c->itemconfigure($label_tag, -fill => '#000080');
	    }
	    if ($orientation eq 'landscape' &&
		!$do_outline_text) {
		foreach my $category (MIN_ORT_CAT() .. MAX_ORT_CAT()) {
		    $c->itemconfigure
			("$label_tag$category",
			 -font => get_orte_label_font($category));
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
warn "Load of BBBikeLazy done!";

1;

__END__
