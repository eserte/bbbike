#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: insert_points.t,v 1.5 2004/05/09 22:12:44 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use IO::Pipe;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my @insert_points = ($^X, "$FindBin::RealBin/../miscsrc/insert_points");
my $datadir = "$FindBin::RealBin/../data";
if (!-x $insert_points[-1]) {
    plan tests => 0;
    exit 0;
}

plan tests => 5;

my $dudenstr      = "9222,8787";
my $dudenstr_orig = $dudenstr; # "8796,8817";

BEGIN { $^W = 0 }
my @methfesselstr = qw(8982,8781 9057,8936);
BEGIN { $^W = 1 }

SKIP: {
    skip "relation_gps-orig missing", 4
	unless -f "$datadir/relation_gps-orig";

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "grep",
					"-report", "-useint",
					"-datadir", $datadir, "-n",
					$dudenstr_orig)->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(ampeln-orig
			hoehe-orig
			housenumbers-orig
			radwege-orig
			relation_gps-orig
			strassen-orig
		       )),
	   "orig and grep");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "grep",
					"-report", "-useint",
					"-noorig", "-coordsys", "H",
					"-datadir", $datadir, "-n",
					$dudenstr)->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(ampeln
			hoehe
			housenumbers
			radwege_exact
			relation_gps
			strassen
		       )),
	   "generated and grep");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "change",
					"-report", "-useint",
					"-datadir", $datadir, "-n",
					$dudenstr_orig, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung-orig.txt
			ampeln-orig
			ampelschaltung-orig
			hoehe-orig
			housenumbers-orig
			radwege-orig
			relation_gps-orig
			strassen-orig
		       )),
	   "orig and change");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "change",
					"-report", "-useint",
					"-noorig", "-coordsys", "H",
					"-datadir", $datadir, "-n",
					$dudenstr, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung.txt
			ampeln
			ampelschaltung
			hoehe
			housenumbers
			radwege_exact
			relation_gps
			strassen
		       )),
	   "generated and change");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "changeline",
					"-report", "-useint",
					"-datadir", $datadir, "-n",
					@methfesselstr, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(qualitaet_s-orig strassen-orig)),
	   "orig and changeline");
    }

}

__END__
