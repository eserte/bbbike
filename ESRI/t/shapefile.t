#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: shapefile.t,v 1.11 2004/01/04 11:34:54 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use Test;

BEGIN { plan tests => 4 }

use ESRI::Shapefile;
use lib ("..", "../..");
use BBBikeESRI;
use File::Basename;

my $arcviewfile = "/cdrom2/arcview/shapes/buf_grue.dbf";
if (-r $arcviewfile) {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("/cdrom2/arcview/shapes/buf_grue");
    $shapefile->dump_bbd("/tmp/muenchen_gruen.bbd");
    ok(1);
} else {
    skip("$arcviewfile missing",1);
}

my $arcexplfile = "/cdrom2/arcexplorer/aepdata/stpl_ges.dbf";
if (-r $arcexplfile) {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("/cdrom2/arcexplorer/aepdata/stpl_ges");
    $shapefile->dump_bbd("/tmp/muenchen_stpl.bbd", -dbfinfo => 'NAME');
    ok(1);
} else {
    skip("$arcexplfile missing",1);
}

$testdir = "$ENV{HOME}/src/bbbike/projects/radlstadtplan_muenchen/data_Muenchen_DE";
if (-d $testdir) {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("$testdir/radroute_muc");
    $shapefile->dump_bbd("/tmp/muenchen.bbd");
    ok(1);
} else {
    skip("$testdir missing",1);
}

$mapserverdir = "$ENV{HOME}/src/bbbike/mapserver/brb/data";
if (-d $mapserverdir) {
    for my $f (glob("$mapserverdir/*.shp")) {
	print "# Check $f...\n";
	$f =~ s/\.shp$//;
	my $shapefile = new ESRI::Shapefile;
	$shapefile->set_file($f);
	$shapefile->dump_bbd("/tmp/" . basename($f));
    }
    ok(1);
} else {
    skip("$mapserverdir missing", 1);
}

__END__
