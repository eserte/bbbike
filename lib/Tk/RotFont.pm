# -*- perl -*-

#
# $Id: RotFont.pm,v 1.12 2002/07/13 21:04:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::RotFont;

use strict;
use constant PI => 3.141592653;

BEGIN {
    if (!$Tk::RotFont::NO_X11) {
	eval q{
	    use Tk::X11Font;
	    use Tk::Font;
	}; die $@ if $@;
    }
}


#*canvas = \&canvas_old;
*canvas = \&rot_text_old;
#*canvas = \&rot_text_smart_compat;
#*rot_text = \&rot_text_old;

# XXX durch Variable verfügbar machen
if (!$Tk::RotFont::NO_X11) { # XXX rot_text_newer ist wesentlich *langsamer* als rot_text_old
    # X11::Protocol scheint Speicherfresser zu sein
    use vars qw($use_rotx11font); # XXX
    if (!defined $main::x11) {
	eval '
	    require X11::Protocol;
	    $main::x11 = X11::Protocol->new;
	    use lib "XXX$ENV{HOME}/devel";
	    require Tk::RotX11Font;
	    if ($main::use_font_rot) {
		$use_rotx11font = 1;
#		*rot_text = \&rot_text_newer;
		*canvas = \&rot_text_smart_compat;
	    }
	';
	warn $@ if $@;
    }
}

use vars qw(%rot_font_cache);

# Zeichnet den Straßennamen mit rotierten Zeichensätzen.
# Argumente:
# $c:        Canvas
# $abk:      Abkürzung, wird als Tag verwendet
# $coordref: Referenz auf Koordinaten der Straße
# $f_sub:    Funktion, die den Fontnamen ermittelt
# $size:     Fontgröße
# $str:      auszugebendes Label
# %args:     more arguments for createText
### AutoLoad Sub
sub rot_text_old {
    my($c, $abk, $coordref, $f_sub, $size, $str, %args) = @_;
    return if length($str) == 0;
    my $ges_strecke_len = 0;
    my $last_coordref = $#{$coordref};
    for(my $i = 0; $i<=$last_coordref-3; $i+=2) {
	$ges_strecke_len +=
	  Strassen::Util::strecke([$coordref->[$i],   $coordref->[$i+1]],
				  [$coordref->[$i+2], $coordref->[$i+3]]);
    }
    return if $ges_strecke_len == 0;
    my $len_per_char = (length($str) == 1 
			? 0 : $ges_strecke_len/(length($str)+1));
    return if $len_per_char < 4; # ansonsten unlesbar
    my $reversed = 0;
    if ($coordref->[0] > $coordref->[$last_coordref-1]) {
	$str = reverse $str;
	$reversed = 1;
    }
    my $last_strecke_len;
    my $strecke_len = 0;
    my $curr_pos = $len_per_char;
    my $curr_i = 0;
    my @create_text_args = (-anchor => 'w', -tags => "$abk-label", %args);
    for(my $i = 0; $i<=$last_coordref-3; $i+=2) {
	$last_strecke_len = $strecke_len;
	$strecke_len +=
	  Strassen::Util::strecke([$coordref->[$i],   $coordref->[$i+1]],
				  [$coordref->[$i+2], $coordref->[$i+3]]);
	while ($strecke_len > $curr_pos) {
	    my($ch_x, $ch_y);
	    my $m = ($curr_pos-$last_strecke_len)/
	      ($strecke_len-$last_strecke_len);
	    $ch_x = $m*($coordref->[$i+2]-$coordref->[$i])
	      + $coordref->[$i];
	    $ch_y = $m*($coordref->[$i+3]-$coordref->[$i+1])
	      + $coordref->[$i+1];
	    my $rotsize;
	    if ($main::use_font_rot) {
		my $r = -atan2($coordref->[$i+3]-$coordref->[$i+1],
			       $coordref->[$i+2]-$coordref->[$i],
			      );
		if ($reversed) {
		    $r += PI;
		}
		$rotsize = get_rot_matrix($r, $size);
	    } else {
		$rotsize = $size*10;
	    }
	    eval {
		my $substr = substr($str, $curr_i, 1); # workaround Tk804 problem
		$c->createText
		    ($ch_x, $ch_y,
		     -text => $substr,
		     -font => $f_sub->($rotsize),
		     @create_text_args,
		    );
	    };
	    if ($@) { warn "Problem at $rotsize: $@\n" }
	    $curr_i++;
	    $curr_pos += $len_per_char;
	}
    }
}

