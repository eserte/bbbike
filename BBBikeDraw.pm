# -*- perl -*-

#
# $Id: BBBikeDraw.pm,v 3.27 2003/06/02 22:57:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package BBBikeDraw;
use strict;
use Strassen;
# Strassen benutzt FindBin benutzt Carp, also brauchen wir hier nicht zu
# sparen:
use Carp qw(confess);

use vars qw($images_dir $VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 3.27 $ =~ /(\d+)\.(\d+)/);

sub new {
    my($pkg, %args) = @_;

    my $self = {};
    $self->{Fh}        = delete $args{Fh} || \*STDOUT;
    $self->{Filename}  = delete $args{Filename};
    $self->{Return}    = delete $args{Return};
    $self->{Geometry}  = delete $args{Geometry};
    $self->{Coords}    = delete $args{Coords}; # route coordinates
    $self->{Draw}      = delete $args{Draw};
    $self->{Scope}     = delete $args{Scope} || 'city';
    $self->{Startname} = delete $args{Startname};
    $self->{Zielname}  = delete $args{Zielname};
    $self->{Strassen}  = delete $args{Strassen};
    $self->{Wind}      = delete $args{Wind};
    $self->{NoScale}   = delete $args{NoScale};
    $self->{Bg}        = delete $args{Bg}; # "white"/"#rrggbb" . "transparent"
    $self->{UseFlags}  = delete $args{UseFlags};
    $self->{Width}     = delete $args{Width}; # boolean
    $self->{RouteWidth}= delete $args{RouteWidth}; # width of route
    $self->{RouteDotted}=delete $args{RouteDotted}; # draw dotted route
    $self->{StrLabel}  = delete $args{StrLabel};
    $self->{MakeNet}   = delete $args{MakeNet};
    $self->{ImageType} = delete $args{ImageType}; # gif, png or wbmp
    $self->{Restrict}  = delete $args{Restrict};  # restriction array
    $self->{OldImage}  = delete $args{OldImage};  # provide old image object
    $self->{OldImage}  = delete $args{GDImage}
	if $args{GDImage}; # backward compatibility for GD
    $self->{FrontierColor} = delete $args{FrontierColor}; # "red"
    $self->{CategoryWidths} = delete $args{CategoryWidths}; # a hash ref
    $self->{CategoryColors} = delete $args{CategoryColors}; # a hash ref
    $self->{Outline}   = delete $args{Outline}; # boolean
    $self->{OutlineCat} = delete $args{OutlineCat}; # array with categories
    $self->{Module}    = delete $args{Module}; # use another BBBikeDraw module
    $self->{MinPlaceCat} = delete $args{MinPlaceCat}; # force minimum place (ort) category
    $self->{FontSizeScale} = delete $args{FontSizeScale} || 1;
    $self->{Conf}      = delete $args{Conf} || 1;

    if (defined $self->{Return} &&
	$self->{Return} eq 'string') {
	if (!defined $self->{Filename}) {
	    require IO::String;
	    $self->{Fh} = IO::String->new;
	}
    }

    my $require;
    if ($self->{Module}) {
	# some king of untainting
	(my $module = $self->{Module}) =~ s/[^A-Za-z_0-9:]+//g;
	$require = $pkg = "BBBikeDraw::" . $self->{Module};
    } elsif (defined $self->{ImageType} && $self->{ImageType} =~ /^pdf$/i) {
	$require = $pkg = "BBBikeDraw::PDF";
    } elsif (defined $self->{ImageType} && $self->{ImageType} =~ /^svg$/i) {
	$require = $pkg = "BBBikeDraw::SVG";
    } elsif (defined $self->{ImageType} && $self->{ImageType} =~ /^dummy$/i) {
	# no re-blessing...
    } else {
	$require = $pkg = "BBBikeDraw::GD";
    }
    if (defined $require) {
	eval "require $require"; die $@ if $@;
    }

    bless $self, $pkg;

    my $noinit = delete $args{NoInit};

    if (keys %args) {
	warn "Warning: the following arguments are supplied, but unrecognized: " . join(", ", keys %args) . "\n";
    }

    if ($noinit) {
	$self;
    } else {
	$self->init;
    }
}

