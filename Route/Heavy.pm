# -*- perl -*-

#
# $Id: Heavy.pm,v 1.2 2003/01/08 20:13:23 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Route::Heavy;

package Route;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

# XXX Msg.pm

sub as_strassen {
    my $in_file = shift;

    open(IN, $in_file) or die "Can't open file $in_file: $!";
    my $first_line = scalar <IN>;
    if ($first_line !~ /^\#BBBike\s+route/) {
	die "$in_file ist keine bbr-Datei, erste Zeile ist <$first_line>";
    }
    close IN;

    require Strassen;
    require Safe;
    my $compartment = new Safe;
    use vars qw($realcoords_ref $coords_ref);
    $compartment->share(qw($realcoords_ref $coords_ref
			   $search_route_points_ref
			   ));
    $compartment->rdo($in_file);

    die "Die Datei <$in_file> enthält keine Route."
	if (!defined $realcoords_ref);

    if (defined $coords_ref) {
	warn "Achtung: <$in_file> enthält altes Routen-Format.\n".
	    "Koordinaten können verschoben sein!\n";
    }

    my $s = Strassen->new_from_data("Route\t#ff0000 " . join(" ", map { $_->[0].",".$_->[1] } @$realcoords_ref));
    $s;
}

1;

__END__
