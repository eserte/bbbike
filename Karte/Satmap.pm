# -*- perl -*-

#
# $Id: Satmap.pm,v 1.8 2005/04/05 22:39:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Satmap;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Satellitenkarte von Berlin (JPEG)',
       Token    => 'satmap',
       Mimetype => 'image/jpeg',
       Coordsys => 'S',

       Fs_base   => "satmap",
       Cache_dir => "$Karte::cache_root/satmap",

       X0 => -12907.0725073228,
       X1 => 20.0037569198591,
       X2 => 0.436930297596207,
       Y0 => 30249.8007162269,
       Y1 => 0.389073964340719,
       Y2 => -20.0349350027507,

       Width  => 195,
       Height => 195,

       # XXX was ist richtig?
       Scrollregion => [0, 0, 10000, 10000],
      };
    bless $self, $class;
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.%s", $self->fs_dir, $self->ext);
}

sub url { return undef;
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.%s", $self->root_url, $self->ext);
}

$obj = new Karte::Satmap;

1;
