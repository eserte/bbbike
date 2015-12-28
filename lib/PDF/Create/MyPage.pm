# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2004,2009,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package PDF::Create::MyPage;

use strict;
use vars qw($VERSION);
$VERSION = '1.06';

######################################################################
# Additional PDF::Create methods

package PDF::Create::Page;

if (!defined &PI) {
    eval 'use constant PI => 4 * atan2(1, 1);';
    die $@ if $@;
}

if (!defined &set_stroke_color) {
    # In newer PDF::Create versions, setrgbcolorstroke exists.
    # However, setrgbcolorstroke does not remember the current stroke
    # color, and would generate too many RG instructions if called
    # repeatedly with the same values.
    *set_stroke_color = sub {
	my($page, $r, $g, $b) = @_;
	return if (defined $page->{'current_stroke_color'} &&
		   $page->{'current_stroke_color'} eq join(",", $r, $g, $b));
	$page->{'pdf'}->page_stream($page);
	$page->{'pdf'}->add("$r $g $b RG");
	$page->{'current_stroke_color'} = join(",", $r, $g, $b);
    };
}

if (!defined &set_fill_color) {
    # Counterpart in PDF::Create is setrgbcolor. Same comment as for
    # setrgbcolorstroke is true here, too.
    *set_fill_color = sub {
	my($page, $r, $g, $b) = @_;
	return if (defined $page->{'current_fill_color'} &&
		   $page->{'current_fill_color'} eq join(",", $r, $g, $b));
	$page->{'pdf'}->page_stream($page);
	$page->{'pdf'}->add("$r $g $b rg");
	$page->{'current_fill_color'} = join(",", $r, $g, $b);
    };
}

if (!defined &set_line_width) {
    # Counterpart in PDF::Create is set_width. Same comment as for
    # setrgbcolorstroke is true here, too.
    *set_line_width = sub {
	my($page, $w) = @_;
	return if (defined $page->{'current_line_width'} &&
		   $page->{'current_line_width'} == $w);
	$page->{'pdf'}->page_stream($page);
	$page->{'pdf'}->add("$w w");
	$page->{'current_line_width'} = $w;
    };
}

if (!defined &set_dash_pattern) {
    # Missing in PDF::Create 1.24
    *set_dash_pattern = sub {
	my($page, $array, $phase) = @_;
	$phase = 0 if !defined $phase;
	my $pdf = $page->{'pdf'};
	$pdf->page_stream($page);
	$pdf->add("[@$array] $phase d");
    };
}

if (!defined &circle) {
    # Missing in PDF::Create 1.24
    *circle = sub {
	my($page, $x, $y, $r) = @_;

	my @coords;
	for(my $i = 0; $i < PI()*2; $i+=PI()*2/$r/2) {
	    my($xi,$yi) = map { $_*$r } (sin $i, cos $i);
	    push @coords, $x+$xi, $y+$yi;
	}
	push @coords, @coords[0,1];
	@coords = map { sprintf "%.2f", $_ } @coords;

	$page->moveto(shift @coords, shift @coords);
	for(my $i = 0; $i <= $#coords; $i+=2) {
	    $page->lineto($coords[$i], $coords[$i+1]);
	}
	$page->stroke;
    }
}

# Override the original string_width method, because it uses wrong
# width tables (maybe based on a non-iso-8859-1 font?). See also
# https://rt.cpan.org/Ticket/Display.html?id=110723
my $font_widths = {};
sub my_string_width {
    my $self   = shift;
    my $font   = shift;
    my $string = shift;

    my $fname = $self->{'pdf'}{'fonts'}{$font}{'BaseFont'}[1];
    if (!exists $font_widths->{$fname}) {
	(my $modname = $fname) =~ s/[^a-zA-Z]//;
	$modname = "Font::Metrics::$modname";
	my @wx = eval qq{ require $modname; \@${modname}::wx };
	if (@wx) {
	    $font_widths->{$fname} = [ map { int($_*1000) } @wx ];
	    # Font::AFM uses ISOLatin1Encoding, whereas PDF::Create
	    # typically sets WinAnsiEncoding. These two are almost the
	    # same, except for hyphen vs. minus and some other diffs,
	    # try:
	    #
	    #    perl -MPostScript::WinANSIEncoding -MFont::AFM -e '@w=PostScript::WinANSIEncoding->array; @l= @Font::AFM::ISOLatin1Encoding; for my $ch (0..255) { if ($w[$ch] ne $l[$ch]) { print "$ch $w[$ch] $l[$ch]\n"}}'
	    #
	    # Fix only the most problematic one, hyphen vs. minus:
	    $font_widths->{$fname}[ord("-")] = $font_widths->{$fname}[173];
	} else {
	    # fallback to original
	    return $self->string_width($font, $string);
	}
    }

    my $w = 0;
    for my $c (split '', $string) {
	$w += $$font_widths{$fname}[ord $c];
    }
    $w / 1000;
}

1;

__END__