# Zeichnet den Straßennamen mit rotierten Zeichensätzen.
# Verwendet Tk::RotX11Font.
# XXX Test2
### AutoLoad Sub
sub rot_text_newer {
    my($c, $abk, $coordref, $f_sub, $size, $str) = @_;
    return if length($str) == 0;
    my $ges_strecke_len = 0;
    my $last_coordref = $#{$coordref};
    for(my $i = 0; $i<=$last_coordref-3; $i+=2) {
	$ges_strecke_len +=
	  Strassen::Util::strecke([$coordref->[$i],   $coordref->[$i+1]],
				  [$coordref->[$i+2], $coordref->[$i+3]]);
    }
    return if $ges_strecke_len == 0;
    my $len_per_char = (length($str) == 1 
			? 0 : $ges_strecke_len/(length($str)+1));
    return if $len_per_char < 4; # ansonsten unlesbar

    if ($coordref->[0] > $coordref->[$#$coordref-1]) {
	my(@newcoordref);
	for(my $i=0; $i<$#$coordref; $i+=2) {
	    unshift @newcoordref, $coordref->[$i], $coordref->[$i+1];
	}
	$coordref = \@newcoordref;
    }

    my $last_strecke_len;
    my $strecke_len = 0;
    my $curr_pos = $len_per_char;
    my $str_i = 0;
    eval {
      STRLOOP:
	for(my $i = 0; $i<=$last_coordref-3; $i+=2) {
	    $last_strecke_len = $strecke_len;
	    $strecke_len +=
	      Strassen::Util::strecke([$coordref->[$i],   $coordref->[$i+1]],
				      [$coordref->[$i+2], $coordref->[$i+3]]);
	    my $r = -atan2($coordref->[$i+3]-$coordref->[$i+1],
			   $coordref->[$i+2]-$coordref->[$i],
			  );
	    my $rotfont1 = new Tk::RotX11Font
	      substr($str, $str_i), $f_sub, $size, $r;
	    while ($strecke_len > $curr_pos) {
		last STRLOOP if ($str_i > length($str));
		my($ch_x, $ch_y);
		my $m = ($curr_pos-$last_strecke_len)/
		  ($strecke_len-$last_strecke_len);
		$ch_x = $m*($coordref->[$i+2]-$coordref->[$i])
		  + $coordref->[$i];
		$ch_y = $m*($coordref->[$i+3]-$coordref->[$i+1])
		  + $coordref->[$i+1];
		my $ch = substr($str, $str_i, 1);
		my($xext1, $yext1) = $rotfont1->x_y_extent($ch);
		$rotfont1->writeCanvas($c, $ch_x, $ch_y, "$abk-label", $ch);
		$str_i++;
		$curr_pos += CORE::sqrt(sqr($xext1) + sqr($yext1));
	    }
	}
    };
    warn $@ if $@;
}

# Kompatibilitätsaufruf
sub rot_text_smart_compat {
    my($c, $abk, $coordref, $f_sub, $size, $str) = @_;
    rot_text_smart($str, $coordref,
		   -anglesteps => 1,
		   -fontsub => $f_sub,
		   -size => $size,
		   -canvas => $c,
		   -abbrev => $abk);
}

# Zeichnet den Straßennamen mit rotierten Zeichensätzen.
# Der Straßenname wird dabei in zwei Teile geteilt und am
# Anfang und Ende der Straße gezeichnet.
# Verwendet entweder Tk::RotX11Font oder benutzerdefinierte Funktionen
### AutoLoad Sub
sub rot_text_smart {
    my($str, $coordref, %args) = @_;
    return if length($str) == 0;
    # Aufteilen in "Duden-" und "str." (wenn möglich)
    # XXX mehrteilige Straßennamen müssen nicht geteilt werden
    # (Hallesches|Ufer, Kaiser-|Wilhelm-|Platz)
    my($strbase, $strtype);
    if ($str =~ /^(.*)(\s+|-)(\S+)$/) {
	($strbase, $strtype) = ($1, $3);
	if ($2 eq '-') { $strbase .= $2 }
    } elsif ($str !~ /^(.*)(str\.    |
			    straße   |
			    damm     |
			    weg      |
			    allee    |
			    chaussee |
			    ring     |
			    platz    |
			    brücke   |
			    ufer)$/ix) {
	return;
    } else {
	($strbase, $strtype) = ($1, $2);
	# Bindestrich bei Bedarf hinzufügen
	if ($strbase =~ /^(.*)(\s+)$/) {
	    $strbase = $1;
	} elsif ($strbase !~ /-$/) {
	    $strbase .= "-";
	}
    }
    $strbase = " $strbase";
    $strtype .= " ";

    if ($coordref->[0] > $coordref->[$#$coordref-1]) {
	my(@newcoordref);
	for(my $i=0; $i<$#$coordref; $i+=2) {
	    unshift @newcoordref, $coordref->[$i], $coordref->[$i+1];
	}
	$coordref = \@newcoordref;
    }

    my @r;
    $r[0] = -atan2($coordref->[0+3]-$coordref->[0+1],
		   $coordref->[0+2]-$coordref->[0],
		  );
    my $coordlen3 = $#$coordref-3;
    $r[1] = -atan2($coordref->[$coordlen3+3]-$coordref->[$coordlen3+1],
		   $coordref->[$coordlen3+2]-$coordref->[$coordlen3],
		  );
    if ($args{-anglesteps}) {
	# 5°-Schritte erzwingen
	foreach (@r) {
	    $_ = int(($_/PI)*36)/36*PI;
	}
    }
    if (ref $args{-drawsub} eq 'CODE') {
return draw_text_exact($str, $coordref, %args);
	# use user defined routine
	# XXX chaos. Die Argumente sind: x, y (nicht transponiert)
	# Straßenname (String), Winkel (rad) (muss - genommen werden?!),
	# optional: delta-w und delta-h (pixel)
	my($w_all) = $args{-extentsub}->($coordref->[0], $coordref->[1],
					 $strbase.$strtype, 0);
	my($w2,$h2) = $args{-extentsub}->($coordref->[-2], $coordref->[-1],
					  $strtype, $r[1]);

	my $ges_strecke_len = len_of_coordrefs($coordref, \%args);
warn "$strbase wall=$w_all ges=$ges_strecke_len\n";
	return if ($ges_strecke_len == 0 || $ges_strecke_len < $w_all);

warn "r0=" . ($r[0]*180/PI) . " r1=" . ($r[1]*180/PI) . "\n";
	$args{-drawsub}->($coordref->[0], $coordref->[1],
			  $strbase, $r[0]);
	$args{-drawsub}->($coordref->[-2], $coordref->[-1],
			  $strtype, $r[1], $w2, $h2);
    } else {
	# use Tk Canvas
	eval {
	    my $f_sub = $args{-fontsub};
	    my $size  = $args{-size};
	    my $c     = $args{-canvas};
	    my $abk   = $args{-abbrev};

	    my $rotfont1 = new Tk::RotX11Font $strbase, $f_sub, $size, $r[0];
	    my $rotfont2 = new Tk::RotX11Font $strtype, $f_sub, $size, $r[1];
	    my($xext1, $yext1) = $rotfont1->x_y_extent;
	    my($xext2, $yext2) = $rotfont2->x_y_extent;
	    if (abs($xext1+$xext2) > abs($coordref->[0]-$coordref->[$#$coordref-1])
		&&
		abs($yext1+$yext2) > abs($coordref->[1]-$coordref->[$#$coordref])
	       ) {
		warn "$strbase $strtype too large...";
		return;
	    }
	    $rotfont1->writeCanvas
		($c, $coordref->[0], $coordref->[1], "$abk-label");
	    $rotfont2->writeCanvas
		($c,
		 $coordref->[$#$coordref-1]-$xext2, $coordref->[$#$coordref]-$yext2,
		 "$abk-label");
	};
    }
    warn $@ if $@;
}

sub draw_text_exact {
    my($str, $coordref, %args) = @_;
    my($w_all) = $args{-extentsub}->($coordref->[0], $coordref->[1],
				     $str, 0);
    my $ges_strecke_len = len_of_coordrefs($coordref, \%args);
    my $margin = 5;
warn "$str wall=$w_all ges=$ges_strecke_len\n";
    return if ($ges_strecke_len == 0 || $ges_strecke_len < $w_all+2*$margin);

warn "coords=@$coordref\n";

    my($last_x, $last_y, $section) =
	advance($coordref, \%args, $coordref->[0], $coordref->[1],
		0, $margin);
warn "advance $margin from $coordref->[0]/$coordref->[1] => $last_x/$last_y\n";
    my $last_section = $section;

    my $next_len = 0;
    my $next_i = 2;
    my($next_x, $next_y);
    while($next_i <= $#$coordref) {
	($next_x, $next_y) = ($coordref->[$next_i], $coordref->[$next_i+1]);
	$next_len += Strassen::Util::strecke([$next_x,$next_y],[$last_x,$last_y]);
	last if ($margin < $next_len);
	$next_i+=2;
    };
    my $last_r0 = -atan2($coordref->[$next_i+1]-$last_y,
			 $coordref->[$next_i]-$last_x);
{
my($tx1,$ty1) = $args{-transpose}->($last_x,$last_y);
my($tx2,$ty2) = $args{-transpose}->($coordref->[$next_i],$coordref->[$next_i+1]);
my $tr = -atan2($ty2-$ty1, $tx2-$tx1);
warn "t1=$tx1/$ty1 t2=$tx2/$ty2 tr=$tr\n";
}

    my $len_so_far = 0;
    my $r; # next
    my $this_r;

    my $draw = sub {
	my $j = shift;
	my($draw_len) = $args{-extentsub}->($last_x, $last_y,
					    substr($str, 0, $j), 0);
warn "draw x/y=$last_x/$last_y, str=($str,0,$j), r0=$last_r0 thisr=$this_r\n";
	$args{-drawsub}->($last_x, $last_y,
			  substr($str, 0, $j),
			  (defined $r ? in_between($last_r0, $r) : $last_r0)
			 );
	#$last_r0);
	#$this_r);
	$str = substr($str, $j);
	($last_x, $last_y, $section) =
	    advance($coordref, \%args, $last_x, $last_y,
		    $section, $draw_len);
	$last_r0 = $r;
	$len_so_far = $draw_len;
warn "after ($draw_len): (x/y=$last_x/$last_y, $section) r=$last_r0 len=$len_so_far\n";
    };

 LOOP:
    while(1) {
	last if ($section*2+3) > $#$coordref;

	$r = -atan2($coordref->[$section*2+3]-$last_y,
		    $coordref->[$section*2+2]-$last_x);
	$this_r = -atan2($coordref->[$section*2+1]-$last_y,
			 $coordref->[$section*2+0]-$last_x);

	$len_so_far += Strassen::Util::strecke
	    ([$args{-transpose}->($coordref->[$section*2],
				  $coordref->[$section*2+1])],
	     [$args{-transpose}->($coordref->[$section*2+2],
				  $coordref->[$section*2+3])]);

	# zu große Abweichung von der Geraden:
	if (abs($r-$last_r0) > 0.175) {

	    for(my $j = 0; $j < length $str; $j++) {
		if (substr($str, $j, 1) =~ /\s/) {
		    $draw->($j);
		    next LOOP;
		}

		my($w_x) = $args{-extentsub}->($last_x, $last_y,
					       substr($str, 0, $j), 0);
		if ($w_x > $len_so_far) {
		    $draw->($j);
		    next LOOP;
		}
	    }
	}

	$section++;
    }

    if ($str ne "") {
	$draw->(length $str);
    }
}

sub len_of_coordrefs {
    my $coordref = shift;
    my $args = shift;
    my $last_coordref = shift || $#{$coordref};
    my $ges_strecke_len = 0;

    for(my $i = 0; $i<=$last_coordref-3; $i+=2) {
	$ges_strecke_len +=
	    Strassen::Util::strecke
		    ([$args->{-transpose}->($coordref->[$i],
					    $coordref->[$i+1])],
		     [$args->{-transpose}->($coordref->[$i+2],
					    $coordref->[$i+3])]);
    }

    $ges_strecke_len;
}

# Advance on the line represented by the $coordref from point $x/$y by
# $delta and return new $newx,$newy values. The point $x/$y lies on
# section number $section. A new section is also returned. Sections are
# numbered from 0. $args should contain the -transpose subroutine.
sub advance {
    my($coordref, $args, $x, $y, $section, $delta) = @_;
    my $i = $section*2 + 2;
    for(; $i<=$#$coordref; $i+=2) {
	my $this_hop = Strassen::Util::strecke
	    ([$args->{-transpose}->($x, $y)],
	     [$args->{-transpose}->($coordref->[$i],
				    $coordref->[$i+1])]);
	if ($this_hop > 0) {
	    if ($this_hop > $delta) {
		my $scale = $delta/$this_hop;
		return (($coordref->[$i]-$x)*$scale+$x,
			($coordref->[$i+1]-$y)*$scale+$y,
			$i);
	    }
	    $delta -= $this_hop;
	    ($x, $y) = ($coordref->[$i], $coordref->[$i+1]);
	}
    }
    ($x, $y, $#$coordref+1); # $delta is larger than line
}

sub in_between {
    my($a, $b) = @_;
#warn "a=$a b=$b middle=" . (($a-$b)/2+$a) . "\n";
    ($a-$b)/2+$b;
}

# Erstellt eine Rotationsmatrix für X11R6
# XXX rot-Funktion auslagern (CanvasRotText)
### AutoLoad Sub
sub get_rot_matrix {
    my($r, $size) = @_;
    $r = int(($r/PI)*36)/36*PI; # 5°-Schritte erzwingen
    if (abs($r - PI) < 0.1) {
	$r = 3.2;
    } elsif (abs($r + PI) < 0.1) {
	$r = -3.1;
    }
    my $mat;
    my $a1 = $size*cos($r);
    my $s1 = sin($r);
    foreach ($a1, $size*$s1, $size*-$s1, $a1) {
	s/-/~/g;
	if ($mat) { $mat .= " " }
	$mat .= $_;
    }
    '[' . $mat . ']';
}

# Rotiert den angegebenen Font um $r (Bogenmaß)
### AutoLoad Sub
sub rot_font {
    my($font, $r) = @_;
    my $top = $main::top;
    my $font_obj;
    eval {
	$font_obj = $top->X11Font($font);
    };
    if (!$font_obj) {
	# $font ist ein Tk-font und kann nicht als Argument für
	# Font verwendet werden.
	my(%f) = $top->fontActual($font);
	$font_obj = $top->Font(family => $f{-family},
			       point  => $f{-size}*10,
# Übersetzung zu medium/old etc. nötig
#			       weight => $f{-weight},
			       slant  => 'r',
#XXX Übersetzung zu o/i etc. nötig
#			       slant  => $f{-slant},
			      );
    }
    my $matrix = get_rot_matrix($r, $font_obj->Point/10);
    $font_obj->Point("");
    $font_obj->Pixel($matrix);
    $font_obj->as_string;
}

# Zeichnet den Straßennamen mit rotierten Zeichensätzen.
# XXX kann mit perl nicht zufriedenstellend gelöst werden
### AutoLoad Sub
sub createRotText {
    my($c, $x, $y, %args) = @_;
    my $str  = delete $args{-text};
    my $font = delete $args{-font};
# XXX effizienter gestalten
    my $dummy_l = $c->parent->Label(defined $font ? (-font => $font) : ());
    my $font_n_obj = $dummy_l->cget(-font);

    my $rot  = delete $args{-rot};
    if ($rot) {
	my $cache_name = "$font/$rot";
	if (exists $rot_font_cache{$cache_name}) {
	    $font = $rot_font_cache{$cache_name};
	} else {
	    $font = rot_font($font, $rot);
	    $rot_font_cache{$cache_name} = $font;
	}
    }
    my $anchor = delete $args{-anchor} || 'w';
    foreach (split(//, $str)) {
	$c->createText($x, $y, -text => $_, -font => $font, %args,
		       -anchor => $anchor,
		      );
	my $xadd = $main::top->font('measure', $font_n_obj, $_);
	$y -= $xadd*sin($rot);
	$x += $xadd*cos($rot);
    }
}
# XXX ^^^

1;

__END__
