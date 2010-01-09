# -*- perl -*-

#
# $Id: SVG.pm,v 1.25 2009/01/11 23:35:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package BBBikeDraw::SVG;
use strict;
use base qw(BBBikeDraw);
use SVG;
use Strassen;
# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);

use vars qw($VERSION @colors %color %style %width %outline_color $sansserif);
BEGIN { @colors =
         qw($grey_bg $white $yellow $lightyellow $red $green $middlegreen $darkgreen
	    $darkblue $lightblue $rose $black $darkgrey $lightgreen);
}
use vars @colors;

$VERSION = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);

sub init {
    my $self = shift;

    my($w, $h) = (640, 480);
    my $geometry = $self->{Geometry};
    if (defined $geometry && $geometry =~ /^(\d+)x(\d+)$/) { # no support for "auto"
	($w, $h) = ($1, $2);
    }

    my $svg = SVG->new(width => $w, height => $h);

    $self->{Image}    = $svg; # named "Image" for GD compatibility
    $self->{Width}    = $w;
    $self->{Height}   = $h;

    if (!defined $self->{Outline}) {
	$self->{Outline} = 1;
    }

    $self->allocate_colors_and_fonts;
    $self->set_category_colors;
    $self->set_category_styles;
#      $self->set_category_outline_colors;
#      $self->set_category_widths;

#      # grey background
#      $page->rectangle(@$page_bbox);
#      $page->set_fill_color(@$grey_bg);
#      $page->fill;

    $self->set_draw_elements;

    $self;
}

sub allocate_colors_and_fonts {
    my $self = shift;
    $self->allocate_colors;
    $self->allocate_fonts;
}

sub allocate_colors {
    my $self = shift;
    my $im = $self->{Image};

    $self->{'Bg'} = '' if !defined $self->{'Bg'};
    if ($self->{'Bg'} eq '' || $self->{'Bg'} =~ /^white/) {
	# Hintergrund weiß: Nebenstraßen werden grau,
	# Hauptstraßen dunkelgelb gezeichnet
	$grey_bg   = [0.9,0.9,0.9];
	$white     = [1,1,1];
    } elsif ($self->{'Bg'} =~ /^\#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})/i) {
	$grey_bg   = [hex($1)/255, hex($2)/255, hex($3)/255];
    } else {
	$grey_bg   = [0.6,0.6,0.6];
    }

    $white       = [1,1,1] if !defined $white;
    $yellow      = [1,1,0] if !defined $yellow;
    $red         = [1,0,0];
    $green       = [0,1,0];
    $darkgreen   = [0,0.5,0];
    $darkblue    = [0,0,0.5];
    $lightblue   = [0.73,0.84,0.97];
    $middlegreen = [0,0.78,0];
    $lightgreen  = [200/256,1,200/256];
    $rose        = [map { $_/256} 215, 184, 200];
    $black       = [0,0,0];
}

sub cat2svgrgb {
    my($cat) = @_;
    my $color = $color{$cat};
    if (!defined $color) {
	warn "No color for category <$cat> found\n";
	return undef;
    }
    "rgb(" . join(",", map { int($_*255) } @$color) . ")";
}

sub set_category_styles {
    my($self) = @_;
    %style = ();
    for my $cat (qw(B HH H NH N NN
		    S SA SB SC S0 SBau
		    R RA RB RC R0 RBau RG RP
		    U UA UB    U0 UBau
		    W W0 W1 W2
		    F:W F:W1 F:W2
		    F:Ae F:ex-Ae F:P F:Pabove F:Forest F:Forestabove
		    F:Cemetery F:Green F:Orchard F:Sport F:Industrial F:Mine
		    Z Route
		   )) {
	if ($cat =~ m{^F:(.*)}) {
	    my $plain_cat = $1;
	    $style{$cat} = {'fill' => cat2svgrgb($plain_cat) };
	} else {
	    $style{$cat} = {'stroke' => cat2svgrgb($cat) };
	}
    }
    for my $cat (qw(W0)) {
	$style{$cat}->{'stroke-width'} = 1;
    }
    for my $cat (qw(B HH H W1)) {
	$style{$cat}->{'stroke-width'} = 2;
    }
    for my $cat (qw(W2)) {
	$style{$cat}->{'stroke-width'} = 3;
    }

    $style{"U-Bhf"} = {'fill' => cat2svgrgb("U") };
    $style{"S-Bhf"} = {'fill' => cat2svgrgb("S") };
}

