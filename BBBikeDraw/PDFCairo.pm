# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeDraw::PDFCairo;
use strict;
use base qw(BBBikeDraw);
use Cairo;
use Strassen;
# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);
use BBBikeUtil qw(pi);

use vars qw($VERSION @colors %color %width %outline_color $VERBOSE $DO_COMPRESS);
BEGIN { @colors =
         qw($grey_bg $white $yellow $lightyellow $red $green $middlegreen $darkgreen
	    $darkblue $lightblue $rose $black $darkgrey $lightgreen);
}
use vars @colors;

$VERSION = 0.02;

# XXX hmmm, also defined in Route::PDF::Cairo...
use constant DIN_A4_WIDTH => 595;
use constant DIN_A4_HEIGHT => 842;

# XXX Maybe move definitions? to BBBikeDraw.pm
my %line_dash = (Tu => [4,5]);

sub init {
    my $self = shift;

    if ($DO_COMPRESS) {
	require BBBikeDraw::PDFUtil;
	BBBikeDraw::PDFUtil::init_compress($self);
    }

    my $page_bbox = [0,0,DIN_A4_WIDTH,DIN_A4_HEIGHT];
    my $rotate;
    my $geometry = $self->{Geometry} || '';
    if ($geometry eq 'auto') {
	$self->dimension_from_route if !defined $self->{Max_y}; # XXX clean enough?
	my $route_height = ($self->{Max_y}-$self->{Min_y});
	$route_height = 20 if (!$route_height); # avoid division by 0
	if (($page_bbox->[2]-$page_bbox->[0])/($page_bbox->[3]-$page_bbox->[1]) <
	    ($self->{Max_x}-$self->{Min_x})/$route_height) {
	    $geometry = "landscape";
	} else {
	    $geometry = "portrait";
	}
    }
    if ($geometry eq 'landscape') {
	@$page_bbox[2,3] = @$page_bbox[3,2];
	#XXX jeht nicht:	$rotate = 90; # oder -90
    }

    my $surface;
    if (defined $self->{Filename}) {
	$surface = Cairo::PdfSurface->create($self->{Filename}, $page_bbox->[2], $page_bbox->[3]);
    } else {
	my $fh = $self->{Fh};
	$surface = Cairo::PdfSurface->create_for_stream(sub { print $fh $_[1] }, undef, $page_bbox->[2], $page_bbox->[3]);
    }

    ## XXX no Cairo support for these, it seems
    #'Author' => 'Slaven Rezic',
    #'Title' => 'BBBike Route',
    #'Creator' => __PACKAGE__ . " version $BBBikeDraw::PDF::VERSION",
    #'CreationDate' => [ localtime ],
    #'Keywords' => 'Routenplaner Fahrrad',
    ##'PageMode' => 'UseOutlines',

    my $cr = Cairo::Context->create($surface);
    # XXX $rotate specification

    ## XXX no outline support here
    #$pdf->new_outline('Title' => (defined $self->{Lang} && $self->{Lang} eq 'en' ? 'map' : 'Karte'),
    #	      'Destination' => $page);

    $self->{PDF}      = $surface;
    $self->{Image}    = $cr; # named "Image" for GD compatibility

# XXX Following is same as in PDF.pm

    $self->{PageBBox} = $page_bbox;
    $self->{Width}    = $page_bbox->[2]-$page_bbox->[0];
    $self->{Height}   = $page_bbox->[3]-$page_bbox->[1];

    if (!defined $self->{Outline}) {
	$self->{Outline} = 1;
    }

    $self->allocate_colors_and_fonts;
    $self->set_category_colors;
    $self->set_category_outline_colors;
    $self->set_category_widths; # Note: will be called again in draw_map (with $m argument)

    # grey background (different from PDF.pm again)
    $cr->rectangle(@$page_bbox);
    $cr->set_source_rgb(@$grey_bg);
    $cr->fill;

    $self->set_draw_elements;

    $self;
}

sub allocate_colors_and_fonts {
    my $self = shift;
    $self->allocate_colors;
    # No fonts need to be allocated, this is the job of Pango
}

