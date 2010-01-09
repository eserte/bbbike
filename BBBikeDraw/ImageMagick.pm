# -*- perl -*-

#
# $Id: ImageMagick.pm,v 1.18 2007/05/31 21:44:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeDraw::ImageMagick;
use strict;
use base qw(BBBikeDraw);
use Strassen;
use Image::Magick;
use VectorUtil;
use vars qw($DEBUG);
eval 'local $SIG{__DIE__};
      require VectorUtil::InlineDist;
      VectorUtil::InlineDist->import;
     '; warn $@ if $DEBUG && $@;

# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);

use vars qw($gd_version $VERSION @colors %color %outline_color %width
	    $TTF_STREET);
BEGIN { @colors =
         qw($grey_bg $white $yellow $lightyellow $red $green $middlegreen $darkgreen
	    $darkblue $lightblue $rose $black $darkgrey $lightgreen);
}
use vars @colors;

$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

my(%brush, %outline_brush);

sub init {
    my $self = shift;

    $self->SUPER::init();

    $TTF_STREET = '/usr/X11R6/lib/X11/fonts/ttf/LucidaSansRegular.ttf'
	if !defined $TTF_STREET;

    $self->{ImageType} = 'png' if !defined $self->{ImageType};

    $self->{Width}  ||= 640;
    $self->{Height} ||= 480;

    my $im;
    if ($self->{OldImage}) {
	$im = $self->{OldImage};
    } else {
	$im = Image::Magick->new(size=>$self->{Width}."x".$self->{Height});
    }

    $self->{Image}  = $im;

    if (!$self->{OldImage}) {
  	$self->allocate_colors;
    }

    $self->set_category_colors;
    $self->set_category_outline_colors;
    $self->set_category_widths;

    # XXX don't hardcode
    $im->Read('xc:' . $grey_bg);

# XXX del:
#     if ($self->{Width}) {
#   	if ($self->{Width} <= 200) {
#   	    # scale widths
#   	    while(my($k,$v) = each %width) {
#   		$width{$k} = int($v/2) if $v >= 2;
#   	    }
#   	}
#     }

    $im->SetAttribute(interlace => 'Plane');

    $self->set_draw_elements;

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx
#$self->{StrLabel} = ['str:HH,H'];#XXX

    $self;
}

sub pre_draw {
    my $self = shift;
    $self->SUPER::pre_draw;

    my $im = $self->{Image};

    my $scale = ($self->{Xk} > 1 ? 10 : $self->{Xk} * 10);
    $scale = 0.5 if $scale < 0.5;

    if ($scale != 1) {
	while(my($k,$v) = each %width) {
	    $width{$k} = int($v*$scale);
	}
    }
}

sub allocate_colors {
    my $self = shift;
    my $im = $self->{Image};
    my($c, $c_order) = $self->get_color_values;

    no strict 'refs';
    for my $color (@$c_order) {
	my $value = $c->{$color};
	if (defined $value) {
	    # XXX handle transparent colors!
	    ${$color} = _colorAllocate(@{$value}[0..2]);
	}
    }
}

sub _colorAllocate {
    my($r,$g,$b) = @_;
    sprintf "#%02x%02x%02x", $r, $g, $b;
}

