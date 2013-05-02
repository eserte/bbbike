# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Quite obsolete code to create imagemaps with a mouseover effect
# This effect relies on setting self.status per javascript, but
# major browsers don't support this feature anymore. See
# http://www.w3schools.com/jsref/prop_win_status.asp

# The code is mainly preserved because the polygon
# calculation might be useful in other places.

package BBBikeDraw::ImageMap;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Carp qw(confess);

sub make_imagemap {
    my $bbbikedraw = shift;
    my $fh = shift || confess "No file handle supplied";
    my(%args) = @_;

    if (!defined $bbbikedraw->{Width} &&
	!defined $bbbikedraw->{Height}) {
	if ($bbbikedraw->{Geometry} =~ /^(\d+)x(\d+)$/) {
	    ($bbbikedraw->{Width}, $bbbikedraw->{Height}) = ($1, $2);
	}
    }

    my $transpose = $bbbikedraw->{Transpose};
    my $multistr = $bbbikedraw->_get_strassen; # XXX Übergabe von %str_draw?

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
	    next unless is_in_map($bbbikedraw, @polygon1);

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

sub is_in_map {
    my($bbbikedraw, @coords) = @_;
    my $i;
    for($i = 0; $i<$#coords; $i+=2) {
	return 1 if ($coords[$i]   >= 0 &&
		     $coords[$i]   <= $bbbikedraw->{Width} &&
		     $coords[$i+1] >= 0 &&
		     $coords[$i+1] <= $bbbikedraw->{Height});
    }
    return 0;
}

1;

__END__
