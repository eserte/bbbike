# -*- perl -*-

#
# $Id: CoreHeavy.pm,v 1.26 2005/08/14 18:06:11 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::CoreHeavy;

package Strassen;
use strict;

# Gibt die Positionsnummern aller Straßen aus $str_ref als Liste aus.
# $str_ref ist eine Liste von [Straßenname, Bezirk]-Elementen
# Falls eine Straße durch mehrere Bezirke führt, wird nur _eine_ Position
# zurückgegeben.
### AutoLoad Sub
sub union {
    my($self, $str_ref, %args) = @_;

    my $uniq = !$args{Nouniq};

    my %str;
    foreach (@$str_ref) {
	$str{$_->[0]}->{$_->[1]}++;
    }

    my %res;
    $self->init;
    my $last;
    while(1) {
	my $ret = $self->next;
	last if !@{$ret->[COORDS]};
	my $name = $ret->[NAME];
	if ($uniq) {
	    if (defined $last && $last eq $name) {
		next;
	    } else {
		$last = $name;
	    }
	}
	my @bez;
	if ($name =~ /^(.*)\s+\((.*)\)$/) {
	    $name = $1;
	    @bez = split(/,\s*/, $2);
	}
	if (exists $str{$name}) {
	    if (@bez) {
		foreach my $bez (@bez) {
		    if (exists $str{$name}->{$bez}) {
			$res{$self->pos}++;
			last;
		    }
		}
	    } else {
		$res{$self->pos}++;
	    }
	}
    }
    keys %res;
}

# Create a new Strassen object from $self and remove points specified
# in Strassen object $to_remove.
sub new_with_removed_points {
    my($self, $to_remove, %args) = @_;
    my $new_s = Strassen->new;
    require Strassen::Kreuzungen;
    my $kr = Kreuzungen->new_from_strassen(Strassen => $to_remove);
    my $h = $kr->{Hash};
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[COORDS] };
	my @newcoords = ([]);
	for my $p (@{ $r->[COORDS] }) {
	    if (!exists $h->{$p}) {
		CORE::push @{$newcoords[-1]}, $p;
	    } else {
		CORE::push @newcoords, [] if @{$newcoords[-1]} != 0;
	    }
	}
	pop @newcoords if @{$newcoords[-1]} == 0;
	for my $new_c (@newcoords) {
	    $new_s->push([$r->[NAME], $new_c, $r->[CAT]]);
	}
    }
    #$new_s->{Id} = $self->id . "_removed_" . $to_remove->id;
    $new_s->{DependentFiles} = [$self->dependent_files,
				$to_remove->dependent_files];
    $new_s;
}

### AutoLoad Sub
sub agrep {
    my($self, $pattern, %arg) = @_;
    agrep_file($pattern, $self->{File}, %arg);
}

