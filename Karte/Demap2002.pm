# -*- perl -*-

#
# $Id: Demap2002.pm,v 1.1 2003/01/22 13:47:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Demap2002;

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
       Name     => 'Demap-Karte 2002',
       Token    => 'de2002',
       Mimetype => 'image/png',
       Coordsys => 'DE02',

       Fs_base   => "demap2002",
       Cache_dir => "$Karte::cache_root/demap2002",
       Root_URL  => "http://www.stadtplandienst.de/cities/de/datlas",
       Users    => ['Stadtplandienst 2002'],

       X0 => -514788.710269181,
       X1 => 17.025482843199,
       X2 => -0.712859465956318,
       Y0 => 259649.848871089,
       Y1 => -0.711248025414887,
       Y2 => -16.9951660668275,
#         X0 => -987396.807840798,
#         X1 => 42.2756614597724,
#         X2 => 2.57683873595281,
#         Y0 => 876.550946473719,
#         Y1 => -2.46137901460171,
#         Y2 => 42.254254304464,

       Width  => $w_h,
       Height => $w_h,

       Scrollregion => [0, 0, 40000, 50000],

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
    ($mapx, 250-$mapy, $mapxx, $mapyy)
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

$obj = new Karte::Demap2002;

1;

__END__
