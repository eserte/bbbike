# -*- perl -*-

#
# $Id: Imager.pm,v 1.24 2008/02/09 22:51:39 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# Especially the drawing of filled polygons, which is needed to emulate
# broad lines, seems to be very slow... maybe this can be made better
# if only *needed* objects are really drawn (use grids!).

package BBBikeDraw::Imager;
use strict;
use base qw(BBBikeDraw);
use Strassen;
# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);
use Imager;

use vars qw($VERSION @colors %color %outline_color %width
	    $TTF_STREET $TTF_CITY);
BEGIN { @colors =
         qw($grey_bg $white $yellow $lightyellow $red $green $middlegreen $darkgreen
	    $darkblue $lightblue $rose $black $darkgrey $lightgreen);
}
use vars @colors;

#XXX
#  use vars qw($AUTOLOAD);
#  sub AUTOLOAD {
#      warn "Loading BBBikeDraw::GDHeavy for $AUTOLOAD ...\n";
#      require BBBikeDraw::GDHeavy;
#      if (defined &$AUTOLOAD) {
#  	goto &$AUTOLOAD;
#      } else {
#  	die "Cannot find $AUTOLOAD in ". __PACKAGE__;
#      }
#  }

$VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

my(%brush, %outline_brush);

# REPO BEGIN
# REPO NAME pi /home/e/eserte/src/repository 
# REPO MD5 bb2103b1f2f6d4c047c4f6f5b3fa77cd
sub pi ()   { 4 * atan2(1, 1) } # 3.141592653
# REPO END

sub init {
    my $self = shift;

    $self->SUPER::init();

    $TTF_STREET = '/usr/X11R6/lib/X11/fonts/ttf/LucidaSansRegular.ttf'
	if !defined $TTF_STREET;
    $TTF_CITY   = '/usr/X11R6/lib/X11/fonts/Type1/lcdxsr.pfa'
	if !defined $TTF_CITY;

    local $^W = 0;

    $self->{Width}  ||= 640;
    $self->{Height} ||= 480;
    my $im;
    if ($self->{OldImage}) {
	$im = $self->{OldImage};
    } else {
	$im = Imager->new(xsize=>$self->{Width}, ysize=>$self->{Height});
    }

    $self->{Image}  = $im;
    $self->{ImageType} = 'png' if !$self->{ImageType};

    # Not really allocate --- just define color variables
    $self->allocate_colors;

    $self->set_category_colors;
    $self->set_category_outline_colors;
    $self->set_category_widths;

    if ($self->{Width}) {
	if ($self->{Width} <= 200) {
	    # scale widths
	    while(my($k,$v) = each %width) {
		$width{$k} = int($v/2) if $v >= 2;
	    }
	}

##XXX not yet
#  	# create brushes
#  	foreach my $cat (keys %width) {
#  	    next if $cat eq 'Route';
#  	    my $brush = GD::Image->new($width{$cat}, $width{$cat});
#  	    $brush->colorAllocate($im->rgb($color{$cat}));
#  	    $brush{$cat} = $brush;
#  	}
#  	# create outline brushes
#  	foreach my $cat (keys %width) {
#  	    next unless $outline_color{$cat};
#  	    my $brush = GD::Image->new($width{$cat}+2, $width{$cat}+2);
#  	    $brush->colorAllocate($im->rgb($outline_color{$cat}));
#  	    $outline_brush{$cat} = $brush;
#  	}
    }

##???
#    $im->interlaced('true');

    $self->set_draw_elements;

#XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx
#$self->{StrLabel} = ['str:HH,H'];#XXX

#XXX anyway, should not be here...
#      if ($self->imagetype eq 'wbmp' && !defined $self->{RouteWidth}) {
#  	$self->{RouteWidth} = $width{HH} + 4;
#          #$self->{RouteDotted} = 3;
#      }

    $self;
}

