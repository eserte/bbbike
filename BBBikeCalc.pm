# -*- perl -*-

#
# $Id: BBBikeCalc.pm,v 1.9 2003/01/08 18:45:40 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package main; # warum notwendig? irgendwann konnte bbbike.cgi nicht mehr ohne..
#XXX irgendwann: package BBBikeCalc;

use BBBikeUtil;
use strict;
use vars qw(@INC @EXPORT_OK
	    %opposite %wind_dir $winddir $wind_dir_from $wind_dir_to $wind);

#XXX irgendwann:
#  require Exporter;
#  @ISA = qw(Exporter);
#  @EXPORT_OK = qw(CAKE %opposite opposite_direction init_wind
#  		%wind_dir analyze_wind_dir norm_arc

# globale Variablen und Konstanten, die auch in main verwendet werden:
#
# CAKE: ein halbes Kuchenstück
# %wind_dir: definiert die Windrichtungen in y- und x-Richtung
# $winddir: aktuelle Windrichtung
# $wind_dir_from, $wind_dir_to: Winkelangaben für die aktuelle Windrichtung
# $wind: Windberechnung in head_wind() wird nur durchgeführt, wenn diese
#        Variable wahr ist
#

#perl2exe_include constant.pm

use constant CAKE => atan2(1,1)/2;

%opposite =
    ('n' => 's',
     'e' => 'w',
     'w' => 'e',
     's' => 'n',
     'ne' => 'sw',
     'sw' => 'ne',
     'nw' => 'se',
     'se' => 'nw');
sub opposite_direction { $opposite{$_[0]} }

sub init_wind {
    #        Windrichtung  y   x
    %wind_dir = ('n'  => [ 1,  0],
		 'ne' => [ 1,  1],
		 'e'  => [ 0,  1],
		 'se' => [-1,  1],
		 's'  => [-1,  0],
		 'sw' => [-1, -1],
		 'w'  => [ 0, -1],
		 'nw' => [ 1, -1],
		 ''   => [ 0,  0],
		);
}

sub analyze_wind_dir {
    my($dir) = @_;
    $winddir = lc($dir);
    my @wd = @{$wind_dir{$winddir}};
    my($winkel) = norm_arc(atan2($wd[0], $wd[1]));
    ($wind_dir_from, $wind_dir_to) = ($winkel - CAKE, $winkel + CAKE);
    # XXX was soll das hier? :
    norm_arc($wind_dir_from);
    norm_arc($wind_dir_to);
}

sub norm_arc {
    my($arc) = @_;
    if ($arc < 0) {
	$arc + 2*pi;
    } elsif ($arc >= 2*pi) {
	$arc - 2*pi;
    } else {
	$arc;
    }
}

sub arc_is_between {
    my($arc, $arc_from, $arc_to) = @_;
    if ($arc_from > $arc_to) {
	return 1 if $arc < $arc_from && $arc < $arc_to;
	return 1 if $arc > $arc_from;
	return 0;
    } else {
	return 1 if $arc > $arc_from && $arc < $arc_to;
	return 0;
    }
}

sub head_wind { # returns +2 for back wind and -2 for head wind
    my($deltax, $deltay) = @_;
    return 0 if !defined $deltax || !defined $deltay || !$wind;
    my $arc = norm_arc(atan2($deltay, $deltax));
    my $i;
    for($i=0; $i<4; $i++) {
	if (arc_is_between($arc,
			   norm_arc($wind_dir_from - $i*2*CAKE),
			   norm_arc($wind_dir_to   + $i*2*CAKE))) {
	    return $i - 2;
	}
    }
    +2;
}

# XXX ist es richtigrum?
sub line_to_canvas_direction {
    my($x1,$y1, $x2,$y2) = @_;
    my $arc = norm_arc(atan2($y2-$y1, $x2-$x1));
    if ($arc >= - CAKE && $arc <= CAKE) {
	'w';
    } elsif ($arc <= CAKE*3) {
	'nw';
    } elsif ($arc <= CAKE*5) {
	'n';
    } elsif ($arc <= CAKE*7) {
	'ne';
    } elsif ($arc <= CAKE*9) {
	'e';
    } elsif ($arc <= CAKE*11) {
	'se';
    } elsif ($arc <= CAKE*13) {
	's';
    } elsif ($arc <= CAKE*15) {
	'sw';
    } elsif ($arc <= CAKE*17) {
	'w';
    } elsif ($arc <= CAKE*19) {
	'nw';
    } elsif ($arc <= CAKE*21) {
	'n';
    } else {
	warn "Winkel $arc is unknown";
	undef;
    }
}

1;

__END__
