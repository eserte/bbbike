#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin";

BEGIN {
    if (!eval q{
	use JSON::XS;
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no JSON::XS, LWP::UserAgent and/or Test::More module(s)\n";
	exit;
    }
}

use BBBikeTest qw($cgiurl);

plan tests => 2;

my $ua = LWP::UserAgent->new;
$ua->agent('BBBikeTest/1.0');

{
    my $url = $cgiurl . '?api=revgeocode;lon=13.460589;lat=52.507395';
    my $resp = $ua->get($url);
    ok($resp->is_success, "revgeocode API call")
	or diag $resp->as_string;
    my $data = decode_json $resp->decoded_content(charset => 'none');
    is_deeply($data, {crossing  => "Simplonstr./Seumestr.", # "Niemannstr." intentionally stripped in API
		      bbbikepos => '14252,11368'});
}

__END__
