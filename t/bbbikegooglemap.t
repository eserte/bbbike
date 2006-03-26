#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.t,v 1.1 2006/03/25 07:22:25 eserte Exp $
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
	print "1..0 # skip: no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

use Getopt::Long;
my $cgi_dir = $ENV{BBBIKE_TEST_CGIDIR} || "http://localhost/~eserte/bbbike/cgi";

if (!GetOptions("cgidir=s" => \$cgi_dir,
	       )) {
    die "usage: $0 [-cgidir url]";
}

plan tests => 2;

my $ua = LWP::UserAgent->new;
$ua->agent('BBBike-Test/1.0');

my %query = (wpt  => "-49893,-29160",
	     zoom => 1,
	    );
my $qs = CGI->new(\%query)->query_string;
my $url = "http://www.bbbike.de/cgi-bin/bbbikegooglemap.cgi?" . $qs;
my $resp = $ua->get($url);
ok($resp->is_success, "Success with $url");

# Introduced this test, because RewriteRule without the NE flag
# would escape the query string (again), leading to wrong results.
my $uri = $resp->request->uri;
my($new_qs) = $uri =~ m{\?(.*)};
is_deeply({CGI->new($new_qs)->Vars}, \%query, "Querystring unchanged");

__END__
