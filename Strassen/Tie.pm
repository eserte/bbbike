# -*- perl -*-

#
# $Id: Tie.pm,v 1.3 2003/01/08 20:15:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# schöneres Interface, aber leider nur halb so schnell wie
# ->init while ->next ...
package Strassen::Tie;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use Strassen::Core;

sub TIEARRAY {
    my($class, $str_obj) = @_;
    bless \$str_obj, $class;
}

sub FETCH {
    $ {$_[0]}->get($_[1]);
}

sub STORE {
    die "STORE not allowed";
}

sub FETCHSIZE {
    scalar @{ $ {$_[0]}->{Data} };
}

sub STORESIZE {
    die "STORESIZE not allowed";
}

package Strassen;

use overload
    '@{}' => sub { [ map { $_[0]->get($_) } (0 .. $#{ $_[0]->{Data} }) ] };

1;

__END__
