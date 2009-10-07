#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: makenet.t,v 1.3 2008/01/17 22:39:10 eserte Exp $
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
	use Test::More;
	use File::Temp;
	1;
    }) {
	print "1..0 # skip no Test::More and/or File::Temp modules\n";
	exit;
    }
}

plan tests => 3;

my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => ".bbd");

print $tmpfh <<EOF;
bla1	X 0,0 10,0 20,0
bla2	X 0,0 10,0 30,0
EOF
close $tmpfh
    or die $!;

my $s = Strassen->new($tmpfile);
my $net = StrassenNetz->new($s);
can_ok($net, "make_net");
$net->make_net;

my $net2 = StrassenNetz->new($s);
can_ok($net2, "make_net_PP");
$net2->make_net_PP;

for (qw(strecke_sub strecke_s_sub to_koord_sub)) { # not existent if created by XS
    delete $net2->{$_};
}
is_deeply($net, $net2)
    or diag(Data::Dumper->new([$net, $net2],[])->Indent(1)->Useqq(1)->Dump);

### not yet:
#  ok(ref (($net->net2name("0,0", "10,0"))[0]), "ARRAY");
#  ok(join("#", @{ ($net->net2name("0,0", "10,0"))[0] }),
#     join("#", 0, 1));
#  ok(ref $net->net2name("10,0", "20,0") ne "ARRAY");
#  ok($net->net2name("10,0", "20,0"), 0);

__END__