sub draw_map {
    my $self = shift;

    $self->pre_draw if !$self->{PreDrawCalled};

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    $self->_get_nets;
    $self->{FlaechenPass} = 1;

    my @netz = @{ $self->{_Net} };
    my @outline_netz = @{ $self->{_OutlineNet} };
    my @netz_name = @{ $self->{_NetName} };
    my %str_draw = %{ $self->{_StrDraw} };
    my %p_draw = %{ $self->{_PDraw} };
    my $title_draw = $self->{_TitleDraw};

    my $restrict;
    if ($self->{Restrict}) {
	$restrict = { map { ($_ => 1) } @{ $self->{Restrict} } };
    }

    if ($self->{Outline}) {
 	foreach my $strecke (@outline_netz) {
 	    $strecke->init;
 	    while(1) {
 		my $s = $strecke->next;
 		last if !@{$s->[1]};
 		my $cat = $s->[2];
		$cat =~ s{::.*}{};
# XXX what about outlined areas?
#  	    if ($cat =~ /^F:(.*)/) {
#  		if ($1 eq 'I') {
#  		    next; # Inseln vorerst ignorieren
#  		}
#  		my $c = $color{$1} || $white;
#  		my $poly = ImageMagick::Polygon->new();
#  		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
#  		    $poly->addPt(&$transpose
#  				 (@{Strassen::to_koord1($s->[1][$i])}));
#  		}
#  		$im->filledPolygon($poly, $c);
#	    } elsif ($cat !~ /^[SRU]0$/) { # Ausnahmen: in Bau
 		next if $restrict && !$restrict->{$cat};
 		my $color = $outline_color{$cat};
		next if !$color;
		my $width = defined $width{$cat} ? $width{$cat} : 1;
 		for(my $i = 0; $i < $#{$s->[1]}; $i++) {
 		    my($x1, $y1, $x2, $y2) =
 		      (@{Strassen::to_koord1($s->[1][$i])},
 		       @{Strassen::to_koord1($s->[1][$i+1])});
#XXX z.Zt. nicht korrekt, weil die bbox nicht anhand der Aspect-Beibehaltung
# des Bildes nicht korrigiert wird. Siehe auch BBBikeDraw::create_transpose
#XXX das stimmt nicht mehr
		    next if !VectorUtil::vector_in_grid
			($x1,$y1,$x2,$y2,
			 $self->{Min_x},$self->{Min_y},
			 $self->{Max_x},$self->{Max_y},
			);
 		    my($x1t, $y1t, $x2t, $y2t) = (&$transpose($x1, $y1),
 						  &$transpose($x2, $y2));
 		    $im->Draw(primitive=>'line',
			      points => "$x1t,$y1t,$x2t,$y2t",
			      strokewidth => $width+2,
			      stroke => $color);
 		}
 	    }
 	}
    }

    foreach my $strecke_i (0 .. $#netz) {
	my $strecke = $netz[$strecke_i];
	my $strecke_name = $netz_name[$strecke_i];
	my $flaechen_pass = $self->{FlaechenPass};

	for my $s ($self->get_street_records_in_bbox($strecke)) {
#XXX del:
#     foreach my $strecke (@netz) {
# 	my $flaechen_pass = $self->{FlaechenPass};
# 	$strecke->init;
# 	while(1) {
# 	    my $s = $strecke->next;
# 	    last if !@{$s->[1]};
	    my $cat = $s->[2];
	    if ($cat =~ /^F:(.*)/) {
		my $cat = $1;
		next if ($strecke_name eq 'flaechen' &&
			 (($flaechen_pass == 1 && $cat eq 'Pabove') ||
			  ($flaechen_pass == 2 && $cat ne 'Pabove'))
			);
		my $c = defined $color{$cat} ? $color{$cat} : $white;
		my $oc = ($self->{Outline} && defined $outline_color{$cat} ?
			  $outline_color{$cat} : $c);
		my @poly;
		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
		    push @poly, join(",", &$transpose
				     (@{Strassen::to_koord1($s->[1][$i])}));
		}
		$im->Draw(primitive => 'polygon',
			  points => join(" ", @poly),
			  fill => $c,
			  stroke => $oc);
	    } elsif ($cat !~ $BBBikeDraw::bahn_bau_rx) { # Ausnahmen: in Bau
		$cat =~ s{::.*}{};
		next if $restrict && !$restrict->{$cat};
		my $color = defined $color{$cat} ? $color{$cat} : $white;
		my $width = defined $width{$cat} ? $width{$cat} : 1;
		for(my $i = 0; $i < $#{$s->[1]}; $i++) {
		    my($x1, $y1, $x2, $y2) =
		      (@{Strassen::to_koord1($s->[1][$i])},
		       @{Strassen::to_koord1($s->[1][$i+1])});
		    # Aus Performancegründen testen, ob überhaupt im
		    # Zeichenbereich.
		    next if !VectorUtil::vector_in_grid
			($x1,$y1,$x2,$y2,
			 $self->{Min_x},$self->{Min_y},
			 $self->{Max_x},$self->{Max_y},
			);
		    my($x1t, $y1t, $x2t, $y2t) = (&$transpose($x1, $y1),
						  &$transpose($x2, $y2));
		    # XXX use polyline instead?
		    $im->Draw(primitive=>'line',
			      points => "$x1t,$y1t $x2t,$y2t",
			      strokewidth => $width,
			      stroke => $color);
		}
	    }
	}

	if ($strecke_name eq 'flaechen') {
	    $self->{FlaechenPass}++;
	}
    }

