# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Time::Zone::By4D;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use VectorUtil qw(point_in_polygon);

sub get_timezone {
    my($longitude, $latitude, $epoch) = @_;
    if ($epoch < 347151600) { # 1981-01-01
	die "Don't know how to get time zone before 1981";
    }
    my $point = [$longitude, $latitude];
    if (_is_in_EU_0100($point)) {
	return 'Europe/Berlin'; # XXX inaccurate, but should work
    }
    die "No support for location lon=$longitude lat=$latitude";
}

{
    my @area;
    sub _is_in_EU_0100 {
	my $point = shift;
	if (!@area) {
	    no warnings 'qw';
	    @area = map { [split /,/, $_] } qw(1.933594,72.475276 2.8125,52.05249 0.53833,50.176898 -2.515869,49.866317 -2.48291,49.632062 -1.933594,49.389524 -1.702881,49.095452 -1.658936,48.814099 -2.423859,48.815907 -3.306885,49.339441 -10.458984,49.439557 -10.568848,42.179688 -5.998535,42.179688 -6.767578,36.066862 -5.619507,35.933541 1.450195,36.949892 11.118164,37.753344 16.347656,35.56798 19.379883,39.909736 20.917969,40.830437 22.675781,41.508577 22.17041,42.407235 22.104492,44.292401 21.071777,44.809122 20.01709,46.17983 20.961914,46.498392 22.5,49.75288 23.598633,50.611132 23.005371,52.241256 22.82959,54.162434 19.401855,54.252389 19.116211,56.619977 20.786133,58.756805 19.050293,60.326948 20.192871,63.233627 22.214355,64.101007 23.334961,65.522068 22.785645,68.056889 20.10498,69.084257 23.57666,69.975493 28.234863,70.185103 29.970703,72.60712 1.933594,72.475276);
	}
	point_in_polygon($point, \@area);
    }
}

1;

__END__

=head1 NAME

Time::Zone::By4D - get time zone name for given location and time

=head1 SYNOPSIS

    use Time::Zone::By4D;
    my $timezone = Time::Zone::By4D::get_timezone($longitude, $latitude, $epoch);

=head1 DESCRIPTION

For the given longitude/latitude and epoch time return the time zone
name for this location at this time.

Currently only a limited implementation: most of South and Central
Europe is covered, starting from 1981. For simplicity reasons,
C<Europe/Berlin> is returned in this case (shouldn't do a difference
for other countries here). For all other input values the function
dies.

=cut
