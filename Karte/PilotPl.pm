# -*- perl -*-

#
# $Id: PilotPl.pm,v 1.3 2002/04/15 22:24:53 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::PilotPl;

use Karte;

use strict;
use vars qw(@ISA $obj $conv_data);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'pilot.pl-Karte (Details)',
       Token    => 'pilotpl',
       Mimetype => 'image/png',

       Fs_dir   => "/usr/www/map/map-pilot-pl",
       Cache_dir => "$Karte::cache_root/pilot-pl",
       Root_URL  => "http://pilot.pil" .
       "ot.pl/obrazek_new.php?katalog=pl13&num_x=%x&num_y=%y&y=0&x=0&copyright=0",
       Users    => ['www.pil'.
		    'ot.pl'],

       X0 => -2098331.16766041,
       X1 => 77.2601058052018,
       X2 => -4.05623472724147,
       Y0 => -1922717.34204521,
       Y1 => 3.17998615288155,
       Y2 => 72.342869303792,

       Width  => 128,
       Height => 64,

       # XXX was ist richtig?
#       Scrollregion => [0, 0, 10000, 10000],
      };
    bless $self, $class;
}

# for map_surround (define if map y does not increase from top to bottom)
sub incy {
    my($self, $y, $incy) = @_;
    $y-$incy;
}

# pseudo map coords => (map image x, map image y, x on image, y on image)
sub coord {
    my($self, $sx, $sy) = @_;
    my($x,$y) = ($sx, $sy);
    my($mapx,$mapy) = (int($x/128), int($y/64)+1);
    ($x, $y) = ($x%128, (64-$y)%64);
#warn "$sx/$sy =>    ($mapx,$mapy,$x,$y)";
    ($mapx,$mapy,$x,$y)
}

# (map image x, map image y, x on image, y on image) => pseudo map coords
sub anti_coord {
    my($self, $mapx,$mapy,$x,$y) = @_;
    ($mapx * 128 + $x, $mapy * 64 - $y);
}

sub subst {
    my($self, $fmt, $x, $y) = @_;
    (my $r = $fmt) =~ s/%x/$x/g;
    $r             =~ s/%y/$y/g;
    $r;
}

sub filename {
    my($self, $x, $y) = @_;
    $self->fs_dir . "/" . $self->subst("pl13_%x_%y." . $self->ext, $x, $y);
}

sub url {
    my($self, $x, $y) = @_;
    $self->subst($self->root_url, $x, $y);
}

sub cache {
    my($self, $x, $y, $create) = @_;
    my $file = sprintf "%s/%s-%s.%s", $self->cache_dir, $x, $y, $self->ext;
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

$conv_data = <<'EOF';
# pl-NE.txt (real coords)	www.pilot.pl (map)
# lat		long		mapx	mapy	x	y	city
54.3500000      18.6333333	260	441	53	5	Danzig
53.8500000      23.0000000	290	428	31	20	Augustow
54.3413889      22.3183333	285	439	57	38	Goldap
53.4833333      18.7666667	260	420	105	39	Grudziadz
54.0833333      21.3833333	279	433	10	12	Ketrzyn
EOF

sub conv_data { $conv_data }

# for use in "convert_berlinmap.pl -mapmod"
sub create_conv_data {
    my $self = shift;
    require Karte;
    Karte::preload('Polar','Standard');
    $Karte::Polar::obj = $Karte::Polar::obj;
    my @map_data = split /\n/, $self->conv_data;
    @map_data = grep { /^[^\#]/ } @map_data;
    my $ret;
    for (@map_data) {
	my($lat, $long, $mapx, $mapy, $x, $y, $city) = split /\s+/;
	my($sx,$sy) = map {int} $Karte::Polar::obj->map2standard($long, $lat);
	my($pseudox,$pseudoy) = $self->anti_coord($mapx,$mapy,$x,$y);
	$ret .= "$sx,$sy\t$pseudox,$pseudoy\t# $city\n";
    }
warn $ret;
    $ret;
}

$obj = new Karte::PilotPl;

1;
