#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-kreuzungen.t,v 1.3 2009/02/01 16:25:57 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 10;

use_ok "Strassen::Kreuzungen";

use Strassen::Core;

my $s = Strassen->new("$FindBin::RealBin/../data/strassen");
my $kr = Kreuzungen->new(Strassen => $s,
			 WantPos => 1,
			 Kurvenpunkte => 1,
			 UseCache => 1,
			);
isa_ok($kr, "Kreuzungen");

{
    my $at_point     = "9229,8785"; # Dudenstr./Mehringdamm
    my $before_point = "9272,8781"; # Platz der Luftbrücke
    my $after_point  = "9227,8890"; # Mehringdamm

    for ($at_point, $before_point, $after_point) {
	ok($kr->get($_), "Got simple entry for point <$_>")
	    or diag("This may fail if data in <strassen> changed");
	ok($kr->get_records($_), "Got complex entry for point <$_>"); 
    }

    my %situation = $kr->situation_at_point($at_point, $before_point, $after_point);
    is($situation{before_street}->[Strassen::NAME()], "Platz der Luftbrücke", "Street before");
    is($situation{after_street}->[Strassen::NAME()],  "Mehringdamm", "Street after");

#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%situation],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

}

__END__