# XXX Same as in PDF.pm
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
    $lightyellow = [1,1,0.7] if !defined $lightyellow;
    $red         = [1,0,0];
    $green       = [0,1,0];
    $darkgreen   = [0,0.5,0];
    $darkblue    = [0,0,0.5];
    $lightblue   = [0.73,0.84,0.97];
    $middlegreen = [0,0.78,0];
    $lightgreen  = [200/256,1,200/256];
    $rose        = [map { $_/256 } 215, 184, 200];
    $black       = [0,0,0];
    $darkgrey    = [map { $_/256 } 63, 63, 63];
}

sub draw_map {
    my $self = shift;
    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    {
	my $m = ($self->{Xk} > 0.06  ? 1   :
		 $self->{Xk} > 0.04  ? 0.8 :
		 $self->{Xk} > 0.02  ? 0.6 :
		                       0.4);
	$self->set_category_widths($m);
    }

    $self->_get_nets;
    $self->{FlaechenPass} = 1;

    my %str_draw = %{ $self->{_StrDraw} };
    my %p_draw = %{ $self->{_PDraw} };
    my $title_draw = $self->{_TitleDraw};

    my $bbox = $self->{PageBBox};

    my $restrict;
    if ($self->{Restrict}) {
	$restrict = { map { ($_ => 1) } @{ $self->{Restrict} } };
    }

    for my $layer_def (@{ $self->{_Layers} }) {
	my($strecke, $strecke_name, $is_outline) = @$layer_def;

	if ($is_outline) {
	    if ($self->{Outline}) {
		$strecke->init;
		while(1) {
		    my $s = $strecke->next;
		    last if !@{$s->[1]};
		    my($cat, $cat_attribs) = $s->[2] =~ m{^([^:]+)(?:::(.*))?};
		    my $is_area = 0;
		    if ($cat =~ /^F:([^|]+)/) {
			$cat = $1;
			$is_area = 1;
		    }
		    next if $restrict && !$restrict->{$cat};

		    my($ss, $bbox) = transpose_all($s->[1], $transpose);
		    next if (!bbox_in_region($bbox, $self->{PageBBox}));

		    my $dash_set;
		    if ($cat_attribs) {
			if ($cat_attribs =~ $BBBikeDraw::tunnel_qr && $line_dash{'Tu'}) {
			    $im->set_dash(@{ $line_dash{Tu} });
			    $dash_set = 1;
			} elsif ($line_dash{$cat_attribs}) {
			    $im->set_dash(@{ $line_dash{$cat_attribs} });
			    $dash_set = 1;
			}
		    }
		    if ($is_area) {
			$im->set_line_width(2);
		    } else {
			$im->set_line_width(($width{$cat}||1)*1+2);
		    }
		    $im->set_source_rgb(@{ $outline_color{$cat} || [0,0,0] });

		    $im->move_to(@{ $ss->[0] });
		    for my $xy (@{$ss}[1 .. $#$ss]) {
			$im->line_to(@$xy);
		    }
		    # close polygon
		    if ($is_area && "@{ $ss->[0] }" ne "@{ $ss->[-1] }") {
			$im->line_to(@{ $ss->[0] });
		    }
		    $im->stroke;
		    $im->set_dash(0) if $dash_set;
		}
	    }
	} else {
	    my $flaechen_pass = $self->{FlaechenPass};
	    for my $s ($self->get_street_records_in_bbox($strecke)) {
		my $cat = $s->[Strassen::CAT];

		my($ss, $bbox) = transpose_all($s->[Strassen::COORDS], $transpose);
		next if (!bbox_in_region($bbox, $self->{PageBBox}));
		next if ($cat =~ $BBBikeDraw::bahn_bau_rx); # Ausnahmen: in Bau

		# move to first point
		$im->move_to(@{ $ss->[0] });

		if ($cat =~ /^F:([^|]+)/) {
		    my $cat = $1;
		    next if ($strecke_name eq 'flaechen' &&
			     (($flaechen_pass == 1 && $cat eq 'Pabove') ||
			      ($flaechen_pass == 2 && $cat ne 'Pabove'))
			    );
		    $im->set_line_width(1);
		    if (my($r,$g,$b) = $cat =~ m{^\#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$}i) {
			($r,$g,$b) = (hex($r)/255,hex($g)/255,hex($b)/255);
			$im->set_source_rgb($r,$g,$b);
		    } else {
			$im->set_source_rgb(@{ $color{$cat} || [0,0,0] });
		    }
		    for my $xy (@{$ss}[1 .. $#$ss]) {
			$im->line_to(@$xy);
		    }
		    $im->fill;
		} else {
		    my $cat_attribs;
		    if (($cat, $cat_attribs) = $cat =~ m{^([^:]+)(?:::(.*))?}) {
			next if $restrict && !$restrict->{$cat};
			my $dash_set;
			if ($cat_attribs && $line_dash{$cat_attribs}) {
			    $im->set_dash(@{ $line_dash{$cat_attribs} });
			    $dash_set = 1;
			}
			$im->set_line_width(($width{$cat} || 1) * 1);
			$im->set_source_rgb(@{ $color{$cat} || [0,0,0] });
			for my $xy (@{$ss}[1 .. $#$ss]) {
			    $im->line_to(@$xy);
			}
			$im->stroke;
			$im->set_dash(0) if $dash_set;
		    }
		}
	    }
	    if ($strecke_name eq 'flaechen') {
		$self->{FlaechenPass}++;
	    }
	}
    }

    # $self->{Xk} bezeichnet den Vergrößerungsfaktor
    # bis etwa 0.02 ist es zu unübersichtlich, Ampeln zu zeichnen,
    # ab etwa 0.05 kann man die mittelgroße Variante nehmen
    if ($p_draw{'ampel'} && $self->{Xk} >= 0.02) {
	my $lsa = new Strassen "ampeln";
	my $images_dir = $self->get_images_dir;
	my $suf = ($self->{Xk} >= 0.05 ? '' : '2');

	my($kl_ampel, $kl_andreas, $kl_zugbruecke, $kl_ampelf);

	eval {
	    my $file;
	    $kl_ampel      = Cairo::ImageSurface->create_from_png("$images_dir/ampel_klein$suf.png");
	    $kl_andreas    = Cairo::ImageSurface->create_from_png("$images_dir/andreaskr_klein$suf.png");
	    $kl_zugbruecke = Cairo::ImageSurface->create_from_png("$images_dir/" . ($self->{Xk} >= 0.05 ? "zugbruecke" : "zugbruecke_klein") . ".png");
	    $kl_ampelf     = Cairo::ImageSurface->create_from_png("$images_dir/ampelf_klein$suf.png");
	}; warn $@ if $@;
	if ($kl_andreas || $kl_ampel || $kl_zugbruecke || $kl_ampelf) {
	    $lsa->init;
	    while(1) {
		my $s = $lsa->next_obj;
		last if $s->is_empty;
		my $cat = $s->category;
		my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
		if ($x < $bbox->[0] || $x > $bbox->[2] ||
		    $y < $bbox->[1] || $y > $bbox->[3]) {
		    next;
		}
		my $image;
		if ($cat =~ m{^(B|B0)$}) {
		    $image = $kl_andreas;
		} elsif ($cat eq 'F' && $kl_ampelf) { # note: F0 currently ignored
		    $image = $kl_ampelf;
		} elsif ($cat =~ m{^(X|F)$}) { # F: only fallback; X0 currently ignored
		    $image = $kl_ampel;
		} elsif ($cat =~ m{^Zbr$}) {
		    $image = $kl_zugbruecke;
		}
		if ($image) {
		    my($w,$h) = ($image->get_width, $image->get_height);
		    $im->set_source_surface($image, $x-$w/2, $y-$h/2);
		    $im->paint;
		}
	    }
	}
    }

# XXXX hier wird $small_display und $xw/$yw nicht beachtet!
    my($xw, $yw);
    my $small_display = 0;
    if ($self->{Width} < 200 ||	$self->{Height} < 150) {
	($xw, $yw) = (1, 1);
	$small_display = 1;
    } else {
	my($xw1, $yw1) = &$transpose(0, 0);
	my($xw2, $yw2) = &$transpose(60, 60);
#	($xw, $yw) = ($xw2-$xw1, $yw2-$yw1);
	($xw, $yw) = (5, 5);
    }

    my $min_ort_category = ($self->{Xk} < 0.005 ? 3
 			    : ($self->{Xk} < 0.01 ? 2
 			       : ($self->{Xk} < 0.02 ? 1 : 0)));
    my %ort_font = (0 => 6,
		    1 => 7,
		    2 => 8,
 		    3 => 10,
 		    4 => 12,
 		    5 => 14,
 		    6 => 16,
		    bhf => 7,
 		   );
    my %seen_bahnhof;
    my $strip_bhf = sub {
	my $bhf = shift;
	require Strassen::Strasse;
	$bhf =~ s/\s+\(.*\)$//; # strip text in parenthesis
	$bhf = Strasse::short($bhf, 1);
	$bhf;
    };
    foreach my $def (['ubahn', 'ubahnhof', 'u'],
		     ['sbahn', 'sbahnhof', 's'],
		     ['rbahn', 'rbahnhof', 'r'],
		     ['ort', 'orte',       'o'],
		     ['orte_city', 'orte_city', 'oc'],
		    ) {
	my($lines, $points, $type) = @$def;
	# check if it is advisable to draw stations...
	next if ($lines =~ /bahn$/ && $self->{Xk} < 0.004);
	my $do_bahnhof = grep { $_ eq $lines."name" } @{$self->{Draw}};
	if ($self->{Xk} < 0.06) {
	    $do_bahnhof = 0;
	}
	# Skip drawing if !ubahnhof, !sbahnhof or !rbahnhof is specified
	next if $str_draw{"!" . $points};
  	if ($str_draw{$lines}) {
  	    my $p = ($lines eq 'ort'
  		     ? $self->_get_orte
  		     : new Strassen $points);

	    my $images_dir = $self->get_images_dir;
	    my $image;
	    my $suffix;
	    if ($self->{Xk} < 0.05) {
		$suffix = "_mini";
	    } elsif ($self->{Xk} < 0.2) {
		$suffix = "_klein";
	    } else {
		$suffix = "";
	    }

	    eval {
		if ($points =~ m{^[us]bahnhof$}) {
		    $image = Cairo::ImageSurface->create_from_png("$images_dir/${type}bahn$suffix.png");
		} elsif ($points eq 'rbahnhof') {
		    $image = Cairo::ImageSurface->create_from_png("$images_dir/eisenbahn$suffix.png");
		}
	    };
	    warn $@ if $@;

	    for my $s ($self->get_street_records_in_bbox($p)) {
  		my $cat = $s->[Strassen::CAT];
  		next if $cat =~ $BBBikeDraw::bahn_bau_rx;
  		my($x0,$y0) = split /,/, $s->[Strassen::COORDS][0];
		if ($image) {
		    my($x1, $y1) = &$transpose($x0, $y0);
		    my($w,$h) = ($image->get_width, $image->get_height);
		    $x1 -= $w/2;
		    $y1 -= $h/2;
		    next if $x1 < 0 || $y1 < 0 || $x1 > $self->{Width} || $y1 > $self->{Height};
		    $im->set_source_surface($image, $x1, $y1);
		    $im->paint;
		    if (0 && $do_bahnhof) { # XXX station label drawing not yet enabled, needs more work...
			my $name = $strip_bhf->($s->[Strassen::NAME]);
			if (!$seen_bahnhof{$name}) {
			    my $pad_top  = $h/2; 
			    my $pad_left = $w+1;
			    $im->set_source_rgb(@$darkblue);
			    draw_text($im, $ort_font{'bhf'},
				      $x1+$pad_left, $y1+$pad_top,
				      $name,
				     );
			    $seen_bahnhof{$name}++;
			}
		    }
 		} else {
 		    if ($cat >= $min_ort_category) {
 			my($x, $y) = &$transpose($x0, $y0);
 			my $ort = $s->[Strassen::NAME];
 			# Anhängsel löschen (z.B. "b. Berlin")
 			$ort =~ s/\|.*$//;
			my $size = $ort_font{$cat} || 6;
			if ($type eq 'oc') {
			    # orte_city is plotted centered, without a dot
			    my($s_width, undef) = get_text_dimensions($im, $size, $ort);
			    $im->set_source_rgb(@$darkblue);
			    draw_text($im, $size, $x-$s_width/2, $y, $ort);
			} else {
			    $im->set_source_rgb(@$black);
			    $im->move_to($x, $y);
			    $im->arc($x, $y, 1, 0, 2*pi);#XXX check!
			    $im->fill;
			    $im->set_source_rgb(@$darkblue);
			    draw_text($im, $size, $x+4, $y, $ort);
			}
 		    }
 		}
  	    }
  	}
    }

#XXXX implement here!!!
#XXX no angle/rotate support with PDF::Create
#      if (ref $self->{StrLabel}) {
#  	my $fontsize = 10;

#  	my $draw_sub = sub {
#  	    my($x,$y) = &$transpose($_[0], $_[1]);
#  	    if (defined $_[4] and defined $_[5]) {
#  		$x -= $_[4];
#  		$y -= $_[5];
#  	    }
#  	    $im->$ft_method($black, $ttf, $fontsize, -$_[3], $x, $y, $_[2]);
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
    my $self = shift;
    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    my $x_margin = 12;
    my $y_margin = $self->{Height} - 20;
    my $color = $black;
    my $bar_width = 4;
    my($x0,$y0) = $transpose->($self->standard_to_coord(0,0));
    my($x1,$y1, $strecke, $strecke_label);
    for $strecke (10, 50, 100, 500, 1000, 5000, 10000, 20000, 50000, 100000) {
	($x1,$y1) = $transpose->($self->standard_to_coord($strecke,0));
	if ($x1-$x0 > 50) {
	    if ($strecke >= 1000) {
		$strecke_label = $strecke/1000 . "km";
	    } else {
		$strecke_label = $strecke . "m";
	    }
	    last;
	}
    }

    {
	my @rect_coords = (
			   $self->{Width}-($x1-$x0)-$x_margin,
			   $y_margin,
			   ($x1-$x0)/2,
			   $bar_width
			  );
	$im->set_source_rgb(@$color);
	$im->set_line_width(1);
	$im->rectangle(@rect_coords);
	$im->stroke;

	$im->set_source_rgb(@$white);
	$im->rectangle(@rect_coords);
	$im->fill;
    }

    $im->set_source_rgb(@$color);
    $im->rectangle($self->{Width}-($x1-$x0)/2-$x_margin,
		   $y_margin,
		   ($x1-$x0)/2,
		   $bar_width);
    $im->fill;

    $im->move_to($self->{Width}-($x1-$x0)-$x_margin, $y_margin);
    $im->line_to($self->{Width}-$x_margin, $y_margin);

    $im->move_to($self->{Width}-($x1-$x0)-$x_margin, $y_margin+$bar_width);
    $im->line_to($self->{Width}-$x_margin, $y_margin+$bar_width);

    $im->move_to($self->{Width}-($x1-$x0)/2-$x_margin, $y_margin);
    $im->line_to($self->{Width}-($x1-$x0)/2-$x_margin, $y_margin+$bar_width);

    $im->move_to($self->{Width}-($x1-$x0)-$x_margin, $y_margin-2);
    $im->line_to($self->{Width}-($x1-$x0)-$x_margin, $y_margin+$bar_width+2);

    $im->move_to($self->{Width}-$x_margin, $y_margin-2);
    $im->line_to($self->{Width}-$x_margin, $y_margin+$bar_width+2);

    $im->stroke;

    my $font_size = 10;
    draw_text($im, $font_size, $self->{Width}-($x1-$x0)-$x_margin-3, $y_margin+$bar_width+4, "0", -forcevertalign => 1);
    draw_text($im, $font_size, $self->{Width}-$x_margin+8-6*length($strecke_label), $y_margin+$bar_width+4, $strecke_label, -forcevertalign => 1);
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

    $im->set_line_width(6);

    # Route
    if (@multi_c1) {
	for my $c1 (@multi_c1) {
	    my @c1 = @$c1;
	    if (@c1) {
		for my $def (
			     # Prepared to use alternate colors, but I
			     # did not found a good pair so far. Use
			     # darker red, to not conflicht with $red
			     # used in Bundesstraßen.
			     [[0.4, 0, 0], 0],
			     [[0.4, 0, 0], 7],
			    ) {
		    my($color, $phase) = @$def;
		    $im->set_source_rgb(@$color);
		    # XXX what was $phase here, can it be emulated (see PDF.pm)?
		    $im->set_dash($phase, 4, 10);
		    $im->move_to(map { sprintf "%.2f", $_ } $transpose->(@{ $c1[0] }));
		    for(my $i = 1; $i <= $#c1; $i++) {
			$im->line_to(map { sprintf "%.2f", $_ } $transpose->(@{ $c1[$i] }));
		    }
		    $im->stroke;
		}
		$im->set_dash(0);
	    }
	}
    }

    # Flags
    if (@multi_c1 > 1 || ($multi_c1[0] && @{$multi_c1[0]} > 1)) {
	if ($self->{UseFlags}) {
	    my $images_dir = $self->get_images_dir;
	    my $start_flag = Cairo::ImageSurface->create_from_png("$images_dir/flag2_bl.png");
	    if ($start_flag) {
		my($x, $y) = &$transpose(@{ $multi_c1[0][0] });
		$im->set_source_surface($start_flag, $x-4, $y-15);
		$im->paint;
	    }
	    my $end_flag = Cairo::ImageSurface->create_from_png("$images_dir/flag_ziel.png");
	    if ($end_flag) {
		my($x, $y) = &$transpose(@{ $multi_c1[-1][-1] });
		$im->set_source_surface($end_flag, $x-4, $y-15);
		$im->paint;
	    }
	}
    }

    # Ausgabe der Straßennnamen
    if ($strnet) {
	$im->set_line_width(1);
	my(@strnames) = $strnet->route_to_name
	    ([ map { [split ','] } @{ $self->{Coords} } ]);
	my $size = (@strnames >= 30 ? 6 :
		    @strnames >= 23 ? 7 :
		    @strnames >= 16 ? 8 :
		    @strnames >= 10 ? 9 :
		    10
		   );
	my $pad = 2;
	my $sm = eval { require Geo::SpaceManager; Geo::SpaceManager->new($self->{PageBBox}) };
	#warn $@ if $@;
	foreach my $e (@strnames) {
	    my $name = Strassen::strip_bezirk($e->[0]);
	    my $f_i  = $e->[4][0];
	    my($x,$y) = &$transpose(split ',', $self->{Coords}[$f_i]);
	    if ($x >= $self->{PageBBox}[0] && $x <= $self->{PageBBox}[2] &&
		$y >= $self->{PageBBox}[1] && $y <= $self->{PageBBox}[3]) {
		my($s_width, $s_height) = get_text_dimensions($im, $size, $name);
		$y-=($s_height+$pad);
		if ($sm) {
		    my($x1,$y1,$x2,$y2) = ($x-$pad, $y-$pad, $x+$s_width+$pad, $y+$s_height+$pad);
		    my $r1 = $sm->nearest([$x1,$y1,$x2,$y2]);
		    if (!defined $r1) {
			warn "No space left for [$x1,$y1,$x2,$y2]";
		    } else {
			$sm->add($r1);
			$x = $r1->[0]+$pad;
			$y = $r1->[1]+$pad;
		    }
		}
		$im->set_source_rgb(@$white);
		$im->rectangle($x-$pad, $y-$pad, $s_width+$pad*2, $s_height+$pad);
		$im->fill;
		$im->set_source_rgb(@$black);
		$im->rectangle($x-$pad, $y-$pad, $s_width+$pad*2, $s_height+$pad);
		$im->stroke;
		draw_text($im, $size, $x, $y, $name);
	    }
	}
    }

    if ($self->{TitleDraw}) {
	my $start = $self->{Startname};
	my $ziel  = $self->{Zielname};
	foreach my $s (\$start, \$ziel) {
	    # Text in Klammern entfernen, damit der Titel kürzer wird
	    my(@s) = split(m|/|, $$s);
	    foreach (@s) {
		s/\s+\(.*\)$//;
	    }
	    $$s = join("/", @s);
	}
	my $title_string = "$start " . chr(0x2192) . " $ziel";

	my $size = 20;
	my($s_width, $s_height) = get_text_dimensions($im, $size, $title_string);

	my $x_top = 20;
	my $y_top = 13;
	my $pad = 3;

	$im->set_source_rgb(@$white);
	$im->set_line_width(1);
	$im->rectangle($x_top-$pad, $y_top-$pad, $s_width+$pad*2, $s_height+$pad);
	$im->fill;
	$im->set_source_rgb(@$black);
	$im->rectangle($x_top-$pad, $y_top-$pad, $s_width+$pad*2, $s_height+$pad);
	$im->stroke;
	draw_text($im, $size, $x_top, $y_top, $title_string);
    }

}

# Draw this first, otherwise the filling of the circle won't work!
sub draw_wind {
    return; # not yet XXXX
    my $self = shift;
    return unless $self->{Wind};
    require BBBikeCalc;
    BBBikeCalc::init_wind();
    my $richtung = lc($self->{Wind}{Windrichtung});
    if ($richtung =~ /o$/) { $richtung =~ s/o$/e/; }
    my $staerke  = $self->{Wind}{Windstaerke};
    my $im = $self->{Image};
    my($rad) = 10;
    my $col = $darkblue;
    $im->set_stroke_color(@$col);
    $im->set_fill_color(@$col);
    $im->circle($self->{Width}-20, 20, $rad);
    $im->fill;
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
	    $im->line($self->{Width}-20, 20, $self->{Width}-20+$xadd, 20+$yadd);
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
			  $self->{Width}-20+$xadd+$xadd2, 20+$yadd+$yadd2);
		$this_tic -= 3;
		last if $this_tic <= 0;
		$i-=2;
	    }
	}
    }
}

