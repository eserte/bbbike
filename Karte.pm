# -*- perl -*-

#
# $Id: Karte.pm,v 1.42 2007/08/02 21:55:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2002 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Karte;
#use AutoLoader 'AUTOLOAD';

$VERSION = sprintf("%d.%02d", q$Revision: 1.42 $ =~ /(\d+)\.(\d+)/);

use strict;
use vars qw(%map %map_by_modname %map_by_coordsys @map $cache_root $map_root);

if (!defined $cache_root) {
    $cache_root = $ENV{TMPDIR} || $ENV{TEMP} || '/tmp';
}
if (!defined $map_root) {
    $map_root = "/usr/www/berlin";
}

sub preload {
    my(@types) = @_;
    if ($types[0] eq ':all') {
	@types = qw(Standard
		    Berlinmap1996 Berlinmap1997 Berlinmap1998 Berlinmap1999
		    Berlinmap2000 Berlinmap2001 Berlinmap2002 Berlinmap2003
		    Berlinmap2004
		    Potsdammap2002 Demap2002 Nbrbmap2004
		    Satmap SatmapGIF GISmap Polar T99 T2001 GDF
		    FURadar FURadar2 FURadar3
                    GPS Soldner_alt Cityinfo PilotPl PilotPl12 Tk50
		    Deinplan
		   );
    }
    my $karte;
    foreach $karte (@types) {
	my $module = "Karte::$karte";
	eval "require $module";
	if ($@) {
	    warn $@;
	} else {
	    my $o = eval "\$" . $module . "::obj";
	    next if !$o or exists $map{$o->token};
	    push @map, $o->token;
	    $map{$o->token} = $o;
	    $map_by_modname{$karte} = $o;
	    if (defined $o->coordsys) {
## sometimes this is legal:
# 		if (exists $map_by_coordsys{$o->coordsys}) {
# 		    warn "Multiple use of Coordsys <" . $o->coordsys . ">";
# 		}
		$map_by_coordsys{$o->coordsys} = $o;
	    }
	}
    }
}

sub name     { shift->{Name} }
sub token    { shift->{Token} }
sub mimetype { shift->{Mimetype} }
sub coordsys { shift->{Coordsys} }

sub map_root  { $map_root }
sub fs_dir    {
    my $o = shift;
    if (defined $o->{Fs_dir}) {
	$o->{Fs_dir};
    } elsif (defined $o->{Fs_base}) {
	$o->map_root . "/" . $o->{Fs_base};
    } else {
	undef;
    }
}
sub cache_dir { shift->{Cache_dir} }
sub root_url  { shift->{Root_URL} }

sub x0 { shift->{X0} }
sub x1 { shift->{X1} }
sub x2 { shift->{X2} }
sub y0 { shift->{Y0} }
sub y1 { shift->{Y1} }
sub y2 { shift->{Y2} }

sub width  { shift->{Width} }
sub height { shift->{Height} }

sub scrollregion { @{shift->{Scrollregion}} }

# gibt an, ob die Karte mit Umgebung gezeichnet werden kann
sub noenvironment { shift->{NoEnvironment} }

sub to_ppm {
    my $self = shift;
    ($self->mimetype eq 'image/gif'
     ? 'giftopnm' # giftoppm gibt's bei netpbm nicht
     : ($self->mimetype eq 'image/jpeg'
	? 'djpeg'
	: ($self->mimetype eq 'image/png'
	   ? 'pngtopnm'
	   : ($self->mimetype eq 'image/tiff'
	      ? 'tifftopnm'
	      : ($self->mimetype =~ m|^image/x-portable-.*map$|
		 ? 'cat'
		 : die "Unknown to_ppm for " . $self->mimetype
		)
	     )
	  )
       )
    );
}

sub ext {
    my $self = shift;
    ($self->mimetype eq 'image/gif'
     ? 'gif'
     : ($self->mimetype eq 'image/jpeg'
	? 'jpg'
	: ($self->mimetype eq 'image/png'
	   ? 'png'
	   : die "Unknown extension for " . $self->mimetype
	  )
       )
    );
}

# Erhöhen/Erniedrigen der Kartenkoordinaten
sub incx {
    my(undef, $c, $inc) = @_;
    $c + $inc;
}

sub incy {
    my(undef, $c, $inc) = @_;
    $c + $inc;
}

# Die ..._s-Formen erwarten und liefern ein Skalar "x,y"

# Transformationen von und zum normalen Koordinatensystem
sub map2standard {
    my($self, $oldx, $oldy) = @_;
    ($self->x0 + $oldx*$self->x1 + $oldy*$self->x2,
     $self->y0 + $oldx*$self->y1 + $oldy*$self->y2
    );
}

sub map2standard_s {
    my($self, $old) = @_;
    # do not use trim_accuracy here ... standard is always int
    join(",", map { int } $self->map2standard(split /,/, $old));
}

sub standard2map {
    my($self, $newx, $newy) = @_;
    ((($newx-$self->x0)*$self->y2-($newy-$self->y0)*$self->x2)/
     ($self->x1*$self->y2-$self->y1*$self->x2),
     (($newx-$self->x0)*$self->y1-($newy-$self->y0)*$self->x1)/
     ($self->x2*$self->y1-$self->x1*$self->y2)
    );
}