#      # $self->{Xk} bezeichnet den Vergrößerungsfaktor
#      # bis etwa 0.02 ist es zu unübersichtlich, Ampeln zu zeichnen,
#      # ab etwa 0.05 kann man die mittelgroße Variante nehmen
#      if ($p_draw{'ampel'} && $self->{Xk} >= 0.02) {
#  	my $lsa = new Strassen "ampeln";
#  	my $images_dir = $self->get_images_dir;
#  	my $suf = ($self->{Xk} >= 0.05 ? '' : '2');

#  	my($kl_ampel, $w_lsa, $h_lsa);
#  	my($kl_andreas, $w_and, $h_and);
#  	if (open(GIF, "$images_dir/ampel_klein$suf." . $self->imagetype)) {
#  	    binmode GIF;
#  	    $kl_ampel = newFromImage ImageMagick::Image \*GIF;
#  	    ($w_lsa, $h_lsa) = $kl_ampel->getBounds;
#  	    close GIF;
#  	}

#  	if (open(GIF, "$images_dir/andreaskr_klein$suf." . $self->imagetype)) {
#  	    binmode GIF;
#  	    $kl_andreas = newFromImage ImageMagick::Image \*GIF;
#  	    # workaround: newFromPNG vergisst die Transparency-Information
#  	    $kl_andreas->transparent($kl_andreas->colorClosest(192,192,192));
#  	    ($w_and, $h_and) = $kl_andreas->getBounds;
#  	    close GIF;
#  	}

#  	if ($kl_andreas && $kl_ampel) {
#  	    $lsa->init;
#  	    while(1) {
#  		my $s = $lsa->next_obj;
#  		last if $s->is_empty;
#  		my $cat = $s->category;
#  		my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  		if ($cat eq 'B') {
#  		    $im->copy($kl_andreas, $x-$w_and/2, $y-$h_and/2, 0, 0,
#  			      $w_and, $h_and);
#  		} else {
#  		    $im->copy($kl_ampel, $x-$w_lsa/2, $y-$h_lsa/2, 0, 0,
#  			      $w_lsa, $h_lsa);
#  		}
#  	    }
#  	}
#      }

#      my($xw, $yw);
#      my $small_display = 0;
#      if ($self->{Width} < 200 ||	$self->{Height} < 150) {
#  	($xw, $yw) = (1, 1);
#  	$small_display = 1;
#      } else {
#  	my($xw1, $yw1) = &$transpose(0, 0);
#  	my($xw2, $yw2) = &$transpose(60, 60);
#  	($xw, $yw) = ($xw2-$xw1, $yw2-$yw1);
#      }
#      my $min_ort_category = ($self->{Xk} < 0.005 ? 4
#  			    : ($self->{Xk} < 0.01 ? 3
#  			       : ($self->{Xk} < 0.02 ? 2
#  				  : ($self->{Xk} < 0.03 ? 1 : 0))));
#      my %ort_font = (0 => &ImageMagick::Font::Tiny,
#  		    1 => &ImageMagick::Font::Small,
#  		    2 => &ImageMagick::Font::Small,
#  		    3 => &ImageMagick::Font::Large, # MediumBold sieht fetter aus
#  		    4 => &ImageMagick::Font::Large,
#  		    5 => &ImageMagick::Font::Giant,
#  		    6 => &ImageMagick::Font::Giant,
#  		   );
#      foreach my $points (['ubahn', 'ubahnhof', 'u'],
#  			['sbahn', 'sbahnhof', 's'],
#  			['ort', 'orte',       'o'],
#  		       ) {
#  	# check if it is advisable to draw stations...
#  	next if ($points->[0] =~ /bahn$/ && $self->{Xk} < 0.004);

