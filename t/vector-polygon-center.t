#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/../lib");

use Test::More 'no_plan';

use VectorUtil qw(get_polygon_center bbox_of_polygon);

{
    my @coords = (6821,5716,6821,5657,6841,5657,6841,5716,6821,5715);
    my $bbox = bbox_of_polygon([flat_to_pairs(@coords)]);
    my($cx,$cy) = get_polygon_center(@coords);
    cmp_ok $cx, ">=", $bbox->[0], 'left bbox check';
    cmp_ok $cx, "<=", $bbox->[2], 'right bbox check';
    cmp_ok $cy, ">=", $bbox->[1], 'upper bbox check';
    cmp_ok $cy, "<=", $bbox->[3], 'lower bbox check';
}

{
    local $TODO = "currently cannot get center";
    my($cx,$cy) = get_polygon_center(6821,5716,6821,5657,6841,5657,6841,5716,6821,5716);
    ok defined $cx;
    ok defined $cy;
}

sub flat_to_pairs {
    my @coords = @_;
    my @res;
    for(my $i=0; $i<@coords; $i+=2) {
	push @res, [@coords[$i, $i+1]];
    }
    @res;
}

__END__
