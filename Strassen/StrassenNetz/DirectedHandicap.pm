# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2019 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://bbbike.de
#

package Strassen::StrassenNetz::DirectedHandicap;

use strict;
use warnings;
use Carp qw(croak);
our $VERSION = '0.01';

# Parameters:
# - Strassen object
# - %args:
#   - speed: speed in km/h, required for converting time penalties
sub new {
    my($class, $s, %args) = @_;

    my $speed_kmh = delete $args{speed};
    if (!defined $speed_kmh) {
	croak "Please specify speed (in km/h)";
    }
    my $speed_ms = $speed_kmh / 3.6;
    my $vehicle = delete $args{vehicle} || '';
    $vehicle = '' if $vehicle eq 'normal'; # alias
    my $handicap_penalty = delete $args{handicap_penalty};
    my $handicap_speed = delete $args{handicap_speed};
    if ($handicap_speed) {
	if ($handicap_penalty) {
	    croak "Cannot specify both handicap_penalty and handicap_speed";
	}
	while(my($cat, $cat_speed_kmh) = each %$handicap_speed) {
	    my $penalty_factor = $speed_kmh / $cat_speed_kmh;
	    if ($penalty_factor < 1) {
		$penalty_factor = 1;
	    }
	    $handicap_penalty->{$cat} = $penalty_factor;
	}
    }
    my $default_lost_trafficlight_time = delete $args{default_lost_trafficlight_time};
    $default_lost_trafficlight_time = 15 if !defined $default_lost_trafficlight_time;
    my $kerb_up_time = delete $args{kerb_up_time};
    my $kerb_down_time = delete $args{kerb_down_time};
    croak "Unhandled options to " . __PACKAGE__ . "->new: " . join(" ", %args) if %args;

    bless {
	   s => $s,
	   speed_ms => $speed_ms,
	   vehicle => $vehicle,
	   handicap_penalty => $handicap_penalty,
	   default_lost_trafficlight_time => $default_lost_trafficlight_time,
	   kerb_up_time => $kerb_up_time,
	   kerb_down_time => $kerb_down_time,
	  }, $class;
}

