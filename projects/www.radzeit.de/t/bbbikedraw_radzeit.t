#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw_radzeit.t,v 1.3 2008/06/23 20:55:33 eserte Exp $
# Author: Slaven Rezic
#

# MapServer/pdf currently fails with
#
#    fatal exception: [1416] PDF_setdashpattern: Value 0 for option 'dasharray' is too small (minimum 1e-06)
#
push @ARGV, qw(-only PDF -only GD/png -only GD/gif -only MapServer -only BBBikeGoogleMaps);
$0 = "bbbikedraw.t";
do $0;

__END__
