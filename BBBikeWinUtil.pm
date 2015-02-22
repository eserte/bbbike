# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeWinUtil;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

# Add ...\c\bin directory for Strawberry Perl on Windows.
# This directory contains shared libraries e.g. libxml2.
# Also the ...\perl\bin may be missing.
sub adjust_path {
    if ($^X =~ m{(.*)(\\perl\\bin)\\}) {
	my $c_bin_dir = "$1\\c\\bin";
	my $perl_bin_dir = "$1$2";
	if (-d $c_bin_dir) {
	    # XXX should probably check if this directory is already in PATH
	    $ENV{PATH} .= ";$c_bin_dir";
	}
	if (-d $perl_bin_dir) {
	    # XXX dito
	    $ENV{PATH} .= ";$perl_bin_dir";
	}
    }
}

1;

__END__
