# -*- perl -*-

#
# $Id: Lazy.pm,v 1.5 2003/07/24 22:10:13 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

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

## Does not work yet, because becomes is both the realized class and the
## required package XXX
package MultiStrassen::Lazy;

use Object::Realize::Later
    becomes => 'MultiStrassen',
    included_in => 'Strassen::MultiStrassen',
    realize => 'load',
    warn_realization => $Strassen::VERBOSE,
    ;

sub new {
    my $class = shift;
    bless {args=>[@_]}, $class;
}

sub load {
    my $self = shift;
    MultiStrassen->new(@{ $self->{args} });
}

1;

__END__
