# -*- perl -*-

#
# $Id: UTM.pm,v 1.8 2003/02/06 21:53:01 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
#
#      This program is free software; you can redistribute it and/or modify
#      it under the terms of the GNU General Public License as published by
#      the Free Software Foundation; either version 2 of the License, or
#      (at your option) any later version.
#
# Original formulas from:
#
#  gpsman --- GPS Manager: a manager for GPS receiver data
#
#  Copyright (c) 2001 Miguel Filgueiras (mig@ncc.up.pt) / Universidade do Porto
#
# (file posncomp.tcl)
# (file projections.tcl)
# (file compute.tcl)
# and other...
#

package Karte::UTM;

use strict;
use vars qw($UTMlat0 $UTMk0 $UPSk0 @EXPORT_OK);
# prefer POSIX over Math::Trig
BEGIN {
    if (!eval 'use POSIX qw(floor pow atan tan); 1') {
	require Math::Trig;
	*atan  = \&Math::Trig::atan;
	*tan   = \&Math::Trig::tan;
	*floor = sub {
	    my $int = int($_[0]);
	    return $int   if ($_[0] == $int || $_[0] >= 0);
	    return $int-1;
	};
	*pow = sub { $_[0]**$_[1] };
    }
}

use base qw(Exporter);
@EXPORT_OK = qw(ConvertDatum ConvToTM ConvFromTM %GRIDZN DegreesToGKK GKKToDegrees UTMToDegrees DegreesToUTM);

$UTMlat0 = 0;
$UTMk0 = 0.9996;
$UPSk0 = 0.994;

use vars qw(%GRIDDEF %GRIDZN @GRIDS %ZGRID);

# grids with no zones
%GRIDDEF = (
    BWI => ['BWI', 400000, 0, 'KM', [0, 1e6, 0, 1e6], [0, 10, -66, -55]],
    CMP => ['CMP', 200000, 300000, 'KM', [64e3, 368e3, 0, 580e3], [36.95, 42.17, -9.66, -6.08], 'Lisboa'],
    IcG => ['IcG', 500000, 500000, 'KM', [0, 1e6, 0, 1e6], [63.5, 65, -30, -10], 'Hjorsey 1955'],
    LV03 => ['LV03', 200000, 600000, 'KM', [0, 1e6, 0, 1e6], [45, 48, 6, 11], 'CH-1903'],
    RDG => ['RDG', 155000, 463000, 'KM', [0, 29e4, 29e4, 63e4], [50.3, 53.45, 3, 7.45], 'Rijks Driehoeksmeting'],
    SEG => ['SEG', 1500000, 0, 'KM', [12e5, 19e5, 61e5, 77e5], [54, 70, 10, 26]],
);

# zones of grids (regular expressions to recognize valid zones)
%GRIDZN = (
    BNG  => '([A-H]|[J-Z])([A-H]|[J-Z])',
    GKK  => '[0-5]',
    ITM  => '[A-H]|[J-Z]',
    KKJY => '27E',
    KKJP => '[1-4]',
    TWG  => '[1-6]',
);

@GRIDS = sort (keys(%GRIDZN), keys(%GRIDDEF));

# initialize grid information
$ZGRID{"UTM/UPS"} = 1;
{
    for my $g (@GRIDS) {
	# grid has more than 1 zone (see SetUpGrids for those that do not)
	$ZGRID{$g} = 1;
	# at present, all grids with >1 zone have no fixed datum
	#XXXset GRD[set g](datum) ""
    }
}

=item DegreesToUTM

Convert position in lat/long signed degrees and given datum to UTM/UPS.

=cut

sub DegreesToUTM {
    my($lat, $long, $datum) = @_;
    my($zn, $ze, $x, $y);
    if ($lat >= -80 && $lat <= 84) {
        $zn = 67 + int(floor(($lat+80)/8.0));
        # skip I, O
        $zn++ if ($zn > 72);
        $zn++ if ($zn > 78);
        $zn = chr($zn);
        my $long0 =  6*int(floor($long/6.0))+3;
        $ze = sprintf "%02d", int(floor(($long0+183)/6.0));
        my(@cs) = ConvToTM($lat, $long, $UTMlat0, $long0, $UTMk0, $datum);#XXXsub
        $x = sprintf "%.0f", 5e5+$cs[0];
	$y = $cs[1];
        if ($lat < 0) { $y = int(1e7+$y) }
    } else {
        $ze = "00";
        if ($lat > 0) {
            if ($long < 0) { $zn = "Y" } else { $zn = "Z" }
        } else {
            if ($long < 0) { $zn = "A" } else { $zn = "B" }
        }
        ($x, $y) = ConvToUPS($lat, $long, $datum);
    }
    ($ze, $zn, $x, $y);
}

