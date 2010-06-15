# -*- perl -*-

#
# $Id: GDHeavy.pm,v 1.6 2005/02/25 01:35:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeDraw::GDHeavy;
# needs BBBikeDraw::GD preloaded

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

package BBBikeDraw::GD;
use Strassen::Core;
use GD;
use VectorUtil qw(get_polygon_center);

use vars qw(%color_to_index);

# recognizes:
#   [$r,$g,$b]
#   "#rrggbb" (as hex)
#   "rrr,ggg,bbb" (as decimal)
sub _get_gd_color {
    my $def = shift;
    if (ref $def eq 'ARRAY') {
	$def
    } elsif ($def =~ /^\#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/) {
	(hex($1), hex($2), hex($3));
    } elsif ($def =~ /^(\d+),(\d+),(\d+)$/) {
	($1, $2, $3);
    } else {
	die "Can't match color `$def'";
    }
}

sub _get_color_index {
    my $def = shift;
    $color_to_index{ join(",", _get_gd_color($def)) };
}

sub allocate_layer_colors {
    my($self, $bgcolor, @layers) = @_;
    my $im = $self->{Image};
    {
	my(@rgb) = _get_gd_color($bgcolor);
	$color_to_index{join(",",@rgb)} = $im->colorAllocate(@rgb);
    }
    for my $layer_def (@layers) {
	my @colors;
	push @colors, $layer_def->{Fill}    if $layer_def->{Fill};
	push @colors, $layer_def->{Outline} if $layer_def->{Outline};
	if ($layer_def->{TypeFill}) {
	    while(my($k,$v) = each %{ $layer_def->{TypeFill} }) {
		push @colors, $v;
	    }
	}
	if ($layer_def->{Dash}) {
	    push @colors, split(/;/, $layer_def->{Dash});
	}
	for my $color (@colors) {
	    next if $color eq 'transparent';
	    my(@rgb) = _get_gd_color($color);
	    my $rgb = join(",",@rgb);
	    if (!exists $color_to_index{$rgb}) {
		$color_to_index{$rgb} = $im->colorAllocate(@rgb);
	    }
	}
    }
}

sub draw_layers {
    my $self = shift;
    my @layers = @_;

    for my $layer_def (@layers) {
	my $type = $layer_def->{Type} || 'line';
	warn "Draw layer type $type...\n";
	my $meth = "draw_" . $type . "_layer";
	$self->$meth($layer_def);
    }
}

sub draw_line_layer {
    my($self, $layer_def) = @_;

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    my $str       = $layer_def->{Streets} || die "Streets object missing";
    my $fill      = exists $layer_def->{Fill} ? _get_color_index($layer_def->{Fill}) : undef;
    if ($layer_def->{Dash}) {
	my(@colors) = map {
	    if ($_ eq 'transparent') {
		gdTransparent;
	    } else {
		_get_color_index($_);
	    }
	} split /;/, $layer_def->{Dash};
	$im->setStyle(@colors);
	$fill = gdStyled;
    }
    if (!defined $fill) {
	die "Fill or Dash option missing";
    }
    my $width     = $layer_def->{Width} || 1;
    my $brush; # XXX GD bug: $brush has to be in this scope
    if ($width > 1) {
	$brush = GD::Image->new($width, $width);
	if ($layer_def->{Dash}) {
	    $brush->colorAllocate(0,0,0); # XXX?
	    $fill = gdStyledBrushed;
	} else {
	    $brush->colorAllocate(_get_gd_color($layer_def->{Fill}));
	    $fill = gdBrushed;
	}
	$im->setBrush($brush);
    }

    $str->init;
    while(1) {
	my $r = $str->next;
	my $coords = $r->[Strassen::COORDS];
	last if !@{ $coords };
	for(my $i = 0; $i < $#{$coords}; $i++) {
	    my($x1t, $y1t) = $transpose->(@{Strassen::to_koord1($coords->[$i])});
	    my($x2t, $y2t) = $transpose->(@{Strassen::to_koord1($coords->[$i+1])});
	    $im->line($x1t,$y1t,$x2t,$y2t, $fill);
	}
    }
}

