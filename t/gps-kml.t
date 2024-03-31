#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use File::Temp qw(tempfile);
use Test::More 'no_plan';

use BBBikeTest qw(eq_or_diff);
use BBBikeTestSamplesKML;

use GPS::KML;

{
    my($tmpfh,$tmpfile) = tempfile("gps-kml-t-XXXXXXXX", UNLINK => 1, SUFFIX => '.kml');
    print $tmpfh get_sample_kml_1();
    close $tmpfh;

    my(@r) = GPS::KML->new->convert_to_route($tmpfile);
    @r = map { join ",", map { int $_ } @$_ } @r;
    eq_or_diff \@r, [get_sample_kml_coordinates_1()];
}

__END__
