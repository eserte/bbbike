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

    {
	my $res = $cb->(GET "/");
	ok $res->is_success;
	tidy_check $res->content, 'mapserver_address start';
	like_html $res->content, qr{Auswahl nach Stra.*en und Orten};
    }

    {
	my $res = $cb->(GET "/?street=Dudenstr");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{mapserv};
    }

    {
	my $res = $cb->(GET "/street=Dudenstr");
	is $res->code, '302', 'street input via pathinfo';
	like $res->header('location'), qr{mapserv};
    }

    {
	my $res = $cb->(GET "/?street=Dudenstr&usemap=googlemaps");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{bbbikegooglemap}, 'redirect to googlemap';
    }

    
    {
	my $res = $cb->(GET "/?street=Dudenstr&width=640&height=400");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{mapserv}, 'redirect to mapserver, with width/height param';
    }

    {
	my $res = $cb->(GET "/?street=Dudenstr&mapext=0,0,10000,10000");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{mapserv}, 'redirect to mapserver, with mapext param';
    }

    {
	my $res = $cb->(GET "/?street=Dudenstr&layer=flaechen");
	is $res->code, '302', 'street input';
	like $res->header('location'), qr{mapserv\?layer=flaechen&}, 'redirect to mapserver, with layer param';
    }

    {
	my $res = $cb->(GET "/?street=Bahnhofstr");
	is $res->code, '200', 'street input with multiple results';
	tidy_check $res->content, 'mapserver_address - multiple results page';
	like_html $res->content, qr{Mehrere Stra.*en gefunden};
	like_html $res->content, qr{Lichtenrade};
    }

    {
	my $res = $cb->(GET "/?street=Bahnhofstr&citypart=Lichtenrade");
	is $res->code, '302', 'street and citypart input';
	like $res->header('location'), qr{mapserv}, 'redirect to mapserver';
    }

    {
	my $res = $cb->(GET "/?street=Altstaedter+Ring");
	is $res->code, '302', 'street input (with Spandau street)';
	like $res->header('location'), qr{mapserv}, "redirect to mapserver, with city scope";
    }

    {
	my $res = $cb->(GET "/?street=ThisStreetDoesNotExist");
	is $res->code, '200', 'no result for street input';
	tidy_check $res->content, 'mapserver_address - no results street page';
	like_html $res->content, qr{Nichts gefunden};
    }

    {
	my $res = $cb->(GET "/?coords=8581,12243");
	is $res->code, '302', 'bbbike coords input';
	like $res->header('location'), qr{mapserv};
    }

    {
	my $res = $cb->(GET "/?city=Bernau");
	is $res->code, '302', 'city input in orte';
	like $res->header('location'), qr{mapserv};
    }

    {
	my $res = $cb->(GET "/?city=Potsdam");
	is $res->code, '302', 'city input (Potsdam)';
	like $res->header('location'), qr{mapserv}, "redirect to mapserver, with potsdam scope (theoretically)";
    }

    {
	my $res = $cb->(GET "/?city=Prenzlau");
	is $res->code, '302', 'city input in orte2';
	like $res->header('location'), qr{mapserv};
    }

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

    {
	my $res = $cb->(GET "/?latD=52&latM=30&latS=58.5&longD=13&longM=22&longS=43.7");
	is $res->code, '302', 'DMS coordinates';
	like $res->header('location'), qr{mapserv};
    }

    {
	my $res = $cb->(GET "/?lat=13.378817&long=52.516263");
	is $res->code, '302', 'DDD coordinates';
	like $res->header('location'), qr{mapserv};
    }

};

__END__
