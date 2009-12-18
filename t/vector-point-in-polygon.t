#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: vectorutiltest5.pl,v 1.3 2009/02/22 19:24:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004,2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data");

BEGIN {
    if (!eval q{
	use Object::Iterate;
	use Test::More;
	use Tk;
	1;
    }) {
	print "1..0 # skip no Object::Iterate, Test::More and/or Tk modules\n";
	exit;
    }
}

my $top = eval { Tk::tkinit() };
if (!$top) {
    print "1..0 # skip cannot create main window: $@\n";
    exit;
}

plan tests => 1;

use File::Temp qw(tempfile);
use Getopt::Long;
use Object::Iterate qw(iterate);

use BBBikeTrans;
use Strassen::Core;
use Strassen::MultiStrassen;
use VectorUtil qw(point_in_polygon); $VectorUtil::VERBOSE=1;

my %opt = (interactive => 0,
	  );
GetOptions(\%opt, "interactive!")
    or die "usage: $0 [-interactive]";

if (!$opt{interactive}) {
    diag "Use -interactive option to run interactive test";
    pass "Everything worked OK?";
    exit;
}

use vars qw($scale);
$scale = 4;
old_create_transpose_subs();

$top->title("Point in polygons");
my $c = $top->Scrolled("Canvas", -scrollbars => "osoe")->pack(-fill => "both", -expand => 1);
$c->CanvasBind('<2>',
	       [sub {
		    my($w,$x,$y) = @_;
		    $w->scan('mark',$x,$y);
		},Tk::Ev('x'),Tk::Ev('y')]);
$c->CanvasBind('<B2-Motion>',
	       [sub {
		    my($w,$x,$y) = @_;
		    $w->scan('dragto',$x,$y,1);
		},Tk::Ev('x'),Tk::Ev('y')]);


my(undef,$tempfile) = tempfile(UNLINK => 1, SUFFIX => "_berlin_polygon.bbd");
die if !$tempfile;
system("$^X $FindBin::RealBin/../miscsrc/combine_streets.pl -closedpolygon berlin > $tempfile");

my $berlin = Strassen->new($tempfile);
my $strassen = MultiStrassen->new("strassen", "landstrassen");

my @polygon = map { [ split /,/, $_ ] } @{ $berlin->get(0)->[Strassen::COORDS] };
$c->createLine((map { transpose_ls_slow(@$_) } @polygon),
	       -width => 2, -fill => "black");

my $last_time = Tk::timeofday();

print STDERR <<EOF;
Canvas is now constantly filled with crossing points in and outer
Berlin. Please be patient, but you can already take a look around.
EOF

iterate {
    for my $p (@{ $_->[Strassen::COORDS] }) {
	my($px,$py) = split /,/, $p;

	my $in_polygon = point_in_polygon([ $px, $py ], \@polygon);

	my($cx,$cy) = transpose_ls_slow($px,$py);
	$c->createLine($cx,$cy,$cx,$cy, -width => 4, -capstyle => "round",
		       -fill => $in_polygon ? "green3" : "red");

	if (Tk::timeofday() - $last_time > 1) {
	    $c->configure(-scrollregion => [ $c->bbox("all") ]);
	    $c->update;
	    $last_time = Tk::timeofday();
	}
    }
} $strassen;

print STDERR "Filling finished!\n";

$c->configure(-scrollregion => [ $c->bbox("all") ]);
MainLoop;

pass "Everything worked OK?";

__END__
