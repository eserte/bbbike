#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-index.pl,v 1.5 2006/06/03 08:01:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Will probably be sometime Strassen::Index or so

use strict;

if (!caller) {
    require FindBin;
    push @INC, ("$FindBin::RealBin/..",
		"$FindBin::RealBin/../lib",
	       );
}

package Strassen::Index;
require Strassen;
require DB_File;
require Fcntl;

sub new {
    my($class, $strassen_file, %opts) = @_;
    my $index_file = $strassen_file . ".inx";
    $index_file .= ($DB_File::db_version eq '' || $DB_File::db_version <= 1 ? '' : int($DB_File::db_version));
    my $self = bless {strassen_file => $strassen_file,
		      index_file    => $index_file,
		      verbose       => (delete $opts{verbose} || 0),
		     }, $class;
    if ((!exists $opts{uptodatecheck} || $opts{uptodatecheck})
	&& (!-e $index_file || -M $strassen_file < -M $index_file)) {
	my $s = Strassen->new($strassen_file);
	$self->{strassen_obj} = $s;
	$self->create_index;
    } else {
	$self->open_index;
    }
    $self;
}

sub open_index {
    my($self) = @_;
    my $index_file = $self->{index_file};

    tie my %db, 'DB_File', $index_file, Fcntl::O_RDWR(),
	0644, $DB_File::DB_HASH
	    or die "Can't open $index_file: $!";

    $self->{db} = \%db;
}

sub create_index {
    my($self) = @_;
    my $s = $self->{strassen_obj};
    my $index_file = $self->{index_file};

    rename $index_file, "$index_file~";
    tie my %db, 'DB_File', $index_file, Fcntl::O_RDWR()|Fcntl::O_CREAT(),
	0644, $DB_File::DB_HASH
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
