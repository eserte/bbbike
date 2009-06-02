# -*- perl -*-

#
# $Id: Util.pm,v 1.25 2008/08/28 21:04:31 eserte Exp eserte $
#
# Copyright (c) 1995-2003 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (slaven@rezic.de)
#

package Strassen::Util;

$VERSION = sprintf("%d.%02d", q$Revision: 1.25 $ =~ /(\d+)\.(\d+)/);

use strict;
use Config;
use BBBikeUtil qw(rad2deg STAT_MODTIME);
#use AutoLoader 'AUTOLOAD';
use vars qw($VERBOSE $tmpdir
	    $cachedir $cacheprefix
	    $cacheable @cacheable $cacheable_array_set %cache_symbol
	    $datadumper_var $use_virt_array
	    $acos);

#BEGIN {#XXX not needed?
#if (0) {#XXX for perlcc
    eval {
	require POSIX;
	$acos = \&POSIX::acos; # C, daher wahrscheinlich etwas schneller
    };
#} $@="fehler";#XXX for perlcc

    if ($@) {
	# from Math::Complex
	$acos = sub {
	    my $z = $_[0];
	    return CORE::atan2(CORE::sqrt(1-$z*$z), $z) if (! ref $z) && CORE::abs($z) <= 1;
	    warn "Fallback to Math::Trig::acos because of $z\n";
	    require Math::Trig;
	    Math::Trig::acos($z);
	};
    }
#}

if (!defined $tmpdir) {
    if (defined $main::tmpdir) {
	$tmpdir = $main::tmpdir;
    } else {
	$tmpdir = $ENV{TMPDIR} || $ENV{TEMP} || "/tmp";
    }
    if (!-d $tmpdir || !-w $tmpdir) { undef $tmpdir }
}

# XXX Should probably prefer ~/.bbbike/cache, see main bbbike program
if (!defined $cachedir) {
    $cachedir = (defined $FindBin::RealBin &&
		 -d "$FindBin::RealBin/cache" &&
		 -w "$FindBin::RealBin/cache"
		 ? "$FindBin::RealBin/cache"
		 : $tmpdir);
}

if (!defined $cacheable) {
    $cacheable = 1
}

if (!defined $cacheprefix) {
    $cacheprefix = "b_de"; # Berlin in Germany
}

# FreezeThaw nicht verwenden: es ist *viel* langsamer als Storable
# Data::Dumper ist auch langsam gegenüber make_net_slow
# Werte (mit dprofpp, perl5.00503, FreeBSD 3.4):
#  FreezeThaw:    55s (!)
#  Data::Dumper:  5s
#  ohne Cache:    2s
if (!@cacheable && !$cacheable_array_set) {
    @cacheable = qw(CDB_File_Flat CDB_File VirtArray Storable);
}

# Argument: [x1,y1], [x2, y2]
sub strecke {
    CORE::sqrt(($_[0]->[0] - $_[1]->[0])**2 +
	       ($_[0]->[1] - $_[1]->[1])**2
	      );
}

# Argument: "x1,y1", "x2,y2"
sub strecke_s {
    my $inx1 = index($_[0], ",");
    my $inx2 = index($_[1], ",");
    CORE::sqrt((substr($_[0],0,$inx1)-substr($_[1],0,$inx2))**2 +
	       (substr($_[0],$inx1+1)-substr($_[1],$inx2+1))**2
	      );
}
## Die alte lesbare (aber etwas langsamere, siehe t/strassen2-bench.pl)
## Variante:
#    my($x1, $y1) = split(/,/, $_[0]);
#    my($x2, $y2) = split(/,/, $_[1]);
#    CORE::sqrt(sqr($x1-$x2) + sqr($y1-$y2));

