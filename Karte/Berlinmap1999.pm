# -*- perl -*-

#
# $Id: Berlinmap1999.pm,v 1.4 2001/11/07 23:16:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap1999;

use Karte;
use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 1999',
       Token    => 'b1999',
## XXX wann spuckt Stadtplandienst png aus?
       Mimetype => 'image/jpeg',
#       Mimetype => 'image/gif',
       Coordsys => 'B99',
       Users    => ['Stadtplandienst 1999'],

       Fs_base   => "map1999",
       Cache_dir => "$Karte::cache_root/map1999",
       Root_URL  => "http://www.stadtplandienst.de/cities/b/b/pq/r195/b9812c",

       X0 => -12822.983798183,
       X1 => 2.59708522291797,
       X2 => 0.0566209022327349,
       Y0 => 30066.3316396554,
       Y1 => 0.0562683600490778,
       Y2 => -2.60658816023295,

       Width  => 195,
       Height => 195,

       Scrollregion => [0, 0, 20000, 16000],

      };
    bless $self, $class;
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.spng", $self->fs_dir);
}

sub url {
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.spng", $self->root_url);
}

$obj = new Karte::Berlinmap1999;

1;
