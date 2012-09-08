# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::PDF::Cairo;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use Cairo;
use List::Util qw(sum); 

use constant DIN_A4_WIDTH => 595;
use constant DIN_A4_HEIGHT => 842;

use constant STREET_TEXT_COLUMN => 2;
use constant MINIMUM_STREET_TEXT_COLUMN_WIDTH => 100;

# Only needed for testing without Pango:
use vars qw($DONT_USE_PANGO);

sub new {
    my($class, %args) = @_;
    my $self = {};
    my $surface = delete $args{-pdf};
    if (!$surface) {
	die "-fh option is not supported yet in " . __PACKAGE__
	    if delete $args{-fh}; # XXX
	my $filename = delete $args{-filename};
	die "-filename is missing"
	    if !$filename;
	$surface = Cairo::PdfSurface->create($filename, DIN_A4_WIDTH, DIN_A4_HEIGHT);
    }
    if (keys %args) {
	die "Too much parameters to " . __PACKAGE__ . "::new";
    }

    $self->{Surface} = $surface;

    bless $self, $class;
}

sub output {
    my $self = shift;

    require Route::Descr;

    my(%args) = @_;
    my $out = Route::Descr::convert(%args);

    # Always force portrait
    $self->{Surface}->set_size(DIN_A4_WIDTH, DIN_A4_HEIGHT);

    my $cr = Cairo::Context->create($self->{Surface});
    my $page_height = DIN_A4_HEIGHT;
    my $page_width = DIN_A4_WIDTH;

#XXX how to create outlines here?
#    $pdf->new_outline('Title' => &Route::Descr::M('Routenliste'),
#		      'Destination' => $page);

    my $has_pango = !$DONT_USE_PANGO && eval { require Pango; 1 };
    if (!$has_pango) {
	# Otherwise we have to deal with non-latin Unicode characters
	require BBBikeUnicodeUtil;
    }

    my %fonts;
    my $get_font;
    if ($has_pango) {
	$get_font = sub {
	    my($font_string) = @_;
	    if (!exists $fonts{$font_string}) {
		$fonts{$font_string} = Pango::FontDescription->from_string($font_string);
	    }
	    $fonts{$font_string};
	};
    } else {
	$get_font = sub {
	    my($font_string) = @_;
	    if (!exists $fonts{$font_string}) {
		$fonts{$font_string} = ["Sans", "normal", ($font_string =~ m{bold}i ? "bold" : "normal")];
	    }
	    $fonts{$font_string};
	};
    }

    my $bold_font_description = 'DejaVu Sans Bold condensed';
    my $font_description = 'DejaVu Sans condensed';

    my $start_y = ($has_pango ? 8 : 30);
    my $y = $start_y;

    my $_string;
    if ($has_pango) {
	$_string = sub {
	    my($doit, $alignment, $text, $fontface, $size, $x0, $y0, $maxwidth) = @_;
	    return if !defined $text || !length $text;
	    return if $x0 && $x0 > $page_width;
	    my $font = $get_font->("$fontface $size");

	    my $layout = Pango::Cairo::create_layout($cr);
	    $layout->set_text($text);
	    $layout->set_font_description($font);
	    if ($alignment eq 'center') {
		$layout->set_width($page_width * Pango->scale);
	    } elsif ($maxwidth) {
		$layout->set_width($maxwidth * Pango->scale);
		$layout->set_ellipsize('end');
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
    } else {
	$_string = sub {
	    my($doit, $alignment, $text, $fontface, $size, $x0, $y0, $maxwidth) = @_;
	    return if !defined $text || !length $text;
	    return if $x0 && $x0 > $page_width;
	    my $font = $get_font->($fontface); # without $size here
	    $cr->select_font_face(@$font);
	    $cr->set_font_size($size);
	    $text = BBBikeUnicodeUtil::unidecode_string($text);
	    utf8::upgrade($text); # workaround bug in Cairo, see https://rt.cpan.org/Ticket/Display.html?id=73177
	    if ($doit) {
		my $y_advance = 0;
		if ($alignment eq 'center') {
		    my $get_centered_x0 = sub {
			my($text) = @_;
			my $extents = $cr->text_extents($text);
			($page_width - $extents->{width}) / 2 + $x0;
		    };
		    my $_x0 = $get_centered_x0->($text);
		    if ($_x0 < 0) {
			# Hack: zweizeilig ausgeben (hoffentlich reicht es!)
			my $half_text_length = int(length($text)/2);
			if (substr($text, $half_text_length) =~ m{^(\S*)(\s+)}) {
			    my($first, $second) = (
						   substr($text, 0, $half_text_length+length($1)),
						   substr($text, $half_text_length+length($1)+length($2))
						  );
			    $_x0 = $get_centered_x0->($first); $_x0 = 0 if $_x0 < 0;
			    $cr->move_to($_x0, $y0);
			    $cr->show_text($first);
			    $y_advance += $size + 2;

			    $text = $second;
			    $_x0 = $get_centered_x0->($text); $_x0 = 0 if $_x0 < 0;
			    $cr->move_to($_x0, $y0 + $size + 2);
			} else {
			    $cr->move_to(0, $y0);
			}
		    } else {
			$cr->move_to($_x0, $y0);
		    }
		} else {
		    $cr->move_to($x0, $y0);
		}
		$cr->show_text($text);
		return $y_advance + $size + 2;
	    } else {
		my $extents = $cr->text_extents($text);
		($extents->{width}, $extents->{height});
	    }
	};
    }
    my $string  = sub { $_string->(1, 'left',   @_) };
    my $stringc = sub { $_string->(1, 'center', @_) };
    my $string_width = sub { $_string->(0, 'left', @_) };

    my($head1_font_size, $head2_font_size, $font_size);
    if ($has_pango) {
	$head1_font_size = 18;
	$head2_font_size = 14;
	$font_size = 8;
    } else {
	$head1_font_size = 24;
	$head2_font_size = 18;
	$font_size = 10;
    }

    $y += $stringc->('BBBike', 'Sans Normal', $head1_font_size, 0, $y);

    if ($out->{Title}) {
	my $title = $out->{Title};
	$y += 4;
	$y += $stringc->($title, 'Sans Normal', $head2_font_size, 0, $y);
    }

    $y += 4;

    my @lines = (@{ $out->{Lines} }, $out->{Footer});

    my @max_width;
    for my $line (@lines) {
	for my $col_i (0 .. $#$line) {
	    my $cell = $line->[$col_i];
	    $cell = "" if !defined $cell;
	    my $font = ($col_i == STREET_TEXT_COLUMN ? $bold_font_description : $font_description);
	    my($this_width, undef) = $string_width->($cell, $font, $font_size);
	    if (defined $this_width && (!defined $max_width[$col_i] || $max_width[$col_i] < $this_width)) {
		$max_width[$col_i] = $this_width;
	    }
	}
    }

    my $start_x = 5;
    my $x_spacing = 10;

    my $sum_width = sum(@max_width) # all column widths
	+ $start_x*2                # both margins
	+ $x_spacing*(@max_width-1) # spacing between columns
    ;
    if ($sum_width > DIN_A4_WIDTH) {
	# reduce the street text column
	$max_width[STREET_TEXT_COLUMN] = DIN_A4_WIDTH - ($sum_width - $max_width[STREET_TEXT_COLUMN]);

	if ($max_width[STREET_TEXT_COLUMN] < MINIMUM_STREET_TEXT_COLUMN_WIDTH) {
	    # Hopefully this should never happen; the other columns
	    # should never get that broad...
	    warn "Route::PDF::Cairo: minimum column width for street name exceeded (sum_width=$sum_width), trying to save things...";
	    $max_width[STREET_TEXT_COLUMN] = MINIMUM_STREET_TEXT_COLUMN_WIDTH;
	}
    }

    for my $line (@lines) {
	my $x = $start_x;
	my $col_i = 0;
	my $max_y = 0;
	for my $col_i (0 .. $#$line) {
	    my $cell = $line->[$col_i];
	    my $font = ($col_i == STREET_TEXT_COLUMN ? $bold_font_description : $font_description);
#	    my $width = $page->my_string_width($font, $col)*$font_size;
#	    if ($x + $width > $page_width-30) {
#		#XXX TODO warn "wrap!";
#	    }
	    my $this_y = $string->($cell, $font, $font_size, $x, $y, $col_i == $#$line ? $page_width - $x : $max_width[$col_i]);
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

sub add_page_to_bbbikedraw {
    my(%args) = @_;
    my $bbbikedraw = delete $args{-bbbikedraw} || die "-bbbikedraw missing";
    my $surface = $bbbikedraw->{PDF};
    $surface->show_page;
    my $rpdf = __PACKAGE__->new(-pdf => $surface);
    $rpdf->output(%args);
}

sub flush {
    shift->{Surface}->finish;
}

1;

__END__
