# -*- perl -*-

#
# $Id: BBBikeExp.pm,v 1.19 2004/02/13 22:13:01 eserte Exp $
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
	    %exp_p_drawn %exp_p
	    %exp_known_grids $exp_master);
use vars qw($xadd_anchor $yadd_anchor @extra_tags $ignore);
use BBBikeGlobalVars;

use vars qw(@defs_str @defs_p @defs_p_o
	    @defs_str_abk
	    @defs_p_abk
	    @defs_p_o_abk);

sub BBBikeExp::bbbikeexp_setup {
    @defs_str = ();
    @defs_p = ();
    @defs_p_o = ();
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
		@defs_p_o = (['o', 'orte']); # Extra-Wurst wegen plotorte()
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
	@defs_p_o = (['o', 'orte-orig']); # Extra-Wurst wegen plotorte()
    } else {
	die "Nothing to do for coord_system $coord_system";
    }
    @defs_str_abk = map { $_->[0] } @defs_str;
    @defs_p_abk   = map { $_->[0] } @defs_p;
    @defs_p_o_abk = map { $_->[0] } @defs_p_o;

    $BBBikeExp::setup_done = 1;
}

sub BBBikeExp::bbbikeexp_empty_setup {
    @defs_str = ();
    @defs_p = ();
    @defs_p_o = ();
    @defs_str_abk = map { $_->[0] } @defs_str;
    @defs_p_abk   = map { $_->[0] } @defs_p;
    @defs_p_o_abk = map { $_->[0] } @defs_p_o;

    $BBBikeExp::setup_done = 1;
}

# XXX for now "-orig" has to be specified unlike in other functions
# like main::plotstr
sub BBBikeExp::bbbikeexp_add_data {
    my($type, $abk, $file) = @_;
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
	# XXX no! main::plot("str", $abk, -draw => 0);
    } else {
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
	# XXX no! main::plot("p", $abk, -draw => 0);
    }

    if (!defined $exp_master) {
	warn "XXX master deleted, disable BBBikeExp mode!!!";
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
	$exp_str{$def->[0]}->make_grid(UseCache => 1);
    } else {
	$exp_str{$def->[0]}->reload;
    }
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
	$exp_p{$def->[0]}->make_grid(UseCache => 1);
    } else {
	$exp_p{$def->[0]}->reload;
    }
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
    foreach my $def (@defs_p, @defs_p_o) {
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
    foreach my $def (@defs_p, @defs_p_o) {
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

	my $municipality = 0;
	foreach my $abk (@defs_p_o_abk) {
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