sub new_from_cgi {
    my($pkg, $q, %args) = @_;
    $args{Geometry}  = $q->param('geometry')
      if defined $q->param('geometry');
    $args{Coords}    = [ split(/[!;]/, $q->param('coords')) ]
      if defined $q->param('coords');
    $args{Draw}      = [ $q->param('draw') ]
      if defined $q->param('draw');
    $args{Scope}     = $q->param('scope')
      if defined $q->param('scope');
    $args{Startname} = $q->param('startname')
      if defined $q->param('startname');
    $args{Zielname} = $q->param('zielname')
      if defined $q->param('zielname');
    if (defined $q->param('windrichtung') &&
	defined $q->param('windstaerke')) {
	$args{Wind} = {Windrichtung => $q->param('windrichtung'),
		       Windstaerke  => $q->param('windstaerke')};
    }
    if (defined $q->param('outputtarget') and
	$q->param('outputtarget') eq 'print') {
	$args{Bg} = 'white';
    }
    $args{UseFlags} = 1;
    # Mit Width (drawwidth) werden breitere Straßen gezeichnet. Damit
    # verlangsamt sich auf meinem Celeron 466 das Zeichnen von
    # ca. 3.5 auf 4 Sekunden.
    $args{Width}    = $q->param('drawwidth')
	if defined $q->param('drawwidth');
    $args{StrLabel} = [ $q->param('strlabel') ]
	if defined $q->param('strlabel');
    $args{ImageType} = $q->param('imagetype')
	if defined $q->param('imagetype');
    $args{Module} = $q->param('module')
	if defined $q->param('module');
    $pkg->new(%args);
}

sub init {
    my $self = shift;
    if (defined $self->{Geometry}) {
	($self->{Width}, $self->{Height}) = split(/x/, $self->{Geometry});
	# support for Geometry => "*x${height}"
	if ($self->{Width} eq '*') {
	    if (!defined $self->{Min_x}) {
		die "* in Geometry/Width is only possible if set_bbox is called before init";
	    }
	    $self->{Width} = $self->{Height} * ($self->{Max_x}-$self->{Min_x}) / ($self->{Max_y}-$self->{Min_y});
	}
	# support for Geometry => "${width}x*"
	if ($self->{Height} eq '*') {
	    if (!defined $self->{Min_x}) {
		die "* in Geometry/Height is only possible if set_bbox is called before init";
	    }
	    $self->{Height} = $self->{Width} * ($self->{Max_y}-$self->{Min_y}) / ($self->{Max_x}-$self->{Min_x});
	}
    }
    $self;
}

sub pre_draw {
    my $self = shift;
    $self->{PreDrawCalled}++;
    $self->dimension_from_route;
    $self->create_transpose;
}

sub dimension_from_route {
    my $self = shift;
    my(@coords) = @{ $self->{Coords} };
    my @c1;
    my($min_x, $min_y, $max_x, $max_y);
    foreach (@coords) {
	my($x, $y) = split(/,/, $_);
	if (!defined $min_x || $x < $min_x) {
	    $min_x = $x;
	}
	if (!defined $max_x || $x > $max_x) {
	    $max_x = $x;
	}
	if (!defined $min_y || $y < $min_y) {
	    $min_y = $y;
	}
	if (!defined $max_y || $y > $max_y) {
	    $max_y = $y;
	}
	push @c1, [$x,$y];
    }

    if ((!defined $max_x && !defined $min_x) ||
	$max_x == $min_x || $max_y == $min_y) {
	$self->empty_image_error;
    }

    # etwas Luft lassen
    $min_x -= int(0.06*($max_x-$min_x));
    $min_y -= int(0.06*($max_y-$min_y));
    $max_x += int(0.06*($max_x-$min_x));
    $max_y += int(0.06*($max_y-$min_y));

    $self->{Min_x} = $min_x;
    $self->{Min_y} = $min_y;
    $self->{Max_x} = $max_x;
    $self->{Max_y} = $max_y;
    $self->{C1}    = \@c1;
}