sub allocate_colors {
    my $self = shift;
    my $im = $self->{Image};
    my($c, $c_order) = $self->get_color_values;

    no strict 'refs';
    for my $color (@$c_order) {
	my $value = $c->{$color};
	if (defined $value) {
	    $ {$color} = Imager::Color->new(@{$value}[0..3]);
	}
    }

    if (!$self->{OldImage}) {
	# fill the background with the first color
	$im->flood_fill(x => 1, y => 1, color => $ {$c_order->[0]});
    }

    if ($self->imagetype eq 'gif') {
	$im->tags(gif_interlace => 1);
    }
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
    my %str_draw = %{ $self->{_StrDraw} };
    my %p_draw = %{ $self->{_PDraw} };
    my $title_draw = $self->{_TitleDraw};

    my($restrict, $restrict_code);
    if (defined $self->{Restrict}) {
	if (UNIVERSAL::isa($self->{Restrict}, 'ARRAY')) {
	    $restrict = { map { ($_ => 1) } @{ $self->{Restrict} } };
	} elsif (UNIVERSAL::isa($self->{Restrict}, 'CODE')) {
	    $restrict_code = $self->{Restrict};
	}
    }

    if ($self->{Outline}) {
	foreach my $strecke (@outline_netz) {
	    $strecke->init;
	    while(1) {
		my $s = $strecke->next;
		last if !@{$s->[1]};
		my $cat = $s->[2];
		$cat =~ s{::.*}{};
#  	    if ($cat =~ /^F:(.*)/) {
#  		if ($1 eq 'I') {
#  		    next; # Inseln vorerst ignorieren
#  		}
#  		my $c = $color{$1} || $white;
#  		my $poly = GD::Polygon->new();
#  		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
#  		    $poly->addPt(&$transpose
#  				 (@{Strassen::to_koord1($s->[1][$i])}));
#  		}
#  		$im->filledPolygon($poly, $c);
#	    } elsif ($cat !~ /^[SRU]0$/) { # Ausnahmen: in Bau
		next if $restrict && !$restrict->{$cat};
		my $color = $outline_color{$cat};
		next if !defined $color;
		my $width = $width{$cat} || 1; $width += 2;
		my $points_x = [];
		my $points_y = [];
		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
		    my($x, $y) = &$transpose(@{Strassen::to_koord1($s->[1][$i])});
		    push @$points_x, $x;
		    push @$points_y, $y;
		}
		($points_x, $points_y) = _add_width($points_x, $points_y,
						    $width) if $width;
		$im->polygon(x => $points_x, y => $points_y, color => $color);
	    }
	}
    }

    foreach my $strecke (@netz) {
	my $flaechen_pass = $self->{FlaechenPass};
$strecke->make_grid(UseCache => 1);
my @grids = $strecke->get_new_grids($self->{Min_x}, $self->{Min_y},
				    $self->{Max_x}, $self->{Max_y},
				   );
#	$strecke->init;
#	while(1) {
#	    my $s = $strecke->next;
#	    last if !@{$s->[1]};
for my $grid (@grids) {
if ($strecke->{Grid}{$grid}) {
for my $strpos (@{ $strecke->{Grid}{$grid}}) {
my $s = $strecke->get($strpos);
	    my $cat = $s->[2];
	    if ($cat =~ /^F:(.*)/) {
		my $cat = $1;
#XXX NYI
#		next if (($flaechen_pass == 1 && $cat eq 'F:Pabove') ||
#			 ($flaechen_pass == 2 && $cat ne 'F:Pabove'));
		my $c = defined $color{$cat} ? $color{$cat} : $white;
		my $points = [];
		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
		    push @$points,
			[&$transpose(@{Strassen::to_koord1($s->[1][$i])})];
		}
		$im->polygon(points => $points, color => $c);
	    } elsif ($cat !~ $BBBikeDraw::bahn_bau_rx) { # Ausnahmen: in Bau
		$cat =~ s{::.*}{};
		next if $restrict && !$restrict->{$cat};
		my $color = defined $color{$cat} ? $color{$cat} : $white;
		my $width = $width{$cat} || 1;
		my $points_x = [];
		my $points_y = [];
		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
		    my($x, $y) = &$transpose(@{Strassen::to_koord1($s->[1][$i])});
		    push @$points_x, $x;
		    push @$points_y, $y;
		}
		($points_x, $points_y) = _add_width($points_x, $points_y,
						    $width) if $width;
		$im->polygon(x => $points_x, y => $points_y, color => $color);
	    }
	}
    }
}
}

#XXX not yet
#      # $self->{Xk} bezeichnet den Vergrößerungsfaktor
#      # bis etwa 0.02 ist es zu unübersichtlich, Ampeln zu zeichnen,
#      # ab etwa 0.05 kann man die mittelgroße Variante nehmen
#      if ($p_draw{'ampel'} && $self->{Xk} >= 0.02) {
#  	my $lsa = new Strassen "ampeln";
#  	my $images_dir = $self->get_images_dir;
#  	my $suf = ($self->{Xk} >= 0.05 ? '' : '2');

#  	my($kl_ampel, $w_lsa, $h_lsa);
#  	my($kl_andreas, $w_and, $h_and);
#  	my $imgfile;
#  	$imgfile = "$images_dir/ampel_klein$suf." . $self->imagetype;
#  	if (open(GIF, $imgfile)) {
#  	    binmode GIF;
#  	    $kl_ampel = newFromImage GD::Image \*GIF;
#  	    if ($kl_ampel) {
#  		($w_lsa, $h_lsa) = $kl_ampel->getBounds;
#  	    } else {
#  		warn "$imgfile exists, but can't be read by GD";
#  	    }
#  	    close GIF;
#  	}