sub standard2map_s {
    my($self, $new) = @_;
    join(",", $self->trim_accuracy($self->standard2map(split /,/, $new)));
}

# Transformation zwischen beliebigen Koordinatensystemen
sub map2map {
    my($from, $to, $oldx, $oldy) = @_;
    $to->standard2map($from->map2standard($oldx, $oldy));
}

sub map2map_s {
    my($from, $to, $old) = @_;
    join(",", $to->trim_accuracy($from->map2map($to, split /,/, $old)));
}

sub trim_accuracy {
    my(undef, $x, $y) = @_;
    (int($x), int($y));
}

# Return the rotating angle between maps XXX NYI
sub rotate_angle {
#    my($self, $map) = @_;
#    my($tx1,$ty1) = $self->map2map($map, 0, 0);
#    my($tx2,$ty2) = $self->map2map($map, 1000, 0);
    # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
}

sub scale_coeff {
    my $self = shift;
    my($x0, $y0) = $self->map2standard(0, 0);
    my($x1, $y1) = $self->map2standard(1, 0);
    sqrt(($x1-$x0)*($x1-$x0) + ($y1-$y0)*($y1-$y0));
}

# statische Funktion
# gibt für ein Coordsys (Koordinaten-Abkürzung) das Karten-Objekt zurück
sub coordsys2obj {
    my($coordsys) = @_;
    my($k, $v);
    while(($k,$v) = each %Karte::map) {
	my $match_coordsys = $v->coordsys;
	return $v if (defined $match_coordsys &&
		      $match_coordsys eq $coordsys);
    }
    undef;
}

# create a Karte object without a class
# %args should at least contain X0 => ... to Y2 => ...
sub create_obj {
    my($class, %args) = @_;
    eval '@' . $class . '::ISA = "Karte"'; die $@ if $@;
    my $obj = { %args };
    bless $obj, $class;
    $obj;
}

# XXX move to "Heavy" module?
sub object_from_file {
    my $file = shift;
    _object_from_file(-datafromfile => $file);
}

sub object_from_bbd_file {
    my $bbd_file = shift;
    _object_from_file(-datafrombbd => $bbd_file);
}

sub object_from_any_file {
    my $bbd_file = shift;
    _object_from_file(-datafromany => $bbd_file);
}

# In argument: [["x,y", "x,y"], ...] where first element is the standard coord
# and the second element the custom map coord
sub object_from_data {
    my $array = shift;
    require File::Temp;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1);
    print $tmpfh join("\n", map { join " ", @$_ } @$array), "\n";
    close $tmpfh;
    my $k_obj = _object_from_file(-datafromfile => $tmpfile);
    unlink $tmpfile;
    $k_obj;
}

sub _object_from_file {
    my(@args) = @_;
    my $cmd = "$FindBin::RealBin/convert_berlinmap.pl";
    if (!-r $cmd) {
	$cmd = "$FindBin::RealBin/miscsrc/convert_berlinmap.pl";
    }
    my $res = `$^X $cmd @args -bbbike`;
    if (!$res) {
	die "Error while running convert_berlinmap?";
    }
    my %args;
    foreach my $l (split /\n/, $res) {
	if ($l =~ /([XY]\d)\s*=>\s*(.*),/) {
	    $args{$1} = $2;
	}
    }
    foreach my $key (qw(X0 X1 X2 Y0 Y1 Y2)) {
	if (!exists $args{$key}) {
	    warn "$key is missing while converting @args";
	}
    }
    my $k_obj = Karte::create_obj("Karte::Custom", %args);
    $k_obj;
}

return 1 if caller;

require Getopt::Long;
Karte::preload(":all");
my($frommap) = "standard";
my($tomap) = "standard";
if (!Getopt::Long::GetOptions("from=s" => \$frommap,
			      "to=s" => \$tomap,
			     )) {
    usage();
}

my $conv = sub {
    my $coord = shift;
    print join(",", $Karte::map{$frommap}->map2map($Karte::map{$tomap},
						   split/,/, $coord)), "\n";
};

if (@ARGV) {
    $conv->(shift);
} else {
    while(<>) {
	chomp;
	my $c = $_;
	$conv->($c);
    }
}

sub usage {
    Karte::preload(":all");
    my $valid_maps = join("\n", map { "- $_ (" . $Karte::map{$_}->name . ")" } sort keys %Karte::map);
    die <<EOF;
Usage: $^X $0 [-from map] [-to map] -- x,y
Where map is any of:
$valid_maps
EOF
}

__END__

=head1 NAME

Karte - conversions between map sets

=head1 SYNOPSIS

In a script:

    use Karte;
    Karte::preload(":all");

    my $frommap = $Karte::map{"standard"};
    my $tomap   = $Karte::map{"polar"};
    ($x_polar, $y_polar) = $frommap->map2map($tomap, $x_standard, $y_standard);

From command line:

    perl Karte.pm -from standard -to polar -- x,y

For a list of all possible maps use

    keys(%Karte::map)

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<convert_coordsys>

=cut

