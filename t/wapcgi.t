#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: wapcgi.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use LWP::UserAgent;
use Getopt::Long;
use File::Temp qw(tempfile);

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

my $ua = new LWP::UserAgent;
$ua->agent("BBBike-Test/1.0");

my @wap_url;

if (!GetOptions("wapurl=s" => sub { @wap_url = $_[1] })) {
    die "usage: $0 [-wapurl url]";
}

if (!@wap_url) {
    @wap_url = "http://www/bbbike/cgi/wapbbbike.cgi";
}

plan tests => 6 * scalar @wap_url;

for my $wapurl (@wap_url) {
    my $resp = $ua->get($wapurl);
    ok($resp->is_success, 1, $resp->as_string);
    ok($resp->header('Content_Type'), qr|^text/vnd.wap.wml|);
    ok(validate_wml($resp->content));
    for (qw(Start Ziel Bezirk)) {
	ok($resp->content, qr/$_/);
    }
}

sub validate_wml {
    my $wml = shift;
    $ENV{SGML_CATALOG_FILES} = "";
    my($fh,$filename) = tempfile(UNLINK => 1);
    print $fh $wml;
    system("xmllint --catalogs file:///home/e/eserte/src/bbbike/misc/xml-catalog $filename 2>&1 >/dev/null");
    $? == 0;
}

__END__