sub add_route_descr {
    my $self = shift;
    my(%args) = @_;
    my $net = $args{-net} || die "-net is missing";
    my @c;
    if ($self->{MultiCoords}) {
	# XXX this is a suboptimal solution!
	# Route should deal with interrupted routes!
	@c = map { [split /,/ ] } map { @$_ } @{ $self->{MultiCoords} };
    } else {
	@c = map { [split /,/ ] } @{ $self->{Coords} };
    }

    require Route::PDF::Cairo;
    require Route;

    Route::PDF::Cairo::add_page_to_bbbikedraw
	    (-bbbikedraw => $self,
	     -net => $net,
	     -route => Route->new_from_realcoords(\@c),
	     -lang => $args{'-lang'},
	    );
}

sub flush {
    my $self = shift;
    my %args = @_;
    if (!defined $self->{Filename}) {
	my $fh = $args{Fh} || $self->{Fh};
	binmode $fh;
    }
    $self->{PDF}->finish;

    if ($DO_COMPRESS) {
	BBBikeDraw::PDFUtil::flush_compress($self, -v => $VERBOSE);
    }
}

# use Return => "string" in the constructor for this method
#XXX NYI
sub string {
    my($self, %args) = @_;
    $self->flush(%args);
    if (defined $self->{Filename}) {
	open(F, $self->{Filename}) or die "Can't open $self->{Filename}: $!";
	local $/ = undef;
	my $buf = scalar <F>;
	close F;
	$buf;
    } else {
	$ {$self->{Fh}->string_ref };
    }
}

