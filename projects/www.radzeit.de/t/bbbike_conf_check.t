#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbike_conf_check.t,v 1.1 2009/04/05 21:54:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use Getopt::Long;
use LWP::UserAgent;
use Test::More 'no_plan';

my $do_mac_download_check;
my $do_vhost_checks;
my $host = "78.47.225.30";
my @tests;

my $doit;
GetOptions("doit!" => \$doit)
    or die "usage: $0 -doit";

if ($doit) {
    @tests =
	(
	 ['/', 'DocumentRoot root (redirect to cgi)', [qr{weitergeleitet werden}]], # XXX should probably be changed, automatically redirect!
	 ['/robots.txt', 'DocumentRoot robots', [qr{disallow}i]],
	 ['/cgi-bin/bbbike.cgi', 'cgi-bin bbbike.cgi', [qr{sucht.*Routen.*in.*Berlin}]],
	 ['/cgi-bin/bbbikegooglemap.cgi', 'cgi-bin bbbikegooglemap.cgi', [qr{maps.google.com/maps}]],
	 ['/mapserver/brb/brb.html', 'mapserver', [qr{Berlin/Brandenburg - BBBike - Mapserver}]],
	 ['/BBBike/data/.modified', 'static BBBike data', [qr{data/strassen}]],
	 ['/BBBike/tmp/berlin_map_07-05_280x240.png', 'detailmaps', [qr{^.PNG}]],
	 ['/wap/', 'wap', [qr{<card}]],
	 ['/wap/index.wml', 'wap (2)', [qr{<card}]],
	 ['/favicon.ico', 'favicon'],
	 ['/BBBike/html/opensearch/opensearch.html', 'opensearch page', [qr{BBBike-Suchplugin}], sub { like(shift->header('content-type'), qr{charset=utf-8}, 'opensearch page is utf-8') }],
	 ['/~slaven/cpantestersmatrix.cgi', 'cpan testers matrix', [qr{CPAN Testers Matrix}]],
	 ['/~slaven/cpantestersmatrix2.cgi', 'cpan testers matrix - devel', [qr{CPAN Testers Matrix}]],
	);
    $do_mac_download_check = 1;
    $do_vhost_checks = 1;
}
# Consider obsolete:
# - routopedia
# - BBBike2 (was just for tests)
# - BBBikeWiki (never online?)
# - newstreetformdata (finally we amuelhausen and me used ipop instead)
# - wapbvg (probably does not work anyway)

my $ua = LWP::UserAgent->new;
for my $test (@tests) {
    my($relurl, $testname, $content_checks, $extra_check) = @$test;
    my $url = "http://$host$relurl";
    my $resp = $ua->get($url);
    ok($resp->is_success, "GET $url" . ($testname ? " ($testname)" : ""))
	or diag $resp->as_string;
    for my $content_check (@{ $content_checks || [] }) {
	like($resp->decoded_content, $content_check)
	    or diag $resp->decoded_content;
    }
    if ($extra_check) {
	$extra_check->($resp);
    }
}

if ($do_mac_download_check) {
    my $url = "http://$host/~slaven/tmp/BBBike-3.16-Intel.dmg";
    my $resp = $ua->head($url);
    ok($resp->is_success);
    is($resp->content_type, 'application/octet-stream');
    cmp_ok($resp->content_length, ">=", 10_000_000, "Expected to be large");
}

if ($do_vhost_checks) {
    my $url = "http://$host/cgi-bin/bbbike.cgi";
    for my $vhost ('bbbike.de',
		   'www.bbbike.de',
		   'bbbike.radzeit.de',
		  ) {
	my $resp = $ua->get($url, Host => $vhost);
	ok($resp->is_success, "$vhost check");
	like($resp->decoded_content, qr{sucht.*Routen.*in.*Berlin});
    }
}

pass("Done!"); # dummy test to avoid "no test" errors

__END__
