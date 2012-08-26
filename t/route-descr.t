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

use BBBikeTest qw(using_bbbike_test_cgi);

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

using_bbbike_test_cgi;
local $Strassen::Util::cacheprefix = $Strassen::Util::cacheprefix = "test_b_de";

my $net = StrassenNetz->new(Strassen->new("$FindBin::RealBin/data/strassen"));
$net->make_net;
my %stdargs = (-net => $net);

no warnings 'qw'; # because of (x,y)

{
    my @coords = map {[split /,/]} qw(8291,8773 8425,8775 8472,8776 8594,8777 8763,8780 8982,8781 9063,8935 9111,9036 9115,9046 9150,9152 9170,9206 9211,9354 9248,9350 9280,9476 9334,9670 9387,9804 9334,9670 9280,9476 9248,9350 9225,9111 9224,9053 9225,9038 9227,8890 9229,8785);
    {
	my $out = Route::Descr::convert(%stdargs, -route => Route->new_from_realcoords([@coords]));
	is_deeply($out, {
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
		  'Route::Descr output, German, simple route',
		 );
    }
    {
	my $out = Route::Descr::convert(%stdargs, -lang => 'en', -route => Route->new_from_realcoords([@coords]));
	is_deeply($out, {
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
		  'Route::Descr output, English, simple route',
		 );
    }
}

__END__
