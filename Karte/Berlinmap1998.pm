# -*- perl -*-

#
# $Id: Berlinmap1998.pm,v 1.10 2004/06/10 22:29:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap1998;

use Karte;
use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'neue Berlinmap-Karte',
       Token    => 'newnewmap',
## XXX was ist korrekt? Check! XXX
#       Mimetype => 'image/jpeg',
       Mimetype => 'image/gif',

       Fs_base   => "newnewmap",
       Cache_dir => "$Karte::cache_root/newnewmap",
       Root_URL  => "http://www.stadtp" .
       "landienst.de/cities/b/b/pq/r195/195",
       Users    => ['Stadtpla' .
		    'ndienst 1998'],

       X0 => -12867.098241163,
       X1 => 2.31694338671684,
       X2 => 0.0597726714860419,
       Y0 => 30043.1335503155,
       Y1 => 0.0525784981597044,
       Y2 => -2.32447131600783,

       Width  => 195,
       Height => 195,
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

$obj = new Karte::Berlinmap1998;

1;
