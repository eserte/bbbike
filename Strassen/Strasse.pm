# -*- perl -*-

#
# $Id: Strasse.pm,v 1.6 2003/07/22 23:28:24 eserte Exp eserte $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::Strasse;

package Strasse;
use strict;
#use AutoLoader 'AUTOLOAD';

use constant NAME   => Strassen::NAME();
use constant COORDS => Strassen::COORDS();
use constant CAT    => Strassen::CAT();

sub new {
    my($class, $obj) = @_;
    bless $obj, $class;
}
sub name        { $_[0]->[NAME] }
sub coords      { $_[0]->[COORDS] }
sub coords_list { @{$_[0]->[COORDS]} }
sub category    { $_[0]->[CAT] }
sub is_empty    { @{$_[0]->[COORDS]} == 0 }
sub coord_as_string { $_[0]->coords->[$_[1]] }
sub coord_as_list {
    my($self, $i) = @_;
    my $s = $self->coords->[$i];
    Strassen::to_koord1($s); # XXX abhängig von Strassen!
}

# gibt TRUE zurück, wenn ein Teil der Straße im angegebenen Rechteck ist
# (keine perfekte Lösung)
### AutoLoad Sub
sub is_in {
    my($self, $x1, $y1, $x2, $y2) = @_;
    my $len = scalar $self->coords_list;
    for(my $i=0; $i<$len; $i++) {
	my($x, $y) = @{$self->coord_as_list($i)};
	if ($x >= $x1 && $x <= $x2 &&
	    $y >= $y1 && $y <= $y2) {
	    return 1;
	}
    }
    0;
}

# statische Methode
### AutoLoad Sub
sub de_artikel {
    my($strasse) = @_;
    if ($strasse =~ /(str\.|straße\b|allee\b|chaussee\b|promenade\b)/i) {
	"in die";
    } elsif ($strasse =~ /(park\b|garten\b|ring\b)/i) {
	"in den";
    } elsif ($strasse =~ /(damm\b|weg\b|steig\b)/i) {
	"in den";
    } elsif ($strasse =~ /(platz\b)/i) {
	"auf den";
    } elsif ($strasse =~ /(ufer\b|gestell\b)/i) {
	"in das";
    } elsif ($strasse =~ /(brücke\b)/i) {
	"auf die";
    } elsif ($strasse =~ /(\balt\b)/i) {
	"in die Straße";
    } elsif ($strasse =~ /(\btor\b)/i) {
	"in das";
    } elsif ($strasse =~ /(\bstern\b)/i) { # möglichst am Ende
	"auf den";
    } else {
	"=>";
    }
}

# Den Straßennamen so weit wie möglich abkürzen...
# Verschiedene Level (0 bis 3) sind möglich
sub short {
    my($strname, $level, $nodot) = @_;
    my $dot = ($nodot ? "" : ".");
    if ($level > 0) {
	$strname =~ s/(s)tra(ss|ß)e/$1tr$dot/i;
	$strname =~ s/(p)latz/$1l$dot/i;
	$strname =~ s/\bBahnhof/Bhf$dot/;
    }
    if ($level > 2) {
	$strname =~ s/str\.//;
	$strname =~ s/^Str\.\s+de[rs]\s+/S.d./;
	$strname =~ s/^Str\./Str/;
	$strname =~ s/([ \-]S)tr\.//;
	$strname =~ s/(p)l\./$1l/i;
	$strname =~ s/damm/d$dot/;
	$strname =~ s/br(ü|ue)cke/br$dot/;
	$strname =~ s/(a)llee/$1$dot/i;
	$strname =~ s/\b(k)leine[srnm]?\b/$1l$dot/i;
	$strname =~ s/\b(g)ro(ß|ss)e[srnm]?\b/$1r$dot/i;
    } elsif ($level > 1) {
	$strname =~ s/(s)tr\./$1tr/i;
	$strname =~ s/(p)l\./$1l/i;
    }
    $strname;
}

# Turn
#    B1: Berlin - Potsdam
# into
#    B1: (Berlin -) Potsdam
# or
#    B1: (Potsdam -) Berlin
# depending on the traveling direction.
# Street numbers like "B1" or "F2.2" are recognized.
sub beautify_landstrasse {
    my($str, $backwards) = @_;
    if ($str =~ /^([\w\.]+:\s+)?(.*\s-\s.*)$/) {
	my $str_nummer = "";
	if (defined $1 and $1 ne "") {
	    $str_nummer = $1;
	    $str = $2;
	}
	my(@comp) = split /\s-\s/, $str;
	my $add_parens = 0;
	if ($backwards) {
	    if ($comp[0] =~ /^\(/ && $comp[-1] =~ /\)$/) {
		$comp[0] =~ s/^\(//;
		$comp[-1] =~ s/\)$//;
		$add_parens = 1;
	    }
	    @comp = reverse @comp;
	}
	$str = $str_nummer . "(" . join(" - ", @comp[0..$#comp-1])
	    . " -) " . $comp[$#comp];
	if ($add_parens) {
	    $str = "($str)";
	}
    }
    $str;
}

# the following schemes are recognized:
#   (B 109)       (anywhere)
#   B 109:        (at beginning)
#   B 109         (whole string)
#   B 109 (...)   (at beginning)
#   F: Radrouten in Potsdam
#   R: Europaradwege
sub parse_street_type_nr {
    my $strname = shift;
    my($type,$nr) = $strname =~ /\((B|L|BAB|F|R)\s*([\d\.]+)\)/;
    if (!defined $type) {
	($type,$nr) = $strname =~ /^(B|L|BAB|F|R)\s*([\d\.]+)(?::|$|\s*\()/;
    }
    ($type, $nr);
}

# Schneidet den Teil in Klammern weg.
# Wird für Bezirke, aber auch bei Bahnhöfen (z.B. (U1)) verwendet.
### AutoLoad Sub
sub strip_bezirk {
    my $str = shift;
    if ($str !~ /^\s*\(/) {
	$str =~ s/\s*\(.*\)\s*$//;
    }
    $str;
}

1;
