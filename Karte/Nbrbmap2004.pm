# -*- perl -*-

#
# $Id: Nbrbmap2004.pm,v 1.1 2004/06/10 07:17:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte::Nbrbmap2004;

use Karte::Berlinmap1997;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte::Berlinmap1997);

my $w_h = 200;

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Nbrb-Karte 2004',
       Token    => 'nbrb2004',
       Mimetype => 'image/png',
       Coordsys => 'NBRB04',

       Fs_base   => "neubrandenburgmap2004",
       Cache_dir => "$Karte::cache_root/neubrandenburgmap2004",
       Root_URL  => "http://www.stadtpl" .
                    "andienst.de/cities/neubrandenburg/grid1",
       Users    => ['Stadtpla' .
		    'ndienst 2004'],

       X0 => -13047.6421433902,
       X1 => 2.71803024996842,
       X2 => 0.0950187785147749,
       Y0 => 140098.011437312,
       Y1 => -0.147517921653971,
       Y2 => -2.6811626755466,

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

$obj = new Karte::Nbrbmap2004;

1;

__END__
