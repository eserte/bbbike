# -*- perl -*-

#
# $Id: Inline.pm,v 1.15 2004/01/17 23:26:10 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2003,2004 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package VectorUtil::Inline;

use vars qw($VERSION @ISA);
use strict;

$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

require DynaLoader;
unshift @ISA, 'DynaLoader';
bootstrap VectorUtil::Inline $VERSION;

# XXX POINT should be a hidden perl/C object...
# return POINT buffer and number of points
sub array_to_POINT {
    my(@a) = @_;
    my $sizeof = sizeof_POINT();
    if ($sizeof != length(pack("ii",0,0))) {
	die "This architecture is not supported (yet)";
    }
    if (@a % 2 != 0) {
	die "Must be even number of points";
    }
    my $points = @a / 2;
    my $buf = "";
    for (@a) {
	$buf .= pack("i", $_);
    }
    ($buf, $points);
}

if (eval { require VectorUtil; 1 }) {
    local($^W) = 0;

    package VectorUtil;

    *vector_in_grid_PP = \&VectorUtil::vector_in_grid;
    *vector_in_grid_XS = \&VectorUtil::Inline::vector_in_grid;
    *vector_in_grid    = \&VectorUtil::Inline::vector_in_grid;

    *distance_point_line_PP = \&VectorUtil::distance_point_line;
    *distance_point_line_XS = \&VectorUtil::Inline::distance_point_line;
    *distance_point_line    = \&VectorUtil::Inline::distance_point_line;
} else {
    warn $@;
}

1;
