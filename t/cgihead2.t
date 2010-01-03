#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead2.t,v 1.27 2009/06/30 21:03:58 eserte Exp $
# Author: Slaven Rezic
#

# Note: At least SourceForge is known to chose a non-working redirect
# URL from time to time. If this seems to persist, then this script
# should probably retry a couple of times, in the hope that another
# redirect URL will be chosen.

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
	print "1..0 # skip no Test::More and/or LWP::UserAgent module\n";
	exit;
    }
}

use constant MSDOS_MIME_TYPE => qr{^application/(octet-stream|x-msdos-program|x-msdownload)$};

{
    use POSIX qw(strftime);
    use constant TODO_ADFC_ERRORS => "2010-04-01T12:00:00" gt strftime("%FT%T", localtime) && 'Redirects on adfc server do not work';
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
	       $BBBike::BBBIKE_UPDATE_DIST_CGI
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
	       $BBBike::DISTFILE_FREEBSD_I386
	       $BBBike::DISTFILE_FREEBSD_ALL
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

# seems to be necessary (for my system? for the freebsd server?)
$ENV{FTP_PASSIVE} = 1;

for my $url (@compat_urls) {
    local $TODO = TODO_ADFC_ERRORS;
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
	    if ($resp->code == 500 && $resp->message =~ /No route to host/i); # 'Bad hostname' was part of this regexp, but this mask a real test failure!
	#warn $resp->content;
	ok($resp->is_success, "Successful request of $url")
	    or diag $resp->status_line . " " . $resp->content;
	my $content_type = $resp->content_type;
	if ($url eq $BBBike::BBBIKE_UPDATE_DATA_CGI ||
	    $url eq $BBBike::BBBIKE_UPDATE_DIST_CGI ||
	    $url =~ m{\.zip$}) {
	    is($content_type, "application/zip", "Expected type (zip)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.tar\.gz$}) {
	    is($content_type, "application/x-gzip", "Expected type (gzip)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{/\.modified$}) {
	    is($content_type, "text/plain", "Expected type (plain text)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{wap}) {
	    is($content_type, "text/vnd.wap.wml", "Expected type (wml)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.exe$}) {
	    like($content_type, MSDOS_MIME_TYPE, "Expected type (binary or msdos program)")
		or diag("For URL $url $redir_url");
	} elsif ($url =~ m{(?:\.tar\.bz2|\.tbz)$}) {
	    is($content_type, "application/octet-stream", "Expected type (binary for bzip2)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.tar\.gz/download$}) { # Sourceforge download
	    # the inetbone mirror (213.203.218.125) running lighttpd returns octet-stream, so accept it, too
	    like($content_type, qr{^application/(x-tar|x-gzip|octet-stream)$}, "Expected type (tar or gzip, but octet-stream also possible)") or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.exe/download$}) { # Sourceforge download
	    like($content_type, MSDOS_MIME_TYPE, "Expected type (binary or msdos program)")
		or diag("For URL $url $redir_url");
	} elsif ($url =~ m{\.deb/download$}) { # Sourceforge download
	    # XXX One of the sourceforge mirrors uses text/plain as content-type
	    like($content_type, qr{^application/(octet-stream|x-debian-package)$}, "Expected type (debian package), got $content_type")
		or diag("For URL $url $redir_url");
	} else {
	    is($content_type, "text/html", "Expected type (html)") or diag("For URL $url $redir_url");
	}
    }
}

__END__