=item ConvToTM

Convert to TM.
$lat0, $long0: centre coordinates in signed degrees.
$k0: scale at central meridian.

=cut

sub ConvToTM {
    my($lat, $long, $lat0, $long0, $k0, $datum) = @_;

    my($a, $f) = EllipsdData($datum);
    my $es = $f*(2-$f);
    my $phi = $lat*0.01745329251994329576;
    my $lambda = $long*0.01745329251994329576;
    my $phi0 = $lat0*0.01745329251994329576;
    my $lambda0 = $long0*0.01745329251994329576;
    my $m0 = TMAux($phi0, $a, $es);
    my $m  = TMAux($phi, $a, $es);
    my $et2 = $es/(1-$es);
    my $n = sin($phi); $n = $a/sqrt(1-$es*$n*$n);
    my $t = tan($phi); $t = $t*$t;
    my $c = cos($phi);
    my $A = ($lambda-$lambda0)*$c; $c = $et2*$c*$c;
    my $x = sprintf "%.0f", ($k0*$n*($A+(1-$t+$c)*$A*$A*$A/6+
				     (5-18*$t+$t*$t+72*$c-58*$et2)*
				     $A*$A*$A*$A*$A/120));
    my $y = sprintf "%.0f", ($k0*($m-$m0+$n*tan($phi)*
				  ($A*$A/2+(5-$t+9*$c+4*$c*$c)*$A*$A*$A*$A/24+
				   (61-58*$t+$t*$t+600*$c-330*$et2)*
				   $A*$A*$A*$A*$A*$A/720)));
    ($x, $y);
}

=item ConvFromTM

Convert from TM.
$lat0, $long0: centre coordinates in signed degrees.
$k0: scale at central meridian.

=cut

sub ConvFromTM {
    my($x, $y, $lat0, $long0, $k0, $datum) = @_;

    my($a,$f) = EllipsdData($datum);
    my $es = $f*(2-$f);
    my $phi0 = $lat0*0.01745329251994329576;
    my $lambda0 = $long0*0.01745329251994329576;
    my $m0 = TMAux($phi0, $a, $es);
    my $m = $m0+1.0*$y/$k0;
    my $et2 = $es/(1-$es);
    my $e1 = sqrt(1-$es); $e1 = (1-$e1)/(1+$e1);
    my $mu = $m/($a*(1-$es/4-3*$es*$es/64-0.01953125*$es*$es*$es));
    my $phi1 = ($mu+(1.5*$e1-27*$e1*$e1*$e1/32)*sin($mu+$mu)+
		(1.3125-1.71875*$e1*$e1)*$e1*$e1*sin(4*$mu)+
		1.572916666667*$e1*$e1*$e1*sin(6*$mu)+
		+2.142578125*$e1*$e1*$e1*$e1*sin(8*$mu));
    my $c1 = cos($phi1); $c1 = $et2*$c1*$c1;
    my $t1 = tan($phi1); $t1 = $t1*$t1;
    my $n1 = sin($phi1);
    my $r1 = $a*(1-$es)/pow(1-$es*$n1*$n1, 1.5);
    $n1 = $a/sqrt(1-$es*$n1*$n1);
    my $d = $x/($n1*$k0);
    my $lat = ($phi1-$n1*tan($phi1)/$r1*
	       ($d*$d/2-(5+3*$t1+10*$c1-4*$c1*$c1-9*$et2)*
		$d*$d*$d*$d/24+
		(61+90*$t1+298*$c1+45*$t1*$t1-252*$et2-3*$c1*$c1)*
		$d*$d*$d*$d*$d*$d/720))*57.29577951308232087684;
    my $long = ($lambda0+($d-(1+($t1+$t1)+$c1)*$d*$d*$d/6+
			  (5-($c1+$c1)+28*$t1-3*$c1*$c1+8*$et2+24*$t1*$t1)*
			  $d*$d*$d*$d*$d/120)/cos($phi1))*57.29577951308232087684;
    ($lat, $long);
}

sub TMAux {
    my($phi, $a, $es) = @_;

    if (abs($phi) < 1e-20) { return 0 }
    my $es2 = $es*$es;
    my $es3 = $es2*$es;
    $a*((1-$es/4-0.046875*$es2-0.01953125*$es3)*$phi-
	(0.375*$es+0.09375*$es2+0.0439453125*$es3)*
	sin($phi+$phi)+
	(0.05859375*$es2+0.0439453125*$es3)*sin(4*$phi)-
	0.011393229166667*$es3*sin(6*$phi))
}

