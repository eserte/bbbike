#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: shapefile.t,v 1.14 2005/01/08 11:10:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003,2004,2005 Slaven Rezic. All rights reserved.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

use Test::More;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../..",
	 "$FindBin::RealBin/../../lib",
	);
use ESRI::Shapefile;
use BBBikeESRI;
use File::Basename;
use Strassen::Core;
use File::Spec::Functions qw(abs2rel);
use Getopt::Long;

my $v;
GetOptions("v" => \$v) or die "usage!";

my @files =
    ("/cdrom2/arcview/shapes/buf_grue.dbf",
     "/cdrom2/arcexplorer/aepdata/stpl_ges.dbf",
     "$ENV{HOME}/src/bbbike/projects/radlstadtplan_muenchen/data_Muenchen_DE/radroute_muc",
    );
push @files, glob("$FindBin::RealBin/../../mapserver/brb/data/*.shp");

@files = grep { -r $_ } @files;

if (!@files) {
    plan tests => 1;
    ok(1);
    diag("No shape files for testing found");
    exit 0;
}

plan tests => 5 * scalar @files;

for my $f (@files) {
    print STDERR "$f...\n" if $v;
    my $shapefile = new ESRI::Shapefile;
    $shapefile->set_file($f);
    ok(UNIVERSAL::isa($shapefile->Main, "ESRI::Shapefile::Main"),
       "main shp loaded from " . abs2rel($f));
    ok(UNIVERSAL::isa($shapefile->Index, "ESRI::Shapefile::Index"),
       "index loaded from " . abs2rel($f));
    ok(UNIVERSAL::isa($shapefile->DBase, "ESRI::Shapefile::DBase"),
       "dbase loaded from " . abs2rel($f));
    my $dbase_obj = $shapefile->DBase->tie_array;
 SKIP: {
	my $tests = 2;
	skip("DBase database is empty", $tests) if !$dbase_obj->FETCHSIZE;
	my $bbd = $shapefile->as_bbd;
	ok(length $bbd > 0, "Non empty bbd export");
	my $s = Strassen->new_from_data(split /\n/, $bbd);
	ok(scalar @{ $s->data } > 0, "Non empty Strassen::Core object");
    }
}

__END__
