# -*- perl -*-

#
# $Id: Pg.pm,v 1.4 2007/07/21 17:18:31 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Pg;

use strict;
use vars qw($VERSION $DSN $USER $dbh);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use BBBikeUtil qw(is_in_path);
use Strassen::Core;
use DBI;
use DBD::Pg;
use File::Temp qw(tempfile);
use File::Spec qw();
use File::Basename qw(dirname);

$USER = ((getpwuid($<))[0]) if !defined $USER;
$DSN = "dbi:Pg:dbname=$USER" if !defined $DSN;

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
    my $table_name = "bbbike_" . $s->id;
    $table_name =~ s{^(.+)\..{1,4}$}{$1}; # throw away file extension (assuming it's rather short)
    $table_name =~ s{[/\.-]}{_}g; # mask invalid characters
    $table_name;
}

=pod

B<import_data>

Example usage:

    perl -MStrassen -MStrassen::Pg -e '$s=MultiStrassen->new(qw(strassen landstrassen landstrassen2)); Strassen::Pg::import_data($s)'

See more notes below.

=cut

sub import_data {
    my($s, %args) = @_;
    my $polar = delete $args{polar};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $table = unique_table_name($s);
    my($dbname) = $DSN =~ /dbname=([^;]+)/;
    if (!is_in_path("shp2pgsql")) {
	die "shp2pgsql is missing, maybe PostGIS is not installed?";
    }
    my($fh, $filename) = tempfile(UNLINK => 1);
    my $bbbike_root = dirname(dirname(File::Spec->rel2abs(__FILE__)));
    local $ENV{PATH} = "$ENV{PATH}:$bbbike_root/miscsrc";
    my(@files) = $s->file;
    system("bbd2esri",
	   ($polar ? "-polar" : ()),
	   @files, "-o", $filename); # XXX opts? ret code?
    #open(PSQL, "| psql 2>/dev/null") or die "Cannot execute psql: $!";
    open(PSQL, "| psql") or die "Cannot execute psql: $!";
    open(SHP2PGSQL, "-|") or do {
	warn "Creating table $table from data in $filename.shp...\n";
	my @cmd = ("shp2pgsql",
		   # "-I", # gist index is created below
		   # "-N", "skip", # do not want NULL geometries #XXX does not work?
		   "-S", # generate LINESTRINGS; simplifies handling
		   ($polar ? ("-s", 4326) : ()),
		   "-d", "$filename.shp", $table, $dbname);
	exec @cmd;
	die "The command <@cmd> failed: \$!=$! \$?=$?";
    };
    while(<SHP2PGSQL>) {
	s{(\s+varchar\()0(\))}{${1}1${2}}; # fixes varchar(0) problem
	print PSQL $_;
    }
    close SHP2PGSQL;
    # Create gist index
    print PSQL "CREATE INDEX ${table}_gist ON $table USING GIST (the_geom GIST_GEOMETRY_OPS);\n";
    # Cluster the index for read-only access, needs non-NULL column
    print PSQL "DELETE FROM ${table} WHERE the_geom IS NULL;\n";
    print PSQL "ALTER TABLE ${table} ALTER COLUMN the_geom SET NOT NULL;\n";
    print PSQL "CLUSTER ${table}_gist ON ${table};\n";
    # ...
    print PSQL "VACUUM ANALYZE;\n";
    close PSQL;
    for my $ext (qw(dbf shp inx)) {
	unlink "$filename.$ext"; # these are not automatically deleted
    }
}

1;

__END__

=pod

B<PostgreSQL installation and configuration>

Installing was rather difficult. I decided to use postgresql81, which
was the latest package on my FreeBSD 6.2 machine.

Set
	PGSQL_VER=81
in /etc/make.conf

Install postgresql81-server with pkg_add.

Add
	postgresql_enable="YES"
to /etc/rc.conf

Initialize postgres database:
	sudo /usr/local/etc/rc.d/010.pgsql.sh initdb

Start postgres:
	sudo /usr/local/etc/rc.d/010.pgsql.sh start

As pgsql user, create the "eserte" database user. Give all
permissions, especially for creating databases.
	createuser eserte

As eserte, create my own database:
	createdb eserte

Compile and install postgis via ports. Set both the UTF-8 and GEOS
options.

Afterwork needed:
	createlang plpgsql eserte
	psql -d eserte -f /usr/local/share/postgis/lwpostgis.sql
	psql -d eserte -f /usr/local/share/postgis/spatial_ref_sys.sql

Compile and install p5-DBD-PG via ports (package does not work,
because all postgres-related packages use PostgreSQL 7.x).

Now the import (see above) should work, hopefully...

=cut