BEGIN {
    if (eval { require Geo::Distance::XS; 1 }) {
	my $geo = Geo::Distance->new;
	*strecke_polar = sub {
	    my($s1,$s2) = @_;
	    $geo->distance('meter', $s1->[0], $s1->[1], $s2->[0], $s2->[1]);
	};
    } elsif (eval { require Math::Trig; 1 }) {
	*strecke_polar = sub {
	    my($s1,$s2) = @_;
	    my $lon0 = Math::Trig::deg2rad($s1->[0]);
	    my $lat0 = Math::Trig::deg2rad(90 - $s1->[1]);
	    my $lon1 = Math::Trig::deg2rad($s2->[0]);
	    my $lat1 = Math::Trig::deg2rad(90 - $s2->[1]);
	    Math::Trig::great_circle_distance($lon0, $lat0,
					      $lon1, $lat1, 6372795);
	};
    } else {
	warn "Math::Trig not available, cannot deal with polar data!\n";
    }
    *strecke_s_polar = sub {
	strecke_polar([split /,/, $_[0]], [split /,/, $_[1]]);
    };
}

# Argumente: Indices
sub strecke_i {
    my($self, $i1, $i2) = @_;
    my($x1,$y1) = unpack("l2", $self->{Index2Coord}[$i1]);
    my($x2,$y2) = unpack("l2", $self->{Index2Coord}[$i2]);
    CORE::sqrt(($x1-$x2)**2 + ($y1-$y2)**2);
}

# return the middle point between the points
sub middle {
    my($x0,$y0,$x1,$y1) = @_;
    (($x1-$x0)/2+$x0, ($y1-$y0)/2+$y0);
}

# like middle, but use "x1,y1" and "x2,y2" as parameters and return "rx,ry"
sub middle_s {
    my($p0,$p1) = @_;
    join(",",middle(split(/,/,$p0), split(/,/,$p1)));
}

# gibt für "x,y"  (x,y) aus
sub string_to_coord ($) { split /,/, $_[0] }

# Gibt "l" oder "r" für Links- oder Rechtsabbiegen sowie den Winkel in
# Grad aus ($dir, $angle).
# Es gibt auch "u" für Umkehren.
# Diese Funktion gilt nur, wenn die Koordinaten im Standard-Koordinatensystem
# sind (X-Koordinaten wachsen nach rechts und Y-Koordinaten nach oben).
# Argumente sind drei Punkte in der Form [x1,y1], ...
### AutoLoad Sub
sub abbiegen {
    my($p0,$p1,$p2) = @_;
    my($x0,$y0, $x1,$y1, $x2,$y2) = (@$p0, @$p1, @$p2);

    if ("@$p0" eq "@$p2") {
	return ("u", 180);
    }

    # XXX kann beim acos anscheinend auftreten
    local $SIG{FPE} = sub { warn "Caught SIGFPE!" };

    my $a1 = $x1-$x0;
    my $a2 = $y1-$y0;
    my $b1 = $x2-$x1;
    my $b2 = $y2-$y1;
    my $dir = ($a1*$b2-$a2*$b1 > 0 ? 'l' : 'r');

    my $a_len = strecke($p0, $p1);
    my $b_len = strecke($p1, $p2);

    my $angle = ($a_len == 0 || $b_len == 0 ? 0
		  : rad2deg(&$acos(($a1*$b1+$a2*$b2)/($a_len*$b_len))));
    $angle = -$angle if $angle < 0; # if using old Math::Trig::acos

    ($dir, $angle);
}

# Wie abbiegen, nur sind hier die Argumente in der Form "x1,y1" ...
sub abbiegen_s {
    abbiegen(map {[string_to_coord $_]} @_)
}

# Für einen Punkt $p und einen Nachbarpunkt $neighbor_p die Himmelsrichtung
# feststellen. Punkte in "x,y"-Syntax.
# XXX $rev_y: TRUE, wenn die y-Achse geometrisch umgekehrt/computergrafisch
# korrekt ist (unten ist das gleiche "mirrored" genannt).
### AutoLoad Sub
sub get_direction {
    my($p, $neighbor_p, $rev_y) = @_;
    my($px,$py)   = split /,/, $p;
    my($npx,$npy) = split /,/, $neighbor_p;
    my $deg = rad2deg(atan2($npy-$py, $npx-$px))+22.5;
    require POSIX;
    $deg = POSIX::floor($deg/45)*45;
    if (!$rev_y) {
	return {0 => 'w', 45 => 'nw', 90 => 'n', 135 => 'ne', 180 => 'e',
		-180 => 'e', -135 => 'se', -90 => 's', -45 => 'sw'}->{$deg};
    } else {
	return {0 => 'e', 45 => 'se', 90 => 's', 135 => 'sw', 180 => 'w',
		-180 => 'w', -135 => 'nw', -90 => 'n', -45 => 'ne'}->{$deg};
    }
}

