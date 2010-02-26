#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# This script is currently misnamed, as it checks data download from
# the live server, not specifically from the (non-existent) radzeit
# server

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	use Compress::Zlib;
	1;
    }) {
	print "1..0 # skip no Test::More, Compress::Zlib and/or LWP::UserAgent modules\n";
	exit;
    }
}

use Data::Dumper;
use Sys::Hostname;

use Http;
use Strassen::Core;

my $bbbike_url               = "http://bbbike.de";
my $bbbike_data_url          = "http://bbbike.de/BBBike/data";
my $bbbike_data_fallback_url = "http://bbbike.radzeit.de/BBBike/data";
#my $bbbike_data_local_url    = "http://radzeit/BBBike/data";
my $bbbike_data_local_url    = "http://bbbike.hosteurope/BBBike/data";

my @urls;
if ($ENV{BBBIKE_TEST_HTMLDIR}) {
    push @urls, "$ENV{BBBIKE_TEST_HTMLDIR}/data";
} else {
    push @urls, $bbbike_data_url;
    push @urls, $bbbike_data_fallback_url;
    push @urls, $bbbike_data_local_url;
}

my $tests_per_url = 17;
plan tests => $tests_per_url * scalar(@urls) + 2;

my $ua_string = 'BBBike-Test/1.0';

my $ua = LWP::UserAgent->new;
$ua->agent($ua_string);

my $uagzip = LWP::UserAgent->new;
$uagzip->agent($ua_string);
$uagzip->default_headers->push_header('Accept-Encoding' => 'gzip');

$Http::user_agent .= " (BBBike-Test/1.0)";

for my $url (@urls) {
    local $TODO;
 SKIP: {
	skip("local URL works only on herceg.local", $tests_per_url)
	    if $url eq $bbbike_data_local_url && hostname !~ m{\.herceg\.(de|local)};

	if ($url eq $bbbike_data_fallback_url) {
	    $TODO = "bbbike.radzeit.de is currently broken!!!";
	}

	{
	    my $resp = $ua->get("$url/temp_blockings/bbbike-temp-blockings-optimized.pl");
	    ok($resp->is_success, ".pl file which should be treated as text ($url)")
		or diag(Dumper $resp);
	    like($resp->content, qr{temp_blocking});
	}

	{
	    my $resp = $ua->get("$url/handicap_l");
	    ok($resp->is_success, "normal bbd file")
		or diag(Dumper $resp);
	    do_content_checks($resp->decoded_content, "LWP");
	}

	{
	    my $resp = $uagzip->get("$url/handicap_l");
	    ok($resp->is_success, "normal bbd file")
		or diag(Dumper $resp);
	    do_content_checks($resp->decoded_content, "LWP (gzip)");
	}

	{
	    my %res = Http::get(url => "$url/handicap_l");
	    is($res{'error'}, 200, "Got $url/handicap_l with Http.pm");
	    do_content_checks($res{'content'}, 'Http (SRT)');
	}
    }
}

{
    my $resp = $ua->get("$bbbike_url/robots.txt");
    ok($resp->is_success, 'robots.txt exists')
	or diag($resp->as_string);
}

{
    my $resp = $ua->get("$bbbike_url/favicon.ico");
    ok($resp->is_success, 'favicon exists')
	or diag($resp->as_string);
}

sub do_content_checks {
    my($content, $wwwmod) = @_;

    ok($content =~ m{sonstige behinderungen}i, "Content check with $wwwmod");
    my $s = Strassen->new_from_data_string($content);
    isa_ok($s, "Strassen");
    cmp_ok($s->count, ">=", 50, "reasonable number of data lines");

    my $have_umlauts;
    $s->init;
    while() {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS] || [] };
	if ($r->[Strassen::NAME] =~ m{(?:Fußgänger|über|Spielstraße)}i) {
	    $have_umlauts++;
	}
    }
    ok($have_umlauts, "Encoding seems to be OK");
}

__END__
