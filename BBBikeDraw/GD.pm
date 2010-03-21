# -*- perl -*-

#
# $Id: GD.pm,v 1.66 2008/12/31 16:36:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package BBBikeDraw::GD;
use strict;
use base qw(BBBikeDraw);
use Strassen;
# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);

use vars qw($gd_version $VERSION $DEBUG @colors %color %outline_color %width
	    $TTF_STREET $TTF_CITY $TTF_TITLE $TTF_SCALE);
BEGIN { @colors =
         qw($grey_bg $white $yellow $lightyellow $red $green $middlegreen $darkgreen
	    $darkblue $lightblue $rose $black $darkgrey $lightgreen);
}
use vars @colors;

use vars qw($AUTOLOAD);
sub AUTOLOAD {
    warn "Loading BBBikeDraw::GDHeavy for $AUTOLOAD ...\n";
    require BBBikeDraw::GDHeavy;
    if (defined &$AUTOLOAD) {
	goto &$AUTOLOAD;
    } else {
	die "Cannot find $AUTOLOAD in ". __PACKAGE__;
    }
}

$DEBUG = 0;
$VERSION = sprintf("%d.%02d", q$Revision: 1.66 $ =~ /(\d+)\.(\d+)/);

my(%brush, %outline_brush, %thickness, %outline_thickness);

# REPO BEGIN
# REPO NAME pi /home/e/eserte/src/repository 
# REPO MD5 bb2103b1f2f6d4c047c4f6f5b3fa77cd
sub pi ()   { 4 * atan2(1, 1) } # 3.141592653
# REPO END

sub init {
    my $self = shift;

    $self->SUPER::init();

    local $^W = 0;

#XXX revamp this code... maybe separate between in/out (newFrom... and ...)

    eval q{
	local $SIG{'__DIE__'};
	if (defined $self->{ImageType} && $self->{ImageType} eq 'svg') {
	    require GD::SVG;
	    $self->{GD_Image}   = 'GD::SVG::Image';
	    $self->{GD_Polygon} = 'GD::SVG::Polygon';
	    $self->{GD_Font}    = 'GD::SVG::Font';
	    $self->{GD}         = 'GD::SVG';

	    package GD::SVG::Image;
            sub imageOut {
		shift->svg(@_);
	    }
	    # newFromImage is missing because the newFrom* methods
	    # are not available in GD::SVG
	} else {
	    require GD;
	    $self->{GD_Image}   = 'GD::Image';
	    $self->{GD_Polygon} = 'GD::Polygon';
	    $self->{GD_Font}    = 'GD::Font';
	    $self->{GD}         = 'GD';
	    $self->{ImageType} = 'gif' if !defined $self->{ImageType};
#  	    if ($GD::VERSION < 1.27 && $self->{ImageType} eq 'wbmp') {
#  	        $self->{ImageType} = 'gif';
#  	    }
	    if ($self->{ImageType} eq 'gif' && $GD::VERSION >= 1.20) {
	        # XXX automatic detection does not seem to work with GD 1.41 ?
#XXX	        if ($GD::VERSION < 1.37 || !GD::Image->can("gif")) {
	    	    if (!eval { require GD::Convert; GD::Convert->import("gif=any", "newFromGif=any"); 1}) {
		        warn "Can't create gif files, fallback to png: $@";
		        $self->{ImageType} = 'png';
		    } else {
		        warn "OK, using GD::Convert for gif conversion"
			    if $DEBUG;
		    }
#XXX	        }
	    }
	    if ($self->{ImageType} eq 'png' && $GD::VERSION < 1.20) {
	        $self->{ImageType} = 'gif';
	    }

	    package GD::Image;
            sub imageOut {
	        my $image = shift;

		if ($self->imagetype eq 'gif' && $image->can('gif')) {
		    $image->gif(@_);
		} elsif ($self->imagetype eq 'png' && $image->can('png')) {
		    $image->png(@_);
		} elsif ($self->imagetype eq 'jpeg' && $image->can('jpeg')) {
		    $image->jpeg(@_);
		} elsif ($self->imagetype eq 'wbmp') {
		    if (!$image->can('wbmp')) {
			require GD::Convert;
			GD::Convert->import('wbmp');
		    }
		    $image->wbmp($BBBikeDraw::black);
		} else {
		    die "Fatal error: no gif or png methods";
		}
	    }
	    sub newFromImage {
		my $image = shift;
		if ($self->imagetype eq 'gif' && $image->can('newFromGif')) {
		    $image->newFromGif(@_);
		} elsif ($self->imagetype eq 'png' && $image->can('newFromPng')) {
		    $image->newFromPng(@_);
		} elsif ($self->imagetype eq 'jpeg' && $image->can('newFromJpeg')) {
		    $image->newFromJpeg(@_);
		} else {
		    die "Fatal error: no newFrom" . ucfirst($self->imagetype) . " method available";
		}
	    }
	}
    };
    warn $@ if $@;
    return undef if ($@);

    {
	local $^W = 1;
	$TTF_STREET ||= $self->search_ttf_font
	    ([
	      '/usr/local/lib/X11/fonts/ttf/LucidaSansRegular.ttf',
	      '/usr/X11R6/lib/X11/fonts/ttf/LucidaSansRegular.ttf',
	      '/usr/local/lib/X11/fonts/bitstream-vera/Vera.ttf',
	      '/usr/X11R6/lib/X11/fonts/bitstream-vera/Vera.ttf',
	      '/usr/local/lib/X11/fonts/TTF/luxisr.ttf',
	      '/usr/X11R6/lib/X11/fonts/TTF/luxisr.ttf',
	      '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansCondensed.ttf', # found on Debian
	     ]);

	$TTF_CITY ||= $self->search_ttf_font
	    ([
	      '/usr/local/lib/X11/fonts/Type1/lcdxsr.pfa',
	      '/usr/X11R6/lib/X11/fonts/Type1/lcdxsr.pfa',
	      '/usr/local/lib/X11/fonts/bitstream-vera/Vera.ttf',
	      '/usr/X11R6/lib/X11/fonts/bitstream-vera/Vera.ttf',
	      '/usr/local/lib/X11/fonts/TTF/luxisr.ttf',
	      '/usr/X11R6/lib/X11/fonts/TTF/luxisr.ttf',
	      '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansCondensed.ttf', # found on Debian
	     ]);

	$TTF_TITLE ||= $self->search_ttf_font
	    ([
	      '/usr/local/lib/X11/fonts/TTF/luxisb.ttf',
	      '/usr/X11R6/lib/X11/fonts/TTF/luxisb.ttf',
	      '/usr/local/lib/X11/fonts/bitstream-vera/VeraBd.ttf',
	      '/usr/X11R6/lib/X11/fonts/bitstream-vera/VeraBd.ttf',
	      '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSansCondensed-Bold.ttf', # found on Debian
	      $TTF_CITY,
	     ]);

	$TTF_SCALE ||= $self->search_ttf_font
	    ([
	      '/usr/local/lib/X11/fonts/TTF/luxirr.ttf',
	      '/usr/X11R6/lib/X11/fonts/TTF/luxirr.ttf',
	      $TTF_CITY,
	     ]);
    }

    eval q{local $SIG{'__DIE__'};
	   $gd_version = $GD::VERSION;
       };

    $self->{Width}  ||= 640;
    $self->{Height} ||= 480;
    my $im;
    if ($self->{OldImage}) {
	$im = $self->{OldImage};
    } else {
	my $use_truecolor = 0; # XXX with 1 segfaults (still with 2.0.33, seen on amd64-freebsd). Also, background color is not set correctly.
	$im = $self->{GD_Image}->new($self->{Width},$self->{Height},
 				     $use_truecolor);
    }

    $self->{Image}  = $im;

    $self->{GD_use_thickness} = $im->can("setThickness");
    $self->{GD_use_aa} = 0 && $im->can("setAntiAliased"); # no effect seen without truecolor

    if (!$self->{OldImage}) {
	$self->allocate_colors;
    }

    $self->set_category_colors;
    $self->set_category_outline_colors;
    $self->set_category_widths;

    $im->interlaced('true');

    $self->set_draw_elements;

    if ($self->imagetype eq 'wbmp' && !defined $self->{RouteWidth}) {
	$self->{RouteWidth} = $width{HH} + 4;
        #$self->{RouteDotted} = 3;
    }

    $self;
}

