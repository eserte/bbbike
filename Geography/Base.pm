# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2021 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Geography::Base;

use strict;
use vars qw($VERSION);
$VERSION = '1.05';

sub new                  { bless {}, shift }
sub cityname             { undef }
sub center               { undef } # "x,y"
sub center_name          { undef }
sub center_wgs84 {
    my $class = shift;
    require Karte::Polar;
    $Karte::Polar::obj = $Karte::Polar::obj if 0; # cease -w
    $Karte::Polar::obj->standard2map_s($class->center);
}
sub bbox                 { undef } # array ref
sub search_args          { () }
sub scrollregion         { () }
sub is_osm_source        { undef }
sub coord_to_standard    { ($_[1], $_[2]) }
sub coord_to_standard_s  { $_[1] }
sub standard_to_coord    { ($_[1], $_[2]) }
sub standard_to_coord_s  { $_[1] }
sub _bbox_standard_coordsys { }
sub _center_standard_coordsys { }

1;