# XXX make gzip-aware
# XXX does not work for MultiStrassen
# %arg:
# NoDot: keine Ausgabe von "...", wenn zu viele Matches existieren
# ErrorDef: Angabe der Reihenfolge (match begin, match errors)
# Agrep: maximale Anzahl von erlaubten Fehlern
# Return value: Array with matched street names
### AutoLoad Sub
sub agrep_file {
    my($pattern, $file, %arg) = @_;

    my @paths;
    my @files;
    if (ref $file eq 'ARRAY') {
	@files = @$file;
    } else {
	CORE::push(@files, $file);
    }

    foreach my $file (@files) {
	my $path;
	if (-r $file) {
	    $path = $file;
	} else {
	    foreach (@datadirs) {
		if (-r "$_/$file") {
		    $path = "$_/$file";
		    last;
		}
	    }
	}
	if (!defined $path) {
	    warn "File $file not found in @datadirs.\n";
	    return undef;
	}
	CORE::push(@paths, $path);
    }

    my $grep_type;
    my @data;
    if (!$OLD_AGREP && is_in_path('agrep')) {
	$grep_type = 'agrep';
	$pattern =~ s/(.)/\\$1/g;
    } else {
	foreach my $path (@paths) {
	    open(F, $path) or die "Can't open $path: $!";
	    my @file_data;
	    chomp(@file_data = <F>);
	    CORE::push(@data, @file_data);
	    close F;
	}
	eval { local $SIG{'__DIE__'};
	       require String::Approx;
	       String::Approx->VERSION(2.7);
	   };
	if (!$@) {
	    $grep_type = 'approx';
	} else {
	    $grep_type = 'perl';
	}
    }
    my @def;
    if ($arg{ErrorDef}) {
	@def = @{$arg{ErrorDef}};
    } else {
	@def = ([1, 0],
		[1, 1],
		[1, 2],
		[0, 0],
		[0, 1],
		[0, 2],
		[0, 3],
	       );
    }
    for my $def (@def) {
	my($begin, $err, @extra) = @$def;
	next if (exists $arg{Agrep} && $err > $arg{Agrep});
	my @this_res;
	my $grep_pattern = $pattern;
	if (grep($_ eq 'strasse', @extra)) {
            next if ($grep_pattern !~ s/(s)traße$/$1tr./i);
	}
	if ($grep_type eq 'agrep') {
	    my @args = '-i';
	    $grep_pattern = ($begin ? "^$grep_pattern" : $grep_pattern);
	    if ($err > 0) { CORE::push(@args, "-$err") }
	    open(AGREP, "-|") or
	      exec 'agrep', @args, $grep_pattern, @paths or
		die "Can't exec program: $!";
	    chomp(@this_res = <AGREP>);
	    close AGREP;
	} elsif ($grep_type eq 'approx' && $err) {
	    next if $begin || $err > 2; # Bug bei $err == 3
	    $grep_pattern =~ s/[()]/./g; # String::Approx-Bug?
	    @this_res = String::Approx::amatch
	      ($grep_pattern, ['i', $err], @data);
	} else { # weder agrep noch String::Approx
	    $grep_pattern = ($begin ? "^$grep_pattern" : $grep_pattern);
	    if ($err == 0) {
		@this_res = grep(/\Q$grep_pattern\E/i, @data);
	    } elsif ($err == 1) { # metacharacter erlauben
		@this_res = grep(/$grep_pattern/i, @data);
	    } else {
		next;
	    }
	}
	if (@this_res == 1) {
	    return parse($this_res[0])->[NAME];
	} elsif (@this_res) {
	    my(@res1, @res2, @res3);
	    my $i = 0;
	    my $last_name;
	    foreach (@this_res) {
		$i++;
		my $name = parse($_)->[NAME];
		if (defined $last_name && $last_name eq $name) {
		    next;
		} else {
		    $last_name = $name;
		}
		if ($name eq $pattern) {
		    return $name;
		} elsif ($name =~ /^\Q$pattern\E/i) {
		    CORE::push(@res1, $name);
		} elsif ($i < 20) {
		    CORE::push(@res2, $name);
		} elsif ($i == 20) {
		    CORE::push(@res3, "...") unless $arg{NoDot};
		}
	    }
	    @res1 = sort @res1;
	    @res2 = sort @res2;
	    return @res1, @res2, @res3;
	}
    }
    ();
}

# Sucht Straße anhand des Bezirkes.
# $bezirk may be in the form "citypart1, citypart2, ..."
### AutoLoad Sub
sub choose_street {
    my($str, $strasse, $bezirk, %args) = @_;
    my @bezirk = split /\s*,\s*/, $bezirk;
    my @pos;
    $str->init;
    while(1) {
	my $ret = $str->next;
	last if !@{$ret->[COORDS]};
	my $check_strasse = $ret->[NAME];
	if (substr($check_strasse, 0, length($strasse)) eq $strasse) {
#	if ($check_strasse =~ /^$strasse/) {
	    my %bez;
	    if ($check_strasse =~ /(.*)\s+\((.*)\)/) {
		$check_strasse = $1;
		foreach (split(/\s*,\s*/, $2)) {
		    $bez{$_}++;
		}
		for my $bezirk (@bezirk) {
		    if (exists $bez{$bezirk}) {
			if (wantarray) {
			    CORE::push(@pos, $str->pos);
			} else {
			    return $str->pos;
			}
			last;
		    }
		}
	    } elsif ($check_strasse eq $strasse) {
		if (wantarray) {
		    CORE::push(@pos, $str->pos);
		} else {
		    return $str->pos;
		}
	    }
	}
    }
    if (wantarray) {
	@pos;
    } else {
	undef;
    }
}

