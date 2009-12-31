#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: to_koord1.t,v 1.8 2008/01/17 23:07:30 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use BBBikeXS;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 11 }

{
    my $sub1 = \&Strassen::to_koord1;
    my $sub2 = \&Strassen::to_koord1_XS;
    is($sub1, $sub2, "to_koord1, used and XS is the same");
}

{
    my $sub1 = \&Strassen::to_koord_f1;
    my $sub2 = \&Strassen::to_koord_f1_XS;
    is($sub1, $sub2, "to_koord_f1, used and XS is the same");
}

my $xy = Strassen::to_koord1("-123,+456");
is($xy->[0], -123, "to_koord1 x");
is($xy->[1], 456, "to_koord1 y");

{
    my $warn = "";
    local $SIG{__WARN__} = sub { $warn .= shift };

    $xy = Strassen::to_koord1("blafoo");
    is($xy->[0], undef, "Undefined");
    is($xy->[1], undef);
    like($warn, qr/blafoo is expected to be of the format x,y/,
	 "Got warning");
}

{
    my $xy = Strassen::to_koord_f1("13.1234,52.5432");
    is($xy->[0], 13.1234, "to_koord_f1 x (float value)");
    is($xy->[1], 52.5432, "to_koord_f1 y (float value)");
}

{
    my $xy = Strassen::to_koord_f1("8598,9074");
    is($xy->[0], 8598, "to_koord_f1 x (int value)");
    is($xy->[1], 9074, "to_koord_f1 y (int value)");
}

__END__
