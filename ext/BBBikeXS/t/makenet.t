#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: makenet.t,v 1.2 2003/02/24 02:38:47 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
BEGIN {
    # no lib here!
    push @INC, ("$FindBin::RealBin/../../..",
		"$FindBin::RealBin/../../../lib",
	       );
}
use Strassen;
use BBBikeXS;
use Data::Dumper;

BEGIN {
    if (!eval q{
	use Test;
	use Data::Compare;
	1;
    }) {
	print "1..0 # skip: no Test/Data::Compare modules\n";
	exit;
    }
}

BEGIN { plan tests => 1 }

open(TMP, ">/tmp/test.bbd") or die $!;
print TMP <<EOF;
bla1	X 0,0 10,0 20,0
bla2	X 0,0 10,0 30,0
EOF
close TMP;

my $s = Strassen->new("/tmp/test.bbd");
my $net = StrassenNetz->new($s);
$net->make_net;

my $net2 = StrassenNetz->new($s);
$net2->make_net_PP;

ok(Compare($net, $net2), 1,
   Data::Dumper->new([$net, $net2],[])->Indent(1)->Useqq(1)->Dump);

### not yet:
#  ok(ref (($net->net2name("0,0", "10,0"))[0]), "ARRAY");
#  ok(join("#", @{ ($net->net2name("0,0", "10,0"))[0] }),
#     join("#", 0, 1));
#  ok(ref $net->net2name("10,0", "20,0") ne "ARRAY");
#  ok($net->net2name("10,0", "20,0"), 0);

__END__
