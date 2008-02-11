#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: bbbikedraw_radzeit.t,v 1.2 2008/02/11 21:11:04 eserte Exp $
# Author: Slaven Rezic
#

push @ARGV, qw(-only PDF -only GD/png -only GD/gif -only MapServer -only BBBikeGoogleMaps);
$0 = "bbbikedraw.t";
do $0;

__END__
