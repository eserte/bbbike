#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead2.t,v 1.7 2005/03/23 14:17:17 eserte Exp $
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

plan tests => 2 * scalar(map { @$_ } values %url);

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
	    skip("No internet available", 1)
		if ($req->code == 500 && $req->message =~ /Bad hostname|No route to host/i);
	    #warn $req->content;
	    ok($req->is_success) or diag $req->content;
	}
    }
}

__END__