# Den besten Nachbarpunkt aus $p_ref für einen Punkt $p in der
# gegebenen Himmelsrichtung $dir zurückgeben. Punkte in "x,y"-Syntax.
# Werte stimmen für Edit-Berlin-Modus. Für den Normal-Modus muß das
# Argument $mirrored auf wahr gesetzt werden.
### AutoLoad Sub
sub best_from_direction {
    my($p, $p_ref, $dir, $mirrored) = @_;
    my($px,$py)   = split /,/, $p;
    my %angle;
    $dir = lc($dir);
    $dir =~ s/o/e/g; # deutsch => englisch
    my %dir_angle;
    if ($mirrored) {
	%dir_angle = ('w' => 0, 'nw' => 45, 'n' => 90, 'ne' => 135, 'e' => 180,
		      'e' => -180, 'se' => -135, 's' => -90, 'sw' => -45);
    } else {
	%dir_angle = ('e' => 0, 'se' => 45, 's' => 90, 'sw' => 135, 'w' => 180,
		      'w' => -180, 'nw' => -135, 'n' => -90, 'ne' => -45);
    }
    if (!exists $dir_angle{$dir}) {
	warn "Can't get angle direction for $p: <$dir>";
    }
    my $dir_angle = $dir_angle{$dir};
    foreach my $neighbor_p (@$p_ref) {
	my($npx,$npy) = split /,/, $neighbor_p;
	my $angle = rad2deg(atan2($npy-$py, $npx-$px));
	my $min_angle;
	for (-360, 0, 360) {
	    if (!defined $min_angle or
		abs($angle + $_ - $dir_angle) < $min_angle) {
		$min_angle = abs($angle + $_ - $dir_angle);
	    }
	}
	$angle{$neighbor_p} = $min_angle;
    }
    my $best_angle;
    my $best_p;
    foreach my $neighbor_p (@$p_ref) {
	if (!defined $best_angle or abs($angle{$neighbor_p}) < $best_angle) {
	    $best_angle = abs($angle{$neighbor_p});
	    $best_p = $neighbor_p;
	}
    }
    $best_p;
}

# This should be sufficient on the earth:
sub infinity () { 40_000_000 }

######################################################################
# Cache routines

### AutoLoad Sub
sub cache_ext {
    {'VirtArray'    => '.va',
     'Storable'     => '.st',
     'Data::Dumper' => '.pl',
     'CDB_File'     => '.st.cdb',
     'CDB_File_Flat'=> '.cdb',
    }->{$_[0]};
}