#  	if ($str_draw{$points->[0]}) {
#  	    my $p = ($points->[0] eq 'ort'
#  		     ? $self->_get_orte
#  		     : new Strassen $points->[1]);
#  	    my $type = $points->[2];
#  	    $p->init;
#  	    while(1) {
#  		my $s = $p->next_obj;
#  		last if $s->is_empty;
#  		my $cat = $s->category;
#  		next if $cat =~ /0$/;
#  		my($x0,$y0) = @{$s->coord_as_list(0)};
#  		# Bereichscheck (XXX ist nicht ganz korrekt wenn der Screen breiter ist als die Route)
#  #  		next if (!(($x0 >= $self->{Min_x} and $x0 <= $self->{Max_x})
#  #  			   and
#  #  			   ($y0 >= $self->{Min_y} and $y0 <= $self->{Max_y})));
#  		if ($type eq 'u' || ($type eq 's' && $small_display)) {
#  		    my($x1,$x2,$y1,$y2);
#  		    if (!$small_display) {
#  			($x1, $y1) = &$transpose($x0-20, $y0-20);
#  			($x2, $y2) = &$transpose($x0+20, $y0+20);
#  		    } else {
#  			($x1, $y2) = &$transpose($x0, $y0);
#  			($x2, $y1) = ($x1+$xw, $y2+$yw);
#  			($x1, $y2) = ($x1-$xw, $y2-$yw);
#  		    }
#  		    # Achtung: y2 und y1 vertauschen!
#  		    # XXX Farbe bei small_display && s-bahn
#  		    $im->filledRectangle($x1, $y2, $x2, $y1, $darkblue);
#  		} elsif ($type eq 's') {
#  		    # XXX ausgefüllten Kreis zeichnen
#  		    my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  		    $im->arc($x, $y, $xw, $yw, 0, 360, $darkgreen);
#  		} else {
#  		    if ($cat >= $min_ort_category) {
#  			my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  			my $ort = $s->name;
#  			# Anhängsel löschen (z.B. "b. Berlin")
#  			$ort =~ s/\|.*$//;
#  			$im->arc($x, $y, 3, 3, 0, 360, $black);
#  			outline_text($im, $ort_font{$cat} || &ImageMagick::Font::Small,
#  				     $x+4, $y,
#  				     patch_string($ort), $white, $darkblue);
#  		    }
#  		}
#  	    }
#  	}
#      }

#      if (ref $self->{StrLabel} &&
#  	(defined &ImageMagick::Image::stringFT || defined &ImageMagick::Image::stringTTF)) {
#  	eval {
#  	    my $ttf = $TTF_STREET;

#  	    my $fontsize = 10;
#  	    $Tk::RotFont::NO_X11 = 1;
#  	    require Tk::RotFont;

#  	    my $ft_method = defined &ImageMagick::Image::stringFT ? 'stringFT' : 'stringTTF';

#  	    my $draw_sub = sub {
#  		my($x,$y) = &$transpose($_[0], $_[1]);
#  		if (defined $_[4] and defined $_[5]) {
#  		    $x -= $_[4];
#  		    $y -= $_[5];
#  		}

#  		# correct base point of text to middle:
#  		my $rad = -$_[3];
#  		my $cx = sin($rad)*$fontsize/2;
#  		my $cy = cos($rad)*$fontsize/2;
#  		$x += $cx;
#  		$y += $cy;
#  		warn "correct $cx/$cy\n";
#  		$im->$ft_method($black, $ttf, $fontsize, $rad, $x, $y, $_[2]);
#  	    };
#  	    my $extent_sub = sub {
#  		my(@b) = ImageMagick::Image->$ft_method($black, $ttf, $fontsize, -$_[3],
#  					       &$transpose($_[0], $_[1]),
#  					       $_[2]);
#  		($b[2]-$b[0], $b[3]-$b[1]);
#  	    };

#  	    my $strecke = $multistr;
#  	    $strecke->init;
#  	    while(1) {
#  		my $s = $strecke->next;
#  		last if !@{$s->[1]};
#  		my $cat = $s->[2];
#  		next unless $cat eq 'HH' || $cat eq 'H';

#  		my($x1, $y1, $xe, $ye) = (@{Strassen::to_koord1($s->[1][0])},
#  					  @{Strassen::to_koord1($s->[1][-1])});
#  		next if (!(($x1 >= $self->{Min_x} and $xe <= $self->{Max_x}) and
#  			   ($y1 >= $self->{Min_y} and $ye <= $self->{Max_y})));
#  		my $str = Strassen::strip_bezirk($s->[0]);
#  		my $coordref = [ map { (split(/,/, $_)) } @{ $s->[1] } ];
#  		Tk::RotFont::rot_text_smart($str, $coordref,
#  					    -drawsub   => $draw_sub,
#  					    -extentsub => $extent_sub,
#  					    -transpose => $transpose,
#  					   );
#  	    }
#  	};
#  	warn $@ if $@;
#      }