sub copy_orig {
    my $self = shift;
    require Strassen::Util;
    if (! -d $Strassen::Util::tmpdir) {
	warn "$Strassen::Util::tmpdir does not exist" if $VERBOSE;
	return;
    }
    my $origdir = $self->get_diff_orig_dir;
    return if !$origdir;

    my @file = $self->file;
    if (!@file) {
	warn "File not defined" if $VERBOSE;
	return;
    }
    foreach (@file) {
	if (!-f $_) {
	    warn "<$_> does not exist" if $VERBOSE;
	    return;
	}
    }
    my $dest = $self->get_diff_file_name;
    if ($self->write($dest)) {
	$self->{OrigFile} = $dest;
	1;
    } else {
	delete $self->{OrigFile};
	0;
    }
}

sub get_diff_orig_dir {
    # ignore $self
    my $origdir = "$Strassen::Util::tmpdir/orig";
    if (! -d $origdir) {
	mkdir $origdir, 0700;
	if (! -d $origdir) {
	    warn "Can't create $origdir: $!" if $VERBOSE;
	    return;
	}
    }
    $origdir;
}

sub get_diff_file_name {
    my($self) = @_;
    my @file = $self->file;
    my $origdir = get_diff_orig_dir;
    require File::Basename;
    my $dest = "$origdir/" . join("_", map { File::Basename::basename($_) } @file);
    $dest;
}

# Erzeugt die Differenz aus dem aktuellen Strassen-Objekt und der
# letzten Version, die (evtl.) in $origdir abgelegt ist.
# Rückgabe: (Strassen-Objekt mit neuen Straßen, zu löschenden Indices)
# Argumente: -clonefile => 1: das File-Argument wird in das neue Objekt
#            kopiert
### AutoLoad Sub
sub diff_orig {
    my($self, %args) = @_;
    require File::Basename;
    require Strassen::Util;
    my $origdir = $self->get_diff_orig_dir;
    my $first_file = $self->get_diff_file_name;
    if (!defined $self->{OrigFile}) {
	$self->{OrigFile} =
	  "$origdir/" . File::Basename::basename($first_file);
    }
    if (! -f $self->{OrigFile}) {
	warn "<$self->{OrigFile}> does not exist" if $VERBOSE;
	delete $self->{OrigFile};
	return;
    }
    if (!is_in_path("diff")) {
	warn "diff not found in path" if $VERBOSE;
	return;
    }

    my $dest = "$origdir/" . File::Basename::basename($first_file) . ".new";
    return unless $self->write($dest);

    my $curr_line = 1;
    my(@del, @add);
    open(DIFF, "diff -u $self->{OrigFile} $dest |");
    scalar <DIFF>; scalar <DIFF>; # overread header
    while(<DIFF>) {
	chomp;
	if (/^\@\@\s*-(\d+)/) {
	    $curr_line = $1;
	} elsif (/^\+(.*)/) {
	    CORE::push(@add, "$1\n");
	} elsif (/^-/) {
	    CORE::push(@del, $curr_line-1); # warum -1?
	    $curr_line++;
	} elsif (!/^[ \\]/) {
	    warn "Unknown diff line: $_";
	} else {
	    $curr_line++;
	}
    }
    close DIFF;

    unlink $dest;
    my $new_s = new_from_data Strassen @add;
    if ($args{-clonefile}) {
	$new_s->{File} = $self->{File};
    }
    ($new_s, \@del);
}

