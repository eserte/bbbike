# -*- perl -*-

#
# $Id: Soldner_alt.pm,v 1.3 2003/01/08 20:12:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Soldner_alt;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Soldner-Koordinaten für Berlin (alt)',
       Token    => 'soldner_alt',
       Coordsys => 'SA',

       X0 => -74262.0466519333,
       X1 => 0.999393924048797,
       X2 => -0.025171654508505,
       Y0 => -642.985102012544,
       Y1 => 0.0219505750838395,
       Y2 => 1.00183320147961,

      };
    bless $self, $class;
}

$obj = new Karte::Soldner_alt;

1;

__END__