sub empty_image_error {
    my $self = shift;
    my $im = $self->{Image};
    my $fh = $self->{Fh};

    if ($im) {
	my @error_msg = $self->empty_image_error_message;
	$im->set_source_rgb(@$black);
	my $y = 750;
	for my $line (@error_msg) {
	    draw_text($im, 24, 50, $y, $line);
	    $y -= 30;
	}
	$self->flush;
    }
    confess "Empty image";
}

# return transposed and pdf'ied "strecke" and the bbox
sub transpose_all {
    my($s, $transpose) = @_;
    # first:
    my($tx,$ty) = map { sprintf "%.2f", $_ }
	              $transpose->(@{ Strassen::to_koord_f1($s->[0]) });

    my $res = [[$tx, $ty]];
    my $bbox = [$tx,$ty,$tx,$ty];

    foreach my $xy (@{$s}[1 .. $#$s]) {
	my($tx,$ty) = map { sprintf "%.2f", $_ }
	                  $transpose->(@{ Strassen::to_koord_f1($xy) });
	push @$res, [ $tx, $ty ];

	$bbox->[0] = $tx if ($tx < $bbox->[0]);
	$bbox->[2] = $tx if ($tx > $bbox->[2]);
	$bbox->[1] = $ty if ($ty < $bbox->[1]);
	$bbox->[3] = $ty if ($ty > $bbox->[3]);
    }

    ($res, $bbox);
}

# return true if the union is not empty
sub bbox_in_region {
    my($bbox, $region) = @_;
    return 0 if ($bbox->[0] > $region->[2] ||
		 $bbox->[1] > $region->[3] ||
		 $bbox->[2] < $region->[0] ||
		 $bbox->[3] < $region->[1]);
    1;
}

sub can_multiple_passes {
    my($self, $type) = @_;
    return $type eq 'flaechen';
}

sub patch_string {
    if (!eval { require BBBikeUnicodeUtil; 1 }) {
	$_[0];
    } else {
	BBBikeUnicodeUtil::unidecode_string($_[0]);
    }
}

sub draw_text {
    my($surface, $size, $x, $y, $string, %args) = @_;
    if (eval { require Pango; 1 }) {
	my $layout = Pango::Cairo::create_layout($surface);
	$layout->set_text($string);
	my $fontdesc = Pango::FontDescription->from_string("DejaVu Sans condensed");
	$fontdesc->set_absolute_size($size * (Pango->scale));
	$layout->set_font_description($fontdesc);
	$surface->move_to($x, $y);
	Pango::Cairo::show_layout($surface, $layout);
    } else {
	$string = patch_string($string);
	utf8::upgrade($string); # workaround bug in Cairo, see https://rt.cpan.org/Ticket/Display.html?id=73177
	my $extents = $surface->text_extents($string);
	# Subtracting y_bearing works fine for the route labels and
	# the title string, but is not good in draw_scale, where both
	# strings may have different y_bearing values (even if it's
	# the same string!). In this case it's better to use the size
	# instead, with a small negative offset.
	if ($args{'-forcevertalign'}) {
	    $surface->move_to($x, $y + $size - 1);
	} else {
	    $surface->move_to($x, $y - $extents->{y_bearing});
	}
	$surface->select_font_face('Sans Serif', 'normal', 'normal');
	$surface->set_font_size($size);
	$surface->show_text($string);
    }
}

sub get_text_dimensions {
    my($surface, $size, $string) = @_;
    if (eval { require Pango; 1 }) {
	my $layout = Pango::Cairo::create_layout($surface);
	$layout->set_text($string);
	my $fontdesc = Pango::FontDescription->from_string("DejaVu Sans condensed");
	$fontdesc->set_absolute_size($size * (Pango->scale));
	$layout->set_font_description($fontdesc);
	my($w, $h) = map { $_/Pango->scale } $layout->get_size;
	($w, $h);
    } else {
	$string = patch_string($string);
	utf8::upgrade($string); # workaround bug in Cairo, see https://rt.cpan.org/Ticket/Display.html?id=73177
	$surface->select_font_face('Sans Serif', 'normal', 'normal');
	$surface->set_font_size($size);
	my $extents = $surface->text_extents($string);
	($extents->{x_advance}, $size);
    }
}

1;
