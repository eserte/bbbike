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
if (!GetOptions("dbfinfo=s"	 => \$dbfinfo,
		"dbfcol=i"    => \$dbfcol,
		"forcelines!" => \$forcelines,
		"int|integer!"=> \$do_int,
	       )) {
    usage();
}

sub usage {
    my $msg = shift;
    if (eval q{ require Pod::Usage; 1; }) {
	Pod::Usage::pod2usage(2);
    } else {
	$msg = "usage?" if !$msg;
	die $msg;
    }
}

my $from = shift or usage("ESRI file missing");
my $to   = shift or usage("Output file missing");

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

=head1 NAME

esri2bbd.pl - convert ESRI shapefiles to bbd data

=head1 SYNOPSIS

    esri2bbd.pl [-dbfinfo string] [-dbfcol columnindex] [-forcelines] [-int]
                esrifile bbdfile

=head1 DESCRIPTION

B<esri2bbd.pl> converts an ESRI shapefile into a bbbike data file
(bbd). The options are:

=over

=item -dbfinfo string

Use an optional dbase database to get attribute information. I<string>
has to be C<NAME>.

=item -dbfcol columnindex

Use the specified column from the dbase database to set the "name"
attribute of the generated bbd file.

=item -forcelines

Force all polygons into lines.

=item -int

Convert coordinates from float into integers.

=back

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<ESRI::Shapefile>, L<BBBikeESRI>, L<bbbike>.

=cut
