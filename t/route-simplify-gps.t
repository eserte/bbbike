#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use utf8;
no warnings 'qw';
use FindBin;
use lib (
	 "$FindBin::RealBin/..", 
	 "$FindBin::RealBin/../lib", 
	 $FindBin::RealBin,
	);

use Route ();
use Route::Simplify ();
use Strassen ();
use Strassen::StrassenNetz ();

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeTest qw(using_bbbike_test_data);

using_bbbike_test_data;

plan 'no_plan';

my $s = Strassen->new("strassen");
my $s_net = StrassenNetz->new($s);
$s_net->make_net;
my $comments_net = StrassenNetz->new(Strassen->new("comments_path"));
$comments_net->make_net_cat(-net2name => 1,
			    -multiple => 1,
			    -obeydir => 1);

{
    my @path = map { [ split /,/ ] } qw(15420,12178 15361,12071 15294,11964 15317,11953);
    my $route = Route->new_from_realcoords(\@path);
    my $routetoname = [ $s_net->route_to_name($route->path) ];

    my @std_args = ($route, -streetobj => $s, -netobj => $s_net);
    my @std_routetoname_args = (@std_args, -routetoname => $routetoname);

    {
	my $simplified_route = Route::simplify_for_gps(@std_args);
	like $simplified_route->{routename}, qr{^Route\d{8}$}, 'Route name with date';
	is $simplified_route->{routenumber}, 1;
	is_deeply $simplified_route->{idents}, {
						0 => 1,
						1 => 1,
						"GURTEL+WIL" => 1,
						"MOLLENDORF" => 1,
					       }, 'Seen idents';
	is $simplified_route->{wpt}->[0]->{origlon}, $path[0][0];
	is $simplified_route->{wpt}->[0]->{origlat}, $path[0][1];

	is $simplified_route->{wpt}->[-1]->{origlon}, $path[-1][0];
	is $simplified_route->{wpt}->[-1]->{origlat}, $path[-1][1];

	like $simplified_route->{wpt}->[0]->{lat}, qr{^52\.5}, 'looks like a latitude';
	like $simplified_route->{wpt}->[0]->{lon}, qr{^13\.4}, 'looks like a longitude';

	# Note that "MOLLENDORF" is suboptimal here... the full
	# waypoint name is 'MOLLENDORFFSTR+FRANKFURTER ALLEE+GURTELSTR',
	# but in this mode there's no good ordering of the street names
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], [0, 'MOLLENDORF', 'GURTEL+WIL', 1], 'Idents in path';
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_args, -routename => "My Route", -routenumber => 2);
	is $simplified_route->{routename}, 'My Route';
	is $simplified_route->{routenumber}, 2;
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_args, -wptsuffix => 'sfx');
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], ['SFX', 'MOLLENDSFX', 'GURTEL+SFX', '0SFX'], 'Idents in path with suffix';
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_args, -waypointlength => 14);
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], [0, 'MOLLENDORFF+FR', 'GURTEL+WILHELM', 1], 'Longer waypoint length';
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_args, -waypointlength => 14, -waypointcharset => 'latin1');
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], ['.', 'Möllendorff+Fr', 'Gürtel+Wilhelm', '..'], 'Waypoint charset is latin1';
    }

    {
	my $waypointscache = { '0' => 1 };
	my $simplified_route = Route::simplify_for_gps(@std_args, -waypointscache => $waypointscache);
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], [1, 'MOLLENDORF', 'GURTEL+WIL', 2], 'pre-populated waypoints cache';
    }

    ######################################################################
    # routetoname tests
    {
	my $simplified_route = Route::simplify_for_gps(@std_routetoname_args);
	is $simplified_route->{routename}, 'Mollen-Wilhel', 'Route name built from start and goal';
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], ['MOLLENDORF', 'GURTEL+FRA', 'WILHELM-GU', 0], 'Idents in path (with routetoname)';
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_routetoname_args, -waypointlength => 14, -waypointcharset => 'latin1');
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], ['Möllendorffstr', 'Gürtel+Frankfu', '(- Wilhelm-Gud', '.'], 'Waypoint charset is latin1 (with routetoname)';
    }

    {
	my $simplified_route = Route::simplify_for_gps(@std_routetoname_args, -waypointlength => 14, -waypointcharset => 'latin1', -leftrightpair => ['<-', '->']);
	is_deeply [ map { $_->{ident} } @{ $simplified_route->{wpt} } ], ['Möllendorffstr', 'Gürtel+Frankfu', '<-Wilhelm-Gudd', '.'], 'Changed left/right arrows';
    }
}

# Missing tests
# - "routetoname" mode (and providing -routenamelength and calculating route name from start/goal)

__END__
