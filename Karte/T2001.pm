# -*- perl -*-

#
# $Id: T2001.pm,v 1.2 2001/11/07 23:16:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::T2001;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Telefonbuch2001-Koordinaten',
       Token    => 't2001',
#       Coordsys => 'T2001',
       Users    => ['Telefonbuch Berlin 2001'],

       X0 => -799812.068651445,
       X1 => 6.79205433538192,
       X2 => -0.19101410837248,
       Y0 => -5839468.36442838,
       Y1 => 0.131994853128503,
       Y2 => 11.1087609541797,

      };
    bless $self, $class;
}

$obj = new Karte::T2001;

1;
