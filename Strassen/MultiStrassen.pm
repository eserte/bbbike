# -*- perl -*-

#
# $Id: MultiStrassen.pm,v 1.13 2004/08/26 23:38:02 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::MultiStrassen;

$VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

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

    for (@obj) {
	if (!UNIVERSAL::isa($_, 'Strassen')) {
	    # assume file name
	    $_ = Strassen->new($_);
	}
	push @{ $self->{SubObj} }, $_;
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
    return join "_", map { $_->id } @{ $self->{SubObj} };
#XXX del:
#     my @depfiles = $self->dependent_files;
#     require File::Basename;
#     my $basedir = File::Basename::basename(File::Basename::dirname($depfiles[0]));
#     $basedir = ($basedir eq "data" ? "" : $basedir . "_");
#     $basedir . join("_", sort map { File::Basename::basename($_) } @depfiles);
}

sub dependent_files {
    my $self = shift;
    my @depfiles = map { $_->dependent_files } @{ $self->{SubObj} };
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
    for (@{ $self->{SubObj} }) {
	if (defined $_->{File}) {
	    push @{$self->{File}}, $_->file;
	}
	push @{$self->{FirstIndex}}, $#{$self->{Data}}+1;
	push @{$self->{Data}}, @{$_->{Data}};
    }
}

# XXX Hack: autoloader does not work for inherited methods
for my $method (qw(agrep bbox bboxes pos_from_name choose_street new_with_removed_points)) {
    my $code = 'sub ' . $method . ' { shift->Strassen::' . $method . '(@_) }';
    #warn $code;
    eval $code;
    die "$code: $@" if $@;
}

1;
