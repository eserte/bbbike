# -*- perl -*-

#
# $Id: MultiStrassen.pm,v 1.18 2008/07/24 20:58:37 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::MultiStrassen;

$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

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
    my($class, @obj) = @_;

    if (@obj == 1 && UNIVERSAL::isa($obj[0], 'Strassen')) {
	return $obj[0];
    }

    my $self = {};

    $self->{File} = [];
    $self->{Pos}  = 0;
    $self->{SourcePos} = {};
    $self->{SubObj} = [];
    $self->{GlobalDirectives} = {};

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
	    warn "WARN: Mismatching coord systems. First was '$first_coordsys', this one is '$this_coordsys'.\nExpect problems!";
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

# XXX Hack: autoloader does not work for inherited methods
for my $method (qw(agrep bbox bboxes pos_from_name choose_street new_with_removed_points sort_records_by_cat make_coord_to_pos)) {
    my $code = 'sub ' . $method . ' { shift->Strassen::' . $method . '(@_) }';
    #warn $code;
    eval $code;
    die "$code: $@" if $@;
}

1;
