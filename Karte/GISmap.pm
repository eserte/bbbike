# -*- perl -*-

#
# $Id: GISmap.pm,v 1.8 2002/07/13 20:55:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::GISmap;

use Karte;

use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Brandenburg-Karte',
       Token    => 'brbmap',
       Mimetype => 'image/gif',
       Coordsys => 'E',

       Fs_base => "gismap",

       Users    => ['E-Plus'],

       (0 ? # 1 == Anpassung für den Süden (Köthen etc.)
	(X0 => -123165.230498862,
	 X1 => 21.0910367327076,
	 X2 => 0.447607047213601,
	 Y0 => 118305.851399809,
	 Y1 => 0.399704472860833,
	 Y2 => -21.2953496893365,
	) : # "richtige" Koordinaten
	(X0 => -121386.178249258,
	 X1 => 21.3506107238918,
	 X2 => 0.0535889077211635,
	 Y0 => 119836.098179657,
	 Y1 => 0.0443840560242271,
	 Y2 => -21.3256129065485,
	)),

       Width  => 453,
       Height => 374,

#       Scrollregion => [0, 0, 11778, 9724],
#       Scrollregion => [-1000, -4000, 11778, 9724],
# West - Nord - Ost - Süd
#       Scrollregion => [-6000, -7000, 11778, 15000],
       Scrollregion => [-5771,-6817, 17585,16673],
      };
    bless $self, $class;
}

sub coord {
    my($self, $bm_x, $bm_y) = @_;
    my($mapx, $mapy, $mapxx, $mapyy);
    $mapx = _ceil($bm_x/453);
    $mapy = _ceil($bm_y/374);
    $mapxx = $bm_x % 453;
    $mapyy = $bm_y % 374;
    ($mapx, $mapy, $mapxx, $mapyy)
}

sub to_x {
    my($self, $x) = @_;
    my $ch = $x+ord('a')-1;
    if ($ch > ord('z')) {
	warn "Illegal character (code): $ch";
    } elsif ($ch < ord('a')) {
	$ch -= (ord('a')-ord('Z')-1);
    }
    chr($ch);
}

sub from_x {
    my($self, $x) = @_;
    if (ord($x) <= ord('Z')) {
	$x = ord($x) + (ord('a')-ord('Z')-1);
    } else {
	$x = ord($x);
    }
    $x -= (ord('a')-1);
}

sub to_y {
    my($self, $y) = @_;
    $y = 26 - $y;
    my $sign = '';
    if ($y < 0) {
	$sign = '-';
	$y = -$y;
    }
    sprintf("%s%02d", $sign, $y);
}

sub filename {
    my($self, $x, $y) = @_;
#     my $ch = $x+ord('a')-1;
#     if ($ch > ord('z')) {
# 	warn $ch;
#     } elsif ($ch < ord('a')) {
# 	$ch -= (ord('a')-ord('Z')-1);
#     }
    $x = $self->to_x($x);
#     $y = 26 - $y;
#     my $sign = '';
#     if ($y < 0) {
# 	$sign = '-';
# 	$y = -$y;
#     }
    $y = $self->to_y($y);
    sprintf("%s/%s%s.gif", $self->fs_dir, $x, $y);
#    sprintf("%s/%s%s%02d.gif", $self->fs_dir, chr($ch), $sign, $y);
}

sub coord_from_filename {
    my($self, $filename) = @_;
    if ($filename =~ m|/([a-zA-z]-?\d\d)\.gif|) {
	$1;
    } else {
	warn "Can't get coord information from $filename" if $^W;
	undef;
    }
}

sub xy_from_filename {
    my($self, $filename) = @_;
    if ($filename =~ m|/([a-zA-z])(-?\d\d)\.gif|) {
# 	my $x = $1;
# 	if (ord($x) >= ord('A')) {
# 	    $x = ord($x) + (ord('a')-ord('Z')-1);
# 	}
# 	$x -= (ord('a')+1);
	my $x = $self->from_x($1);
	my $y = 26 - $2;
	($x, $y);
    } else {
	undef;
    }
}

$obj = new Karte::GISmap;

sub _ceil {
    my $x = shift;
    my $r = int($x);
    $x < 0 ? $r-1 : $r;
}

1;
