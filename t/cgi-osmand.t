#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use Test::More;

use FindBin;
use lib ($FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Getopt::Long;
use LWP::UserAgent;
use BBBikeTest qw(check_cgi_testing gpxlint_string get_std_opts $cgidir $debug);

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
    my $resp = $ua->get("$osmand_cgi?point=52.427377,13.7477672&point=52.4601088,13.7423562");
    ok $resp->is_success
	or diag($resp->dump);
    is $resp->content_type, 'application/gpx+xml';
    my $gpx_content = $resp->decoded_content;
    gpxlint_string $gpx_content;
    if ($debug) {
	diag($gpx_content);
    }
}

__END__