#  	$imgfile = "$images_dir/andreaskr_klein$suf." . $self->imagetype;
#  	if (open(GIF, $imgfile)) {
#  	    binmode GIF;
#  	    $kl_andreas = newFromImage GD::Image \*GIF;
#  	    if ($kl_andreas) {
#  		# workaround: newFromPNG vergisst die Transparency-Information
#  		$kl_andreas->transparent($kl_andreas->colorClosest(192,192,192));
#  		($w_and, $h_and) = $kl_andreas->getBounds;
#  	    } else {
#  		warn "$imgfile exists, but can't be read by GD";
#  	    }
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

    my($xw_u, $yw_u);
    my($xw_s, $yw_s);
    my $small_display = 0;
    if ($self->{Width} < 200 ||	$self->{Height} < 150) {
	($xw_u, $yw_u) = (1, 1);
	($xw_s, $yw_s) = (1, 1);
	$small_display = 1;
    } else {
  	my($xw1, $yw1) = &$transpose(0, 0);
  	my($xw2, $yw2) = &$transpose(60, 60);
  	my($xw, $yw) = ($xw2-$xw1, $yw2-$yw1);
	if ($xw < 2) {
	    ($xw_s, $yw_s) = (5,5);
	    ($xw_u, $yw_u) = (1,1);
	} else {
	    ($xw_s, $yw_s) = (7,7);
	    ($xw_u, $yw_u) = (2,2);
	}
    }
    my $min_ort_category = $self->{MinPlaceCat};
    if (!defined $min_ort_category) {
	$min_ort_category = ($self->{Xk} < 0.005 ? 4
			     : ($self->{Xk} < 0.01 ? 3
				: ($self->{Xk} < 0.02 ? 2
				   : ($self->{Xk} < 0.03 ? 1 : 0))));
    }
##XXX not yet
#      my %ort_font = %{ $self->get_ort_font_mapping };
#      my %seen_bahnhof;
#      my $strip_bhf = sub {
#  	my $bhf = shift;
#  	require Strassen::Strasse;
#  	$bhf =~ s/\s+\(.*\)$//; # strip text in parenthesis
#  	$bhf = Strasse::short($bhf, 1);
#  	$bhf =~ s/b[eu]rg$/b\'g/;
#  	$bhf;
#      };
#      foreach my $points (['ubahn', 'ubahnhof', 'u'],
#  			['sbahn', 'sbahnhof', 's'],
#  			['rbahn', 'rbahnhof', 'r'],
#  			['ort', 'orte',       'o'],
#  			['orte_city', 'orte_city', 'oc'],
#  		       ) {
#  	# check if it is advisable to draw stations...
#  	next if ($points->[0] =~ /bahn$/ && $self->{Xk} < 0.004);

#  	my $do_bahnhof = grep { $_ eq $points->[0]."name" } @{$self->{Draw}};
#  	if ($self->{Xk} < 0.06) {
#  	    $do_bahnhof = 0;
#  	}

#  	my $brush;
#  	if ($points->[2] =~ /^[sr]$/) {
#  	    $brush = GD::Image->new($xw_s,$yw_s);
#  	    $brush->transparent($brush->colorAllocate(255,255,255));
#  	    my $col = $brush->colorAllocate($im->rgb($color{'SA'}));
#  	    $brush->arc($xw_s/2,$yw_s/2,$xw_s,$yw_s,0,360,$col);
#  	    $brush->fill($xw_s/2,$yw_s/2,$col);
#  	    $im->setBrush($brush);
#  	}

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
#  		    if (0 && !$small_display) {
#  			($x1, $y1) = &$transpose($x0-20, $y0-20);
#  			($x2, $y2) = &$transpose($x0+20, $y0+20);
#  		    } else {
#  			($x1, $y2) = &$transpose($x0, $y0);
#  			($x2, $y1) = ($x1+$xw_u, $y2+$yw_u);
#  			($x1, $y2) = ($x1-$xw_u, $y2-$yw_u);
#  		    }
#  		    # Achtung: y2 und y1 vertauschen!
#  		    # XXX Farbe bei small_display && s-bahn
#  		    $im->filledRectangle($x1, $y2, $x2, $y1, $darkblue);
#  		    if ($do_bahnhof) {
#  			my $name = $strip_bhf->($s->name);
#  			if (!$seen_bahnhof{$name}) {
#  			    $self->outline_text($ort_font{'bhf'},
#  						$x1+4, $y1,
#  						patch_string($name),
#  						$darkblue, $grey_bg,
#  #						$white, $darkblue
#  					       );
#  			    $seen_bahnhof{$name}++;
#  			}
#  		    }
#  		} elsif ($type =~ /^[sr]$/) {
#  		    # XXX ausgefüllten Kreis zeichnen
#  		    my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  		    #$im->arc($x, $y, $xw_s, $yw_s, 0, 360, $darkgreen);
#  		    $im->line($x,$y,$x,$y,GD::gdBrushed());
#  		    if ($do_bahnhof) {
#  			my $name = $strip_bhf->($s->name);
#  			if (!$seen_bahnhof{$name}) {
#  			    $self->outline_text($ort_font{'bhf'},
#  						$x+4, $y,
#  						patch_string($name),
#  						$darkgreen, $grey_bg,
#  #						$white, $darkgreen
#  					       );
#  			    $seen_bahnhof{$name}++;
#  			}
#  		    }
#  		} else {
#  		    if ($cat >= $min_ort_category &&
#  			(!$restrict_code || $restrict_code->($s, $type))) {
#  			my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  			my $ort = $s->name;
#  			# Anhängsel löschen (z.B. "b. Berlin")
#  			$ort =~ s/\|.*$//;
#  			if ($type eq 'oc') {
#  			    $self->outline_text
#  				($ort_font{$cat} || &GD::Font::Small,
#  				 $x, $y,
#  				 patch_string($ort), $black, $grey_bg,
#  				 -anchor => "c",
#  				);
#  			} else {
#  			    $im->arc($x, $y, 3, 3, 0, 360, $black);
#  			    $self->outline_text
#  				($ort_font{$cat} || &GD::Font::Small,
#  				 $x, $y,
#  				 patch_string($ort), $black, $grey_bg,
#  				 -padx => 4, -pady => 4,
#  				);
#  			}
#  		    }
#  		}
#  	    }
#  	}
#      }

