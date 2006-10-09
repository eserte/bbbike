#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassennetz.t,v 1.16 2006/10/07 13:27:13 eserte Exp $
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

use Strassen::Core;
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

plan tests => 38;

print "# Tests may fail if data changes\n";

if (!GetOptions(get_std_opts(qw(xxx)))) {
    die "usage: $0 [-xxx]";
}

my $s		  = Strassen::Lazy->new("strassen");
my $s_net	  = StrassenNetz->new($s);
$s_net->make_net(UseCache => 1);

my $qs            = Strassen::Lazy->new("qualitaet_s");
my $comments_path = Strassen::Lazy->new("comments_path");

if ($do_xxx) {
    goto XXX;
}

my $bahnhofstr_coords = "16962,15440 16898,15453 16819,15495";
my $bahnhofstr_route  = [map { [split /,/] } split /\s+/, $bahnhofstr_coords];
{
    pass("-- Bahnhofstr. (Hohenschönhausen): einseitiges Kopfsteinpflaster --");

    my $net = StrassenNetz->new($qs);
    $net->make_net_cat(-obeydir => 1, -net2name => 1);
    my $route = $bahnhofstr_route;
    is($net->get_point_comment($route, 1, undef), 0, "Without multiple");
    $route = [ reverse @$route ];
    like(($net->get_point_comment($route, 1, undef))[0], qr/kopfstein/i);
}

{
    pass("-- Bahnhofstr. (Hohenschönhausen): einseitiges Kopfsteinpflaster (dito) --");

    my $net = StrassenNetz->new($qs);
    $net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);
    my $route = $bahnhofstr_route;
    is(scalar $net->get_point_comment($route, 1, undef), 0, "With multiple");
    $route = [ reverse @$route ];
    like(($net->get_point_comment($route, 1, undef))[0], qr/kopfstein/i);
}

{
    my $net = StrassenNetz->new($comments_path);
    $net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);

    {
	pass("-- CP;-Kommentar Buchholzer/Schönhauser Allee --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 11055,15504 10930,15522 10917,15418
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
	pass("-- CP-Kommentar (beide Richtungen) Sonnenallee/Treptower --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 13478,8095 13459,8072 13376,7970
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
	    like($comment, qr{Ampel.*benutzen}i, "CP comment only at middle point, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 2, undef);
	    is($comment, undef, "No CP comment for end point, pass $pass")
		or diag $comment;
	}
    }

    {
	pass("-- CS;-Kommentar Henriettenplatz --");

	my $route = [[2702,10006], [2770,10024], [2770,9945], [3044,9621]];
	my $comment;
	($comment) = $net->get_point_comment($route, 0, undef);
	is($comment, undef, "No CS; comment for first point in route")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 1, undef);
	like($comment, qr{zufahrt}i, "CS; comment for beginning point in feature")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 2, undef);
	is($comment, undef, "No CS; comment for end point in feature")
	    or diag $comment;
	($comment) = $net->get_point_comment($route, 3, undef);
	is($comment, undef, "No CS; comment for last point in route")
	    or diag $comment;
    }

    {
	pass("-- CS-Kommentar (beide Richtungen) Jüdenstr. --");

	my $route =
	    [ map { [ split /,/ ] } split / /,
	      "10704,12595 10778,12493 10800,12461 10831,12371 10825,12271"
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
	    like($comment, qr{unbequem}i, "CS comment for first point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 2, undef);
	    like($comment, qr{unbequem}i, "CS comment for second point in feature, pass $pass")
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

XXX:
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

__END__
