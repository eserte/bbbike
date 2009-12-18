#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vector-polygon-center.t,v 1.10 2009/02/22 18:59:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Visual test for the get_polygon_center function in VectorUtil. For
# comparison, it is possible to get the centroid as calculated by
# Math::Geometry::Planar. In most simple cases, both results are quite
# the same, but sometimes it is some pixels off (but not very
# significant). Note that some polygons could crash
# Math::Geometry::Planar, see
# https://rt.cpan.org/Ticket/Display.html?id=43510

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Test::More;
	use Tk;
	use Tk::MinMaxScale;
	1;
    }) {
	print "1..0 # skip no Test::More, Tk and/or Tk::MinMaxScale modules\n";
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

my($c, $s);
my $min = 2;
my $max = 20;
my @points;

my %opt = (interactive => 0,
	  );
GetOptions(\%opt, "interactive!")
    or die "usage: $0 [-interactive]";

sub doit {
    my $line = shift;
    if (!defined $line) {
	my $points = int(rand($max)+1);
	if ($points < $min) { $points = $min }
	for (1 .. $points) {
	    push @points, int(rand($c->width)), int(rand($c->height));
	}
    } else {
	warn "<$line>";
	@points = split /\s+/, $line;
    }

    $c->delete("polygon || center");
    $c->createPolygon(@points, -tags => "polygon");

    my($x,$y) = VectorUtil::get_polygon_center(@points);

    if (!defined $x) {
	warn "undef...";
	#$c->messageBox(-message => "Returned undef");
    } else {
	$c->createLine($x,$y,$x,$y,-fill=>"green",-width=>4,-capstyle=>"round",-tags=>"center");
    }

    $c->configure(-scrollregion => [$c->bbox("all")]);
}

sub center_by_math_geometry_planar {
    my($xy1, $mgp);
    if (@points >= 8) {
	require Math::Geometry::Planar;
	eval {
	    $mgp = Math::Geometry::Planar->new;
	    my @p;
	    for (my $i=0; $i<=$#points; $i+=2) {
		push @p, [@points[$i,$i+1]];
	    }
	    $mgp->points(\@p);
	    $xy1 = $mgp->centroid;
	};
	if ($@) {
	    warn $@;
	} else {
	    my @c = @$xy1; # typically x/y ?
	    $c->createLine(@c, @c,-fill=>"red",-width=>4,-capstyle=>"round",-tags=>"center") if $xy1;
	}
    }
}

sub next_bbbike_data {
    if (!$s) {
	require Strassen::Core;
	$s = Strassen->new("sehenswuerdigkeit");
	$s->init;
    }
    my $r = $s->next;
    while (@{ $r->[Strassen::COORDS()] }) {
	last if (@{ $r->[Strassen::COORDS()] } > 1);
	$r = $s->next;
    }
    if (!@{ $r->[Strassen::COORDS()] }) {
	$s->init;
	$r = $s->next;
    }
    doit(join(" ", map { split(/,/, $_) } @{$r->[Strassen::COORDS()]}));
}

$top->title("Polygon centers");
{
    my $f = $top->Frame->pack;
    $f->Label(-text => "get_polygon_center")->pack(-side => "left");
    my $mm = $f->MinMaxScale(-orient => "horiz", -variablemin => \$min, -variablemax => \$max, -from => 2, -to => 20)->pack(-side => "left");
}

$c = $top->Scrolled("Canvas")->pack(qw/-fill both -expand 1/);

$c->update; # to get width/height up to date
doit();

$top->Button(-text => "do it random",
	     -command => sub { doit() })->pack;
{
    my $var;
    my $f = $top->Frame->pack;
    $f->Button(-text => "do it:",
	       -command => sub {
		   (my $splitted = $var) =~ s{,}{ }g;
		   doit($splitted);
	       })->pack(-side => "left");
    $f->Entry(-textvariable => \$var)->pack(-side => "left");
}
$top->Button(-text => "next from bbbike data",
	     -command => sub { next_bbbike_data })->pack;
# Does not seem to work for triangular shapes:
$top->Button(-text => "by math::geometry::planar",
	     -command => sub { center_by_math_geometry_planar })->pack;
if ($opt{interactive}) {
    Tk::MainLoop();
} else {
    diag "Use -interactive option to run interactive test";
}
pass "Everything worked OK?";

__END__
