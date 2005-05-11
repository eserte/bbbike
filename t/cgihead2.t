#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead2.t,v 1.11 2005/05/11 23:41:01 eserte Exp $
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
push @var, (qw($BBBike::HOMEPAGE
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
	      )
	   );
# Not HEADable:
#   DISTDIR

my %url;
for my $var (@var) {
    my @url = eval $var;
    die $@ if $@;
    if ($var eq '$BBBike::BBBIKE_UPDATE_WWW') {
	@url = map { "$_/data/.modified" } @url;
    }
    $url{$var} = \@url;
}

plan tests => 1 + 3 * scalar(map { @$_ } values %url);

my $ua = LWP::UserAgent->new;
$ua->agent('BBBike-Test/1.0');

for my $var (@var) {
    for my $url (@{ $url{$var} }) {
	ok(defined $url, "$var -> $url");
	my $method = "head";
	if ($url =~ m{user.cs.tu-berlin.de}) {
	    $method = "get"; # HEAD does not work here
	}
	my $req = $ua->$method($url);
    SKIP: {
	    my $no_tests = 2;
	    skip("No internet available", $no_tests)
		if ($req->code == 500 && $req->message =~ /Bad hostname|No route to host/i);
	    #warn $req->content;
	    ok($req->is_success) or diag $req->content;
	    my $content_type = $req->content_type;
	    if ($url eq $BBBike::BBBIKE_UPDATE_DATA_CGI ||
		$url =~ m{\.zip$}) {
		is($content_type, "application/zip");
	    } elsif ($url =~ m{\.tar\.gz$}) {
		is($content_type, "application/x-gzip");
	    } elsif ($url =~ m{/\.modified$}) {
		is($content_type, "text/plain");
	    } elsif ($url =~ m{wap}) {
		is($content_type, "text/vnd.wap.wml");
	    } elsif ($url =~ m{\.exe$}) {
		is($content_type, "application/octet-stream");
	    } else {
		is($content_type, "text/html");
	    }
	}
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

__END__
