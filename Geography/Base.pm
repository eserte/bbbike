# -*- perl -*-

#
# $Id: Base.pm,v 1.1 2009/02/25 23:44:49 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub new                  { bless {}, shift }
sub cityname             { undef }
sub center               { undef } # "x,y"
sub bbox                 { undef } # array ref
sub search_args          { () }
sub scrollregion         { () }

1;