# Create array reference from Data property:
# [[$name, $category, ["$x1,$y1", "$x2,$y2" ...]],
#  [$name2, ...]
# ]
# Warning: this method resets any init/next loop!
### AutoLoad Sub
sub as_array {
    my $self = shift;
    my $ret = [];
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{$r->[COORDS]};
	my $new_item = [$r->[NAME], $r->[CAT], $r->[COORDS]];
	CORE::push(@$ret, $new_item);
    }
    $ret;
}

# Create a reverse hash pointing from a point to a list of streets
# containing this point:
# { "$x1,$y1" => [$streetname1, $streetname2 ...], ... }
# Warning: this method resets any init/next loop!
### AutoLoad Sub
sub as_reverse_hash {
    my $self = shift;
    my $rev_hash = {};
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{$r->[COORDS]};
	foreach my $c (@{$r->[COORDS]}) {
	    if (exists $rev_hash->{$c}) {
		CORE::push(@{ $rev_hash->{$c} }, $r->[NAME]);
	    } else {
		$rev_hash->{$c} = [$r->[NAME]];
	    }
	}
    }
    $rev_hash;
}

# Given a Strassen file and a position, return the linenumber (starting
# at 1). This function will skip all comment lines.
### AutoLoad Sub
sub get_linenumber {
    my($strfile, $pos) = @_;
    my $orig_pos = $pos;
    my $linenumber = 0;
    open(STR, $strfile) or die "Can't open $strfile: $!";
    while(<STR>) {
	$linenumber++;
	next if /^( \# | \s*$ )/x;
	if ($pos == 0) {
            close STR;
	    return $linenumber;
	}
	$pos--;
    }
    close STR;
    warn "Can't find position $orig_pos in file $strfile";
    undef;
}

# Resets iterator
### AutoLoad Sub
sub filter_region {
    my($s, $type, $x1,$y1, $x2,$y2) = @_;
    my $new_s = Strassen->new;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[COORDS] };
	my $ret;
	if ($type eq 'enclosed') {
	    # XXX works only for one point
	    my($x,$y) = split /,/, $r->[COORDS][0];
	    $ret = ($x1 <= $x && $x2 >= $x &&
		    $y1 <= $y && $y2 >= $y);
	} else {
	    die "XXX type $type NYI";
	}
	if ($ret) {
	    $new_s->push($r);
	}
    }
    $new_s;
}

# Resets iterator
# Arguments: -date (optional, default is today)
#            -negpos (optional, default is 0=negative, matches are deleted)
### AutoLoad Sub
sub filter_date {
    my($s, %args) = @_;

    my $date = $args{-date};
    if (!defined $date) {
	my @l = localtime;
	$date = sprintf "%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3];
    }

    my $neg_pos = $args{-negpos} || 0;

    my $new_s = Strassen->new;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[COORDS] };
	my $hit;
	if ($r->[NAME] =~ /(\d{4}-\d{2}-\d{2})\s*(?:-|bis)\s*(\d{4}-\d{2}-\d{2})/
	    && ($date lt $1 || $date gt $2)) {
	    if ($neg_pos == 0) {
		next;
	    } else {
		$hit = 1;
	    }
	} elsif ($r->[NAME] =~ /(?:-|bis)\s*(\d{4}-\d{2}-\d{2})/
		 && $date le $1) {
	    if ($neg_pos == 0) {
		next;
	    } else {
		$hit = 1;
	    }
	} elsif ($r->[NAME] =~ /(\d{4}-\d{2}-\d{2})\s*(?:-|bis)/
		 && $date ge $1) {
	    if ($neg_pos == 0) {
		next;
	    } else {
		$hit = 1;
	    }
	}
	if ($neg_pos == 0 || $hit) {
	    $new_s->push($r);
	}
    }
    $new_s;
}

# XXX german/multilingual labels?
# use as: $mw->getOpenFile(-filetypes => [Strassen->filetypes])
sub filetypes {
    (['bbd Files' => '.bbd'],
     ['Compressed bbd Files' => '.bbd.gz'],
     ['All Files' => '*']);
}