sub allocate_fonts {
    my $self = shift;
    my $im = $self->{Image};

#XXX???
#    $sansserif = $self->{PDF}->font('Subtype'  => 'Type1',
#				    'Encoding' => 'WinAnsiEncoding',
#				    'BaseFont' => 'Helvetica');
}


sub draw_map {
    my $self = shift;
    my(%args) = @_;

    my $draw = $args{-draw} || $self->{Draw};

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    # XXX use _get_nets
    # Netze zeichnen
    my @netz;
    my @outline_netz;
    my(%str_draw, $title_draw, %p_draw);

    foreach (@$draw) {
	if ($_ eq 'title' &&
	    defined $self->{Startname} && $self->{Startname} ne '' &&
	    defined $self->{Zielname}  && $self->{Zielname}  ne '') {
	    $title_draw = 1;
	} elsif ($_ eq 'ampel') {
	    $p_draw{$_} = 1;
	} elsif ($_ eq 'strname') {
	    # NOP, done in draw_route
	} else {
	    $str_draw{$_} = 1;
	}
    }
    # Reihenfolge (von unten nach oben):
    # Berlin-Grenze, Gewässer, Straßen, U-, S-Bahn
    foreach (
	     ['berlin',           'berlin'],
	     ['flaechen',         'flaechen'],
	    ) {
	push @netz, new Strassen $_->[0] if $str_draw{$_->[1]}
    }
    if ($str_draw{'wasser'}) {
	my $wasser = $self->_get_gewaesser(Strdraw => \%str_draw);
	push @netz, $wasser;
#XXX not yet: erst einmal muss das Zeichnen der outlines auch F: verstehen
#	push @outline_netz, $wasser;
    }

    my $multistr = $self->_get_strassen(Strdraw => \%str_draw);
    if ($str_draw{'str'}) {
	push @netz, $multistr;
	push @outline_netz, $multistr;
    }

    foreach (
	     ['ubahn',           'ubahn'],
	     ['sbahn',           'sbahn'],
	     ['rbahn',           'rbahn'],
	    ) {
	push @netz, new Strassen $_->[0] if $str_draw{$_->[1]}
    }

    if ($str_draw{'Route'}) {
	if (@{ $self->{MultiCoords} || [] }) {
	    push @netz, Strassen->new_from_data
		(map { "Route\tRoute " . join(" ", @$_) . "\n" } @{ $self->{MultiCoords} });
	} else {
	    push @netz, Strassen->new_from_data
		("Route\tRoute " . join(" ", @{$self->{Coords}}));
	}
    }

    my $restrict;
    if ($self->{Restrict}) {
	$restrict = { map { ($_ => 1) } @{ $self->{Restrict} } };
    }

    if ($self->{Outline}) {
	foreach my $strecke (@outline_netz) {
	    my $g = $im->group(style=>{
				       'stroke'=>'black',
				       'stroke-width'=>'2',
				       'fill'=>'none',
				      });
	    $strecke->init;
	    while(1) {
		my $s = $strecke->next;
		last if !@{$s->[1]};
		my $cat = $s->[2];
		$cat =~ s{::.*}{};
		next if $restrict && !$restrict->{$cat};

		my @p = map { [map { sprintf "%.2f", $_ } &$transpose(split /,/, $_)] } @{$s->[Strassen::COORDS]};
		next if (@p == 1); # at least ImageMagick cannot handle one-point polylines
		my $xv = [ map { $_->[0] } @p ];
		my $yv = [ map { $_->[1] } @p ];
		my $points = $im->get_path
		    (x => $xv, y => $yv,
		     -type => 'polyline', -closed => 'false');
		my $style = $style{$cat};
		$g->polyline(%$points,
			     (defined $style && defined $style->{'stroke-width'} ? ("stroke-width" => $style->{'stroke-width'}+1) : ()),
			    );

#  		my($ss, $bbox) = transpose_all($s->[1], $transpose);
#  		next if (!bbox_in_region($bbox, $self->{PageBBox}));

#  		$im->set_line_width(($width{$cat}||1)*1+2);
#  		$im->set_stroke_color(@{ $outline_color{$cat} || [0,0,0] });

#  		$im->moveto(@{ $ss->[0] });
#  		for my $xy (@{$ss}[1 .. $#$ss]) {
#  		    $im->lineto(@$xy);
#  		}
#  		$im->stroke;
	    }
	}
    }

    foreach my $strecke (@netz) {
	my $g = $im->group(style=>{
				   'stroke'=>'white',
				   'stroke-width'=>'1',
				   'fill'=>'none',
				  });
	$strecke->init;
	while(1) {
	    my $s = $strecke->next;
	    last if !@{$s->[1]};
	    my $cat = $s->[2];

#  	    my($ss, $bbox) = transpose_all($s->[1], $transpose);
#  	    next if (!bbox_in_region($bbox, $self->{PageBBox}));

	    # move to first point
#	    $im->moveto(@{ $ss->[0] });

	    next if $restrict && !$restrict->{$cat};

	    my @p = map { [map { sprintf "%.2f", $_ } &$transpose(split /,/, $_)] } @{$s->[Strassen::COORDS]};
	    next if (@p == 1); # at least ImageMagick cannot handle one-point polylines
	    my $xv = [ map { $_->[0] } @p ];
	    my $yv = [ map { $_->[1] } @p ];

	    if ($cat =~ /^F:(.*)/) {
		my $subcat = $1;
		my $style = $style{$cat};
		if (!defined $style) { $style = $style{$subcat} }
#  		$im->set_line_width(1);
#  		$im->set_stroke_color(@{ $color{$1} || [0,0,0] });
#  		$im->set_fill_color  (@{ $color{$1} || [0,0,0] });
#  		for my $xy (@{$ss}[1 .. $#$ss]) {
#  		    $im->lineto(@$xy);
#  		}
#  		$im->fill;

		my $points = $im->get_path
		    (x => $xv, y => $yv,
		     -type => 'polygon',
		    );
		$g->polygon(%$points,
			    (defined $style ? (style => $style) : ()),
			   );

	    } elsif ($cat !~ $BBBikeDraw::bahn_bau_rx) { # Ausnahmen: in Bau
		$cat =~ s{::.*}{};
		my $style = $style{$cat};

#  		$im->set_line_width(($width{$cat} || 1) * 1);
#  		$im->set_stroke_color(@{ $color{$cat} || [0,0,0] });
#  		for my $xy (@{$ss}[1 .. $#$ss]) {
#  		    $im->lineto(@$xy);
#  		}
#  		$im->stroke;
		if (1) {
		    my $points = $im->get_path
			(x => $xv, y => $yv,
			 -type => 'polyline', -closed => 'false',
			);
		    #my $style = $style{$cat};
		    $g->polyline(%$points,
				 (defined $style ? (style => $style) : ()),
				);
		} else {
		    for my $i (0 .. $#{$s->[Strassen::COORDS]}-1) {
			my($x1,$y1) = map { int } &$transpose(split /,/, $s->[Strassen::COORDS][$i]);
			my($x2,$y2) = map { int } &$transpose(split /,/, $s->[Strassen::COORDS][$i+1]);
			$g->line(x1 => $x1, y1 => $y1,
				 x2 => $x2, y2 => $y2,
				);
		    }
		}
	    }
	}
    }

#      # $self->{Xk} bezeichnet den Vergrößerungsfaktor
#      # bis etwa 0.02 ist es zu unübersichtlich, Ampeln zu zeichnen,
#      # ab etwa 0.05 kann man die mittelgroße Variante nehmen
#      if ($p_draw{'ampel'} && $self->{Xk} >= 0.02) {
#  	my $lsa = new Strassen "ampeln";
#  	my $images_dir = $self->get_images_dir;
#  	my $suf = ($self->{Xk} >= 0.05 ? '' : '2');

#  	my($kl_ampel);
#  	my($kl_andreas);

#          eval {
#  	$kl_ampel = $self->{PDF}->image("$images_dir/ampel_klein$suf.jpg");
#  	$kl_andreas = $self->{PDF}->image("$images_dir/andreaskr_klein$suf.jpg");
#  	}; warn $@ if $@;
#  	warn "weiter...";
#  	if ($kl_andreas && $kl_ampel) {
#  	    $lsa->init;
#  	    while(1) {
#  		my $s = $lsa->next_obj;
#  		last if $s->is_empty;
#  		my $cat = $s->category;
#  		my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  		if ($cat eq 'B') {
#  		    $im->image(image => $kl_andreas, xpos => $x, ypos => $y,
#  			       xalign => 1, yalign => 1);
#  		} else {
#  		    $im->image(image => $kl_ampel, xpos => $x, ypos => $y,
#  			       xalign => 1, yalign => 1);
#  		}
#  	    }
#  	}
#      }

# XXX verschiedene Zeichensatzgrößen für die Orte
#      my $min_ort_category = ($self->{Xk} < 0.005 ? 4
#  			    : ($self->{Xk} < 0.01 ? 3
#  			       : ($self->{Xk} < 0.02 ? 2
#  				  : ($self->{Xk} < 0.03 ? 1 : 0))));
#      my %ort_font = (0 => &GD::Font::Tiny,
#  		    1 => &GD::Font::Small,
#  		    2 => &GD::Font::Small,
#  		    3 => &GD::Font::Large, # MediumBold sieht fetter aus
#  		    4 => &GD::Font::Large,
#  		    5 => &GD::Font::Giant,
#  		    6 => &GD::Font::Giant,
#  		   );
    if (1) {
    foreach my $points (['ubahn', 'ubahnhof', 'u'],
  			['sbahn', 'sbahnhof', 's'],
#  			['ort', 'orte',       'o'],
  		       ) {
  	if ($str_draw{$points->[0]}) {
  	    my $p = ($points->[0] eq 'ort'
  		     ? $self->_get_orte
  		     : new Strassen $points->[1]);
  	    my $type = $points->[2];
	    if (0 && $type eq 's') { # XXX Symbols are not supported very well by either ImageMagick or Mozilla
		# Taken from
		# http://upload.wikimedia.org/wikipedia/commons/e/e7/S-Bahn-Logo.svg
		my $s_symbol = $im->symbol(id => 'SBhf',
					   width => 500, height => 500);
		$s_symbol->circle(cx=>250,cy=>250,r=>250,style=>{fill=>"#093",stroke=>"none"});
		my $points = $s_symbol->get_path(x => [qw(100   102   106.6 111.7 122.9 147.4 159.8 172.6 190.8 209.4 228.3 247.3 263.7 279.9 296.1 311.8 329.4 346   361.3 368.3 374.8 382.6 389.4 395.1 399.5 402.7 404.3 404.4 402.8 399.8 394.7 388   379.9 370.7 360.5 349.7 338.8 327.9 316.9 294.4 270.2 257.3 243.8 232   220.2 209   199   190.6 184.5 182.5 181.3 180.8 181.3 182.1 183.9 186.8 190.4 194.7 199.6 210.2 219.3 228.6 238.1 247.6 257.1 266.5 284.9 302.9 319.7 335.6 351   378.9 379.4 372.8 356.5 339.1 320.6 301.2 287.7 273.9 260.1 246.1 232.2 218.4 204.8 191.4 180.7 170.3 160.4 150.9 142   133.8 126.4 119.8 114.3 109.7 105.9 103.1 101.3 100.7 101.2 103.1 105.6 109.1 113.8 119.2 125.4 132.3 147.2 164.9 174.2 183.8 193.9 204.2 215.1 226.5 249.9 261.5 272.7 283.2 292.5 300.5 306.8 309.6 311.8 313.5 314.5 314.8 313.9 312.3 309.7 306.1 301.5 296.2 290.3 284.1 271.2 258.4 245.7 233.2 220.9 205.7 190.7 176.3 162.5 150.2 138.5 127.3 116.8 100   100     )],
						 "y" => [qw(380.5    383        387.4    391.2    398.3    411.7    417.8    423.1    429.3    434      437      438      437.6    435.7    432.4    427.7    421.1  412.6      401.8    395.5    388.6    379.5    369.4    358.7    347.7    336.2    324.5    312.8    301.2    288.7    276.6  265.4      254.8    245.1    236.7    229.4    223.5    218.5    214.7    209      203.6    200.1    195.6  191.1      185.6  179.2    172.1      164.3    155.7    151.3    146.7    142      137.1    131.7    126.1    120.7    115.5    110.7    106.4    99.6     95.6     93.3     92.5     93       94.6     97.1     103.6    111.2    119.7    129    139.2      160      102.6    97.5     86.2     76.8     69.1     63       59.3     56.5     54.4     53.3     53.3     54.4     56.8     60.4     64.1     68.7     74.2     80.4   87.6       95.5     104.2    113.8    122.8    132.4    142.2    152.3    162.5    172.8    183.1    193      202.5    211.5    220.1    228.4    236.2    243.5    256.5    269.2    274.5    279.1    282.8    286      288.4    290.1    292.8    294.2    296.2    299.2    303.6    309.8    318      322.3    327      332.1    337.3    348.1    353.2    358.1    363.9    369.1    373.8    377.7    381.2    384      388.1    390.9    392      391.4    389.6    386.2    381      374.4    366.3    358.1    349      339.1    328.7  311.9    380.5       )],
						 -type => "path",
						 -closed => "true",
						);
		$s_symbol->path(
				%$points,
				style => {
					  'fill'   => 'white',
					  'stroke' => 'none'
					 },
			       );
	    }

  	    $p->init;
  	    while(1) {
  		my $s = $p->next_obj;
  		last if $s->is_empty;
  		my $cat = $s->category;
  		next if $cat =~ $BBBikeDraw::bahn_bau_rx;
  		my($x0,$y0) = @{$s->coord_as_list(0)};
  		# Bereichscheck (XXX ist nicht ganz korrekt wenn der Screen breiter ist als die Route)
#  		next if (!(($x0 >= $self->{Min_x} and $x0 <= $self->{Max_x})
#  			   and
#  			   ($y0 >= $self->{Min_y} and $y0 <= $self->{Max_y})));
  		if ($type eq 'u') {
		    my($xtt, $ytt) = &$transpose($x0-8, $y0-8);
		    my($x1t, $y1t) = &$transpose($x0-10, $y0-10);
		    my($x2t, $y2t) = &$transpose($x0+10, $y0+10);
		    my $fontsize = sprintf "%.1f", Strassen::Util::strecke([$x1t,$y1t],[$x2t,$y2t])*0.6;
		    my $points = $im->get_path('x' => [$x1t, $x2t, $x2t, $x1t],
					       'y' => [$y1t, $y1t, $y2t, $y2t],
					       -type => 'polygon',
					      );
		    $im->polygon(%$points, ($style{'U-Bhf'} ? (style => $style{"U-Bhf"}) : ()));
		    $im->text("x"=>$xtt, "y"=>$ytt, -cdata => 'U',
			      style => {'font-size' => $fontsize, 'font' => 'sans', fill => 'white'});
		} elsif ($type eq 's') {
		    my($x0,$y0) = @{$s->coord_as_list(0)};
 		    my($xct, $yct) = &$transpose($x0, $y0);
		    if (1) {
			my($x2t, $y2t) = &$transpose($x0+12, $y0+0);
			my($xtt, $ytt) = &$transpose($x0-7, $y0-7);
			my $radius = sprintf "%.1f", Strassen::Util::strecke([$xct,$yct],[$x2t,$y2t]);
			my $fontsize = $radius*1.3;
			$im->circle("cx" => $xct, "cy" => $yct, "r" => $radius,
				    ($style{'S-Bhf'} ? (style => $style{"S-Bhf"}) : ()));
			$im->text("x"=>$xtt, "y"=>$ytt, -cdata => 'S',
				  style => {'font-size' => $fontsize, 'font' => 'sans', fill => 'white'});
		    } else {
			$im->use(-href => "#SBhf", x=>$xct,"y"=>$yct,width=>10,height=>10,transform=>'scale(0.02)'); #XXXX
		    }
		}
#  		} else {
#  		    if ($cat >= $min_ort_category) {
#  			my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
#  			my $ort = $s->name;
#  			# Anhängsel löschen (z.B. "b. Berlin")
#  			$ort =~ s/\|.*$//;
#  			$im->arc($x, $y, 3, 3, 0, 360, $black);
#  			outline_text($im, $ort_font{$cat} || &GD::Font::Small,
#  				     $x+4, $y,
#  				     patch_string($ort), $white, $darkblue);
#  		    }
#  		}
  	    }
  	}
    }
}
#XXX Straßenbeschriftung
#      if (ref $self->{StrLabel} &&
#  	(defined &GD::Image::stringFT || defined &GD::Image::stringTTF)) {
#  	eval {
#  	    # XXX allgemeiner machen
#  	    #my $ttf = '/usr/X11R6/share/enlightenment/E-docs/aircut3.ttf';
#  	    my $ttf = '/usr/X11R6/share/enlightenment/E-docs//benjamingothic.ttf';
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
#  		$im->$ft_method($black, $ttf, $fontsize, -$_[3], $x, $y, $_[2]);
#  	    };
#  	    my $extent_sub = sub {
#  		my(@b) = GD::Image->$ft_method($black, $ttf, $fontsize, -$_[3],
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

    $self->{TitleDraw} = $title_draw;

    $self->draw_scale unless $self->{NoScale};
}

