# -*- perl -*-

#
# $Id: Core.pm,v 1.31 2004/01/13 18:33:56 eserte Exp $
#
# Copyright (c) 1995-2003 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Core;

package Strassen;
use strict;
use BBBikeUtil;
#require StrassenNetz; # AUTOLOAD: activate
#require MultiStrassen; # AUTOLOAD: activate
#require Strassen::Util; # AUTOLOAD: activate
#require Strasse; # AUTOLOAD: activate
#use AutoLoader 'AUTOLOAD';
use vars qw(@datadirs $OLD_AGREP $VERBOSE $VERSION $can_strassen_storable);

use enum qw(NAME COORDS CAT);
use constant LAST => CAT;

$VERSION = sprintf("%d.%02d", q$Revision: 1.31 $ =~ /(\d+)\.(\d+)/);

if (defined $ENV{BBBIKE_DATADIR}) {
    require Config;
    push @datadirs, split /$Config::Config{'path_sep'}/o, $ENV{BBBIKE_DATADIR};
} else {
    push @datadirs, ("$FindBin::RealBin/data", './data')
	if defined $FindBin::RealBin;
    foreach (@INC) {
	push @datadirs, "$_/data";
    }
    # XXX push @datadirs, "http://www/~eserte/bbbike/root/data";
}

$OLD_AGREP = 0 if !defined $OLD_AGREP;

#eval 'require Strassen::Storable; $can_strassen_storable = 1';warn $@ if $@;

# static method to set the datadirs variable according to the used geography
# object
sub set_geography {
    my $geo = shift;
    @datadirs = $geo->datadir;
}

# XXX The Autoloader does not work for inherited methods... see
# MultiStrassen.pm for a non-comprehensive list of problematic methods.
use vars qw($AUTOLOAD);
sub AUTOLOAD {
    warn "Loading Strassen::CoreHeavy for $AUTOLOAD ...\n"
	if $VERBOSE;
    require Strassen::CoreHeavy;
    if (defined &$AUTOLOAD) {
	goto &$AUTOLOAD;
    } else {
	die "Cannot find $AUTOLOAD in ". __PACKAGE__;
    }
}

# Arguments:
#   NoRead
#   PreserveLineInfo
sub new {
    my($class, $filename, %arg) = @_;

    if (defined $filename &&
	$filename =~ /\.(dbf|sbn|sbx|shp|shx)$/) {
	require Strassen::ESRI;
	return Strassen::ESRI->new($filename, %arg);
    }

    my(@filenames);
    if (defined $filename) {
	push @filenames, $filename;
	if (!file_name_is_absolute($filename)) { 
	    push @filenames, map { $_ . "/$filename" } @datadirs;
	}
    }
    my $self = { Data => [],
		 Directives => {},
	       };
    bless $self, $class;

    if (@filenames) {
      TRY: {
	    if ($filename eq '-') {
		$self->{File} = "-";
		last TRY;
	    }

	    my $file;
	    foreach $file (@filenames) {
#  		if (!$arg{NoStorable} and $can_strassen_storable and -f "$file.st" and -r _) {
#  		    my $obj = Strassen::Storable->new("$file.st");
#  		    return $obj if $obj;
#  		}
		if (-f $file and -r _) {
		    $self->{File} = $file;
		    if ($file =~ /\.gz$/) {
			$self->{IsGzipped} = 1;
		    }
		    last TRY;
		}
		my $gzfile = "$file.gz";
		if (-f $gzfile and -r _) {
		    $self->{File} = $gzfile;
		    $self->{IsGzipped} = 1;
		    last TRY;
		}
	    }
	    # XXX 2. versuch mit internet für minimale Funktionsfähigkeit
	    # mit bbbike.ppl
	    if (0) {
	    foreach $file (@filenames) {
		eval q{
		    use lib "/home/e/eserte/src/perl/Hyper";
		    require Hyper;
		    my $cachefile = Hyper::hypercopy($file);
		    $self->{File} = $cachefile;
		};
		last TRY if $self->{File};
	    }
	    }
	    # XXX end

	    require Carp;
	    Carp::confess("Can't open ", join(", ", @filenames));
	}
	unless ($arg{NoRead}) {
	    $self->read_data(PreserveLineInfo => $arg{PreserveLineInfo});
	}
    }

    $self->{Pos}   = 0;

    $self;
}

