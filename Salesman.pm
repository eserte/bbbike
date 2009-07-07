# -*- perl -*-

#
# $Id: Salesman.pm,v 1.19 2007/12/27 11:46:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2003,2006 Slaven Rezic. All rights reserved.
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
	    if ($main::escape) { die "User break" }
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

1;

__END__

# More references to TSP:
# - http://www.jochen-pleines.de/index.htm
