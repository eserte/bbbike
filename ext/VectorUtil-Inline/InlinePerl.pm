# -*- perl -*-

#
# $Id: InlinePerl.pm,v 1.1 2003/08/30 21:43:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package VectorUtil::InlinePerl;

package VectorUtil::Inline;

use strict;

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
    warn "IGNORE while building: $@\n";
}

1;

__END__
