# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::SimpleSearch;

use strict;
our $VERSION = '0.01';

use base 'Exporter';
our @EXPORT_OK = 'simple_search';

use Strassen::Util qw();

sub simple_search {
    my($net, $start_coord, $goal_coords, %opts) = @_;

    my $callback    = delete $opts{callback};
    my $threshold   = delete $opts{threshold};
    my $adjust_dist = delete $opts{adjustdist};
    my $add_net     = delete $opts{add_net};
    die "Unhandled options: " . join(" ", keys %opts) if %opts;

    my $net_net = $net->{Net}
	or die "Cannot find 'Net' field in $net";
    my $add_net_net = $add_net ? $add_net->{Net} : {};

    my %CLOSED;
    my %OPEN;
    my %PRED;

    my $act_coord = $start_coord;
    my $act_dist  = 0;
    $OPEN{$act_coord} = $act_dist;
    $PRED{$act_coord} = undef;

    my $found_goal;
    my $found_dist;
    my $hit_threshold;
 FLOOD_SEARCH: while () {
	$CLOSED{$act_coord} = $act_dist;
	delete $OPEN{$act_coord};

	for my $neighbors (grep { defined } $net_net->{$act_coord}, $add_net_net->{$act_coord}) {
	    while (my($neighbor, $dist) = each %$neighbors) {
		$dist = $adjust_dist->($dist, $act_coord, $neighbor)
		    if $adjust_dist;
		my $new_dist = $act_dist + $dist;
		next if exists $CLOSED{$neighbor} && $CLOSED{$neighbor} <= $new_dist;
		next if exists $OPEN{$neighbor}   && $OPEN{$neighbor}   <= $new_dist;
		$OPEN{$neighbor} = $new_dist;
		$PRED{$neighbor} = $act_coord;
	    }
	}

	my $new_act_coord;
	my $new_act_dist = Strassen::Util::infinity();
	while (my($c, $dist) = each %OPEN) {
	    if ($dist < $new_act_dist) {
		$new_act_coord = $c;
		$new_act_dist = $dist;
	    }
	}

	if ($goal_coords) {
	    for my $goal_coord (@$goal_coords) {
		if ($new_act_coord eq $goal_coord) {
		    $found_goal = $goal_coord;
		    $found_dist = $new_act_dist;
		    last FLOOD_SEARCH;
		}
	    }
	}

	if ($threshold && $new_act_dist > $threshold) {
	    $hit_threshold = 1;
	    $found_goal = $new_act_coord;
	    $found_dist = $new_act_dist;
	    last FLOOD_SEARCH;
	}

	if (!defined $new_act_coord) { # everything's flooded
	    last;
	}

	$callback->($new_act_coord, $new_act_dist, $act_coord, \%PRED, \%CLOSED, \%OPEN)
	    if $callback;

	$act_coord = $new_act_coord;
	$act_dist = $new_act_dist;
    }

    if ($found_goal) {
	my $act_coord = $found_goal;
	my @route = $act_coord;
	while(my $prev_coord = $PRED{$act_coord}) {
	    unshift @route, $prev_coord;
	    $act_coord = $prev_coord;
	}
	+{ route => \@route,
	   dist  => $found_dist,
	   ($threshold ? (hit_threshold => $hit_threshold) : ()),
	 };
    } else {
	undef;
    }
}

1;

__END__
