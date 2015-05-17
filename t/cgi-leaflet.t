#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 $FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Test::More;

use Getopt::Long;
use LWP::UserAgent ();

use BBBikeTest qw(check_cgi_testing eq_or_diff tidy_check get_std_opts $cgidir get_cgi_config);

check_cgi_testing;

if (!GetOptions(
		get_std_opts("cgidir", "xxx"),
	       )) {
    die "usage: $0 [-cgidir url]";
}

plan 'no_plan';

my $coordssession_qr = qr{coordssession=(?i:\d+%3a)?[0-9a-f_]+};

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

my $base_url = "$cgidir/bbbikeleaflet.cgi";

{
    my $resp = $ua->get($base_url);
    ok $resp->is_success, "Fetching $base_url is OK"
	or diag $resp->status_line;
    my $content = $resp->decoded_content(charset => 'none');
    tidy_check $content, 'tidy check for base URL';
    like $content, qr{var initialRouteGeojson = null;}, 'no initial coords';
    like $content, qr{var initialGeojson = null;}, 'no initial coords';
}

{
    my @contents;
    for my $param (qw(coords coords_rev)) {
	my $url = "$base_url?$param=1381,11335!1450,11309!1532,11280!1574,11379"; # Theodor-Heuss-Platz
	my $resp = $ua->get($url);
	ok $resp->is_success, "Fetching with simple coords and param key $param is OK"
	    or diag $resp->status_line;
	my $content = $resp->decoded_content(charset => 'none');
	tidy_check $content, 'tidy check with simple coords';
	like $content, qr<^\QinitialRouteGeojson = {"geometry":{"coordinates":[[\E13.27\d+,52.50\d+\Q],[\E13.27\d+,52.50\d+\Q],[\E13.27\d+,52.50\d+\Q],[\E13.27\d+,52.50\d+\Q]],"type":"LineString"},"properties":{"type":"Route"},"type":"Feature"};>m, 'simple initial coords';
	push @contents, $content;
    }

    eq_or_diff $contents[1], $contents[0], 'No difference between coords and coords_rev';
}

{
    my $url = "$base_url?coords=1381,11335!1450,11309!1532,11280!1574,11379&coords=1574,11379!1625,11380!1834,11408!1960,11426"; # Theodor-Heuss-Platz und weiter
    my $resp = $ua->get($url);
    ok $resp->is_success, "Fetching with multiple coords is OK"
	or diag $resp->status_line;
    my $content = $resp->decoded_content(charset => 'none');
    tidy_check $content, 'tidy check with multiple coords';
    like $content, qr<^initialGeojson =>m, 'beginning geojson';
    like $content, qr<"type" : "FeatureCollection">, 'expected geojson type';
}

SKIP: {
    my $can_apache_session = get_cgi_config()->{use_apache_session};
    skip 'No Apache::Session available, no coordssession param', 2
	if !$can_apache_session;

    my $bbbike_url = "$cgidir/bbbike.cgi?startc=9229,8785&zielc=9227,8890&pref_seen=1&pref_speed=20";

    { # bbbike.cgi (German)
	my $resp1 = $ua->get($bbbike_url);
	my $content1 = $resp1->decoded_content(charset => 'none');
	if ($content1 =~ m{<a href="([^"]+/bbbikeleaflet\.cgi\?$coordssession_qr)">Leaflet<img style="vertical-align:bottom;" src=".*?/images/bbbike_leaflet_16.png" border="0" alt=""></a>}) {
	    my $bbbikeleaflet_url = $1;
	    pass "Found bbbikeleaflet link '$bbbikeleaflet_url'";
	    my $resp2 = $ua->get($bbbikeleaflet_url);
	    ok $resp2->is_success, 'Fetching a bbbikeleaflet URL with coordssession is OK';
	    my $content2 = $resp2->decoded_content(charset => 'none');
	    tidy_check $content2, 'tidy check';
	    like $content2, qr<^\QinitialRouteGeojson = {"geometry":{"coordinates":[[\E13.38\d+,52.48\d+\Q],[\E13.38\d+,52.48\d+\Q]],"type":"LineString"},"properties":{"type":"Route"},"type":"Feature"};>m, 'expected coords';
	} else {
	    fail 'Cannot find bbbikeleaflet link';
	}
    }

    (my $bbbike_en_url = $bbbike_url) =~ s{bbbike\.cgi}{bbbike.en.cgi};

    { # bbbike.en.cgi
	my $resp1 = $ua->get($bbbike_en_url);
	my $content1 = $resp1->decoded_content(charset => 'none');
	if ($content1 =~ m{<a href="([^"]+/bbbikeleaflet\.en\.cgi\?$coordssession_qr)">Leaflet<img style="vertical-align:bottom;" src=".*?/images/bbbike_leaflet_16.png" border="0" alt=""></a>}) {
	    my $bbbikeleaflet_url = $1;
	    pass "Found English bbbikeleaflet link '$bbbikeleaflet_url'";
	    my $resp2 = $ua->get($bbbikeleaflet_url);
	    ok $resp2->is_success, 'Fetching a bbbikeleaflet URL with coordssession is OK';
	    my $content2 = $resp2->decoded_content(charset => 'none');
	    tidy_check $content2, 'tidy check';
	    like $content2, qr<^\QinitialRouteGeojson = {"geometry":{"coordinates":[[\E13.38\d+,52.48\d+\Q],[\E13.38\d+,52.48\d+\Q]],"type":"LineString"},"properties":{"type":"Route"},"type":"Feature"};>m, 'expected coords';
	} else {
	    fail 'Cannot find bbbikeleaflet link';
	}
    }
    
}



__END__
