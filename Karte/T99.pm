# -*- perl -*-

#
# $Id: T99.pm,v 1.2 2001/11/07 23:16:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::T99;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Telefonbuch99-Koordinaten',
       Token    => 't99',
       Coordsys => 'T',
       Users    => ['Telefonuch Berlin 1999'],
 
       X0 => -822980.141499423,
       X1 => 6.75042240446942,
       X2 => -0.136253985749713,
       Y0 => -5803467.10277387,
       Y1 => 0.149033545807703,
       Y2 => 11.0358139323583,

      };
    bless $self, $class;
}

$obj = new Karte::T99;

1;