# Zeichnen des Maßstabs
sub draw_scale {
#      my $self = shift;
#      my $im        = $self->{Image};
#      my $transpose = $self->{Transpose};

#      my $x_margin = 10;
#      my $y_margin = 10;
#      my $color = $black;
#      my $bar_width = 4;
#      my($x0,$y0) = $transpose->(0,0);
#      my($x1,$y1, $strecke, $strecke_label);
#      for $strecke (1000, 5000, 10000, 20000, 50000, 100000) {
#  	($x1,$y1) = $transpose->($strecke,0);
#  	if ($x1-$x0 > 30) {
#  	    $strecke_label = $strecke/1000 . "km";
#  	    last;
#  	}
#      }

#      $im->set_stroke_color(@$color);
#      $im->set_line_width(1);

#      $im->set_fill_color(@$white);
#      $im->rectangle($self->{Width}-($x1-$x0)-$x_margin,
#  		   $y_margin,
#  		   ($x1-$x0)/2,
#  		   $bar_width);
#      $im->fill;

#      $im->set_fill_color(@$color);
#      $im->rectangle($self->{Width}-($x1-$x0)/2-$x_margin,
#  		   $y_margin,
#  		   ($x1-$x0)/2,
#  		   $bar_width);
#      $im->fill;

#      $im->line($self->{Width}-($x1-$x0)-$x_margin,
#  	      $y_margin,
#  	      $self->{Width}-$x_margin,
#  	      $y_margin);

#      $im->line($self->{Width}-($x1-$x0)-$x_margin,
#  	      $y_margin+$bar_width,
#  	      $self->{Width}-$x_margin,
#  	      $y_margin+$bar_width);

#      $im->line($self->{Width}-($x1-$x0)/2-$x_margin,
#  	      $y_margin,
#  	      $self->{Width}-($x1-$x0)/2-$x_margin,
#  	      $y_margin+$bar_width);
#      $im->line($self->{Width}-($x1-$x0)-$x_margin,
#  	      $y_margin-2,
#  	      $self->{Width}-($x1-$x0)-$x_margin,
#  	      $y_margin+$bar_width+2);
#      $im->line($self->{Width}-$x_margin,
#  	      $y_margin-2,
#  	      $self->{Width}-$x_margin,
#  	      $y_margin+$bar_width+2);

#      $im->string($sansserif, 10,
#  		$self->{Width}-($x1-$x0)-$x_margin-3,
#  		$y_margin+$bar_width+4,
#  		"0");
#      $im->string($sansserif, 10,
#  		$self->{Width}-$x_margin+8-6*length($strecke_label),
#  		$y_margin+$bar_width+4,
#  		$strecke_label);
}

