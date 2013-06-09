# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2000,2003,2006,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# Maybe Algorithm::Permute 0.08 is reliable? Try it...
#
# Older notes:
#
# | Algorithm::Permute seems to be slightly faster, but dumps core
# | if "die"ing in the permute { } loop. This seems only to happen within
# | Tk callbacks.
# | 
# | This seems to happen randomly, see the test reports at
# |  http://cpantesters.perl.org/show/Algorithm-Permute.html#Algorithm-Permute-0.06
# | 
# | So prefer List::Permutor over Algorithm::Permute.
#

package Salesman;
BEGIN {
    eval 'use Algorithm::Permute 0.08;';
    if ($@) {
	warn "$@, fallback to List::Permutor";
	eval 'use List::Permutor;';
	if ($@) {
	    die $@;
	}
    }
}

use strict;

sub new {
    my($class, %args) = @_;
    if (!exists $args{-net}) {
	die "No -net argument supplied";
    }
    if (!exists $args{-addnewpoint}) {
	die "No -addnewpoint argument supplied";
    }
    my $self = {};
    $self->{Net}         = $args{-net};
    $self->{AddNewPoint} = $args{-addnewpoint};
    $self->{Tk}          = $args{-tk};
    $self->{Progress}    = $args{-progress};
    $self->{SearchArgs}  = $args{-searchargs};
    $self->{NumberOfPoints} = 0;
    bless $self, $class;
}

sub get_number_of_points { shift->{NumberOfPoints} }

sub add_point {
    my($self, $point) = @_;
    my $r = 0;
    eval {
	my $new_point = $point;
	if (!$self->{Net}->reachable($point)) {
	    $new_point = $self->{AddNewPoint}->($self->{Net}, $point);
	}
	push @{ $self->{ProcessPoints} }, $new_point;
	$r = 1;
    };
    $self->{NumberOfPoints} = scalar @{ $self->{ProcessPoints} };
    warn $@ if ($@);
    $r;
}

sub reset_points {
    my $self = shift;
    $self->{ProcessPoints} = [];
}

# first in the list is always the start point,
# the last is the end point
sub _points {
    my($self, @points) = @_;
    @points = @{ $self->{ProcessPoints} }
        if !@points && $self->{ProcessPoints};
    $self->{Start} = shift @points;
    $self->{End}   = pop   @points;
    $self->{Points} = \@points;
    $self->{Distances} = {};
}

sub _calculate_distances {
    my $self = shift;
    my(@points)   = ($self->{Start}, @{ $self->{Points} }, $self->{End});
    my $distances = $self->{Distances};
    my $tk        = $self->{Tk};
    my $progress  = $self->{Progress};
    local $Strassen::StrassenNetz::VERBOSE = $Strassen::StrassenNetz::VERBOSE = 0; # too verbose
    for(my $i = 0; $i <= $#points; $i++) {
	$progress->Update(0.5*($i/scalar @points)) if $progress;
	if ($tk) {
	    $tk->update; # see below
	    if ($main::escape) {
		$progress->Finish;
		die "User break";
	    }
	}
	for(my $j = 0; $j <= $#points; $j++) {
	    next if $i == $j;
	    my(@res) = $self->{Net}->search
		($points[$i], $points[$j],
		 ($self->{SearchArgs} ? %{ $self->{SearchArgs} } : ()),
		);
	    if (@res) {
		my $len = $res[1];
		$distances->{$points[$i]}{$points[$j]} = $len;
		warn "Route between $points[$i] and $points[$j] found"
		    if $main::verbose;
	    } else {
		warn "No route between $points[$i] and $points[$j] found";
	    }
	}
    }
    $self->_dump_tsplib_file;
}

