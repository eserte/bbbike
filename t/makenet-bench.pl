#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use Benchmark;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen;
use strict;
#use BBBikeXS;
my $s = MultiStrassen->new("strassen", "landstrassen", "landstrassen2");
my $iter = shift || 10;

timethese($iter,
	  {
	   makenet => sub {
	       my $net = StrassenNetz->new($s);
	       $net->make_net_classic(UseCache => 0);
	   },
	  });
__END__