sub ConvToUPS {
    my($lat, $long, $datum) = @_;

    my($a, $f) = EllipsdData($datum);
    my $es = $f*(2-$f);
    my $lambda = $long*0.01745329251994329576;
    my $phi = abs($lat*0.01745329251994329576);
    my $e = sqrt($es);
    my $ee = $e*sin($phi);
    my $t = tan(0.78539816339744830961-$phi/2)/pow((1-$ee)/(1+$ee),($e/2));
    my $rho = 2*$a*$UPSk0*$t/sqrt(pow(1+$e,1+$e)*pow(1-$e,1-$e));
    my $x = sprintf "%.0f", ($rho*sin($lambda)+2e6);
    my $y = $rho*cos($lambda);

    if ($lat > 0) { $y = -$y }
    ($x, sprintf "%.0f", $y+2e6);
}

=item UTMToDegrees

Convert from UTM/UPS to lat/long in signed degrees.

=cut

sub UTMToDegrees {
    my($ze, $zn, $x, $y, $datum) = @_;

    if ($ze != 0) {
	my $long0 = -183+6.0*$ze;
        if ($zn le "M") {
            $y = $y-1e7;
        }
        $x = $x-5e5;
        ConvFromTM($x, $y, $UTMlat0, $long0, $UTMk0, $datum);
    } else {
        ConvFromUPS($zn, $x, $y, $datum);
    }
}

sub ConvFromUPS {
    my($zn, $x, $y, $datum) = @_;

    my($a, $f) = EllipsdData($datum);
    my $es = $f*(2-$f);
    my $e = sqrt($es);
    $x = $x-2e6;
    $y = $y-2e6;
    my $rho = sqrt($x*$x+$y*$y);
    my $t = $rho*sqrt(pow(1+$e,1+$e)*pow(1-$e,1-$e))/(2*$a*$UPSk0);
    my $lat = UPSAux($e, $t)*57.29577951308232087684;
    my $long;
    if (abs($y) > 1e-20) {
	$long = atan(abs(1.0*$x/$y))*57.29577951308232087684;
    } else {
        $long = 90;
        if ($x < 0) { $long = -$long }
    }
    if ($zn gt "M") {
        $y = -$y;
    }
    if ($y < 0) { $long = 180-$long }
    if ($x < 0) { $long = -$long }
    ($lat, $long);
}

sub UPSAux {
    my($e, $t) = @_;

    my $phi = 1.57079632679489661923-2*atan($t);
    my $old = 999.9e-99;
    my $maxIterations = 20;
    my $i = 0;
    while (abs(($phi-$old)/$phi) > 1e-8 && $i < $maxIterations) {
        $i++;
        $old = $phi;
        $phi = (1.57079632679489661923-
		2*atan($t*pow((1-$e*sin($phi))/((1+$e*sin($phi))),$e/2.0)));
    }
    $phi;
}

=item ConvertDatum

Convert position given in lat/long signed degrees from one datum
to another, and yield position in format $pformt

=cut

