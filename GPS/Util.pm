# -*- perl -*-

#
# $Id: Util.pm,v 1.3 2003/01/08 20:12:34 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package GPS::Util;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw(Exporter);

@EXPORT = qw(eliminate_umlauts);

sub eliminate_umlauts {
    my $s = shift;
    $s =~ tr/הצüִײÜ/aouAOU/;
    $s =~ s/ß/ss/g;
    $s =~ s/[יט]/e/g;
    $s =~ s/[\200-\377]/_/g;
    $s;
}

1;

__END__