### AutoLoad Sub
sub try_cache {
    my($filename, $write, $ref, %args) = @_;
    my $cache_type;
    my $rw_text   = ($write ? 'writing' : 'reading');
    my $rw_text_2 = ($write ? 'to' : 'from');
    foreach $cache_type (@cacheable) {
	my $filename = $filename .
	    ($cache_type =~ /^(Storable|CDB_File)$/ ? "_$Config{byteorder}" : "") . cache_ext($cache_type);

	if (eval {
	    require Digest::MD5;
	    require File::Basename;
	    1;
	}) {
	    # Prevent long filenames (very short on cygwin/MSWin32,
	    # still short (< 256) on Unix systems)
	    $filename = File::Basename::dirname($filename). "/bbbike_" . Digest::MD5::md5_hex(File::Basename::basename($filename)) . ".cache";
	}

	warn "Try $rw_text cache type $cache_type $rw_text_2 $filename ...\n"
	    if $VERBOSE;
	if ($cache_type eq 'VirtArray') {
	    # wird überhaupt ein Array gespeichert?
	    next if defined $ref && ref $ref ne 'ARRAY';
	    # Arrays mit Referenzen können mit VirtArray nicht gespeichert
	    # XXX stimmt nicht, anscheinend wird Storable::freeze verwendet!
	    next if $args{-deeparray};
	    eval q{ local $SIG{'__DIE__'};
		    require VirtArray;
		    die "VirtArray kann kein TIEARRAY"
		      unless VirtArray->can("TIEARRAY");
		};
	    if (!$@) {
		if (!$write) {
		    # ist die existierende Datei überhaupt
		    # eine VirtArray-Datei?
		    next if !VirtArray::is_valid($filename);
		}
		return ($cache_type, $filename);
	    }
	} elsif ($cache_type eq 'Storable') {
	    eval q{ local $SIG{'__DIE__'};
		    require Storable;
		    Storable->VERSION(0.509);
		};
	    if (!$@) {
		next if !$write && !-f $filename; # Datei existiert nicht
		return ($cache_type, $filename);
	    }
	} elsif ($cache_type eq 'Data::Dumper') {
	    if ($write) {
		eval q{ local $SIG{'__DIE__'};
			require Data::Dumper;
			Data::Dumper->VERSION(2.10);
			# use only the fast version
		        Data::Dumper->can("Dumpxs");
		    };
		if (!$@) {
		    return ($cache_type, $filename);
		}
	    } else {
		if (-f $filename) {
		    return ($cache_type, $filename);
		}
	    }
	} elsif ($cache_type eq 'CDB_File_Flat') {
	    next if defined $ref && ref $ref ne 'HASH';
	    next if !$args{-flathash} || $args{-modifiable};
	    eval q{ local $SIG{'__DIE__'};
		    require CDB_File;
	          };
	    #warn $@ if $@;
	    next if $@;
	    next if !$write && !-f $filename;
	    warn "CDB_File_Flat NYI"; # XXX
	    next; # XXX
	    return ($cache_type, $filename);
	} elsif ($cache_type eq 'CDB_File') {
	    next if defined $ref && ref $ref ne 'HASH';
	    next if $args{-modifiable};
	    eval q{ local $SIG{'__DIE__'};
		    require Storable;
		    Storable->VERSION(1.006); # bugs...
		    require MLDBM;
		    require CDB_File;
		  };
	    #warn $@ if $@;
	    next if $@;
	    next if !$write && !-f $filename;
	    return ($cache_type, $filename);
	} else {
	    die "Unknown cache type $cache_type";
	}
    }
    undef;
}

# Gibt wahr zurück, wenn der Cache nicht älter als alle Source-Dateien
# in $srcref (Array-Referenz oder ein String) ist.
# Internal function.
### AutoLoad Sub
sub cache_is_recent {
    my($cachefile, $srcref) = @_;

    my(@stat_cache) = stat $cachefile;
    if (!defined $stat_cache[STAT_MODTIME]) { # cachefile nicht vorhanden
	return undef;
    }
    my $src;
    my(@src) = (ref $srcref eq 'ARRAY' ? @$srcref : $srcref);
    foreach $src (@src) {
	my(@stat_orig)  = stat $src;
	if (defined $stat_orig[STAT_MODTIME] &&
	    $stat_cache[STAT_MODTIME] < $stat_orig[STAT_MODTIME]) {
	    # Cache ist nicht gültig
	    return undef;
	}
    }
    1;
}

# Return true if cache is valid. Same arguments as get_from_cache.
sub valid_cache {
    my($cachefile, $srcref) = @_;
    $cachefile = get_cachefile($cachefile);
    my($cache_func_found, $cachepath) = try_cache($cachefile);
    return 0 if (!$cache_func_found);
    return cache_is_recent($cachepath, $srcref);
}

# Return cache file name
### AutoLoad Sub
sub get_cachefile {
    my($_cachefile) = @_;
    unless ($_cachefile =~ m|^/|) {
	"$cachedir/bbbike_${cacheprefix}_" . $< . "_" . $_cachefile;
    } else {
	$_cachefile;
    }
}

