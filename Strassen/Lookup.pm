# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Lookup;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Hash::Util qw(lock_keys);

use Strassen::Core ();

sub new {
    my($class, $file) = @_;
    my $self = {
		File => $file,
		Fh => undef,
		GlobalDirectives => undef,
		Offset => undef,
		CurrentSearchString => undef,
	       };
    bless $self, $class;
    lock_keys %$self;
    $self->_scan;
    $self;
}

sub _scan {
    my($self) = @_;
    my $file = $self->{File};
    my $s = Strassen->new($file, NoRead => 1);
    my $offset;
    $s->read_data(ReadOnlyGlobalDirectives => 1, ReturnSeekPosition => \$offset);
    $self->{Offset} = $offset;
    $self->{GlobalDirectives} = $s->get_global_directives;
}

sub look {
    my($self, $search_string) = @_;
    require Tie::Handle::Offset;
    require Search::Dict;
    require Symbol;
    my $fh = Symbol::gensym();
    my $layer_string = $self->{GlobalDirectives}->{encoding} ? ":encoding($self->{GlobalDirectives}->{encoding}->[0])" : '';
    tie *$fh, 'Tie::Handle::Offset', "<$layer_string", $self->{File}, { offset => $self->{Offset} }
	or die "Can't tie: $!";
    $self->{CurrentSearchString} = $search_string;
    $self->{Fh} = $fh;
    Search::Dict::look($fh, $search_string);
}

sub get_next {
    my($self) = @_;
    my $fh = $self->{Fh};
    chomp(my $line = <$fh>);
    my $rec = Strassen::parse($line);
    $rec;
}

sub search_first {
    my($self, $search_string) = @_;
    if ($self->look($search_string) != -1) {
	$self->search_next;
    } else {
	undef;
    }
}

sub search_next {
    my($self) = @_;
    my $rec = $self->get_next;
    if (index($rec->[Strassen::NAME], $self->{CurrentSearchString}) == 0) {
	$rec;
    } else {
	undef;
    }
}

sub convert_for_lookup {
    my($self, $dest) = @_;
    my @data;
    my $s = Strassen->new($self->{File}, UseLocalDirectives => 0);
    @{ $s->{Data} } = sort @{ $s->{Data} };
    $s->write($dest);
}

1;

__END__
