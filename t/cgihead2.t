#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgihead2.t,v 1.3 2003/06/30 07:32:05 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Test;
use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeVar;
use File::Basename;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

my @prog;
push @prog, ($BBBike::HOMEPAGE,
	     $BBBike::BBBIKE_WWW,
	     @BBBike::BBBIKE_WWW,
	     $BBBike::BBBIKE_DIRECT_WWW,
	     $BBBike::BBBIKE_SF_WWW,
	     $BBBike::BBBIKE_UPDATE_WWW,
	     $BBBike::BBBIKE_WAP,
	     $BBBike::BBBIKE_DIRECT_WAP,
	     $BBBike::DISTDIR,
	     $BBBike::DISPLAY_DISTDIR,
	     $BBBike::UPDATE_DIR,
	     $BBBike::DIPLOM_URL,
	     $BBBike::BBBIKE_MAPSERVER_URL,
	     $BBBike::BBBIKE_MAPSERVER_ADDRESS_URL,
	     $BBBike::BBBIKE_MAPSERVER_DIRECT,
	     $BBBike::BBBIKE_MAPSERVER_INDIRECT,
	    );

plan tests => 2 * scalar @prog;

for my $prog (@prog) {
    ok(defined $prog, 1, "not defined");
    system("HEAD -H 'User-Agent: BBBike-Test/1.0' $prog > '/tmp/head." . basename($prog) . ".log'");
    ok($?, 0, $prog);
}

__END__