# XXX %args is unused
### AutoLoad Sub
sub get_from_cache {
    my($cachefile, $srcref, %args) = @_;
    return if !$cacheable || !@cacheable;

    if (!defined $cachedir) {
	$cacheable = 0;
	return undef;
    }

    $cachefile = get_cachefile($cachefile);
    my($cache_func_found, $cachepath) = try_cache($cachefile);
    if (!$cache_func_found) {
	warn "No read cache function found (tried: @cacheable)\n" if $VERBOSE;
	return undef;
    }
    warn "Using $cache_func_found for reading.\n" if $VERBOSE;

    if (!cache_is_recent($cachepath, $srcref)) {
	warn "Cache file $cachepath is not recent with respect to
the source files @$srcref.\n" if $VERBOSE;
	return undef;
    }

    if ($cache_func_found eq 'Storable') {
	# Cache ist gültig
	my $obj;
	eval {
	    $obj = Storable::retrieve($cachepath);
	};
	warn $@ if $@;
	$obj;
    } elsif ($cache_func_found eq 'Data::Dumper') {
	do $cachepath;
	my $x = $datadumper_var;
	undef $datadumper_var; # evtl. memory leak vermeiden
	$x;
    } elsif ($cache_func_found eq 'VirtArray') {
	my @a;
	tie @a, 'VirtArray', $cachepath;
	\@a;
    } elsif ($cache_func_found eq 'CDB_File_Flat') {
	my %a;
	tie %a, 'CDB_File', $cachepath or die "Can't tie $cachepath: $!";
	\%a;
    } elsif ($cache_func_found eq 'CDB_File') {
	local $MLDBM::UseDB = 'CDB_File';
	local $MLDBM::Serializer = 'Storable';
	my %a;
	tie %a, 'MLDBM', $cachepath or die "Can't tie $cachepath: $!";
	\%a;
    } elsif (defined $cache_func_found) {
	warn "Unknown cache function: $cache_func_found";
    }
}

### AutoLoad Sub
sub write_cache {
    my($ref, $cachefile, %args) = @_;
    return if !$cacheable || !@cacheable;

    $cachefile = get_cachefile($cachefile);
    my($cache_func_found, $cachepath) = try_cache($cachefile, 1, $ref, %args);
    if (!$cache_func_found) {
	warn "No write cache function found (tried: @cacheable)\n" if $VERBOSE;
	return undef;
    }
    warn "Using $cache_func_found for writing.\n" if $VERBOSE;

    if ($cache_func_found eq 'Storable') {
	eval {
	    Storable::store($ref, $cachepath);
	};
	if ($@) {
	    warn "Can't write cache file $cachepath: $@";
	    undef;
	} else {
	    1;
	}
    } elsif ($cache_func_found eq 'Data::Dumper') {
	$Data::Dumper::Indent = 0; # write as tight as possible
	if (open(DD, ">$cachepath")) {
	    binmode DD;
	    print DD Data::Dumper->Dumpxs([$ref], ['datadumper_var']);
	    close DD;
	    1;
	} else {
	    undef;
	}
    } elsif ($cache_func_found eq 'VirtArray') {
	VirtArray::store($ref, $cachepath);
    } elsif ($cache_func_found eq 'CDB_File_Flat') {
	my $t = new CDB_File ($cachepath, "$cachepath.$$")
	    or die "Can't create cache file $cachepath with CDB_File: $!";
	while(my($k,$v) = each %$ref) {
	    $t->insert($k, $v);
	}
	$t->finish or die "CDB_File finish of $cachepath failed: $!\n";
	if (!-r $cachepath || !-s $cachepath) {
	    die "Really can't create cache file $cachepath with CDB_File";
	}
	1;
    } elsif ($cache_func_found eq 'CDB_File') {
	my $t = new CDB_File ($cachepath, "$cachepath.$$")
	    or die "Can't create cache file $cachepath with CDB_File: $!";
	# Using nfreeze instead of freeze saves about 10-20% of the
	# cdb file size (because of the smaller Storable header). Because
	# most data are string based, there is no penalty on little
	# endian machines.
	while(my($k,$v) = each %$ref) {
	    $t->insert($k, Storable::nfreeze(\$v));
	}
	$t->finish or die "CDB_File finish of $cachepath failed: $!\n";
	if (!-r $cachepath || !-s $cachepath) {
	    die "Really can't create cache file $cachepath with CDB_File (MLDBM, Storable)";
	}
	1;
    } elsif (defined $cache_func_found) {
	warn "Unknown cache function: $cache_func_found";
	undef;
    }
}

1;
