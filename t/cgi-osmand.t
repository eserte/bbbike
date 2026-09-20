#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use utf8;
use Test::More;

use FindBin;
use lib ($FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Getopt::Long;
use LWP::UserAgent;
use BBBikeTest qw(check_cgi_testing gpxlint_string xpath_checks get_std_opts $cgidir $debug);

check_cgi_testing;
plan 'no_plan';

if (!GetOptions(get_std_opts("cgidir", "debug"))) {
    die "usage!";
}

my $osmand_cgi = "$cgidir/osmand.cgi";

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;
$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());

{
    my $resp = $ua->get("$osmand_cgi?point=52.469746,13.331503&&point=52.490819,13.330932"); # Schmiljanstr./Handjerystr. -> Bundesallee/Güntzelstr.
    ok $resp->is_success
	or diag($resp->dump);
    is $resp->content_type, 'application/gpx+xml';
    my $gpx_content = $resp->decoded_content;
    gpxlint_string $gpx_content;
    xpath_checks $gpx_content, 2,
	sub {
	    my $doc = shift;
	    my @rtes = $doc->findnodes('//rte');
	    is scalar(@rtes), 1, 'created one route';
	    my $route_names = join(" - ", $doc->findnodes('//rte//name'));
	    like $route_names, qr{Schmiljanstr.*Friedrich-Wilhelm-Platz.*Bundesallee}, 'expected route via Bundesallee';
	};
    if ($debug) {
	diag($gpx_content);
    }
}

{
    my $resp = $ua->get("$osmand_cgi?pref_cat=N2&point=52.469746,13.331503&&point=52.490819,13.330932"); # Schmiljanstr./Handjerystr. -> Bundesallee/Güntzelstr. with preference
    ok $resp->is_success
	or diag($resp->dump);
    is $resp->content_type, 'application/gpx+xml';
    my $gpx_content = $resp->decoded_content;
    gpxlint_string $gpx_content;
    xpath_checks $gpx_content, 2,
	sub {
	    my $doc = shift;
	    my @rtes = $doc->findnodes('//rte');
	    is scalar(@rtes), 1, 'created one route';
	    my $route_names = join(" - ", $doc->findvalue('//rte//name'));
	    like $route_names, qr{Handjerystr.*Prinzregentenstr.*Güntzelstr}, 'expected route via Prinzregentenstr.';
	};
    if ($debug) {
	diag($gpx_content);
    }
}

__END__
