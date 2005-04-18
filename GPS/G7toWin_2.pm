# -*- perl -*-

#
# $Id: G7toWin_2.pm,v 1.2 2005/04/18 07:10:57 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net/
#

package GPS::G7toWin_2;
use GPS::G7toWin_ASCII;
push @ISA, 'GPS::G7toWin_ASCII';

sub magics { '^Version 2:G7T' }

1;
