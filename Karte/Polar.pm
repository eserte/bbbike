# -*- perl -*-

#
# $Id: Polar.pm,v 1.16 2005/11/10 21:03:11 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# Die X0 etc.-Parameter basieren auf Dezimalgraden, die Ausgabe auf
# Grad/Minuten

package Karte::Polar;
use Karte;
use strict;
use vars qw(@ISA $obj);

@ISA = qw(Karte);

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Polare Koordinaten (WGS-84)',
       Token    => 'polar',
       Coordsys => 'P',

# alte Daten:
#         X0 => -790086.391400205,
#         X1 => 67845.9393462968,
#         X2 => -2073.78902640448,
#         Y0 => -5824916.26148241,
#         Y1 => 1021.55512610816,
#         Y2 => 110888.031499432,

#  # alte @polar_data-Daten, allerdings ohne die Brandenburger Daten:
#         X0 => -722207.53657807,
#         X1 => 68791.4431271489,
#         X2 => -3606.02363962925,
#         Y0 => -5908514.40301391,
#         Y1 => 797.096731883998,
#         Y2 => 112538.820481108,

#  # erzeugt aus meinem ersten Tracklog:
#         X0 => -794367.964940472,
#         X1 => 67839.1895690972,
#         X2 => -1990.98433751565,
#         Y0 => -5743124.94026287,
#         Y1 => 1318.09644368911,
#         Y2 => 109256.047141788,

#  # erzeugt aus dem Tracklog bis zum 2002-1-20:
#         X0 => -770895.051743501,
#         X1 => 67944.117707078,
#         X2 => -2464.85696704533,
#         Y0 => -5839995.54068123,
#         Y1 => 1199.84534625717,
#         Y2 => 111131.212045654,

# Tracklog bis 2002-1-26:
       X0 => -780761.760862528,
       X1 => 67978.2421158527,
       X2 => -2285.59137120724,
       Y0 => -5844741.03397902,
       Y1 => 1214.24447469596,
       Y2 => 111217.945663725,

# von T2001 abgeleitete Daten:
#         X0 => -799812.068665913,
#         X1 => 67920.5433536305,
#         X2 => -1910.14108336354,
#         Y0 => -5839468.36531781,
#         Y1 => 1319.94853184892,
#         Y2 => 111087.609558648,

#  # von 20000510.tracks abgeleitete Daten:
#         X0 => -798590.696343232,
#         X1 => 67705.589136054,
#         X2 => -1876.40600064877,
#         Y0 => -5621170.36905198,
#         Y1 => -458.511708212376,
#         Y2 => 107384.253345884,

#       Scrollregion => [0, 0, 11778, 9724],
#       Scrollregion => [0, -3000, 11778, 9724],
       Scrollregion => [0,0,60,30],
      };
    bless $self, $class;
}

# input: deg (decimal)
# output: deg, min, sec
# deg is signed
sub ddd2dms {
    my($ddd) = @_;

    my $north_east = $ddd >= 0;
    $ddd = -$ddd if !$north_east;
    my $deg = int($ddd);
    my $min = ($ddd-$deg)*60;
    my $sec = ($min-int($min))*60;
    $min = int($min);
    (($north_east ? $deg : -$deg), $min, $sec);
}

# input: deg (decimal)
# output: deg, min (with fraction)
# deg is signed
sub ddd2dmm {
    my($ddd) = @_;

    my $north_east = $ddd >= 0;
    $ddd = -$ddd if !$north_east;
    my $deg = int($ddd);
    my $min = ($ddd-$deg)*60;
    (($north_east ? $deg : -$deg), $min);
}

sub dms_human_readable {
    my($type, @dms) = @_;
    my $s = "";
    if (defined $type) {
	if ($type eq 'lat') {
	    if ($dms[0] >= 0) {
		$s .= "N ";
	    } else {
		$s .= "S ";
		$dms[0] *= -1;
	    }
	} elsif ($type eq 'long') {
	    if ($dms[0] >= 0) {
		$s .= "E ";
	    } else {
		$s .= "W ";
		$dms[0] *= -1;
	    }
	} else {
	    die "Unknown type, should be lat or long";
	}
    }
    $s . $dms[0] . "°" . sprintf("%02d", $dms[1]) . "'" . sprintf("%04.1f",$dms[2]) . "\"";
}

sub dmm_human_readable {
    my($type, @dmm) = @_;
    my $s = "";
    if (defined $type) {
	if ($type eq 'lat') {
	    if ($dmm[0] >= 0) {
		$s .= "N ";
	    } else {
		$s .= "S ";
		$dmm[0] *= -1;
	    }
	} elsif ($type eq 'long') {
	    if ($dmm[0] >= 0) {
		$s .= "E ";
	    } else {
		$s .= "W ";
		$dmm[0] *= -1;
	    }
	} else {
	    die "Unknown type, should be lat or long";
	}
    }
    $s . $dmm[0] . "°" . sprintf("%05.2f",$dmm[1]) . "'";
}

# input: deg, min, sec
# deg should be signed
# output: deg (decimal)
sub dms2ddd {
    my(@dms) = @_;
    die "Overflow" if ($dms[1] >= 60 || $dms[2] >= 60);
    $dms[0] + $dms[1]/60 + $dms[2]/3600;
}

# input: deg, min
# deg should be signed
# output: deg (decimal)
sub dmm2ddd {
    my(@dmm) = @_;
    die "Overflow" if $dmm[1] >= 60;
    $dmm[0] + $dmm[1]/60;
}

# input: a dms styled string e.g. N51 12 56.2
sub dms_string2ddd {
    my($s) = @_;
    if ($s =~ /([NSEW])(\d+)\s(\d+)\s([\d\.]+)/) {
	my($sgn) = $1 eq 'N' || $1 eq 'E' ? +1 : -1;
	dms2ddd($sgn*$2, $3, $4);
    } else {
	die "Can't parse the dms styled string <$s>";
    }
}

# input: a dmm styled string e.g. N51 12.1234
sub dmm_string2ddd {
    my($s) = @_;
    if ($s =~ /([NSEW])(\d+)\s([\d\.]+)/) {
	my($sgn) = $1 eq 'N' || $1 eq 'E' ? +1 : -1;
	dmm2ddd($sgn*$2, $3);
    } else {
	die "Can't parse the dms styled string <$s>";
    }
}

sub trim_accuracy {
    my(undef, $x, $y) = @_;
    (sprintf("%.6f", $x), sprintf("%.6f", $y));
}

$obj = new Karte::Polar;

1;

__END__

=head1 NAME

Karte::Polar - convert between BBBike and WGS84 coordinates

=head1 SYNOPSIS

See L<Karte>.

=head1 AUTHOR

Slaven Rezic.

=cut
