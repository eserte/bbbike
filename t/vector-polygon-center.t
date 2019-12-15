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
    my @coords = ([6821,5716],[6821,5657],[6841,5657],[6841,5716],[6821,5715]);
    for my $def (
		 [\@coords, 'ccw'],
		 [[reverse @coords], 'cw'],
		) {
	my @c = @{ $def->[0] };
	my $direction = $def->[1];
	my($cx,$cy) = get_polygon_center(flatten(@c));
	my $bbox = bbox_of_polygon(\@c);
	within_bbox($cx,$cy,$bbox,"$direction, unclosed polygon");
    }
}

{
    my @coords = ([6821,5716],[6821,5657],[6841,5657],[6841,5716],[6821,5716]);
    for my $def (
		 [\@coords, 'ccw'],
		 [[reverse @coords], 'cw'],
		) {
	my @c = @{ $def->[0] };
	my $direction = $def->[1];
	my($cx,$cy) = get_polygon_center(flatten(@c));
	my $bbox = bbox_of_polygon(\@c);
	within_bbox($cx,$cy,$bbox,"closed polygon");
    }
}

sub flatten { map { @$_ } @_ }

sub within_bbox {
    my($x,$y,$bbox,$testname) = @_;
    $testname = defined $testname ? "$testname: " : "";
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    cmp_ok $x, ">=", $bbox->[0], "${testname}left bbox check";
    cmp_ok $x, "<=", $bbox->[2], "${testname}right bbox check";
    cmp_ok $y, ">=", $bbox->[1], "${testname}upper bbox check";
    cmp_ok $y, "<=", $bbox->[3], "${testname}lower bbox check";
    
}

__END__
