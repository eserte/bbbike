#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikerouting.t,v 1.4 2003/08/25 06:47:23 eserte Exp $
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
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

my $num_tests = 48; # basic number of tests

use vars qw($single $all $bench $v);

use vars qw($token %times $cmp_path
	    $usexs $algorithm $usenetserver $usecache $cachetype);

if (!GetOptions("full|slow|all" => sub { $all = 1 },
		"bench" => \$bench,
		"v+" => \$v,

		"usexs!" => \$usexs,
		"algorithm=s" => \$algorithm,
		"usenetserver!" => \$usenetserver,
		"usecache!" => \$usecache,
		"cachetype=s" => \$cachetype,
	       )) {
    die "usage!";
}

if (defined $v && $v > 1) {
    require Strassen;
    Strassen::set_verbose(1);
}

system("$FindBin::RealBin/../miscsrc/bbbikestrserver -restart");

if (!$all) {
    plan tests => $num_tests;
    if ($bench) {
	my $t = timeit(1, 'do_tests()');
	$times{$token} += $t->[$_] for (1..4);
    } else {
	do_tests();
    }
    goto EXIT;
}

plan tests => $num_tests * 5 * 2 * 2 * 2;

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
		for $algorithm ("C-A*", "A*") {
		    if ($bench) {
			my $t = timeit(1, 'do_tests()');
			$times{$token} += $t->[$_] for (1..4);
		    } else {
			do_tests();
		    }
		}
	    }
	}
    }
}

system("$FindBin::RealBin/../miscsrc/bbbikestrserver -stop");

