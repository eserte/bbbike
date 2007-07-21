# -*- perl -*-

#
# $Id: Unknown1.pm,v 1.4 2007/07/20 19:36:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

# XXX trim_accuracy calls are missing

package GPS::Unknown1;
require GPS;
push @ISA, 'GPS';

use strict;

sub magics { ('^TRK') }

sub convert_to_route {
    my($self, $file, %args) = @_;

    my($fh, $lines_ref) = $self->overread_trash($file, %args);
    die "File $file does not match" unless $fh;

    require Karte::Polar;
    my $obj = $Karte::Polar::obj;

    my @res;
    my $check = sub {
	my $line = shift;
	chomp;
	if (m|^TRK\s+(.)(\d+)\s+([\d\.]+)\s+(.)(\d+)\s+([\d\.]+)\s+(\d+)[/-](\d+)[/-](\d+)[- ](\d+):(\d+):(\d+)\s+(\d+)$|) {
	    my($ns, $breite_grad, $breite_min,
	       $ew, $laenge_grad, $laenge_min,
	       $year, $mon, $day, $hour, $min, $sec, $xxx) =  ($1, $2, $3,
							       $4, $5, $6,
							       $7, $8, $9,
							       $10, $11, $12,
							       $13);
	    $breite_grad *= -1 if ($ns eq 'S');
	    $laenge_grad *= -1 if ($ew eq 'W');
	    my($breite, $laenge) = ($breite_grad + $breite_min/60,
				    $laenge_grad + $laenge_min/60);
	    push @res, [$obj->map2standard($laenge, $breite)];
	}
    };

    $check->($_) foreach @$lines_ref;
    while(<$fh>) {
	$check->($_);
    }

    close $fh;

    @res;
}

1;

__END__
