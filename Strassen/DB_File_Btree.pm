# -*- perl -*-

#
# $Id: DB_File_Btree.pm,v 1.3 2003/01/08 20:14:13 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::DB_File_Btree;

use strict;
use vars qw($VERSION @ISA);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Strassen::Core;
@ISA = qw(Strassen);

use DB_File;
use Fcntl;

sub read_data {
    my($self) = @_;
    my $file = $self->{File};
    tie my %db, 'DB_File', $file, O_RDONLY, 0644, $DB_BTREE
	or die "Can't tie $file: $!";
    $self->{DB} = \%db;
}

sub get_by_name {
    my($self, $name, $rxcmp) = @_;
    if ($rxcmp) {
	die "NYI";
    }
    my $line = $self->{DB}->{$name};
    if (!defined $line) {
	return [undef, [], undef];
    }
    Strassen::parse($line);
}

sub get_all_by_name {
    my($self, $name, $rxcmp) = @_;
    if ($rxcmp) {
	die "NYI";
    }
    my @res;
    my $db = tied %{$self->{DB}};
    for ($db->get_dup($name)) {
	push @res, Strassen::parse($_);
    }
    @res;
}

# static method
sub convert {
    my($s, $file) = @_;
    unlink $file;
    local $DB_BTREE->{'flags'} = R_DUP;
    tie my %db, 'DB_File', $file, O_RDWR|O_CREAT, 0644, $DB_BTREE
	or die "Can't tie $file for writing: $!";
    require Object::Iterate;
    Object::Iterate::iterate
	    (sub {
		 $db{$_->[Strassen::NAME]} = "$_->[Strassen::NAME]\t$_->[Strassen::CAT] " . join(" ", @{ $_->[Strassen::COORDS] });
	     }, $s);
}

1;

__END__
