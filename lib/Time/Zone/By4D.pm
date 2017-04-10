# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2016,2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Time::Zone::By4D;

use strict;
use vars qw($VERSION);
$VERSION = '0.03';

use VectorUtil qw(point_in_polygon);

sub get_timezone {
    my($longitude, $latitude, $epoch) = @_;
    if ($epoch < 347151600) { # 1981-01-01
	die "Don't know how to get time zone before 1981";
    }
    my $point = [$longitude, $latitude];
    if (_is_in_EU_0100($point)) {
	return 'Europe/Berlin'; # XXX inaccurate, but should work
    } elsif (_is_in_GB_IRL($point)) {
	return 'Europe/London'; # XXX inaccurate, but should work
    } elsif (_is_in_EET($point)) {
	return 'Europe/Riga', # XXX inaccurate, but should work
    }
    die "No support for location lon=$longitude lat=$latitude";
}

{
    my @area;
    sub _is_in_EU_0100 {
	my $point = shift;
	if (!@area) {
	    no warnings 'qw';
	    @area = map { [split /,/, $_] }
		(
		 qw(1.933594,72.475276 2.8125,52.05249 0.53833,50.176898 -2.515869,49.866317 -2.48291,49.632062 -1.933594,49.389524 -1.702881,49.095452 -1.658936,48.814099 -2.423859,48.815907 -3.306885,49.339441 -10.458984,49.439557 -10.568848,42.179688 -5.998535,42.179688 -6.767578,36.066862 -5.619507,35.933541 1.450195,36.949892 11.118164,37.753344 16.347656,35.56798 19.379883,39.909736 20.917969,40.830437 22.675781,41.508577 22.17041,42.407235 22.104492,44.292401 21.071777,44.809122 20.01709,46.17983 20.961914,46.498392 22.5,49.75288 23.598633,50.611132),
		 # PL-RUS
		 qw(23.181152,52.284962 23.358307,52.469397 23.489456,52.561743 23.733902,52.609719 23.859558,52.668471 23.935776,52.713835 23.943329,52.958980 23.875351,53.080827 23.891144,53.121229 23.915863,53.162417 23.818359,53.244673 23.659744,53.521125 23.585587,53.706462 23.582840,53.743838 23.548508,53.767790 23.548508,53.830649 23.529282,53.864271),
		 # PL-LT
		 qw(23.515549,53.953257 23.481216,53.997679 23.523788,54.031570 23.525848,54.071074 23.486710,54.152784 23.475037,54.160424 23.340454,54.251186 23.240204,54.260412 23.145447,54.314521 23.120728,54.308913 23.096008,54.297294 23.043137,54.316123 23.060989,54.343350 22.994385,54.363358 23.007431,54.382557 22.844009,54.407342 22.796631,54.362958),
		 # PL-BY
		 qw(22.298126,54.339747 21.551743,54.325334 21.446686,54.318125 21.437073,54.326535 21.272964,54.327336 20.658417,54.370559 20.356979,54.395351 20.067902,54.422126 19.896927,54.434109 19.646301,54.453275),
		 qw(19.116211,56.619977 20.786133,58.756805 19.050293,60.326948 20.192871,63.233627 22.214355,64.101007 23.334961,65.522068 22.785645,68.056889 20.10498,69.084257 23.57666,69.975493 28.234863,70.185103 29.970703,72.60712 1.933594,72.475276)
		);
	}
	point_in_polygon($point, \@area);
    }
}

