#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vector-in-grid-tk.t,v 1.4 2009/02/22 18:56:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";

BEGIN {
    if (!eval q{
	use Test::More;
	use Tk;
	1;
    }) {
	print "1..0 # skip no Test::More and/or Tk modules\n";
	exit;
    }
}

my $top = eval { Tk::tkinit() };
if (!$top) {
    print "1..0 # skip cannot create main window: $@\n";
    exit;
}

plan tests => 1;

use VectorUtil;
use Getopt::Long;

my %opt = (xs => 1,
	   interactive => 0,
	  );
GetOptions(\%opt, "xs!", "interactive!")
    or die "usage: $0 [-xs] [-interactive]";

if ($opt{xs}) {
    eval {
	require VectorUtil::InlineDist;
    };
    if ($@) { warn $@ }
}

my $c;
my $drinnen = 1;
my $draussen = 1;

sub doit {
    my($gridx1,$gridy1,$gridx2,$gridy2) = @_;

    $c->delete("drinnen");
    $c->delete("draussen");

    foreach (1..100) {
	# zufällige Vektoren erzeugen und zeichnen
	my($x1, $y1) = (rand(20)-5, rand(20)-5);
	my($x2, $y2) = (rand(20)-5, rand(20)-5);

	my $l = $c->createLine(transform($x1,$y1), transform($x2,$y2),
			       -arrow => "last",
			       -fill => "green");

	# Einfärben anhand der Tatsache, ob der Vektor draußen ($r == 0)
	# oder drinnen ($r != 0) ist.
	my $r = VectorUtil::vector_in_grid($x1,$y1,$x2,$y2,
					   $gridx1,$gridy1,$gridx2,$gridy2
					  );
	if ($r) {
	    $c->itemconfigure($l, -fill => {1 => 'red',
					    2 => 'blue',
					    3 => 'black',
					    4 => 'yellow4'}->{$r},
			      -tags => "drinnen",
			      -state => $drinnen ? "normal" : "hidden",
			     );
	    if ($r > 5) { $c->delete($l) }
	} else {
	    $c->itemconfigure($l,
			      -tags => "draussen",
			      -state => $draussen ? "normal" : "hidden",
			     );
	}
	# $c->delete($l) if !$r; # alle löschen, die draussen bzw. drinnen sind
	#$top->update;
	#sleep 1000;
    }
}


$top->title("Vector in grid");
$c = $top->Canvas->pack;

#($x1, $y1) = (-1, 2);
#($x2, $y2) = ( 3, 6);
#($x2, $y2) = ( -0, 6);

# Gitter-Koordinaten festlegen
my $gridx1 = 0;
my $gridx2 = 5;
my $gridy1 = 0;
my $gridy2 = 5;

# Gitter zeichnen
$c->createLine(transform($gridx1,$gridy1), transform($gridx1,$gridy2),
	       transform($gridx2,$gridy2), transform($gridx2,$gridy1),
	       transform($gridx1,$gridy1));

doit($gridx1,$gridy1,$gridx2,$gridx2);

foreach my $def (["drinnen", \$drinnen],
		 ["draussen", \$draussen],
		) {
    my($label, $varref) = @$def;
    $top->Checkbutton(-text => $label,
		      -variable => $varref,
		      -command => sub {
			  if (!$$varref) {
			      $c->itemconfigure
				  ($label, -state => "hidden");
			  } else {
			      $c->itemconfigure
				  ($label, -state => "normal");
			  }
		      })->pack;
}
$top->Button(-text => "do it",
	     -command => sub { doit($gridx1,$gridy1,$gridx2,$gridy2) })->pack;
if ($opt{interactive}) {
    Tk::MainLoop();
} else {
    diag "Use -interactive option to run interactive test";
}
pass "Everything worked OK?";

sub transform {
    my($x,$y) = @_;
    ($x*20+100, $y*20+100);
}

__END__