# XXX fast shot
sub draw_route {
    my $self = shift;
    $self->draw_map(-draw => ['Route']);
}
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

#  ##XXX gestrichelte Route
#  #      my $brush; # should be *outside* the next block!!!
#  #      my $line_style;
#  #      if ($self->{RouteWidth}) {
#  #  	# fette Routen für die WAP-Ausgabe (B/W)
#  #  	$brush = GD::Image->new($self->{RouteWidth}, $self->{RouteWidth});
#  #  	$brush->colorAllocate($im->rgb($black));
#  #  	$im->setBrush($brush);
#  #  	$line_style = GD::gdBrushed();
#  #      } elsif ($brush{Route}) {
#  #  	$im->setBrush($brush{Route});
#  #  	$line_style = GD::gdBrushed();
#  #      } else {
#  #  	# Vorschlag von Rainer Scheunemann: die Route in blau zu zeichnen,
#  #  	# damit Rot-Grün-Blinde sie auch erkennen können. Vielleicht noch
#  #  	# besser: rot-grün-gestrichelt
#  #  	$im->setStyle($darkblue, $darkblue, $darkblue, $red, $red, $red);
#  #  	$line_style = GD::gdStyled();
#  #      }

#      $im->set_stroke_color(@$red);
#      $im->set_line_width(4);

