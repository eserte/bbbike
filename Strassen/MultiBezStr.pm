# -*- perl -*-

#
# $Id: MultiBezStr.pm,v 1.3 2005/03/28 22:49:18 eserte Exp $
#
# Copyright (c) 1995-2001,2005 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@users.sourceforge.net)
#

package Strassen::MultiBezStr;

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

package MultiBezStr;
use strict;
#use AutoLoader 'AUTOLOAD';

# make gzip-aware
sub new {
    my $class = shift;
    my $base = shift || "multi_bez_str";
    require MyFile;
    if (MyFile::openlist(*MULTI,
			 map { "$_/$base" } @Strassen::datadirs)) {
	my $self = {};
	while(<MULTI>) {
	    chomp;
	    next if /^\#/; # comments
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
