# -*- perl -*-

#
# $Id: Tk50.pm,v 1.3 2003/04/17 19:38:03 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Much work left!

package Karte::Tk50;
use Karte;
use strict;
use vars qw(@ISA $obj $cdrom_drive);

@ISA = qw(Karte);

use vars qw($tile_width $tile_height);
$tile_width = 800;
$tile_height = 800;

sub new {
    my $class = shift;
    my $self =
      {
       Name     => 'Tk50-Koordinaten',
       Token    => 'tk50',
       Coordsys => 'tk50',
       Mimetype => 'image/x-portable-anymap',

       # see calc_coefficientes()
       X0 => -3141426.15177759,
       X1 => 2.4966739068303,
       X2 => -0.101246685570687,
       Y0 => -5839331.75786708,
       Y1 => 0.103203599091897,
       Y2 => 2.45332072725714,

       Width  => $tile_width,
       Height => $tile_height,

       Scrollregion => [3230268.3,5671154.8,3500732.4,5941646.2],
      };
    bless $self, $class;
}

sub coord {
    my($self, $mx, $my) = @_;
    my($x,$y) = map2etrs($mx,$my);
    my($tx,$ty) = map2etrs($tile_width,$tile_height);
    my $d = find_best_map($x, $y);
    my $dx = ($x-$d->{X1} < -$tx/2 ? -($x-$d->{X1}) : -$tx/2);
    my $dy = ($y-$d->{Y1} < -$ty/2 ? -($y-$d->{Y1}) : -$ty/2);
    my($delta_x, $delta_y) = etrs2map($dx,$dy);
    ($mx, $my, $delta_x, $delta_y);
}

sub filename {
    my($self, $mx, $my) = @_;
    my($x,$y) = map2etrs($mx,$my);
    my $d = find_best_map($x, $y);
    my $img_file = $d->{Imgfile};
    my $cache_file = cachefile($img_file);
    $cache_file = "/cabulja/usr/tmp/tmptk50.pnm"; # XXX
    if (!-e $cache_file) {
  	system("tifftopnm $img_file > $cache_file");
    }
    require BBBikeUtil;
    my $xq = ($d->{X2}-$d->{X1})/$d->{Width};
    my $yq = ($d->{Y2}-$d->{Y1})/$d->{Height};

    my($tx,$ty) = map2etrs($tile_width,$tile_height);
    my $dx = ($x-$d->{X1} < -$tx/2 ? -($x-$d->{X1}) : -$tx/2);
    my $dy = ($y-$d->{Y1} < -$ty/2 ? -($y-$d->{Y1}) : -$ty/2);
    my($delta_x, $delta_y) = etrs2map($dx,$dy);

    my $x0 = int(BBBikeUtil::max(($x-$d->{X1})/$xq+$delta_x, 0));
    my $y0 = int(BBBikeUtil::max(($y-$d->{Y1})/$yq+$delta_y, 0));
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$x,$y,$d,$x0,$y0,$xq,$yq,$delta_x,$delta_y],[])->Indent(1)->Useqq(1)->Dump; # XXX
    my $pnmcut = "/home/e/eserte/src/twistdim/fastpnmcut.freebsd";
    # my $pnmcut = "pnmcut";
    my $outfile = "/tmp/img.pnm";
    my $cmd = "$pnmcut " . $x0 . " " . ($d->{Height}-$y0-$tile_height) . " " .
	$tile_width . " " . $tile_height . " " . $cache_file . " > $outfile";
    warn "$cmd\n";
    system($cmd);
    $outfile;
}

sub cachefile { # XXX not yet used
    my $f = shift;
    require File::Spec;
    require File::Basename;
    $f = File::Basename::basename($f);
    $f =~ s/\.tif$/.gif/; # XXX change to .pnm
    File::Spec->catfile(File::Spec->tmpdir, $f);
}