#      # Route
#      if (@c1) {
#  	$im->moveto(map { sprintf "%.2f", $_ } $transpose->(@{ $c1[0] }));
#  	for(my $i = 1; $i <= $#c1; $i++) {
#  	    $im->lineto(map { sprintf "%.2f", $_ } $transpose->(@{ $c1[$i] }));
#  	}
#  	$im->stroke;
#      }

#      # Flags
#      if (@c1 > 1) {
#  $self->{UseFlags} = 0; # XXX don't use this because of missing transparency information in .jpg
#  	if ($self->{UseFlags}) {
#  	    my $images_dir = $self->get_images_dir;
#  	    my $start_flag = $self->{PDF}->image("$images_dir/flag2_bl.jpg");
#  	    if ($start_flag) {
#  		my($x, $y) = &$transpose(@{ $c1[0] });
#  		$im->image(image => $start_flag, xpos => $x-5, ypos => $y-15,
#  			   xalign => 1, yalign => 1);
#  	    }
#  	    my $end_flag = $self->{PDF}->image("$images_dir/flag_ziel.jpg");
#  	    if ($end_flag) {
#  		my($x, $y) = &$transpose(@{ $c1[-1] });
#  		$im->image(image => $end_flag, xpos => $x-5, ypos => $y-15,
#  			   xalign => 1, yalign => 1);
#  	    }
#  	}
#      }