#    $self->{TitleDraw} = $title_draw;

    $self->draw_scale unless $self->{NoScale};
}

# Zeichnen des Maßstabs
sub draw_scale {
    my $self = shift;
    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    my $x_margin = 10;
    my $y_margin = 10;
    my $color = $black;
    my $bar_width = 4;
    my($x0,$y0) = $transpose->(0,0);
    my($x1,$y1, $strecke, $strecke_label);
    for $strecke (1000, 5000, 10000, 20000, 50000, 100000) {
	($x1,$y1) = $transpose->($strecke,0);
	if ($x1-$x0 > 30) {
	    $strecke_label = $strecke/1000 . "km";
	    last;
	}
    }

    $im->Draw(primitive => 'line',
	      points => (($self->{Width}-($x1-$x0)-$x_margin).",".
			 ($self->{Height}-$y_margin)." ".
			 ($self->{Width}-$x_margin).",".
			 ($self->{Height}-$y_margin)),
	      stroke => $color);
    $im->Draw(primitive => 'line',
	      points => (($self->{Width}-($x1-$x0)-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width)." ".
			 ($self->{Width}-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width)),
	      stroke => $color);
    $im->Draw(primitive => 'rectangle',
	      points => (($self->{Width}-($x1-$x0)/2-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width)." ".
			 ($self->{Width}-$x_margin).",".
			 ($self->{Height}-$y_margin)),
	      fill => $color);
    $im->Draw(primitive => 'line',
	      points => (($self->{Width}-($x1-$x0)/2-$x_margin).",".
			 ($self->{Height}-$y_margin)." ".
			 ($self->{Width}-($x1-$x0)/2-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width)),
	      stroke => $color);
    $im->Draw(primitive => 'line',
	      points => (($self->{Width}-($x1-$x0)-$x_margin).",".
			 ($self->{Height}-$y_margin+2)." ".
			 ($self->{Width}-($x1-$x0)-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width-2)),
	      stroke => $color);
    $im->Draw(primitive => 'line',
	      points => (($self->{Width}-$x_margin).",".
			 ($self->{Height}-$y_margin+2)." ".
			 ($self->{Width}-$x_margin).",".
			 ($self->{Height}-$y_margin-$bar_width-2)),
	      stroke => $color);
    $im->Annotate(text => "0",
		  geometry => "+".($self->{Width}-($x1-$x0)-$x_margin-3).
		              "+".($self->{Height}-$y_margin-$bar_width-2),
		  fill => $color,
		  pointsize => 10);
    $im->Annotate(text => $strecke_label,
		  geometry => "+".($self->{Width}-$x_margin+8-6*length($strecke_label)).
		              "+".($self->{Height}-$y_margin-$bar_width-2),
		  fill => $color,
		  pointsize => 10);
}

  sub draw_route {
#      my $self = shift;
#      my $im        = $self->{Image};
#      my $transpose = $self->{Transpose};
#      my(@c1)       = @{ $self->{C1} };
#      my $strnet; # StrassenNetz-Objekt

#      foreach (@{$self->{Draw}}) {
#  	if ($_ eq 'strname' && $self->{'MakeNet'}) {
#  	    $strnet = $self->{MakeNet}->('lite');
#  	}
#      }

#      my $brush; # should be *outside* the next block!!!
#      my $line_style;
#      if ($self->{RouteWidth}) {
#  	# fette Routen für die WAP-Ausgabe (B/W)
#  	$brush = ImageMagick::Image->new($self->{RouteWidth}, $self->{RouteWidth});
#  	$brush->colorAllocate($im->rgb($black));
#  	$im->setBrush($brush);
#  	$line_style = ImageMagick::gdBrushed();
#      } elsif ($brush{Route}) {
#  	$im->setBrush($brush{Route});
#  	$line_style = ImageMagick::gdBrushed();
#      } else {
#  	# Vorschlag von Rainer Scheunemann: die Route in blau zu zeichnen,
#  	# damit Rot-Grün-Blinde sie auch erkennen können. Vielleicht noch
#  	# besser: rot-grün-gestrichelt
#  	$im->setStyle($darkblue, $darkblue, $darkblue, $red, $red, $red);
#  	$line_style = ImageMagick::gdStyled();
#      }

#      # Route
#      for(my $i = 0; $i < $#c1; $i++) {
#  	my($x1, $y1, $x2, $y2) = (@{$c1[$i]}, @{$c1[$i+1]});
#  	$im->line(&$transpose($x1, $y1),
#  		  &$transpose($x2, $y2), $line_style);
#      }

#      # Flags
#      if (@c1 > 1) {
#  	if ($self->{UseFlags} &&
#  	    defined &ImageMagick::Image::copyMerge &&
#  	    $self->imagetype ne 'wbmp') {
#  	    my $images_dir = $self->get_images_dir;
#  	    if (open(GIF, "$images_dir/flag2_bl." . $self->imagetype)) {
#  		binmode GIF;
#  		my $start_flag = newFromImage ImageMagick::Image \*GIF;
#  		close GIF;
#  		my($w, $h) = $start_flag->getBounds;
#  		my($x, $y) = &$transpose(@{ $c1[0] });
#  		# workaround: newFromPNG vergisst die Transparency-Information
#  		$start_flag->transparent($start_flag->colorClosest(192,192,192));
#  		$im->copyMerge($start_flag, $x-5, $y-15,
#  			       0, 0, $w, $h, 50);
#  	    }
#  	    if (open(GIF, "$images_dir/flag_ziel." . $self->imagetype)) {
#  		binmode GIF;
#  		my $end_flag = newFromImage ImageMagick::Image \*GIF;
#  		close GIF;
#  		my($w, $h) = $end_flag->getBounds;
#  		my($x, $y) = &$transpose(@{ $c1[-1] });
#  		# workaround: newFromPNG vergisst die Transparency-Information
#  		$end_flag->transparent($end_flag->colorClosest(192,192,192));
#  		$im->copyMerge($end_flag, $x-5, $y-15,
#  			       0, 0, $w, $h, 50);
#  	    }
#  	} elsif ($self->{UseFlags} && $self->imagetype eq 'wbmp' &&
#  		 $self->{RouteWidth}) {
#  	    my($x, $y) = &$transpose(@{ $c1[0] });
#  	    for my $w ($self->{RouteWidth}+5 .. $self->{RouteWidth}+6) {
#  		$im->arc($x,$y,$w,$w,0,360,$black);
#  	    }
#  	}
#      }

#      # Ausgabe der Straßennnamen
#      if ($strnet) {
#  	my($text_inner, $text_outer);
#  	if ($self->{Bg} eq 'white') {
#  	    ($text_inner, $text_outer) = ($darkblue, $white);
#  	} else {
#  	    ($text_inner, $text_outer) = ($white, $darkblue);
#  	}
#  	my(@strnames) = $strnet->route_to_name
#  	    ([ map { [split ','] } @{ $self->{Coords} } ]);
#  	foreach my $e (@strnames) {
#  	    my $name = Strassen::strip_bezirk($e->[0]);
#  	    my $f_i  = $e->[4][0];
#  	    my($x,$y) = &$transpose(split ',', $self->{Coords}[$f_i]);
#  	    outline_text($im, &ImageMagick::Font::Small, $x, $y,
#  			 patch_string($name), $text_inner, $text_outer);
#  	}
#      }

#      if ($self->{TitleDraw}) {
#  	my $start = patch_string($self->{Startname});
#  	my $ziel  = patch_string($self->{Zielname});
#  	foreach my $s (\$start, \$ziel) {
#  	    # Text in Klammern entfernen, damit der Titel kürzer wird
#  	    my(@s) = split(m|/|, $$s);
#  	    foreach (@s) {
#  		s/\s+\(.*\)$//;
#  	    }
#  	    $$s = join("/", @s);
#  	}
#  	my $s =  "$start -> $ziel";

#  	my $gdfont;
#  	if (7*length($s) <= $self->{Width}) {
#  	    $gdfont = \&ImageMagick::Font::MediumBold;
#  	} elsif (6*length($s) <= $self->{Width}) {
#  	    $gdfont = \&ImageMagick::Font::Small;
#  	} else {
#  	    $gdfont = \&ImageMagick::Font::Tiny;
#  	}
#  	my $inner = $white;
#  	my $outer = $darkblue;
#  	if ($self->{Bg} =~ /^white/) {
#  	    ($inner, $outer) = ($outer, $inner);
#  	}
#  	outline_text($im, &$gdfont, 1, 1, $s, $inner, $outer);
#      }
#  }

#  sub outline_text {
#      my($im, $gdfont, $x, $y, $s, $inner, $outer) = @_;
#      for ([-1, 0], [1, 0], [0, 1], [0, -1]) {
#  	$im->string($gdfont, $x+$_->[0], $y+$_->[1],
#  		    $s, $outer);
#      }
#      $im->string($gdfont, $x, $y,
#  		$s, $inner);
  }

