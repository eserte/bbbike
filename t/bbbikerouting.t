#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikerouting.t,v 1.16 2004/03/23 00:09:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");
use BBBikeRouting;
use Strassen::Util;
use Benchmark;
use Getopt::Long;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys = 1;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "# tests only work with installed Test::More module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

my $num_tests = 63; # basic number of tests

use vars qw($single $all $common $bench $v $do_xxx);

use vars qw($token %times $cmp_path
	    $usexs $algorithm $usenetserver $usecache $cachetype);

$common = 1;
if (!GetOptions("full|slow|all" => sub { $all = 1 },
		"single" => sub { $common = 0 },
		"bench" => \$bench,
		"v+" => \$v,
		"xxx" => \$do_xxx,

		"usexs!"        => sub { $common = 0; $usexs = $_[1] },
		"algorithm=s"   => sub { $common = 0; $algorithm = $_[1] },
		"usenetserver!" => sub { $common = 0; $usenetserver = $_[1] },
		"usecache!"     => sub { $common = 0; $usecache = $_[1] },
		"cachetype=s"   => sub { $common = 0; $cachetype = $_[1] },
	       )) {
    die "usage!";
}

if ($all) { $v = 1 }

if (defined $v && $v > 1) {
    require Strassen;
    Strassen::set_verbose(1);
}

system($^X, "$FindBin::RealBin/../miscsrc/bbbikestrserver", "-restart");

my @runs;

if ($common) {
    push @runs,
	([1, 0, 1, "CDB_File", "A*"], # standard bbbike with compilation
	 [1, 0, 1, "Storable", "A*"], # as above, without CDB_File
	 [1, 0, 1, "CDB_File", "C-A*"], # standard bbbike with C-A* set
	 [0, 0, 1, "Storable", "A*"], # standard bbbike without anything

	 [1, 0, 1, "CDB_File", "A*"], # cgi on radzeit (?)

	 [1, 0, 1, "CDB_File", "C-A*-2"], # radlstadtplan
	);
} elsif (!$all) {
    push @runs, [$usexs, $usenetserver, $usecache,
		 $cachetype, $algorithm];
} else {
    # run twice to get the cache effect!
    my @cachetypes;
    for (qw(CDB_File VirtArray Storable Data::Dumper)) {
	if (eval "require $_; 1") {
	    push @cachetypes, $_;
	} else {
	    warn "$_ is not available, not using as cache type\n";
	}
    }

    for $usexs (0, 1) {
	for $usenetserver (0, 1) {
	    for $usecache (0, 1) {
		my @trycache = $usecache ? @cachetypes : undef;
		for $cachetype (@trycache) {
		    for $algorithm ("C-A*-2", "C-A*", "A*") {
			# remove meaningless combinations:
			if ($algorithm =~ /^C-A*/) {
			    next if $usenetserver;
			    # $usexs is probably meaningful, because of some
			    # helper functions like strecke_XS
			}
			push @runs, [$usexs, $usenetserver, $usecache,
				     $cachetype, $algorithm];
		    }
		}
	    }
	}
    }
}

plan tests => $num_tests * @runs;

for my $rundef (@runs) {
    ($usexs, $usenetserver, $usecache, $cachetype, $algorithm)
	= @$rundef;
    if ($bench) {
	my $t = timeit(1, 'do_tests()');
	$times{$token} += $t->[$_] for (1..4);
    } else {
	if (@runs > 1) {
	    print "# xs=$usexs netserver=$usenetserver cache=$usecache cachetype=$cachetype algorithm=$algorithm\n";
	}
	do_tests();
    }
}


system($^X, "$FindBin::RealBin/../miscsrc/bbbikestrserver", "-stop");

if ($bench) {
    print STDERR join("\n",
		      map { "$_: $times{$_}" }
		      sort { $times{$a} <=> $times{$b} }
		      keys %times), "\n";
}

sub _my_init_context {
    my $context = shift;
    $context->Algorithm($algorithm)       if defined $algorithm;
    $context->UseXS($usexs)               if defined $usexs;
    $context->UseNetServer($usenetserver) if defined $usenetserver;
    $context->UseCache($usecache)         if defined $usecache;
    $context->MultipleChoices(0);
}

