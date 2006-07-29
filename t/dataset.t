#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: dataset.t,v 1.3 2006/07/29 21:33:20 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");
use Strassen::Dataset;

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

BEGIN { plan tests => 21 }

my $city_street   = "Dudenstr.";
my $region_street = "Mövenstr. (Potsdam)";
my $jwd_street    = "Anklam, Peenedamm";

# test Strassen::Dataset->get with single scope
my $ds = Strassen::Dataset->new("berlin"); # XXX arg is ignored for now
isa_ok($ds, "Strassen::Dataset");
my $s = $ds->get("str","s",["city"]);
isa_ok($s, "Strassen");
ok(grep { /\Q$city_street\E/ } @{$s->{Data}}, "Street in city data");
ok(!grep { /\Q$region_street\E/ } @{$s->{Data}}, "Street not in region data");
my $s2 = $ds->get("str","s","city");
isa_ok($s2, "Strassen");
is($s, $s2);

my $l = $ds->get("str","s",["region"]);
isa_ok($l, "Strassen");
isnt($s, $l);
ok(grep { /\Q$region_street\E/ } @{$l->{Data}}, "Street in region data");

# test Strassen::Dataset->get with multiple scopes
my $s_all = $ds->get("str","s",[qw(city region wideregion)]);
isa_ok($s_all, "Strassen");
ok((grep { /\Q$city_street\E/ } @{$s_all->{Data}}), "City street in all data");
ok((grep { /\Q$region_street\E/ } @{$s_all->{Data}}), "Region street in all data");
ok((grep { /\Q$jwd_street\E/ } @{$s_all->{Data}}), "Jwd street in all data");

my $s_all2 = $ds->get("str","s",[qw(city region wideregion)]);
is($s_all, $s_all2);

my $s_all3 = $ds->get("str","s",[qw(city region wideregion)], -cache => 0);
isnt($s_all, $s_all3);

my $s_all4 = $ds->get("str","s","all");
is($s_all3, $s_all4);

my $s_all5 = $ds->get("str","s",[qw(jwd city region)]);
is($s_all3, $s_all5);

# test Strassen::Dataset->get_net with single scope
my $net = $ds->get_net("str","s",["city"], -makenetargs => [UseCache => 1]);
isa_ok($net, "StrassenNetz");
my $first_street_coord = $s->get(0)->[Strassen::COORDS()][0];
my $last_street_coord  = $s->get($#{$s->{Data}})->[Strassen::COORDS()][0];
ok($net->search($first_street_coord, $last_street_coord), "Found result in search");

# test Strassen::Dataset->get_net with multiple scopes
my $net2 = $ds->get_net("str","s",[qw(city region)],
			-makenetargs => [UseCache => 1]);
isa_ok($net2, "StrassenNetz");
ok($net2->search($first_street_coord, $last_street_coord), "Found result in search");

__END__
