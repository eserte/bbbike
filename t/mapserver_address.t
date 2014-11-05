#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    for my $mod (qw(Test::More Plack::Test CGI::Compile CGI::Emulate::PSGI HTTP::Request::Common)) {
	if (!eval qq{ use $mod; 1 }) {
	    print "1..0 # skip no $mod available\n";
	    exit;
	}
    }
}

use FindBin;
use lib (
	 "$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib", # for enum.pm
	);
use Cwd 'realpath';
use BBBikeTest qw(check_cgi_testing like_html tidy_check);

check_cgi_testing;

plan 'no_plan';

$FindBin::RealBin = realpath "$FindBin::RealBin/../cgi"; # fake location of script

my $sub = do {
    local $^W; # cease "redefined" warnings (does not work with no warnings becase of -w...)
    no warnings 'once';
    local $BBBike::PLACK_TESTING = 1;
    CGI::Compile->compile("$FindBin::RealBin/mapserver_address.cgi");
};
ok $sub, 'can compile mapserver_address.cgi';
my $app = CGI::Emulate::PSGI->handler($sub);
ok $app, 'can convert into psgi application';

test_psgi app => $app, client => sub {
    my $cb = shift;

    my $expect_mapserver_redirect = sub ($$$) {
	my($url, $location_rx, $testname) = @_;

	$location_rx = qr{mapserv} if !defined $location_rx;

    SKIP: {
	    skip "Mapserver skipped by env variable", 2
		if $ENV{BBBIKE_TEST_SKIP_MAPSERVER};

	    my $res = $cb->(GET $url);
	    is $res->code, '302', "$testname - expect redirect"
		or diag $res->as_string;
	    like $res->header('location'), $location_rx, "$testname - expected location";
	}
    };

    {
	my $res = $cb->(GET "/");
	ok $res->is_success
	    or diag $res->as_string;
	tidy_check $res->content, 'mapserver_address start';
	like_html $res->content, qr{Auswahl nach Stra.*en und Orten};
    }

    $expect_mapserver_redirect->('/?street=Dudenstr', undef, 'street input');
    $expect_mapserver_redirect->('/street=Dudenstr', undef, 'street input via pathinfo');

    {
	my $res = $cb->(GET "/?street=Dudenstr&usemap=googlemaps");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{bbbikegooglemap}, 'redirect to googlemap';
    }

    $expect_mapserver_redirect->('/?street=Dudenstr&width=640&height=400', undef, 'with width/height param');
    $expect_mapserver_redirect->('/?street=Dudenstr&mapext=0,0,10000,10000', undef, 'with mapext param');
    $expect_mapserver_redirect->('/?street=Dudenstr&layer=flaechen', qr{mapserv\?layer=flaechen&}, 'with layer param');

    {
	my $res = $cb->(GET "/?street=Bahnhofstr");
	is $res->code, '200', 'street input with multiple results';
	tidy_check $res->content, 'mapserver_address - multiple results page';
	like_html $res->content, qr{Mehrere Stra.*en gefunden};
	like_html $res->content, qr{Lichtenrade};
    }

    $expect_mapserver_redirect->('/?street=Bahnhofstr&citypart=Lichtenrade', undef, 'street and citypart input');
    $expect_mapserver_redirect->('/?street=Altstaedter+Ring', undef, 'street input (with Spandau street)');

    {
	my $res = $cb->(GET "/?street=ThisStreetDoesNotExist");
	is $res->code, '200', 'no result for street input';
	tidy_check $res->content, 'mapserver_address - no results street page';
	like_html $res->content, qr{Nichts gefunden};
    }

    $expect_mapserver_redirect->('/?coords=8581,12243', undef, 'bbbike coords input');

    $expect_mapserver_redirect->('/?city=Bernau', undef, 'city input (orte)');
    $expect_mapserver_redirect->('/?city=Potsdam', undef, 'city input (Potsdam, theoretically with potsdam scope)');
    $expect_mapserver_redirect->('/?city=Prenzlau', undef, 'city input (orte2)');

    {
	my $res = $cb->(GET "/?city=Wilmersdorf");
	is $res->code, '200', 'multiple results for city input';
	tidy_check $res->content, 'mapserver_address - multiple city page';
	like_html $res->content, qr{Mehrere Orte gefunden};
    }

    {
	my $res = $cb->(GET "/?city=ThisCityDoesNotExist");
	is $res->code, '200', 'no result for city input';
	tidy_check $res->content, 'mapserver_address - no results city page';
	like_html $res->content, qr{Nichts gefunden};
    }

    {
	my $res = $cb->(GET "/?searchterm=Tegeler+See");
	is $res->code, '200', 'search term input - multiple results';
	tidy_check $res->content, 'mapserver_address - multiple searchterm results page';
	like_html $res->content, qr{Mehrere Treffer};
    }

    {
	my $res = $cb->(GET "/?searchterm=.");
	is $res->code, '200', 'search term input - search everything';
	tidy_check $res->content, 'mapserver_address - multiple searchterm results page';
	like_html $res->content, qr{Mehrere Treffer};
    }

    $expect_mapserver_redirect->('/?latD=52&latM=30&latS=58.5&longD=13&longM=22&longS=43.7', undef, 'DMS coordinates');
    $expect_mapserver_redirect->('/?lat=13.378817&long=52.516263', undef, 'DDD coordinates');
};

__END__