#      if (ref $self->{StrLabel} &&
#  	(defined &GD::Image::stringFT || defined &GD::Image::stringTTF)) {
#  	eval {
#  	    my $ttf = $TTF_STREET;

#  	    my $fontsize = 10;
#  	    $Tk::RotFont::NO_X11 = 1;
#  	    require Tk::RotFont;

#  	    my $ft_method = defined &GD::Image::stringFT ? 'stringFT' : 'stringTTF';

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
#  		my(@b) = GD::Image->$ft_method($black, $ttf, $fontsize, -$_[3],
#  					       &$transpose($_[0], $_[1]),
#  					       $_[2]);
#  		($b[2]-$b[0], $b[3]-$b[1]);
#  	    };

#  	    #my $strecke = $multistr;
#  	    my $strecke = $self->_get_strassen(Strdraw => \%str_draw); # XXX Übergabe von %str_draw notwendig?
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

    $self->{TitleDraw} = $title_draw;

    $self->draw_scale unless $self->{NoScale};
}

sub _add_width {
    my($cl_x, $cl_y, $width) = @_;
    my $delta = $width/2;
    my $res_x = [];
    my $res_y = [];
    for(my $i = 1; $i <= $#$cl_x; $i++) {
	# atan2(y2-y1, x2-x1)
	my $alpha = atan2($cl_y->[$i]-$cl_y->[$i-1],
			  $cl_x->[$i]-$cl_x->[$i-1]);
	my $beta  = $alpha - pi()/2;

	my($dx, $dy);
	($dx, $dy) = (-$delta*cos($beta), -$delta*sin($beta));
	$res_x->[$i]     = $cl_x->[$i] + $dx;
	$res_y->[$i]     = $cl_y->[$i] + $dy;
	if ($i == 1) {
	    $res_x->[0]    = $cl_x->[0] + $dx;
	    $res_y->[0]    = $cl_y->[0] + $dy;
	}

	($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
	$res_x->[@$cl_x*2-$i-1] = $cl_x->[$i] + $dx;
	$res_y->[@$cl_y*2-$i-1] = $cl_y->[$i] + $dy;
	if ($i == 1) {
	    $res_x->[@$cl_x*2-1] = $cl_x->[0] + $dx;
	    $res_y->[@$cl_y*2-1] = $cl_y->[0] + $dy;
	}
    }
    ($res_x, $res_y);
}

sub get_ort_font_mapping {
return; # XXX NYI
    my $self = shift;

    my %ort_font;
    my $ttf = $TTF_CITY;
    if (defined $ttf && defined &GD::Image::stringFT && -r $ttf) {
	my $sc = $self->{FontSizeScale} || 1;
	%ort_font = (0 => [$ttf, 6*$sc],
		     1 => [$ttf, 7*$sc],
		     2 => [$ttf, 8*$sc],
		     3 => [$ttf, 9*$sc],
		     4 => [$ttf, 10*$sc],
		     5 => [$ttf, 11*$sc],
		     6 => [$ttf, 12*$sc],
		     bhf => [$ttf, 7*$sc],
		     strname => [$ttf, 9*$sc],
		    );
    } else {
	%ort_font = (0 => &GD::Font::Tiny,
		     1 => &GD::Font::Small,
		     2 => &GD::Font::Small,
		     3 => &GD::Font::Large, # MediumBold sieht fetter aus
		     4 => &GD::Font::Large,
		     5 => &GD::Font::Giant,
		     6 => &GD::Font::Giant,
		     bhf => &GD::Font::Small,
		     strname => &GD::Font::Small,
		    );
    }
    \%ort_font;
}

# Zeichnen des Maßstabs
sub draw_scale {
    my $self = shift;
return; # XXX not yet
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

    $im->line($self->{Width}-($x1-$x0)-$x_margin,
	      $self->{Height}-$y_margin,
	      $self->{Width}-$x_margin,
	      $self->{Height}-$y_margin,
	      $color);
    $im->line($self->{Width}-($x1-$x0)-$x_margin,
	      $self->{Height}-$y_margin-$bar_width,
	      $self->{Width}-$x_margin,
	      $self->{Height}-$y_margin-$bar_width,
	      $color);
    $im->filledRectangle
	($self->{Width}-($x1-$x0)/2-$x_margin,
	 $self->{Height}-$y_margin-$bar_width,
	 $self->{Width}-$x_margin,
	 $self->{Height}-$y_margin,
	 $color);
    $im->line($self->{Width}-($x1-$x0)/2-$x_margin,
	      $self->{Height}-$y_margin,
	      $self->{Width}-($x1-$x0)/2-$x_margin,
	      $self->{Height}-$y_margin-$bar_width,
	      $color);
    $im->line($self->{Width}-($x1-$x0)-$x_margin,
	      $self->{Height}-$y_margin+2,
	      $self->{Width}-($x1-$x0)-$x_margin,
	      $self->{Height}-$y_margin-$bar_width-2,
	      $color);
    $im->line($self->{Width}-$x_margin,
	      $self->{Height}-$y_margin+2,
	      $self->{Width}-$x_margin,
	      $self->{Height}-$y_margin-$bar_width-2,
	      $color);
    $im->string(&GD::Font::Small,
		$self->{Width}-($x1-$x0)-$x_margin-3,
		$self->{Height}-$y_margin-$bar_width-2-12,
		"0", $color);
    $im->string(&GD::Font::Small,
		$self->{Width}-$x_margin+8-6*length($strecke_label),
		$self->{Height}-$y_margin-$bar_width-2-12,
		$strecke_label, $color);
}

sub draw_route {
    my $self = shift;

    $self->pre_draw if !$self->{PreDrawCalled};

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};
    my @multi_c1 = @{ $self->{MultiC1} };
    my $strnet; # StrassenNetz-Objekt

    foreach (@{$self->{Draw}}) {
	if ($_ eq 'strname' && $self->{'MakeNet'}) {
	    $strnet = $self->{MakeNet}->('lite');
	}
    }

#XXX
#    my $brush; # should be *outside* the next block!!!
#   my $line_style;
#    my $width;
#      if ($self->{RouteDotted}) {
#  	# gepunktete Routen für die WAP-Ausgabe (B/W)
#  	$im->setStyle(($white)x$self->{RouteDotted},
#  		      ($black)x$self->{RouteDotted});
#  	$line_style = GD::gdStyled();
#  #	$width = $width{Route};
#      } elsif ($self->{RouteWidth}) {
#  	# fette Routen für die WAP-Ausgabe (B/W)
#  	$brush = GD::Image->new($self->{RouteWidth}, $self->{RouteWidth});
#  	$brush->colorAllocate($im->rgb($white));
#  	$im->setBrush($brush);
#  	$line_style = GD::gdBrushed();
#      } elsif ($brush{Route}) {
#  	$im->setBrush($brush{Route});
#  	$line_style = GD::gdBrushed();
#      } else {
#  	# Vorschlag von Rainer Scheunemann: die Route in blau zu zeichnen,
#  	# damit Rot-Grün-Blinde sie auch erkennen können. Vielleicht noch
#  	# besser: rot-grün-gestrichelt
#  	$im->setStyle($darkblue, $darkblue, $darkblue, $red, $red, $red);
#  	$line_style = GD::gdStyled();
#  	$width = $width{Route};
#      }
    #my $color = $darkblue; # XXX red/blue?
    my $width = $width{Route};
    require Imager::Fill;
    my $fill = Imager::Fill->new(hatch=> "check4x4", fg=>$darkblue, bg=>$red);

    # Route
    for my $c1 (@multi_c1) {
	my $points_x = [];
	my $points_y = [];
	for(my $i = 0; $i <= $#$c1; $i++) {
	    my($x, $y) = &$transpose(@{$c1->[$i]});
	    push @$points_x, $x;
	    push @$points_y, $y;
	}
	($points_x, $points_y) = _add_width($points_x, $points_y,
					    $width) if $width;
	$im->polygon(x => $points_x, y => $points_y, fill => $fill);
	#XXXcolor => $color);
    }
#      for(my $i = 0; $i < $#c1; $i++) {
#  	my($x1, $y1, $x2, $y2) = (@{$c1[$i]}, @{$c1[$i+1]});
#  	my($tx1,$ty1, $tx2,$ty2) = (&$transpose($x1, $y1),
#  				    &$transpose($x2, $y2));
#  	$im->line($tx1,$ty1, $tx2,$ty2, $line_style);
#  	if (defined $width) {
#  	    my $alpha = atan2($ty2-$ty1, $tx2-$tx1);
#  	    my $beta  = $alpha - pi()/2;
#  	    for my $delta (-int($width/2) .. int($width/2)) {
#  		next if $delta == 0;
#  		my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
#  		$im->line($tx1+$dx,$ty1+$dy,$tx2+$dx,$ty2+$dy,
#  			  $line_style);
#  	    }
#  	}
#      }

    if (0) {

    # Flags
    if (@multi_c1 > 1 || ($multi_c1[0] && @{$multi_c1[0]} > 1)) {
	if ($self->{UseFlags} &&
	    defined &GD::Image::copyMerge &&
	    $self->imagetype ne 'wbmp') {
	    my $images_dir = $self->get_images_dir;
	    my $imgfile;
	    $imgfile = "$images_dir/flag2_bl." . $self->imagetype;
	    if (open(GIF, $imgfile)) {
		binmode GIF;
		my $start_flag = newFromImage GD::Image \*GIF;
		close GIF;
		if ($start_flag) {
		    my($w, $h) = $start_flag->getBounds;
		    my($x, $y) = &$transpose(@{ $multi_c1[0][0] });
		    # workaround: newFromPNG vergisst die Transparency-Information
		    $start_flag->transparent($start_flag->colorClosest(192,192,192));
		    $im->copyMerge($start_flag, $x-5, $y-15,
				   0, 0, $w, $h, 50);
		} else {
		    warn "$imgfile exists, but can't be read by GD";
		}
	    }

	    $imgfile = "$images_dir/flag_ziel." . $self->imagetype;
	    if (open(GIF, $imgfile)) {
		binmode GIF;
		my $end_flag = newFromImage GD::Image \*GIF;
		close GIF;
		if ($end_flag) {
		    my($w, $h) = $end_flag->getBounds;
		    my($x, $y) = &$transpose(@{ $multi_c1[-1][-1] });
		    # workaround: newFromPNG vergisst die Transparency-Information
		    $end_flag->transparent($end_flag->colorClosest(192,192,192));
		    $im->copyMerge($end_flag, $x-5, $y-15,
				   0, 0, $w, $h, 50);
		} else {
		    warn "$imgfile exists, but can't be read by GD";
		}
	    }
	} elsif ($self->{UseFlags} && $self->imagetype eq 'wbmp' &&
		 $self->{RouteWidth}) {
	    my($x, $y) = &$transpose(@{ $multi_c1[0][0] });
	    for my $w ($self->{RouteWidth}+5 .. $self->{RouteWidth}+6) {
		$im->arc($x,$y,$w,$w,0,360,$black);
	    }
	}
    }

    # Ausgabe der Straßennnamen
    if ($strnet) {
	my %ort_font = %{ $self->get_ort_font_mapping };
	my($text_inner, $text_outer);
#  	if ($self->{Bg} eq 'white') {
#  	    ($text_inner, $text_outer) = ($darkblue, $white);
#  	} else {
#  	    ($text_inner, $text_outer) = ($white, $darkblue);
#  	}
	($text_inner, $text_outer) = ($black, $grey_bg);
	my(@strnames) = $strnet->route_to_name
	    ([ map { [split ','] } @{ $self->{Coords} } ]);
	require VectorUtil;
	my @rectangles;
	foreach my $e (@strnames) {
	    my $name = Strassen::strip_bezirk($e->[0]);
	    my $f_i  = $e->[4][0];
	    my($x,$y) = &$transpose(split ',', $self->{Coords}[$f_i]);
	    my @args = ($ort_font{strname}, $x, $y,
			patch_string($name),
			$text_inner, $text_outer
		       );
	    my(@bounds) = $self->check_outline_text(@args);
	    if (!@bounds) {
		$self->outline_text(@args);
	    } else {
	    CHECK_FOR_INTERSECT: {
		    for my $rect (@rectangles) {
			if (VectorUtil::intersect_rectangles(@bounds[0,1,4,5], @$rect)) {
			    last CHECK_FOR_INTERSECT;
			}
		    }
		    $self->outline_text(@args);
		    push @rectangles, [@bounds[0,1,4,5]];
		}
	    }
	}
    }

}

    if (0 && $self->{TitleDraw}) {
	my $start = patch_string($self->{Startname});
	my $ziel  = patch_string($self->{Zielname});
	foreach my $s (\$start, \$ziel) {
	    # Text in Klammern entfernen, damit der Titel kürzer wird
	    my(@s) = split(m|/|, $$s);
	    foreach (@s) {
		s/\s+\(.*\)$//;
	    }
	    $$s = join("/", @s);
	}
	my $s =  "$start -> $ziel";

	my $gdfont;
	if (7*length($s) <= $self->{Width}) {
	    $gdfont = \&GD::Font::MediumBold;
	} elsif (6*length($s) <= $self->{Width}) {
	    $gdfont = \&GD::Font::Small;
	} else {
	    $gdfont = \&GD::Font::Tiny;
	}
#  	my $inner = $white;
#  	my $outer = $darkblue;
#  	if ($self->{Bg} =~ /^white/) {
#  	    ($inner, $outer) = ($outer, $inner);
#  	}
	my($inner, $outer) = ($darkblue, $grey_bg);
	$self->outline_text(&$gdfont, 1, 1, $s, $inner, $outer);
    }
}

