#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-tie.t,v 1.1 2003/06/21 14:36:03 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use Strassen::Core;
use Strassen::Tie;
use Data::Dumper;
use Benchmark;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 3 }

my $s = Strassen->new("strassen");

tie my @t, 'Strassen::Tie', $s;
ok((tied @t)->isa('Strassen::Tie'));

LOOP: {
    $s->init;
    foreach my $t (@t) {
	my $r = $s->next;
	my $ser1 = Dumper($r);
	my $ser2 = Dumper($t);
	if ($ser1 ne $ser2) {
	    ok($ser1, $ser2);
	    last LOOP;
	}
    }
    ok(1);
}

my $r = $s->next;
ok(@{$r->[Strassen::COORDS]}, 0);

if (defined &Benchmark::cmpthese) {
    Benchmark::cmpthese(1,
	  {'while' => sub {
	       $s->init;
	       while(1) {
		   my $r = $s->next;
		   last if !@{ $r->[Strassen::COORDS] };
		   my $name   = $r->[Strassen::NAME];
		   my $cat    = $r->[Strassen::CAT];
		   my $coords = $r->[Strassen::COORDS];
	       }
	   },
	   'tie' => sub {
	       for my $r (@t) {
		   my $name   = $r->[Strassen::NAME];
		   my $cat    = $r->[Strassen::CAT];
		   my $coords = $r->[Strassen::COORDS];
	       }
	   },
	   'overload' => sub {
	       for my $r (@$s) {
		   my $name   = $r->[Strassen::NAME];
		   my $cat    = $r->[Strassen::CAT];
		   my $coords = $r->[Strassen::COORDS];
	       }
	   },

	  });
}

__END__
