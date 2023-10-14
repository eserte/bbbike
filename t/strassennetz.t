#!/usr/bin/perl -w
# -*- perl -*-

#
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

use BBBikeUtil qw(sum);
use Strassen::Core;
use Strassen::Util;
use Strassen::Lazy;
use Strassen::StrassenNetz;

use BBBikeTest;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my $have_nowarnings;
BEGIN {
    $have_nowarnings = 1;
    eval 'use Test::NoWarnings ":early"';
    if ($@) {
	$have_nowarnings = 0;
	#warn $@;
    }
}

plan tests => 80 + $have_nowarnings;

print "# Tests may fail if data changes\n";

my $use_cache = 1;
if (!GetOptions(get_std_opts(qw(xxx)),
		'no-cache' => sub { $use_cache = 0 },
		'verbose|v' => sub { $Strassen::VERBOSE = $StrassenNetz::VERBOSE = 1 },
	       )) {
    die "usage: $0 [-xxx] [-no-cache] [-verbose|-v]\n";
}

my $s		  = Strassen::Lazy->new("strassen");
{
    my $i_s = new Strassen "inaccessible_strassen";
    $s = $s->new_with_removed_points($i_s);
}
my $s_net	  = StrassenNetz->new($s);
$s_net->make_net(UseCache => 0);
$s_net->make_sperre(
		    'gesperrt',
		    Type => [qw(einbahn sperre wegfuehrung)],
		   );

my $qs              = Strassen::Lazy->new("qualitaet_s");
my $comments_path   = Strassen::Lazy->new("comments_path");
my $comments_scenic = Strassen::Lazy->new("comments_scenic");
my $comments_route  = Strassen::Lazy->new("comments_route");

if ($do_xxx) {
    goto XXX;
}

{
    # Winckelmannstr.: Kopfsteinpflaster Richtung S�den
    my $coords = "17507,4216 17476,4337";
    my $route  = [map { [split /,/] } split /\s+/, $coords];

    {
	pass("-- Winckelmannstr.: einseitige Qualit�tsangabe --");

	my $net = StrassenNetz->new($qs);
	$net->make_net_cat(-usecache => $use_cache, -obeydir => 1, -net2name => 1);
	my $route = dclone $route;
	is($net->get_point_comment($route, 0, undef), 0, "Without multiple");
	$route = [ reverse @$route ];
	like(($net->get_point_comment($route, 0, undef))[0], qr/Kopfsteinpflaster sowie asphaltierter Gleisbereich/i);
    }

    {
	pass("-- Winckelmannstr.: einseitige Qualit�tsangabe (dito) --");

	my $net = StrassenNetz->new($qs);
	$net->make_net_cat(-usecache => $use_cache, -obeydir => 1, -net2name => 1, -multiple => 1);
	my $route = dclone $route;
	is(scalar $net->get_point_comment($route, 0, undef), 0, "With multiple");
	$route = [ reverse @$route ];
	like(($net->get_point_comment($route, 0, undef))[0], qr/Kopfsteinpflaster sowie asphaltierter Gleisbereich/i);
    }
}