sub outline_text {
return; # XXX not yet
    my($self, $gdfont, $x, $y, $s, $inner, $outer, %args) = @_;
    return if $x < 0 || $y < 0 || $x > $self->{Width} || $y > $self->{Height};
    if (ref $gdfont eq 'ARRAY') { # check for ft font spec
	return outline_ft_text(@_);
    }
    # XXX anchor handling missing
    $x += $args{-padx} if defined $args{-padx};
    my $im = $self->{Image};
    for ([-1, 0], [1, 0], [0, 1], [0, -1]) {
	$im->string($gdfont, $x+$_->[0], $y+$_->[1],
		    $s, $outer);
    }
    $im->string($gdfont, $x, $y, $s, $inner);
}

# $fontspec = [$fontname,$ptsize]
sub outline_ft_text {
return; # XXX not yet
    my($self, $fontspec, $x, $y, $s, $inner, $outer, %args) = @_;
    my $im = $self->{Image};
    if ($args{-anchor}) {
	($x, $y) = _adjust_anchor
	    ($x, $y, $args{-anchor}, $args{-padx}||0, $args{-pady}||0,
	     sub {
		 my @bounds = GD::Image->stringFT($inner, @$fontspec, 0, 0, 0, $s);
		 ($bounds[2]-$bounds[0], $bounds[5]-$bounds[3]);
	     }
	    );
    } else {
	$x += $args{-padx} if defined $args{-padx};
    }
    for ([-1, 0], [1, 0], [0, 1], [0, -1]) {
	$im->stringFT($outer, @$fontspec, 0, $x+$_->[0], $y+$_->[1], $s);
    }
    $im->stringFT($inner, @$fontspec, 0, $x, $y, $s);
}

