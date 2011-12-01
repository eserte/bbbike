# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::PDF::Cairo;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Cairo;
use Pango;

use constant DIN_A4_WIDTH => 595;
use constant DIN_A4_HEIGHT => 842;

sub new {
    my($class, %args) = @_;
    my $self = {};
    die "-pdf option not supported in " . __PACKAGE__
	if delete $args{-pdf};
    die "-fh option is not supported yet in " . __PACKAGE__
	if delete $args{-fh}; # XXX
    my $filename = delete $args{-filename};
    die "-filename is missing"
	if !$filename;
    if (keys %args) {
	die "Too much parameters to " . __PACKAGE__ . "::new";
    }

    my $surface = Cairo::PdfSurface->create($filename, DIN_A4_WIDTH, DIN_A4_HEIGHT);
    $self->{Surface} = $surface;

    bless $self, $class;
}

sub output {
    my $self = shift;

    require Route::Descr;

    my(%args) = @_;
    my $out = Route::Descr::convert(%args);

    my $cr = Cairo::Context->create($self->{Surface});
    my $page_height = DIN_A4_HEIGHT;

#XXX how to create outlines here?
#    $pdf->new_outline('Title' => &Route::Descr::M('Routenliste'),
#		      'Destination' => $page);

    my %fonts;
    my $get_font = sub {
	my($font_string) = @_;
	if (!exists $fonts{$font_string}) {
	    $fonts{$font_string} = Pango::FontDescription->from_string($font_string);
	}
	$fonts{$font_string};
    };

    my $bold_font_description = 'DejaVu Sans Bold condensed';
    my $font_description = 'DejaVu Sans condensed';

    my $start_y = 8;
    my $y = $start_y;

    my $_string = sub {
	my($doit, $alignment, $fontface, $size, $x0, $y0, $text) = @_;
	return if !defined $text || !length $text;
	my $font = $get_font->("$fontface $size");

	my $layout = Pango::Cairo::create_layout($cr);
	$layout->set_text($text);
	$layout->set_font_description($font);
	if ($alignment eq 'center') {
	    $layout->set_width(DIN_A4_WIDTH * Pango->scale);
	}
	$layout->set_alignment($alignment);
	if ($doit) {
	    $cr->move_to($x0, $y0);
	    Pango::Cairo::show_layout($cr, $layout);
	    return (($layout->get_size)[1]) / Pango->scale;
	} else {
	    map { $_/Pango->scale } $layout->get_size;
	}
    };
    my $string  = sub { $_string->(1, 'left',   @_) };
    my $stringc = sub { $_string->(1, 'center', @_) };
    my $string_width = sub { $_string->(0, 'left', @_) };

    $y += $stringc->('Sans Normal', 18, 0, $y, 'BBBike');

    if ($out->{Title}) {
	my $title = $out->{Title};
	my $head2_font_size = 14;
	$y += 4;
	$y += $stringc->('Sans Normal', 14, 0, $y, $title);
    }

    $y += 4;

    my @lines = (@{ $out->{Lines} }, $out->{Footer});

    my $font_size = 8;
    my @max_width;
    for my $line (@lines) {
	for my $col_i (0 .. $#$line) {
	    my $col = $line->[$col_i];
	    $col = "" if !defined $col;
	    my $font = ($col_i == 2 ? $bold_font_description : $font_description);
	    my($this_width, undef) = $string_width->($font, $font_size, 0, 0, $col);
	    if (defined $this_width && (!defined $max_width[$col_i] || $max_width[$col_i] < $this_width)) {
		$max_width[$col_i] = $this_width;
	    }
	}
    }

    my $start_x = 30;
    my $x_spacing = 10;

    for my $line (@lines) {
	my $x = $start_x;
	my $col_i = 0;
	my $max_y = 0;
	for my $col_i (0 .. $#$line) {
	    my $col = $line->[$col_i];
	    my $font = ($col_i == 2 ? $bold_font_description : $font_description);
#	    my $width = $page->my_string_width($font, $col)*$font_size;
#	    if ($x + $width > $page_width-30) {
#		#XXX TODO warn "wrap!";
#	    }
	    my $this_y = $string->($font, $font_size, $x, $y, $col);
	    $max_y = $this_y if defined $this_y && (!defined $max_y || $max_y < $this_y);
	    if ($max_width[$col_i]) {
		$x += $max_width[$col_i]+$x_spacing;
	    }
	    $col_i++;
	}
	$y += $max_y;
	if ($y > DIN_A4_HEIGHT-$start_y-$start_y-10) {
	    $cr->show_page;
	    $y = $start_y;
	}
    }

    $cr->show_page;
}

sub flush {
    shift->{Surface}->finish;
}

1;

__END__
