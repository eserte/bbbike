# -*- perl -*-

#
# $Id: MultiBezStr.pm,v 1.1 2002/05/21 23:47:07 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::MultiBezStr;

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

package MultiBezStr;
use strict;
#use AutoLoader 'AUTOLOAD';

# make gzip-aware
sub new {
    my $class = shift;
    require MyFile;
    if (MyFile::openlist(*MULTI,
			 map { "$_/multi_bez_str" } @Strassen::datadirs)) {
	my $self = {};
	while(<MULTI>) {
	    chomp;
	    my($str, $rest) = split(/\t/);
	    my(@bez) = split(/,/, $rest);
	    $self->{$str} = \@bez;
	}
	bless $self, $class;
    } else {
	undef;
    }
}

sub exists {
    my($self, $str) = @_;
    exists $self->{$str};
}

sub bezirke {
    my($self, $str) = @_;
    if ($self->exists($str)) {
	@{$self->{$str}}
    } else {
	();
    }
}

sub hash { %{$_[0]} }

1;
