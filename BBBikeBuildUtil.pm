# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeBuildUtil;

use strict;
use vars qw($VERSION @EXPORT_OK);
$VERSION = '0.01';

use Exporter 'import';
@EXPORT_OK = qw(get_pmake);

use BBBikeUtil qw(is_in_path);

sub get_pmake () {
    (
     $^O =~ m{bsd}i               ? "make"         # standard BSD make
     : is_in_path("fmake")        ? "fmake"        # debian jessie and later
     : is_in_path("freebsd-make") ? "freebsd-make" # debian wheezy and earlier
     : "pmake"                                     # self-compiled BSD make, maybe
    );
}

1;

__END__
