# -*- perl -*-

#
# $Id: PilotPl12.pm,v 1.2 2002/04/15 22:24:42 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Karte::PilotPl12;

use Karte;
use Karte::PilotPl;

use strict;
use vars qw(@ISA $obj $conv_data);

@ISA = qw(Karte::PilotPl Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'pilot.pl-Karte (Region)',
       Token    => 'pilotpl12',
       Mimetype => 'image/png',

       Fs_dir   => "/usr/www/map/map-pilot-pl12",
       Cache_dir => "$Karte::cache_root/pilot-pl12",
       Root_URL  => "http://pilot.pi".
       "lot.pl/obrazek_new.php?katalog=pl12&num_x=%x&num_y=%y&y=0&x=0&copyright=0",
       Users    => ['www.pi'.
		    'lot.pl'],

       X0 => -2115832.46797278,
       X1 => 230.795920584112,
       X2 => -11.1116433828952,
       Y0 => -1924243.27760441,
       Y1 => 8.85046450209299,
       Y2 => 217.984698207802,

       Width  => 128,
       Height => 64,

       # XXX was ist richtig?
#       Scrollregion => [0, 0, 10000, 10000],
      };
    bless $self, $class;
}

sub filename {
    my($self, $x, $y) = @_;
    $self->fs_dir . "/" . $self->subst("pl12_%x_%y." . $self->ext, $x, $y);
}

$conv_data = <<'EOF';
# pl-NE.txt (real coords)	www.pilot.pl (map)
# lat		long		mapx	mapy	x	y	city
54.3500000      18.6333333	87	147	54	5	Danzig
53.8500000      23.0000000	97	143	53	27	Augustow
54.3413889      22.3183333	95	147	105	53	Goldap
53.4833333      18.7666667	87	140	75	13	Grudziadz
54.0833333      21.3833333	93	145	89	45	Ketrzyn
EOF

sub conv_data { $conv_data }

$obj = new Karte::PilotPl12;

1;