# Create a net for the DirectedHandicap search feature.
sub make_net {
    my($self) = @_;

    my $s = $self->{s};
    my $speed_ms = $self->{speed_ms};
    my $vehicle = $self->{vehicle};
    my $handicap_penalty = $self->{handicap_penalty};
    my $default_lost_trafficlight_time = $self->{default_lost_trafficlight_time};
    my %time;
    $time{kerb_up}   = $self->{kerb_up_time};
    $time{kerb_down} = $self->{kerb_down_time};

    # XXX check kerb times!
    if (!defined $time{kerb_up}) {
	$time{kerb_up} =
	    {''          => 4,
	     'childseat' => 5,
	     'trailer'   => 12,
	     'cargobike' => 18,
	     'heavybike' => 40,
	    }->{$vehicle};
    }
    if (!defined $time{kerb_down}) {
	$time{kerb_down} =
	    {''          => 2,
	     'childseat' => 3,
	     'trailer'   => 8,
	     'cargobike' => 13,
	     'heavybike' => 25,
	    }->{$vehicle};
    }

    my %directed_handicaps;
    my $warned_too_few_coord;
    my $warned_invalid_cat;
    my $warned_no_handicap_penalty;
    my $warned_missing_handicap_penalty_cat;
    $s->init;
    while() {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS()] };
	last if !@c;
	if (@c < 3) {
	    if (!$warned_too_few_coord++) {
		warn "Invalid directedhandicap record: less than three coordinates. Entry is: @$r (warn only once)";
	    }
	}
	my $pen;    # penalty time
	my $tl_pen; # penalty time on traffic lights
	my $len;    # additional length
	if ($r->[Strassen::CAT()] =~ m{^DH:(.+)$}) {
	    my $attrs = $1;
	    for my $attr (split /:/, $attrs) {
		if ($attr =~ m{^t=(\d+)$}) {
		    my $time = $1;
		    $pen += $time * $speed_ms;
		} elsif ($attr =~ m{^len=(\d+)$}) {
		    $pen += $1;
		    $len += $1;
		} elsif ($attr =~ m{^kerb_(?:up|down)$}) {
		    $pen += $time{$attr} * $speed_ms;
		} elsif ($attr =~ m{^h=(q\d[-+]?),(\d+)$}) {
		    my($cat, $len) = ($1, $2);
		    if (!$handicap_penalty) {
			if (!$warned_no_handicap_penalty++) {
			    warn "DH:h=qX category encountered, but no handicap_penalty provided (warn only once)";
			}
		    } else {
			my $factor = $handicap_penalty->{$cat};
			if (!$factor) {
			    if (!$warned_missing_handicap_penalty_cat++) {
				warn "No handicap_penalty definiton for '$cat' (warn only once)";
			    }
			} else {
			    $pen += ($factor-1)*$len;
			}
		    }
		} elsif ($attr =~ m{^tl(?:=(\d+))?$}) {
		    my $lost_trafficlight_time = defined $1 ? $1 : $default_lost_trafficlight_time;
		    $pen    += 0; # trafficlight penalties are handled specially, in $tl_pen
		    $tl_pen += $lost_trafficlight_time * $speed_ms;
		} else {
		    if (!$warned_invalid_cat++) {
			warn "Invalid attr '$attr'. Entry is @$r (warn only once)";
		    }
		}
	    }
	} else {
	    if (!$warned_invalid_cat++) {
		warn "Invalid category '$r->[Strassen::CAT()]'. Entry is @$r (warn only once)";
	    }
	}
	if (defined $pen) {
	    my $last = pop @c;
	    push @{ $directed_handicaps{$last} },
		{
		 p => \@c,
		 pen => $pen,
		 (defined $tl_pen ? (tl_pen => $tl_pen) : ()),
		 len => $len,
		};
	}
    }

    $self->{Net} = \%directed_handicaps;

    $self;
}

sub get_losses {
    my($self, $route_path_ref) = @_;
    my $net = $self->{Net};
    my $speed_ms = $self->{speed_ms};
    my @route_path = map { join ',', @$_ } @$route_path_ref;
    my @ret;
    for(my $rp_i=1; $rp_i<=$#route_path; $rp_i++) {
	my $next_node = $route_path[$rp_i];
	if (exists $net->{$next_node}) {
	    my $directed_handicaps = $net->{$next_node};
	FIND_MATCHING_DIRECTED_HANDICAPS: {
		for my $directed_handicap (@$directed_handicaps) {
		    my $rp_j = $rp_i-1;
		    my $this_node = $route_path[$rp_j];
		    my $handicap_path = $directed_handicap->{p};
		FIND_MATCHING_DIRECTED_HANDICAP: {
			for(my $hp_i=$#$handicap_path; $hp_i>=0; $hp_i--) {
			    if ($handicap_path->[$hp_i] ne $this_node) {
				last FIND_MATCHING_DIRECTED_HANDICAP;
			    }
			    if ($hp_i > 0) {
				last FIND_MATCHING_DIRECTED_HANDICAP
				    if $rp_j == 0;
				$this_node = $route_path[--$rp_j];
			    }
			}
			push @ret,
			    {
			     path_begin_i  => $rp_j,
			     path_end_i    => $rp_i,
			     add_len       => $directed_handicap->{len},
			     lost_time     => $directed_handicap->{pen} / $speed_ms,
			     lost_time_tl  => (exists $directed_handicap->{tl_pen} ? $directed_handicap->{tl_pen} / $speed_ms : undef),
			    };
			last FIND_MATCHING_DIRECTED_HANDICAPS;
		    }
		}
	    }
	}
    }
    @ret;
}

1;

__END__
