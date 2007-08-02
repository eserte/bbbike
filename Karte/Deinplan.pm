# -*- perl -*-

#
# $Id: Deinplan.pm,v 1.1 2007/08/02 21:54:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Deinplan;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Deinplan-Karte',
       Token    => 'deinplan',
       Coordsys => 'DP',

       X0 => -6318.99957672401,
       X1 => 2.89210632564425,
       X2 => 0.0721837177577989,
       Y0 => 28403.5266183543,
       Y1 => 0.0558397826109509,
       Y2 => -2.94886545401142,
      };
    bless $self, $class;
}

$obj = new Karte::Deinplan;

1;