#      # Ausgabe der Straßennnamen
#      if ($strnet) {
#  	$im->set_stroke_color(@$black);
#  	$im->set_line_width(1);
#  	my(@strnames) = $strnet->route_to_name
#  	    ([ map { [split ','] } @{ $self->{Coords} } ]);
#  	my $size = 10;
#  	foreach my $e (@strnames) {
#  	    my $name = Strassen::strip_bezirk($e->[0]);
#  	    my $f_i  = $e->[4][0];
#  	    my($x,$y) = &$transpose(split ',', $self->{Coords}[$f_i]);
#  	    my $s_width = $im->string_width($sansserif, $name) * $size;
#  	    $im->set_fill_color(@$white);
#  	    $im->rectangle($x-2, $y-2, $s_width+4, $size+2);
#  	    $im->fill;
#  	    $im->rectangle($x-2, $y-2, $s_width+4, $size+2);
#  	    $im->stroke;
#  	    $im->set_fill_color(@$black);
#  	    $im->string($sansserif, $size, $x, $y, $name);
#  	}
#      }

#      if ($self->{TitleDraw}) {
#  	my $start = $self->{Startname};
#  	my $ziel  = $self->{Zielname};
#  	foreach my $s (\$start, \$ziel) {
#  	    # Text in Klammern entfernen, damit der Titel kürzer wird
#  	    my(@s) = split(m|/|, $$s);
#  	    foreach (@s) {
#  		s/\s+\(.*\)$//;
#  	    }
#  	    $$s = join("/", @s);
#  	}
#  	my $s =  "$start -> $ziel";

