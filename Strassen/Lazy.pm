# -*- perl -*-

#
# $Id: Lazy.pm,v 1.3 2003/01/08 20:14:50 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Lazy;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Object::Realize::Later
    becomes => 'Strassen',
    realize => 'load',
    warn_realization => $Strassen::VERBOSE,
    ;

sub new {
    my $class = shift;
    bless {args=>[@_]}, $class;
}

sub load {
    my $self = shift;
    Strassen->new(@{ $self->{args} });
}

1;

__END__
