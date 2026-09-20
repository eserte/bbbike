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

use VectorUtil ();

use BBBikeTest qw(check_cgi_testing gpxlint_string xpath_checks get_std_opts $cgidir $debug);

sub trk_crosses ($$$);

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
	    my @trks = $doc->findnodes('//trk');
	    is scalar(@trks), 1, 'created one track';
	    trk_crosses($trks[0], '13.32779,52.47394', '13.329128,52.473926'); # via Bundesallee
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
	    my @trks = $doc->findnodes('//trk');
	    is scalar(@trks), 1, 'created one track';
	    trk_crosses($trks[0], '13.332073,52.47401', '13.333309,52.474006'); # via Handjerystr
	};
    if ($debug) {
	diag($gpx_content);
    }
}

sub trk_crosses ($$$) {
    my($trk, $p0, $p1) = @_;
    my($p0x,$p0y) = split /,/, $p0;
    my($p1x,$p1y) = split /,/, $p1;
    my @trkpts = map { join(",", $_->findvalue('@lon'), $_->findvalue('@lat')) } $trk->findnodes('.//trkpt');
    for(my $i=0; $i<$#trkpts; $i++) {
	my($tp0x,$tp0y) = split /,/, $trkpts[$i];
	my($tp1x,$tp1y) = split /,/, $trkpts[$i+1];
	if (VectorUtil::intersect_lines($p0x,$p0y,$p1x,$p1y, $tp0x,$tp0y,$tp1x,$tp1y)) {
	    pass "track crosses line";
	    return;
	}
    }
    fail "track does not cross line (got @trkpts; should cross $p0 $p1)";
}

__END__
