# -*- perl -*-

#
# $Id: ETRS89.pm,v 1.3 2003/04/17 18:14:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Karte::ETRS89;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw(Exporter);
@EXPORT_OK = qw(UTMToETRS89 ETRS89ToUTM ETRS89ToDegrees);

sub UTMToETRS89 {
    my($ze, $zn, $x, $y, $datum) = @_;
    if (defined $datum && $datum ne "WGS 84") {
	die "Datum $datum not supported";
    }
    if ($zn le "M") {
	die "South hemisphere not supported (zn is $zn)";
    }
    if ($ze != 33) {
	if ($ze < 30 || $ze > 39) {
	    die "Zone $ze probably not supported";
	} elsif ($ze != 33) {
	    warn "Using ze=$ze\n";
	}
    }
    (($ze-30).$x, $y);
}

sub ETRS89ToUTM {
    my($x, $y) = @_;
    (my $ze, $x) = $x =~ /^(.)(.*)$/;
    $ze += 30;
    # XXX compute $zn!!!
    ($ze, "U", $x, $y);
}

# XXX
sub ETRS89ToDegrees {
    my($zone, $x, $y, $datum) = @_;
    # convert from German Krueger grid coords to lat/long in signed degrees

    if ($x < 0 || $y < 0 || $x > 6e6 || $y > 1e7 #||$zone !~ /$GRIDZN{GKK}/
       ) {
	return 0;
    }

    require Karte::UTM;

    my $long0 = 3.0*$zone;
#    $x = $x-5e5-1e6*$zone;
    $x = $x-1e6*$zone;
#    Karte::UTM::ConvFromTM($x, $y, 0, $long0, 1.0, $datum);
    Karte::UTM::ConvFromTM($x, $y, 0, $long0, $Karte::UTM::UTMk0, $datum);
}

1;

__END__
