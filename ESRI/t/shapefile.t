#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: shapefile.t,v 1.8 2003/01/08 20:12:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

use Test;

BEGIN { plan tests => 3 }

use ESRI::Shapefile;
use lib ("..", "../..");
use BBBikeESRI;

if (-r "/cdrom2/arcview/shapes/buf_grue.dbf") {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("/cdrom2/arcview/shapes/buf_grue");
    $shapefile->dump_bbd("/tmp/muenchen_gruen.bbd");
    ok(1);
} else {
    skip(1,1);
}

if (-r "/cdrom2/arcexplorer/aepdata/stpl_ges.dbf") {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("/cdrom2/arcexplorer/aepdata/stpl_ges");
    $shapefile->dump_bbd("/tmp/muenchen_stpl.bbd", -dbfinfo => 'NAME');
    ok(1);
} else {
    skip(1,1);
}

$testdir = "$ENV{HOME}/src/bbbike/projects/radlstadtplan_muenchen/data_Muenchen_DE";
if (-d $testdir) {
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file("$testdir/netzgraph");
    $shapefile->dump_bbd("/tmp/muenchen.bbd");
    ok(1);
} else {
    skip(1,1);
}

__END__
