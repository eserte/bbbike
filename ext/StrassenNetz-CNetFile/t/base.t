#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: base.t,v 1.3 2002/11/22 18:27:48 eserte Exp $
# Author: Slaven Rezic
#

use Cwd;
BEGIN { $root = "../.." }
use lib ($root, "$root/lib", "$root/data");
use lib @lib::ORIG_INC;

use Strassen::Core;
use StrassenNetz::CNetFileDist;

use strict;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 5 }

my $s = Strassen->new("strassen");
my $net = StrassenNetz->new($s);
ok($net->isa("StrassenNetz"));
$net->use_data_format($StrassenNetz::FMT_MMAP);
ok($net->isa("StrassenNetz::CNetFile"));
{
    my $c1 = $net->can("make_net"); # workaround Test.pm DWIMery
    my $c2 = \&StrassenNetz::CNetFile::make_net;
    ok($c1 eq $c2);
}
{
    my $c1 = $net->can("reachable");
    my $c2 = \&StrassenNetz::CNetFile::reachable;
    ok($c1 eq $c2);
}
$net->make_net;
ok(1);

__END__
