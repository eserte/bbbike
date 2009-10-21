#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassennetz.t,v 1.23 2009/02/05 22:19:09 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin",
	);
use Getopt::Long;
use Data::Dumper qw(Dumper);
use Storable qw(dclone);

use Strassen::Core;
use Strassen::Util;
use Strassen::Lazy;
use Strassen::StrassenNetz;
use Route;
use Route::Heavy;

use BBBikeTest;

BEGIN {
    if (!eval q{
	use Test::More;
	use List::Util qw(sum);
	1;
    }) {
	print "1..0 # skip: no Test::More and/or List::Util module\n";
	exit;
    }
}

plan tests => 48;

print "# Tests may fail if data changes\n";

if (!GetOptions(get_std_opts(qw(xxx)))) {
    die "usage: $0 [-xxx]";
}

my $s		  = Strassen::Lazy->new("strassen");
my $s_net	  = StrassenNetz->new($s);
$s_net->make_net(UseCache => 1);

my $qs              = Strassen::Lazy->new("qualitaet_s");
my $comments_path   = Strassen::Lazy->new("comments_path");
my $comments_scenic = Strassen::Lazy->new("comments_scenic");

if ($do_xxx) {
    goto XXX;
}

{
    # Melchiorstr.: mäßiger Asphalt	Q1; 11726,11265 11542,11342
    my $coords = "11542,11342 11726,11265";
    my $route  = [map { [split /,/] } split /\s+/, $coords];

    {
	pass("-- Melchiorstr.: einseitige Qualitätsangabe --");

	my $net = StrassenNetz->new($qs);
	$net->make_net_cat(-obeydir => 1, -net2name => 1);
	my $route = dclone $route;
	is($net->get_point_comment($route, 0, undef), 0, "Without multiple");
	$route = [ reverse @$route ];
	like(($net->get_point_comment($route, 0, undef))[0], qr/mäßiger Asphalt/i);
    }

    {
	pass("-- Melchiorstr.: einseitige Qualitätsangabe (dito) --");

	my $net = StrassenNetz->new($qs);
	$net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);
	my $route = dclone $route;
	is(scalar $net->get_point_comment($route, 0, undef), 0, "With multiple");
	$route = [ reverse @$route ];
	like(($net->get_point_comment($route, 0, undef))[0], qr/mäßiger Asphalt/i);
    }
}

XXX:
{
    my $net = StrassenNetz->new($comments_path);
    $net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);

    {
	pass("-- CP;-Kommentar Buchholzer/Schönhauser Allee --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 11055,15504 10917,15525 10902,15422
			) ];
	my $comment;
	($comment) = $net->get_point_comment($route, 0, undef);
	is($comment, undef, "No CP; comment for begin point")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 1, undef);
	like($comment, qr{auf der linken}i, "CP; comment only at middle point")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 2, undef);
	is($comment, undef, "No CP; comment for end point")
	    or diag $comment;
    }

    {
	# XXX Note that this comment will probably move to comments_misc some day!
	pass("-- CP-Kommentar (beide Richtungen) Rampe Nähe Götzstr. --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 9453,6415 9404,6392 9389,6348
			) ];
	my $comment;
	for my $pass (1, 2) {
	    if ($pass == 2) {
		@$route = reverse @$route;
	    }

	    ($comment) = $net->get_point_comment($route, 0, undef);
	    is($comment, undef, "No CP comment for begin point, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 1, undef);
	    like($comment, qr{flache Rampe zum Umfahren der Treppen benutzen}i, "CP comment only at middle point, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 2, undef);
	    is($comment, undef, "No CP comment for end point, pass $pass")
		or diag $comment;
	}
    }

    {
	pass("-- CS;-Kommentar Hausdurchfahrt Müggelstr. --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 14794,11770 14855,11737 14837,11706 14764,11591
			) ];
	my $comment;
	($comment) = $net->get_point_comment($route, 0, undef);
	is($comment, undef, "No CS; comment for first point in route")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 1, undef);
	like($comment, qr{hausdurchfahrt}i, "CS; comment for beginning point in feature")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 2, undef);
	is($comment, undef, "No CS; comment for end point in feature")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 3, undef);
	is($comment, undef, "No CS; comment for last point in route")
	    or diag $comment;
    }
}