sub set_bbox {
    my $self = shift;
    my @bbox = @_;
    # turn it the right way...
    if ($bbox[0] > $bbox[2]) {
	@bbox[0,2] = @bbox[2,0];
    }
    if ($bbox[1] > $bbox[3]) {
	@bbox[1,3] = @bbox[3,1];
    }
    ($self->{Min_x}, $self->{Min_y}, $self->{Max_x}, $self->{Max_y}) = @bbox;
}

# Old, obsolete, but still supported version of set_bbox:
sub set_dimension { shift->set_bbox($_[0], $_[2], $_[1], $_[3]) }

# Setzt die Dimension so, dass die Koordinaten des Strassen-Objekts
# komplett gezeichnet werden können.
sub set_bbox_max {
    my($self, $str) = @_;
    $str->init;
    my($min_x, $min_y, $max_x, $max_y);
    while(1) {
	my $s = $str->next_obj;
	last if $s->is_empty;
	for(my $i = 0; $i <= $#{$s->coords}; $i++) {
	    my($x, $y) = @{$s->coord_as_list($i)};
	    if (!defined $min_x || $x < $min_x) {
		$min_x = $x;
	    }
	    if (!defined $max_x || $x > $max_x) {
		$max_x = $x;
	    }
	    if (!defined $min_y || $y < $min_y) {
		$min_y = $y;
	    }
	    if (!defined $max_y || $y > $max_y) {
		$max_y = $y;
	    }
	}
    }
    $self->set_bbox($min_x, $min_y, $max_x, $max_y);
}

# Alias for old method name:
sub set_dimension_max { shift->set_bbox_max(@_) }

# If
#    -asstring => 1
# is set, create also TransposeCode and AntiTransposeCode.
sub create_transpose {
    my($self, %args) = @_;
    my($w, $h) = ($self->{Width}, $self->{Height});
    my($min_x, $min_y, $max_x, $max_y) =
      ($self->{Min_x}, $self->{Min_y}, $self->{Max_x}, $self->{Max_y});
    my($xk, $yk) = ($w/($max_x-$min_x), $h/($max_y-$min_y));
    my $aspect = ($max_x-$min_x)/($max_y-$min_y);
    my($delta_x, $delta_y) = ($min_x, $min_y);
    if ($aspect < $w/$h) {
	$xk *= $aspect/($w/$h);
	$delta_x -= ($w/$xk-$max_x+$min_x)/2;
    } else {
	$yk /= $aspect/($w/$h);
	$delta_y -= ($h/$yk-$max_y+$min_y)/2;
    }

    my($transpose, $anti_transpose);

    my($code, $anti_code);
    if ($self->isa("BBBikeDraw::PDF")) {
	# Ursprung ist unten, nicht oben
#XXX Konstanten konstant machen! siehe unten... s// nicht vergessen
	$code = <<'EOF';
	sub {
	    my($x, $y) = @_;
	    ($x-$delta_x)*$xk, ($y-$delta_y)*$yk;
	};
EOF
	$transpose = eval $code;
	die $@ if $@;

	$anti_code = <<'EOF';
	sub {
	    my($x, $y) = @_;
	    (($x/$xk)+$delta_x, (-$y)/$yk+$delta_y); # XXX y???
	};
EOF
        $anti_transpose = eval $anti_code;
	die "$anti_code: $@" if $@;
    } else {
	$code = <<EOF;
	sub {
	    my(\$x, \$y) = \@_;
	    ((\$x-$delta_x)*$xk, $h-(\$y-$delta_y)*$yk);
	};
EOF
        $code =~ s/--/+/g;
	$code =~ s/\+-/-/g;
        $transpose = eval $code;
	die "$code: $@" if $@;

	$anti_code = <<EOF;
	sub {
	    my(\$x, \$y) = \@_;
	    ((\$x/$xk)+$delta_x, ($h-\$y)/$yk+$delta_y);
	};
EOF
        $anti_code =~ s/--/+/g;
	$anti_code =~ s/\+-/-/g;
        $anti_transpose = eval $anti_code;
	die "$anti_code: $@" if $@;
    }

    $self->{Transpose}     = $transpose;
    $self->{AntiTranspose} = $anti_transpose;

    if ($args{-asstring}) {
	$self->{TransposeCode}     = $code;
	$self->{AntiTransposeCode} = $anti_code;
    }

    $self->{Xk} = $xk;
    $self->{Yk} = $yk;
}

