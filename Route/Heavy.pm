# -*- perl -*-

#
# $Id: Heavy.pm,v 1.3 2005/01/15 22:39:30 eserte Exp $
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

use Route;

package Route;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

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

# XXX make more sophisticated
sub get_sample_coords {
    my($coordref, $max_samples) = @_;
    my @res;
    if (@$coordref < $max_samples) {
	@res = @$coordref;
    } else {
	my $delta = @$coordref/$max_samples;
	for(my $i=0; $i<@$coordref;$i+=$delta) {
	    push @res, $coordref->[$i];
	}
    }
    @res;
}

sub load_from_string {
    my($string, @args) = @_;
    require File::Temp;
    my($fh, $file) = File::Temp::tempfile(UNLINK => !$Route::DEBUG);
    print $fh $string;
    close $fh;
    my $ret = Route::load($file, @args);
    unlink $file if !$Route::DEBUG;
    $ret;    
}

1;

__END__
