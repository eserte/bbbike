# -*- perl -*-

#
# $Id: Fast.pm,v 1.2 2005/03/28 22:49:05 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

package Strassen::Fast;

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use strict;
#use AutoLoader 'AUTOLOAD';
use vars qw(@ISA);
@ISA = qw(Strassen);

sub new {
    my($class, $filename) = @_;
    require Storable;
    my $self = retrieve $filename;
    bless $self, $class;
}

1;
