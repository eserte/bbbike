# -*- perl -*-

#
# $Id: MultiStrassen.pm,v 1.2 2002/09/25 13:05:26 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::MultiStrassen;

package MultiStrassen;
use strict;
#use AutoLoader 'AUTOLOAD';
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

    $self->{Data} = [];
    $self->{File} = [];
    $self->{Pos}  = 0;
    $self->{SourcePos} = {};

    for (@obj) {
	if (!UNIVERSAL::isa($_, 'Strassen')) {
	    # assume file name
	    $_ = Strassen->new($_);
	}
	if (defined $_->{File}) {
	    push @{$self->{File}}, $_->file;
	}
	push @{$self->{FirstIndex}}, $#{$self->{Data}}+1;
	push @{$self->{Data}}, @{$_->{Data}};
	push @{$self->{SubObj}}, $_; # XXX Performance-Hit?
    }
    bless $self, $class;
}

# Ausgabe der Source-Files
sub file { @{shift->{File}} }

sub id {
    my $self = shift;
    if (defined $self->{Id}) {
	return $self->{Id};
    }
    require File::Basename;
    join("_", sort map { File::Basename::basename($_) } $self->file);
}

# XXX Hack: autoloader does not work for inherited methods
for my $method (qw(agrep pos_from_name)) {
    my $code = 'sub ' . $method . ' { shift->Strassen::' . $method . '(@_) }';
    #warn $code;
    eval $code;
    die "$code: $@" if $@;
}

1;
