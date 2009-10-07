#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: prefer_cache.t,v 1.3 2003/06/23 22:09:37 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
BEGIN {
    # Don't use "use lib", so we are sure that the real BBBikeXS.pm/so is
    # loaded first
    push @INC, qw(../.. ../../lib);
}
use Strassen;
use BBBikeXS 0.10;
use Getopt::Long;

my $v;
GetOptions("v" => \$v)
    or die "usage: $0 [-v]";

if ($v) {
    $Strassen::VERBOSE = $StrassenNetz::VERBOSE = $Strassen::Util::VERBOSE = 1;
}

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 2 }

my $s = Strassen->new("strassen");

{
    my $net = StrassenNetz->new($s);
    $net->make_net(PreferCache => 1);
    ok(ref $net->{Net}, "HASH");
}

{
    my $net = StrassenNetz->new($s);
    $net->make_net(PreferCache => 1);
    ok(ref $net->{Net}, "HASH");
}


__END__
