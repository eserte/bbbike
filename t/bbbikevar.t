#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikevar.t,v 1.1 2004/11/29 22:08:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use File::Basename;

use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeVar;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

my $ports_dir = "/usr/ports";
my $bbbike_bsd_port = $ports_dir . "/german/BBBike";

SKIP: {
    skip("No BSD port for BBBike available on this system", 1)
	if ! -d $bbbike_bsd_port;
    chdir $bbbike_bsd_port or die "Can't chdir to $bbbike_bsd_port: $!";
    my($out) = `make fetch-list DISTDIR=/`;
    my @url;
    while($out =~ m{((?:ftp|http)://\S+)}g) {
	push @url, $1;
    }
    my %dir_url = map { (dirname($_),1) } @url;
    my $bbbike_versioned_distdir = $BBBike::DISTDIR . '/BBBike/' . $BBBike::FREEBSD_VERSION;
    if (!exists $dir_url{$bbbike_versioned_distdir}) {
	fail("$bbbike_versioned_distdir not found in " . join(", ", keys %dir_url));
    } else {
	pass("$bbbike_versioned_distdir found");
    }
}

__END__
