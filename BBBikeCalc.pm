# -*- perl -*-

#
# $Id: BBBikeCalc.pm,v 1.13 2006/07/30 20:37:52 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999,2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

#XXX del: package main; # warum notwendig? irgendwann konnte bbbike.cgi nicht mehr ohne..
#XXX irgendwann: 
package BBBikeCalc;

use BBBikeUtil;
use strict;
use vars qw(@INC @EXPORT_OK
	    %opposite %canvas_translation
	    %wind_dir $winddir $wind_dir_from $wind_dir_to $wind);

#XXX irgendwann:
# require Exporter;
# @ISA = qw(Exporter);
# @EXPORT_OK = qw(CAKE %opposite opposite_direction init_wind
# 		%wind_dir analyze_wind_dir norm_arc);

# globale Variablen und Konstanten, die auch in main verwendet werden:
#
# CAKE: ein halbes Kuchenstück
# %wind_dir: definiert die Windrichtungen in y- und x-Richtung
# $winddir: aktuelle Windrichtung
# $wind_dir_from, $wind_dir_to: Winkelangaben für die aktuelle Windrichtung
# $wind: Windberechnung in head_wind() wird nur durchgeführt, wenn diese
#        Variable wahr ist XXX del
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
     'se' => 'nw',
     'nne' => 'ssw',
     'ene' => 'esw',
     'ese' => 'enw',
     'sse' => 'nnw',
     'ssw' => 'nne',
     'wsw' => 'wne',
     'wnw' => 'wse',
     'nnw' => 'sse',
    );
sub opposite_direction { $opposite{$_[0]} }

# to translate between y-up and y-down coordinate systems
# XXX what's the difference between %opposite and %canvas_translation --- seems to be the same!
%canvas_translation =
    ('n' => 's',
     'e' => 'e',
     'w' => 'w',
     's' => 'n',
     'ne' => 'se',
     'sw' => 'nw',
     'nw' => 'sw',
     'se' => 'ne',
     'nne' => 'sse',
     'ene' => 'ese',
     'ese' => 'ene',
     'sse' => 'nne',
     'ssw' => 'nnw',
     'wsw' => 'wnw',
     'wnw' => 'wsw',
     'nnw' => 'ssw',
    );
sub canvas_translation { $canvas_translation{$_[0]} }

sub init_wind {
    #        Windrichtung   y     x
    %wind_dir = ('n'   => [ 1,    0],
		 'nne' => [ 1,    0.5],
		 'ne'  => [ 1,    1],
		 'ene' => [ 0.5,  1],
		 'e'   => [ 0,    1],
		 'ese' => [-0.5,  1],
		 'se'  => [-1,    1],
		 'sse' => [-1,    0.5],
		 's'   => [-1,    0],
		 'ssw' => [-1,   -0.5],
		 'sw'  => [-1,   -1],
		 'wsw' => [-0.5, -1],
		 'w'   => [ 0,   -1],
		 'wnw' => [ 0.5  -1],
		 'nw'  => [ 1,   -1],
		 'nnw' => [ 1,   -0.5],
		 ''    => [ 0,    0],
		);
}

# Returns a list (normalized wind direction string, wind dir cake from, wind dir cake to)
# Sets also the global variables $winddir, $wind_dir_from, $wind_dir_to
sub analyze_wind_dir {
    my($dir) = @_;
    $winddir = lc($dir);
    my @wd = @{$wind_dir{$winddir}};
    my($winkel) = norm_arc(atan2($wd[0], $wd[1]));
    ($wind_dir_from, $wind_dir_to) = ($winkel - CAKE, $winkel + CAKE);
    # XXX was soll das hier? :
    $wind_dir_from = norm_arc($wind_dir_from);
    $wind_dir_to = norm_arc($wind_dir_to);
    ($winddir, $wind_dir_from, $wind_dir_to);
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
    return 0 if !defined $deltax || !defined $deltay; #XXX || !$wind; del XXX
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

sub line_to_canvas_direction {
    my($x1,$y1, $x2,$y2) = @_;
    my $arc = norm_arc(atan2($y2-$y1, $x2-$x1));
    if ($arc >= - CAKE && $arc <= CAKE) {
	'e';
    } elsif ($arc <= CAKE*3) {
	'ne';
    } elsif ($arc <= CAKE*5) {
	'n';
    } elsif ($arc <= CAKE*7) {
	'nw';
    } elsif ($arc <= CAKE*9) {
	'w';
    } elsif ($arc <= CAKE*11) {
	'sw';
    } elsif ($arc <= CAKE*13) {
	's';
    } elsif ($arc <= CAKE*15) {
	'se';
    } elsif ($arc <= CAKE*17) {
	'e';
    } elsif ($arc <= CAKE*19) {
	'ne';
    } elsif ($arc <= CAKE*21) {
	'n';
    } else {
	warn "Winkel $arc is unknown";
	undef;
    }
}

sub localize_direction {
    my($dir, $lang) = @_;
    if ($lang eq 'de') {
	$dir = { 'N'   => 'Norden',
		 'NNE' => 'Nordnordosten',
		 'NE'  => 'Nordosten',
		 'ENE' => 'Ostnordosten',
		 'E'   => 'Osten',
		 'ESE' => 'Ostsüdosten',
		 'SE'  => 'Südosten',
		 'SSE' => 'Südsüdosten',
		 'S'   => 'Süden',
		 'SSW' => 'Südsüdwesten',
		 'SW'  => 'Südwesten',
		 'WSW' => 'Westsüdwesten',
		 'W'   => 'Westen',
		 'WNW' => 'Westnordwesten',
		 'NW'  => 'Nordwesten',
		 'NNW' => 'Nordnordwesten',
	       }->{uc($dir)};
    }
    $dir;
}

1;

__END__