sub read_asc_data {
    require Storable;
    require File::Spec;

    my $cache_file = File::Spec->catfile(File::Spec->tmpdir(),
					 "tk50-corners.st");
    if (-r $cache_file) {
	return Storable::retrieve($cache_file);
    }

    my $cdrom_drive = find_cdrom_drive();

    my @data;
    my($minx, $maxx, $miny, $maxy);

    for my $asc_file (glob("$cdrom_drive/*/*.asc")) {
	(my $nr) = $asc_file =~ m|\Q$cdrom_drive\E/([^/]+)|;
	my($nr_in_asc, $map_name, $x1, $y1, $x2, $y2, $width, $height);
	open(ASC, $asc_file) or die "$asc_file: $!";
	my $parse = 0;
	while(<ASC>) {
	    if (/^\s+L(\d+)\s+(.*?)\s*$/) {
		$nr_in_asc = $1;
		$map_name = $2;
		if ($nr_in_asc ne $nr) {
		    warn "Map numbers do not match in $asc_file: $nr vs. $nr_in_asc\n";
		}
	    } elsif (/Datensatzbegrenzung/) {
		$parse = 1;
	    } elsif ($parse == 1 && /^\s+\d+\s+([\d.]+)\s+([\d.]+)\s+1\s+(\d+)/) {
		($x1, $y1, $height) = ($1, $2, $3);
		$parse = 2;
	    } elsif ($parse == 2 && /^\s+\d+\s+([\d.]+)\s+([\d.]+)\s+(\d+)/) {
		($x2, $y2, $width) = ($1, $2, $3);
		last;
	    }
	}
	close ASC;
	if (!defined $x1 || !defined $x2) {
	    die "Can't find corner points in $asc_file";
	}

	push @data, { X1 => $x1, X2 => $x2, Y1 => $y1, Y2 => $y2,
		      Width => $width, Height => $height,
		      Mapname => $map_name, Nr => $nr,
		      Imgfile => File::Spec->catfile($cdrom_drive, $nr,
						     "l${nr}f.tif"),
		    };

	if (!defined $minx || $x1 < $minx) { $minx = $x1 }
	if (!defined $maxx || $x2 > $maxx) { $maxx = $x2 }
	if (!defined $miny || $y1 < $miny) { $miny = $y1 }
	if (!defined $maxy || $y2 > $maxy) { $maxy = $y2 }
    }

    @data = sort { $a->{X1} <=> $b->{X1} } @data;

    warn "Min x: $minx\nMax x: $maxx\nMin y: $miny\nMax y: $maxy\n";

    Storable::nstore(\@data, $cache_file);

    \@data;
}

# XXX rewrite to minimize distance $x/$y - center of map
sub find_best_map {
    my($x, $y) = @_;
    my $data = read_asc_data();
    for my $d (@$data) {
	if ($d->{X1} <= $x && $d->{X2} >= $x &&
	    $d->{Y1} <= $y && $d->{Y2} >= $y) {
	    return $d;
	}
    }
    die "Can't find map for $x/$y";
}

sub find_cdrom_drive {
    return $cdrom_drive if defined $cdrom_drive;

    my @cdrom_drives;
    if ($^O =~ /mswin32/i) {
	require Win32Util;
	@cdrom_drives = Win32Util::get_cdrom_drives();
	if (!@cdrom_drives) {
	    @cdrom_drives = qw(D: E: F:);
	}
    } else {
	require UnixUtil;
	@cdrom_drives = UnixUtil::get_cdrom_drives();
	if (!@cdrom_drives) {
	    @cdrom_drives = qw(/cdrom /mnt/cdrom /cd /CDROM);
	}
    }

 TRY: {
	for my $try_cdrom_drive (@cdrom_drives) {
	    if (-e "$try_cdrom_drive/Testdaten_Brandenburg") {
		$cdrom_drive = $try_cdrom_drive;
		last TRY;
	    }
	}
	die "Can't find CDROM";
    }
    $cdrom_drive;
}