sub read_data {
    my($self, %args) = @_;
    my $file = $self->{File};
    if ($self->{IsGzipped}) {
	die "Can't execute zcat $file" if !open(FILE, "gzip -dc $file |");
    } else {
	die "Can't open $file" if !open(FILE, $file);
    }
    warn "Read Strassen file $file...\n" if ($VERBOSE && $VERBOSE > 1);
    $self->{Modtime} = (stat($file))[STAT_MODTIME];
    binmode FILE;
    my @data;
    my %directives;
    if ($args{PreserveLineInfo}) {
	while (<FILE>) {
	    next if m{^(\#|\s*$)};
	    push @data, $_;
	    $self->{LineInfo}[$#data] = $.;
	}
    } else {
	while (<FILE>) {
	    if (/^\#:\s*(.*?):\s*(.*)/) {
		$directives{$1} = $2;
	    }
	    next if m{^(\#|\s*$)};
	    push @data, $_;
        }
    }
    warn "... done\n" if ($VERBOSE && $VERBOSE > 1);
    close FILE;
    $self->{Data} = \@data;
    $self->{Directives} = \%directives;
}

# Return true if there is no data loaded.
### AutoLoad Sub
sub has_data { $_[0]->{Data} && @{$_[0]->{Data}} }

### AutoLoad Sub
sub new_from_data {
    my($class, @data) = @_;
    $class->new_from_data_ref(\@data);
}

### AutoLoad Sub
sub new_from_data_ref {
    my($class, $data_ref) = @_;
    my $self = {};
    $self->{Data} = $data_ref;
    $self->{Pos}  = 0;
    bless $self, $class;
}

# Erzeugt ein neues Strassen-Objekt mit Restriktionen
### AutoLoad Sub
sub new_copy_restricted {
    my($class, $old_s, %args) = @_;
    my %restrictions;
    my %grep;
    if ($args{-restrictions}) {
	%restrictions = map { ($_ => 1) } @{ $args{-restrictions} };
    }
    if ($args{-grep}) {
	%grep = map { ($_ => 1) } @{ $args{-grep} };
    }

    my $res = $class->new;
    $old_s->init;
    while(1) {
	my $ret = $old_s->next;
	last if !@{$ret->[COORDS]};
	next if (keys %grep && !exists $grep{$ret->[CAT]});
	next if exists $restrictions{$ret->[CAT]};
	$res->push($ret);
    }

    $res->{File} = $old_s->file;
    $res->{Id}   = $old_s->id . "_restr_" . join("_", keys %restrictions);

    $res;
}

# Erzeugt aus dem Objekt eine Hash-Referenz mit erster Koordinate als Key
# und dem Namen als Value. Ist nur für ein-Punkt-Daten geeignet.
# init()/next() wird verwendet!
### AutoLoad Sub
sub get_hashref {
    my($self) = @_;
    my $hash = {};

    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	$hash->{$ret->[COORDS][0]} = $ret->[NAME];
    }

    $hash;
}

# Wie get_hashref, nur ist hier die Kategorie der Value.
# init()/next() wird verwendet!
### AutoLoad Sub
sub get_hashref_by_cat {
    my($self) = @_;
    my $hash = {};

    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	$hash->{$ret->[COORDS][0]} = $ret->[CAT];
    }

    $hash;
}

# Erzeugt ein Hash Name => [Positions] im Data-Array. Optional kann ein
# CODE ref angegeben werden, um den Hash-Key zu ändern.
# init()/next() wird verwendet!
### AutoLoad Sub
sub get_hashref_name_to_pos {
    my($self, $sub) = @_;
    my $hash = {};

    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	my $name = $sub ? $sub->($ret->[NAME]) : $ret->[NAME];
	push @{$hash->{$name}}, $self->pos;
    }

    $hash;
}

# Ausgabe des Source-Files
sub file { shift->{File} }

# ID (für Caching)
sub id {
    my $self = shift;
    if (defined $self->{Id}) {
	return $self->{Id};
    }
    if (defined $self->{File}) {
	require File::Basename;
	File::Basename::basename($self->{File});
    } else {
	undef;
    }
}

### AutoLoad Sub
sub as_string {
    join "", @{ shift->{Data} };
}

### AutoLoad Sub
sub write {
    my($self, $filename) = @_;
    if (!defined $filename) {
	$filename = $self->file;
    }
    if (!defined $filename) {
	warn "No filename specified";
	return 0;
    }
    if (open(COPY, ">$filename")) {
	binmode COPY;
	print COPY $self->as_string;
	close COPY;
	1;
    } else {
	warn "Can't write to $filename: $!" if $VERBOSE;
	0;
    }
}

### AutoLoad Sub
sub append {
    my($self, $filename) = @_;
    open(COPY, ">>$filename") or die "Can't append to $filename: $!";
    binmode COPY;
    print COPY $self->as_string;
    close COPY;
}

sub get {
    my($self, $pos) = @_;
    return [undef, [], undef] if $pos < 0;
    my $line = $self->{Data}->[$pos];
    parse($line);
}

# Returns a list of all elements in the streets database
# Warning: this method resets the iterator!
### AutoLoad Sub
sub get_all {
    my $self = shift;
    my @res;
    $self->init;
    while(1) {
	my $r = $self->next;
	return @res if !@{ $r->[COORDS] };
	push @res, $r;
    }
}

# Für den angegebenen Namen wird die erste gefundene Zeile im selben Format
# wie bei get(), next() und parse() zurückgegeben.
# Achtung: da mit init() und next() gearbeitet wird, wird durch diese Methode
# eine laufende Schleife aus dem Konzept gebracht!
# If $rxcmp is true, then a regexp match is done.
### AutoLoad Sub
sub get_by_name {
    my($self, $name, $rxcmp) = @_;
    $self->init;
    while(1) {
	my $ret = $self->next;
	return undef if !@{$ret->[COORDS]};
	return $ret if ((!$rxcmp && $ret->[NAME] eq $name) ||
			( $rxcmp && $ret->[NAME] =~ /$name/));
    }
}

# Like get_by_name, but return all matching streets in a list.
sub get_all_by_name {
    my($self, $name, $rxcmp) = @_;
    my @res;
    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	push @res, $ret if ((!$rxcmp && $ret->[NAME] eq $name) ||
			    ( $rxcmp && $ret->[NAME] =~ /$name/));
    }
    @res;
}

# XXX Die zwei verschiedenen Aufrufarten für das Koordinatenargument in
# set und push ist unbefriedigend.
### AutoLoad Sub
sub set {
    my($self, $index, $arg) = @_;
    $self->{Data}[$index] = arr2line($arg);
}
sub set_current { # funktioniert in init/next-Schleifen
    my($self, $arg) = @_;
    $self->set($self->{Pos}, $arg);
}

# arguments: [name, [xy1, xy2, ...], cat]
sub push {
    my($self, $arg) = @_;
    my $x = [$arg->[NAME], join(" ", @{$arg->[COORDS]}), $arg->[CAT]];
    push @{$self->{Data}}, arr2line($x);
}

sub delete_current { # funktioniert in init/next-Schleifen
    my($self) = @_;
    return if $self->{Pos} < 0;
    splice @{$self->{Data}}, $self->{Pos}, 1;
    $self->{Pos}--;
}

# wandelt eine Array-Referenz ["name", $Koordinaten, "cat"] in
# einen String zum Abspeichern um
# Achtung: das Koordinaten-Argument ist hier anders als beim Rückgabewert von
# parse()! Siehe arr2line2().
# Tabs werden aus dem Namen entfernt
# Achtung: ein "\n" wird angehängt
### AutoLoad Sub
sub arr2line {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/\t/ /;
    "$name\t$arg->[CAT] $arg->[COORDS]\n"
}

# wie arr2line, aber ohne Newline
# Tabs werden aus dem Namen entfernt
### AutoLoad Sub
sub _arr2line {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/\t/ /;
    "$name\t$arg->[CAT] $arg->[COORDS]"
}

# Wie _arr2line, aber das COORDS-Argument ist eine Array-Referenz wie
# beim Rückgabewert von parse().
# Tabs werden aus dem Namen entfernt
### AutoLoad Sub
sub arr2line2 {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/\t/ /;
    "$name\t$arg->[CAT] " . join(" ", @{ $arg->[COORDS] });
}

sub parse {
    my $line = shift;
    return [undef, [], undef] if !$line;
    my $tab_inx = index($line, "\t");
    if ($tab_inx < 0) {
	warn "Probably tab character is missing\n";
	[$line];
    } else {
	my @s = split /\s+/, substr($line, $tab_inx+1);
	my $category = shift @s;
	[substr($line, 0, $tab_inx), \@s, $category];
    }
}

### AutoLoad Sub
sub get_obj {
    my($self, $pos) = @_;
    Strasse->new($self->get($pos));
}

# initialisiert für next() und gibt *keinen* Wert zurück
sub init {
    my $self = shift;
    $self->{Pos} = -1;
}

# Like init(), but use a private iterator
sub init_for_iterator {
    my($self, $iterator) = @_;
    $self->{"Pos_Iterator_$iterator"} = -1;
}

# Setzt den Index auf den angegeben Wert (jedenfalls so, dass ein
# anschließendes next() das richtige zurückgibt).
sub set_index {
    $_[0]->{Pos} = $_[1] - 1;
}

sub set_last {
    $_[0]->{Pos} = scalar @{$_[0]->{Data}};
}

# initialisiert für next() und gibt den ersten Wert zurück
### AutoLoad Sub
sub first {
    my $self = shift;
    $self->{Pos} = 0;
    $self->get(0);
}

sub next {
    my $self = shift;
    $self->get(++($self->{Pos}));
}

# Like next(), but use a private iterator
sub next_for_iterator {
    my($self, $iterator) = @_;
    $self->get(++($self->{"Pos_Iterator_$iterator"}));
}

sub prev {
    my $self = shift;
    $self->get(--($self->{Pos}));
}

sub next_obj {
    my $self = shift;
    $self->get_obj(++($self->{Pos}));
}

#del?
#  # XXX wird das hier verwendet? Schönerer Ersatz für !@{$ret->[COORDS]} ?
#  sub at_end {
#      my $self = shift;
#      $self->{Pos} >= $#{$self->{Data}};
#  }

sub count {
    my $self = shift;
    scalar @{$self->{Data}};
}

# gibt die aktuelle Position zurück
sub pos { shift->{Pos} }

sub line {
    my $self = shift;
    $self->{LineInfo}[$self->{Pos}];
}

# Accessor for Data (but it's OK to use {Data})
sub data { shift->{Data} }

# Gibt die Positionen (als Array) für einen bestimmten Namen zurück
# Achtung: eine laufende init/next-Schleife wird hiermit zurückgesetzt!
### AutoLoad Sub
sub pos_from_name {
    my($self, $name) = @_;
    my @res;
    my $found = 0;
    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	if ($ret->[NAME] eq $name) {
	    CORE::push(@res, $self->pos);
	    $found++;
	} elsif ($found) {
	    last;
	}
    }
    @res;
}

