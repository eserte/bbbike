#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

use GPS::GpsmanData::Any;

my($lon0, $lat0, $lon1, $lat1) = (shift, shift, shift, shift);
my $file = shift
    or die "usage: $0 minlon minlat maxlon maxlat file";
($lon0, $lon1) = ($lon1, $lon0) if $lon1 < $lon0;
($lat0, $lat1) = ($lat1, $lat0) if $lat1 < $lat0;

my $g = GPS::GpsmanData::Any->load($file);
for my $c (@{ $g->Chunks }) {
    for my $wpt (@{ $c->Points }) {
	my($lon,$lat) = ($wpt->Longitude, $wpt->Latitude);
	if ($lon0 <= $lon && $lon <= $lon1 &&
	    $lat0 <= $lat && $lat <= $lat1) {
	    exit 0;
	}
    }
}
exit 1;

__END__

=head1 NAME

is_in_bbox.pl - is track part of the bounding box

=head1 SYNOPSIS

     is_in_bbox.pl minlon minlat maxlon maxlat file
     echo $?

=head1 DESCRIPTION

Exit code is 0, if any point in the file is within the given bounding
box. Otherwise exit code is not zero.

File may be any format accepted by L<GPS::GpsmanData::Any>, at least
gpsman tracks and waypoint files and gpx files.

=head1 BUGS

Uses a simple-minded algorithm: only exact point matches are checked,
not lines between points.

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<GPS::GpsmanData::Any>.

=cut
