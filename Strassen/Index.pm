#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Index;

use strict;
use vars qw($DB_File);
$DB_File = "DB_File::Lock" if !defined $DB_File;

require Strassen;
if ($DB_File eq 'DB_File') {
    require DB_File;
} else {
    require DB_File::Lock;
}
require Fcntl;

sub new {
    my($class, $strassen_file, %opts) = @_;
    my $index_file = $strassen_file . ".inx";
    $index_file .= ($DB_File::db_version eq '' || $DB_File::db_version <= 1 ? '' : int($DB_File::db_version));
    my $self = bless {strassen_file => $strassen_file,
		      index_file    => $index_file,
		      verbose       => (delete $opts{verbose} || 0),
		     }, $class;
    $self;
}

sub DESTROY {
    my($self) = @_;
    $self->close_index;
}

sub needs_update {
    my($self) = @_;
    my $index_file = $self->{index_file};
    my $strassen_file = $self->{strassen_file};
    return !-e $index_file || -M $strassen_file < -M $index_file;
}

sub open_updated_index {
    my($self) = @_;
    if ($self->needs_update) {
	$self->create_index;
    } else {
	$self->open_index;
    }
}

sub open_index {
    my($self) = @_;
    my $index_file = $self->{index_file};

    tie my %db, $DB_File, $index_file, Fcntl::O_RDWR(),
	0644, $DB_File::DB_HASH, ($DB_File =~ /Lock/ ? "write" : ())
	    or die "Can't open $index_file: $!";

    $self->{db} = \%db;
}

sub close_index {
    my($self) = @_;
    if ($self->{db}) {
	(tied %{ $self->{db} })->sync;
	untie %{ $self->{db} };
	delete $self->{db};
    }
}

sub create_index {
    my($self) = @_;
    my $s = $self->{strassen_obj};
    if (!$s) {
	$s = Strassen->new($self->{strassen_file});
	$self->{strassen_obj} = $s;
    }
    my $index_file = $self->{index_file};

    rename $index_file, "$index_file~";
    tie my %db, $DB_File, $index_file, Fcntl::O_RDWR()|Fcntl::O_CREAT(),
	0644, $DB_File::DB_HASH, ($DB_File =~ /Lock/ ? "write" : ())
	    or die "Can't create $index_file: $!";

    if ($self->{verbose}) {
	print STDERR "Creating <$index_file>... ";
    }
    $s->init;
    while(1) {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS()] };
	last if !@c;
	for my $c (@c) {
	    $db{$c}++;
	}
    }

    unlink "$index_file~";

    if ($self->{verbose}) {
	print STDERR "done\n";
    }

    $self->{db} = \%db;
}

sub point_exists {
    my($self, $c) = @_;
    exists $self->{db}->{$c};
}

sub add_point {
    my($self, $c) = @_;
    $self->{db}->{$c}++;
}

1;

__END__
