# -*- perl -*-

#
# $Id: Base.pm,v 1.4 2009/06/27 15:34:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Geography::Base;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub new                  { bless {}, shift }
sub cityname             { undef }
sub center               { undef } # "x,y"
sub center_name          { undef }
sub bbox                 { undef } # array ref
sub search_args          { () }
sub scrollregion         { () }
sub is_osm_source        { undef }
sub coord_to_standard    { ($_[1], $_[2]) }
sub coord_s_to_standard  { $_[1] }
sub _bbox_standard_coordsys { }
sub _center_standard_coordsys { }

1;
