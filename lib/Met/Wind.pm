# -*- perl -*-

#
# $Id: Wind.pm,v 1.7 2003/12/20 22:46:48 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998, 1999, 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://bbbike.sourceforge.net
#

package Met::Wind;

use strict;
use vars qw(@wind_table @ISA @EXPORT $VERSION);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(wind_velocity wind_dir wind_chill);

$VERSION = '0.04';

use constant INX_BEAUFORT => 0;
use constant INX_LOC_DE   => 1;
use constant INX_MS       => 2;
use constant INX_KMH      => 3;
use constant INX_LOC_EN   => 4;

@wind_table = 
# Beaufort   German            m/s   km/h  English
  ([ 0, 'Stille',              0.2,   0.7, "calm"],
   [ 1, 'leiser Zug',          1.5,   5.4, "light air"],
   [ 2, 'leichte Brise',       3.3,  11.9, "light breeze"],
   [ 3, 'schwache Brise',      5.4,  19.4, "gentle breeze"],
   [ 4, 'mäßige Brise',        7.9,  28.4, "moderate breeze"],
   [ 5, 'frische Brise',      10.7,  38.5, "fresh breeze"],
   [ 6, 'starker Wind',       13.8,  49.7, "strong breeze"],
   [ 7, 'steifer Wind',       17.1,  61.6, "moderate gale"],
   [ 8, 'stürmischer Wind',   20.7,  74.5, "gale"],
   [ 9, 'Sturm',              24.4,  87.8, "strong gale"],
   [10, 'schwerer Sturm',     28.4, 102.2, "storm"],
   [11, 'orkanartiger Sturm', 32.6, 117.4, "violent storm"],
   [12, 'Orkan',              36.9, 132.8, "hurricane-force"],
   [13, 'Orkan',              41.4, 149.0, "hurricane-force"],
   [14, 'Orkan',              46.1, 166.0, "hurricane-force"],
   [15, 'Orkan',              50.9, 183.2, "hurricane-force"],
   [16, 'Orkan',              56.0, 201.6, "hurricane-force"],
  );

sub wind_velocity {
    my($in, $out_unit) = @_;
    my($in_num, $in_unit) = _num_unit($in, 'm/s');
    $out_unit = _normalize_unit($out_unit);

    if ($out_unit eq 'beaufort' || $out_unit =~ m{^text_(?:de|en)$}) {
	my $out_col = _unit_to_col($out_unit);
	my $in_col;
	if ($in_unit eq 'beaufort') {
	    $in_col = INX_BEAUFORT;
	} elsif ($in_unit eq 'text_de') {
	    $in_col = INX_LOC_DE;
	} elsif ($in_unit eq 'text_en') {
	    $in_col = INX_LOC_EN;
	} elsif ($in_unit eq 'm/s') {
	    $in_col = INX_MS;
	} else {
	    $in_col = INX_KMH;
	    if ($in_unit eq 'mi/h') {
		$in_num = _mih_kmh($in_num);
	    } elsif ($in_unit eq 'sm/h') {
		$in_num = _smh_kmh($in_num);
	    } elsif ($in_unit ne 'km/h') {
		die "Unknown unit <$in_unit>";
	    }
	}
	my $last = 0;
	foreach (@wind_table) {
#warn "@$_";
	    if ($in_col == INX_BEAUFORT) {
		if ($_->[$in_col] eq $in_num) {
		    return $_->[$out_col];
		}
	    } elsif ($in_unit =~ m{^text}) {
		if ($_->[$in_col] eq $in_num) {
		    return $_->[$out_col];
		}
	    } else {
		if ($_->[$in_col] >= $in_num &&
		    $last <= $in_num) {
		    return $_->[$out_col];
		}
		$last = $_->[$in_col];
	    }
	}
	return undef; # XXXX
    } elsif ($in_unit eq 'beaufort' || $in_unit =~ m{^text_(?:de|en)$}) {
	my $in_col = _unit_to_col($in_unit);
	my $out_col;
	if ($out_unit eq 'm/s') {
	    $out_col = INX_MS;
	} else {
	    $out_col = INX_KMH;
	}
	my $out_num;
	my $last = 0;
	foreach (@wind_table) {
	    if ($_->[$in_col] eq $in_num) {
		$out_num = ($_->[$out_col]-$last)/2+$last; # Mitte des Bereichs
		last;
	    }
	    $last = $_->[$out_col]; 
	}
	if (!defined $out_num) {
	    return undef; # XXXX
	}

	if ($out_unit eq 'm/s' || $out_unit eq 'km/h') {
	    return $out_num;
	} elsif ($out_unit eq 'mi/h') {
	    return _kmh_mih($out_num);
	} elsif ($out_unit eq 'sm/h') {
	    return _kmh_smh($out_num);
	} else {
	    die "Unknown unit <$out_unit>";
	}
    } else {
	my $kmh;
	if ($in_unit eq 'm/s') {
	    $kmh = _ms_kmh($in_num);
	} elsif ($in_unit eq 'mi/h') {
	    $kmh = _mih_kmh($in_num);
	} elsif ($in_unit eq 'sm/h') {
	    $kmh = _smh_kmh($in_num);
	} elsif ($in_unit eq 'km/h') {
	    $kmh = $in_num;
	} else {
	    die "Unknown unit <$in_unit>";
	}
	if ($out_unit eq 'm/s') {
	    return _kmh_ms($kmh);
	} elsif ($out_unit eq 'mi/h') {
	    return _kmh_mih($kmh);
	} elsif ($out_unit eq 'sm/h') {
	    return _kmh_smh($kmh);
	} elsif ($out_unit eq 'km/h') {
	    return $kmh;
	} else {
	    die "Unknown unit <$out_unit>";
	}
    }
}

