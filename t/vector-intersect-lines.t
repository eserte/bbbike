#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutiltest4.pl,v 1.3 2009/02/22 19:11:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Visual test for line intersection function.

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data");

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

use Getopt::Long;
use VectorUtil; $VectorUtil::VERBOSE=1;

my %opt = (interactive => 0,
	  );
GetOptions(\%opt, "interactive!")
    or die "usage: $0 [-interactive]";

$top->title("Line intersections");
my $c = $top->Canvas->pack;

if ($opt{interactive}) {
    while(1) {
	$c->delete("all");
	my(@l1) = map { rand(300) } (1..4);
	my(@l2) = map { rand(300) } (1..4);
	$c->createLine(@l1);
	$c->createLine(@l2);
	$c->configure(-bg => "#c0c0c0");

	if (VectorUtil::intersect_lines(@l1, @l2)) {
	    $c->configure(-bg => "#ffc0c0");
	    warn "Intersection!";
	}
	$c->update;
	print STDERR "<Return> to continue, <Control-C> to abort ... ";
	scalar <STDIN>;
    }
} else {
    diag "Use -interactive option to run interactive test";
}
pass "Everything worked OK?";

__END__