sub check_outline_text {
    if (ref $_[1] eq 'ARRAY') { # check for ft font spec
	return &check_outline_ft_text;
    }
    ();
}

# XXX rough (without outline, no non-true-type support)
# return bounds
sub check_outline_ft_text {
    my($self, $fontspec, $x, $y, $s, $inner, $outer, %args) = @_;
    GD::Image->stringFT($inner, @$fontspec, 0, $x, $y, $s);
}

sub _adjust_anchor {
    my($x, $y, $anchor, $padx, $pady, $get_bounds) = @_;
    my($dx,$dy);
    if ($anchor =~ / ( ^[ns]|[cew]$ ) /x) {
	($dx,$dy) = $get_bounds->();
    }
    if ($anchor =~ /^n/) {
	$y -= ($dy + $pady);
    } elsif ($anchor =~ /^s/) {
	$y += $pady;
    }
#XXX this is not quite right: anchor !~ /e$/ should be -= $dx/2, however,
#all calls to outline_text should specify -anchor => "w" then
    if ($anchor =~ /e$/) {
	$x -= ($dx + $padx);
    } elsif ($anchor =~ /c$/) { # XXX hack, see above
	$x -= $dx/2;
    } else {
	$x += $padx;
    }
    ($x, $y);
}

# Draw this first, otherwise the filling of the circle won't work!
sub draw_wind {
return; # XXX not yet
    my $self = shift;
    return unless $self->{Wind};
    require BBBikeCalc;
    BBBikeCalc::init_wind();
    my $richtung = lc($self->{Wind}{Windrichtung});
    if ($richtung =~ /o$/) { $richtung =~ s/o$/e/; }
    my $staerke  = $self->{Wind}{Windstaerke};
    my $im = $self->{Image};
    my($radx, $rady) = (10, 10);
    my $col = $darkblue;
    $im->arc($self->{Width}-20, 20, $radx, $rady, 0, 360, $col);
    $im->fill($self->{Width}-20, 20, $col);
    if ($staerke > 0) {
	my %senkrecht = # im Uhrzeigersinn
	    ('-1,-1' => [-1,+1],
	     '-1,0'  => [ 0,+1],
	     '-1,1'  => [+1,+1],
	      '0,1'  => [+1, 0],
	      '1,1'  => [+1,-1],
	      '1,0'  => [ 0,-1],
	      '1,-1' => [-1,-1],
	      '0,-1' => [-1, 0],
	    );
	my($ydir, $xdir) = @{$BBBikeCalc::wind_dir{$richtung}};
	if (exists $senkrecht{"$xdir,$ydir"}) {
	    my($x2dir, $y2dir) = @{ $senkrecht{"$xdir,$ydir"} };
	    my($yadd, $xadd) = map { -$_*15 } ($ydir, $xdir);
	    $xadd = -$xadd; # korrigieren
	    $im->line($self->{Width}-20, 20, $self->{Width}-20+$xadd, 20+$yadd,
		      $col);
	    my $this_tic = 15;
	    my $i = $staerke;
	    my $last_is_half = 0;
	    if ($i%2 == 1) {
		$last_is_half++;
		$i--;
	    }
	    while ($i >= 0) {
		my($yadd, $xadd) = map { -$_*$this_tic } ($ydir, $xdir);
		$xadd = -$xadd;
		my $stroke_len;
		if ($i == 0) {
		    if ($last_is_half) {
			# half halbe Strichlänge
			$stroke_len = 3;
		    } else {
			last;
		    }
		} else {
		    # full; volle Strichlänge
		    $stroke_len = 6;
		}
		my($yadd2, $xadd2) = map { -$_*$stroke_len } ($y2dir, $x2dir);
		$xadd2 = -$xadd2;
		$im->line($self->{Width}-20+$xadd, 20+$yadd,
			  $self->{Width}-20+$xadd+$xadd2, 20+$yadd+$yadd2,
			  $col);
		$this_tic -= 3;
		last if $this_tic <= 0;
		$i-=2;
	    }
	}
    }
}

