# -*- perl -*-

#
# $Id: Berlinmap1996.pm,v 1.7 2004/06/10 23:02:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap1996;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'alte Berlinmap-Karte',
       Token    => 'berlinmap',
       Mimetype => 'image/gif',
       Coordsys => 'B',
       Users    => ['Stadtp' .
		    'landienst 1996'],
       Fs_base => "map",

       X0 => -12836.9327939148,
       X1 => 2.45136658405786,
       X2 => 0.056379335402179,
       Y0 => 30045.9720846232,
       Y1 => 0.0545170183739305,
       Y2 => -2.46551998888634,

       Width  => 850,
       Height => 810,

       Scrollregion => [0, 0, 20000, 16000],

       NoEnvironment => 1,
      };
    bless $self, $class;
}

sub incy {
    my($self, $y, $incy) = @_;
    chr(ord($y)+$incy);
}

sub coord {
    my($self, $bm_x, $bm_y) = @_;
    my($mapx, $mapy, $mapxx, $mapyy);
    $mapx = int($bm_x/640);
    $mapy = chr(int($bm_y/600) + ord('a'));
    $mapxx = $bm_x % 640 + 105;
    $mapyy = $bm_y % 600 + 105;
    ($mapx, $mapy, $mapxx, $mapyy)
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/$y%02d.gif", $self->fs_dir, $x);
}

$obj = new Karte::Berlinmap1996;

1;