EXIT:
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
    ok(ref $routing, "BBBikeRouting");
    $routing->init_context;
    my $context = $routing->Context;
    _my_init_context($context);
    @Strassen::Util::cacheable = $cachetype if defined $cachetype;
    $token = "Algorithm=".$context->Algorithm.", UseXS=".$context->UseXS.", UseNetServer=".$context->UseNetServer.", UseCache=".$context->UseCache.(defined $cachetype ? " ($cachetype)" : "");
    if ($v) {
	print STDERR "$token\n";
    }
    ok(1);

    $routing->Start->Street("Dudenstr");
    ok($routing->Start->Street, "Dudenstr");
    $routing->Goal->Street("Sonntagstr/Böcklinstr.");
    ok($routing->Goal->Street, "Sonntagstr/Böcklinstr.");
    $routing->search;
    ok($routing->Start->Street, "Dudenstr."); # normalized
    ok($routing->Goal->Street, "Sonntagstr/Böcklinstr."); # XXX not yet normalized
    my $goal_street = "Sonntagstr.";
    ok(scalar @{ $routing->Path } > 0);
    my $path = clone($routing->Path);
    ok(scalar @{ $routing->RouteInfo } > 0);
    my $routeinfo = clone($routing->RouteInfo);
    {
	local $^W; # no "numeric" warning
	ok($routing->RouteInfo->[0]->{Whole} < $routing->RouteInfo->[-1]->{Whole});
    }
    ok($routing->RouteInfo->[-1]->{Street}, $goal_street);
    my $new_goal = BBBikeRouting::Position->new;
    $new_goal->Street("Alexanderplatz");
    $routing->continue($new_goal);
    ok($routing->Goal->Street, "Alexanderplatz");
    ok(scalar @{$routing->Via}, 1);
    ok($routing->Via->[0]->Street, "Sonntagstr/Böcklinstr."); # XXX not yet normalized
    $routing->search;
    ok($routing->RouteInfo->[-1]->{Street}, $routing->Goal->Street);

    $routing->delete_to_last_via;
    ok(Data::Dumper->new([$routing->Path],[])->Useqq(1)->Dump,
       Data::Dumper->new([$path],[])->Useqq(1)->Dump);
    ok(Data::Dumper->new([$routing->RouteInfo],[])->Useqq(1)->Dump,
       Data::Dumper->new([$routeinfo],[])->Useqq(1)->Dump);

    if ($cmp_path) {
	ok(Data::Dumper->new([$cmp_path],[])->Useqq(1)->Dump,
	   Data::Dumper->new([$path],[])->Useqq(1)->Dump);
    } else {
	$cmp_path = $path;
	ok(1);
    }

    my $custom_pos = BBBikeRouting::Position->new;
    $custom_pos->Street("???");
    $custom_pos->Coord("4711,1234");
    my $old_goal = $routing->Goal;
    $routing->add_position($custom_pos);
    ok($routing->Goal->Coord, "4711,1234");
    ok($routing->Via->[-1]->Coord, $old_goal->Coord);
    ok($routing->RouteInfo->[-1]->{Coords}, join(",", @{$routing->Path->[-2]}));
    {
	local $^W = 0;
	ok($routing->RouteInfo->[-1]->{Whole} =~ /km/);
	ok($routing->RouteInfo->[-1]->{Whole} > $routing->RouteInfo->[-2]->{Whole});
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
	ok($routing2->Start->Coord, "4711,1234");
	ok($routing2->Start->Attribs =~ /\bfree\b/);
	ok(UNIVERSAL::isa($routing2->RouteInfo,"ARRAY"));
	ok(UNIVERSAL::isa($routing2->Path,"ARRAY"));
	ok(join(",", @{$routing2->Path->[-1]}), "4711,1234");

	# add another freehand position
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("???");
	$custom_pos->Coord("1234,4711");
	$routing2->add_position($custom_pos);
	ok($routing2->Goal->Coord, "1234,4711");
	ok($routing2->Goal->Attribs =~ /\bfree\b/);
	ok(scalar @{$routing2->RouteInfo}, 1);
	ok(scalar @{$routing2->Path}, 2);
	ok(join(",", @{$routing2->Path->[-1]}), "1234,4711");
	ok(join(",", @{$routing2->Path->[-2]}), "4711,1234");

	# now an existing position, but do _no_ search yet
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("Dudenstr.");
	$routing2->resolve_position($custom_pos);
	$routing2->add_position($custom_pos);
	ok(scalar @{$routing2->RouteInfo}, 2);
	ok(scalar @{$routing2->Path}, 3);

	# again an existing position _with_ search
	$custom_pos = BBBikeRouting::Position->new;
	$custom_pos->Street("Alexanderplatz");
	$routing2->continue($custom_pos);
	$routing2->search;
	ok(1);
    }

    {
	my $routing2 = BBBikeRouting->new();
	ok(ref $routing2, "BBBikeRouting");
	$routing2->init_context;
	_my_init_context($routing2->Context);
	$routing2->Context->Vehicle("oepnv");
	$routing2->Start->Street("Platz der Luftbrücke");
	ok($routing2->Start->Street, "Platz der Luftbrücke");
	$routing2->Goal->Street("Wannsee");
	ok($routing2->Goal->Street, "Wannsee");
	$routing2->search;
	# nach Wannsee kommt man nur mit der S- oder R-Bahn
	ok($routing2->RouteInfo->[-1]->{Street} =~ /^[SR]\d+$/);

	# clear the positions and check it with street names
	$routing2->Start(BBBikeRouting::Position->new);
	$routing2->Goal(BBBikeRouting::Position->new);
	$routing2->Start->Street("Dudenstr.");
	$routing2->Goal->Street("Kronprinzessinnenweg");
	eval {
	    $routing2->search;
	};
	ok($@, "", "Error while searching: $@, Routing start object is: " . Dumper($routing2->Start) . " and goal object is: " . Dumper($routing2->Goal));
	ok($routing2->Start->Street, "Platz der Luftbrücke");
	ok($routing2->Goal->Street, "Wannsee");
	ok($routing2->RouteInfo->[-1]->{Street} =~ /^[SR]\d+$/);
    }

    # changing the existing scope
    $routing->change_scope("wideregion");
    $routing->Start->Street("B2");
    $routing->Goal->Street("B96");
    $routing->search;
    ok($routing->Start->Street =~ /^B2/); # normalized
    ok($routing->Goal->Street =~ /^B96/); # normalized
    ok(scalar @{ $routing->Path } > 0);
    ok(scalar @{ $routing->RouteInfo } > 0);
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
