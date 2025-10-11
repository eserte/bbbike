# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2025 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://gihub.com/eserte/bbbike
#

package Route::LineSimplification;

use strict;
use warnings;
our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT_OK = qw(visvalingam_whyatt);

sub visvalingam_whyatt {
    require VectorUtil;
    require Storable;

    my($in_points_ref, $stop) = @_;
    my @out_points = @{ Storable::dclone($in_points_ref) };

    my $get_size_func;
    if (ref $stop->[0] eq 'CODE') {
	$get_size_func = $stop->[0];
    } elsif ($stop->[0] eq 'strlen') {
	# assumes a one-byte separator between x and y and one-byte separator between points
	require List::Util;
	$get_size_func = sub {
	    my $points_ref = shift;
	    (List::Util::sum(map { length($_->{x}) + length($_->{y}) + 1 } @$points_ref) + @$points_ref - 1);
	};
    } elsif ($stop->[0] eq 'elements') {
	$get_size_func = sub {
	    my $points_ref = shift;
	    scalar @$points_ref;
	};
    } else {
	die "Unhandled stop function $stop->[0]";
    }
    my $max_size = $stop->[1];

    my $calc_area = sub {
	my($i) = @_;
	$out_points[$i]->{area} = VectorUtil::triangle_area(
							    [@{$out_points[$i-1]}{qw(x y)}],
							    [@{$out_points[$i  ]}{qw(x y)}],
							    [@{$out_points[$i+1]}{qw(x y)}],
							   );
    };

    if ($get_size_func->(\@out_points) > $max_size && @out_points > 2) {

	for my $i (1 .. $#out_points-1) {
	    $calc_area->($i);
	}

	while (@out_points > 2) {
	    my($min_area, $min_area_inx);
	    for my $i (1 .. $#out_points-1) {
		if (!defined $min_area || $min_area > $out_points[$i]->{area}) {
		    $min_area = $out_points[$i]->{area};
		    $min_area_inx = $i;
		}
	    }
	    splice @out_points, $min_area_inx, 1;
	    if ($min_area_inx-1 > 0) {
		$calc_area->($min_area_inx-1)
	    }
	    if ($min_area_inx < $#out_points) {
		$calc_area->($min_area_inx);
	    }
	    my $current_size = $get_size_func->(\@out_points);
	    if ($current_size <= $max_size) {
		last;
	    }
	}
    }
    return \@out_points;
}

1;

__END__
