# -*- perl -*-

#
# Copyright (c) 1995-2001,2019,2023 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (srezic@cpan.org)
#

package Strassen::MultiStrassen;

$VERSION = '1.20';

package MultiStrassen;
use strict;
#use AutoLoader 'AUTOLOAD';
require Strassen::Core;
use vars qw(@ISA);
@ISA = qw(Strassen);

# The constructor accepts either a list of Strassen objects or a list
# of filenames (which are used as the argument for Strassen->new())
# and constructs a new MultiStrassen object, which isa-Strassen.
sub new {
    my $class = shift;
    my $opts;
    if (ref $_[0] eq 'HASH' && !UNIVERSAL::isa($_[0], 'Strassen')) {
	$opts = shift;
    } else {
	$opts = {};
    }
    my @obj = @_;

    my $on_globdir_mismatches = delete $opts->{on_globdir_mismatches} || 'silent';
    die "on_globdir_mismatches can be only 'silent' (default), 'warn' or 'die'" if $on_globdir_mismatches !~ /^(silent|warn|die)$/;
    die "Unhandled options: " . join(" ", %$opts) if %$opts;

    if (@obj == 1 && UNIVERSAL::isa($obj[0], 'Strassen')) {
	return $obj[0];
    }

    my $self = {};

    $self->{File} = [];
    $self->{Pos}  = -1;
    $self->{SourcePos} = {};
    $self->{SubObj} = [];
    if (Strassen::_has_tie_ixhash()) {
	tie %{ $self->{GlobalDirectives} }, 'Tie::IxHash';
    } else {
	$self->{GlobalDirectives} = {};
    }

    for (@obj) {
	if (!UNIVERSAL::isa($_, 'Strassen')) {
	    # assume file name
	    $_ = Strassen->new($_);
	}
	push @{ $self->{SubObj} }, $_;
    }

    # common encoding
    for (@{ $self->{SubObj} }) {
	my $global_dirs = $_->get_global_directives;
	if ($global_dirs && $global_dirs->{encoding}) {
	    my $encoding = $global_dirs->{encoding}->[0];
	    if ($encoding ne 'iso-8859-1') {
		# force everything to utf-8
		$self->{GlobalDirectives}{encoding}[0] = 'utf-8';
		last;
	    }
	}
    }

    # common coordsys
    my $first_coordsys;
    for my $subobj (@{ $self->{SubObj} }) {
	if ($subobj->count == 0) {
	    # no data -> no problems, skip
	    next;
	}
	my $global_dirs = $subobj->get_global_directives;
	my $this_coordsys = 'bbbike';
	if ($global_dirs && $global_dirs->{map}) {
	    $this_coordsys = $global_dirs->{map}->[0];
	}
	if (!defined $first_coordsys) {
	    $self->{GlobalDirectives}{map} = [$this_coordsys] if $this_coordsys ne 'bbbike';
	    $first_coordsys = $this_coordsys;
	} elsif ($this_coordsys ne $first_coordsys) {
	    warn "WARN: Mismatching coord systems. First was '$first_coordsys', this one (" . $subobj->id . ") is '$this_coordsys'.\nExpect problems!\n";
	}
    }

    # other global directives
    {
	my %new_global_directives;
	if (Strassen::_has_tie_ixhash()) {
	    tie %new_global_directives, 'Tie::IxHash';
	}
	my %conflicting_warn;
	for my $subobj (@{ $self->{SubObj} }) {
	    my $global_dirs = $subobj->get_global_directives;
	    if ($global_dirs) {
		for my $k (keys %$global_dirs) {
		    next if $k eq 'encoding' || $k eq 'map'; # handled already above
		    if (!$new_global_directives{$k}) {
			$new_global_directives{$k} = $global_dirs->{$k};
		    } else {
			# XXX simple-minded comparison, but don't rely on the presence of Data::Compare or similar
			my $first_value = "@{ $new_global_directives{$k} }";
			my $this_value  = "@{ $global_dirs->{$k} }";
			if ($first_value eq $this_value) {
			    # probably the same
			} elsif ($on_globdir_mismatches ne 'silent' && !$conflicting_warn{$k}) {
			    my $msg = "Global directive $k with differing values ('$first_value' vs '$this_value')";
			    if ($on_globdir_mismatches eq 'die') {
				die "ERROR: $msg.\n";
			    } else {
				warn "WARN: $msg, use the first one.\n";
				$conflicting_warn{$k} = 1;
			    }
			}
		    }
		}
	    }
	}
	for my $k (keys %new_global_directives) {
	    $self->{GlobalDirectives}->{$k} = $new_global_directives{$k};
	}
    }

    bless $self, $class;
    $self->read_data;
    $self;
}

# Ausgabe der Source-Files
sub file { @{shift->{File}} }

sub id {
    my $self = shift;
    if (defined $self->{Id}) {
	return $self->{Id};
    }
    return join "_", map { $_->id } grep { defined $_->id } @{ $self->{SubObj} };
}

sub dependent_files {
    my $self = shift;
    my @depfiles = map { $_->dependent_files } @{ $self->{SubObj} };
    if ($self->{DependentFiles}) {
	push @depfiles, @{ $self->{DependentFiles} };
    }
    @depfiles;
}

sub is_current {
    my $self = shift;
    for my $subobj (@{ $self->{SubObj} }) {
	return 0 if !$subobj->is_current;
    }
    1;
}

sub reload {
    my $self = shift;
    for my $subobj (@{ $self->{SubObj} }) {
	$subobj->reload;
    }
    $self->read_data;
}

sub reset_data {
    my $self = shift;
    $self->{Data} = [];
    $self->{FirstIndex} = [];
    $self->{File} = [];
}

sub read_data {
    my $self = shift;
    $self->reset_data;
    my $last_directives_index = -1;
    for my $subobj (@{ $self->{SubObj} }) {
	if (defined $subobj->{File}) {
	    push @{$self->{File}}, $subobj->file;
	}
	push @{$self->{FirstIndex}}, $#{$self->{Data}}+1;
	push @{$self->{Data}}, @{$subobj->{Data}};
	if (exists $subobj->{Directives} && @{ $subobj->{Directives} }) {
	    $#{$self->{Directives}} = $self->{FirstIndex}[-1]-1;
	    push @{$self->{Directives}}, @{ $subobj->{Directives} };
	}
    }
}

# Just a quick check if the dependent files of all sub objects are the
# same, and the sub objects have the same modtime recorded. Return 1
# if the structures are considered the same.
sub shallow_compare {
    my($self, $other_self) = @_;

    my @subobjs       = @{ $self->{SubObj} };
    my @other_subobjs = @{ $other_self->{SubObj} };
    return 0 if scalar(@subobjs) != scalar(@other_subobjs);

    for my $i (0 .. $#subobjs) {
	return 0 if !$subobjs[$i]->shallow_compare($other_subobjs[$i]);
    }

    return 1;    
}

# XXX Hack: autoloader does not work for inherited methods
for my $method (qw(agrep bbox bboxes pos_from_name choose_street new_with_removed_points sort_records_by_cat make_coord_to_pos grepstreets)) {
    my $code = 'sub ' . $method . ' { shift->Strassen::' . $method . '(@_) }';
    #warn $code;
    eval $code;
    die "$code: $@" if $@;
}

1;
