# -*- perl -*-

#
# $Id: Standard.pm,v 1.6 2001/11/07 23:16:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Standard;

use Karte;

use strict;
use vars qw(@ISA $obj $init_scrollregion);

@ISA = qw(Karte);

# Koordinaten sind in m angegeben (z.B. hafas)

$init_scrollregion = 10000; # siehe Wert in bbbike

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Standard',
       Token    => 'standard',
       Coordsys => 'H',

       Users    => ['Fahrinfo CD-ROM 1996'],

       Scrollregion => [-$init_scrollregion, -$init_scrollregion,
			$init_scrollregion, $init_scrollregion],
      };
    bless $self, $class;
}

sub standard2map { @_[1,2] }
sub map2standard { @_[1,2] }

$obj = new Karte::Standard;

1;
