# -*- perl -*-

#
# $Id: Stat.pm,v 1.3 2003/01/08 20:14:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Stat;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

package Strassen;
use Strassen::Util;
use Carp;

# Return the area for a list of coordinates (x1,y1,x2,y2,...)
sub area_for_coords {
    my(@coords) = @_;
    croak "Not an even number of coords (@{[ scalar @coords ]})" if @coords % 2 != 0;

    # Polygon schlieﬂen
    if ($coords[$#coords-1] != $coords[0] ||
	$coords[$#coords]   != $coords[1]) {
	CORE::push @coords, @coords[0, 1];
    }

    my @x = (undef);
    my @y = (undef);
    my $i;
    for($i = 0; $i<$#coords; $i+=2) {
	CORE::push @x, $coords[$i];
	CORE::push @y, $coords[$i+1];
    }
    $y[0] = $y[$#y];
    CORE::push @y, $y[1];

    my $area = 0;
    for($i = 1; $i <= $#x; $i++) {
	$area += $x[$i]*($y[$i+1]-$y[$i-1]);
    }
    0.5*abs($area);
}

# Return area for an object returned by Strassen::next
sub area {
    area_for_coords(map { split /,/ } @{ $_[0]->[Strassen::COORDS()] });
}

# Return the total length of a street (or the circumference of an area)
# for a coordinate list (x1,y1,x2,y2,...)
sub total_len_for_coords {
    my @coords = @_;
    my $len = 0;
    for(my $i = 0; $i<$#coords-2; $i+=2) {
	$len += Strassen::Util::strecke([@coords[$i, $i+1]],
					[@coords[$i+2, $i+3]],
				       );
    }
    $len;
}

# Same as total_len_for_coords, but use an object returned by Strassen::next
# as input parameter
sub total_len {
    total_len_for_coords(map { split /,/ } @{ $_[0]->[Strassen::COORDS()] });
}

1;

__END__
