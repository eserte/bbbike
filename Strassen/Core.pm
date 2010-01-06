# -*- perl -*-

#
# $Id: Core.pm,v 1.94 2009/01/17 15:48:53 eserte Exp $
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
use vars qw(@datadirs $OLD_AGREP $VERBOSE $VERSION $can_strassen_storable
	    %directive_aliases
	   );

use enum qw(NAME COORDS CAT);
use constant LAST => CAT;

$VERSION = sprintf("%d.%02d", q$Revision: 1.94 $ =~ /(\d+)\.(\d+)/);

if (defined $ENV{BBBIKE_DATADIR}) {
    require Config;
    push @datadirs, split /$Config::Config{'path_sep'}/o, $ENV{BBBIKE_DATADIR};
} else {
    # XXX use BBBikeUtil::bbbike_root().'/data'!
    push @datadirs, BBBikeUtil::bbbike_root() . '/data';
    push @datadirs, ("$FindBin::RealBin/data", './data')
	if defined $FindBin::RealBin;
    foreach (@INC) {
	push @datadirs, "$_/data";
    }
    # XXX push @datadirs, "http://www/~eserte/bbbike/root/data";
}

$OLD_AGREP = 0 if !defined $OLD_AGREP;

%directive_aliases = (attrs => "attributes");

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
#   PreserveComments
#   UseLocalDirectives
#   CustomPush (only for MapInfo)
sub new {
    my($class, $filename, %args) = @_;
    if (defined $filename) {
	if      ($filename =~ /\.(dbf|sbn|sbx|shp|shx)$/) {
	    require Strassen::ESRI;
	    return Strassen::ESRI->new($filename, %args);
	} elsif ($filename =~ /\.(mif|mid)$/i) {
	    require Strassen::MapInfo;
	    return Strassen::MapInfo->new($filename, %args);
	} elsif ($filename =~ /\.e00$/i) {
	    require Strassen::E00;
	    return Strassen::E00->new($filename, %args);
	} elsif ($filename =~ /\.(wpt|trk|rte)$/) {
	    require Strassen::Gpsman;
	    return Strassen::Gpsman->new($filename, %args);
	} elsif ($filename =~ /waypoint\.txt$/) {
	    require Strassen::WaypointPlus;
	    return Strassen::WaypointPlus->new($filename, %args);
	} elsif ($filename =~ /\.ovl$/i) {
	    require Strassen::Gpsman;
	    require GPS::Ovl;
	    my $ovl = GPS::Ovl->new;
	    $ovl->check($filename);
	    my $gpsman_data = $ovl->convert_to_gpsman;
	    return Strassen::Gpsman->new_from_string($gpsman_data, File => $filename, %args);
	} elsif ($filename =~ /\.(mps|gpx|g7t)$/i) {
	    if ($filename =~ /\.gpx$/ && eval { require Strassen::GPX; 1 }) {
		return Strassen::GPX->new($filename, %args);
	    } else {
		require Strassen::FromRoute;
		return Strassen::FromRoute->new($filename, %args);
	    }
	} elsif ($filename =~ /\.km[lz]$/i) {
	    if (eval { require Strassen::KML; 1 }) {
		return Strassen::KML->new($filename, %args);
	    }
	} elsif ($filename =~ /\.xml$/ && eval { require Strassen::Touratech; 1 }) {
	    # XXX Maybe really check for touratech files
	    return Strassen::Touratech->new($filename, %args);
	}
    }

    my(@filenames);
    if (defined $filename) {
	if (!file_name_is_absolute($filename)) { 
	    push @filenames, map { $_ . "/$filename" } @datadirs;
	}
	# relative filenames to end
	push @filenames, $filename;
    }
    my $self = { Data => [],
		 Directives => [],
		 GlobalDirectives => {},
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
#  		if (!$args{NoStorable} and $can_strassen_storable and -f "$file.st" and -r _) {
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
	unless ($args{NoRead}) {
	    $self->read_data(PreserveLineInfo   => $args{PreserveLineInfo},
			     UseLocalDirectives => $args{UseLocalDirectives},
			     PreserveComments   => $args{PreserveComments},
			    );
	}
    }

    $self->{Pos}   = 0;

    $self;
}

sub new_stream {
    my($class, $filename, %args) = @_;
    $args{NoRead} = 1;
    $class->new($filename, %args);
}