sub draw_polygon_layer {
    my($self, $layer_def) = @_;

    my $str       = $layer_def->{Streets} || die "Streets object missing";
    my($fill, $meth);
    if ($layer_def->{Fill}) {
	$fill = _get_color_index($layer_def->{Fill});
	$meth = "filledPolygon";
    } elsif ($layer_def->{Outline}) {
	$fill = _get_color_index($layer_def->{Outline});
	$meth = "polygon";
    } else {
	die "Fill or Outline option missing";
    }

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    $str->init;
    while(1) {
	my $r = $str->next;
	my $coords = $r->[Strassen::COORDS];
	last if !@{ $coords };
	my $poly = GD::Polygon->new();
	for(my $i = 0; $i <= $#{$coords}; $i++) {
	    $poly->addPt($transpose->(@{Strassen::to_koord1($coords->[$i])}));
	}
	$im->$meth($poly, $fill);
    }
}

sub draw_arctext_layer {
    my($self, $layer_def) = @_;

    my $str       = $layer_def->{Streets} || die "Streets object missing";
    my %typefill;
    while(my($k,$v) = each %{ $layer_def->{TypeFill} }) {
	$typefill{$k} = _get_color_index($v);
    }

    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};

    $str->init;
    while(1) {
	my $r = $str->next;
	my $coords = $r->[Strassen::COORDS];
	last if !@{ $coords };
	my(undef, $type, undef, undef, $text, $height, $angle, undef, $justify, $fonttype, $slant) = split /:/, $r->[Strassen::NAME];
	my($x, $y) = $transpose->(@{Strassen::to_koord1($coords->[0])});
	if ($type == 3 || $type == 16) { # Hauptstraßen, Bahnhöfe
	    $im->stringFT($typefill{$type}, $TTF_STREET, $height/4, -$angle/180 * pi, $x, $y, $text);
	}
    }
}

sub draw_custom_places {
    my($self, $mapping_str) = @_;
    my(@l) = split /;/, $mapping_str;
    my %mapping;
    for (@l) {
	$_ = [split /,/, $_];
	$mapping{$_->[0]} = { @{$_}[1..$#$_] };
    }
    my $im        = $self->{Image};
    my $transpose = $self->{Transpose};
    my $p = $self->_get_orte;

    my $cp = Strassen->new("orte_city");
    $cp->init;
    while(1) {
	my $s = $cp->next_obj;
	last if $s->is_empty;
	if ($s->name eq 'Mitte') {
	    $p->push(["Berlin", $s->coords, $s->category]);
	}
    }

    my %ort_font = %{ $self->get_ort_font_mapping };
    $p->init;
    $BBBikeDraw::GD::grey_bg = $BBBikeDraw::GD::grey_bg; # peacify -w
    while(1) {
	my $s = $p->next_obj;
	last if $s->is_empty;
	my $cat = $s->category;
	my($x0,$y0) = @{$s->coord_as_list(0)};
	my($x, $y) = &$transpose(@{$s->coord_as_list(0)});
	my $ort = $s->name;
	# Anhängsel löschen (z.B. "b. Berlin")
	$ort =~ s/\|.*$//;
	next if !exists $mapping{$ort};
	$im->arc($x, $y, 3, 3, 0, 360, $BBBikeDraw::GD::black);
	$self->outline_text
	    ($ort_font{$cat} || &GD::Font::Small,
	     $x, $y,
	     BBBikeDraw::GD->patch_string($ort),
	     $BBBikeDraw::GD::black, $BBBikeDraw::GD::grey_bg,
	     -padx => 4, -pady => 2,
	     -anchor => $mapping{$ort}->{-anchor},
	    );
    }
}

1;

__END__
