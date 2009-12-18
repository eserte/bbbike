#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutiltest3.pl,v 1.4 2009/02/22 19:11:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Visual test for rectangle intersection function.

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

$top->title("Rectangle intersections");
my $c = $top->Canvas->pack;

if ($opt{interactive}) {
    while (1) {
	$c->delete("all");
	my(@rect1) = map { rand(300) } (1..4);
	my(@rect2) = map { rand(300) } (1..4);
	$c->createRectangle(@rect1);
	$c->createRectangle(@rect2);
	$c->configure(-bg => "#c0c0c0");

#   CHECK_IT: {
#  	my($xa1,$ya1,$xa2,$ya2) = @rect1;

#  	$c->createLine($xa1,$ya1,$xa2,$ya1, -fill => "blue");$c->update;
#  	warn "yeah", last CHECK_IT if VectorUtil::vector_in_grid($xa1,$ya1,$xa2,$ya1, @rect2);
#  	scalar <STDIN>;

#  	$c->createLine($xa2,$ya1,$xa2,$ya2, -fill => "blue");$c->update;
#  	warn "yeah", last CHECK_IT if VectorUtil::vector_in_grid($xa2,$ya1,$xa2,$ya2, @rect2);
#  	scalar <STDIN>;

#  	$c->createLine($xa2,$ya2,$xa1,$ya2, -fill => "blue");$c->update;
#  	warn "yeah", last CHECK_IT if VectorUtil::vector_in_grid($xa2,$ya2,$xa1,$ya2, @rect2);
#  	scalar <STDIN>;

#  #    return 1 if vector_in_grid($xa1,$ya2,$xa1,$ya1, @rect2);$c->update;
#  #    0;
#      }


	if (VectorUtil::intersect_rectangles(@rect1, @rect2)) {
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
