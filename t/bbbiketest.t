#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;
use Test::More 'no_plan';

use BBBikeTest qw(is_number isnt_number);

is_number(0, "integer test (zero)");
is_number(1, "integer test (non-zero)");
is_number(1.2, "float test");
isnt_number("1.2", "string test");
isnt_number(undef, "undef test");
isnt_number([], "array test");
isnt_number({}, "hash test");

__END__
