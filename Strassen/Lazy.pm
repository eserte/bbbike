# -*- perl -*-

#
# $Id: Lazy.pm,v 1.7 2003/11/15 16:07:04 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

require Object::Realize::Later;
Object::Realize::Later->VERSION(0.14);

package Strassen::Lazy;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use Object::Realize::Later
    becomes => 'Strassen',
    realize => 'load',
    warn_realization => $Strassen::VERBOSE,
    ;

sub new {
    my $class = shift;
    bless {args => [@_],
	   strassen_datadirs => [@Strassen::datadirs],
	  }, $class;
}

sub load {
    my $self = shift;
    local @Strassen::datadirs = @{ $self->{strassen_datadirs} },
    my $s = Strassen->new(@{ $self->{args} });
    bless $self, ref $s;
    %$self = %$s;
    $self;
}

package MultiStrassen::Lazy;

use Object::Realize::Later
    becomes => 'MultiStrassen',
    source_module => 'Strassen::MultiStrassen',
    realize => 'load',
    warn_realization => $Strassen::VERBOSE,
    ;

sub new {
    my $class = shift;
    bless {args => [@_],
	   strassen_datadirs => [@Strassen::datadirs],
	  }, $class;
}

sub load {
    my $self = shift;
    local @Strassen::datadirs = @{ $self->{strassen_datadirs} },
    my $s = MultiStrassen->new(@{ $self->{args} });
    bless $self, ref $s;
    %$self = %$s;
    $self;
}

1;

__END__