sub pre_draw {
    my $self = shift;
    $self->SUPER::pre_draw;

    my $im = $self->{Image};

    my $scale = ($self->{Xk} > 1 ? 10 : $self->{Xk} * 10);
    $scale = 0.5 if $scale < 0.5;

    # create brushes
    foreach my $cat (keys %width) {
	next if $cat eq 'Route';
	my $width = $width{$cat} * $scale;
	$width = 1 if $width < 1;
	$width = int($width);
	if ($self->{GD_use_thickness}) {
	    $thickness{$cat} = $width;
	} else {
	    my $brush = $self->{GD_Image}->new($width, $width);
	    $brush->colorAllocate($im->rgb($color{$cat}));
	    $brush{$cat} = $brush;
	}
    }
    # create outline brushes
    foreach my $cat (keys %width) {
	next unless $outline_color{$cat};
	my $width = $width{$cat} * $scale;
	$width = 1 if $width < 1;
	$width = int($width);
	$width += 2;
	if ($self->{GD_use_thickness}) {
	    $outline_thickness{$cat} = $width;
	} else {
	    my $brush = $self->{GD_Image}->new($width, $width);
	    $brush->colorAllocate($im->rgb($outline_color{$cat}));
	    $outline_brush{$cat} = $brush;
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
	    $ {$color} = $im->colorAllocate(@{$value}[0..2]);
	    if (defined $value->[3] && $value->[3] == 1) {
		$im->transparent($ {$color});
	    }
	}
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
    my @netz_name = @{ $self->{_NetName} };
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

    my $draw_outline_sub = sub {
	my($strecke) = @_;
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
#  		my $poly = GD::Polygon->new();
#  		for(my $i = 0; $i <= $#{$s->[1]}; $i++) {
#  		    $poly->addPt(&$transpose
#  				 (@{Strassen::to_koord1($s->[1][$i])}));
#  		}
#  		$im->filledPolygon($poly, $c);
#	    } elsif ($cat !~ /^[SRU]0$/) { # Ausnahmen: in Bau
	    next if $restrict && !exists $restrict->{$cat};
	    next if (!$outline_brush{$cat} && !defined $outline_thickness{$cat});
	    my $color;
	    if (defined $outline_thickness{$cat}) {
		$im->setThickness($outline_thickness{$cat});
		$color = $outline_color{$cat};
	    } else {
		$im->setBrush($outline_brush{$cat});
		$color = $self->{GD}->gdBrushed();
	    }
	    for my $i (0 .. $#{$s->[1]}-1) {
		my($x1, $y1, $x2, $y2) =
		    (@{Strassen::to_koord1($s->[1][$i])},
		     @{Strassen::to_koord1($s->[1][$i+1])});
		# XXX evtl. aus Performancegründen testen, ob
		# überhaupt im Zeichenbereich.
		# Evtl. eine XS-Funktion für diese Schleife
		# schreiben?
		my($x1t, $y1t, $x2t, $y2t) = ($transpose->($x1, $y1),
					      $transpose->($x2, $y2));
		$im->line($x1t, $y1t, $x2t, $y2t, $color);
	    }
	}
    };

    my $draw_normal_sub = sub {
	my($strecke, $strecke_name, $flaechen_pass) = @_;

	for my $s ($self->get_street_records_in_bbox($strecke)) {
	    my $cat = $s->[Strassen::CAT];
	    if ($cat =~ /^F:(.*)/) {
		my $cat = $1;
		next if ($strecke_name eq 'flaechen' &&
			 (($flaechen_pass == 1 && $cat eq 'Pabove') ||
			  ($flaechen_pass == 2 && $cat ne 'Pabove'))
			);
		my $c = defined $color{$cat} ? $color{$cat} : $white;
		if ($self->{GD_use_aa}) {
		    $im->setAntiAliased($c);
		    $c = $self->{GD}->gdAntiAliased();
		}
		my $poly = $self->{GD_Polygon}->new();
		for my $coord (@{ $s->[Strassen::COORDS] }) {
		    $poly->addPt($transpose->(split /,/, $coord));
		}
		if ($self->{GD_use_thickness}) {
		    $im->setThickness(1);
		}
		$im->filledPolygon($poly, $c);
	    } elsif ($cat !~ $BBBikeDraw::bahn_bau_rx) { # Ausnahmen: in Bau, stillgelegt, Güterstrecken ...
		$cat =~ s{::.*}{};
		next if $restrict && !exists $restrict->{$cat};
		my $color;
		if (defined $thickness{$cat}) {
		    $im->setThickness($thickness{$cat});
		    $color = $color{$cat};
		} elsif ($brush{$cat}) {
		    $im->setBrush($brush{$cat});
		    $color = $self->{GD}->gdBrushed();
		} else {
		    if ($self->{GD_use_thickness}) {
			$im->setThickness(1);
		    }
		    $color = defined $color{$cat} ? $color{$cat} : $white;
		}
		if ($self->{GD_use_aa} && $color ne $self->{GD}->gdBrushed()) {
		    $im->setAntiAliased($color);
		    $color = $self->{GD}->gdAntiAliased();
		}
		if (0) { # XXX no visible change using unclosedPolygon (with gd 2.0.33)
		    # But it seems to be 20% slower than ->line, measured with bbbikedraw.t -slow
		    my $poly = $self->{GD_Polygon}->new;
		    for my $coord (@{ $s->[Strassen::COORDS] }) {
			$poly->addPt($transpose->(split /,/, $coord));
		    }
		    $im->unclosedPolygon($poly, $color);
		} else {
		    my @txy = map { $transpose->(split/,/, $_) } @{ $s->[Strassen::COORDS] };
		    next if @txy < 4; # ignore points
		    if (0) { # no visible results without using a truecolor image, but see above...
			$im->setAntiAliased($color);
			$color = $self->{GD}->gdAntiAliased();
		    }
		    for my $i (0 .. $#txy/2-1) {
			$im->line(@txy[$i*2 .. $i*2+3], $color);
		    }
		}
	    }
	}
    };

    my @layers;

    use constant LAYER_TYPE_OUTLINE => 1;
    use constant LAYER_TYPE_NORMAL  => 2;

    if ($self->{Outline}) {
	push @layers, map {
	    +{type => LAYER_TYPE_OUTLINE,
	      str  => $_,
	     }
	} @outline_netz;
    }

    foreach my $strecke_i (0 .. $#netz) {
	my $strecke = $netz[$strecke_i];
	my $strecke_name = $netz_name[$strecke_i];
	my $flaechen_pass = $self->{FlaechenPass};

	push @layers, +{type => LAYER_TYPE_NORMAL,
			str  => $strecke,
			name => $strecke_name,
			flaechen_pass => $flaechen_pass,
		       };

	if ($strecke_name eq 'flaechen') {
	    $self->{FlaechenPass}++;
	}
    }

    {
	# Sort layers:
	# At bottom: flaechen+wasser
	# then: outlines
	# then: remaining layers
	# Preserve original sorting by using $micro_level
	my $micro_level = 0;
	@layers = (map { $_->[1] }
		   sort {
		       $a->[0] <=> $b->[0];
		   } 
		   map {
		       my $level = 0;
		       $micro_level+=0.0001;
		       if ($_->{type} eq LAYER_TYPE_OUTLINE) {
			   $level = -1;
		       } elsif ($_->{name} =~ /^(flaechen|wasser)$/) {
			   $level = -2;
		       }
		       [$level + $micro_level, $_];
		   } @layers);
    }

    for my $layer_def (@layers) {
	my($type,$str) = @{$layer_def}{qw(type str)};
	if ($type eq LAYER_TYPE_OUTLINE) {
	    $draw_outline_sub->($str);
	} else {
	    my($name,$flaechen_pass) = @{$layer_def}{qw(name flaechen_pass)};
	    $draw_normal_sub->($str, $name, $flaechen_pass);
	}
    }
    

    # $self->{Xk} bezeichnet den Vergrößerungsfaktor
    # bis etwa 0.02 ist es zu unübersichtlich, Ampeln zu zeichnen,
    # ab etwa 0.05 kann man die mittelgroße Variante nehmen
    if ($p_draw{'ampel'} && $self->{Xk} >= 0.02) {
	my $lsa = new Strassen "ampeln";
	my $suf = ($self->{Xk} >= 0.05 ? '' : '2');

	my($kl_ampel, $w_lsa, $h_lsa) = $self->read_image("ampel_klein$suf");
	my($kl_andreas, $w_and, $h_and) = $self->read_image("andreaskr_klein$suf");
	my($kl_zugbruecke, $w_zbr, $h_zbr) = $self->read_image($self->{Xk} >= 0.05 ? "zugbruecke" : "zugbruecke_klein");
	my($kl_ampelf, $w_lsaf, $h_lsaf) = $self->read_image("ampelf_klein$suf");

	if ($kl_andreas || $kl_ampel || $kl_zugbruecke || $kl_ampelf) {
	    $lsa->init;
	    while(1) {
		my $s = $lsa->next_obj;
		last if $s->is_empty;
		my $cat = $s->category;
		my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
		if ($cat =~ m{^(B|B0)$}) {
		    if ($kl_andreas) {
			$im->copy($kl_andreas, $x-$w_and/2, $y-$h_and/2, 0, 0,
				  $w_and, $h_and);
		    }
		} elsif ($cat eq 'Zbr') {
		    if ($kl_zugbruecke) {
			$im->copy($kl_zugbruecke, $x-$w_zbr/2, $y-$h_zbr/2, 0, 0,
				  $w_zbr, $h_zbr);
		    }
		} elsif (0 && $cat eq 'F') {
		    # XXX Wegen des Alpha-Channels in ampelf* nicht nutzbar.
		    # Es würde funktionieren, wenn das truecolor-Bit sowohl
		    # auf $im als auch auf $kl_ampelf gesetzt wäre.
		    # Leider bekomme ich einen Absturz bei $im mit truecolor.
		    if ($kl_ampelf) {
			$im->copy($kl_ampelf, $x-$w_lsa/2, $y-$h_lsa/2, 0, 0,
				  $w_lsa, $h_lsa);
		    }
		} elsif ($cat =~ m{^(F|X)$}) { # F: only fallback here
		    if ($kl_ampel) {
			$im->copy($kl_ampel, $x-$w_lsa/2, $y-$h_lsa/2, 0, 0,
				  $w_lsa, $h_lsa);
		    }
		}
	    }
	}
    }

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
    my %ort_font = %{ $self->get_ort_font_mapping };
    my %seen_bahnhof;
    my $strip_bhf = sub {
	my $bhf = shift;
	require Strassen::Strasse;
	$bhf =~ s/\s+\(.*\)$//; # strip text in parenthesis
	$bhf = Strasse::short($bhf, 1);
	$bhf;
    };
    foreach my $points (['ubahn', 'ubahnhof', 'u'],
			['sbahn', 'sbahnhof', 's'],
			['rbahn', 'rbahnhof', 'r'],
			['ort', 'orte',       'o'],
			['orte_city', 'orte_city', 'oc'],
		       ) {
	# check if it is advisable to draw stations...
	next if ($points->[0] =~ /bahn$/ && $self->{Xk} < 0.004);
	my $do_bahnhof = grep { $_ eq $points->[0]."name" } @{$self->{Draw}};
	if ($self->{Xk} < 0.06) {
	    $do_bahnhof = 0;
	}
	# Skip drawing if !ubahnhof, !sbahnhof or !rbahnhof is specified
	next if $str_draw{"!" . $points->[1]};

	if ($str_draw{$points->[0]}) {

	    my $brush;
	    if ($points->[2] =~ /^[sr]$/) {
		$brush = $self->{GD_Image}->new($xw_s,$yw_s);
		$brush->transparent($brush->colorAllocate(255,255,255));
		my $col = $brush->colorAllocate($im->rgb($color{'SA'}));
		$brush->arc($xw_s/2,$yw_s/2,$xw_s,$yw_s,0,360,$col);
		$brush->fill($xw_s/2,$yw_s/2,$col);
		$im->setBrush($brush);
	    }

	    my $p = ($points->[0] eq 'ort'
		     ? $self->_get_orte
		     : new Strassen $points->[1]);
	    my $type = $points->[2];

	    my($image, $image_w, $image_h);
	    if ($points->[1] =~ /^([us])bahnhof$/ && $self->{Xk} > 0.01) {
		my $type = $1;
		my $basename = "${type}bahn" . ($self->{Xk} > 0.12 ? "" :
						$self->{Xk} > 0.07 ? "_klein" : "_mini");
		($image, $image_w, $image_h) = $self->read_image($basename);
	    }

	    for my $s ($self->get_street_records_in_bbox($p)) {

		my $cat = $s->[Strassen::CAT];
		next if $cat =~ $BBBikeDraw::bahn_bau_rx;
		my($x0,$y0) = split /,/, $s->[Strassen::COORDS][0];
		my $draw_symbol = 1;
		my $pad_left;
		if ($type =~ /^[us]$/ && $image) {
		    my($x, $y) = &$transpose($x0, $y0);
		    $im->copy($image, $x-$image_w/2, $y-$image_h/2, 0, 0,
			      $image_w, $image_h);
		    $draw_symbol = 0;
		    $pad_left = int($image_w/2) + 2;
		}
		if ($type eq 'u' || ($type eq 's' && $small_display)) {
		    my($x1,$x2,$y1,$y2);
		    if (0 && !$small_display) {
			($x1, $y1) = &$transpose($x0-20, $y0-20);
			($x2, $y2) = &$transpose($x0+20, $y0+20);
		    } else {
			($x1, $y2) = &$transpose($x0, $y0);
			($x2, $y1) = ($x1+$xw_u, $y2+$yw_u);
			($x1, $y2) = ($x1-$xw_u, $y2-$yw_u);
		    }
		    # Achtung: y2 und y1 vertauschen!
		    # XXX Farbe bei small_display && s-bahn
		    if ($draw_symbol) {
			$im->filledRectangle($x1, $y2, $x2, $y1, $darkblue);
		    }
		    if ($do_bahnhof) {
			my $name = $strip_bhf->($s->[Strassen::NAME]);
			if (!$seen_bahnhof{$name}) {
			    $pad_left = 4 if !defined $pad_left;
			    $self->outline_text($ort_font{'bhf'},
						$x1+$pad_left, $y1,
						$self->patch_string($name),
						$darkblue, $grey_bg,
						-anchor => "cw",
					       );
			    $seen_bahnhof{$name}++;
			}
		    }
		} elsif ($type =~ /^[sr]$/) {
		    # XXX ausgefüllten Kreis zeichnen
		    my($x, $y) = &$transpose(split /,/, $s->[Strassen::COORDS][0]);
		    #$im->arc($x, $y, $xw_s, $yw_s, 0, 360, $darkgreen);
		    if ($draw_symbol) {
			$im->line($x,$y,$x,$y,$self->{GD}->gdBrushed());
		    }
		    if ($do_bahnhof) {
			my $name = $strip_bhf->($s->[Strassen::NAME]);
			if (!$seen_bahnhof{$name}) {
			    $pad_left = 4 if !defined $pad_left;
			    $self->outline_text($ort_font{'bhf'},
						$x+$pad_left, $y,
						$self->patch_string($name),
						$darkgreen, $grey_bg,
						-anchor => "w",
					       );
			    $seen_bahnhof{$name}++;
			}
		    }
		} else {
		    if ($cat >= $min_ort_category &&
			(!$restrict_code || $restrict_code->($s, $type))) {
			my($x, $y) = &$transpose(split /,/, $s->[Strassen::COORDS][0]);
			my $ort = $s->[Strassen::NAME];
			# Anhängsel löschen (z.B. "b. Berlin")
			$ort =~ s/\|.*$//;
			if ($type eq 'oc') {
			    $self->outline_text
				($ort_font{$cat} || $self->{GD_Font}->Small,
				 $x, $y,
				 $self->patch_string($ort), $black, $grey_bg,
				 -anchor => "c",
				);
			} else {
			    $im->arc($x, $y, 3, 3, 0, 360, $black);
			    $self->outline_text
				($ort_font{$cat} || $self->{GD_Font}->Small,
				 $x, $y,
				 $self->patch_string($ort), $black, $grey_bg,
				 -padx => 4, -pady => 4,
				);
			}
		    }
		}
	    }
	}
    }

    if (ref $self->{StrLabel} &&
#	(defined &GD::Image::stringFT || defined &GD::Image::stringTTF)
	($self->_really_can_stringFT || $im->can('stringTTF'))
       ){
	eval {
	    my $ttf = $TTF_STREET;
	    local $^W = -r $ttf; # no warnings if ttf could not be found...

	    my $fontsize = 10;
	    $Tk::RotFont::NO_X11 = 1;
	    require Tk::RotFont;

	    #my $ft_method = defined &GD::Image::stringFT ? 'stringFT' : 'stringTTF';
	    my $ft_method = $im->can('stringFT') ? 'stringFT' : 'stringTTF';

	    my $draw_sub = sub {
		my($x,$y) = &$transpose($_[0], $_[1]);
		if (defined $_[4] and defined $_[5]) {
		    $x -= $_[4];
		    $y -= $_[5];
		}

		# correct base point of text to middle:
		my $rad = -$_[3];
		my $cx = sin($rad)*$fontsize/2;
		my $cy = cos($rad)*$fontsize/2;
		$x += $cx;
		$y += $cy;
		warn "correct $cx/$cy\n" if $DEBUG;
		$im->$ft_method($black, $ttf, $fontsize, $rad, $x, $y, $_[2]);
	    };
	    my $extent_sub = sub {
		my(@b) = $self->{GD_Image}->$ft_method
		    ($black, $ttf, $fontsize, -$_[3],
		     &$transpose($_[0], $_[1]), $_[2]);
		($b[2]-$b[0], $b[3]-$b[1]);
	    };

	    #my $strecke = $multistr;
	    my $strecke = $self->_get_strassen(Strdraw => \%str_draw); # XXX Übergabe von %str_draw notwendig?
	    $strecke->init;
	    while(1) {
		my $s = $strecke->next;
		last if !@{$s->[1]};
		my $cat = $s->[2];
		next unless $cat eq 'HH' || $cat eq 'H';

		my($x1, $y1, $xe, $ye) = (@{Strassen::to_koord1($s->[1][0])},
					  @{Strassen::to_koord1($s->[1][-1])});
		next if (!(($x1 >= $self->{Min_x} and $xe <= $self->{Max_x}) and
			   ($y1 >= $self->{Min_y} and $ye <= $self->{Max_y})));
		my $str = Strassen::strip_bezirk($s->[0]);
		my $coordref = [ map { (split(/,/, $_)) } @{ $s->[1] } ];
		Tk::RotFont::rot_text_smart($str, $coordref,
					    -drawsub   => $draw_sub,
					    -extentsub => $extent_sub,
					    -transpose => $transpose,
					   );
	    }
	};
	warn $@ if $@;
    }

    $self->{TitleDraw} = $title_draw;

    $self->draw_scale unless $self->{NoScale};
}