sub _num_unit {
    my($s, $default) = @_;

    my($num, $unit);
    if (ref $s eq 'ARRAY') {
	$num  = $s->[0];
	$unit = $s->[1];
    } else {
	if ($s !~ /^\s*([+-]?[\d.]+)\s*(.*)\s*$/) {
	    if (!$default) {
		die "Can't parse $s";
	    }
	    $num = $s;
	    $unit = $default;
	} else {
	    $num = $1;
	    $unit = $2;
	}
    }
    $unit = _normalize_unit($unit);

    ($num, $unit);
}

sub _normalize_unit {
    my $unit = shift;
    if    ($unit eq 'kn')          { 'sm/h' }
    elsif ($unit =~ /^beaufort$/i) { 'beaufort' }
    elsif ($unit =~ /^text_en/i)   { 'text_en' }
    elsif ($unit =~ /^text/i)      { 'text_de' }
    else                           { $unit }
}

sub _unit_to_col {
    my $unit = shift;
    if    ($unit eq 'beaufort') { INX_BEAUFORT }
    elsif ($unit eq 'text_de')  { INX_LOC_DE   }
    elsif ($unit eq 'text_en')  { INX_LOC_EN   }
    else                        { undef        }
}

sub _mih_kmh { $_[0] * 1.609344 }
sub _kmh_mih { $_[0] / 1.609344 }
sub _smh_kmh { $_[0] * 1.852 }
sub _kmh_smh { $_[0] / 1.852 }
sub _ms_kmh  { $_[0] * 3.6 }
sub _kmh_ms  { $_[0] / 3.6 }
sub _F_C     { (5/9)*($_[0]-32) }

sub wind_dir {
    die "NYI";
}

sub wind_chill {
    my($wind, $temp_s, $formula) = @_;
    my($temp, $temp_unit) = _num_unit($temp_s, '°C');
    if ($temp_unit eq '°F') {
	$temp = _F_C($temp);
    }
    my $kmh = wind_velocity($wind, 'km/h');
    if ($kmh < 8.5 || $kmh > 81.5) {
	return undef;
    }
    if ($formula eq 'tsp') {
	33 + (0.478 + 0.237 * sqrt($kmh) - 0.0124*$kmh) * ($temp - 33);
    } else {
	0.045*(5.27*sqrt($kmh) + 10.45 - 0.28 * $kmh) * ($temp - 33) + 33
    }
}