#  	my $size = 20;
#  	my $s_width = $im->string_width($sansserif, $s) * $size;

#  	$im->set_stroke_color(@$black);
#  	$im->set_fill_color(@$white);
#  	$im->set_line_width(1);
#  	$im->rectangle(15, 795, $s_width+5+5, $size+5);
#  	$im->fill;
#  	$im->rectangle(15, 795, $s_width+5+5, $size+5);
#  	$im->stroke;

#  	$im->set_stroke_color(@$black);
#  	$im->set_fill_color(@$black);
#  	$im->string($sansserif, $size, 20, 800, $s);
#      }

#  }

# Draw this first, otherwise the filling of the circle won't work!
sub draw_wind {
#      return; # not yet XXXX
#      my $self = shift;
#      return unless $self->{Wind};
#      require BBBikeCalc;
#      BBBikeCalc::init_wind();
#      my $richtung = lc($self->{Wind}{Windrichtung});
#      if ($richtung =~ /o$/) { $richtung =~ s/o$/e/; }
#      my $staerke  = $self->{Wind}{Windstaerke};
#      my $im = $self->{Image};
#      my($rad) = 10;
#      my $col = $darkblue;
#      $im->set_stroke_color(@$col);
#      $im->set_fill_color(@$col);
#      $im->circle($self->{Width}-20, 20, $rad);
#      $im->fill;
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
#  	    $im->line($self->{Width}-20, 20, $self->{Width}-20+$xadd, 20+$yadd);
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
#  			  $self->{Width}-20+$xadd+$xadd2, 20+$yadd+$yadd2);
#  		$this_tic -= 3;
#  		last if $this_tic <= 0;
#  		$i-=2;
#  	    }
#  	}
#      }
}

