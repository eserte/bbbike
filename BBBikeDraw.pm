# -*- perl -*-

#
# $Id: BBBikeDraw.pm,v 3.63 2009/01/11 23:35:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2008 Slaven Rezic. All rights reserved.
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

use vars qw($images_dir $VERSION $bahn_bau_rx);

$VERSION = sprintf("%d.%02d", q$Revision: 3.63 $ =~ /(\d+)\.(\d+)/);

$bahn_bau_rx = qr{^[SRU](0|Bau|G|P)$}; # auch ignorieren: Güterbahnen, Parkbahnen

sub new {
    my($pkg, %args) = @_;

    my $self = {};
    $self->{Fh}        = delete $args{Fh} || \*STDOUT;
    $self->{Filename}  = delete $args{Filename};
    $self->{Return}    = delete $args{Return};
    $self->{Geometry}  = delete $args{Geometry};
    $self->{Coords}    = delete $args{Coords}; # route coordinates
    $self->{MultiCoords} = delete $args{MultiCoords}; # same for interrupted routes
    $self->{OldCoords}   = delete $args{OldCoords}; # optional for an alternative route
    $self->{MarkerPoint} = delete $args{MarkerPoint};
    $self->{BBBikeRoute} = delete $args{BBBikeRoute}; # route as from bbbike.cgi
    $self->{Draw}      = delete $args{Draw};
    $self->{Scope}     = delete $args{Scope} || 'city';
    $self->{Startname} = delete $args{Startname};
    $self->{Zielname}  = delete $args{Zielname};
    $self->{Strassen}  = delete $args{Strassen};
    $self->{Wind}      = delete $args{Wind};
    $self->{NoScale}   = delete $args{NoScale};
    $self->{Bg}        = delete $args{Bg}; # "white"/"#rrggbb" . "transparent"
    $self->{UseFlags}  = delete $args{UseFlags};
#XXX del???    $self->{Width}     = delete $args{Width}; # boolean # XXX hmmm, this is not in use? because of Width/Height members???
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
    $self->{FontSizeScale} = delete $args{FontSizeScale};
    $self->{Conf}      = delete $args{Conf};
    $self->{CGI}       = delete $args{CGI};
    $self->{Compress}  = delete $args{Compress};
    $self->{Lang}      = delete $args{Lang};
    $self->{Geo}       = delete $args{Geo};

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
	$pkg = "BBBikeDraw::" . $self->{Module};
	if ($pkg->can("init")) {
	    # already loaded...
	} else {
	    $require = $pkg;
	}
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
    my @coords = $q->param('coords');
    if (@coords == 1) {
	$args{Coords} = [ split(/[!; ]/, $coords[0]) ];
    } elsif (@coords > 1) {
	$args{MultiCoords} = [ map { [ split(/[!; ]/, $_) ] } @coords ];
    }
    my @oldcoords = $q->param('oldcoords');
    $args{OldCoords} = [ split(/[!; ]/, $oldcoords[0]) ] if @oldcoords;
    $args{MarkerPoint} = $q->param('markerpoint')
      if defined $q->param('markerpoint');
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
#XXX del???
#     # Mit Width (drawwidth) werden breitere Straßen gezeichnet. Damit
#     # verlangsamt sich auf meinem Celeron 466 das Zeichnen von
#     # ca. 3.5 auf 4 Sekunden.
#     $args{Width}    = $q->param('drawwidth')
# 	if defined $q->param('drawwidth');
    $args{StrLabel} = [ $q->param('strlabel') ]
	if defined $q->param('strlabel');
    $args{ImageType} = $q->param('imagetype')
	if defined $q->param('imagetype');
    $args{Module} = $q->param('module')
	if defined $q->param('module');
    $args{CGI} = $q;
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
    if (!defined $self->{Min_x}) { # XXX condition may be dangerous
	$self->dimension_from_route;
    } #else {
	$self->_set_c1;
    #}
    $self->create_transpose;
}

