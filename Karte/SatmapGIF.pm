# -*- perl -*-

#
# $Id: SatmapGIF.pm,v 1.2 1998/08/01 21:05:27 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::SatmapGIF;

use Karte::Satmap;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Satmap);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();
    @{$self}{qw(Name Token Mimetype)} = ('Satellitenkarte von Berlin (GIF)',
					 'satmap_gif',
					 'image/gif',
					);
    bless $self, $class;
}

$obj = new Karte::SatmapGIF;

1;