{
    my $net = StrassenNetz->new($comments_scenic);
    $net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);

    {
	pass("-- CS-Kommentar (beide Richtungen) Naturlehrpfad --");

	my $route =
	    [ map { [ split /,/ ] } split / /,
	      "4911,24299 5216,24157 5535,24016 5645,23968 5693,24037"
	    ];
	my $comment;

	for my $pass (1, 2) {
	    if ($pass == 2) {
		@$route = reverse @$route;
	    }

	    ($comment) = $net->get_point_comment($route, 0, undef);
	    is($comment, undef, "No CS comment for first point in route, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 1, undef);
	    like($comment, qr{Landschaftlich sehr schön}i, "CS comment for first point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 2, undef);
	    like($comment, qr{Landschaftlich sehr schön}i, "CS comment for second point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 3, undef);
	    is($comment, undef, "No CS comment for last point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 4, undef);
	    is($comment, undef, "No CS comment for last point in route, pass $pass")
		or diag $comment;
	}
    }
}

{
    pass("-- Scharnweber - Lichtenrader Damm --");

    my $c1 = "4695,17648"; # Scharnweberstr.
    my $c2 = "10524,655"; # Lichtenrader Damm
    for my $c ($c1, $c2) { # points may move ... fix it!
	$c = $s_net->fix_coords($c);
    }
    my($path) = $s_net->search($c1, $c2);
    my(@route) = $s_net->route_to_name($path);
    my $dist1 = int sum map { $_->[StrassenNetz::ROUTE_DIST] } @route;
    my(@compact_route) = $s_net->compact_route(\@route);
    my $dist2 = int sum map { $_->[StrassenNetz::ROUTE_DIST] } @compact_route;
    is($dist1, $dist2, "Distance the same after compaction");
    cmp_ok(scalar(@compact_route), "<", scalar(@route), "Actually less hops in compacted route");
}

{
    pass("-- Bug reported by Dominik --");

    $TODO = "In some strange circumstances, angle may be undef";
    my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[-3011,10103],[-2761,10323],[-2766,10325],[-2761,10323],[-2571,10258]];
$search_route_points_ref = [['-3011,10103','m'],['-2766,10325','a'],['-2571,10258','a']];
EOF
    my $ret = Route::load_from_string($route);
    my $path = $ret->{RealCoords};
    my(@route) = $s_net->route_to_name($path);
    my $got_undef = 0;
    for (@route) { $got_undef++ if !defined $_->[StrassenNetz::ROUTE_ANGLE] }
    is($got_undef, 0);
}

{
    # Bug reported by Andreas Wirsing, but was already known to me

    {
	# Wilhelmstr. - Stresemannstr.
	my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[9392,10260], [9376,10393], [9250,10563]];
EOF
	my $ret = Route::load_from_string($route);
	my $path = $ret->{RealCoords};
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));

	# Add another point before start. This triggers a special case
	# in route_to_name with combinestreet set (which is default)
	unshift @$path, [9395,10233];
	(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (longer Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));

	# And add yet another point before start, just to see if everything
	# is right if ImportantAngle is set to the *2nd* street in route
	unshift @$path, [9401,10199];
	(@route) = $s_net->route_to_name($path);
	is($route[1][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (Mehringdamm -> Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));
    }

    {
	# gleiche Kreuzung, Wilhelmstr. geradeaus
	my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[9392,10260], [9376,10393], [9366,10541]];
EOF
	my $ret = Route::load_from_string($route);
	my $path = $ret->{RealCoords};
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, undef, "Important angle not set here (Wilhelmstr.)")
	    or diag(Dumper(\@route));
    }

    {
	# Martin-Luther-Str. -> Dominicusstr.
	my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[6470,8809], [6470,8681], [6590,8469]];
EOF
	my $ret = Route::load_from_string($route);
	my $path = $ret->{RealCoords};
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (Martin-Luther-Str. ->Dominicusstr.)")
	    or diag(Dumper(\@route));

	# reverse route: "geradeaus" ist OK
	@$path = reverse @$path;
	(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, undef, "Important angle not set now (Dominicusstr. -> Martin-Luther-Str.)")
	    or diag(Dumper(\@route));

    }

    {
	# gleiche Kreuzung, Martin-Luther-Str. geradeaus
	my $route = <<'EOF';
#BBBike route
$realcoords_ref = [[6470,8809], [6470,8681], [6471,8639]];
EOF
	my $ret = Route::load_from_string($route);
	my $path = $ret->{RealCoords};
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, undef, "Important angle not set here (Martin-Luther-Str.)")
	    or diag(Dumper(\@route));
    }
}

{
    # Check for nearest_node output (find nearest reachable point if
    # the selected goal is not reachable)
    my $c1 = "11242,11720"; # Brückenstr./Köpenicker Str. (Mitte)
    my $c2 = "10921,12057"; # mitten in der Spree (not reachable!)
    $c1 = $s_net->fix_coords($c1); # start point may move
    my($r) = $s_net->search($c1, $c2, AsObj => 1);
    ok(!$r->path, "Found no path");
    ok($r->nearest_node, "Found a nearest node with distance " . int(Strassen::Util::strecke_s($c2, $r->nearest_node)) . "m");
    my($r2) = $s_net->search($c1, $r->nearest_node, AsObj => 1);
    ok($r2->path, "Now found a path");
}

__END__
