#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: wapcgi.t,v 1.5 2003/07/14 06:36:42 eserte Exp $
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

if (defined $ENV{BBBIKE_TEST_WAPURL}) {
    push @wap_url, $ENV{BBBIKE_TEST_WAPURL};
}

if (!GetOptions("wapurl=s" => sub { @wap_url = $_[1] })) {
    die "usage: $0 [-wapurl url]";
}

if (!@wap_url) {
    @wap_url = "http://www/bbbike/cgi/wapbbbike.cgi";
}

plan tests => 14 * scalar @wap_url;

for my $wapurl (@wap_url) {
    my $resp;
    my $url;

    $url = $wapurl;
    $resp = $ua->get($url);
    ok($resp->is_success, 1, $resp->as_string);
    ok($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
    ok(!!validate_wml($resp->content), 1, $url);
    for (qw(Start Ziel Bezirk)) {
	ok($resp->content, qr/$_/, $url);
    }

    $url = "$wapurl?startname=duden&startbezirk=&zielname=sonntag&zielbezirk=";
    $resp = $ua->get($url);
    ok($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
    ok(!!validate_wml($resp->content), 1, $url);
    ok($resp->content, qr/Dudenstr/, $url);
    ok($resp->content, qr/Sonntagstr/, $url);

    $url = "$wapurl?startname=Dudenstr.&startbezirk=Kreuzberg&zielname=Sonntagstr.&zielbezirk=Friedrichshain&output_as=imagepage";
    $resp = $ua->get($url);
    ok($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
    ok(!!validate_wml($resp->content), 1, $url);

    $url = "$wapurl?startname=Dudenstr.&startbezirk=Kreuzberg&zielname=Sonntagstr.&zielbezirk=Friedrichshain&output_as=image";
    $resp = $ua->get($url);
    ok(!!$resp->is_success, 1, $url);
    ok($resp->header('Content_Type'), qr|^image/|, $url);
}

sub validate_wml {
    my $wml = shift;
    if (!is_in_path("xmllint")) {
	warn "xmllint is not installed, skipping test...\n";
	return 1;
    }
    my $xml_catalog = "/home/e/eserte/src/bbbike/misc/xml-catalog";
    if (!-e $xml_catalog) {
	warn "Cannot find $xml_catalog, skipping test...\n";
	return 1;
    }
    $ENV{SGML_CATALOG_FILES} = "";
    my($fh,$filename) = tempfile(UNLINK => 1);
    print $fh $wml;
    system("xmllint --catalogs file://$xml_catalog $filename 2>&1 >/dev/null");
    $? == 0;
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 81c0124cc2f424c6acc9713c27b9a484
sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    # maybe use $ENV{PATHEXT} like maybe_command in ExtUtils/MM_Win32.pm?
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe" ||
		    -x "$_\\$prog.cmd");
	} else {
	    return "$_/$prog" if (-x "$_/$prog" && !-d "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 89d0fdf16d11771f0f6e82c7d0ebf3a8
BEGIN {
    if (eval { require File::Spec; defined &File::Spec::file_name_is_absolute }) {
	*file_name_is_absolute = \&File::Spec::file_name_is_absolute;
    } else {
	*file_name_is_absolute = sub {
	    my $file = shift;
	    my $r;
	    if ($^O eq 'MSWin32') {
		$r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	    } else {
		$r = ($file =~ m|^/|);
	    }
	    $r;
	};
    }
}
# REPO END

__END__
