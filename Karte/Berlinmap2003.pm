# -*- perl -*-

#
# $Id: Berlinmap2003.pm,v 1.4 2004/06/10 07:29:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Berlinmap2003;

use Karte;
use Karte::Berlinmap2002;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap2002);

my $w_h = 200;

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 2003',
       Token    => 'b2003',
       Mimetype => 'image/png',
       Coordsys => 'B03',

       Fs_base   => "map2003",
       Cache_dir => "$Karte::cache_root/map2003",
       Root_URL  => "http://www.stadtp" .
       "landienst.de/cities/berlin/grid1",
       Users    => ['Stadtpla' .
		    'ndienst 2003'],

       X0 => -11837.5948498893-15570,
       X1 => 2.48091758841086,
       X2 => 0.0455978928296558,
       Y0 => 41398.8254029303-6200,
       Y1 => 0.0466983489977484,
       Y2 => -2.48388003012095,

       Width  => $w_h,
       Height => $w_h,

       Scrollregion => [0, 0, 20000, 16000],
      };
    bless $self, $class;
}

if (defined $obj) {
    my $new_obj = new Karte::Berlinmap2003;
    @{$obj}{keys %$new_obj} = values %$new_obj;
} else {
    $obj = new Karte::Berlinmap2003;
}

1;

__END__