# Create a hash reference "x1,y1_x2,y2" => [position,...] in data array.
# Optional $restrict should hold a callback returning 0 if the record
# should be ignored, 1 for normal processing and 2 for using both
# directions.
# Warning: this method resets any init/next loop!
sub make_coord_to_pos {
    my($s, $restrict) = @_;
    my $hash = {};
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{$r->[COORDS]};
	my $restrict = $restrict->($r);
	next if !$restrict;
	for my $i (1 .. $#{$r->[COORDS]}) {
	    CORE::push @{$hash->{$r->[COORDS]->[$i-1]."_".$r->[COORDS]->[$i]}}, $s->{Pos};
	    if ($restrict == 2) {
		CORE::push @{$hash->{$r->[COORDS]->[$i]."_".$r->[COORDS]->[$i-1]}}, $s->{Pos};
	    }
	}
    }
    $hash;
}

# Read/write bounding box file
# Ack: resets the iterator if writing!
### AutoLoad Sub
sub bboxes {
    my($self) = @_;

    return $self->{BBoxes} if $self->{BBoxes};

    my @bboxes;
    $self->init;
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };

	my @p;
	foreach (@{ $r->[Strassen::COORDS] }) {
	    CORE::push(@p, split /,/, $_);
	}

	my(@bbox) = ($p[0], $p[1], $p[0], $p[1]);
	for(my $i=2; $i<$#p-1; $i+=2) {
	    $bbox[0] = $p[$i] if ($p[$i] < $bbox[0]);
	    $bbox[2] = $p[$i] if ($p[$i] > $bbox[2]);
	    $bbox[1] = $p[$i+1] if ($p[$i+1] < $bbox[1]);
	    $bbox[3] = $p[$i+1] if ($p[$i+1] > $bbox[3]);
	}

	CORE::push @bboxes, \@bbox;
    }

    $self->{BBoxes} = \@bboxes;
    \@bboxes;
}

# Return the bounding box of the file
# Ack: resets the iterator
sub bbox {
    my($self) = @_;
    $self->init;
    my($x1,$y1,$x2,$y2);
    while(1) {
	my $r = $self->next;
	last if !@{ $r->[Strassen::COORDS] };
	for (@{ $r->[Strassen::COORDS] }) {
	    my($x,$y) = split /,/;
	    $x1 = $x if !defined $x1 || $x1 > $x;
	    $x2 = $x if !defined $x2 || $x2 < $x;
	    $y1 = $y if !defined $y1 || $y1 > $y;
	    $y2 = $y if !defined $y2 || $y2 < $y;
	}
    }
    ($x1,$y1,$x2,$y2);
}

# $catref is either a hash reference of category => level mapping or a
# an array reference of categories. Lower categories should be first.
sub sort_by_cat {
    my($self, $catref, %args) = @_;
    $catref = $self->default_cat_stack_mapping if !$catref;
    my %catval;
    if (ref $catref eq 'HASH') {
	%catval = %$catref;
    } else {
	my $i = 0;
	$catval{$_} = $i++ foreach (@$catref);
    }
    my %ignore;
    %ignore = map { ($_,1) } @{ $args{-ignore} } if $args{-ignore};
    @{ $self->{Data} } =
	map  { $_->[1] }
	sort {
	    if (exists $ignore{$a->[2][CAT]} || exists $ignore{$b->[2][CAT]}) {
		0;
	    } else {
		$a->[0] <=> $b->[0];
	    }
	}
	map  { my $l = parse($_);
	       [exists $catval{$l->[CAT]} ? $catval{$l->[CAT]} : 9999,
		$_,
		$l
	       ]
	} @{ $self->{Data} };
}

sub sort_records_by_cat {
    my($self, $records, $catref, %args) = @_;
    $catref = $self->default_cat_stack_mapping if !$catref;
    return map  { $_->[1] }
	   sort { $a->[0] <=> $b->[0] }
	   map  { [(exists $catref->{$_->[CAT]} ? $catref->{$_->[CAT]} : 9999),
		   $_
		  ]
	      } @$records;
}

