# -*- perl -*-

#
# $Id: GDF.pm,v 1.6 2002/07/13 20:55:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# Bei der Telefonbuch-CDROM (1999) werden ähmliche Daten
# mit einer geringeren Genauigkeit (2 Dezimalstellen weniger)
# verwendet.

package Karte::GDF;
use Karte;
use strict;
use vars qw(@ISA $obj);
use Karte::T99;

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $t99 = $Karte::T99::obj;
    my $self =
      {
       Name     => 'GDF-Koordinaten',
       Token    => 'gdf',
       Coordsys => 'W',
       Users    => [qw/Teleatlas Veturo FahrinfoBerlin/],
       Description_de => <<EOF,
GDF-Daten liegen häufig im Longitude/Latitude-Format nach WGS-84
(einheitlicher Ellipsoid) vor. Dabei bezeichnen die Zahlen vor dem
Komma die Grade und nach dem Komma die Dezimalstellen (nicht Minuten
und Sekunden).
EOF

       X0 => -789351.104447435,
       X1 => 0.06760274161218,
       X2 => -0.0020260527650519,
       Y0 => -5801944.92780532,
       Y1 => 0.00122144839033196,
       Y2 => 0.110401509607961,

       # Brandenburg
#       Scrollregion => [13090316, 52339723, 13760339, 52673740],
       # Poland
       Scrollregion => [14124354,49013626,24150743,54833015],

      };
    bless $self, $class;
}

$obj = new Karte::GDF;

1;