sub flush {
    my $self = shift;
    my %args = @_;
    my $fh = $args{Fh} || $self->{Fh};
    my $im = $self->{Image};
    if ($fh == \*STDOUT) { # This is to help CGI::Compress:Gzip
	print $im->xmlify;
    } else {
	print $fh $im->xmlify;
    }
#      my %args = @_;
#      if (!defined $self->{Filename}) {
#  	my $fh = $args{Fh} || $self->{Fh};
#  	binmode $fh;
#      }
#      $self->{PDF}->close;
}

# use Return => "string" in the constructor for this method
sub string {
#      my($self, %args) = @_;
#      $self->flush(%args);
#      if (defined $self->{Filename}) {
#  	open(F, $self->{Filename}) or die "Can't open $self->{Filename}: $!";
#  	local $/ = undef;
#  	my $buf = scalar <F>;
#  	close F;
#  	$buf;
#      } else {
#  	$ {$self->{Fh}->string_ref };
#      }
}

sub empty_image_error {
#      my $self = shift;
#      my $im = $self->{Image};
#      my $fh = $self->{Fh};

#      $im->stringc($sansserif, 24, 300, 400, "Empty image!");
#      $self->{PDF}->close;
    confess "Empty image";
}

# return transposed and pdf'ied "strecke" and the bbox
sub transpose_all {
    my($s, $transpose) = @_;
    # first:
    my($tx,$ty) = map { sprintf "%.2f", $_ }
	              $transpose->(@{ Strassen::to_koord1($s->[0]) });

    my $res = [[$tx, $ty]];
    my $bbox = [$tx,$ty,$tx,$ty];

    foreach my $xy (@{$s}[1 .. $#$s]) {
	my($tx,$ty) = map { sprintf "%.2f", $_ }
	                  $transpose->(@{ Strassen::to_koord1($xy) });
	push @$res, [ $tx, $ty ];

	$bbox->[0] = $tx if ($tx < $bbox->[0]);
	$bbox->[2] = $tx if ($tx > $bbox->[2]);
	$bbox->[1] = $ty if ($ty < $bbox->[1]);
	$bbox->[3] = $ty if ($ty > $bbox->[3]);
    }

    ($res, $bbox);
}

# return true if the union is not empty
#  sub bbox_in_region {
#      my($bbox, $region) = @_;
#      return 0 if ($bbox->[0] > $region->[2] ||
#  		 $bbox->[1] > $region->[3] ||
#  		 $bbox->[2] < $region->[0] ||
#  		 $bbox->[3] < $region->[1]);
#      1;
#  }

#  # Additional PDF::Create methods

#  package PDF::Create::Page;

#  use constant PI => 3.141592653;

#  sub set_stroke_color {
#      my($page, $r, $g, $b) = @_;
#      return if (defined $page->{'current_stroke_color'} &&
#  	       $page->{'current_stroke_color'} eq join(",", $r, $g, $b));
#      $page->{'pdf'}->page_stream($page);
#      $page->{'pdf'}->add("$r $g $b RG");
#      $page->{'current_stroke_color'} = join(",", $r, $g, $b);
#  }

#  sub set_fill_color {
#      my($page, $r, $g, $b) = @_;
#      return if (defined $page->{'current_fill_color'} &&
#  	       $page->{'current_fill_color'} eq join(",", $r, $g, $b));
#      $page->{'pdf'}->page_stream($page);
#      $page->{'pdf'}->add("$r $g $b rg");
#      $page->{'current_fill_color'} = join(",", $r, $g, $b);
#  }

#  sub set_line_width {
#      my($page, $w) = @_;
#      return if (defined $page->{'current_line_width'} &&
#  	       $page->{'current_line_width'} == $w);
#      $page->{'pdf'}->page_stream($page);
#      $page->{'pdf'}->add("$w w");
#      $page->{'current_line_width'} = $w;
#  }

#  sub circle {
#      my($page, $x, $y, $r) = @_;

#      my @coords;
#      for(my $i = 0; $i < PI*2; $i+=PI*2/$r/2) {
#  	my($xi,$yi) = map { $_*$r } (sin $i, cos $i);
#  	push @coords, $x+$xi, $y+$yi;
#      }
#      push @coords, @coords[0,1];
#      @coords = map { sprintf "%.2f", $_ } @coords;

#      $page->moveto(shift @coords, shift @coords);
#      for(my $i = 0; $i <= $#coords; $i+=2) {
#  	$page->lineto($coords[$i], $coords[$i+1]);
#      }
#  }

1;
