# -*- perl -*-

#
# $Id: Berlinmap2002.pm,v 1.3 2003/01/08 20:12:51 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Berlinmap2002;

use Karte;
use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte Karte::Berlinmap1997);

my $w_h = 200;

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Berlinmap-Karte 2002',
       Token    => 'b2002',
       Mimetype => 'image/png',
       Coordsys => 'B02',

       Fs_base   => "map2002",
       Cache_dir => "$Karte::cache_root/map2002",
       Root_URL  => "http://www.stadtplandienst.de/cities/berlin/grid1",
       Users    => ['Stadtplandienst 2002'],

       X0 => -11837.5948498893,
       X1 => 2.48091758841086,
       X2 => 0.0455978928296558,
       Y0 => 41398.8254029303,
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
    $mapy = int($bm_y/$w_h);
    $mapxx = $bm_x % $w_h;
    $mapyy = $bm_y % $w_h;
    ($mapx, 100-$mapy, $mapxx, $mapyy)
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/${x}_$y.png", $self->fs_dir);
}

sub url {
    my($self, $x, $y) = @_;
    sprintf("%s/${x}_$y.png", $self->root_url);
}

sub incy {
    my($self, $y, $incy) = @_;
    $y-$incy;
}

sub cache_format { "%s/%s_%s.png" }

sub coord_from_filename {
    my($self, $filename) = @_;
    if ($filename =~ m|/(\d+_\d+)\.png|) {
	$1;
    } else {
	warn "Can't get coord information from $filename" if $^W;
	undef;
    }
}

$obj = new Karte::Berlinmap2002;

1;

__END__
