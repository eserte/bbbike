#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cmdbbbike.t,v 1.2 2007/09/20 22:41:27 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 4 + 2;

{
    my @route = `$^X $FindBin::RealBin/../cmdbbbike duden seume`;
    like($route[0], qr{duden.*seume}i, "Title line");
    like($route[1], qr{methfesse}i, "First hop expected");
    like($route[-1], qr{seume}i, "Last hop expected");
    like($route[1], qr{\s+\d+\.\d+\s+km}i, "Expected distance format");
}

{
    my $route = `$^X $FindBin::RealBin/../smsbbbike duden seume`;
    chomp $route;
    like($route, qr{^methfessel.*\*.*seume$}i, "Short SMS route");
    local $TODO = "Not yet";
    cmp_ok(length($route), "<=", 160, "Route is short enough");
}

__END__
