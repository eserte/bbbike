#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

# Note: At least SourceForge is known to chose a non-working redirect
# URL from time to time. If this seems to persist, then this script
# should probably retry a couple of times, in the hope that another
# redirect URL will be chosen.

use strict;

use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 $FindBin::RealBin,
	);
use BBBikeVar;
use BBBikeTest qw(check_cgi_testing check_network_testing on_author_system);
use File::Basename;
use Sys::Hostname qw(hostname);
use Time::HiRes qw(time);

BEGIN {
    if (!eval q{
	use Test::More;
	use LWP::UserAgent;
	1;
    }) {
	print "1..0 # skip no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

check_cgi_testing;
check_network_testing;
on_author_system;

use constant MSDOS_MIME_TYPE => qr{^application/(octet-stream|x-msdos-program|x-msdownload)$};

{
    use POSIX qw(strftime);
    #use constant TODO_FREEBSD_PORTSMON_BROKEN => "2017-10-26T12:00:00" gt strftime("%FT%T", localtime) && 'FreeBSD portsmon/portsoverview page is broken (internal server error)';
    use constant TODO_FREEBSD_PKG_ERRORS => "2015-05-13T12:00:00" gt strftime("%FT%T", localtime) && 'BBBike packages for FreeBSD not available, maybe permanently?';
}

my @var;
push @var, (qw(
	       $BBBike::HOMEPAGE
	       $BBBike::BBBIKE_WWW
	       @BBBike::BBBIKE_WWW
	       "$BBBike::BBBIKE_WWW/beta"
	       "$BBBike::BBBIKE_WWW/en"
	       $BBBike::BBBIKE_DIRECT_WWW
	       $BBBike::BBBIKE_SF_WWW
	       $BBBike::BBBIKE_UPDATE_WWW
	       $BBBike::BBBIKE_UPDATE_DATA_CGI
	       $BBBike::BBBIKE_UPDATE_DIST_CGI
	       $BBBike::BBBIKE_MOBILE
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
	       $BBBike::BBBIKE_GOOGLEMAP_URL
	       $BBBike::BBBIKE_LEAFLET_URL
	       $BBBike::BBBIKE_LEAFLET_CGI_URL
	       $BBBike::SF_DISTFILE_SOURCE
	       $BBBike::SF_DISTFILE_WINDOWS
	       $BBBike::SF_DISTFILE_DEBIAN
	       $BBBike::SF_DISTFILE_DEBIAN_I386
	       $BBBike::SF_DISTFILE_DEBIAN_AMD64
	       $BBBike::DISTFILE_FREEBSD_I386
	      ),
	   );
# Not HEADable:
#   DISTDIR
# Broken:
#	       $BBBike::DISTFILE_FREEBSD_ALL

my %url;
for my $var (@var) {
    my @url = eval $var;
    die $@ if $@;
    if ($var eq '$BBBike::BBBIKE_UPDATE_WWW') {
	@url = map { "$_/data/.modified" } @url;
    }
    $url{$var} = \@url;
}

plan tests => 1 + 3 * (scalar(map { @$_ } values %url));

my $ua = LWP::UserAgent->new(keep_alive => 10);
$ua->agent('BBBike-Test/1.0');
$ua->env_proxy;

my $ua_letsencrypt;
# With older Net::SSLeay it's necessary to turn off cert checks on sites with Let's Encrypt certs
# https://letsencrypt.org/docs/dst-root-ca-x3-expiration-september-2021/
if (eval { require Net::SSLeay; require IO::Socket::SSL; 1 } && ($Net::SSLeay::VERSION < 1.69 || $IO::Socket::SSL::VERSION < 2.016)) {
    $ua_letsencrypt = $ua->clone;
    $ua_letsencrypt->ssl_opts(verify_hostname => 0);
    $ua_letsencrypt->ssl_opts(SSL_verify_mode => &IO::Socket::SSL::SSL_VERIFY_NONE); # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=907853
} else {
    $ua_letsencrypt = $ua;
}

# seems to be necessary (for my system? for the freebsd server?)
$ENV{FTP_PASSIVE} = 1;

for my $var (@var) {
    for my $url (@{ $url{$var} }) {

	if (0) {
	    # XXX requesting bbbike-snapshot.cgi sometimes fails, with
	    # really long request times. Doing first a head against the
	    # debug version to have the timings in the errorlog
	    #
	    # 2012-01: this is not anymore an issue, a request is typically
	    # accomplished after 5 seconds.
	    if ($url eq $BBBike::BBBIKE_UPDATE_DIST_CGI) {
		my $resp = $ua->head('http://bbbike.de/cgi-bin/bbbike-snapshot-debug.cgi');
		if (!$resp->is_success) {
		    diag "Failure requesting the bbbike snapshot: " . $resp->as_string;
		}
	    }
	}

	local $TODO;
	if (TODO_FREEBSD_PKG_ERRORS &&
	    ($url eq $BBBike::DISTFILE_FREEBSD_I386 # || $url eq $BBBike::DISTFILE_FREEBSD_ALL
	    )
	   ) {
	    $TODO = TODO_FREEBSD_PKG_ERRORS;
	}
	#if (TODO_FREEBSD_PORTSMON_BROKEN &&
	#    $url eq $BBBike::DISTFILE_FREEBSD_ALL
	#   ) {
	#    $TODO = TODO_FREEBSD_PORTSMON_BROKEN;
	#}

	my $timeout = 10;
	if ($url =~ m{^\Qhttp://sourceforge.net/projects/bbbike/files}) {
	    $timeout = 60; # yes: even a HEAD on (some?) sf mirrors can take many, many seconds
	}
	$ua->timeout($timeout);

	check_url($url, $var);
    }
}

SKIP: {
    my $no_tests = 1;
    skip "Test does not apply anymore", $no_tests;
    # That's because $BBBike::DISTDIR is now set to a different
    # download link, not using anymore the sf mirrors.

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

 SKIP: {
	my $no_tests = 2;

	our %checked;
	if ($checked{$url}++) {
	    skip("$url was already checked", $no_tests);
	}

	my $used_ua;
	if ($url =~ m{^https?://sourceforge\.net}) {
	    $used_ua = $ua_letsencrypt;
	    if ($ua_letsencrypt != $ua) {
		diag "Need to switch to 'forgiving' user-agent for accessing '$url'";
	    }
	} else {
	    $used_ua = $ua;
	}

	my $method = "head";
	my $t0 = time;
	my $resp = $used_ua->$method($url);
	my $dt = time - $t0;
	my $redir_text = do {
	    my $redir_url = $resp->request->uri;
	    if ($redir_url eq $url) {
		'';
	    } else {
		" (redirected to $redir_url)";
	    }
	};

	skip("No internet available", $no_tests)
	    if ($resp->code == 500 && $resp->message =~ /No route to host/i); # 'Bad hostname' was part of this regexp, but this mask a real test failure!
	if ($resp->code == 500 && $resp->message =~ /certificate verify failed/i) {
	    diag <<EOF;
Make sure that your SSL-related libraries and modules are up-to date.
Especially requests to sourceforge.net may fail if Net::SSLeay is too
old (1.66 probably to old, 1.78 should work).
EOF
	}
	#warn $resp->content;
	ok($resp->is_success, "Successful request of $url$redir_text " . sprintf("%.3fs", $dt))
	    or diag $resp->status_line . " " . $resp->content;
	my $content_type = $resp->header('content-type');
	if ($url eq $BBBike::BBBIKE_UPDATE_DIST_CGI) {
	    like($content_type, qr{^application/(zip|octet-stream)$}, "Expected type (zip)") or diag("For URL $url$redir_text");
	} elsif ($url eq $BBBike::BBBIKE_UPDATE_DATA_CGI ||
		 $url =~ m{\.zip$}) {
	    is($content_type, "application/zip", "Expected type (zip)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.tar\.gz$}) {
	    is($content_type, "application/x-gzip", "Expected type (gzip)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.txz$}) {
	    is($content_type, "application/octet-stream", "Expected type (txz)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.pkg$}) {
	    is($content_type, "application/octet-stream", "Expected type (pkg)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{/\.modified$}) {
	    local $TODO = "May return text/plain or nothing, depending of active backend for data files";
	    like($content_type, qr{^text/plain}, "Expected type (plain text)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{wap}) {
	    like($content_type, qr{^text/vnd.wap.wml}, "Expected type (wml)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.exe$}) {
	    like($content_type, MSDOS_MIME_TYPE, "Expected type (binary or msdos program)")
		or diag("For URL $url$redir_text");
	} elsif ($url =~ m{(?:\.tar\.bz2|\.tbz)$}) {
	    is($content_type, "application/octet-stream", "Expected type (binary for bzip2)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.tar\.gz/download$}) { # Sourceforge download
	    # the inetbone mirror (213.203.218.125) running lighttpd returns octet-stream, so accept it, too
	    like($content_type, qr{^application/(x-tar|x-gzip|octet-stream)$}, "Expected type (tar or gzip, but octet-stream also possible)") or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.exe/download$}) { # Sourceforge download
	    like($content_type, MSDOS_MIME_TYPE, "Expected type (binary or msdos program)")
		or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.deb/download$}) { # Sourceforge download
	    # XXX One of the sourceforge mirrors uses text/plain as content-type
	    like($content_type, qr{^application/(octet-stream|x-debian-package)$}, "Expected type (debian package), got $content_type")
		or diag("For URL $url$redir_text");
	} elsif ($url =~ m{\.deb$}) { # direct download
	    like($content_type, qr{^application/x-debian-package$}, "Expected type (debian package), got $content_type")
		or diag("For URL $url$redir_text");
	} else {
	    like($content_type, qr{^text/html}, "Expected type (html)") or diag("For URL $url$redir_text");
	}
    }
}

__END__