sub calc_coefficientes {
    require Karte::ETRS89;
    require Karte::UTM;
    require Karte::Polar;

    # Data from convert_berlinmap.pl:
    my $data = <<'EOF';
# hafas		polar/eTrex (DDD, WGS84)
14444,11752	13.46414,52.51064	# GRUENBERGER BOXHAGENER
13467,11787	13.44894,52.51144	# GUBENER KOPERNIKUS
14442,11101	13.46286,52.50517	# REVALER HELMERDINGER
13594,11489	13.45094,52.50856	# WARSCHAUER REVALER
9784,9519	13.39438,52.49131	# GNEISENAU ZOSSENER
9043,9745	13.38381,52.49339	# YORCK GROSSBEEREN
7941,9686	13.36750,52.49308	# BUELOW GOEBEN
6753,10446	13.34956,52.50033	# KLEIST EISENACHER
5938,10808	13.33764,52.50358	# TAUENTZIEN MARBURGER
4245,10435	13.31289,52.50058	# LEIBNIZ KURFUERSTENDAMM
4540,11041	13.31781,52.50614	# KANT SCHLUETER
6175,10968	13.34089,52.50539	# BUDAPESTER KURFUERSTENSTR
8172,11679	13.37164,52.51133	# KEMPERPLATZ
9046,11558	13.38447,52.51008	# LEIPZIGER WILHELM
10222,11724	13.40169,52.51147	# SPITTELMARKT
11328,12040	13.41761,52.51394	# BRUECKEN MAERKISCHES UFER
11773,11993	13.42419,52.51372	# LICHTENBERGER HOLZMARKT
12584,12233	13.43626,52.51546	# RUEDERSDORFER KOPPEN
EOF

    my $d = read_asc_data();
    # assumes same scale for each map
    my $xq = ($d->[0]->{X2}-$d->[0]->{X1})/$d->[0]->{Width};
    my $yq = ($d->[0]->{Y2}-$d->[0]->{Y1})/$d->[0]->{Height};

    my $new_data = "";
    for my $l (split /\n/, $data) {
	my($hafas, $polar, $comment) = split /\t/, $l;
	my($long,$lat) = split /,/, $polar;
	my($ze, $zn, $x, $y) = Karte::UTM::DegreesToUTM($lat, $long);
	#warn "($ze, $zn, $x, $y)($long,$lat)";
	($x, $y) = Karte::ETRS89::UTMToETRS89($ze, $zn, $x, $y);
	$x = int($x/$xq);
	$y = int($y/$yq);
	#warn "$x,$y";
	$new_data .= "$hafas\t$x,$y\t$comment\n";
    }

    my $tmp_file = "/tmp/hafas2etrs.dat";
    open(TMP, ">$tmp_file") or die "$tmp_file: $!";
    print TMP $new_data;
    close TMP;

    my @cmd = ("/home/e/eserte/src/bbbike/miscsrc/convert_berlinmap.pl",
	       "-datafromfile", $tmp_file, "-bbbike");
    warn "@cmd\n";
    system @cmd;
}

sub etrs2map {
    my($x,$y) = @_;
    my $d = read_asc_data();
    my $xq = ($d->[0]->{X2}-$d->[0]->{X1})/$d->[0]->{Width};
    my $yq = ($d->[0]->{Y2}-$d->[0]->{Y1})/$d->[0]->{Height};
    ($x/$yq, $y/$yq);
}

sub map2etrs {
    my($mx,$my) = @_;
    my $d = read_asc_data();
    my $xq = ($d->[0]->{X2}-$d->[0]->{X1})/$d->[0]->{Width};
    my $yq = ($d->[0]->{Y2}-$d->[0]->{Y1})/$d->[0]->{Height};
    ($mx*$yq, $my*$yq);
}

$obj = new Karte::Tk50;

return 1 if caller;

#exit calc_coefficientes();

my($x, $y) = @ARGV;
require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([
find_best_map($x, $y)
],[])->Indent(1)->Useqq(1)->Dump; # XXX

__END__
