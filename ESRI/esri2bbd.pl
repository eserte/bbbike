#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: esri2bbd.pl,v 1.12 2003/11/11 23:32:25 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003 Slaven Rezic. All rights reserved.
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
my $do_autoconv;
if (!GetOptions("dbfinfo=s"   => \$dbfinfo,
		"dbfcol=i"    => \$dbfcol,
		"forcelines!" => \$forcelines,
		"int|integer!"=> \$do_int,
		"autoconv!"   => \$do_autoconv,
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
		     ($do_autoconv ? (-autoconv => 1) : ()),
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

    esri2bbd.pl [-dbfinfo string] [-dbfcol columnindex] [-forcelines]
                [-int] [-autoconv]
                esrifile bbdfile

=head1 DESCRIPTION

B<esri2bbd.pl> converts an ESRI shapefile into a bbbike data file
(bbd). The options are:

=over

=item -dbfinfo string

Use an optional DBase database to get attribute information. I<string>
has to be C<NAME>.

=item -dbfcol columnindex

Use the specified column from the DBase database to set the "name"
attribute of the generated bbd file.

=item -forcelines

Force all polygons into lines.

=item -int

Convert coordinates from float into integers.

=item -autoconv

Automatically convert coordinates to fit in the bbbike application.

=back

=head1 HOWTO use ESRI shapefiles in bbbike

Here are some checkpoints for using ESRI shapefiles in bbbike routing:

=over

=item *

Make sure that the source ESRI shapefile only contains PolyLine
records. These polylines should constitute a street network. Street
crossings should be real network nodes, that is the two polylines
should have the same coordinates at the crossing point. Street names
may be attached in a DBase file, see the C<-dbfinfo> and C<-dbfcol>
options above.

=item *

Convert the ESRI shapefile with this script:

    perl esri2bbd.pl -autoconv .../esrifile.shp .../output.bbd

=item *

Start bbbike with no initial data:

    env LC_ALL=en perl bbbike -fast -menu

The setting of the environment variable causes bbbike to start with
english labels.

=item *

Select the menu Settings > Draw additionally > Draw street layers and
select the converted bbd file. After a while, you should see the
street network in bbbike's canvas.

=item *

Now replace the file F<data/strassen> with the new bbd file. If you
restart bbbike without the C<-fast> option, then you should also see
the street network, but now you should be able to calculate routes by
clicking on the streets to set start and goal points.

=item *

For a custom application using the BBBike modules, you should take a
look at the L<BBBikeRouting> documentation. The small example in the
L<SYNOPSIS|BBBikeRouting/"SYNOPSIS"> should be a good base for an own
routing interface. You have only to replace the lines

    $routing->Start->Street("from street");
    $routing->Goal->Street("to street");

with

    $routing->Start->Coord("$x,$y");
    $routing->Goal->Coord("$x,$y");

because the street-to-coordinate conversion is still too tightly
connected with the original Berlin data.

=item *

This is just a start --- street routing may be hard if everything is
done right. Especially if it comes to take care of one way streets,
prohibited turns, temporarily blocked streets, differentiation between
"fast" streets (highways, freeways) and other streets. Routing for
cyclists is even harder, as there are far more attributes to take care
of (quality of streets, mounts, cycle paths...).

=back

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<ESRI::Shapefile>, L<BBBikeESRI>, L<bbbike>.

=cut
