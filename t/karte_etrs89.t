#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: karte_etrs89.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";
use Karte::ETRS89 qw(UTMToETRS89 ETRS89ToUTM ETRS89ToDegrees);
use Karte::UTM qw(GKKToDegrees);

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 2 }

my(@etrs1) = (3368499.7, 5798499.9);
my(@etrs2) = (3373500.5, 5803500.7);

ok(join(",", @etrs1), join(",",UTMToETRS89(ETRS89ToUTM(@etrs1))));
ok(join(",", @etrs2), join(",",UTMToETRS89(ETRS89ToUTM(@etrs2))));


#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([GKKToDegrees(3,3565938.060,5519235.636)],[])->Indent(1)->Useqq(1)->Dump; # XXX
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([GKKToDegrees(4,4350023.966,5520916.682)],[])->Indent(1)->Useqq(1)->Dump; # XXX
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([GKKToDegrees(2.4,3368499.7,5798499.9)],[])->Indent(1)->Useqq(1)->Dump; # XXX


require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([
ETRS89ToDegrees(3, 3368499.7,5798499.9, "WGS 84"),
ETRS89ToDegrees(3, 3373500.5,5803500.7, "WGS 84"),

],[])->Indent(1)->Useqq(1)->Dump; # XXX

__END__
