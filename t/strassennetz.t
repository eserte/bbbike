#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassennetz.t,v 1.2 2003/07/25 09:41:17 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen::Core;
use Strassen::StrassenNetz;

BEGIN {
    if (!eval q{
	use Test::More qw(no_plan);
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

my $s = Strassen->new("qualitaet_s");

{
    my $net = StrassenNetz->new($s);
    $net->make_net_cat(-obeydir => 1, -net2name => 1);
    my $route = [[17014,15442],[16888,15462],[16819,15495]];
    is($net->get_point_comment($route, 1, undef), undef);
    $route = [ reverse @$route ];
    like($net->get_point_comment($route, 1, undef), qr/kopfstein/i);
}

{
    my $net = StrassenNetz->new($s);
    $net->make_net_cat(-obeydir => 1, -net2name => 1, -multiple => 1);
    my $route = [[17014,15442],[16888,15462],[16819,15495]];
    is(scalar $net->get_point_comment($route, 1, undef), 0);
    $route = [ reverse @$route ];
    like(($net->get_point_comment($route, 1, undef))[0], qr/kopfstein/i);
}

__END__