# Argument -command:
# Werte werden in Buttons statt in Labels gesetzt. Beim Klick wird
# die in -command angegebene Subroutine mit den Parametern $num, $unit und
# $toplevel aufgerufen.
sub beaufort_table {
    my($top, %args) = @_;
    $args{-title} = 'Beaufort-Tabelle' unless exists $args{-title};
    my $command = delete $args{-command};
    my $tl = $top->Toplevel(%args);
    my $t = $tl->Frame(Name => 'table')->pack(-expand => 1, -fill => 'both');
    (my $optname = $t->PathName) =~ s/^.//;
    $t->optionAdd("*$optname*relief" => 
		  ($Tk::VERSION >= 800 ? 'solid' : 'sunken'), 'interactive');
    $t->optionAdd("*$optname*borderwidth" => 1, 'interactive');
    my $row = 0;
    my $col = 0;
    $t->Label(-text => 'Beaufort')->grid(-row => $row, -column => $col++,
					 -sticky => 'we');
    $t->Label(-text => 'Beschreibung')->grid(-row => $row, -column => $col++,
					     -sticky => 'we');
    $t->Label(-text => 'm/s')->grid(-row => $row, -column => $col++,
				    -sticky => 'we');
    $t->Label(-text => 'km/h')->grid(-row => $row, -column => $col++,
				     -sticky => 'we');

    $row++;
    $t->Frame(-background => 'black',
	      -height => 2,
	     )->grid(-row => $row, -column => 0,
		     -columnspan => 4,
		     -sticky => 'ew');
    my(%add_args, $lab_but);
    if (defined $command) {
	$lab_but = "Button";
	%add_args = (-highlightthickness => 0,
		     -padx => 0, -pady => 0);
    } else {
	$lab_but = "Label";
    }
    foreach (@wind_table) {
	$row++;
	$col = 0;
	my($bf,$bez,$ms,$kmh) = @$_;
	$t->$lab_but(-text => $bf,
		     -justify => 'right',
		     %add_args,
		     (defined $command 
		      ? (-command => sub { $command->($bf, 'beaufort', $tl) })
		      : ()),
		    )->grid(-row => $row, -column => $col++,
			    -sticky => 'we');
	$t->$lab_but(-text => $bez,
		     %add_args,
		     (defined $command 
		      ? (-command => sub { $command->($bez, 'text_de', $tl) })
		      : ()),
		    )->grid(-row => $row, -column => $col++,
			    -sticky => 'we');
	$t->$lab_but(-text => $ms,
		     -justify => 'right',
		     %add_args,
		     (defined $command 
		      ? (-command => sub { $command->($ms, 'm/s', $tl) })
		      : ()),
		    )->grid(-row => $row, -column => $col++,
			    -sticky => 'we');
	$t->$lab_but(-text => $kmh,
		     -justify => 'right',
		     %add_args,
		     (defined $command 
		      ? (-command => sub { $command->($kmh, 'km/h', $tl) })
		      : ()),
		    )->grid(-row => $row, -column => $col++,
			    -sticky => 'we');
    }

    $row++;
    $tl->Button(-text => 'Schließen',
		-foreground => 'red',
		-command => sub { $tl->destroy },
	       )->pack;

    foreach (qw(q Control-c Escape)) {
	$tl->bind("<$_>" => sub { $tl->destroy });
    }

    my(@popup_style) = ('-popover', 'cursor');
    if (exists $args{-popover}) {
	if (defined $args{-popover}) {
	    @popup_style = ('-popover', $args{-popover});
	} else {
	    @popup_style = ();
	}
    }

    $tl->withdraw;
    $tl->Popup(@popup_style);
    $tl;
}

1;
