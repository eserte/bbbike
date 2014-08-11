#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

BEGIN {
    if (!eval q{
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no LWP::UserAgent, and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();

use BBBikeTest qw(using_bbbike_test_cgi check_cgi_testing $cgidir);

check_cgi_testing;

my @origin_defs =
    (
     [undef,                   0],
     ['http://example.com',    0],
     ['https://example',       0],
     ['http://localhost',      1],
     ['http://localhost:8080', 1],
     ['https://localhost',     1],
     ['http://bbbike.de',      1],
     ['http://www.bbbike.de',  1],
     ['http://www.bbbike.org', 1],
    );

my @output_as_defs =
    (
     ['json',    1],
     ['geojson', 1],
     ['xml',     1],
     [undef,     0],
    );

plan tests => @origin_defs * @output_as_defs;

using_bbbike_test_cgi;

my $testcgi = "$cgidir/bbbike-test.cgi";
my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

my %std_args = (startc => '8538,12245', zielc => '9141,12320', pref_seen => 1);

for my $origin_def (@origin_defs) {
    my($origin, $expected_by_origin) = @$origin_def;
    for my $output_as_def (@output_as_defs) {
	my($output_as, $expected_by_output_as) = @$output_as_def;
	my $q = CGI->new({ %std_args, (defined $output_as ? (output_as => $output_as) : ()) });
	my $url = $testcgi . "?" . $q->query_string;
	my $resp = $ua->get($url, (defined $origin ? (Origin => $origin) : ()));
	my $origin_string    = defined $origin    ? $origin    : '<undef>';
	my $output_as_string = defined $output_as ? $output_as : '<undef>';
	if ($expected_by_origin && $expected_by_output_as) {
	    is $resp->header('Access-Control-Allow-Origin'), $origin, "Expected CORS header for Origin=$origin_string and output_as=$output_as_string"
		or diag $resp->headers->as_string;
	} else {
	    ok !$resp->header('Access-Control-Allow-Origin'), "Expected missing CORS header for Origin=$origin_string and output_as=$output_as_string";
	}
    }
}

__END__
