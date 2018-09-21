# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2002,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package HouseNumbers;

require 5.005; # qr//

use strict;
use vars qw($VERSION);
$VERSION = '1.04';

# Types:
#  NO   (GDF HS=1)    : no house numbers
#  CONT               : continuous, odd and even numbers on both sides
#  ALT                : alternate, odd and even numbers of different sides
#  IRR                : irregular
#  SINGLE (not in GDF): alternate, but no differation between sides
#                       ("left" is always empty)
use constant TYPES => [qw(NO CONT ALT IRR SINGLE)];

# name syntax: type (see enum above)
#              right begin/left begin
#              right end/left end
use constant NAME_RX => qr|^(\S+)\s+([^/]*)/([^/]*)\s+([^/]*)/([^/]*)$|;

1;

__END__
