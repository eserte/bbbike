#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-grid.t,v 1.1 2003/10/01 22:35:52 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data");
use Strassen::Core;
use Strassen::Kreuzungen;
use Getopt::Long;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 9 }

my %opt;
GetOptions(\%opt, "v!") or die "usage!";

Strassen::set_verbose($opt{v});

my $s_fast = Strassen->new("strassen");
$s_fast->make_grid(Exact => 0, UseCache => 1);

my $s_exact = Strassen->new("strassen");
$s_exact->make_grid(Exact => 1, UseCache => 1);

my $kr = Kreuzungen->new(Strassen => $s_fast,
			 WantPos => 1,
			 Kurvenpunkte => 1,
			 UseCache => 1);

for my $p_def (# Köpenicker Chaussee/Rummelsburg (with wrong $p_kr)
	       ["16743,9200", "17072,8714", undef, "16449,9011"],
	       # etwas südlich davon
	       ["16912,8956", "17072,8714"],
	       # etwas nördlich davon
	       ["16587,9437", "16374,9760"],
	      ) {
    my($p, $p_exact, $p_fast, $p_kr) = @$p_def;
    if (!defined $p_fast) { $p_fast = $p_exact }
    if (!defined $p_kr)   { $p_kr   = $p_fast }
    is($s_exact->nearest_point($p), $p_exact);
    is(($kr->nearest_loop(split /,/, $p))[0], $p_kr);
    is($s_fast->nearest_point($p), $p_fast);
}

__END__