# for Object::Iterate
*__init__ = \&init;
sub __more__ { $_[0]->{Pos} < $#{$_[0]->{Data}} }
*__next__ = \&next;

# Statische Methode.
# Wandelt die Indices aus dem Ergebnis von get() (2. Element) in
# Koordinaten um (Format des Arguments: ["x1,y1", "x2,y2", ...])
# Gibt eine Referenz auf ein Array zurück: [[x1,y1], [x2,y2] ...]
sub to_koord_slow {
    my($resref) = @_;
    my @res;
    foreach (@$resref) {
	if (/^(-?\d+),(-?\d+)$/) {
	    CORE::push(@res, [$1, $2]);
	} elsif (/(-?\d+),(-?\d+)$/) { # ignore prefix XXX
	    CORE::push(@res, [$1, $2]);
	} elsif ($_ eq '*') {
	    CORE::push(@res, $_);
	} else {
	    warn "Unrecognized reference: $_";
	    return [];
	}
    }
    \@res;
}

# Statische Methode.
# wie to_koord, nur für einen Punkt
# XXX Koordinaten der Form prefix(x,y) bearbeiten
sub to_koord1_slow {
    my($s) = @_;
    if ($s =~ /^(-?\d+),(-?\d+)$/) {
	[$1, $2];
    } elsif ($s =~ /^((:[^:]*:)?([A-Za-z])?)?(-?\d+),(-?\d+)$/) {
	# Ausgabe: x, y, coordsystem, bahnhof
	[$4, $5, $3, $2];
    } else {
	warn "Unrecognized string: $s...";
	[undef, undef]; # XXX
    }
}

*to_koord = \&to_koord_slow;
*to_koord1 = \&to_koord1_slow;

# Return crossings as an array or hash reference.
# Argumente:
#   RetType: hash, hashpos, array (default) oder arraypos
#            Bei den ...pos-Varianten wird statt des Straßennamens die
#            Position im Strassen-Objekt zurückgegeben.
#   UseCache: gibt an, ob vom Cache gelesen und ein Cache geschrieben werden
#             soll
#   Kurvenpunkte: bei TRUE werden auch die Kurvenpunkte zurückgegeben
#   AllPoints:    synonym for KurvenPunkte
#
# See below for the output forms.
### AutoLoad Sub
sub all_crossings {
    my($self, %args) = @_;
    my $rettype      = $args{RetType};
    my $use_cache    = $args{UseCache};
    my $all_points   = $args{AllPoints} || $args{Kurvenpunkte};
    my $min_strassen = ($all_points ? 1 : 2);

    if (!defined $rettype) { $rettype = 'array' }
    if ($rettype !~ /^(array|hash)(pos)?$/) {
	die "Wrong RetType $rettype";
    }
    my $basename = $self->id;
    my $cachefile = "all_crossings_${basename}_$rettype";
    if ($all_points) {
	$cachefile .= "_kurvenp";
    }
    if ($use_cache && $rettype =~ /^hash/) {
	require Strassen::Util;
	my $hashref = Strassen::Util::get_from_cache($cachefile, [$self->file]);
	if (defined $hashref) {
	    warn "Using cache for $cachefile\n" if $VERBOSE;
	    return $hashref;
	}
    }

    my $inacc;
    if ($self->{Inaccessible}) {
	require Strassen::Kreuzungen;
	my $cr = Kreuzungen->new_from_strassen
	    (WantPos => 1,
	     Strassen => $self->{Inaccessible},
	    );
	$inacc = $cr->{Hash};
    }

    # RetType ...pos: Positionen statt Straßennamen speichern
    my $store_pos = ($rettype =~ /pos$/);
    my %crossings;
    my %crossing_name;
    $self->init();
    while(1) {
	my $ret = $self->next();
	my @kreuzungen = @{$ret->[COORDS]};
	last if @kreuzungen == 0;
	my $store = ($store_pos ? $self->pos : $ret->[NAME]);
	for my $xy (@kreuzungen) {
	    next if $inacc && exists $inacc->{$xy};
	    $crossings{$xy}++;
	  TEST: {
		for my $test (@{$crossing_name{$xy}}) {
		    last TEST if ($test eq $store);
		}
		CORE::push(@{$crossing_name{$xy}}, $store);
	    }
	}
    }
    if ($rettype =~ /^hash/) { # Rückgabewert: "x,y" => [name1,name2 ...]
	my @to_del;
	while(my($k, $v) = each %crossings) {
	    if ($v < $min_strassen) {
		CORE::push(@to_del, $k);
	    } else {
		$crossings{$k} = $crossing_name{$k};
	    }
	}
	foreach (@to_del) {
	    delete $crossings{$_};
	}
	if ($use_cache) {
	    require Strassen::Util;
	    if (Strassen::Util::write_cache(\%crossings, $cachefile)) {
		warn "Wrote cache ($cachefile)\n" if $VERBOSE;
	    }
	}
	\%crossings;
    } else { # Rückgabewert: [x, y, "name1/name2/..."]
	my @crossings;
	while(my($k, $v) = each %crossings) {
	    if ($v >= $min_strassen) {
		my($x, $y) = split(/,/, $k);
		CORE::push(@crossings, [$x, $y, join("/", @{$crossing_name{$k}})]);
	    }
	}
	\@crossings;
    }
}

### AutoLoad Sub
sub strip_bezirk { Strasse::strip_bezirk(@_) }

# Für Orte: trennt den Namen vom Zusatz (z.B. ("Frankfurt", "Oder")
### AutoLoad Sub
sub split_ort {
    split /\|/, $_[0], 2;
}

# Arguments (hash-style):
#   UseCache: use cache
#   Exact: use "exact" algorithm
#   GridHeight, GridWidth: grid extents (by default 1000)
# With -rebuild => 1 the grid will be build again.
# Uses the private Strassen::Core iterator "make_grid".
### AutoLoad Sub
sub make_grid {
    my($self, %args) = @_;
    if ($args{-rebuild} && $self->{Grid}) {
	%args = (GridWidth => $self->{GridWidth},
		 GridHeight => $self->{GridHeight},
		 Exact => $self->{GridIsExact},
		 UseCache => $self->{GridUseCache},
		);
    }
    my $use_cache = $args{UseCache};
    my $use_exact = $args{Exact}||0;
    $self->{GridWidth}  = (defined $args{GridWidth}
			   ? $args{GridWidth} : 1000);
    $self->{GridHeight} = (defined $args{GridHeight}
			   ? $args{GridHeight} : $self->{GridWidth});
    my $cachefile = "grid" . ($use_exact ? "x" : "") . "_" . $self->id .
	            "_" . $self->{GridWidth}."x".$self->{GridHeight};
    if ($use_cache) {
	require Strassen::Util;
	my $hashref = Strassen::Util::get_from_cache($cachefile, [$self->file]);
	if (defined $hashref) {
	    warn "Using grid cache for $cachefile\n" if $VERBOSE;
	    $self->{Grid} = $hashref;
	    return;
	}
    }
    $self->{Grid} = {};
    $self->{GridIsExact} = $use_exact;
    $self->{GridUseCache} = $use_cache;
    my $grid_build = ($use_exact
		      ? $self->_make_grid_exact
		      : $self->_make_grid_fast);
    while(my($g, $v) = each %$grid_build) {
	$self->{Grid}{$g} = [keys %$v];
    }
    if ($use_cache) {
	require Strassen::Util;
	if (Strassen::Util::write_cache($self->{Grid}, $cachefile)) {
	    warn "Wrote cache ($cachefile)\n" if $VERBOSE;
	}
    }
}

### AutoLoad Sub
sub _make_grid_fast {
    my $self = shift;
    my %grid_build;
    $self->init_for_iterator("make_grid");
    my $strpos = 0;
    while(1) {
	my $r = $self->next_for_iterator("make_grid");
	last if !@{$r->[COORDS]};
	foreach my $c (@{$r->[COORDS]}) {
	    $grid_build{join(",",$self->grid(split(/,/, $c)))}->{$strpos}++;
	}
	$strpos++;
    }
    \%grid_build;
}

### AutoLoad Sub
sub _make_grid_exact {
    my $self = shift;

    if (!eval { require VectorUtil; 1 }) {
	warn "Can't load VectorUtil.pm, fallback to _make_grid_fast";
	return $self->_make_grid_fast;
    }
    eval {
	require VectorUtil::InlineDist;
    };
    if ($@ && $VERBOSE) { warn $@ }

    my %grid_build;
    $self->init_for_iterator("make_grid");
    my $strpos = 0;
    while(1) {
	my $r = $self->next_for_iterator("make_grid");
	last if !@{$r->[COORDS]};
	if (@{ $r->[COORDS] } == 1) {
	    $grid_build{join(",",$self->grid(split(/,/, $r->[COORDS][0])))}->{$strpos}++;
	} else {
	    for my $i (0 .. $#{$r->[COORDS]}-1) {
		my($x1, $y1) = split(',', $r->[COORDS][$i]);
		my($x2, $y2) = split(',', $r->[COORDS][$i+1]);
		my($from_grid_x, $from_grid_y) = $self->grid($x1,$y1);
		my($to_grid_x, $to_grid_y) = $self->grid($x2,$y2);
		($from_grid_x, $to_grid_x) = ($to_grid_x, $from_grid_x)
		    if $to_grid_x < $from_grid_x;
		($from_grid_y, $to_grid_y) = ($to_grid_y, $from_grid_y)
		    if $to_grid_y < $from_grid_y;
		for my $grid_x ($from_grid_x .. $to_grid_x) {
		    for my $grid_y ($from_grid_y .. $to_grid_y) {
			my $grid_xy = join(",", $grid_x, $grid_y);
			next if $grid_build{$grid_xy}->{$strpos};
			$grid_build{$grid_xy}->{$strpos}++
			    if VectorUtil::vector_in_grid($x1,$y1,$x2,$y2,
							  $grid_x*$self->{GridWidth}, $grid_y*$self->{GridHeight}, ($grid_x+1)*$self->{GridWidth}, ($grid_y+1)*$self->{GridHeight});
		    }
		}
	    }
	}
	$strpos++;
    }
    \%grid_build;
}

### AutoLoad Sub
sub grid {
    my($self, $x, $y) = @_;
    my($gx,$gy) = (int($x/$self->{GridWidth}), int($y/$self->{GridHeight}));
    $gx-- if $x < 0;
    $gy-- if $y < 0;
    ($gx,$gy);
}

# Gibt eine Liste mit den neuen Gitterquadranten für die
# Koordinateneckpunte aus. Mit dem Argument KnownGrids können bereits
# bekannte Quadranten aus der Liste ausgeschlossen werden.
### AutoLoad Sub
sub get_new_grids {
    my($self, $x1, $y1, $x2, $y2, %args) = @_;
    if ($x2 < $x1) { ($x2, $x1) = ($x1, $x2) }
    if ($y2 < $y1) { ($y2, $y1) = ($y1, $y2) }
    my $known_grids = {};
    if (exists $args{'KnownGrids'} and ref $args{'KnownGrids'} eq 'HASH') {
	$known_grids = $args{'KnownGrids'};
    }
    my @new_grids;
    my($x,$ybeg) = $self->grid($x1,$y1);
    my($xend,$yend) = $self->grid($x2,$y2);
    while ($x <= $xend) {
	my $y = $ybeg;
	while ($y <= $yend) {
	    my $xy = "$x,$y";
	    if (!$known_grids->{$xy}) {
		CORE::push(@new_grids, $xy);
		$known_grids->{$xy}++;
	    }
	    $y++;
	}
	$x++;
    }

    @new_grids;
}

# Checks if the coordinate is present in the Strassen data, so there is no
# need to create a $net. The coord is in the form "$x,$y".
# Warning: Initializes the iterator!
sub reachable {
    my($self, $coord) = @_;
    $self->init;
    while(1) {
	my $ret = $self->next;
	return 0 if !@{ $ret->[Strassen::COORDS] };
	foreach my $c (@{ $ret->[Strassen::COORDS] }) {
	    return 1 if ($c eq $coord);
	}
    }
}

# Get the nearest point at a street for the given point.
# Further arguments:
#   FullReturn: return all information instead only the returned point
#   AllReturn:  return an array reference with the data for all nearest points,
#               not just the first one
# The returned object contains:
#   StreetObj:  the street object (result of Strassen::get)
#   N:          the index of the street object in Strassen->{Data}
#   CoordIndex: the index of Coord in the Strassen::COORDS array
#   Dist:       the distance from the given point to Coord
#   Coord:      the nearest coordinate to the given point
# Uses the private iterator "make_grid"
sub nearest_point {
    my($s, $xy, %args) = @_;
    my($x,$y) = split /,/, $xy;
    my $mindist = 40_000*1000; # größte Distanz auf der Erde
    my @line;

    if (!defined &VectorUtil::distance_point_line) {
	require VectorUtil;
	eval {
	    require VectorUtil::InlineDist;
	};
	if ($@ && $VERBOSE) { warn $@ }
    }

    $s->make_grid(UseCache => 1,
		  Exact => 1) unless $s->{Grid};
    my($grx,$gry) = $s->grid($x,$y);

    my %seen;
    for my $xx ($grx-1 .. $grx+1) {
	for my $yy ($gry-1 .. $gry+1) {
	    # prevent autovivify (bad for CDB_File)
	    next unless (exists $s->{Grid}{"$xx,$yy"});
	    foreach my $n (@{ $s->{Grid}{"$xx,$yy"} }) {
		next if $seen{$n};
		$seen{$n}++;
		my $r = $s->get($n);

		my @p;
		foreach (@{ $r->[Strassen::COORDS] }) {
		    CORE::push(@p, split /,/, $_);
		}

		if (@p == 2) { # point
		    my $new_mindist = sqrt(sqr($x-$p[0])+sqr($y-$p[1]));
		    if ($mindist >= $new_mindist) {
			my $line = {StreetObj  => $r,
				    N          => $n,
				    CoordIndex => 0,
				    Dist       => $new_mindist,
				    Coords     => \@p,
				   };
			if ($mindist == $new_mindist) {
			    CORE::push(@line, $line);
			} else {
			    @line = $line;
			}
			$mindist = $new_mindist;
		    }
		} else { # line
		    for(my $i=0; $i<$#p-1; $i+=2) {
			my $new_mindist = VectorUtil::distance_point_line($x,$y,@p[$i..$i+3]);
			if ($mindist >= $new_mindist) {
			    my $line = {StreetObj  => $r,
					N          => $n,
					CoordIndex => $i/2,
					Dist       => $new_mindist,
					Coords     => [@p[$i..$i+3]],
				       };
			    if ($mindist == $new_mindist) {
				CORE::push(@line, $line);
			    } else {
				@line = $line;
			    }
			    $mindist = $new_mindist;
			}
		    }
		}

	    }
	}
    }

    if (@line) {
	for my $line (@line) {
	    my($s0x,$s0y,$s1x,$s1y) = @{$line->{Coords}};
	    if (!defined $s1x) { # point
		$line->{Coord} = "$s0x,$s0y";
	    } else {
		my $dist0 = sqrt(sqr($s0x-$x)+sqr($s0y-$y));
		my $dist1 = sqrt(sqr($s1x-$x)+sqr($s1y-$y));
		if ($dist0 < $dist1) {
		    $line->{Coord} = "$s0x,$s0y";
		} else {
		    $line->{Coord} = "$s1x,$s1y";
		}
	    }
	}
	if ($args{FullReturn}) {
	    $args{AllReturn} ? \@line : $line[0];
	} else {
	    $args{AllReturn} ? [map { $_->{Coord} } @line] : $line[0]->{Coord};
	}
    } else {
	undef;
    }
}

sub get_conversion {
    my $self = shift;
    my $convsub;
    if ($self->{Directives}{map}) {
	my $map = $self->{Directives}{map};
	require Karte;
	Karte::preload($map);
	$convsub = sub {
	    join ",", $Karte::map{$map}->map2standard(split /,/, $_[0]);
	};
    }
    $convsub;
}

# set all $VERBOSE vars in this file
sub set_verbose {
    my $verbose = shift;
    $StrassenNetz::VERBOSE    = $verbose;
    $Strassen::VERBOSE        = $verbose;
    $Strassen::Util::VERBOSE  = $verbose;
    $Kreuzungen::VERBOSE      = $verbose;
    $StrassenNetz::CNetFile::VERBOSE = $verbose;
}

sub DESTROY { }

1;

__END__

=head1 NAME

Strassen::Core - the main Strassen object for bbd data

=head1 SYNOPSIS

   use Strassen::Core;
   $s = Strassen->new($bbdfile);
   $s->init;
   while(1) {
     my $ret = $s->next;
     last if !@{ $ret->[Strassen::COORDS] };
     print "Name:        $ret->[Strassen::NAME]\n";
     print "Category:    $ret->[Strassen::CAT]\n";
     print "Coordinates: " . join(" ", @{ $ret->[Strassen::COORDS] }) . "\n";
   }

=head1 DESCRIPTION

See SYNOPSIS.

=head1 SEE ALSO

L<BBBikeRouting>.
