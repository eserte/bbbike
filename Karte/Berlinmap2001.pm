# -*- perl -*-

#
# $Id: Berlinmap2001.pm,v 1.4 2004/06/10 22:29:46 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap2001;

use Karte;
use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 2001',
       Token    => 'b2001',
       Mimetype => 'image/jpeg',
       Coordsys => 'B01',

       Fs_base   => "map2001",
       Cache_dir => "$Karte::cache_root/map2001",

       X0 => -11129.5289835653,
       X1 => 2.62357003833534,
       X2 => 0.0483637344933767,
       Y0 => 30110.0278729521,
       Y1 => 0.0498156344906825,
       Y2 => -2.631403716288,

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

sub url { return undef;
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.spng;img=JPG", $self->root_url);
}

sub cache_format { "%s/s-%s/%s.jpeg" }

$obj = new Karte::Berlinmap2001;

1;
