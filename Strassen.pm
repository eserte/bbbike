# -*- perl -*-

#
# $Id: Strassen.pm,v 4.23 2002/05/21 23:49:02 eserte Exp $
#
# Copyright (c) 1995-2001 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Author: Slaven Rezic (eserte@cs.tu-berlin.de)
#

use Strassen::Heavy;

1;

__END__

=head1 NAME

Strassen - the interface to bbd data

=head1 SYNOPSIS

   use Strassen;

=head1 DESCRIPTION

This module loads L<Strassen::Heavy>, which in turn loads
L<Strassen::Core>, L<Strassen::StrassenNetz> and many more
Strassen-related modules.
