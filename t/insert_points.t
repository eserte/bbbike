#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: insert_points.t,v 1.8 2004/11/27 12:08:00 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use IO::Pipe;
use File::Temp qw(tempfile);

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
    print "1..0 # skip: insert_points script not available\n";
    exit 0;
}

plan tests => 5;

my($logfh,$logfile) = tempfile(SUFFIX => ".log");

my $dudenstr      = "9222,8787";
my $dudenstr_orig = $dudenstr; # "8796,8817";

BEGIN { $^W = 0 }
my @methfesselstr = qw(8982,8781 9057,8936);
BEGIN { $^W = 1 }

my @common_args = ("-report", "-useint",
		   "-datadir", $datadir, "-n",
		   "-logfile", $logfile,
		  );
SKIP: {
    skip "Workaround utf-8 problem", 4
	if $] == 5.008 && defined $ENV{LANG} && $ENV{LANG} =~ /utf/i;

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "grep",
					@common_args,
					$dudenstr_orig)->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung-orig.txt
			ampeln-orig
			ampelschaltung-orig
			hoehe-orig
			housenumbers-orig
			radwege-orig
			strassen-orig
		       )),
	   "orig and grep");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "grep",
					@common_args,
					"-noorig", "-coordsys", "H",
					$dudenstr)->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung.txt
			ampeln
			ampelschaltung
			hoehe
			housenumbers
			radwege_exact
			strassen
		       )),
	   "generated and grep");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "change",
					@common_args,
					$dudenstr_orig, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung-orig.txt
			ampeln-orig
			ampelschaltung-orig
			hoehe-orig
			housenumbers-orig
			radwege-orig
			strassen-orig
		       )),
	   "orig and change");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "change",
					@common_args,
					"-noorig", "-coordsys", "H",
					$dudenstr, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(../misc/ampelschaltung.txt
			ampeln
			ampelschaltung
			hoehe
			housenumbers
			radwege_exact
			strassen
		       )),
	   "generated and change");
    }

    {
	my @res = IO::Pipe->new->reader(@insert_points,
					"-operation", "changeline",
					@common_args,
					@methfesselstr, "0,0")->getlines;
	chomp @res;
	is(join(" ", sort @res),
	   join(" ", qw(qualitaet_s-orig strassen-orig)),
	   "orig and changeline");
    }

}

__END__
