# -*- perl -*-

#
# $Id: FURadar.pm,v 1.2 2001/11/07 23:16:22 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::FURadar;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Koordinaten für FU-Radarkarte (Vergrößerung)',
       Token    => 'fub',
       Coordsys => 'F',

       Users    => ['Meteorologisches Institut/FU Berlin'],

##XXX alte Werte mit Berliner Stadtrandpunkten
## allerdings scheinen die Berliner Grenzen *sehr* ungenau eingezeichnet
## zu sein. Also unten nochmal nur mit den Brandenburger Punkten.
#        X0 => -132542.034610489,
#        X1 => 493.754590334284,
#        X2 => 16.0465410945931,
#        Y0 => 120947.733997271,
#        Y1 => 16.6390039425509,
#        Y2 => -486.124810345239,

       X0 => -133527.211398949,
       X1 => 498.76245944952,
       X2 => 14.0474850053258,
       Y0 => 121663.738652453,
       Y1 => 20.2159492362084,
       Y2 => -496.082496660836,

      };
    bless $self, $class;
}

$obj = new Karte::FURadar;

1;