sub set_category_colors {
    my $self = shift;
    my $pkg = ref $self;

    if ($self->{CategoryColors}) {
	eval '%'.$pkg.'::color = %{$self->{CategoryColors}}';
	die $@ if $@;
	return;
    }

    eval "package $pkg;\n" . <<'EOF';

    %color = (B  => $red,
	      H  => $yellow,
	      HH => $yellow,
	      N  => $white,
	      NN => $green,
	      S  => $darkgreen,
	      SA => $darkgreen,
	      SB => $darkgreen,
	      SC => $darkgreen,
	      R  => $darkgreen,
	      RA => $darkgreen,
	      RB => $darkgreen,
	      RC => $darkgreen,
	      U  => $darkblue,
	      UA => $darkblue,
	      UB => $darkblue,
	      W  => $lightblue,
	      W1 => $lightblue,
	      W2 => $lightblue,
	      I  => $grey_bg,
	      F  => $white,
	      Ae => $white,
	      P  => $middlegreen,
	      Z  => $self->{FrontierColor} eq 'red' ? $red : $black,
	      '?' => $black,
	      '??' => $black,
	      Route => $red,
	     );
EOF
    die $@ if $@;
}

sub set_category_outline_colors {
    my $self = shift;
    my $pkg = ref $self;

    if ($self->{CategoryOutlineColors}) {
	eval '%'.$pkg.'::outline_color = %{$self->{CategoryOutlineColors}}';
	die $@ if $@;
	return;
    }

    eval "package $pkg;\n" . <<'EOF';

    %outline_color = (B  => $black,
		      H  => $black,
		      HH => $black,
		      N  => $black,
		      NN => $black,
		      W  => $darkblue,
		      W1 => $darkblue,
		      W2 => $darkblue,
		     );

    if ($self->{OutlineCat}) {
	my %notseen = %outline_color;
	foreach my $cat (@{ $self->{OutlineCat} }) {
	    delete $notseen{$cat};
	}
	delete $outline_color{$_} for (keys %notseen);
    }
EOF
    die $@ if $@;
}

sub get_color {
    my($self, $colorname) = @_;
    my $pkg = ref $self;
    my $i;
    my $code = "\$i = \$".$pkg."::$colorname";
    #warn $code;
    eval $code;
    warn $@ if $@;
    $i;
}

sub set_category_widths {
    my $self = shift;
    my $m = shift || 1;
    my $pkg = ref $self;

    if ($self->{CategoryWidths}) {
	eval '%'.$pkg.'::width = %{$self->{CategoryWidths}}';
	die $@ if $@;
	return;
    }

    eval "package $pkg;\n" . <<'EOF';

    %width = (B  => 3*$m,
	      H  => 3*$m,
	      HH => 3*$m,
	      N  => 2*$m,
	      NN => 2*$m,
	      S  => 2*$m,
	      SA => 2*$m,
	      SB => 2*$m,
	      SC => 2*$m,
	      R  => 2*$m,
	      RA => 2*$m,
	      RB => 2*$m,
	      RC => 2*$m,
	      U  => 2*$m,
	      UA => 2*$m,
	      UB => 2*$m,
	      W  => 2*$m,
	      W1 => 3*$m,
	      W2 => 2*$m,
	      Z  => 1*$m,
	      Route => 3*$m,
	     );
EOF
    die $@ if $@;
}

sub set_draw_elements {
    my $self = shift;

    foreach (@{$self->{Draw}}) {
	if ($_ eq 'all') {
	    $self->{Draw} = ['title', 'ampel', 'berlin', 'wasser',
			     'faehren',
			     'flaechen', 'ubahn', 'sbahn', 'rbahn', 'str',
			     'ort', 'wind',
			     'strname', 'ubahnname', 'sbahnname'];
	    if ($self->{Scope} =~ /^(wide)?region$/) {
		push @{ $self->{Draw} }, 'landstr';
	    }
	    last;
	}
    }

}

