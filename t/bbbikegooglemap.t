#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.t,v 1.2 2006/08/16 20:53:08 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	use CGI;
	1;
    }) {
	print "1..0 # skip no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

my $gmap_api = 2;

use Getopt::Long;
my $cgi_dir = $ENV{BBBIKE_TEST_CGIDIR} || "http://localhost/bbbike/cgi";
my $cgi_url = "http://www.bbbike.de/cgi-bin/bbbikegooglemap.cgi";

if (!GetOptions("cgidir=s" => \$cgi_dir, # XXX not used
		"cgiurl=s" => \$cgi_url,
	       )) {
    die "usage: $0 [-cgiurl url]";
}

plan tests => 4;

my $ua = LWP::UserAgent->new;
$ua->agent('BBBike-Test/1.0');

{
    my %query = (wpt  => "-49893,-29160",
		 zoom => 1,
		);
    my $qs = CGI->new(\%query)->query_string;
    my $url = $cgi_url . "?" . $qs;
    my $resp = $ua->get($url);
    ok($resp->is_success, "Success with $url");

    # Introduced this test, because RewriteRule without the NE flag
    # would escape the query string (again), leading to wrong results.
    my $uri = $resp->request->uri;
    my($new_qs) = $uri =~ m{\?(.*)};
    is_deeply({CGI->new($new_qs)->Vars}, \%query, "Querystring unchanged");
}

{
    my %query = (wpt_or_trk  => "   -49893,-29160 -49793,-29260 ");
    my $qs = CGI->new(\%query)->query_string;
    my $url = $cgi_url . "?" . $qs;
    my $resp = $ua->get($url);
    ok($resp->is_success, "Success with $url");
    my $content = $resp->content;
    if ($content !~ m{\Qnew GPolyline([}g) {
	fail("Cannot match Polyline");
    } else {
	my $points = 0;
	my $gpoint_qr = $gmap_api == 1 ? qr{new GPoint} : qr{new GLatLng};
	while($content =~ m{$gpoint_qr}g) {
	    $points++;
	}
	is($points, 2, "Found exactly two points from wpt_or_trk query")
	    or diag $content;
    }
}


__END__
