# -*- perl -*-

#
# $Id: GIS.pm,v 1.1 1998/06/24 00:28:08 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::GIS;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'GIS-Koordinaten (Gauß-Krüger?)',
       Token    => 'gis',
       Coordsys => 'G',
       
       X0 => -4591489.50876615,
       X1 => 0.992538370742847,
       X2 => 0.00700432484712343,
       Y0 => -5786504.87828011,
       Y1 => 0.00306758341161667,
       Y2 => 0.993710430173963,

      };
    bless $self, $class;
}

$obj = new Karte::GIS;

sub convert_to_route {
    my $file = shift;
    my @res;
    open(GIS, $file) or die "Can't open $file: $!";
    while(<GIS>) {
	chomp;
	if (/(\d+)\D+(\d+)/) {
	    my($x, $y) = ($1, $2);
	    push @res, [$obj->map2standard($x, $y)];
	} else {
	    warn "Can't parse $_";
	}
    }
    close GIS;
    @res;
}

sub save_as_route {
    my $file = shift;
    require Data::Dumper;
    my @res = convert_to_route($file);
    local $Data::Dumper::Indent = 0;
    print Data::Dumper->Dumpxs([\@res], ['realcoords_ref']);
}

1;