sub get_ort_font_mapping {
    my $self = shift;

    my %ort_font;
    my $ttf = $TTF_CITY;
    if (defined $ttf) {
	my $sc = $self->{FontSizeScale} ||
	    ($self->{Xk} < 0.1 ? 1 :
	     $self->{Xk} < 0.2 ? 1.2 :
	     $self->{Xk} < 0.5 ? 1.5 : 2);
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
	%ort_font = (0 => $self->{GD_Font}->Tiny,
		     1 => $self->{GD_Font}->Small,
		     2 => $self->{GD_Font}->Small,
		     3 => $self->{GD_Font}->Large, # MediumBold sieht fetter aus
		     4 => $self->{GD_Font}->Large,
		     5 => $self->{GD_Font}->Giant,
		     6 => $self->{GD_Font}->Giant,
		     bhf => $self->{GD_Font}->Small,
		     strname => $self->{GD_Font}->Small,
		    );
    }
    \%ort_font;
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
    my($x0,$y0) = $transpose->($self->standard_to_coord(0,0));
    my($x1,$y1, $strecke, $strecke_label);
    for $strecke (10, 50, 100, 500, 1000, 5000, 10000, 20000, 50000, 100000) {
	($x1,$y1) = $transpose->($self->standard_to_coord($strecke,0));
	if ($x1-$x0 > $self->{Width}/15) {
	    if ($strecke >= 1000) {
		$strecke_label = $strecke/1000 . "km";
	    } else {
		$strecke_label = $strecke . "m";
	    }
	    last;
	}
    }

    if ($self->{GD_use_thickness}) {
	$im->setThickness(1);
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
    $self->_draw_scale_label($self->{Width}-($x1-$x0)-$x_margin-3,
			     $self->{Height}-$y_margin-$bar_width-2-12,
			     "0", $color);
    $self->_draw_scale_label($self->{Width}-$x_margin+8-6*length($strecke_label),
			     $self->{Height}-$y_margin-$bar_width-2-12,
			     $strecke_label, $color);
}

sub _draw_scale_label {
    my($self, $x, $y, $string, $color) = @_;
    my $ttf = $TTF_SCALE;
    my $im = $self->{Image};
    if ($self->{GD_Image}->can("stringFT") && -r $ttf) {
	# XXX why +8?
	$im->stringFT($color, $ttf, 8, 0, $x, $y+8, $string);
    } else {
	$im->string($self->{GD_Font}->Small,
		    $x, $y, $string, $color);
    }
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

    my $line_style;
    my $width;

    my $draw_route_polyline = sub {
	my($c1) = @_;
	# Route
	# Don't use setThickness here, because the dashed effect looks
	# strange (schraffiert).
	for(my $i = 0; $i < $#$c1; $i++) {
	    my($x1, $y1, $x2, $y2) = (@{$c1->[$i]}, @{$c1->[$i+1]});
	    my($tx1,$ty1, $tx2,$ty2) = (&$transpose($x1, $y1),
					&$transpose($x2, $y2));
	    $im->line($tx1,$ty1, $tx2,$ty2, $line_style);
	    if (defined $width) {
		my $alpha = atan2($ty2-$ty1, $tx2-$tx1);
		my $beta  = $alpha - pi()/2;
		for my $delta (-int($width/2) .. int($width/2)) {
		    next if $delta == 0;
		    my($dx, $dy) = ($delta*cos($beta), $delta*sin($beta));
		    $im->line($tx1+$dx,$ty1+$dy,$tx2+$dx,$ty2+$dy,
			      $line_style);
		}
	    }
	}
    };

    if (@{ $self->{OldCoordsC1} || [] }) {
	$im->setStyle(($red)x2,
		      ($self->{GD}->gdTransparent)x6
		     );
	$line_style = $self->{GD}->gdStyled();
	$width = 1;
	$draw_route_polyline->($self->{OldCoordsC1});
	undef $line_style;
	undef $width;
    }

    my $brush; # should be *outside* the next block!!!
    if ($self->{RouteDotted}) {
	# gepunktete Routen für die WAP-Ausgabe (B/W)
	$im->setStyle(($white)x$self->{RouteDotted},
		      ($black)x$self->{RouteDotted});
	$line_style = $self->{GD}->gdStyled();
#	$width = $width{Route};
    } elsif ($self->{RouteWidth}) {
	# fette Routen für die WAP-Ausgabe (B/W)
	$brush = $self->{GD_Image}->new($self->{RouteWidth}, $self->{RouteWidth});
	$brush->colorAllocate($im->rgb($white));
	$im->setBrush($brush);
	$line_style = $self->{GD}->gdBrushed();
    } elsif ($brush{Route}) {
	$im->setBrush($brush{Route});
	$line_style = $self->{GD}->gdBrushed();
    } else {
	# Vorschlag von Rainer Scheunemann: die Route in blau zu zeichnen,
	# damit Rot-Grün-Blinde sie auch erkennen können. Vielleicht noch
	# besser: rot-grün-gestrichelt
	$im->setStyle(($darkblue)x3,
		      ($self->{GD}->gdTransparent)x3,
		      ($red)x3,
		      ($self->{GD}->gdTransparent)x3,
		     );
	$line_style = $self->{GD}->gdStyled();
	$width = $width{Route};
    }

    for my $c1 (@multi_c1) {
	$draw_route_polyline->($c1);
    }

    # Flags
    if (@multi_c1 > 1 || ($multi_c1[0] && @{$multi_c1[0]} > 1)) {
	if ($self->{UseFlags} &&
	    $self->{GD_Image}->can("copyMerge") &&
	    $self->imagetype ne 'wbmp') {
	    my $images_dir = $self->get_images_dir;
	    my $imgfile;
	    $imgfile = "$images_dir/flag2_bl." . $self->suffix;
	    if (open(GIF, $imgfile)) {
		binmode GIF;
		my $start_flag = $self->{GD_Image}->newFromImage(\*GIF);
		close GIF;
		if ($start_flag) {
		    my($w, $h) = $start_flag->getBounds;
		    my($x, $y) = &$transpose(@{ $multi_c1[0][0] });
		    # workaround: newFromPNG vergisst die Transparency-Information
		    #$start_flag->transparent($start_flag->colorClosest(192,192,192));
		    $im->copyMerge($start_flag, $x-5, $y-15,
				   0, 0, $w, $h, 80);
		} else {
		    warn "$imgfile exists, but can't be read by GD";
		}
	    } else {
		warn "Can't open $imgfile: $!";
	    }

	    $imgfile = "$images_dir/flag_ziel." . $self->suffix;
	    if (open(GIF, $imgfile)) {
		binmode GIF;
		my $end_flag = $self->{GD_Image}->newFromImage(\*GIF);
		close GIF;
		if ($end_flag) {
		    my($w, $h) = $end_flag->getBounds;
		    my($x, $y) = &$transpose(@{ $multi_c1[-1][-1] });
		    # workaround: newFromPNG vergisst die Transparency-Information
		    #$end_flag->transparent($end_flag->colorClosest(192,192,192));
		    $im->copyMerge($end_flag, $x-5, $y-15,
				   0, 0, $w, $h, 80);
		} else {
		    warn "$imgfile exists, but can't be read by GD";
		}
	    } else {
		warn "Can't open $imgfile: $!";
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
			$self->patch_string($name),
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

    if ($self->{TitleDraw}) {
	# XXX It's difficult to decide if the font may display -> or not
	my $s = $self->make_default_title(); # Unicode => defined $TTF_TITLE);

	my $gdfont;
	if (defined $TTF_TITLE) {
	    $gdfont = [$TTF_TITLE, 10];
	} else {
	    if (7*length($s) <= $self->{Width}) {
		$gdfont = $self->{GD_Font}->MediumBold;
	    } elsif (6*length($s) <= $self->{Width}) {
		$gdfont = $self->{GD_Font}->Small;
	    } else {
		$gdfont = $self->{GD_Font}->Tiny;
	    }
	}
	my($inner, $outer) = ($darkblue, $grey_bg);
	$self->outline_text($gdfont, 1, 1, $s, $inner, $outer, -anchor => "nw");
    }
}

sub outline_text {
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
    my($self, $fontspec, $x, $y, $s, $inner, $outer, %args) = @_;
    my $im = $self->{Image};
    return if !$self->_really_can_stringFT;
    if ($args{-anchor}) {
	($x, $y) = _adjust_anchor
	    ($x, $y, $args{-anchor}, $args{-padx}||0, $args{-pady}||0,
	     sub {
		 my @bounds = $self->{GD_Image}->stringFT($inner, @$fontspec, 0, 0, 0, $s);
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
    $self->{GD_Image}->stringFT($inner, @$fontspec, 0, $x, $y, $s);
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
    } else {
	$y -= ($dy/4 + $pady);
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

# Comment only valid for older GDs without filledArc:
# Draw this first, otherwise the filling of the circle won't work!
sub draw_wind {
    my $self = shift;
    return unless $self->{Wind};
    require BBBikeCalc;
    BBBikeCalc::init_wind();
    my $richtung = lc($self->{Wind}{Windrichtung});
    if ($richtung =~ /o$/) { $richtung =~ s/o$/e/; }
    my $staerke  = $self->{Wind}{Windstaerke};
    my $im = $self->{Image};
    if ($self->{GD_use_thickness}) {
	$im->setThickness(1);
    }
    my($radx, $rady) = (10, 10);
    my $col = $darkblue;
    if ($im->can("filledArc")) {
	$im->filledArc($self->{Width}-20, 20, $radx, $rady, 0, 360, $col);
    } else {
	$im->arc($self->{Width}-20, 20, $radx, $rady, 0, 360, $col);
	$im->fill($self->{Width}-20, 20, $col);
    }
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
	        #XXX"onclick=\"return false\" ",
		">\n";
#XXXXXXXXXXXXX
# Geht jetzt auch nicht mehr mit NS4?!
	}
    }

    print $fh "</map>";
}

sub flush {
    my $self = shift;
    my %args = @_;
    my $fh = $args{Fh} || $self->{Fh};
    binmode $fh;
    print $fh $self->{Image}->imageOut;
}

sub patch_string {
    my $self = shift;
    if (defined $gd_version and $gd_version >= 1.16) {
	shift;
    } else {
	my $s = shift;
	require BBBikeUtil;
	BBBikeUtil::umlauts_to_german($s);
    }
}

sub empty_image_error {
    my $self = shift;
    my $im = $self->{Image};
    my $fh = $self->{Fh};

    $im->string($self->{GD}->gdLargeFont, 10, 10, "Karte kann nicht gezeichnet werden!", $darkblue);
    $im->string($self->{GD}->gdLargeFont, 10, 30, "Cannot draw map!", $darkblue);
    $im->string($self->{GD}->gdLargeFont, 10, 50, scalar(localtime), $darkblue);
    binmode $fh if $fh;
    if ($fh) {
	print $fh $im->imageOut;
    } else {
	print $im->imageOut;
    }
    confess "Empty image";
}

sub can_multiple_passes {
    my($self, $type) = @_;
    return $type eq 'flaechen';
}

sub read_image {
    my($self, $basename) = @_;
    my($img, $w, $h);

    my $images_dir = $self->get_images_dir;
    my $imgfile = "$images_dir/$basename." . $self->suffix;
    if (open(GIF, $imgfile)) {
	binmode GIF;
	$img = $self->{GD_Image}->newFromImage(\*GIF);
	if ($img) {
	    ($w, $h) = $img->getBounds;
	} else {
	    warn "$imgfile exists, but can't be read by GD";
	}
	close GIF;
    }
    ($img, $w, $h);
}

sub search_ttf_font {
    my($self, $candidates) = @_;
    return if !defined &GD::Image::stringFT;
    for my $font (@$candidates) {
	next if !$font;
	if (-r $font) {
	    return $font;
	}
    }
    warn "Cannot find font in candidates @$candidates" if $^W;
    undef;
}

sub _really_can_stringFT {
    my $self = shift;
    my $im = $self->{Image};
    return 0 if !$im->can('stringFT'); # for example old GD::SVG <= 0.32
    return 0 if $im->isa('GD::SVG::Image'); # GD::SVG 0.33 defines stringFT as a no-op
    1;
}

# To avoid loading of GDHeavy
sub DESTROY { }

1;