#  # Draw this first, otherwise the filling of the circle won't work!
  sub draw_wind {
#      my $self = shift;
#      return unless $self->{Wind};
#      require BBBikeCalc;
#      BBBikeCalc::init_wind();
#      my $richtung = lc($self->{Wind}{Windrichtung});
#      if ($richtung =~ /o$/) { $richtung =~ s/o$/e/; }
#      my $staerke  = $self->{Wind}{Windstaerke};
#      my $im = $self->{Image};
#      my($radx, $rady) = (10, 10);
#      my $col = $darkblue;
#      $im->arc($self->{Width}-20, 20, $radx, $rady, 0, 360, $col);
#      $im->fill($self->{Width}-20, 20, $col);
#      if ($staerke > 0) {
#  	my %senkrecht = # im Uhrzeigersinn
#  	    ('-1,-1' => [-1,+1],
#  	     '-1,0'  => [ 0,+1],
#  	     '-1,1'  => [+1,+1],
#  	      '0,1'  => [+1, 0],
#  	      '1,1'  => [+1,-1],
#  	      '1,0'  => [ 0,-1],
#  	      '1,-1' => [-1,-1],
#  	      '0,-1' => [-1, 0],
#  	    );
#  	my($ydir, $xdir) = @{$BBBikeCalc::wind_dir{$richtung}};
#  	if (exists $senkrecht{"$xdir,$ydir"}) {
#  	    my($x2dir, $y2dir) = @{ $senkrecht{"$xdir,$ydir"} };
#  	    my($yadd, $xadd) = map { -$_*15 } ($ydir, $xdir);
#  	    $xadd = -$xadd; # korrigieren
#  	    $im->line($self->{Width}-20, 20, $self->{Width}-20+$xadd, 20+$yadd,
#  		      $col);
#  	    my $this_tic = 15;
#  	    my $i = $staerke;
#  	    my $last_is_half = 0;
#  	    if ($i%2 == 1) {
#  		$last_is_half++;
#  		$i--;
#  	    }
#  	    while ($i >= 0) {
#  		my($yadd, $xadd) = map { -$_*$this_tic } ($ydir, $xdir);
#  		$xadd = -$xadd;
#  		my $stroke_len;
#  		if ($i == 0) {
#  		    if ($last_is_half) {
#  			# half halbe Strichlänge
#  			$stroke_len = 3;
#  		    } else {
#  			last;
#  		    }
#  		} else {
#  		    # full; volle Strichlänge
#  		    $stroke_len = 6;
#  		}
#  		my($yadd2, $xadd2) = map { -$_*$stroke_len } ($y2dir, $x2dir);
#  		$xadd2 = -$xadd2;
#  		$im->line($self->{Width}-20+$xadd, 20+$yadd,
#  			  $self->{Width}-20+$xadd+$xadd2, 20+$yadd+$yadd2,
#  			  $col);
#  		$this_tic -= 3;
#  		last if $this_tic <= 0;
#  		$i-=2;
#  	    }
#  	}
#      }
  }

