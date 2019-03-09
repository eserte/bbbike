#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

sub is_between ($$$;$);

plan tests => 12;

use Strassen::Util;

is(Strassen::Util::strecke([0,0],[1000,0]), 1000, 'strecke');
is(Strassen::Util::strecke([0,0],[0,1000]), 1000);
is(Strassen::Util::strecke_s('0,0','1000,0'), 1000, 'strecke_s');
is(Strassen::Util::strecke_s('0,0','0,1000'), 1000);

is Strassen::Util::get_direction("8000,8000", "8000,9000"), 'n';
is Strassen::Util::get_direction("8000,8000", "8000,7000"), 's';
is Strassen::Util::get_direction("8000,8000", "7000,8000"), 'w';
is Strassen::Util::get_direction("8000,8000", "9000,8000"), 'e';

is Strassen::Util::get_direction("8000,8000", "9000,9000"), 'ne';
is Strassen::Util::get_direction("8000,8000", "7000,7000"), 'sw';
is Strassen::Util::get_direction("8000,8000", "7000,9000"), 'nw';
is Strassen::Util::get_direction("8000,8000", "9000,7000"), 'se';

__END__
