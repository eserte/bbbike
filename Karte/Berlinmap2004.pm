# -*- perl -*-

#
# $Id: Berlinmap2004.pm,v 1.1 2004/03/30 18:05:24 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Berlinmap2004;

use Karte;
use Karte::Berlinmap2002;

use POSIX qw(floor);

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap2002);

my $w_h = 200;

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 2004',
       Token    => 'b2004',
       Mimetype => 'image/png',
       Coordsys => 'B03',

       Fs_base   => "map2004",
       Cache_dir => "$Karte::cache_root/map2004",
       Root_URL  => "http://www.stadtplandienst.de/cities/berlin/grid1",
       Users    => ['Stadtplandienst 2004'],

       X0 => -11837.5948498893-15570+55,
       X1 => 2.48091758841086,
       X2 => 0.0455978928296558,
       Y0 => 41398.8254029303-6200-2975,
       Y1 => 0.0466983489977484,
       Y2 => -2.48388003012095,

       Width  => $w_h,
       Height => $w_h,

       Scrollregion => [0, 0, 20000, 16000],
      };
    bless $self, $class;
}

sub coord {
    my($self, $bm_x, $bm_y) = @_;
    my($mapx, $mapy, $mapxx, $mapyy);
    $mapx = int($bm_x/$w_h);
    $mapy = floor($bm_y/$w_h);
    $mapxx = $bm_x % $w_h;
    $mapyy = $bm_y % $w_h;
    ($mapx, 100-$mapy, $mapxx, $mapyy)
}

if (defined $obj) {
    my $new_obj = new Karte::Berlinmap2004;
    @{$obj}{keys %$new_obj} = values %$new_obj;
} else {
    $obj = new Karte::Berlinmap2004;
}

1;

__END__