sub _set_c1 {
    my $self = shift;

    if ($self->{MultiCoords}) {
	my @multi_c1;
	for my $elem (@{ $self->{MultiCoords} }) {
	    my @c1;
	    for (@$elem) {
		my($x, $y) = split /,/, $_;
		push @c1, [$x, $y];
	    }
	    push @multi_c1, \@c1;
	}
	$self->{MultiC1} = \@multi_c1;
    } elsif ($self->{Coords}) {
	my(@coords) = @{ $self->{Coords} };
	my @c1;
	foreach (@coords) {
	    my($x, $y) = split(/,/, $_);
	    push @c1, [$x,$y];
	}
	$self->{C1} = \@c1;
	$self->{MultiC1} = [ $self->{C1} ];
    }

    if ($self->{OldCoords}) {
	my @oldcoords_c1;
	foreach (@{ $self->{OldCoords} }) {
	    my($x, $y) = split(/,/, $_);
	    push @oldcoords_c1, [$x,$y];
	}
	$self->{OldCoordsC1} = \@oldcoords_c1;
    }
}

sub dimension_from_route {
    my $self = shift;
    #my(@coords) = @{ $self->{Coords} };
    my @coords = $self->{MultiCoords} ? map { @$_ } @{ $self->{MultiCoords} } : @{ $self->{Coords} };
#    my @c1;
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
#	push @c1, [$x,$y];
    }

    if (!defined $max_x && !defined $min_x) {
	$self->empty_image_error;
    }

    {
	# Support for one point routes: show an area of about
	# 1000x1000 meters:
	my $min_bbox = 1000;
	if ($max_x == $min_x) {
	    $min_x -= $min_bbox/2;
	    $max_x += $min_bbox/2;
	}
	if ($max_y == $min_y) {
	    $min_y -= $min_bbox/2;
	    $max_y += $min_bbox/2;
	}
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
#    $self->{C1}    = \@c1;
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
    {
	# prefill min/max values, so we don't need to check for
	# definedness in the loop
	my $r = $str->peek;
	my @c = @{ $r->[Strassen::COORDS] };
	if (@c) {
	    my($x,$y) = split /,/, $c[0];
	    $min_x = $max_x = $x;
	    $min_y = $max_y = $y;
	}
    }
    while(1) {
	my $r = $str->next;
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;
	for my $c (@c) {
	    my($x, $y) = split /,/, $c;
	    $min_x = $x if $x < $min_x;
	    $max_x = $x if $x > $max_x;
	    $min_y = $y if $y < $min_y;
	    $max_y = $y if $y > $max_y;
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
    my $geo = $self->{Geo};
    my $has_custom_coord_to_standard = $geo && $geo->can('coord_to_standard'); # XXX maybe check also for coordsys != bbbike
    my($min_x, $min_y, $max_x, $max_y) =
      ($self->{Min_x}, $self->{Min_y}, $self->{Max_x}, $self->{Max_y});
    if ($has_custom_coord_to_standard) {
	($min_x, $min_y) = $geo->coord_to_standard($min_x, $min_y);
	($max_x, $max_y) = $geo->coord_to_standard($max_x, $max_y);
    }
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
    if ($self->origin_position eq 'sw') {
	# Ursprung ist unten, nicht oben (z.B. PDF)
	if ($has_custom_coord_to_standard) {
	    $code = <<EOF;
	sub {
	    my(\$x,\$y) = \$geo->coord_to_standard(\@_);
	    ((\$x-$delta_x)*$xk, (\$y-$delta_y)*$yk);
	};
EOF
	} else {
	    $code = <<EOF;
	sub {
	    ((\$_[0]-$delta_x)*$xk, (\$_[1]-$delta_y)*$yk);
	};
EOF
	}
        $code =~ s/--/+/g;
	$code =~ s/\+-/-/g;
	#warn $code;
	$transpose = eval $code;
	die "$code: $@" if $@;

	if ($has_custom_coord_to_standard) {
	    $anti_code = <<EOF;
	sub {
	    my(\$x,\$y) = ((\$_[0]/$xk)+$delta_x, (\$_[1]/$yk)+$delta_y);
	    \$geo->standard_to_coord(\$x,\$y);
	};
EOF
	} else {
	    $anti_code = <<EOF;
	sub {
	    ((\$_[0]/$xk)+$delta_x, (\$_[1]/$yk)+$delta_y);
	};
EOF
	}
        $anti_code =~ s/--/+/g;
	$anti_code =~ s/\+-/-/g;
	#warn $anti_code;
        $anti_transpose = eval $anti_code;
	die "$anti_code: $@" if $@;
    } else { # origin_positon eq 'nw'
	if ($has_custom_coord_to_standard) {
	    $code = <<EOF;
	sub {
	    my(\$x,\$y) = \$geo->coord_to_standard(\@_);
	    ((\$x-$delta_x)*$xk, $h-(\$y-$delta_y)*$yk);
	};
EOF
	} else {
	    $code = <<EOF;
	sub {
	    ((\$_[0]-$delta_x)*$xk, $h-(\$_[1]-$delta_y)*$yk);
	};
EOF
	}
        $code =~ s/--/+/g;
	$code =~ s/\+-/-/g;
        $transpose = eval $code;
	die "$code: $@" if $@;

	if ($has_custom_coord_to_standard) {
	    $anti_code = <<EOF;
	sub {
	    my(\$x,\$y) = ((\$_[0]/$xk)+$delta_x, ($h-\$_[1])/$yk+$delta_y);
	    \$geo->standard_to_coord(\$x,\$y);
	};
EOF
	} else {
	    $anti_code = <<EOF;
	sub {
	    ((\$_[0]/$xk)+$delta_x, ($h-\$_[1])/$yk+$delta_y);
	};
EOF
	}
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

    $self->{TransposeJS} = _transpose_perl_to_js($code);
    # warn $self->{TransposeJS};

    # Correct bounding box:
    #warn "before: $self->{Min_x},$self->{Min_y} $self->{Max_x},$self->{Max_y}";
    $self->set_bbox($anti_transpose->(0,0),$anti_transpose->($w, $h));
    #warn "after: $self->{Min_x},$self->{Min_y} $self->{Max_x},$self->{Max_y}";

    # Bei 100dpi ist Xk=1 <=> 1km=1000 Pixel
    $self->{Xk} = $xk;
    $self->{Yk} = $yk;
}

sub _transpose_perl_to_js {
    my $code = shift;
    $code =~ s{\bsub\b}{function (x,y)};
    $code =~ s{\$_\[0\]}{x}g;
    $code =~ s{\$_\[1\]}{y}g;
    $code =~ s<\{><{return new Array>;
    $code;
}

sub get_color_values {
    my $self = shift;

#    my $GREY = 153;
    my $GREY = 225;

    my %c; # for color mapping
    my @c; # for order

    if ($self->can('imagetype') && $self->imagetype eq 'wbmp') {
	# black-white image for WAP
	$c{black} = $c{grey_bg} = $c{darkgrey} = [0, 0, 0];
	$c{white} = $c{yellow} = $c{lightyellow} = $c{red} = $c{green} = $c{darkgreen} =
	    $c{darkblue} = $c{lightblue} = $c{middlegreen} = $c{lightgreen} = $c{rose} = [255,255,255];
	@c = qw(black grey_bg white yellow lightyellow red green darkgreen
		darkblue lightblue middlegreen lightgreen rose darkgrey);
	return (\%c, \@c);
    }

    $self->{'Bg'} = '' if !defined $self->{'Bg'};
    if ($self->{'Bg'} =~ /^white/) {
	# Hintergrund weiß: Nebenstraßen werden grau,
	# Hauptstraßen dunkelgelb gezeichnet
	$c{grey_bg}   = [255,255,255,
			 $self->{'Bg'} =~ /transparent$/ ? 1 : 0];
	$c{white}     = [$GREY,$GREY,$GREY];
	$c{yellow}    = [180,180,0];
	$c{lightyellow}    = [180,180,100];
	@c = qw(grey_bg white yellow lightyellow);
    } elsif ($self->{'Bg'} =~ /^\#([a-f0-9]{2})([a-f0-9]{2})([a-f0-9]{2})/i) {
	my($r,$g,$b) = (hex($1), hex($2), hex($3));
	$c{grey_bg}   = [$r,$g,$b,
			 $self->{'Bg'} =~ /transparent$/ ? 1 : 0];
	@c = qw(grey_bg);
    } else {
	$c{grey_bg}   = [$GREY,$GREY,$GREY,
			 $self->{'Bg'} =~ /transparent$/ ? 1 : 0];
	@c = qw(grey_bg);
    }

    if (!defined $c{white}) {
	$c{white}   = [255,255,255];
	push @c, "white";
    }
    if (!defined $c{yellow}) {
	$c{yellow}  = [255,255,0];
	push @c, "yellow";
    }
    if (!defined $c{lightyellow}) {
	$c{lightyellow} = [0xff, 0xff, 0x90];
	push @c, 'lightyellow';
    }
    $c{red}         = [255,0,0];
    $c{green}       = [0,255,0];
    $c{darkgreen}   = [0,128,0];
    $c{darkblue}    = [0,0,128];
    $c{lightblue}   = [186,213,247];
    #$c{lightblue}   = [0xa0,0xa0,0xff];
    $c{middlegreen} = [0, 200, 0];
    $c{lightgreen}  = [200, 255, 200];
    $c{rose}        = [215, 184, 200];
    $c{black}       = [0, 0, 0];
    $c{darkgrey}    = [0x63,0x63,0x63];
    push @c, qw(red green darkgreen darkblue lightblue middlegreen lightgreen rose black darkgrey);

    (\%c, \@c);
}

sub set_category_colors {
    my $self = shift;
    my $pkg = ref $self;

    if ($self->{CategoryColors}) {
	eval '%'.$pkg.'::color = %{$self->{CategoryColors}}';
	die $@ if $@;
	return;
    }

    local $^W; # $self->{FrontierColor}
    my $code = "package $pkg;\n" . <<'EOF';

    %color = (B  => $red,
	      HH => $yellow,
	      H  => $yellow,
	      NH => $lightyellow,
	      N  => $white,
	      NN => $lightgreen,
	      S  => $darkgreen,
	      SA => $darkgreen,
	      SB => $darkgreen,
	      SC => $darkgreen,
	      SBau => $green,
	      S0 => $green,
	      R  => $darkgreen,
	      RA => $darkgreen,
	      RB => $darkgreen,
	      RC => $darkgreen,
	      RG => $darkgreen,
	      RBau => $green,
	      R0 => $green,
	      RP => $darkgreen,
	      U  => $darkblue,
	      UA => $darkblue,
	      UB => $darkblue,
	      UBau => $lightblue,
	      U0 => $lightblue,
	      W  => $lightblue,
	      W0 => $lightblue,
	      W1 => $lightblue,
	      W2 => $lightblue,
	      I  => $grey_bg,
	      F  => $white,
	      Ae => $white,
	      'ex-Ae' => $white,
	      P  => $middlegreen,
	      Pabove => $middlegreen,
	      Forest  => $middlegreen,
	      Forestabove => $middlegreen,
	      Cemetery  => $middlegreen,
	      Green  => $middlegreen,
	      Orchard  => $middlegreen,
	      Sport  => $middlegreen,
	      Industrial => $rose,
	      Mine => $white,
	      Z  => $self->{FrontierColor} eq 'red' ? $red : $black,
	      '?' => $black,
	      '??' => $black,
	      Route => $red,
	      OldRoute => $grey_bg, # XXX check!
	     );
EOF
    eval $code;
    die "$code: $@" if $@;
}

sub set_category_outline_colors {
    my $self = shift;
    my $pkg = ref $self;

    if ($self->{CategoryOutlineColors}) {
	eval '%'.$pkg.'::outline_color = %{$self->{CategoryOutlineColors}}';
	die $@ if $@;
	return;
    }

    my $code = "package $pkg;\n" . <<'EOF';

    %outline_color = (B  => $black,
		      HH => $black,
		      H  => $black,
		      NH => $darkgrey,
		      N  => $darkgrey,
		      NN => $darkgrey,
		      W  => $darkblue,
		      W0 => $darkblue,
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
    eval $code;
    die "$code: $@" if $@;
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

    my $code = "package $pkg;\n" . <<'EOF';

    %width = (B  => 3*$m,
	      HH => 3*$m,
	      H  => 3*$m,
	      NH => 2*$m,
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
	      RG => 1*$m,
	      RBau => 1*$m,
	      R0 => 1*$m,
	      RP => 1*$m,
	      U  => 2*$m,
	      UA => 2*$m,
	      UB => 2*$m,
	      W  => 2*$m,
	      W0 => 1*$m,
	      W1 => 3*$m,
	      W2 => 4*$m,
	      Z  => 1*$m,
	      Route => 3*$m,
	      OldRoute => 3*$m, # XXX check
	     );
EOF
    eval $code;
    die "$code: $@" if $@;
}

sub set_draw_elements {
    my $self = shift;

    foreach (@{$self->{Draw}}) {
	if ($_ eq 'all') {
	    $self->{Draw} = ['title', 'ampel', 'berlin', 'wasser',
			     'faehren',
			     'flaechen', 'ubahn', 'sbahn', 'rbahn', 'str',
			     'ort', 'wind',
			     'strname', 'ubahnname', 'sbahnname',
			     'radwege', 'qualitaet', 'handicap', 'blocked',
			     'mount'];
	    if ($self->{Scope} =~ /^(wide)?region$/) {
		push @{ $self->{Draw} }, 'landstr';
	    }
	    last;
	}
    }

}

sub _get_nets {
    my($self) = @_;

    # Draw nets
    # Old style, will be removed some day:
    my @netz;
    my @netz_name;
    my @outline_netz;
    # New style:
    my @layers; # array elements: [Strassen object, net name, is_outline]

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
	    my $s = Strassen->new($f);
	    push @netz, $s,
	    push @netz_name, $f;
	    push @layers, [$s, $f, 0];
	}
    }

    # Reihenfolge (von unten nach oben):
    # Berlin-Grenze, Gewässer, Straßen, U-, S-Bahn
    foreach my $def (
	     ['berlin_area',      'berlin_area'],
	     ['berlin',           'berlin'],
	     ['potsdam',          'potsdam'],
	     ['deutschland',      'deutschland'],
	     ['flaechen',         'flaechen'],
	    ) {
	if ($str_draw{$def->[1]}) {
	    my $s = Strassen->new($def->[0]);
	    push @netz, $s;
	    push @netz_name, $def->[1];
	    push @layers, [$s, $def->[1], 0];
	}
    }
    if ($str_draw{'wasser'}) {
	my $wasser = $self->_get_gewaesser(Strdraw => \%str_draw);
	push @netz, $wasser;
	push @netz_name, 'wasser';
	push @layers, [$wasser, 'wasser', 1];
	push @layers, [$wasser, 'wasser', 0];
#XXX not yet, siehe auch comment bei PDF.pm
#	push @outline_netz, $wasser;
	if ($self->can_multiple_passes("flaechen") && $str_draw{"flaechen"}) {
	    my $s = Strassen->new("flaechen");
	    push @netz, $s;
	    push @netz_name, 'flaechen';
	    push @layers, [$s, 'flaechen', 0];
	}
    }
    my $multistr = $self->_get_strassen(Strdraw => \%str_draw);
    if ($str_draw{'str'}) {
	push @netz, $multistr;
	push @outline_netz, $multistr;
	push @netz_name, 'str';
	push @layers, [$multistr, 'str', 1];
	push @layers, [$multistr, 'str', 0];
    }
    if ($str_draw{'fragezeichen'}) {
	eval {
	    my $s = Strassen->new("fragezeichen");
	    push @netz, $s;
	    push @netz_name, 'fragezeichen';
	    push @layers, [$s, 'fragezeichen', 0];
	};
	warn $@ if $@;
    }
    foreach my $def (
	     ['ubahn',           'ubahn'],
	     ['sbahn',           'sbahn'],
	     ['rbahn',           'rbahn'],
	    ) {
	my($file, $type) = @$def;
	if ($str_draw{$type}) {
	    my $s = Strassen->new($file);
	    push @netz, $s;
	    push @netz_name, $type;
	    push @layers, [$s, $type, 0];
	}
    }

    $self->{_Net} = \@netz;
    $self->{_OutlineNet} = \@outline_netz;
    $self->{_NetName} = \@netz_name;
    $self->{_Layers} = \@layers;
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
    my $self = shift;
    $self->{ImageType} eq 'jpeg' ? 'jpg' : $self->{ImageType};
}

sub imagetype {
    shift->{ImageType};
}

sub mimetype {
    my $self = shift;
    if ($self->{ImageType} =~ /^svg$/) {
	"image/svg+xml";
    } elsif ($self->{ImageType} =~ /^wbmp$/) {
	"image/vnd.wap.wbmp";
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

sub module_handles_all_cgi { 0 }

sub origin_position { "nw" }

sub is_in_map {
    my($self, @coords) = @_;
    my $i;
    for($i = 0; $i<$#coords; $i+=2) {
	return 1 if ($coords[$i]   >= 0 &&
		     $coords[$i]   <= $self->{Width} &&
		     $coords[$i+1] >= 0 &&
		     $coords[$i+1] <= $self->{Height});
    }
    return 0;
}

sub make_default_title {
    my($self, %args) = @_;
    my $start = $self->{Startname};
    $start = $self->patch_string($start) if $self->can("patch_string");
    my $ziel  = $self->{Zielname};
    $ziel = $self->patch_string($ziel) if $self->can("patch_string");
    local $^W; # ignore warnings if $start or $ziel undef
    foreach my $s (\$start, \$ziel) {
	# Text in Klammern entfernen, damit der Titel kürzer wird
	my(@s) = split(m|/|, $$s);
	foreach (@s) {
	    s/\s+\(.*\)$//;
	}
	$$s = join("/", @s);
    }
    my $s =  "$start " . ($args{Unicode} ? chr(0x2190) : "->") . " $ziel";
    $s;
}

sub get_street_records_in_bbox {
    my($self, $streets) = @_;
    my %seen;
    my $grid_width = 1000;
    # XXX I should really use quadtrees...
    if ($self->{Max_x}-$self->{Min_x} > 100000 ||
	$self->{Max_y}-$self->{Min_y} > 100000) {
	$grid_width = 10000;
    }
    $streets->make_grid(UseCache => 1,
			GridWidth => $grid_width, GridHeight => $grid_width,
		       );
    my @grids = $streets->get_new_grids($self->{Min_x}, $self->{Min_y},
					$self->{Max_x}, $self->{Max_y},
				       );
    $streets->sort_records_by_cat
	([map  { $seen{$_}++;
		 $streets->get($_) }
	  grep { !$seen{$_} }
	  map  {
	      $streets->{Grid}{$_} ? @{ $streets->{Grid}{$_} } : ()
	  } @grids
	 ]);
}

sub can_multiple_passes {
    my($self, $type) = @_;
    0;
}

sub standard_to_coord {
    my($self, $sx, $sy) = @_;
    my $geo = $self->{Geo};
    if ($geo && $geo->can('standard_to_coord')) {
	$geo->standard_to_coord($sx, $sy);
    } else {
	($sx, $sy);
    }
}

1;

__END__

# Modules based on BBBikeDraw should be named C<BBBikeDraw::I<Type>>.