sub do_tests {

    my $routing = BBBikeRouting->new();

    is(ref $routing, "BBBikeRouting");
    $routing->init_context;
    my $context = $routing->Context;
    _my_init_context($context);

    if (!$all && $v) {
	diag Dumper($context);
    }
    if ($do_xxx) { goto XXX }

    @Strassen::Util::cacheable = $cachetype if defined $cachetype;
    if ("@Strassen::Util::cacheable" eq "VirtArray") {
	# VirtArray can only cache flat arrays ... add a fallback
	push @Strassen::Util::cacheable, "Storable";
    }
    $token = "Algorithm=".$context->Algorithm.", UseXS=".$context->UseXS.", UseNetServer=".$context->UseNetServer.", UseCache=".$context->UseCache.(defined $cachetype ? " ($cachetype)" : "");
    if ($v) {
	print STDERR "$token\n";
    }
    ok(1);

    $routing->Start->Street("Dudenstr");
    is($routing->Start->Street, "Dudenstr", "Check start street");
    $routing->Goal->Street("Sonntagstr/Böcklinstr.");
    is($routing->Goal->Street, "Sonntagstr/Böcklinstr.", "Check goal street");
    $routing->search;
    is($routing->Start->Street, "Dudenstr.", "Normalized start street");
    is($routing->Goal->Street, "Sonntagstr./Böcklinstr.", "Normalized goal street");
    my $goal_street = "Sonntagstr.";
    ok(scalar @{ $routing->Path } > 0, "Non-empty path");
    my $path = clone($routing->Path);
    ok(scalar @{ $routing->RouteInfo } > 0, "Non-empty route info");
    my $routeinfo = clone($routing->RouteInfo);
    {
	local $^W; # no "numeric" warning
	ok($routing->RouteInfo->[0]->{Whole} < $routing->RouteInfo->[-1]->{Whole}, "Positive distance");
    }
    is($routing->RouteInfo->[-1]->{Street}, $goal_street, "Goal street is really goal street");
    my $new_goal = BBBikeRouting::Position->new;
    $new_goal->Street("Alexanderplatz");
    $routing->continue($new_goal);
    is($routing->Goal->Street, "Alexanderplatz", "Continued to new goal");
    is(scalar @{$routing->Via}, 1, "With a new via");
    is($routing->Via->[0]->Street, "Sonntagstr./Böcklinstr.", "Correct via");
    $routing->search;
    is($routing->RouteInfo->[-1]->{Street}, $routing->Goal->Street);

    $routing->delete_to_last_via;
 SKIP: {
	eval {
	    Data::Dumper->VERSION(2.12); # Sortkeys
	};
	if ($@) {
	    skip("Need recent Data::Dumper (2.12)", 3);
	}

	is(Data::Dumper->new([$routing->Path],[])->Useqq(1)->Dump,
	   Data::Dumper->new([$path],[])->Useqq(1)->Dump);
	is(Data::Dumper->new([$routing->RouteInfo],[])->Useqq(1)->Dump,
	   Data::Dumper->new([$routeinfo],[])->Useqq(1)->Dump);

	if ($cmp_path) {
	    is(Data::Dumper->new([$cmp_path],[])->Useqq(1)->Dump,
	       Data::Dumper->new([$path],[])->Useqq(1)->Dump);
	} else {
	    $cmp_path = $path;
	    ok(1);
	}
    }

    my $custom_pos = BBBikeRouting::Position->new;
    $custom_pos->Street("???");
    $custom_pos->Coord("4711,1234");
    my $old_goal = $routing->Goal;
    $routing->add_position($custom_pos);
    is($routing->Goal->Coord, "4711,1234", "Added freehand position");
    is($routing->Via->[-1]->Coord, $old_goal->Coord);
    is($routing->RouteInfo->[-1]->{Coords}, join(",", @{$routing->Path->[-2]}));
    {
	local $^W = 0;
	like($routing->RouteInfo->[-1]->{Whole}, qr/km/);
	ok($routing->RouteInfo->[-1]->{Whole} > $routing->RouteInfo->[-2]->{Whole}, "Distance Ok");
    }

    {
	my $routing2 = BBBikeRouting->new;
	$routing2->init_context;
	_my_init_context($routing2->Context);
	$routing2->Start->Street("Kolonnenstr/Naumannstr");
	$routing2->Goal->Street("Hauptstr/Eisenacher");
	$routing2->search;
	ok(scalar @{ $routing2->RouteInfo } > 1, "Non-empty route info");
	is((grep { $_->{Street} =~ /kaiser.*wilhelm/i } @{$routing2->RouteInfo}),
	   0, "Obeying one-way streets");

	# Swapping start and goal:
	$routing2->Start->reset;
	$routing2->Goal->reset;
	$routing2->Start->Street("Hauptstr/Eisenacher");
	$routing2->Goal->Street("Kolonnenstr/Naumannstr");
	$routing2->search;
	ok(scalar @{ $routing2->RouteInfo } > 1, "Non-empty route info");
	is((grep { $_->{Street} =~ /kaiser.*wilhelm/i } @{$routing2->RouteInfo}),
	   1, "One-way in the right direction");

	# completely blocked streets
	$routing2->Start->reset;
	$routing2->Goal->reset;
	$routing2->Start->Street("Wexstr/Prinzregenten");
	$routing2->Goal->Street("Hauptstr/Wexstr");
	$routing2->search;
	ok(scalar @{ $routing2->RouteInfo } > 1, "Non-empty route info");
	is((grep { $_->{Street} =~ /wexstr/i } @{$routing2->RouteInfo}),
	   0, "Obeying completely blocked streets");

	# Wegfuehrung
	$routing2->Start->reset;
	$routing2->Goal->reset;
	$routing2->Start->Street("Paderborner/Eisenzahn");
	$routing2->Goal->Street("Düsseldorfer/Konstanzer");
	$routing2->search;
	ok(scalar @{ $routing2->RouteInfo } > 1, "Non-empty route info");
	is((grep { $_->{Street} =~ /düsseldorfer/i } @{$routing2->RouteInfo}),
	   0, "Obeying Wegfuehrung");
    }

    {
	my $routing2 = BBBikeRouting->new;
	$routing2->init_context;
	_my_init_context($routing2->Context);

	# add a freehand position
	my $custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("???");
	$custom_pos->Coord("4711,1234");
	$routing2->add_position($custom_pos);
	is($routing2->Start->Coord, "4711,1234", "Added freehand position");
	like($routing2->Start->Attribs, qr/\bfree\b/);
	ok(UNIVERSAL::isa($routing2->RouteInfo,"ARRAY"));
	ok(UNIVERSAL::isa($routing2->Path,"ARRAY"));
	is(join(",", @{$routing2->Path->[-1]}), "4711,1234");

	# add another freehand position
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("???");
	$custom_pos->Coord("1234,4711");
	$routing2->add_position($custom_pos);
	is($routing2->Goal->Coord, "1234,4711", "Added another freehand position");
	like($routing2->Goal->Attribs, qr/\bfree\b/);
	is(scalar @{$routing2->RouteInfo}, 1);
	is(scalar @{$routing2->Path}, 2);
	is(join(",", @{$routing2->Path->[-1]}), "1234,4711");
	is(join(",", @{$routing2->Path->[-2]}), "4711,1234");

	# now an existing position, but do _no_ search yet
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("Dudenstr.");
	$routing2->resolve_position($custom_pos);
	$routing2->add_position($custom_pos);
	is(scalar @{$routing2->RouteInfo}, 2, "Correct route info element count");
	is(scalar @{$routing2->Path}, 3, "Correct path element count");

	# again an existing position _with_ search
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("Alexanderplatz");
	$routing2->continue($custom_pos);
	$routing2->search;
	ok(1, "No errors while continuing search");
    }

    SKIP: {
	skip("No oepnv search with algorithm=$algorithm", 8)
	    if defined $algorithm && $algorithm eq 'C-A*-2';

	my $routing2 = BBBikeRouting->new();
	is(ref $routing2, "BBBikeRouting");
	$routing2->init_context;
	_my_init_context($routing2->Context);
	$routing2->Context->Vehicle("oepnv");
	$routing2->Start->Street("Platz der Luftbrücke");
	is($routing2->Start->Street, "Platz der Luftbrücke", "Station as start");
	$routing2->Goal->Street("Wannsee");
	is($routing2->Goal->Street, "Wannsee", "Station as goal");
	$routing2->search;
	# nach Wannsee kommt man nur mit der S- oder R-Bahn
	like($routing2->RouteInfo->[-1]->{Street}, qr/^[SR]\d+$/,
	     "Vehicle=oepnv test");

	# clear the positions and check it with street names
	$routing2->Start(BBBikeRouting::Position->new);
	$routing2->Goal(BBBikeRouting::Position->new);
	$routing2->Start->Street("Dudenstr.");
	$routing2->Goal->Street("Kronprinzessinnenweg");
	eval {
	    $routing2->search;
	};
	is($@, "") or diag("Error while searching: $@, Routing start object is: " . Dumper($routing2->Start) . " and goal object is: " . Dumper($routing2->Goal));
	is($routing2->Start->Street, "Platz der Luftbrücke", "Correct start");
	is($routing2->Goal->Street, "Wannsee", "Correct goal");
	like($routing2->RouteInfo->[-1]->{Street}, qr/^[SR]\d+$/,
	     "Route info contains S-Bahn/R-Bahn");
    }

    # changing the existing scope
    $routing->change_scope("wideregion");
    $routing->Start->Street("B2");
    $routing->Goal->Street("B96");
    $routing->search;
    like($routing->Start->Street, qr/^B2/); # normalized
    like($routing->Goal->Street, qr/^B96/); # normalized
    ok(scalar @{ $routing->Path } > 0, "scope=wideregion test");
    ok(scalar @{ $routing->RouteInfo } > 0);

 XXX:

    {
	# (Similar test in cgi.t)
	# this is critical --- both streets in the neighborhood of Berlin
	my $routing2 = BBBikeRouting->new;
	$routing2->init_context;
	_my_init_context($routing2->Context);
	$routing2->change_scope("region");
	my $start_pos = BBBikeRouting::Position->new;
	$start_pos->Street("Otto-Nagel-Str.");
	$start_pos->Coord("-12064,-284");
	$routing2->fix_position($start_pos);
	$routing2->Start($start_pos);
	my $goal_pos = BBBikeRouting::Position->new;
	$goal_pos->Street("Helmholtzstr.");
	$goal_pos->Coord("-11831,-70");
	$routing2->fix_position($goal_pos);
	$routing2->Goal($goal_pos);
	eval {
	    $routing2->search;
	};
	is($@, "", "successful search between " .
	   $start_pos->Coord . " and " . $routing2->Goal->Coord);
	ok($routing2->Path && scalar @{ $routing2->Path } > 0,
	   "Non-empty path");
	my $route_len = $routing2->RouteInfo->[-1]->{WholeMeters};
	ok($route_len < 500, "check route length")
	    or diag "Route length: $route_len too large, Route is " . Dumper($routing2->RouteInfo);
    }

    {
	my $routing2 = BBBikeRouting->new;
	$routing2->init_context;
	_my_init_context($routing2->Context);

	# Start position which is in the net, but really unreachable
	my $start_pos = BBBikeRouting::Position->new;
	$start_pos->Street("???");
	my $inacc_xy = "21306,381"; # B96a
	$start_pos->Coord($inacc_xy);
	$routing2->fix_position($start_pos);
	ok($start_pos->Coord ne $inacc_xy,
	   "fixed start position from $inacc_xy to " . $start_pos->Coord);
	ok(Strassen::Util::strecke_s($inacc_xy, $start_pos->Coord) < 600,
	   "new fixed position is reasonably near");
	$routing2->Start($start_pos);
	$routing2->Goal->Street("Dudenstr");

	eval {
	    $routing2->search;
	};
	is($@, "", "successful search between " .
	   $start_pos->Coord . " and " . $routing2->Goal->Coord);
	ok($routing2->Path && scalar @{ $routing2->Path } > 0,
	   "Non-empty path");
    }

}

# REPO BEGIN
# REPO NAME clone /home/e/eserte/src/repository 
# REPO MD5 40a45aaabc694572efaee9f0cd5dc125
sub clone {
    my $orig = shift;
    require Data::Dumper;
    my $clone;
    eval Data::Dumper->new([$orig], ['clone'])->Indent(0)->Purity(1)->Dump;
}
# REPO END

__END__
