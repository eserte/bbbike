#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: esri2bbd.pl,v 1.9 2003/01/08 20:11:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeESRI;
use Getopt::Long;
use strict;

my $dbfinfo;
my $dbfcol;
my $forcelines;
my $do_int;
GetOptions("dbfinfo=s"	 => \$dbfinfo,
	   "dbfcol=i"    => \$dbfcol,
	   "forcelines!" => \$forcelines,
	   "int|integer!"=> \$do_int,
	  );

my $from = shift or die "ESRI file?";
my $to   = shift or die "Output file?";

my $shapefile = new ESRI::Shapefile;
$shapefile->set_file($from);
$shapefile->dump_bbd($to,
		     -dbfinfo    => $dbfinfo,
		     -dbfcol     => $dbfcol,
		     -forcelines => $forcelines,
		     ($do_int ? (-conv => \&do_int) : ()),
		    );

sub do_int {
    map {
	join(",", int($_->[0]), int($_->[1]));
    } @{ $_[0] }
}

__END__
