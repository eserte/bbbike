#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: leak.t,v 1.1 2003/11/16 10:34:54 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use blib "$FindBin::RealBin/..";
use BBBikeXS;

BEGIN {
    if (!eval q{
	use Test::More;
	use Devel::Leak;
	1;
    }) {
	print "1..0 # skip no Test::More and/or Devel::Leak modules\n";
	exit;
    }
}

BEGIN { plan tests => 2 }

{
    my $count1 = Devel::Leak::NoteSV(my $handle);
    Strassen::Util::strecke_s("1,1","100,100");
    my $count2 = Devel::Leak::CheckSV($handle);
    is($count1, $count2);
}

{
    my $count1 = Devel::Leak::NoteSV(my $handle);
    Strassen::Util::strecke([1,1],[100,100]);
    my $count2 = Devel::Leak::CheckSV($handle);
    is($count1, $count2);
}

__END__
