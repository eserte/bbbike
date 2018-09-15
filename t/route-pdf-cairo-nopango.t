#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;

if (eval { require Cairo; 1 }) {
    exec $^X, "$FindBin::RealBin/route-pdf.t", "-class", "Route::PDF::Cairo", "-nopango", @ARGV;
    die $!;
} else {
    require Test::More;
    Test::More::plan(skip_all => 'No Cairo available');
}

__END__
