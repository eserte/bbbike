#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 $FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Route;
use Route::Descr;
use Strassen::Core;
use Strassen::StrassenNetz;

use BBBikeTest qw(using_bbbike_test_data);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan 'no_plan';

using_bbbike_test_data;

my $net = StrassenNetz->new(Strassen->new("strassen"));
$net->make_net;
my %stdargs = (-net => $net);

no warnings 'qw'; # because of (x,y)

{
    my @coords = map {[split /,/]} qw(8291,8773 8425,8775 8472,8776 8594,8777 8763,8780 8982,8781 9063,8935 9111,9036 9115,9046 9150,9152 9170,9206 9211,9354 9248,9350 9280,9476 9334,9670 9387,9804 9334,9670 9280,9476 9248,9350 9225,9111 9224,9053 9225,9038 9227,8890 9229,8785);
    {
	my $out = Route::Descr::convert(%stdargs, -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route von Dudenstr. bis Mehringdamm",
			 "Start" => "Dudenstr.",
			 "Goal" => "Mehringdamm",
			 "Lines" => [
				     [undef, undef, "Dudenstr.", undef],
				     ["nach 0.69 km", "links (60\260) in die", "Methfesselstr.", "0.7 km"],
				     ["nach 0.62 km", "rechts (80\260) in die", "Kreuzbergstr.", "1.3 km"],
				     ["nach 0.04 km", "links (80\260) in den", "Mehringdamm", "1.3 km"],
				     ["nach 0.47 km", "umdrehen", "Mehringdamm", "1.8 km"],
				    ],
			 "Footer" => ["nach 1.04 km", "", "angekommen!", "2.9 km"],
			},
		  'Route::Descr output, German, simple route';
    }
    {
	my $out = Route::Descr::convert(%stdargs, -lang => 'en', -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route from Dudenstr. to Mehringdamm",
			 "Start" => "Dudenstr.",
			 "Goal" => "Mehringdamm",
			 "Lines" => [
				     [undef, undef, "Dudenstr.", undef],
				     ["after 0.69 km", "left (60\260) ->", "Methfesselstr.", "0.7 km"],
				     ["after 0.62 km", "right (80\260) ->", "Kreuzbergstr.", "1.3 km"],
				     ["after 0.04 km", "left (80\260) ->", "Mehringdamm", "1.3 km"],
				     ["after 0.47 km", "turn around", "Mehringdamm", "1.8 km"],
				    ],
			 "Footer" => ["after 1.04 km", "", "arrived!", "2.9 km"],
			},
		  'Route::Descr output, English, simple route';
    }
}

{
    my @coords = map {[split /,/]} qw(7866,9918 7906,10098 7813,10112 7702,10146 7698,10147 7579,10183);
    {
	my $out = Route::Descr::convert(%stdargs, -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route von B\374lowstr. (Sch\366neberg) bis B\374lowstr. (Sch\366neberg)",
			 "Start" => "B\374lowstr. (Sch\366neberg)",
			 "Goal" => "B\374lowstr. (Sch\366neberg)",
			 "Lines" => [
				     [undef, undef, "B\374lowstr.", undef],
				     ["nach 0.18 km", "links (90\260) weiter auf der", "B\374lowstr.", "0.2 km"]
				    ],
			 "Footer" => ["nach 0.34 km", "", "angekommen!", "0.5 km"],
			}, "Test 'weiter auf...'";
    }

    {
	my $out = Route::Descr::convert(%stdargs, -lang => 'en', -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route from B\374lowstr. (Sch\366neberg) to B\374lowstr. (Sch\366neberg)",
			 "Start" => "B\374lowstr. (Sch\366neberg)",
			 "Goal" => "B\374lowstr. (Sch\366neberg)",
			 "Lines" => [
				     [undef, undef, "B\374lowstr.", undef],
				     ["after 0.18 km", "left (90\260) ->", "B\374lowstr.", "0.2 km"]
				    ],
			 "Footer" => ["after 0.34 km", "", "arrived!", "0.5 km"],
			}, "Test 'weiter auf...' on English (which is just an arrow)";
    }
}

{
    my @coords = map {[split /,/]} qw(8291,8773 8425,8775 8472,8776 8594,8777 8689,8779 8763,8780 8982,8781 9063,8935);
    add_missing_points(\@coords);
    my $out = Route::Descr::convert(%stdargs, -route => Route->new_from_realcoords([@coords]));
    is_deeply $out, {
		     "Title" => "Route von Dudenstr. bis Methfesselstr.",
		     "Start" => "Dudenstr.",
		     "Goal" => "Methfesselstr.",
		     "Lines" => [
				 [undef, undef, "Dudenstr.", undef],
				 ["nach 0.69 km", "links (60\260) in die", "Methfesselstr.", "0.7 km"]
				],
		     "Footer" => ["nach 0.17 km", "", "angekommen!", "0.9 km"],
		    }, 'Test with additional added points';
    del_add_points();
}

{
    my @coords = map {[split /,/]} qw(13711,10022 13789,9949 13829,9905 13884,9882 13995,9834);
    {
	my $out = Route::Descr::convert(%stdargs, -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route von Puschkinallee bis Puschkinallee",
			 "Start" => "Puschkinallee",
			 "Goal" => "Puschkinallee",
			 "Lines" => [
				     [undef, undef, "Puschkinallee", undef],
				     ["nach 0.17 km", "halblinks (20\260) weiter auf der", "Puschkinallee", "0.2 km"]
				    ],
			 "Footer" => ["nach 0.18 km", "", "angekommen!", "0.3 km"],
			}, 'Test with "half-left" (German)';
    }
    {
	my $out = Route::Descr::convert(%stdargs, -lang => 'en', -route => Route->new_from_realcoords([@coords]));
	is_deeply $out, {
			 "Title" => "Route from Puschkinallee to Puschkinallee",
			 "Start" => "Puschkinallee",
			 "Goal" => "Puschkinallee",
			 "Lines" => [
				     [undef, undef, "Puschkinallee", undef],
				     ["after 0.17 km", "half left (20\260) ->", "Puschkinallee", "0.2 km"]
				    ],
			 "Footer" => ["after 0.18 km", "", "arrived!", "0.3 km"],
			}, 'Test with "half-left" (English)';
    }
}


# Question: should this be done automatically, somewhere?
sub add_missing_points {
    my($coords_ref) = @_;
    my @coords = map { $_->[0].",".$_->[1] } @$coords_ref;
    for my $coord_i (1 .. $#coords-1) {
	if (!exists $net->{Net}->{$coords[$coord_i]}) {
	    my($pos) = $net->net2name(@coords[$coord_i-1, $coord_i+1]);
	    $net->add_net($pos, @{$coords_ref}[$coord_i, $coord_i-1, $coord_i+1]);
	}
    }
}

sub del_add_points {
    $net->reset;
}

__END__
