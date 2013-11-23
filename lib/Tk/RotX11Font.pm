# -*- perl -*-

#
# $Id: RotX11Font.pm,v 1.15 2005/11/05 22:42:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998, 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

#
# Creating rotated fonts on perl/Tk canvases.
#

#
# This code needs Tk800+ and X11::Protocol to run.
#

package main;
use vars qw($x11); # $x11 should hold the X11::Protocol object

package Tk::RotX11Font;
use Tk;
use Tk::Font 3.017;
use strict;
use vars qw(%font_cache);

sub new {
    my($pkg, $text, $f_sub, $size, $rad) = @_;
    my $self = {};
    ($self->{Font}, $self->{'Xadd'}, $self->{'Yadd'})
      = get_font_attrib($text, $f_sub, $size, $rad);
    $self->{Text} = $text;
    bless $self, $pkg;
}

sub writeCanvas {
    my($rotfont, $c, $x, $y, $tags, $text) = @_;
    my $xadd_ref = $rotfont->{Xadd};
    my $yadd_ref = $rotfont->{Yadd};
    $text = $rotfont->{Text} if !defined $text;
    for(split(//, $text)) {
	my $item = $c->createText
	  ($x, $y, -text => $_, -font => $rotfont->{Font},
	   -anchor => 'w',
	   (defined $tags ? (-tags => $tags) : ()));
	$x+=$xadd_ref->[ord($_)];
	$y+=$yadd_ref->[ord($_)];
    }
    ($x, $y);
}

#
# Write a rotated text once on a canvas
#
# Arguments:
# $c     - canvas
# $x, $y - start coordinates
# $f_sub - template for font as a sub reference, something like:
#          sub { "-adobe-helvetica-medium-r-normal--0-" . $_[0] .
#                "-0-0-p-0-iso8859-1" }
# $size  - point- (or pixel?)size
# $rad   - angle in radians
# $text  - text for output
# $tags  - (optional) tags
#
# Returns coordinate ($x, $y) of the position of textcursor after drawing.
#
sub writeRot {
    my($c, $x, $y, $f_sub, $size, $rad, $text, $tags) = @_;
    my($f, $xadd_ref, $yadd_ref) = get_font_attrib($text, $f_sub, $size, $rad);
    for(split(//, $text)) {
#warn "font=$f\n";
	my $item = $c->createText($x, $y, -text => $_, -font => $f,
				  -anchor => 'w',
				  (defined $tags ? (-tags => $tags) : ()));
	$x+=$xadd_ref->[ord($_)];
	$y+=$yadd_ref->[ord($_)];
    }
    ($x, $y);
}

# Returns an array with the generated X11 font name, and references
# to the per-character X-Add- and Y-Add-arrays
sub get_font_attrib {
    my($text, $f_sub, $size, $rad) = @_;
    my($mat) = get_matrix($size, $rad);
    my %chars_used = map { (ord($_), 1) } split(//, $text);
    my $chars_used = join(" ", sort {$a <=> $b } keys %chars_used);
    # X11R6- oder X11::Protocol-Bug? Font-Struktur muß mehr als ein
    # Zeichen enthalten!
    if (scalar keys %chars_used == 1) {
	$chars_used .= " " . ((keys(%chars_used))[0] == 32 ? 33 : 32);
    }
    my $f = $f_sub->($mat);
    #warn "FONT: $f\n";
    $f .= "[$chars_used]";
    my($xadd_ref, $yadd_ref) = get_x11font_resources($f, \%chars_used);
    ($f, $xadd_ref, $yadd_ref);
}

sub get_matrix {
    my($size, $r) = @_;
    my($mat);
    foreach ($size*cos($r), $size*sin($r), $size*-sin($r), $size*cos($r)) {
	s/-/~/g;
	if ($mat) { $mat .= " " }
	$mat .= $_;
    }
    "[" . $mat . "]";
}

sub x_y_extent {
    my($rotfont, $text) = @_;
    my $x = 0; 
    my $y = 0;
    my $xadd_ref = $rotfont->{Xadd};
    my $yadd_ref = $rotfont->{Yadd};
    $text = $rotfont->{Text} if !defined $text;
    foreach (split(//, $text)) {
	$x += $xadd_ref->[ord($_)];
	$y += $yadd_ref->[ord($_)];
    }
    ($x, $y);
}

sub get_x_y_extent {
    my($text, $f_sub, $size, $rad) = @_;
    my($f, $xadd_ref, $yadd_ref) = get_font_attrib($text, $f_sub, $size, $rad);
    my $x = 0; 
    my $y = 0;
    foreach (split(//, $text)) {
	$x += $xadd_ref->[ord($_)];
	$y += $yadd_ref->[ord($_)];
    }
    ($x, $y);
}


sub get_x11font_resources {
    my $font = shift;

    my $chars_used_ref = shift;
    my $fid = $main::x11->new_rsrc;
    $main::x11->OpenFont($fid, $font);
    my(%res) = $main::x11->QueryFont($fid);
#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%res],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

    my @x;
    foreach (keys %{$res{'properties'}}) {
	my $atom_name = $main::x11->atom_name($_);
#	warn "$atom_name $res{'properties'}->{$_} " . eval { $main::x11->atom_name($res{'properties'}->{$_}) };
	if ($atom_name eq 'FONT') {
	    my $realfont;
	    $realfont = $main::x11->atom_name($res{'properties'}->{$_});
	    my(@f) = split(/-/, $realfont);
	    @x = split(/\s/, substr($f[7], 1, length($f[7])-2));
	    foreach (@x) { s/~/-/g }
	    last;
	}
    }

    my(@font_xadd);
    my(@font_yadd);
    $#font_xadd = 255;
    $#font_yadd = 255;
    foreach (keys %$chars_used_ref) {
	my $attr = $res{'char_infos'}->[$_-$res{'min_char_or_byte2'}]->[5];
# XXX if $attr == 0 use SPACING instead???
	my($x, $y) = ($attr/1000*$x[0], -$attr/1000*$x[1]);
	$font_xadd[$_] = $x;
	$font_yadd[$_] = $y;
    }
    $main::x11->CloseFont($fid);

    $font_cache{$font} = [\@font_xadd, \@font_yadd]; # XXX create dup?
    (\@font_xadd, \@font_yadd);
}

return 1 if caller();

######################################################################

package main;
use Tk;
use X11::Protocol;

MAIN: {
    my $top = new MainWindow;
    $x11 = X11::Protocol->new();

    my $font = shift || "adobe-helvetica";
    #$font = "adobe-utopia";
    my $size = shift || 24;

    my $f_sub = sub { "-$font-medium-r-normal--0-" 
			. $_[0] . "-0-0-p-0-iso8859-1" };

    my $c = $top->Canvas(-width => 500,
			 -height => 500)->pack;

#     my $start = time;
#     for(my $deg = -180; $deg <= 180; $deg+=15) {
# 	my $d = $deg;
# 	my $r = _deg2rad($d);
# 	my $text = "         $deg Müller";
# #	my $rotfont = new Tk::RotX11Font $text, $f_sub, $size, $r;
# #	$rotfont->writeCanvas($c, 250, 250);
# 	Tk::RotX11Font::writeRot($c, 250, 250, $f_sub, $size, $r, $text);
# 	printf STDERR "(x/y) at %4d° = (" . 
# 	  join("/", Tk::RotX11Font::get_x_y_extent($text, $f_sub, $size, $r)) .
# 	    ")\n", $d;
#     }
#     warn "Time: " . (time-$start) . " seconds\n";

    Tk::RotX11Font::writeRot($c, 250, 250, $f_sub, $size, _deg2rad(90), "90°");
    MainLoop;
}

sub _deg2rad {
    $_[0]/180*3.141592653;
}

__END__

Regeln, die ein Labeling-Programm für Straßen einhalten sollte/muß:

* Straßennamen aufteilen. Der Teil mit "str." kommt ans Ende, der andere Teil
  an den Anfang. Bei Straßen, die aus mehreren Wörtern bestehen, können die
  mittleren Teile auch in der Mitte der Straße erscheinen.

* beim Rotieren möglichst die Winkel quanteln, damit der X11-Server
  eine begrenzte Anzahl von Fonts (ca. 180/5, alle auf dem Kopf
  stehenden fallen weg) erzeugen muß.

* zu lange Straßennamen (Eigenüberlappung) werden nicht gezeichnet

* es wird am Anfang und am Ende mindestens ein Space Platz gelassen

* die Namen sollten dem Verlauf der Straße folgen

* Überlappungen feststellen und vermeiden

* wenn nur Hauptstraßen gelabelt werden und ein Teil einer Hauptstraße
  als Nebenstraße weitergeführt wird, sollte dieser Teil auch im Label
  enthalten sein

* in C schreiben!
