#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
    if ($ENV{BBBIKE_TEST_NO_NETWORK}) {
        print "1..0 # skip due no network\n";
        exit;
    }
}

use LWP::UserAgent;

use BBBikeTest qw(check_cgi_testing);
check_cgi_testing;

plan tests => 3;

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent('BBBike-Test/1.0');
$ua->env_proxy;
{
    my $resp = $ua->get('http://m.bbbike.de');
    ok $resp->is_success, 'm.bbbike.de';

    my $content = $resp->decoded_content;
    like $content, qr{<meta name="viewport"}, 'Found viewport tag';
    like $content, qr{BBBikeForm}, 'Found form name';
}

__END__
