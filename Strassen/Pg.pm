# -*- perl -*-

#
# $Id: Pg.pm,v 1.1 2003/02/19 23:33:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX ummmm....????

package Strassen::Pg;

use strict;
use vars qw($VERSION $DSN $dbh);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use BBBikeUtil qw(is_in_path);
use Strassen::Core;
use DBI;
use DBD::Pg;
use File::Temp qw(tempfile);

$DSN = "dbi:Pg:dbname=eserte" if !defined $DSN;

sub import {
    # Not yet: override_functions();
}

sub override_functions {
    # override make_grid and grid
    my $orig_make_grid = \&Strassen::make_grid;
    my $orig_grid = \&Strassen::grid;
    *Strassen::make_grid = \&pg_make_grid;
    *Strassen::grid = \&pg_grid;
}

sub dbh {
    if (!$dbh) {
	$dbh = DBI->connect($DSN) or die $!;
    }
    $dbh;
}

sub pg_make_grid {
    my($s, %args) = @_;
    die;
}

sub pg_grid {
    my($s, $x, $y) = @_;
    my $sth = grid_sth($s);
    $sth->execute($x - $s->{GridWidth}, $y - $s->{GridWidth},
		  $x + $s->{GridWidth}, $y + $s->{GridWidth});
    # XXX and now???
    die;
}

sub grid_sth {
    my $s = shift;
    my $sth = $s->{PgGridSth};
    if (!$sth) {
	$sth = $s->{PgGridSth} = dbh()->prepare
	    ("select * from " . unique_table_name($s)
	     . "where the_geom && 'BOX3D(? ?, ? ?)'::box3d");
    }
    $sth;
}

sub unique_table_name {
    my $s = shift;
    "bbbike_" . $s->id;
}

# Example usage:
# perl -MStrassen -MStrassen::Pg -e '$s=MultiStrassen->new(qw(strassen landstrassen landstrassen2)); Strassen::Pg::import_data($s)'
sub import_data {
    my $s = shift;
    my $table = unique_table_name($s);
    my($dbname) = $DSN =~ /dbname=([^;]+)/;
    if (!is_in_path("shp2pgsql")) {
	die "No PostGIS installed?";
    }
    my($fh, $filename) = tempfile();
    local $ENV{PATH} = "$ENV{PATH}:$ENV{HOME}/src/bbbike/miscsrc"; # XXX
    my(@files) = $s->file;
    system("bbd2esri", @files, "-o", $filename); # XXX opts? ret code?
    open(PSQL, "| psql 2>/dev/null") or die $!;
    open(SHP2PGSQL, "-|") or do {
	exec("shp2pgsql", "-d", "$filename.shp", $table, $dbname);
	die $!;
    };
    while(<SHP2PGSQL>) {
	print PSQL $_;
    }
    close SHP2PGSQL;
    print PSQL "CREATE INDEX ${table}_gist ON $table USING GIST (the_geom GIST_GEOMETRY_OPS);\n";
    print PSQL "VACUUM ANALYZE;\n";
    close PSQL;
    for my $ext (qw(dbf shp inx)) {
	unlink "$filename.$ext";
    }
}

1;

__END__