sub _dump_tsplib_file {
    my $self = shift;
    $main::devel_host = $main::devel_host;
    if ($main::devel_host) {
	## Use the generated file for upload at
	# http://www-neos.mcs.anl.gov/neos/solvers/co:concorde/TSP.html
	my @points = ($self->{Start}, @{ $self->{Points} }); # End should be == Start
	my $distances = $self->{Distances};
	open(FH, ">/tmp/test.tsplib") or die $!;
	# ATSP geht leider nicht mit dem Service :-(
	print FH <<EOF;
NAME: test
TYPE: TSP
COMMENT: srt
DIMENSION: @{[ scalar @points ]}
NODE_COORD_TYPE: TWOD_COORDS
DISPLAY_DATA_TYPE: COORD_DISPLAY
EDGE_WEIGHT_TYPE: EXPLICIT
EDGE_WEIGHT_FORMAT: FULL_MATRIX
EOF

	print FH <<EOF;
DISPLAY_DATA_SECTION:
EOF
	for my $i (0 .. $#points) {
	    print FH "$i " . join(" ", split /,/, $points[$i]) . "\n";
	}

	print FH <<EOF;
EDGE_WEIGHT_SECTION:
EOF
	for my $i (0 .. $#points) {
	    print FH join(" ", map { $distances->{$points[$i]}{$points[$_]}||0 } (0 .. $#points)) . "\n";
	}
	close FH;
    }
}

sub best_path_algorithm_permute {
    my $self = shift;
    my $progress  = $self->{Progress};
    $main::escape = 0;

    if ($progress) {
	$progress->Init(-label => "Abbruch mit Esc");
    }

    $self->_points; # XXX conditional?
    if (!$self->{Start} || !$self->{End}) {
	return ();
    }

    if (!scalar keys %{ $self->{Distances} }) {
	$self->_calculate_distances;
    }
    my@row = @{ $self->{Points} };
    my $count    = _fact(scalar @{ $self->{Points} });

    my $best_permute;
    my $shortest_path;
    my $distances = $self->{Distances};
    my $tk        = $self->{Tk};
    my $i = 0;
    eval {
	Algorithm::Permute::permute(sub {
 PERMUTE:
	my $permute = [@row];
	$i++;
	if ($i%500 == 0) {
	    $progress->Update(0.5+0.5*($i/$count));
	    if ($tk) {
		$tk->update;
		if ($main::escape) {
		    $progress->Finish;
		    CORE::die("User break, using best path at moment");
		}
	    }
	}
	unshift @$permute, $self->{Start};
	push    @$permute, $self->{End};
	my $pathlen = 0;
	for(my $j = 1; $j <= $#$permute; $j++) {
	    if (exists $distances->{$permute->[$j-1]}{$permute->[$j]}) {
		$pathlen += $distances->{$permute->[$j-1]}{$permute->[$j]};
	    } else {
		#XXX to verbose: warn "No path for permutation @$permute";
		next PERMUTE;
	    }
	}
	if (!defined $shortest_path ||
	    $shortest_path > $pathlen) {
	    $shortest_path = $pathlen;
	    $best_permute = $permute;
	    warn "Best one is $shortest_path" if $main::verbose;
	}
    }, @row);
    };
    warn $@ if $@;

    if ($progress) {
	$progress->Finish;
    }

    if ($best_permute) {
	warn "best one is: @$best_permute";
	@$best_permute;
    } else {
	();
    }
}

sub best_path_list_permutor {
    my $self = shift;
    my $progress  = $self->{Progress};
    $main::escape = 0;

    if ($progress) {
	$progress->Init(-label => "Abbruch mit Esc");
    }

    $self->_points; # XXX conditional?
    if (!$self->{Start} || !$self->{End}) {
	return ();
    }

    if (!scalar keys %{ $self->{Distances} }) {
	$self->_calculate_distances;
    }
    my $permutor = List::Permutor->new(@{ $self->{Points} });
    my $count    = _fact(scalar @{ $self->{Points} });

    my $best_permute;
    my $shortest_path;
    my $distances = $self->{Distances};
    my $tk        = $self->{Tk};
    my $i = 0;
 PERMUTE:
    while(1) {
	my @row = $permutor->next;
	last if !@row;
	my $permute = \@row;
	$i++;
	if ($i%500 == 0) {
	    $progress->Update(0.5+0.5*($i/$count));
	    if ($tk) {
		$tk->update;
		if ($main::escape) {
		    $progress->Finish;
		    warn "User break, using best path at moment";
		    last PERMUTE;
		}
	    }
	}
	unshift @$permute, $self->{Start};
	push    @$permute, $self->{End};
	my $pathlen = 0;
	for(my $j = 1; $j <= $#$permute; $j++) {
	    if (exists $distances->{$permute->[$j-1]}{$permute->[$j]}) {
		$pathlen += $distances->{$permute->[$j-1]}{$permute->[$j]};
	    } else {
		#XXX to verbose: warn "No path for permutation @$permute";
		next PERMUTE;
	    }
	}
	if (!defined $shortest_path ||
	    $shortest_path > $pathlen) {
	    $shortest_path = $pathlen;
	    $best_permute = $permute;
	    warn "Best one is $shortest_path" if $main::verbose;
	}
    }

    if ($progress) {
	$progress->Finish;
    }

    if ($best_permute) {
	warn "best one is: @$best_permute";
	@$best_permute;
    } else {
	();
    }
}

sub best_path_bitonic_tour_closed {
    my($self) = @_;
    my $progress  = $self->{Progress};
    $main::escape = 0;

    if (!eval { require Algorithm::TravelingSalesman::BitonicTour; 1 }) {
	die "The module Algorithm::TravelingSalesman::BitonicTour is not available";
    }

    if ($progress) {
	$progress->Init(-label => "Abbruch mit Esc");
    }

    my $bittour = My::Algorithm::TravelingSalesman::BitonicTour->new;
    my $net = $self->{Net};
    my @search_args = ($self->{SearchArgs} ? %{ $self->{SearchArgs} } : ());
    $self->{Distances} = {};
    my $distances = $self->{Distances};
    $bittour->{_get_distance} = sub {
	my($x1,$y1,$x2,$y2) = @_;
	my $p1 = "$x1,$y1";
	my $p2 = "$x2,$y2";
	my $dist = $distances->{$p1}{$p2};
	return $dist if defined $dist;
	my(@res) = $net->search($p1, $p2, @search_args);
	if (@res) {
	    my $len = $res[1];
	    if ($len == 0) {
		warn "Distance between $p1 and $p2 is 0, which is not allowed, adjusting...";
		$len = 0.00001;
	    }
	    $distances->{$p1}{$p2} = $len;
	    return $len;
	} else {
	    warn "Cannot get distance between $p1 and $p2";
	    0.00001; # otherwise BitonicTour.pm will croak
	}
    };

    for my $p (@{ $self->{ProcessPoints} }) {
	$bittour->add_point(split /,/, $p);
    }

    my(@res_points);
    (undef, @res_points) = $bittour->solve;
    @res_points = map { join(",", @$_) } @res_points;

    {
	my $start = $self->{ProcessPoints}[0];
	for my $i (0 .. $#res_points) {
	    if ($res_points[$i] eq $start) {
		if ($i > 0) {
		    @res_points = @res_points[$i..$#res_points,0..$i];
		}
		last;
	    }
	}
    }

    if ($progress) {
 	$progress->Finish;
    }

    @res_points;
}

sub _fact {
    if ($_[0] < 2) {
	$_[0];
    } else {
	_fact($_[0]-1)*$_[0];
    }
}

if (defined &Algorithm::Permute::permute) {
    *best_path = \&best_path_algorithm_permute;
} else {
    *best_path = \&best_path_list_permutor;
}

{
    package My::Algorithm::TravelingSalesman::BitonicTour;
    # No "require" here, this needs to be optional.
    our @ISA = qw(Algorithm::TravelingSalesman::BitonicTour);

    # Overwriting delta() to use precalculated distance net instead of
    # simple euclidean distance.
    sub delta {
	my($self, $p1, $p2) = @_;
	my($x1, $y1) = $self->coord($p1);
	my($x2, $y2) = $self->coord($p2);
	$x1 = $self->{_orig_x}->{$x1}->{$y1};
	$x2 = $self->{_orig_x}->{$x2}->{$y2};
	$self->{_get_distance}->($x1,$y1,$x2,$y2);
    }

    # Overwriting add_point() to not croak on duplicate x values, but
    # slightly adjust them.
    sub add_point {
	my($self, $x, $y) = @_;
	# Skip Regexp::Common validation here found in the original add_point()
	my $_points = $self->_points;
	my $orig_x = $x;
	if (exists $_points->{$x}) {
	SEARCH_FOR_NEW_X: {
		for(1..1000) {
		    $x+=0.00001;
		    if (!exists $_points->{$x}) {
			last SEARCH_FOR_NEW_X;
		    }
		}
		die "Cannot find new x value for $x/y. BitonicTour cannot be calculated";
	    }
	}

	$self->_sorted_points(undef);   # clear any previous cache of sorted points
	$_points->{$x} = $y;
	$self->{_orig_x}->{$x}->{$y} = $orig_x;
	return [$x, $y];
    }
}

1;

__END__

# More references to TSP:
# - http://www.jochen-pleines.de/index.htm
