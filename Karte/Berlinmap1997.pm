# -*- perl -*-

#
# $Id: Berlinmap1997.pm,v 1.8 2005/04/05 22:37:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::Berlinmap1997;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'neuere Berlinmap-Karte',
       Token    => 'newmap',
       Mimetype => 'image/gif',

       Fs_base   => "newmap",
       Cache_dir => "$Karte::cache_root/newmap",

       X0 => -12832.5603303591,
       X1 => 2.60107157639434,
       X2 => 0.0586042970543831,
       Y0 => 30135.3033132474,
       Y1 => 0.0598178946761238,
       Y2 => -2.61463460417602,

       Width  => 195,
       Height => 195,
      };
    bless $self, $class;
}

sub coord {
    my($self, $bm_x, $bm_y) = @_;
    my($mapx, $mapy, $mapxx, $mapyy);
    $mapx = int($bm_x/195);
    $mapy = int($bm_y/195);
    $mapxx = $bm_x % 195;
    $mapyy = $bm_y % 195;
    ($mapx, $mapy, $mapxx, $mapyy)
}

sub filename {
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.gif", $self->fs_dir);
}

sub url { return undef;
    my($self, $x, $y) = @_;
    sprintf("%s/s-$x/$y.gif", $self->root_url);
}

sub cache_format { "%s/s-%s/%s.gif" }

sub cache {
    my($self, $x, $y, $create) = @_;
    my $file = sprintf $self->cache_format, $self->cache_dir, $x, $y;
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

$obj = new Karte::Berlinmap1997;

1;