sub default_cat_stack_mapping {
    return {'F:W'          => 3, # Gewässer
	    'F:W1'         => 3, # Gewässer
	    'W'            => 3,
	    'W1'           => 3,
	    'W2'           => 3,
	    'F:I'          => 6, # Insel
	    'F:P'          => 15, # Parks

	    # XXX This should be changed to real categories
	    'F:#c08080'    => 10, # bebaute Flächen
	    'F:violet'     => 20, # Industrie (alt)
	    'F:Industrial' => 20, # Industrie
	    'F:DarkViolet' => 21, # Hafen oder Industrie
	    'F:#46b47b'    => 13, # Wald (alt)
	    'F:Woods'      => 13, # Wald
	    'F:Orchard'    => 13,
	    'F:Sport'      => 13,
	    'F:Green'      => 13,

	    'BAB'	   => 21,
	    'B'            => 20,
	    'HH'           => 15,
	    'H'            => 10,
	    'N'            => 5,
	    'NN'           => 1,
	    'Pl'	    => 0,

	    # Orte
	    6		   => 6,
	    5		   => 5,
	    4		   => 4,
	    3		   => 3,
	    2		   => 2,
	    1		   => 1,
	    0 		   => 0,
	   };
}


sub is_current {
    my($self) = @_;
    my @dependent_files;
    if ($self->dependent_files) {
	@dependent_files = $self->dependent_files;
    } elsif (defined $self->file) {
	@dependent_files = $self->file;
    }
    return 1 if !@dependent_files;
    return 0 if !defined $self->{Modtime};
    for my $f (@dependent_files) {
	my $now_modtime = (stat($f))[STAT_MODTIME];
	return 0 if $self->{Modtime} < $now_modtime;
    }
    return 1;
}

sub reload {
    my($self) = @_;
    return if $self->is_current;
    if ($self->{RebuildCode}) {
	$self->{RebuildCode}->();
    } else {
	warn "Reload " . $self->file . "...\n";
	$self->read_data;
    }
    if ($self->{Grid}) {
	warn "Rebuild grid ...\n";
	$self->make_grid(-rebuild => 1);
    }
}

# See also get_conversion
sub get_anti_conversion {
    my($self, %args) = @_;
    my $convsub;
    my $tomap = $self->{GlobalDirectives}{map} || $args{Map};
    if ($tomap) {
	require Karte;
	Karte::preload(":all"); # Can't preload specific maps, because $map is a token, not a map module name
	my $frommap = $args{-frommap} || "standard";
	return if $tomap eq $frommap; # no conversion needed
	if ($frommap ne "standard") {
	    $convsub = sub {
		join ",", $Karte::map{$frommap}->map2map($Karte::map{$tomap},
							 split /,/, $_[0]);
	    };
	} else {
	    $convsub = sub {
		join ",", $Karte::map{$tomap}->standard2map(split /,/, $_[0]);
	    };
	}
    }
    $convsub;
}

# Filter by a subroutine.
# Return a new Strassen object.
# This method uses the "grepstreets" iterator (use this for
# get_directive_for_iterator)
# Arguments:
#  -idadd => $string      add this string to the id of the created object
#  -preservedir => $bool  preserve directives
sub grepstreets {
    my($s, $sub, %args) = @_;
    my $new_s = Strassen->new;
    $new_s->{DependentFiles} = [ $s->dependent_files ];
    if ($args{-idadd}) {
	my $id = $new_s->id;
	$new_s->{Id} = $id . "_" . $args{-idadd};
    }
    my $preserve_dir = $args{-preservedir} || 0;
    $s->init_for_iterator("grepstreets");
    while(1) {
	my $r = $s->next_for_iterator("grepstreets");
	last if !@{$r->[Strassen::COORDS]};
	local $_ = $r;
	next if !&$sub;
	if ($preserve_dir) {
	    $new_s->push_ext($r, $s->get_directive_for_iterator("grepstreets"));
	} else {
	    $new_s->push($r);
	}
    }
    $new_s;
}

1;

__END__
