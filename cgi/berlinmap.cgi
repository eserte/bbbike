#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: berlinmap.cgi,v 2.6 2000/04/12 23:21:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use CGI;

$query = new CGI;

# XXX kann man es relativ rauskriegen?
$flagurl = "http://localhost/~eserte/bbbike/images/flag2_bl.gif";

$fsroot  = "/usr/www/berlin";
$wwwroot = "http:/berlin";

eval { local $SIG{'__DIE__'};
       do "$0.config" };

if ($0 =~ /brandenburg/) {
    $xfrom = 'a';
    $xto   = 'v';
    $yfrom = 2;
    $yto   = 22;
    $index_xstep = 73;
    $index_ystep = 60;
    $border = 80; # nur für Map-Berechnung
    $xstep = 453;
    $ystep = 374;
    $type = 'brandenburg';
    *imgname = \&brb_imgname;
    # in $0.config konfigurierbare Variablen
    $fsdir = "$fsroot/gismap";
    $wwwdir = "$wwwroot/gismap";
} else {
    $yfrom  = 'a';
    $yto    = 'z';
    $xfrom  = 0;
    $xto    = 28;
    $xstep  = 640;
    $ystep  = 600;
    $border = 105;
    $index_xstep = 32;
    $index_ystep = 30;
    $type = 'berlin';
    *imgname = \&berlin_imgname;
    # in $0.config konfigurierbare Variablen
    $fsdir = "$fsroot/map";
    $wwwdir = "$wwwroot/map";
}

if (!$query->param) {
    &index;
}
else {
    &showmap;
}

sub index {
    print
      $query->header,
      $query->start_html(-title => 'Stadtplan von ' . ucfirst($type),
			 -BGCOLOR => 'white');
    print <<EOF;
<center>
<img src="$wwwdir/index.gif" usemap="#map">
<map name="map">
EOF

    $ycoor = ($type eq 'brandenburg' ? ($yto-$yfrom)*$index_ystep : 0);
    for $y ($yfrom .. $yto) {
        $xcoor = 0;
	for $x ($xfrom .. $xto) {
	    if (-r fsimgname($y, $x)) {
		print
		  "<area shape=rect coords=\"$xcoor,$ycoor,",
		  ($xcoor+$index_xstep-1) . "," . ($ycoor+$index_ystep-1),
		  "\" target=mapwin href=\"$ENV{SCRIPT_NAME}?y=$y&x=$x\">\n";
	    }
	    $xcoor += $index_xstep;
	}
	print "\n";
	$ycoor += ($type eq 'brandenburg' ? -1 : 1) * $index_ystep;
    }

    print <<EOF;
</map>
</center>
EOF
    print $query->end_html;
}

sub showmap {
    $y    = $query->param('y') || 'o';
    if ($type eq 'brandenburg') {
	$up   = $y+1;
	$down = $y-1;
    } else {
	$up   = chr(ord($y)-1);
	$down = chr(ord($y)+1);
    }

    $x     = $query->param('x') || 13;
    if ($type eq 'brandenburg') {
	$left  = chr(ord($x)-1);
	$right = chr(ord($x)+1);
    } else {
	$left  = $x-1;
	$right = $x+1;
    }

    print
      $query->header,
      $query->start_html(-title => 'Quadrant ' . uc($y) . $x,
			 -BGCOLOR => 'white');
    print '<!-- <center> -->
<img src="';
    print httpimgname($y, $x);
    print <<EOF;
" usemap="#map"><br>
<!-- <a href="$ENV{SCRIPT_NAME}">Übersicht</a> -->
<!-- </center> -->
<!-- Leider werden bei 'width="100%"' die Koordinaten der Map nicht umgerechnet -->

<map name="map">
EOF
    my($x1, $x2, $y1, $x2);
    if ($type eq 'brandenburg') {
	($x1, $x2, $y1, $y2) = ($xstep-$border, $xstep,
				$ystep-$border, $ystep);
    } else {
	$x1 = $border+$xstep;
	$x2 = $border*2+$xstep;
	$y1 = $border+$ystep;
	$y2 = $border*2+$ystep;
    }

    print qq{<area shape=rect coords="0,0,$border,$border" href="$ENV{SCRIPT_NAME}?y=$up&x=$left">\n}     if -r fsimgname($up, $left);
    print qq{<area shape=rect coords="0,$border,$border,$y1" href="$ENV{SCRIPT_NAME}?y=$y&x=$left">\n}    if -r fsimgname($y, $left);
    print qq{<area shape=rect coords="0,$y1,$border,$y2" href="$ENV{SCRIPT_NAME}?y=$down&x=$left">\n} if -r fsimgname($down, $left);

    print qq{<area shape=rect coords="$border,0,$x1,$border" href="$ENV{SCRIPT_NAME}?y=$up&x=$x">\n}     if -r fsimgname($up, $x);
    print qq{<area shape=rect coords="$border,$border,$x1,$y1" nohref>\n};
    print qq{<area shape=rect coords="$border,$y1,$x1,$y2" href="$ENV{SCRIPT_NAME}?y=$down&x=$x">\n} if -r fsimgname($down, $x);

    print qq{<area shape=rect coords="$x1,0,$x2,$border" href="$ENV{SCRIPT_NAME}?y=$up&x=$right">\n}     if -r fsimgname($up, $right);
    print qq{<area shape=rect coords="$x1,$border,$x2,$y1" href="$ENV{SCRIPT_NAME}?y=$y&x=$right">\n}    if -r fsimgname($y, $right);
    print qq{<area shape=rect coords="$x1,$y1,$x2,$y2" href="$ENV{SCRIPT_NAME}?y=$down&x=$right">\n} if -r fsimgname($down, $right);

    print <<EOF;
</map>
EOF
    if (defined $query->param('yy') and defined $query->param('xx')) {
	# Die Verschiebung ist notwendig, damit die Stange der Flagge
	# genau auf dem Punkt erscheint.
	my($xx, $yy) = ($query->param('xx')-5, $query->param('yy')-16);
	# XXX <div> bei nicht DHTML-fähigen Browsern ignorieren
	print <<EOF;
<div id=mark style="position:absolute"><img src="$flagurl"></div>
<script language=javascript>
<!--
if (document.layers) {
    document.layers.mark.moveTo($xx, $yy);
    if (window.innerHeight && window.innerWidth) {
        window.scrollTo($xx-window.innerWidth/2, $yy-window.innerHeight/2);
    }
} else if (document.all) {
    document.all.mark.style.left = $xx;
    document.all.mark.style.top = $yy;
    document.all.mark.scrollIntoView("true");
}
// -->
</script>
EOF
    }
    print $query->end_html;
}

sub berlin_imgname {
    my($y, $x, $dir) = @_;
    my $imgname = $dir . sprintf "%s%02d.gif", $y, $x;
    $imgname;
}

sub brb_imgname {
    my($y, $x, $dir) = @_;
    my $imgname = $dir . sprintf "%s%02d.gif", $x, $y;
    $imgname;
}

sub fsimgname {
    "$fsdir/" . imgname(@_);
}

sub httpimgname {
    "$wwwdir/" . imgname(@_);
}

__END__

Verwendung von Javascript:
- 640x600-Bilder (ohne Border) erzeugen
- ein Kartenteil darstellen, alle anderen mit blank.gif darstellen
- wenn sich die Maus in einen anderen Kartenteil bewegt und dieser Kartenteil
  noch immer blank.gif ist, wird das aktuelle Bild geladen. Kartenteil
  zentrieren
  (onMouseOver, images, scroll)
