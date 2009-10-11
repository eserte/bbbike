#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: point_in_poly.t,v 1.7 2005/04/05 22:48:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;

# To cease warnings (Can't find VectorUtil):
use FindBin;
BEGIN { push @INC, "$FindBin::RealBin/../../../lib" } # at end!!!

use VectorUtil::Inline;

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

my $mw = eval { tkinit };
if (!$mw) {
    plan skip_all => 'Cannot create MainWindow';
    CORE::exit(0);
}
plan tests => 1;

my $c = $mw->Scrolled("Canvas")->pack;
my $cw = 400;
my $ch = 300;

cmp_ok(VectorUtil::Inline::sizeof_POINT(), ">=", 8); # no support for 16bit systems...

my $weiter = 0;
{
    my $f = $mw->Frame->pack;
    Tk::grid($f->Button(-command => sub { $weiter = 1 },
			-text => "Cont"),
	     $f->Button(-command => sub { $weiter = -1 },
			-text => "Cancel")
	    );
}
$mw->OnDestroy(sub { $weiter = -1 });

my(@algo) = (
	     \&VectorUtil::Inline::point_in_poly,
	     \&VectorUtil::Inline::InsidePolygon,
	     \&VectorUtil::Inline::pnpoly,
	     \&VectorUtil::Inline::InsidePolygon2,
	    );

#@algo[0,2] = @algo[2,0];

while(1) {
    $weiter = 0;
    $c->delete("all");

    my @points = (10,10, 40,20, 60,40, 40,80, 10,80, 10,10);
    $c->createLine(@points);
    my($poly_buf, $points) = VectorUtil::Inline::array_to_POINT(@points);

    my @points2 = (160,130, 200,140, 190,180, 150,170, 160,130);
    $c->createLine(@points2);
    my($poly_buf2, $points2) = VectorUtil::Inline::array_to_POINT(@points2);

    my @points3 = (260,130, 300,140, 270,160, 290,180, 250,170, 260,130);
    $c->createLine(@points3);
    my($poly_buf3, $points3) = VectorUtil::Inline::array_to_POINT(@points3);

    my $mismatches = 0;
    for(1..500) {
	my($x,$y) = (int(rand($cw)), int(rand($ch)));
	my($point_buf) = VectorUtil::Inline::array_to_POINT($x,$y);
	my @in;
	my $mismatch;

	my $call_algos = sub {
	    my($poly_buf, $points) = @_;
	    @in = ();
	    foreach my $algo (@algo) {
		push @in, $algo->($poly_buf, $points, $point_buf);
		if (!$mismatch && @in > 1) {
		    $mismatch = $in[0] != $in[-1];
		}
	    }
	};

	$call_algos->($poly_buf, $points);
	$mismatches++ if $mismatch;

	if (!$in[0]) {
	    $call_algos->($poly_buf2, $points2);
	    if (!$in[0]) {
		$call_algos->($poly_buf3, $points3);
	    }
	}

	if ($Tk::VERSION < 804) {
	    $c->createLine($x,$y,-width=>2,-fill=>($mismatch?"yellow":$in[0]?"green":"red"));
	} else {
	    $c->createLine($x,$y,$x,$y+1,-width=>1,-fill=>($mismatch?"yellow":$in[0]?"green":"red"));
	}
    }
    if ($mismatches) {
	print "# $mismatches mismatches\n";
    }

    $c->configure(-scrollregion => [$c->bbox("all")]);

    $c->update;

    if (!defined $ENV{BATCH} || $ENV{BATCH} eq 'yes') {
	diag "Specify BATCH=no for interactive mode";
	select(undef,undef,undef,0.5);
	last;
    }

    $c->waitVariable(\$weiter);
    last if $weiter < 1;
}

#MainLoop;

__END__
