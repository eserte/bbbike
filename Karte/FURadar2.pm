# -*- perl -*-

#
# $Id: FURadar2.pm,v 1.2 2001/11/07 23:16:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::FURadar2;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Koordinaten für FU-Radarkarte (Norddeutschland)',
       Token    => 'fub2',
       Coordsys => 'F2',
       Users    => ['Meteorologisches Institut/FU Berlin'],

       X0 => -258453.453278907,
       X1 => 1003.00452339661,
       X2 => 28.294082861365,
       Y0 => 252644.749799214,
       Y1 => 37.5352416282891,
       Y2 => -997.593298089638,

      };
    bless $self, $class;
}

$obj = new Karte::FURadar2;

1;
