# -*- perl -*-

#
# $Id: GPS.pm,v 1.4 2001/03/19 23:17:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# Das ist das Format von einem GPS-Empfänger (welchem?)
# Auch hier werden Longitude/Latitude-Daten verwendet. Die Kommastelle
# liegt hierbei nach der vierten Stelle. Wir können also hier die
# Telefonbuch-CDROM-Daten (1999) verwenden.

# XXX Der Name des Moduls wird evtl. um den Namen des Empfängers
# oder des Standard ergänzt.

# Die X0 etc.-Parameter basieren auf Dezimalgraden, die Ausgabe auf
# Grad/Minuten

package Karte::GPS;
use Karte;
use strict;
use vars qw(@ISA $obj);
use Karte::Polar;

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $t99 = $Karte::Polar::obj;
    my $self =
      {
       Name     => 'GPS-Koordinaten',
       Token    => 'gps',
       Coordsys => 'p',

       X0 => $t99->{X0},
       X1 => $t99->{X1},
       X2 => $t99->{X2},
       Y0 => $t99->{Y0},
       Y1 => $t99->{Y1},
       Y2 => $t99->{Y2},

#       Scrollregion => [13090316, 52339723, 13760339, 52673740],

      };
    bless $self, $class;
}

$obj = new Karte::GPS;

1;
