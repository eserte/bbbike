# -*- perl -*-

#
# $Id: FURadar3.pm,v 1.2 2001/11/07 23:16:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::FURadar3;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Koordinaten für FU-Radarkarte (Brandenburg)',
       Token    => 'fub3',
       Coordsys => 'F3',
       Users    => ['Meteorologisches Institut/FU Berlin'],

       X0 => -68310.5696413359,
       X1 => 355.86877070747,
       X2 => -4.13037623334894,
       Y0 => 585.277786899445,
       Y1 => 304.56864341429,
       Y2 => -448.689731534311,

      };
    bless $self, $class;
}

$obj = new Karte::FURadar3;

1;
