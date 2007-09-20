#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead2.t,v 1.17 2007/09/20 23:22:27 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeVar;
use File::Basename;

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

my @var;
push @var, (qw(
	       $BBBike::HOMEPAGE
	       $BBBike::BBBIKE_WWW
	       @BBBike::BBBIKE_WWW
	       $BBBike::BBBIKE_DIRECT_WWW
	       $BBBike::BBBIKE_SF_WWW
	       $BBBike::BBBIKE_UPDATE_WWW
	       $BBBike::BBBIKE_UPDATE_DATA_CGI
	       $BBBike::BBBIKE_WAP
	       $BBBike::BBBIKE_DIRECT_WAP
	       $BBBike::DISTFILE_SOURCE
	       $BBBike::DISTFILE_WINDOWS
	       $BBBike::DISPLAY_DISTDIR
	       $BBBike::DIPLOM_URL
	       $BBBike::BBBIKE_MAPSERVER_URL
	       $BBBike::BBBIKE_MAPSERVER_ADDRESS_URL
	       $BBBike::BBBIKE_MAPSERVER_DIRECT
	       $BBBike::BBBIKE_MAPSERVER_INDIRECT
	       $BBBike::SF_DISTFILE_SOURCE
	       $BBBike::SF_DISTFILE_WINDOWS
	       $BBBike::SF_DISTFILE_DEBIAN
	       $BBBike::DISTFILE_FREEBSD
	      ),
	   );
# Not HEADable:
#   DISTDIR

my @compat_urls = ('http://www.radzeit.de/BBBike/data/.modified',
		   'http://www.radzeit.de/cgi-bin/bbbike.cgi',
		   'http://www.radzeit.de/cgi-bin/wapbbbike.cgi',
		   'http://bbbike.radzeit.de/cgi-bin/bbbike.cgi',
		  );

my %url;
for my $var (@var) {
    my @url = eval $var;
    die $@ if $@;
    if ($var eq '$BBBike::BBBIKE_UPDATE_WWW') {
	@url = map { "$_/data/.modified" } @url;
    }
    $url{$var} = \@url;
}

plan tests => 1 + 3 * (scalar(map { @$_ } values %url) + @compat_urls);

my $ua = LWP::UserAgent->new;
$ua->agent('BBBike-Test/1.0');

for my $url (@compat_urls) {
    check_url($url);
}

for my $var (@var) {
    for my $url (@{ $url{$var} }) {
	check_url($url, $var);
    }
}

SKIP: {
    my $no_tests = 1;
    my $bsd_port_dir = "/usr/ports";
    if (-d $bsd_port_dir) {
	chdir "$bsd_port_dir/Mk" or die "Cannot chdir into Mk directory: $!";
	my($output) = `make -f bsd.sites.mk -V MASTER_SITE_SOURCEFORGE 2>/dev/null`;
	chomp $output;
	my @sf_dist_dir = map { s{%SUBDIR%/*}{bbbike}g; $_ } split / /, $output;
	if (grep { $_ eq $BBBike::DISTDIR } @sf_dist_dir) {
	    pass("Found $BBBike::DISTDIR in Sourceforge sites");
	} else {
	    fail("Cannot find $BBBike::DISTDIR in @sf_dist_dir");
	}
    } else {
	skip "No BSD ports available", $no_tests
    }
}

sub check_url {
    my($url, $var) = @_;

    ok(defined $url, (defined $var ? "$var -> $url" : $url));
    my $method = "head";
    if ($url =~ m{user.cs.tu-berlin.de}) {
	$method = "get";	# HEAD does not work here
    }
    my $resp = $ua->$method($url);
    my $redir_url = $resp->request->uri;
    if ($redir_url eq $url) {
	$redir_url = "(not redirected)";
    } else {
	$redir_url = "(redirected to $redir_url)";
    }
 SKIP: {
	my $no_tests = 2;
	skip("No internet available", $no_tests)
	    if ($resp->code == 500 && $resp->message =~ /Bad hostname|No route to host/i);
	#warn $resp->content;
	ok($resp->is_success, "Successful request of $url")
	    or diag $resp->status_line . " " . $resp->content;
	my $content_type = $resp->content_type;
	if ($url eq $BBBike::BBBIKE_UPDATE_DATA_CGI ||
	    $url =~ m{\.zip$}) {
	    is($content_type, "application/zip", "Expected type (zip)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.tar\.gz$}) {
	    is($content_type, "application/x-gzip", "Expected type (gzip)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{/\.modified$}) {
	    is($content_type, "text/plain", "Expected type (plain text)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{wap}) {
	    is($content_type, "text/vnd.wap.wml", "Expected type (wml)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.exe$}) {
	    is($content_type, "application/octet-stream", "Expected type (binary)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{(?:\.tar\.bz2|\.tbz)$}) {
	    is($content_type, "application/octet-stream", "Expected type (binary for bzip2)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.tar\.gz\?download$}) { # Sourceforge download
	    like($content_type, qr{^application/x-(tar|gzip)$}, "Expected type (tar or gzip)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.exe\?download$}) { # Sourceforge download
	    is($content_type, "application/octet-stream", "Expected type (binary)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.deb\?download$}) { # Sourceforge download
	    # XXX One of the sourceforge mirrors uses text/plain as content-type
	    like($content_type, qr{^application/(octet-stream|x-debian-package)$}, "Expected type (debian package), got $content_type") or diag("For URL $url $redir_url");
	} else {
	    is($content_type, "text/html", "Expected type (html)") or diag("For URL $url $redir_url");
	}
    }
}

__END__
