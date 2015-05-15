#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use Route ();
use Route::Heavy ();
use Strassen::Core ();

plan 'no_plan';

{
    # Same bbd data, just differing in coordinate system
    my $bbd1 = <<EOF;
Route	#ff0000 -11023.6731754748,336.440822258592 -11003.5533843057,346.813496466726 -10997.6307243751,349.812016567215
EOF
    my $bbd2 = <<EOF;
#: map: polar
#:
Route	#ff0000 13.085528,52.412301 13.085827,52.412391 13.085915,52.412417
EOF

    my $r1 = Route->new_from_strassen(Strassen->new_from_data_string($bbd1));
    my $r2 = Route->new_from_strassen(Strassen->new_from_data_string($bbd2));
    isa_ok $r1, 'Route';
    cmp_ok $r1->len, ">=", 28;
    cmp_ok $r1->len, "<=", 31;
    is_deeply $r1->path->[0], [-11023.6731754748,336.440822258592];
    is_deeply $r2, $r1, 'Both routes are the same';
}

{
    my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[-3011,10103],[-2761,10323],[-2766,10325],[-2761,10323],[-2571,10258]];
$search_route_points_ref = [['-3011,10103','m'],['-2766,10325','a'],['-2571,10258','a']];
EOF
    my $ret = Route::load_from_string($route);
    my $path = $ret->{RealCoords};
    is_deeply $path, [[-3011,10103],[-2761,10323],[-2766,10325],[-2761,10323],[-2571,10258]], 'load_from_string path';
    my $search_route_points = $ret->{SearchRoutePoints};
    is_deeply $search_route_points, [['-3011,10103','m'],['-2766,10325','a'],['-2571,10258','a']], 'load_from_string search_route_points';
}

{
    my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[9404,10250], [9388,10393], [9250,10563]];
EOF
    my $ret = Route::load_from_string($route);
    my $path = $ret->{RealCoords};
    is_deeply $path, [[9404,10250], [9388,10393], [9250,10563]], 'load_from_string path 2nd';
    my $search_route_points = $ret->{SearchRoutePoints};
    is_deeply $search_route_points, [['9404,10250', 'm'], ['9250,10563', 'm']], 'implicit search_route_points';
}

__END__