sub read_stream {
    my($self, $callback, %args) = @_;
    my $fh = $self->open_file(%args);
    $args{Callback} = $callback;
    $args{UseLocalDirectives} = 1 if !exists $args{UseLocalDirectives};
    $self->read_from_fh($fh, %args);
}

sub open_file {
    my($self, %args) = @_;

    my $file = $self->{File};
    if ($self->{IsGzipped}) {
	die "Can't execute zcat $file" if !open(FILE, "gzip -dc $file |");
    } else {
	if (!open(FILE, $file)) {
	    require Carp;
	    Carp::confess("Can't open $file");
	}
    }
    warn "Read Strassen file $file...\n" if ($VERBOSE && $VERBOSE > 1);
    $self->{Modtime} = (stat($file))[STAT_MODTIME];
    binmode FILE;

    \*FILE;
}

sub read_data {
    my($self, %args) = @_;
    my $fh = $self->open_file(%args);
    $self->read_from_fh($fh, %args);
}

sub read_from_fh {
    my($self, $fh, %args) = @_;

    my @data;
    my @directives;

    my $read_only_global_directives = $args{ReadOnlyGlobalDirectives};
    my $use_local_directives = $args{UseLocalDirectives};
    my $callback = $args{Callback};
    my $has_tie_ixhash = eval {
	require Tie::IxHash;
	# See http://rt.cpan.org/Ticket/Display.html?id=39619
	if (!defined &Tie::IxHash::SCALAR) {
	    *Tie::IxHash::SCALAR = sub {
		scalar @{ $_[0]->[1] };
	    };
	}
	1;
    };

    use constant DIR_STAGE_LOCAL => 0;
    use constant DIR_STAGE_GLOBAL => 1;
    my $directives_stage = DIR_STAGE_LOCAL;

    my %global_directives;
    my %line_directive;
    if ($has_tie_ixhash) {
	tie %line_directive, "Tie::IxHash";
	tie %global_directives, "Tie::IxHash";
    }
    my @block_directives;
    my @block_directives_line;
    my $preserve_line_info = $args{PreserveLineInfo} || 0;
    my $preserve_comments  = $args{PreserveComments} || 0;

    while (<$fh>) {
	if (/^\#:\s*([^\s:]+):?\s*(.*)$/) {
	    my($directive, $value_and_marker) = ($1, $2);
	    $directive = $directive_aliases{$directive}
		if exists $directive_aliases{$directive};
	    my($value, $is_block_begin, $is_block_end);
	    if ($value_and_marker =~ /^\^+\s*$/) {
		$is_block_end = 1;
		$value = "";
	    } else {
		$value_and_marker =~ /(.*?)(\s*vvv+\s*)?$/;
		if ($2) {
		    $is_block_begin = 1;
		}
		$value = $1;
	    }

	    if ($. == 1) {
		$directives_stage = DIR_STAGE_GLOBAL;
	    } elsif ($directives_stage eq DIR_STAGE_GLOBAL && $_ =~ /^\#:$/) {
		$directives_stage = DIR_STAGE_LOCAL;
	    }
	    if ($directives_stage == DIR_STAGE_GLOBAL) {
		push @{ $global_directives{$directive} }, $value;
		if ($directive eq 'encoding') {
		    switch_encoding($fh, $value);
		}
	    } elsif ($use_local_directives) {
		if ($is_block_begin) {
		    push @block_directives, [$directive => $value];
		    push @block_directives_line, $.;
		} elsif ($is_block_end) {
		    pop @block_directives;
		    pop @block_directives_line;
		} else {
		    push @{ $line_directive{$directive} }, $value;
		}
	    }
	    next;
	}
	$directives_stage = DIR_STAGE_LOCAL if $directives_stage == DIR_STAGE_GLOBAL;
	last if ($read_only_global_directives);
	if ($preserve_comments) {
	    next if m{^\#:}; # directives already handled
	} else {
	    next if m{^(\#|\s*$)};
	}

	my $data_pos = $#data + 1;

	my $this_directives;
	if ($use_local_directives && (@block_directives || %line_directive)) { # Note: %line_directive is a tied hash and slower to check!
	    if (!$callback) {
		if ($has_tie_ixhash && !$directives[$data_pos]) {
		    tie %{ $directives[$data_pos] }, 'Tie::IxHash';
		}
		$this_directives = $directives[$data_pos];
	    } else {
		if ($has_tie_ixhash) {
		    tie %$this_directives, 'Tie::IxHash';
		} else {
		    $this_directives = {};
		}
	    }

	    while(my($directive,$values) = each %line_directive) {
		push @{ $this_directives->{$directive} }, @$values;
	    }
	    for (@block_directives) {
		my($directive, $value) = @$_;
		push @{ $this_directives->{$directive} }, $value;
	    }
	    if (%line_directive) {
		%line_directive = ();
	    }
	}

	if (!$callback) {
	    push @data, $_;
	    if ($preserve_line_info) {
		$self->{LineInfo}[$data_pos] = $.;
	    }
	} else {
	    $callback->(parse($_), $this_directives, $.);
	}

    }
    if (@block_directives) {
	my $msg = "The following block directives were not closed:";
	for my $i (0 .. $#block_directives) {
	    $msg .= " '@{$block_directives[$i]}' (start at line $block_directives_line[$i])";
	}
	die $msg, "\n";
    }
    if (%line_directive) {
	die "Stray line directive `@{[ keys %line_directive ]}' at end of file\n";
    }
    warn "... done\n" if ($VERBOSE && $VERBOSE > 1);
    close $fh;

    $self->{Data} = \@data;
    $self->{Directives} = \@directives;
    $self->{GlobalDirectives} = \%global_directives;
}

# Return true if there is no data loaded.
### AutoLoad Sub
sub has_data { $_[0]->{Data} && @{$_[0]->{Data}} }

# new_from_data can't handle directives:
### AutoLoad Sub
sub new_from_data {
    my($class, @data) = @_;
    $class->new_from_data_ref(\@data);
}

# new_from_data_ref can't handle directives:
### AutoLoad Sub
sub new_from_data_ref {
    my($class, $data_ref) = @_;
    my $self = {};
    $self->{Data} = $data_ref;
    $self->{Pos}  = 0;
    bless $self, $class;
}

# Note that this constructor expects binary data i.e. *octets*
# not character data! 
### AutoLoad Sub
sub new_from_data_string {
    my($class, $string, %args) = @_;
    my $self = { Pos => 0 };
    bless $self, $class;
    my $fh;
    if ($] >= 5.008) {
	# Make sure we have raw octets. Encoding is controlled
	# through an "encoding" bbd directive
	require Encode;
	if (Encode::is_utf8($string)) {
	    $string = Encode::encode("iso-8859-1", $string);
	}
	# string eval because for older perl's this is invalid syntax
	eval 'open($fh, "<", \$string)';
    } else {
	require IO::String; # XXX add as prereq_pm for <5.008
	$fh = IO::String->new($string);
    }
    $self->read_from_fh($fh, %args);
    $self;
}

# Erzeugt ein neues Strassen-Objekt mit Restriktionen
# -restrictions => \@cats: do not copy records with these categories
# -grep => \@cats: do only copy records with these categories (only if set)
# -callback => sub { my($record) = shift; ... }: copy only if the callback
#    returns a true value for the given record
### AutoLoad Sub
sub new_copy_restricted {
    my($class, $old_s, %args) = @_;
    my %restrictions;
    my %grep;
    my $callback;
    if ($args{-restrictions}) {
	%restrictions = map { ($_ => 1) } @{ $args{-restrictions} };
    }
    if ($args{-grep}) {
	%grep = map { ($_ => 1) } @{ $args{-grep} };
    }
    $callback = delete $args{-callback};

    my $res = $class->new;
    $old_s->init;
    while(1) {
	my $ret = $old_s->next;
	last if !@{$ret->[COORDS]};
	next if (%grep && !exists $grep{$ret->[CAT]});
	next if exists $restrictions{$ret->[CAT]};
	next if ($callback && !$callback->($ret));
	$res->push($ret);
    }

    $res->{File} = $old_s->file;
    $res->{DependentFiles} = $old_s->{DependentFiles};
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

sub dependent_files {
    my $self = shift;
    if ($self->{DependentFiles}) {
	@{ $self->{DependentFiles} };
    } else {
	defined $self->file ? $self->file : ();
    }
}

# ID (für Caching)
sub id {
    my $self = shift;
    if (defined $self->{Id}) {
	return $self->{Id};
    }
    my @depfiles = $self->dependent_files;
    if (@depfiles) {
	require File::Basename;
	my $basedir = File::Basename::basename(File::Basename::dirname($depfiles[0]));
	$basedir = ($basedir eq "data" ? "" : $basedir . "_");
	$basedir . join("_", map { File::Basename::basename($_) } @depfiles);
    } else {
	undef;
    }
}

### AutoLoad Sub
sub as_string {
    my($self, %args) = @_;
    my $s = "";
    my $maybe_need_directive_separator = 1;
    if (!$args{IgnoreDirectives}) {
	$s = $self->global_directives_as_string; # force at beginning of $s
	if ($s ne '') {
	    $maybe_need_directive_separator = 0;
	}
    }
    if (!$args{IgnoreDirectives} && $self->{Directives}) {
	if ($maybe_need_directive_separator && $self->{Directives}[0] && keys %{ $self->{Directives}[0] }) {
	    $s .= "#:\n";
	}
	my %current_block_directives;
	for my $pos (0 .. $#{$self->{Data}}) {
	    my $close_blocks = "";
	    if ($self->{Directives}[$pos]) {
		while(my($directive,$values) = each %{ $self->{Directives}[$pos] }) {
		    for my $value (@$values) {
			my $continuing_to_next_line = 0;
			if ($pos < $#{$self->{Data}}) {
			    if ($self->{Directives}[$pos+1] &&
				exists $self->{Directives}[$pos+1]{$directive} &&
				grep { $_ eq $value } @{ $self->{Directives}[$pos+1]{$directive} }) {
				$continuing_to_next_line = 1;
			    }
			}
			if ($continuing_to_next_line && !$current_block_directives{$directive}{$value}) {
			    $s .= "#: $directive: $value vvv\n";
			    $current_block_directives{$directive}{$value} = 1;
			} elsif ($continuing_to_next_line && $current_block_directives{$directive}{$value}) {
			    # do nothing
			} elsif (!$continuing_to_next_line && $current_block_directives{$directive}{$value}) {
			    $close_blocks .= "#: $directive: ^^^\n";
			    delete $current_block_directives{$directive}{$value};
			} else {
			    $s .= "#: $directive: $value\n";
			}
		    }
		}
	    }
	    $s .= $self->{Data}[$pos];
	    $s .= $close_blocks;
	}
	$s;
    } else {
	$s . join "", @{ $self->{Data} };
    }
}

### AutoLoad Sub
sub global_directives_as_string {
    my($self) = @_;
    return "" if (!$self->{GlobalDirectives} || !keys %{$self->{GlobalDirectives}});
    my $s = "";
    while(my($k,$v) = each %{ $self->{GlobalDirectives} }) {
	$s .= join("\n", map { "#: $k: $_" } @$v) . "\n";
    }
    $s .= "#:\n"; # end global directives
    $s;
}

### AutoLoad Sub
sub _write {
    my($self, $filename, %args) = @_;
    if (!defined $filename) {
	$filename = $self->file;
    }
    if (!defined $filename) {
	warn "No filename specified";
	return 0;
    }
    my $mode = delete $args{mode};
    if (open(COPY, "$mode $filename")) {
	my $global_dirs = $self->get_global_directives;
	binmode COPY;
	if ($global_dirs->{encoding}) {
	    binmode COPY, ":encoding(". $global_dirs->{encoding}->[0] . ")";
	}
	print COPY $self->as_string(%args);
	close COPY;
	1;
    } else {
	warn "Can't write/append to $filename: $!" if $VERBOSE;
	0;
    }
}

### AutoLoad Sub
sub write {
    my($self, $filename, %args) = @_;
    $self->_write($filename, mode => ">", %args);
}

### AutoLoad Sub
sub append {
    my($self, $filename, %args) = @_;
    $self->_write($filename, mode => ">>", %args);
}

sub get {
    my($self, $pos) = @_;
    return [undef, [], undef] if $pos < 0;
    my $line = $self->{Data}->[$pos];
    parse($line);
}

sub get_directives {
    my($self, $pos) = @_;
    $pos = $self->{Pos} if !defined $pos;
    return {} if !$self->{Directives};
    $self->{Directives}[$pos] || {};
}

sub set_directives_for_current {
    my($self, $directives) = @_;
    my $pos = $#{ $self->{Data} };
    $self->{Directives}[$pos] = $directives;
}

sub get_directives_for_iterator {
    my($self, $iterator) = @_;
    my $pos = $self->{"Pos_Iterator_$iterator"};
    $self->get_directives($pos);
}

BEGIN {
    # These are misnomers (singular vs. plural), but kept for
    # backward compatibility.
    *get_directive              = \&get_directives;
    *set_directive_for_current  = \&set_directives_for_current;
    *get_directive_for_iterator = \&get_directives_for_iterator;
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

# Like get_all_by_name, but specify street name and citypart
sub get_by_strname_and_citypart {
    my($self, $strname, $citypart) = @_;
    require Strassen::Strasse;
    my @res;
    $self->init;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	my($strname2,@cityparts2) = Strasse::split_street_citypart($ret->[NAME]);
	if ($strname eq $strname2) {
	    if (!defined $citypart || !@cityparts2) {
		push @res, $ret;
	    } else {
		for my $citypart2 (@cityparts2) {
		    if ($citypart eq $citypart2) {
			push @res, $ret;
			last;
		    }
		}
	    }
	}
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
sub set_current {
    my($self, $arg) = @_;
    $self->set($self->{Pos}, $arg);
}

sub set2 {
    my($self, $index, $arg) = @_;
    $self->{Data}[$index] = arr2line2($arg) . "\n";
}
sub set_current2 { # preferred for usage in init/next loops
    my($self, $arg) = @_;
    $self->set2($self->{Pos}, $arg);
}

# Arguments: [name, [xy1, xy2, ...], cat],
# which is the same as the return value of next().
sub push {
    my($self, $arg) = @_;
    my $x = [$arg->[NAME], join(" ", @{$arg->[COORDS]}), $arg->[CAT]];
    push @{$self->{Data}}, arr2line($x);
}

# Push with directives
sub push_ext {
    my($self, $arg, $dir) = @_;
    if ($dir) {
	my $pos = @{$self->{Data}} || 0;
	$self->{Directives}[$pos] = $dir;
    }
    $self->push($arg);
}

sub push_unparsed {
    my($self, $comment) = @_;
    CORE::push(@{$self->{Data}}, $comment);
}

sub delete_current { # funktioniert in init/next-Schleifen
    my($self) = @_;
    return if $self->{Pos} < 0;
    splice @{ $self->{Data} }, $self->{Pos}, 1;
    for my $member (qw(Directives LineInfo)) {
	if ($self->{$member}) {
	    splice @{ $self->{$member} }, $self->{Pos}, 1;
	}
    }
    $self->{Pos}--;
    # XXX invalidate get_hashref_name_to_pos result
    # XXX invalidate all_crossings result
}

# wandelt eine Array-Referenz ["name", $Koordinaten, "cat"] in
# einen String zum Abspeichern um
# Achtung: das Koordinaten-Argument ist hier anders als beim Rückgabewert von
# parse()! Siehe arr2line2().
# Tabs und Newlines werden aus dem Namen entfernt
# Achtung: ein "\n" wird angehängt
### AutoLoad Sub
sub arr2line {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/[\t\n]/ /;
    "$name\t$arg->[CAT] $arg->[COORDS]\n"
}

# wie arr2line, aber ohne Newline
# Tabs und Newlines werden aus dem Namen entfernt
### AutoLoad Sub
sub _arr2line {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/[\t\n]/ /;
    "$name\t$arg->[CAT] $arg->[COORDS]"
}

# Wie _arr2line, aber das COORDS-Argument ist eine Array-Referenz wie
# beim Rückgabewert von parse().
# Tabs und Newlines werden aus dem Namen entfernt.
# Ein Newline fehlt hier und muss manuell angefügt werden, falls der Datensatz
# in $self->{Data} geschrieben werden soll.
### AutoLoad Sub
sub arr2line2 {
    my $arg = shift;
    (my $name = $arg->[NAME]) =~ s/[\t\n]/ /;
    "$name\t$arg->[CAT] " . join(" ", @{ $arg->[COORDS] });
}

# This is a static method
sub parse {
    # $_[0] is $line
    # my $_[0] = shift;
    return [undef, [], undef] if !$_[0];
    my $tab_inx = index($_[0], "\t");
    if ($tab_inx < 0) {
	warn "Probably tab character is missing (line <$_[0]>)\n" if $VERBOSE;
	[$_[0]];
    } else {
	my @s = split /\s+/, substr($_[0], $tab_inx+1);
	my $category = shift @s;
	[substr($_[0], 0, $tab_inx), \@s, $category];
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
    $_[0]->{Pos} = scalar @{$_[0]->{Data}} - 1;
}

# initialisiert für next() und gibt den ersten Wert zurück
### AutoLoad Sub
sub first {
    my $self = shift;
    $self->{Pos} = 0;
    $self->get(0);
}

# Return the next record and increment the iterator
sub next {
    my $self = shift;
    $self->get(++($self->{Pos}));
}

# Return the next record without incrementing the iterator
sub peek {
    my $self = shift;
    $self->get($self->{Pos}+1);
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

# Return next comment or undef, if it's not a comment
sub next_comment {
    my $self = shift;
    return undef if $self->{Pos}+1 > $#{$self->{Data}};
    return undef if $self->{Data}[$self->{Pos}+1] !~ /^#/;
    return $self->{Data}[$self->{Pos}++];
}

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
	} elsif (/(-?\d+(?:\.\d*)?),(-?\d+(?:\.\d*)?)$/) { # float numbers
	    CORE::push(@res, [$1, $2]);
	} else {
	    warn "Unrecognized reference in <@$resref>: <$_>";
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
    } elsif ($s =~ /(-?\d+(?:\.\d*)?),(-?\d+(?:\.\d*)?)$/) { # float numbers
	[$1, $2];
    } else {
	warn "Unrecognized string: $s...";
	[undef, undef]; # XXX
    }
}

*to_koord = \&to_koord_slow;
*to_koord1 = \&to_koord1_slow;
*to_koord_f = \&to_koord_slow;
*to_koord_f1 = \&to_koord1_slow;

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
    my $cachefile;
    if ($use_cache) {
	my $basename = $self->id;
	$cachefile = "all_crossings_${basename}_$rettype";
	if ($all_points) {
	    $cachefile .= "_kurvenp";
	}
	if ($self->{Inaccessible}) {
	    $cachefile .= "_inacc";
	}
    }
    if ($use_cache && $rettype =~ /^hash/) {
	require Strassen::Util;
	my $hashref = Strassen::Util::get_from_cache($cachefile, [$self->dependent_files]);
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
sub strip_bezirk { require Strassen::Strasse; Strasse::strip_bezirk(@_) }

# Für Orte: trennt den Namen vom Zusatz (z.B. ("Frankfurt", "Oder")
### AutoLoad Sub
sub split_ort {
    split /\|/, $_[0], 2;
}

# Arguments (hash-style):
#   UseCache: use cache
#   Exact: use "exact" algorithm
#   GridHeight, GridWidth: grid extents (by default 1000, for WGS84 data 0.01 degrees)
# With -rebuild => 1 the grid will be build again.
# Uses the private Strassen::Core iterator "make_grid".
# Specify another coordinate system with -tomap (like in get_conversion)
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
    my $get_default_grid_width = sub {
	if (!$args{-tomap}) {
	    my $map = $self->get_global_directive('map');
	    if ($map && $map eq 'polar') {
		return 0.01;
	    }
	}
	1000;
    };
    $self->{GridWidth}  = (defined $args{GridWidth}
			   ? $args{GridWidth} : $get_default_grid_width->());
    $self->{GridHeight} = (defined $args{GridHeight}
			   ? $args{GridHeight} : $self->{GridWidth});
    my $conv;
    if ($args{-tomap}) {
	$conv = $self->get_conversion(-tomap => $args{-tomap});
    }
    my $cachefile = "grid" . ($use_exact ? "x" : "") . "_" . $self->id .
	            "_" . $self->{GridWidth}."x".$self->{GridHeight};
    if ($conv) {
	$cachefile .= "_" . $args{-tomap};
    }
    if ($use_cache) {
	require Strassen::Util;
	my $hashref = Strassen::Util::get_from_cache($cachefile, [$self->dependent_files]);
	if (defined $hashref) {
	    warn "Using grid cache for $cachefile\n" if $VERBOSE;
	    $self->{Grid} = $hashref;
	    return;
	}
    }
    $self->{Grid} = {};
    $self->{GridIsExact} = $use_exact;
    $self->{GridUseCache} = $use_cache;
    $self->{GridConv} = $conv;
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
    my $conv = $self->{GridConv};
    my $strpos = 0;
    while(1) {
	my $r = $self->next_for_iterator("make_grid");
	last if !@{$r->[COORDS]};
	foreach my $c (@{$r->[COORDS]}) {
	    $c = $conv->($c) if $conv;
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
    my $conv = $self->{GridConv};
    my $strpos = 0;
    while(1) {
	my $r = $self->next_for_iterator("make_grid");
	last if !@{$r->[COORDS]};
	my @c;
	if ($conv) {
	    @c = map { $conv->($_) } @{ $r->[COORDS] };
	} else {
	    @c = @{ $r->[COORDS] };
	}
	if (@c == 1) {
	    $grid_build{join(",",$self->grid(split(/,/, $c[0])))}->{$strpos}++;
	} else {
	    for my $i (0 .. $#c-1) {
		my($x1, $y1) = split(',', $c[$i]);
		my($x2, $y2) = split(',', $c[$i+1]);
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

# Get the nearest point "$x,$y" at a street for the given point.
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
    require Strassen::Util;
    my $mindist = Strassen::Util::infinity();
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

# See also get_anti_conversion
sub get_conversion {
    my($self, %args) = @_;
    my $convsub;
    my $frommap = $self->{GlobalDirectives}{map} || $args{Map};
    if ($frommap) {
	$frommap = $frommap->[0];
	my $tomap = $args{-tomap} || "standard";
	return if $frommap eq $tomap; # no conversion needed
	require Karte;
	Karte::preload(":all"); # Can't preload specific maps, because $map is a token, not a map module name
	if ($tomap ne "standard") {
	    $convsub = sub {
		join ",", $Karte::map{$frommap}->map2map($Karte::map{$tomap},
							 split /,/, $_[0]);
	    };
	} else {
	    $convsub = sub {
		join ",", $Karte::map{$frommap}->map2standard(split /,/, $_[0]);
	    };
	}
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

sub get_global_directives {
    my $self = shift;
    if (ref $self && UNIVERSAL::isa($self, "Strassen")) {
	$self->{GlobalDirectives};
    } else {
	my $file = shift;
	my $tmp_s = $self->new($file, NoRead => 1);
	$tmp_s->read_data(ReadOnlyGlobalDirectives => 1);
	$tmp_s->{GlobalDirectives};
    }
}

# If existing, get the *first* global directive with the given name,
# otherwise undef
sub get_global_directive {
    my($self, $directive) = @_;
    my $global_dir = $self->get_global_directives;
    if ($global_dir && exists $global_dir->{$directive}) {
	$global_dir->{$directive}[0];
    } else {
	undef;
    }
}

# Note that this sets only the reference; if you want a copy, then
# use Storable::dclone before!
sub set_global_directives {
    my($self, $global_directives) = @_;
    $self->{GlobalDirectives} = $global_directives;
}

sub switch_encoding {
    my($fh, $value) = @_;
    # The encoding directive is executed immediately
    eval q{
	die "No UTF-8 support with this perl version ($])" if $] < 5.008;
	die "UTF-8 bugs with perl 5.8.0" if $] < 5.008001;
	binmode($fh, ":encoding($value)")
    };
    if ($@) {
	if ($value ne 'iso-8859-1') { # this is perl's default, so do not warn
	    warn "Cannot execute encoding <$value> directive: $@";
	}
    }
}

sub DESTROY { }

if (0) { # peacify -w
    $Kreuzungen::VERBOSE = $Kreuzungen::VERBOSE;
    $StrassenNetz::VERBOSE = $StrassenNetz::VERBOSE;
    $StrassenNetz::CNetFile::VERBOSE = $StrassenNetz::CNetFile::VERBOSE;
    $Strassen::Util::VERBOSE = $Strassen::Util::VERBOSE;
    *to_koord = *to_koord;
    *to_koord1 = *to_koord1;
    *to_koord_f = *to_koord_f;
    *to_koord_f1 = *to_koord_f1;
}

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

Also see the comments in the source code.

=head1 SEE ALSO

L<BBBikeRouting>, L<bbd>.
