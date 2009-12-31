# -*- perl -*-

#
# $Id: CoreHeavy.pm,v 1.44 2009/02/15 20:49:18 eserte Exp $
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

# XXX make gzip-aware
# XXX does not work for MultiStrassen
# %arg:
# NoDot: keine Ausgabe von "...", wenn zu viele Matches existieren
# NoStringApprox: do not use String::Approx, even if available
# ErrorDef: Angabe der Reihenfolge (match begin, match errors)
# Agrep: maximale Anzahl von erlaubten Fehlern
# Return value: Array with matched street names
### AutoLoad Sub
sub agrep {
    my($self, $pattern, %arg) = @_;

    my @paths;
    my @files;
    my $file = $self->{File};
    if (ref $file eq 'ARRAY') {
	@files = @$file;
    } else {
	CORE::push(@files, $file);
    }

    my $file_encoding = $self->get_global_directive("encoding");

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
	# agrep does not cope with utf-8, so convert to octets
	if (defined $file_encoding) {
	    eval {
		require Encode;
		$pattern = Encode::encode($file_encoding, $pattern);
	    };
	    warn $@ if $@;
	}
	$pattern =~ s/(.)/\\$1/g;
    } else {
	foreach my $path (@paths) {
	    open(F, $path) or die "Can't open $path: $!";
	    if (defined $file_encoding) {
		switch_encoding(\*F, $file_encoding);
	    }
	    my @file_data;
	    chomp(@file_data = <F>);
	    CORE::push(@data, @file_data);
	    close F;
	}
	return () if !@data;
	eval { local $SIG{'__DIE__'};
	       die if $arg{NoStringApprox};
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
	    if (defined $file_encoding) {
		switch_encoding(\*AGREP, $file_encoding);
	    }
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
	@this_res = grep { !/^#/ } @this_res;
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
    if ($self->write($dest, IgnoreDirectives => 1)) {
	$self->{OrigFile} = $dest;
	1;
    } else {
	delete $self->{OrigFile};
	0;
    }
}

sub get_diff_orig_dir {
    # ignore $self
    my $origdir = "$Strassen::Util::tmpdir/bbbike-orig";
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
    my $dest = "$origdir/" . join("_", map { defined $_ ? File::Basename::basename($_) : "???" } @file);
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

    my $use_diff_tool;
    # XXX check order not yet clear
    if (eval { require Text::Diff; 1 }) {
	$use_diff_tool = "Text::Diff";
    } elsif (is_in_path("diff")) {
	$use_diff_tool = "diff";
    }

    if (!$use_diff_tool) {
	warn "diff not found in path or Text::Diff not available" if $VERBOSE;
	return;
    }

    my $dest = "$origdir/" . File::Basename::basename($first_file) . ".new";
    return unless $self->write($dest, IgnoreDirectives => 1);

    my $old_line = 1;
    my $new_line = 1;
    my(@del, @add, %index_mapping);

    if ($use_diff_tool eq 'diff') {
	my $diff_cmd = "diff -u $self->{OrigFile} $dest |";
	#warn $diff_cmd;
	open(DIFF, $diff_cmd) or die $!;
    } else {
	my $diff = Text::Diff::diff($self->{OrigFile}, $dest, {STYLE => "Unified"});
	eval 'open(DIFF, "<", \$diff) or die $!;';
	if ($@) {
	    warn "Need fallback ($@)";
	    my $diff_fallback_file = "/tmp/bbbike_diff_fallback_" . $< . ".diff";
	    open(DIFFOUT, "> $diff_fallback_file")
		or die $!;
	    binmode DIFFOUT;
	    print DIFFOUT $diff;
	    close DIFFOUT
		or die $!;

	    open(DIFF, $diff_fallback_file);
	}
    }
    scalar <DIFF>; scalar <DIFF>; # overread header
    while(<DIFF>) {
	chomp;
	if (/^\@\@\s*-(\d+).*\+(\d+)/) {
	    $old_line = $1;
	    $new_line = $2;
	} elsif (/^\+(.*)/) {
	    CORE::push(@add, "$1\n");
	    $index_mapping{$#add} = $new_line-1;
	    $new_line++;
	} elsif (/^-/) {
	    CORE::push(@del, $old_line-1); # warum -1?
	    $old_line++;
	} elsif (!/^[ \\]/) {
	    warn "Unknown diff line: $_";
	} else {
	    $old_line++;
	    $new_line++;
	}
    }
    close DIFF;

    unlink $dest;
    my $new_s = new_from_data Strassen @add;
    if ($args{-clonefile}) {
	$new_s->{File} = $self->{File};
    }
    ($new_s, \@del, \%index_mapping);
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

    my $data = $self->{Data};
    my $directives = $self->{Directives} || [];
    my @data_and_directives;
    for my $i (0 .. $#$data) {
	CORE::push @data_and_directives, [$data->[$i], $directives->[$i]];
    }

    @data_and_directives =
	map  { $_->[1] }
	sort {
	    if (exists $ignore{$a->[2][CAT]} || exists $ignore{$b->[2][CAT]}) {
		0;
	    } else {
		$a->[0] <=> $b->[0];
	    }
	}
	map  { my $l = parse($_->[0]);
	       [exists $catval{$l->[CAT]} ? $catval{$l->[CAT]} : 9999,
		$_,
		$l
	       ]
	} @data_and_directives;

    $self->{Data} = [];
    $self->{Directives} = [];
    for my $i (0 .. $#data_and_directives) {
	CORE::push @{ $self->{Data} }, $data_and_directives[$i]->[0];
	CORE::push @{ $self->{Directives} }, $data_and_directives[$i]->[1];
    }
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
	    'F:Mine'	   => 13,

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
    # XXX Hmmm, what's right, what's wrong? Returning 1 helps in
    # temp_blockings objects, where one subobj is a file-based
    # Strassen object.
    return 1 if !defined $self->{Modtime};
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
	warn "Reload " . $self->file . "...\n"
	    if $VERBOSE;
	$self->read_data;
    }
    if ($self->{Grid}) {
	warn "Rebuild grid ...\n"
	    if $VERBOSE;
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

# Simplify the object using the Douglas-Peucker algorithm.
# Adapted from http://mapserver.gis.umn.edu/community/scripts/thin.pl
# Note: this changes the self object
sub simplify {
    my($s, $tolerance) = @_;

    $s->init;
    while() {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;
	next if $r->[Strassen::NAME] =~ m{^\#}; # skip comments (really needed???)
	next if @c == 1;

	my @new_c;
	douglas_peucker(\@c, \@new_c, $tolerance);

	$r->[Strassen::COORDS] = \@new_c;
	$s->set_current2($r);
    }
}

sub _distance_point_to_segment {
    # from: mapsearch.c, msDistancePointToSegment
    my($p, $a, $b) = @_;

    require BBBikeUtil;
    require Strassen::Util;

    $p = [ Strassen::Util::string_to_coord($p) ];
    $a = [ Strassen::Util::string_to_coord($a) ];
    $b = [ Strassen::Util::string_to_coord($b) ];

    my $l = Strassen::Util::strecke($a, $b);
    if ($l == 0.0) { # a = b
	return Strassen::Util::strecke($a, $p);
    }

    my $r = (($a->[1] - $p->[1])*($a->[1] - $b->[1]) -
	     ($a->[0] - $p->[0])*($b->[0] - $a->[0]))/($l*$l);
    if ($r > 1) { # perpendicular projection of P is on the forward extention of AB
	return BBBikeUtil::min(Strassen::Util::strecke($p, $b),
			       Strassen::Util::strecke($p, $a));
    }
    if ($r < 0) { # perpendicular projection of P is on the backward extention of AB
	return BBBikeUtil::min(Strassen::Util::strecke($p, $b),
			       Strassen::Util::strecke($p, $a));
    }
    
    my $s = (($a->[1] - $p->[1])*($b->[0] - $a->[0]) - ($a->[0] - $p->[0])*($b->[1] - $a->[1]))/($l*$l);
	
    return abs($s*$l);
}

sub douglas_peucker {
    my($c, $new_c, $tolerance) = @_;

    my @stack = ();
    my $anchor = $c->[0]; # save first point
    CORE::push @$new_c, $anchor;
    my $aIndex = 0;
    my $fIndex = $#$c;
    CORE::push @stack, $fIndex;

    # Douglas - Peucker algorithm
    while (@stack) {
	$fIndex = $stack[$#stack];
	my $fPoint = $c->[$fIndex];
	my $max = $tolerance; # comparison values
	my $maxIndex = 0;

	# process middle points
	for (($aIndex+1) .. ($fIndex-1)) {

	    my $point = $c->[$_];
	    # XXX wrong! should be distanceToSegment!!!
	    my $dist = _distance_point_to_segment($point, $anchor, $fPoint);

	    if ($dist >= $max) {
		$max = $dist;
		$maxIndex = $_;
	    }
	}

	if ($maxIndex > 0) {
	    CORE::push @stack, $maxIndex;
	} else {
	    CORE::push @$new_c, $fPoint;
	    $anchor = $c->[pop @stack];
	    $aIndex = $fIndex;
	}
    }
}

1;

__END__
