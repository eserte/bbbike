#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikegooglemap.t,v 1.2 2006/08/16 20:53:08 eserte Exp $
# Author: Slaven Rezic
#

no utf8;
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
my $cgi_url;

if (!GetOptions("cgidir=s" => \$cgi_dir,
		"cgiurl=s" => \$cgi_url,
	       )) {
    die "usage: $0 [-cgiurl url | -cgidir url]";
}

if (!defined $cgi_url) {
    $cgi_url = $cgi_dir . '/bbbikegooglemap.cgi';
}

plan tests => 14;

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
    for my $query_def ({wpt_or_trk  => "   -49893,-29160 -49793,-29260 "},
		       {coords      => "-49893,-29160!-49793,-29260" },
		      ) {
	my %query = %$query_def;
	my $qs = CGI->new(\%query)->query_string;
	my $url = $cgi_url . "?" . $qs;
	my $resp = $ua->get($url);
	ok($resp->is_success, "Success with $url");
	check_polyline($resp, 2, "Found exactly two points from " . ((keys %query)[0]) . " query");
    }
}

{
    my %query = (coords => ['0,0!100,100', '200,200;300,300'],
		 oldcoords => '400,400!500,500',
		);
    my $qs = CGI->new(\%query)->query_string;
    my $url = $cgi_url . "?" . $qs;
    my $resp = $ua->get($url);
    ok($resp->is_success, "Success with $url");
    check_polyline($resp, 6, "Found exactly six points from coords+oldcoords query");
}

{
    my $url = $cgi_url;
    my $resp = do_post($ua, $url, gpxfile => <<EOF);
#: #: -*- coding: utf-8 -*-
#:encoding: utf-8
#:map: polar
SpinnerbrÃ¼cke	X 13.1910231,52.4333002
Loretta	X 13.1764685,52.4202488
Buchwald	X 13.3477971,52.5211918
Eiscafe Eisberg	X 13.3960606,52.5389681
GrÃ¼ne Oase	X 13.3450792,52.5485538
EOF
    ok($resp->is_success, "Success with post");
    check_points($resp, 5, 'Found exactly five points in POST with map=polar and utf8');
    like($resp->decoded_content, qr{Spinnerbrücke}, 'Found Spinnerbrücke');
}

{
    my $url = $cgi_url;
    my $resp = do_post($ua, $url, gpxfile => <<EOF);
#:map: standard
Spinnerbrücke	X 13.1910231,52.4333002
Loretta	X 13.1764685,52.4202488
Buchwald	X 13.3477971,52.5211918
Eiscafe Eisberg	X 13.3960606,52.5389681
Grüne Oase	X 13.3450792,52.5485538
EOF
    ok($resp->is_success, "Success with post");
    check_points($resp, 5, 'Found exactly five points in POST with map=standard and latin1');
    like($resp->decoded_content, qr{Spinnerbr(ü|&#xfc;)cke}i, 'Found Spinnerbrücke');
}

sub check_polyline {
    my($resp, $expected_points, $testname) = @_;
    $testname = "Found exactly $expected_points points in polyline" if !$testname;
    my $content = $resp->content;
    if ($content !~ m{\Qnew GPolyline([}g) {
	fail("Cannot match Polyline");
    } else {
	my $points = 0;
	my $gpoint_qr = $gmap_api == 1 ? qr{new GPoint} : qr{new GLatLng};
	while($content =~ m{$gpoint_qr}g) {
	    $points++;
	}
	is($points, $expected_points, $testname)
	    or diag $content;
    }
}

sub check_points {
    my($resp, $expected_points, $testname) = @_;
    $testname = "Found exactly $expected_points points" if !$testname;
    my $content = $resp->content;
    if ($content !~ m{\QBEGIN DATA}g) {
	fail("Cannot match beginning of data");
    } else {
	my $points = 0;
	my $gpoint_qr = $gmap_api == 1 ? qr{new GPoint} : qr{new GLatLng};
	while($content =~ m{var\s+point\s+=\s+$gpoint_qr}g) {
	    $points++;
	}
	is($points, $expected_points, $testname)
	    or diag $content;
    }
}

sub do_post {
    my($ua, $url, $key, $data) = @_;
    require File::Temp;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => '.bbd');
    print $tmpfh $data or die $!;
    close $tmpfh or die $!;
    $ua->post($url, Content_Type => 'form-data', Content => [$key => [$tmpfile]]);
}

__END__
