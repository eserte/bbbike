# -*- perl -*-

#
# $Id: MapInfo.pm,v 1.1 2004/02/17 18:19:09 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (c) 2004 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::MapInfo;

sub create_mif_mid {
    my $self = shift;
    my $version = "300";
    my($minx,$miny,$maxx,$maxy) = $self->bbox;

    my($max_name_length, $max_cat_length) = (1, 1);
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS()] };
	$max_name_length = length($r->[Strassen::NAME()])
	    if $max_name_length < length($r->[Strassen::NAME()]);
	$max_cat_length = length($r->[Strassen::CAT()])
	    if $max_cat_length < length($r->[Strassen::CAT()]);
    }

    my $mid = "";
    my $mif = <<EOF;
VERSION $version
CHARSET "WindowsLatin1"
DELIMITER ","
COORDSYS NonEarth Units "m" Bounds ($minx,$miny) ($maxx,$maxy)
COLUMNS 2
  Name     Char($max_name_length)
  Category Char($max_cat_length)
DATA

EOF

    $self->init;
    while(1) {
	my $r = $self->next;
	my $no_coords = @{ $r->[Strassen::COORDS()] };
	last if !$no_coords;

	$mif .= "Pline $no_coords\n";
	for my $p (@{ $r->[Strassen::COORDS()] }) {
	    my($x, $y) = split /,/, $p;
	    $mif .= "$x $y\n";
	}
	$mif .= "    Pen (1,2,1)\n";

	(my $name = $r->[Strassen::NAME()]) =~ s/\"//g; # XXX better solution!
	(my $cat  = $r->[Strassen::CAT()])  =~ s/\"//g; # XXX better solution!
	$mid .= qq{"$name","$cat"\n};
    }

    ($mif, $mid);
}

sub export {
    my($self, $filename) = @_;
    my($mif, $mid) = create_mif_mid($self);
    open(MIF, ">$filename.MIF") or die "Can't create $filename.MIF: $!";
    print MIF $mif;
    close MIF;
    open(MID, ">$filename.MID") or die "Can't create $filename.MID: $!";
    print MID $mid;
    close MID;
}

return 1 if caller;

require Strassen;
require Getopt::Long;
my $o;
if (!Getopt::Long::GetOptions("o=s" => \$o)) { die "usage!" }
if (!defined $o) { die "-o option missing" }
my $f = shift || die "Strassen file missing";
my $s = Strassen->new($f);
export($s, $o);