sub ConvertDatum {
    my($latd, $longd, $datum0, $datum1, $pformt) = @_;
    my($clat, $clong);
    if ($datum0 ne $datum1) {
	my $phi = $latd*0.01745329251994329576;
	my $lambda = $longd*0.01745329251994329576;
	my @d0 = EllipsdData($datum0);
	my($a0, $f0) = @d0[0,1];
	my @d1 = EllipsdData($datum1);
	my($a1, $f1) = @d1[0,1];
	my $dx = $d1[2]-$d0[2];
	my $dy = $d1[3]-$d0[3];
	my $dz = $d1[4]-$d0[4];
	my $b0 = $a0*(1-$f0);
	my $es0 = $f0*(2-$f0);
	my $b1 = $a1*(1-$f1);
	my $es1 = $f1*(2-$f1);
	# convert geodetic latitude to geocentric latitude
	my $psi;
	if ($latd==0 || $latd==90 || $latd==-90) {
	    $psi = $phi;
	} else {
	    $psi = atan((1-$es0)*tan($phi));
	}
	# x and y axis coordinates with respect to original ellipsoid
	my $t1 = tan($psi);
	my($x,$y,$z);
	if ($longd==90 || $longd==-90.0) {
	    $x = 0;
	    $y = abs($a0*$b0/sqrt($b0*$b0+$a0*$a0*$t1*$t1));
	} else {
	    my $t2 = tan($lambda);
	    $x = abs(($a0*$b0)/sqrt((1+$t2*$t2)*($b0*$b0+$a0*$a0*$t1*$t1)));
	    $y = abs($x*$t2);
	}
	if ($longd<-90 || $longd>90) {
	    $x = -$x;
	}
	if ($longd < 0) {
	    $y = -$y;
	}
	# z axis coordinate with respect to the original ellipsoid
	if ($latd == 90) {
	    $z = $b0;
	} elsif ($latd == -90) {
	    $z = -$b0;
	} else {
	    $z = $t1*sqrt(($a0*$a0*$b0*$b0)/($b0*$b0+$a0*$a0*$t1*$t1));
	}
	# geocentric latitude with respect to the new ellipsoid
	my $ddx = $x-$dx;
	my $ddy = $y-$dy;
	my $ddz = $z-$dz;
	my $psi1 = atan($ddz/sqrt($ddx*$ddx+$ddy*$ddy));
	# geocentric latitude and longitude
	$clat = atan(tan($psi1)/(1-$es1))*57.29577951308232087684;
	$clong = atan($ddy/$ddx)*57.29577951308232087684;
	if ($ddx < 0) {
	    if ($ddy > 0) {
		$clong = $clong+180;
	    } else {
		$clong = $clong-180;
	    }
	}
    } else {
	$clat = $latd;
	$clong = $longd;
    }
    CreatePos($clat, $clong, $pformt, PosType($pformt), $datum1);
}

sub PosType {
    my($pformt) = @_;

#    global ZGRID

    if ($pformt =~ /^(DMS|DMM|DDD)$/) {
	return "latlong";
    } elsif ($pformt eq 'UTM/UPS') {
	return "utm";
    } elsif ($pformt eq 'MH') {
	return "mh";
    }
    if ($ZGRID{$pformt}) {
	return "grid";
    }
    return "nzgrid";
}

=item CreatePos

Create position representation under format $pformt, $type,
from lat/long in degrees, and $datum
a position representation is a list whose first two elements
are lat and long in degrees, and whose rest is dependent on format:
  $type==latlong: lat and long in external format
  $type==utm: zones east and north and x y coordinates
  $type==grid: zone name and x y coordinates
  $type==nzgrid: x y coordinates
  $type==mh: Maidenhead-locator (6 characters)

=cut

sub CreatePos {
    my($latd, $longd, $pformt, $type, $datum) = @_;

    if ($type eq 'latlong') {
	my($la, $lo, $hlat, $hlng);
	if ($latd < 0) {
	    $la = -$latd;
	    $hlat = 'S';
	} else {
	    $la = $latd;
	    $hlat = 'N';
	}
	if ($longd < 0) {
	    $lo = -$longd;
	    $hlng = 'W';
	} else {
	    $lo = $longd;
	    $hlng = 'E';
	}
	return ($latd, $longd,
		"$hlat".ExtDegrees($pformt, $la),
		"$hlng".ExtDegrees($pformt, $lo));
    } elsif ($type eq 'utm') {
	my @p = DegreesToUTM($latd, $longd, $datum);
	return ($latd, $longd, @p);
    } elsif ($type eq 'grid')  {
	my $func = "DegreesTo$pformt";
	no strict 'refs';
	my @p = &$func($latd, $longd, $datum);
	return ($latd, $longd, @p);
    } elsif ($type eq 'nzgrid') {
	my @p = DegreesToNZGrid($pformt, $latd, $longd, $datum);
	return ($latd, $longd, @p);
    } elsif ($type eq 'mh') {
	return ($latd, $longd, DegreesToMHLoc($latd, $longd));
    } else {
	die "Unknown type $type for CreatePos";
    }
}

=item ExtDegrees

from signed degrees $degs to external representation of format $pformt
$pformt in {DMS, DMM, DDD, DMSsimpl}
DMSsimpl is similar to DMS, but for values less than 1 degree the
representation is either MM'SS.S" or SS.S"

=cut

#'XXX emacs