{
    my @area;
    sub _is_in_EET {
	my $point = shift;
	if (!@area) {
	    no warnings 'qw';
	    @area = map { [split /,/, $_] }
		(
		 # PL-LT
		 qw(23.515549,53.953257 23.481216,53.997679 23.523788,54.031570 23.525848,54.071074 23.486710,54.152784 23.475037,54.160424 23.340454,54.251186 23.240204,54.260412 23.145447,54.314521 23.120728,54.308913 23.096008,54.297294 23.043137,54.316123 23.060989,54.343350 22.994385,54.363358 23.007431,54.382557 22.844009,54.407342 22.796631,54.362958),
		 # LT-RUS
		 qw(22.679901,54.530645 22.747879,54.639671 22.741699,54.724620 22.881088,54.795539 22.841263,54.892801 22.583771,55.067753 22.355804,55.061461 22.154617,55.055169 22.107239,55.026054 22.037888,55.045335 22.036514,55.082691 21.963730,55.074436 21.906052,55.083477 21.570282,55.195724 21.506424,55.187885 21.382828,55.293583 21.269531,55.245075 20.956421,55.280680),
		 qw(20.467529,55.329144 20.577393,58.602611 19.687500,59.811685 19.110718,60.277962 19.335938,62.400551 20.983887,63.568120 24.147949,65.357677 23.532715,68.007571 20.698242,69.060712 21.445313,69.318320 22.390137,68.752315 25.598145,68.640555 26.433105,69.930300 27.927246,70.043098 29.487305,69.626510 28.872070,69.060712 28.234863,68.171555 30.036621,67.667737 29.113770,66.895596 30.234375,65.694476 29.707031,65.603878 29.685059,64.830254 30.498047,64.101007 30.080566,63.811592 31.530762,62.845119 27.773438,60.457218 27.993164,59.500880 28.212891,59.366794 27.927246,59.243415 27.443848,58.779591 27.817383,57.879816 27.355957,57.515823 27.861328,57.302790 27.663574,56.885002 27.993164,56.800878 28.212891,56.157788 27.685547,55.788929 26.652832,55.677584 26.499023,55.329144 26.806641,55.291628 26.696777,55.166319 26.323242,55.141210 25.795898,54.876607 25.784912,54.584797 25.587158,54.348553 25.817871,54.201010 25.587158,54.123822 25.510254,54.278055 25.202637,54.258807 25.037842,54.130260 24.993896,54.162434 24.818115,54.104502 24.884033,53.994854 24.444580,53.904338 24.191895,53.969012 23.606873,53.926986),
		 qw(23.515549,53.953257),
		);
	    # missing: Ukraine, Romania, Bulgaria...
	}
	point_in_polygon($point, \@area);
    }
}

{
    my @area;
    sub _is_in_GB_IRL {
	my $point = shift;
	if (!@area) {
	    no warnings 'qw';
	    @area = map { [split /,/, $_] } qw(-6.020508,48.893615 0.703125,50.597186 3.229980,51.903613 2.724609,61.637726 -13.447266,59.220934 -13.754883,48.908059);
	}
	point_in_polygon($point, \@area);
    }
}

# Return time offset in seconds
sub get_timeoffset {
    my($longitude, $latitude, $epoch) = @_;
    require DateTime;
    require DateTime::TimeZone;
    my $timezone_name = get_timezone($longitude, $latitude, $epoch);
    my $dt = DateTime->from_epoch(epoch => $epoch);
    my $timezone = DateTime::TimeZone->new(name => $timezone_name);
    $timezone->offset_for_datetime($dt);
}

# Return time offset as [+-]hh:mm
sub get_iso8601_timeoffset {
    my $s = get_timeoffset(@_);
    my $sgn = $s < 0 ? '-' : '+';
    $s = abs($s);
    my $min = int($s/60) % 60;
    my $h = int($s/3600);
    sprintf "%s%02d:%02d", $sgn, $h, $min;
}

1;

__END__

=head1 NAME

Time::Zone::By4D - get time zone name for given location and time

=head1 SYNOPSIS

    use Time::Zone::By4D;
    my $timezone = Time::Zone::By4D::get_timezone($longitude, $latitude, $epoch);
    my $offset     = Time::Zone::By4D::get_timeoffset($longitude, $latitude, $epoch);
    my $offset8601 = Time::Zone::By4D::get_8601_timeoffset($longitude, $latitude, $epoch);

=head1 DESCRIPTION

For the given longitude/latitude and epoch time return the time zone
name for this location at this time.

The C<get_timeoffset> function returns the offset in seconds for the
guessed time zone.

The C<get_8601_timezone> function returns the offset as I<+hh:mm> or
I<-hh:mm>, suitable for inclusion in ISO 8601 times.

Currently only a limited implementation: most of South and Central
Europe is covered, starting from 1981. For simplicity reasons,
C<Europe/Berlin> is returned in this case (shouldn't do a difference
for other countries here). For all other input values the function
dies.

=cut