#  sub make_imagemap {
#      my $self = shift;
#      my $fh = shift || confess "No file handle supplied";
#      my(%args) = @_;

#      if (!defined $self->{Width} &&
#  	!defined $self->{Height}) {
#  	if ($self->{Geometry} =~ /^(\d+)x(\d+)$/) {
#  	    ($self->{Width}, $self->{Height}) = ($1, $2);
#  	}
#      }

#      my $transpose = $self->{Transpose};
#      my $multistr = $self->_get_strassen; # XXX Übergabe von %str_draw?

#      # keine Javascript-Abfrage, damit der Code generell bleibt und
#      # gecachet werden kann...
#      if ($args{'-generate_javascript'}) {
#  	print $fh <<EOF;
#  <script language=javascript>
#  <!--
#  function s(text) {
#    self.status=text;
#    return true;
#  }
#  // -->
#  </script>
#  EOF
#      }
#      print $fh "<map name=\"map\">";

#      $multistr->init;
#      while(1) {
#  	my $s = $multistr->next_obj;
#  	last if $s->is_empty;
#  	if ($s->category !~ /^F/ && $#{$s->coords} > 0) {
#  	    my(@polygon1, @polygon2);
#  	    my($dx, $dy, $c);
#  	    my($x1, $y1, $x2, $y2);
#  	    for(my $i = 0; $i < $#{$s->coords}; $i++) {
#  		($x1, $y1, $x2, $y2) = 
#  		  (&$transpose(@{$s->coord_as_list($i)}),
#  		   &$transpose(@{$s->coord_as_list($i+1)}));
#  		$dx = $x2-$x1;
#  		$dy = $y2-$y1;
#  		$c = CORE::sqrt($dx*$dx + $dy*$dy)/2;
#  		if ($c == 0) { $c = 0.00001; }
#  		$dx /= $c;
#  		$dy /= $c;
#  		push    @polygon1, int($x1-$dy), int($y1+$dx);
#  		unshift @polygon2, int($x1+$dy), int($y1-$dx);
#  	    }
#  	    # letzter Punkt
#  	    push    @polygon1, int($x2-$dy), int($y2+$dx);
#  	    unshift @polygon2, int($x2+$dy), int($y2-$dx);

