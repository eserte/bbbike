# -*- perl -*-

#
# $Id: Potsdammap2002.pm,v 1.2 2003/01/21 01:02:59 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Potsdammap2002;

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
       Name     => 'Potsdammap-Karte 2002',
       Token    => 'p2002',
       Mimetype => 'image/png',
       Coordsys => 'P02',

       Fs_base   => "potsdammap2002",
       Cache_dir => "$Karte::cache_root/potsdammap2002",

       X0 => -27118.2922275088,
       X1 => 2.48640820411157,
       X2 => 0.0505462153213597,
       Y0 => 16313.2155662763,
       Y1 => 0.0428225812233474,
       Y2 => -2.48818126426114,
#         X0 => -26547.0912826816,
#         X1 => 2.49052071196003,
#         X2 => -0.0787769633279676,
#         Y0 => -9616.52229986857,
#         Y1 => 0.0922560644249609,
#         Y2 => 2.57802118860165,

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
    $mapyy = $bm_y % $w_h;#XXX 200-?
    ($mapx, 50-$mapy, $mapxx, $mapyy)
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/${x}_$y.png", $self->fs_dir);
}

sub url { return undef;
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

$obj = new Karte::Potsdammap2002;

1;

__END__
