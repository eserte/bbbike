#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: dataset.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
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
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }
}

BEGIN { plan tests => 21 }

my $city_street   = "Dudenstr.";
my $region_street = "Mövenstr. (Potsdam)";
my $jwd_street    = "Anklam, Peendedamm";

# test Strassen::Dataset->get with single scope
my $ds = Strassen::Dataset->new("berlin"); # XXX arg is ignored for now
ok($ds->isa("Strassen::Dataset"));
my $s = $ds->get("str","s",["city"]);
ok($s->isa("Strassen"));
ok(grep { /\Q$city_street\E/ } @{$s->{Data}});
ok(!grep { /\Q$region_street\E/ } @{$s->{Data}});
my $s2 = $ds->get("str","s","city");
ok($s2->isa("Strassen"));
ok($s eq $s2);

my $l = $ds->get("str","s",["region"]);
ok($l->isa("Strassen"));
ok($s ne $l);
ok(grep { /\Q$region_street\E/ } @{$l->{Data}});

# test Strassen::Dataset->get with multiple scopes
my $s_all = $ds->get("str","s",[qw(city region wideregion)]);
ok($s_all->isa("Strassen"));
ok(grep { /\Q$city_street\E/ } @{$s_all->{Data}});
ok(grep { /\Q$region_street\E/ } @{$s_all->{Data}});
ok(grep { /\Q$jwd_street\E/ } @{$s_all->{Data}});

my $s_all2 = $ds->get("str","s",[qw(city region wideregion)]);
ok($s_all eq $s_all2);

my $s_all3 = $ds->get("str","s",[qw(city region wideregion)], -cache => 0);
ok($s_all ne $s_all3);

my $s_all4 = $ds->get("str","s","all");
ok($s_all3 eq $s_all4);

my $s_all5 = $ds->get("str","s",[qw(jwd city region)]);
ok($s_all3 eq $s_all5);

# test Strassen::Dataset->get_net with single scope
my $net = $ds->get_net("str","s",["city"], -makenetargs => [UseCache => 1]);
ok($net->isa("StrassenNetz"));
my $first_street_coord = $s->get(0)->[Strassen::COORDS()][0];
my $last_street_coord  = $s->get($#{$s->{Data}})->[Strassen::COORDS()][0];
ok($net->search($first_street_coord, $last_street_coord));

# test Strassen::Dataset->get_net with multiple scopes
my $net2 = $ds->get_net("str","s",[qw(city region)],
			-makenetargs => [UseCache => 1]);
ok($net2->isa("StrassenNetz"));
ok($net2->search($first_street_coord, $last_street_coord));

__END__