sub make_imagemap {
    require BBBikeDraw::GD;
    return BBBikeDraw::GD::make_imagemap(@_);
#XXX ^^^ OK?
    my $self = shift;
    my $fh = shift || confess "No file handle supplied";
    my(%args) = @_;

    if (!defined $self->{Width} &&
	!defined $self->{Height}) {
	if ($self->{Geometry} =~ /^(\d+)x(\d+)$/) {
	    ($self->{Width}, $self->{Height}) = ($1, $2);
	}
    }

    my $transpose = $self->{Transpose};
    my $multistr = $self->_get_strassen; # XXX Übergabe von %str_draw?

    # keine Javascript-Abfrage, damit der Code generell bleibt und
    # gecachet werden kann...
    if ($args{'-generate_javascript'}) {
	print $fh <<EOF;
<script language=javascript>
<!--
function s(text) {
  self.status=text;
  return true;
}
// -->
</script>
EOF
    }
    print $fh "<map name=\"map\">";

    $multistr->init;
    while(1) {
	my $s = $multistr->next_obj;
	last if $s->is_empty;
	if ($s->category !~ /^F/ && $#{$s->coords} > 0) {
	    my(@polygon1, @polygon2);
	    my($dx, $dy, $c);
	    my($x1, $y1, $x2, $y2);
	    for(my $i = 0; $i < $#{$s->coords}; $i++) {
		($x1, $y1, $x2, $y2) = 
		  (&$transpose(@{$s->coord_as_list($i)}),
		   &$transpose(@{$s->coord_as_list($i+1)}));
		$dx = $x2-$x1;
		$dy = $y2-$y1;
		$c = CORE::sqrt($dx*$dx + $dy*$dy)/2;
		if ($c == 0) { $c = 0.00001; }
		$dx /= $c;
		$dy /= $c;
		push    @polygon1, int($x1-$dy), int($y1+$dx);
		unshift @polygon2, int($x1+$dy), int($y1-$dx);
	    }
	    # letzter Punkt
	    push    @polygon1, int($x2-$dy), int($y2+$dx);
	    unshift @polygon2, int($x2+$dy), int($y2-$dx);

	    # Optimierung: nur die eine Seite des Polygons wird überprüft
	    next unless $self->is_in_map(@polygon1);

	    my $coordstr = join(",", @polygon1, @polygon2,
				$polygon1[0], $polygon1[1]);
	    print $fh
# XXX folgendes: AREA ONMOUSEOVER funktioniert für
# FreeBSD-Netscape
# bei Win-MSIE wird es ignoriert
# und bei WIn-NS wird ein falscher Link erzeugt
# title= wird noch nicht von NS und IE unterstützt (aber vom Galeon)
# evtl. AREA ganz weglassen
# XXX check mit onclick. evtl. onclick so patchen, dass submit mit
# richtigen Werten aufgerufen wird.
#	      "<area title=\"" . $s->name . "\" ",
	      "<area href=\"\" ",
		"shape=poly ",
		"coords=\"$coordstr\" ",
		#XXX "title=\"" . $s->name . "\" ",
		"onmouseover=\"return s('" . $s->name . "')\" ",
	        "onclick=\"return false\" ",
		">\n";
#XXXXXXXXXXXXX
# Geht jetzt auch nicht mehr mit NS4?!
	}
    }

    print $fh "</map>";
}

