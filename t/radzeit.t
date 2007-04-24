#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: radzeit.t,v 1.2 2007/04/24 20:44:41 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or LWP::UserAgent modules\n";
	exit;
    }
}

use Data::Dumper;
use Sys::Hostname;

if (hostname !~ m{\.herceg\.(de|local)}) {
    print "1..0 # skip: works only on herceg.local\n";
    exit;
}

plan tests => 4;

my $bbbike_data = "http://bbbike.radzeit.de/BBBike/data";

my $ua = LWP::UserAgent->new;
$ua->agent('BBBike-Test/1.0');

{
    my $resp = $ua->get("$bbbike_data/temp_blockings/bbbike-temp-blockings-optimized.pl");
    ok($resp->is_success, ".pl file which should be treated as text")
	or diag(Dumper $resp);
    like($resp->content, qr{temp_blocking});
}

{
    my $resp = $ua->get("$bbbike_data/handicap_l");
    ok($resp->is_success, "normal bbd file")
	or diag(Dumper $resp);
    like($resp->content, qr{sonstige behinderungen}i);
}

__END__