{
    my $net = StrassenNetz->new($comments_path);
    $net->make_net_cat(-usecache => $use_cache, -obeydir => 1, -net2name => 1, -multiple => 1);

    {
	pass("-- CP;-Kommentar Buchholzer/Sch�nhauser Allee --");

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
	pass("-- CP-Kommentar (beide Richtungen) Rampe N�he G�tzstr. --");

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
	pass("-- CS;-Kommentar Hausdurchfahrt M�ggelstr. --");

	no warnings qw(qw);
	my $route = [ map { [ split /,/ ] }
		      qw(
			 14798,11777 14858,11744 14837,11706 14764,11591
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
    $net->make_net_cat(-usecache => $use_cache, -obeydir => 1, -net2name => 1, -multiple => 1);

    {
	pass("-- CS-Kommentar (beide Richtungen) Naturlehrpfad --");

	my $route =
	    [ map { [ split /,/ ] } split / /,
	      "5136,24201 5182,24183 5253,24190 5363,24109 5408,24068 5545,23993 5621,23966 5676,23971 5780,23997"
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
	    like($comment, qr{Landschaftlich sehr sch�n}i, "CS comment for first point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 2, undef);
	    like($comment, qr{Landschaftlich sehr sch�n}i, "CS comment for second point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 7, undef);
	    is($comment, undef, "No CS comment for last point in feature, pass $pass")
		or diag $comment;
	    ($comment) = $net->get_point_comment($route, 8, undef);
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

    my $path = [[-3011,10103],[-2761,10323],[-2766,10325],[-2761,10323],[-2571,10258]];
    my(@route) = $s_net->route_to_name($path);
    my $got_undef = 0;
    for (@route[0..$#route-1]) { $got_undef++ if !defined $_->[StrassenNetz::ROUTE_ANGLE] }
    is($got_undef, 0);

}

{
    # Bug reported by Andreas Wirsing, but was already known to me

    {
	# Wilhelmstr. - Stresemannstr.
	my $path = [[9404,10250], [9388,10393], [9250,10563]];
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));

	# Add another point before start. This triggers a special case
	# in route_to_name with combinestreet set (which is default)
	unshift @$path, [9409,10226];
	(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (longer Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));

	# And add yet another point before start, just to see if everything
	# is right if ImportantAngle is set to the *2nd* street in route
	unshift @$path, [9416,10196];
	(@route) = $s_net->route_to_name($path);
	is($route[1][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, '!', "Found an important angle (Mehringdamm -> Wilhelmstr. -> Stresemannstr.)")
	    or diag(Dumper(\@route));
    }

    {
	# gleiche Kreuzung, Wilhelmstr. geradeaus
	my $path = [[9404,10250], [9388,10393], [9378,10539]];
	my(@route) = $s_net->route_to_name($path);
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, undef, "Important angle not set here (Wilhelmstr.)")
	    or diag(Dumper(\@route));
    }

    {
	# Martin-Luther-Str. -> Dominicusstr.
	my $path = [[6449,8807], [6460,8688], [6575,8469]];
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
	my $path = [[6449,8807], [6460,8688], [6454,8653]];
	my(@route) = $s_net->route_to_name($path);
	like($route[0][0], qr{Martin-Luther-Str}, "we're really on the Martin-Luther-Str.")
	    or diag("Check coordinates if this test fails");
	is($route[0][StrassenNetz::ROUTE_EXTRA]{ImportantAngle}, undef, "Important angle not set here (Martin-Luther-Str.)")
	    or diag(Dumper(\@route));
    }
}

{
    # Bug reported (sort-of) by Felix Weiland
    # a '3nocross' was acting badly on a route on Pankeweg via Badstr.
    # -> it was not used at all!
    my $start = '8759,16684'; # Pankeweg, north of Badstr.
    my $goal  = '8389,16214'; # Pankeweg, south of Badstr.
    for my $c ($start, $goal) { # points may move ... fix it!
	$c = $s_net->fix_coords($c);
    }

    {
	my($path) = $s_net->search($start, $goal);
	my(@route) = $s_net->route_to_name($path);
	my @street_names = map { $_->[StrassenNetz::ROUTE_NAME] } @route;
	like "@street_names", qr{Travem�nder Str.*Zugang zum Pankeweg.*Badstr.*Gropiusstr.};
	unlike "@street_names", qr{Badstr.*linker Gehweg};
    }

    {
	my($path) = $s_net->search($goal, $start);
	my(@route) = $s_net->route_to_name($path);
	my @street_names = map { $_->[StrassenNetz::ROUTE_NAME] } @route;
	like "@street_names", qr{Gropiusstr.*Badstr.*linker Gehweg.*Zugang zum Pankeweg.*Travem�nder Str};
    }
}

{ # Another ImportantAngle problem. Also check for new
  # ImportantAngleCrossingName feature.
    no warnings qw(qw);
    # Regattastr. -> Sportpromenade (Schm�ckwitz)
    my $route = [map { [split /,/] } qw(23085,898 23252,792 23501,797 23681,800 23955,728 24019,711)];
    my @res = $s_net->route_to_name($route);
    ok $res[0]->[StrassenNetz::ROUTE_EXTRA]->{ImportantAngle}, 'Important angle is defined';
    is $res[0]->[StrassenNetz::ROUTE_EXTRA]->{ImportantAngleCrossingName}, 'Rabindranath-Tagore-Str.', 'ImportantAngleCrossingName';
    is $res[0]->[StrassenNetz::ROUTE_NAME], $res[1]->[StrassenNetz::ROUTE_NAME], 'Route name appears twice';
}

{
    # Check for nearest_node output (find nearest reachable point if
    # the selected goal is not reachable)
    my $c1 = "11242,11720"; # Br�ckenstr./K�penicker Str. (Mitte)
    my $c2 = "10921,12057"; # mitten in der Spree (not reachable!)
    $c1 = $s_net->fix_coords($c1); # start point may move
    my($r) = $s_net->search($c1, $c2, AsObj => 1);
    ok(!$r->path, "Found no path");
    ok($r->nearest_node, "Found a nearest node with distance " . int(Strassen::Util::strecke_s($c2, $r->nearest_node)) . "m");
    my($r2) = $s_net->search($c1, $r->nearest_node, AsObj => 1);
    ok($r2->path, "Now found a path");
}

{
    pass("-- A bug happening on the radroute.html page --");

    # Twice the same coord in the route, use to cause a division by
    # zero error somewhere
    my $path = [[-3025,10116],[-2774,10345],[-2774,10345],[-2766,10325]];
    my(@route) = eval { $s_net->route_to_name($path) };
    is $@, '', 'No division by zero error';
}

{
    # Sketching the handling of "2" vs. "3" records in temp-blockings.
    my $s = Strassen->new_from_data_string(<<EOF);
userdel	3 13150,7254 13047,7234 13058,7165
userdel	3 13058,7165 13047,7234 13150,7254
userdel	3 13150,7254 13047,7234 13034,7319
userdel	3 13034,7319 13047,7234 13150,7254
userdel	2::inwork 46581,105900 47587,106693
EOF
    my $s_3    = $s->grepstreets(sub { $_->[Strassen::CAT] eq '3' });
    my $s_non3 = $s->grepstreets(sub { $_->[Strassen::CAT] ne '3' });
    my $net = StrassenNetz->new($s_non3);
    $net->make_net_cat(-usecache => $use_cache, -onewayhack => 1);
    $net->make_sperre($s_3, Type => ['wegfuehrung']);
    is scalar keys %{$net->{Net}}, 2, 'Only the "blocked" records in Net';
    is scalar keys %{$net->{Wegfuehrung}}, 3, 'The "wegfuehrung" records'
	or diag Dumper($net->{Wegfuehrung});
}

{
    # stack and pop_stack

    # Create net with existing record
    my($k1,$v1);
    while(($k1,$v1) = each %{$s_net->{Net}}) {
	last if defined $v1;
	# $v1 may be undefined if $k1 is part of
	# inaccessible_strassen
	# --- probably this should not happen anymore,
	# as points from inaccessible_strassen are filtered out
    }
    keys %{$s_net->{Net}}; # reset iterator
    my($k2,$v2) = each %$v1;
    keys %$v1; # reset iterator
    my $add_s1 = Strassen->new_from_data_string(<<EOF);
something	XYZ $k1 $k2
EOF
    my $add_net1 = StrassenNetz->new($add_s1);
    $add_net1->make_net_cat(-usecache => $use_cache, -onewayhack => 1);

    # Create net with completely new record
    my $new_k1  = '1234567,987654';
    my $new_k2  = '-1234,-4321';
    my $new_cat = 'ABC';
    my $add_s2 = Strassen->new_from_data_string(<<EOF);
something new	$new_cat $new_k1 $new_k2
EOF
    my $add_net2 = StrassenNetz->new($add_s2);
    $add_net2->make_net_cat(-usecache => $use_cache, -onewayhack => 1);

    $s_net->push_stack($add_net1);
    is $s_net->{Net}{$k1}{$k2}, 'XYZ', 'Stacked value (overwriting old)'
	or diag "Random line is $k1 - $k2, original value '$v2'";

    $s_net->push_stack($add_net2);
    is $s_net->{Net}{$new_k1}{$new_k2}, $new_cat, 'Stacked value (newly added)';

    $s_net->pop_stack;
    ok !exists $s_net->{Net}{$new_k1}{$new_k2}, 'Original value --- does not exist';

    $s_net->pop_stack;
    is $s_net->{Net}{$k1}{$k2}, $v2, 'Original value';

    eval { $s_net->pop_stack };
    ok $@, 'Cannot pop_stack from empty stack';
}

{
    # make_sperre tests
    my $s = Strassen->new_from_data_string(<<EOF);
Street	H 0,0 10,0 20,0 30,0 40,0 50,0 60,0 70,0
EOF
    my $sperre = Strassen->new_from_data_string(<<EOF);
One way	1 0,0 10,0
One way non-strict	1s 10,0 20,0
One way with attrib	1::igndisp 20,0 30,0
Blocked	2 30,0 40,0
Blocked with attrib	2:inwork 40,0 50,0
Wegfuehrung	3 50,0 60,0
Wegfuehrung with attrib	3::igndisp 60,0 70,0
BNP	BNP:5:90	50,0
Tragen	0:30:90	60,0
EOF
    my $net = StrassenNetz->new($s);
    $net->make_net;
    $net->make_sperre($sperre, Type => 'all', DelToken => 'removable_test');

    ok $net->{Net}{'10,0'}{'0,0'}, 'One way, open';
    ok !$net->{Net}{'0,0'}{'10,0'}, 'One way, closed';
    ok !$net->{Net}{'10,0'}{'20,0'}, 'One way, non-strict, closed';
    ok !$net->{Net}{'20,0'}{'30,0'}, 'One way, with attrib, closed';
    ok !$net->{Net}{'30,0'}{'40,0'}, 'Blocked';
    ok !$net->{Net}{'40,0'}{'30,0'}, 'Blocked, other direction';
    ok $net->{Wegfuehrung}{'60,0'}, 'Wegfuehrung';
    # XXX bnp/tragen tests missing

    $net->remove_all_from_deleted(undef, 'removable_test');
    ok $net->{Net}{'10,0'}{'0,0'}, 'One way, open, unchanged';
    ok $net->{Net}{'0,0'}{'10,0'}, 'One way removed';
    ok $net->{Net}{'10,0'}{'20,0'}, 'Another one way, non-strict, removed';
    ok $net->{Net}{'20,0'}{'30,0'}, 'One way, with attrib, removed';
    ok $net->{Net}{'30,0'}{'40,0'}, 'Blocked, removed';
    ok $net->{Net}{'40,0'}{'30,0'}, 'Blocked, other direction, removed';
    ok !$net->{Wegfuehrung}{'60,0'}, 'Wegfuehrung removed';
}

XXX:
{
    pass("-- Preserve order of comments --");

    my $name = "Oberbaumbruecke";
    my $route = [[13305,10789],[13206,10651]];
    my @expected_cycleroutes = ('R1', 'Spreeradweg', 'Berliner Mauerweg');

    my $net = StrassenNetz->new($comments_route);
    $net->make_net_cat(-usecache => $use_cache, -obeydir => 1, -net2name => 1, -multiple => 1);
    my @cycleroutes = $net->get_point_comment($route, 0, undef, AsIndex => 0);
    is_deeply \@cycleroutes, \@expected_cycleroutes, 'expected cycleroutes'
	or diag <<"EOF";

If this test fails, then check two things:
* sort order of routes changed in the file data/comments_route
* cycle routes via $name were renamed, removed, or new ones added

EOF
}
__END__