sub ExtDegrees {
    my($pformt, $degs) = @_;

    if ($pformt =~ /^DMS.*/) {
	my $sign;
	if ($degs < 0) {
	    $degs = -$degs;
	    $sign = -1;
	} else {
	    $sign = 1;
	}
	my $d = int($degs);
	my $degs = ($degs-$d)*60;
	$d = $sign*$d;
	my $m = int($degs);
	my $s = ($degs-$m)*60;
	if ($s > 59.95) {
	    $s = 0;
	    $m++;
	}
	if ($m > 59) {
	    $m = 0;
	    $d++;
	}
	if ($d > 0 || $pformt eq "DMS") {
	    return sprintf "%d %02d %04.1f", $d, $m, $s;
	}
	if ($m > 0) {
	    return sprintf "%02d'%04.1f", $m, $s;
	}
	return sprintf "%04.1f\"", $s;
    } elsif ($pformt eq 'DMM') {
	my $sign;
	if ($degs < 0) {
	    $degs = -$degs;
	    $sign = -1;
	} else {
	    $sign = 1;
	}
	my $d = int($degs);
	$degs = ($degs-$d)*60;
	$d = $sign*$d;
	if ($degs > 59.995) {
	    $degs = 0;
	    $d++;
	}
	return sprintf("%d %06.3f", $d, $degs);
    } elsif ($pformt eq 'DDD') {
	return sprintf "%.5f", $degs;
    } else {
	die "Unknown format $pformt in ExtDegrees";
    }
}

# XXX changed to Tcl/Tk version: optional extra argument $z
sub DegreesToGKK {
    my($lat, $long, $datum, $z) = @_;
    # convert from lat/long in signed degrees to German Krueger grid coords
    # zone codes: 0-5

    if ($long < -1.5 || $long > 16.5 || $lat < 0) {
	return ("--", 0, 0);
    }
    $z = int(($long+1.5)/3) if !defined $z;
    my $long0 = 3.0*$z;
    my(@cs) = ConvToTM($lat, $long, 0, $long0, 1.0, $datum);
    my $x = sprintf("%.0f", $cs[0]+5e5+1e6*$z);
    my $y = sprintf("%.0f", $cs[1]);
    if ($x < 0 || $y < 0) {
	return ("--", 0, 0);
    }
    ($z, $x, $y);
}

sub GKKToDegrees {
    my($zone, $x, $y, $datum) = @_;
    # convert from German Krueger grid coords to lat/long in signed degrees

    if ($x < 0 || $y < 0 || $x > 6e6 || $y > 1e7 ||
	$zone !~ /$GRIDZN{GKK}/) {
	return 0;
    }
    my $long0 = 3.0*$zone;
    $x = $x-5e5-1e6*$zone;
    ConvFromTM($x, $y, 0, $long0, 1.0, $datum);
}

######################################################################

use vars qw(%GDATUM %ELLPSDDEF);

## datum definitions
# index of GDATUM is datum name
# each list contains:
#  - ellipsoid name
#  - dx, dy, dz
#  - reference id; if a number, it is the number used by GPStrans
#  - comment
#    (the following elements are not being used and may be absent)
#  - expected error estimate in metres: ex, ey, ez (-1 for unknown)
#  - number of satellite measurement stations (0 for unknown)
#  - min, max lat and min, max long in signed degrees (empty or "_" if unknown)

%GDATUM =
    (
     "WGS 84"  => ["WGS 84", 0, 0, 0, 100, "", -1, -1, -1, 0],
     "Potsdam" => ["Bessel 1841", 587, 16, 393, 102, "GPStrans has: 606 23 413"],
    );

## ellipsoid definitions
# indexed by name
# each list has:
#  - a (semi-major axis in metre), invf (inverse of flattening)
#  - comment

## those after "WGS 66" until "Walbeck" were taken from PROJ4.0

%ELLPSDDEF =
    (
     "WGS 84"      => [6378137.0, 298.257223563, ""],
     "Bessel 1841" => [6377397.155, 299.1528128, "used in Germany, Japan"],
    );


=item EllipsdData

Based on contribution by Stefan Heinen.
Yield the ellipsoid data for datum as a list with
    a - semi-major axis
    f - flattening
    dx, dy, dz - translation of center

=cut

sub EllipsdData {
    my $datum = shift || "WGS 84";

    my @d = @{ $GDATUM{$datum} || die "Unknown datum $datum" }[0..3];
    my $def = $ELLPSDDEF{$d[0]};
    ($def->[0], 1.0/$def->[1], @d[1..$#d]);
}

return 1 if caller;

package main;

my($lat, $long) = @ARGV;
foreach my $ref (\$lat, \$long) {
    if ($$ref =~ /\s+/) {
	warn "DMS coord detected, converting to DDD\n";
	require FindBin;
	push @INC, "$FindBin::RealBin/..";
	require Karte::Polar;
	$$ref = Karte::Polar::dms_string2ddd($$ref);
    }
}

warn join " ", Karte::UTM::DegreesToUTM($lat, $long), "\n";

__END__