sub _get_nets {
    my($self) = @_;

    # Netze zeichnen
    my @netz;
    my @outline_netz;
    my(%str_draw, $title_draw, %p_draw);

    foreach (@{$self->{Draw}}) {
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

    # data files with absolute paths (user supplied)
    foreach my $f (@{$self->{Draw}}) {
	if ($f =~ m|^/|) {
	    push @netz, new Strassen $f;
	}
    }

    # Reihenfolge (von unten nach oben):
    # Berlin-Grenze, Gewässer, Straßen, U-, S-Bahn
    foreach (
	     ['berlin_area',      'berlin_area'],
	     ['berlin',           'berlin'],
	     ['potsdam',          'potsdam'],
	     ['deutschland',      'deutschland'],
	     ['flaechen',         'flaechen'],
	    ) {
	push @netz, new Strassen $_->[0] if $str_draw{$_->[1]}
    }
    if ($str_draw{'wasser'}) {
	my $wasser = $self->_get_gewaesser(Strdraw => \%str_draw);
	push @netz, $wasser;
#XXX not yet, siehe auch comment bei PDF.pm
#	push @outline_netz, $wasser;
    }
    my $multistr = $self->_get_strassen(Strdraw => \%str_draw);
    if ($str_draw{'str'}) {
	push @netz, $multistr;
	push @outline_netz, $multistr;
    }
    if ($str_draw{'fragezeichen'}) {
	eval {
	    # XXX don't hardcode path
	    push @netz,
		new Strassen "/home/e/eserte/src/bbbike/misc/fragezeichen";
	};
	warn $@ if $@;
    }
    foreach (
	     ['ubahn',           'ubahn'],
	     ['sbahn',           'sbahn'],
	     ['rbahn',           'rbahn'],
	    ) {
	push @netz, new Strassen $_->[0] if $str_draw{$_->[1]}
    }

    $self->{_Net} = \@netz;
    $self->{_OutlineNet} = \@outline_netz;
    $self->{_StrDraw} = \%str_draw;
    $self->{_PDraw} = \%p_draw;
    $self->{_TitleDraw} = $title_draw;
}

sub _get_strassen {
    my($self, %args) = @_;
    my $multistr = $self->{Strassen};
    if (!defined $multistr) {
	my $str = new Strassen "strassen";
	if ($self->{Scope} =~ /^(wide)?region$/) {
	    my @s = ($str);
	    push @s, new Strassen "landstrassen";
	    if ($self->{Scope} eq 'wideregion') {
		push @s, new Strassen "landstrassen2";
	    }
	    $multistr = new MultiStrassen @s;
	} else {
	    $multistr = $str;
	}
    }
    $multistr;
}

sub _get_gewaesser {
    my($self, %args) = @_;
    my $multistr;
    my $wstr = new Strassen "wasserstrassen";
    if ($self->{Scope} =~ /^(wide)?region$/) {
	my @w = ($wstr);
	push @w, new Strassen "wasserumland";
	if ($self->{Scope} eq 'wideregion') {
	    push @w, new Strassen "wasserumland2";
	}
	$multistr = new MultiStrassen @w;
    } else {
	$multistr = $wstr;
    }
    $multistr;
}

sub _get_orte {
    my($self, %args) = @_;
    my $multistr;
    my $ostr = new Strassen "orte";
    if ($self->{Scope} eq 'wideregion') {
	my @o = ($ostr);
	push @o, new Strassen "orte2";
	$multistr = new MultiStrassen @o;
    } else {
	$multistr = $ostr;
    }
    $multistr;
}

sub suffix {
    shift->{ImageType};
}

sub imagetype {
    shift->{ImageType};
}

sub mimetype {
    my $self = shift;
    if ($self->{ImageType} =~ /^svg$/) {
	"image/svg+xml";
    } else {
	($self->{ImageType} =~ /^pdf$/ ? "application" : "image") . "/"
	    . $self->{ImageType};
    }
}

sub get_images_dir {
    if (!defined $images_dir) {
	require File::Basename;
	$images_dir = $INC{'BBBikeDraw.pm'};
	if ($images_dir ne '') {
	    $images_dir = File::Basename::dirname($images_dir);
	} else {
	    $images_dir = "/home/e/eserte/src/bbbike";
	}
	$images_dir .= "/images";
    }
    $images_dir;
}

1;