#XXX del:
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
    my $fh = $args{Fh} || $self->{Fh};
    binmode $fh;
    if (!$fh) {
	$fh = \*STDOUT;
    }

    my $im = $self->{Image};
    if ($ENV{MOD_PERL}) {
	# Workaround --- is this an Imager bug or limitation?
	require File::Temp;
	my($ofh, $ofilename) = File::Temp::tempfile(UNLINK => 1);
	$im->write(file => $ofilename,
		   type => $self->imagetype)
	    or die "Cannot write to temporary file $ofilename: ", $im->errstr;
	open(INFH, $ofilename) or die "Can't read from $ofilename: $!";
	local $/ = \4096;
	while(<INFH>) {
	    print $fh $_;
	}
	close INFH;
	unlink $ofilename;
    } else {
	$im->write(fh => $fh,
		   type => $self->imagetype)
	    or die "Cannot write to filehandle with format ", $self->imagetype, ": ", $im->errstr;
    }
}

sub empty_image_error {
return; # XXX not yet
    my $self = shift;
    my $im = $self->{Image};
    my $fh = $self->{Fh};

    $im->string(GD->gdLargeFont, 10, 10, "Empty image!", $white);
    binmode $fh if $fh;
    if ($fh) {
	print $fh $im->imageOut;
    } else {
	print $im->imageOut;
    }
    confess "Empty image";
}

1;
