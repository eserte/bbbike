#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: wapcgi.t,v 1.24 2009/02/25 23:46:23 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use LWP::UserAgent 2.001; # get method
use Getopt::Long;
use File::Temp qw(tempfile);
use URI;

use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test module\n";
	exit;
    }

    eval q{ use Image::Info qw(image_info) };
}

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin");
use BBBikeTest qw(get_std_opts $do_display do_display);

# XXX Missing:
# a test with a "real" user agent and a profile setting
# to check if BrowserInfo::UAProf works correcly

my $ua = new LWP::UserAgent;
$ua->agent("BBBike-Test/1.0 (wapcgi.t/$VERSION)");

my @wap_url;
my @hdrs;

if (defined $ENV{BBBIKE_TEST_WAPURL}) {
    push @wap_url, $ENV{BBBIKE_TEST_WAPURL};
} elsif (defined $ENV{BBBIKE_TEST_CGIDIR}) {
    push @wap_url, $ENV{BBBIKE_TEST_CGIDIR} . "/wapbbbike.cgi";
}

if (!GetOptions(get_std_opts("display"),
		"wapurl=s" => sub { @wap_url = $_[1] },
		"keep!" => \$File::Temp::KEEP_ALL,
	       )) {
    die "usage: $0 [-wapurl url] [-display] [-keep]";
}

if (!@wap_url) {
    @wap_url = "http://localhost/bbbike/cgi/wapbbbike.cgi";
}
if (!@hdrs) {
    @hdrs = (["wbmp", Accept => "text/vnd.wap.wml"],
	     ["gif",  Accept => "text/vnd.wap.wml, image/gif"],
	     ["png",  Accept => "text/vnd.wap.wml, image/png"],
	    );
}

plan tests => 29 * scalar @wap_url * scalar @hdrs;

for my $wapurl (@wap_url) {
    for my $hdr (@hdrs) {
	my @hdr = @$hdr;
	my $desc = shift @hdr;
	print "# $desc\n";
	my $resp;
	my $url;

	my $absolute = sub {
	    my $relurl = shift;
	    URI->new_abs($relurl, $wapurl)->as_string;
	};

	$url = $wapurl;
	$resp = $ua->get($url, @hdr);
	is($resp->is_success, 1, $url) or diag $resp->as_string;
	like($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
	validate_wml($resp->content, $url);
	for (qw(Start Ziel Bezirk)) {
	    like($resp->content, qr/$_/, "$_ in $url?");
	}

	# This used to be "sonntag", but now is not unambigous anymore
	# (Sonntagsfrieden ...)
	$url = "$wapurl?startname=duden&startbezirk=&zielname=sonntagstr&zielbezirk=";
	$resp = $ua->get($url, @hdr);
	like($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
	validate_wml($resp->content, $url);
	like($resp->content, qr/Dudenstr/, "Dudenstr. in $url");
	like($resp->content, qr/Sonntagstr/, "Sonntagstr. in $url");

	my($surr_url) = $resp->content =~ /href=\"([^\"]+sess=[^\"]+)\"/;
	ok(defined $surr_url, "Session parameter exists? --- only with Apache::Session");
	isnt($surr_url, "");
	$surr_url = $absolute->($surr_url);

	$url = "$wapurl?startname=Dudenstr.&startbezirk=Kreuzberg&zielname=Sonntagstr.&zielbezirk=Friedrichshain&output_as=imagepage";
	$resp = $ua->get($url, @hdr);
	like($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $url);
	validate_wml($resp->content, $url);

	$url = "$wapurl?startname=Dudenstr.&startbezirk=Kreuzberg&zielname=Sonntagstr.&zielbezirk=Friedrichshain&output_as=image";
	$resp = $ua->get($url, @hdr);
	is(!!$resp->is_success, 1, $url)
	    or diag $resp->content;
	like($resp->header('Content_Type'), qr|^image/|, $url);
	is(length $resp->content > 0, 1, "Check for content in $url");
	check_image($resp, $url);

	$resp = $ua->get($surr_url, @hdr);
	like($resp->header('Content_Type'), qr|^text/vnd.wap.wml|, $surr_url);
	validate_wml($resp->content, $surr_url);
	my($surr_image_url) = $resp->content =~ /img.*src=\"([^\"]+sess[^\"]+)\"/;
	ok(defined $surr_image_url);
	isnt($surr_image_url, "");
	$surr_image_url = $absolute->($surr_image_url);

	$resp = $ua->get($surr_image_url, @hdr);
	is(!!$resp->is_success, 1, $surr_image_url);
	like($resp->header('Content_Type'), qr|^image/|, $surr_image_url);
	is(length $resp->content > 0, 1, "Check for content in $surr_image_url");
	check_image($resp, $surr_image_url);

	$url = $wapurl . "?startname=dudenstr&startbezirk=&zielname=kleistpark&zielbezirk=;form=advanced";
	$resp = $ua->get($url, @hdr);
	ok($resp->is_success, "Advanced search ($url)");
	like($resp->content, qr{genaue kreuzung.*dudenstr.*ecke}i, "Expected multiple start choices");
	unlike($resp->content, qr{\$zielcoord}, "No multiple goal choices expected");
    }
}

sub validate_wml {
    my($wml, $url) = @_;
 SKIP: {
	skip("xmllint is not installed", 1) unless is_in_path("xmllint");

	my $xml_catalog = "/home/e/eserte/src/bbbike/misc/xml-catalog";
	my @xmllint_args;
	if (!-e $xml_catalog) {
	    ##XXX validate over the 'net
	    #	warn "Cannot find $xml_catalog, skipping test...\n";
	    #	return 1;
	} else {
	    push @xmllint_args, "--catalogs", "file://$xml_catalog";
	}
	$ENV{SGML_CATALOG_FILES} = "";
	my($fh,$filename) = tempfile(UNLINK => 1);
	print $fh $wml;
	close $fh; # to avoid problems (flush?) with 5.00503
	system("xmllint @xmllint_args $filename 2>&1 >/dev/null");
	is($?, 0, "Validate correct wml in $url");
    }
}

sub check_image {
    my($resp, $url) = @_;
    if ($resp->header('Content_Type') eq 'image/vnd.wap.wbmp') {
	check_wbmp($resp->content, $url);
	do_display(\($resp->content), "wbmp") if $do_display;
    } else {
    SKIP: {
	    skip("image_info not defined", 1) unless defined &image_info;
	    is(image_info(\$resp->content)->{file_media_type},
	       $resp->header('Content_Type'), "Validate image in $url");
	    do_display(\($resp->content)) if $do_display;
	}
    }
}

# Image::Info does not recognize wbmp (probably because of lack of
# magic), so utilize ImageMagick to check for valid wbmp
sub check_wbmp {
    my($wbmp_content, $url) = @_;
 SKIP: {
	skip("ImageMagick is not installed", 1) unless is_in_path("convert");
	my($wbmp_fh, $wbmp_file) = tempfile(UNLINK => 1,
					    SUFFIX => ".wbmp");
	my($png_fh, $png_file)   = tempfile(UNLINK => 1,
					    SUFFIX => ".png");
	print $wbmp_fh $wbmp_content;
	close $wbmp_fh;
	system("convert $wbmp_file $png_file");
	is($?, 0, "Validate wbmp in $url");
    }
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
