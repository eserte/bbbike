# -*- perl -*-

#
# $Id: Cityinfo.pm,v 1.3 2002/07/13 20:55:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Cityinfo;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Cityinfo-Karte',
       Token    => 'cityinfo',
       Mimetype => 'image/gif',
       Coordsys => 'Y',

       Fs_base   => "cityinfo",
       Cache_dir => "$Karte::cache_root/cityinfo",
       Root_URL  => "http://germany.city-info.ch/germany.rcl?",
       Users    => ['Cityinfo'],

       X0 => -501509.375271274,
       X1 => 61.8845992415835,
       X2 => -1.07034442370699,
       Y0 => 665624.66206395,
       Y1 => 1.7419763359727,
       Y2 => -62.8883085120949,

#        X0 => -522916.26374542,
#        X1 => 61.8845992415839,
#        X2 => 1.0703444237072,
#        Y0 => -592141.508177956,
#        Y1 => 1.74197633597394,
#        Y2 => 62.8883085120946,

       Width  => 605,
       Height => 605,

       Scrollregion => [0000, 5000, 10000, 20000],
      };
    bless $self, $class;
}

sub coord {
    my($self, $bm_x, $bm_y) = @_;
    $bm_y = 20000 - $bm_y;
    my($offx, $offy) = ($bm_x % $self->{Width}, $bm_y % $self->{Height});
    if ($offx > $self->{Width}/2)  { $offx = $offx-$self->{Width}  }
    if ($offy > $self->{Height}/2) { $offy = $offy-$self->{Height} }
    (int($bm_x)-$offx, int($bm_y)-$offy,
     -int($self->{Width}/2)-$offx, -int($self->{Height}/2)+$offy);
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s%s,%s,%s,%s,%s.%s", $self->fs_dir, $x, $y, $self->{Width}, $self->{Height}, 1, $self->ext);
}

sub url {
    my($self, $x, $y) = @_;
    sprintf("%s%s,%s,%s,%s,%s", $self->root_url, $x, $y, $self->{Width}, $self->{Height}, 1);
}

sub cache {
    my($self, $x, $y, $create) = @_;
    my $file = sprintf "%s/%s-%s.gif", $self->cache_dir, $x, $y;
    if ($create) {
	require File::Basename;
	my $dirname = File::Basename::dirname($file);
	require File::Path;
	File::Path::mkpath([$dirname], 1, 0755);
	if (!-d $dirname && !-w $dirname) {
	    return undef;
	}
    }
    sprintf($file);
}

$obj = new Karte::Cityinfo;

1;