#  	    # Optimierung: nur die eine Seite des Polygons wird überprüft
#  	    next unless $self->is_in_map(@polygon1);

#  	    my $coordstr = join(",", @polygon1, @polygon2,
#  				$polygon1[0], $polygon1[1]);
#  	    print $fh
#  # XXX folgendes: AREA ONMOUSEOVER funktioniert für
#  # FreeBSD-Netscape
#  # bei Win-MSIE wird es ignoriert
#  # und bei WIn-NS wird ein falscher Link erzeugt
#  # title= wird noch nicht von NS und IE unterstützt
#  # evtl. AREA ganz weglassen
#  # XXX check mit onclick. evtl. onclick so patchen, dass submit mit
#  # richtigen Werten aufgerufen wird.
#  #	      "<area title=\"" . $s->name . "\" ",
#  	      "<area href=\"\" ",
#  		"shape=poly ",
#  		"coords=\"$coordstr\" ",
#  		"onmouseover=\"return s('" . $s->name . "')\" ",
#  	        "onclick=\"return false\" ",
#  		">\n";
#  	}
#      }

#      print $fh "</map>";
#  }

#  sub is_in_map {
#      my($self, @coords) = @_;
#      my $i;
#      for($i = 0; $i<$#coords; $i+=2) {
#  	return 1 if ($coords[$i]   >= 0 &&
#  		     $coords[$i]   <= $self->{Width} &&
#  		     $coords[$i+1] >= 0 &&
#  		     $coords[$i+1] <= $self->{Height});
#      }
#      return 0;
#  }

sub flush {
    my $self = shift;
    my %args = @_;
    my $file = "/tmp/imagemagick.$$." . $self->suffix; # XXX /tmp
    $self->{Image}->Write($file);
    open(IN, $file) or open(IN, "$file.0") or die "Can't open $file: $!";
    local $/ = undef;
    my $fh = $args{Fh} || $self->{Fh};
    binmode $fh;
    print $fh <IN>;
    close IN;
    unlink $file;
    unlink "$file.0";
}

#  sub empty_image_error {
#      my $self = shift;
#      my $im = $self->{Image};
#      my $fh = $self->{Fh};

#      $im->string(ImageMagick->gdLargeFont, 10, 10, "Empty image!", $white);
#      binmode $fh if $fh;
#      if ($fh) {
#  	print $fh $im->imageOut;
#      } else {
#  	print $im->imageOut;
#      }
#      confess "Empty image";
#  }

# XXX trying to fix ImageMagick color problem...
sub DESTROY {
#      my $self = shift;
#      if ($self->{Image}) {
#  	foreach my $col (@colors) {
#  	    $self->{Image}->colorDeallocate(eval '$col');
#  	}
#      }
}

1;
