# -*- perl -*-

#
# $Id: Berlinmap2000.pm,v 1.3 2004/06/10 22:29:54 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap2000;

use Karte;
use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 2000',
       Token    => 'b2000',
       Mimetype => 'image/jpeg',
       Coordsys => 'B00',

       Fs_base   => "map2000",
       Cache_dir => "$Karte::cache_root/map2000",

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

sub url { return undef;
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.spng;img=JPG", $self->root_url);
}

sub cache_format { "%s/s-%s/%s.jpeg" }

$obj = new Karte::Berlinmap2000;

1;
