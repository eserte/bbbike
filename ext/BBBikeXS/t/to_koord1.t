#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: to_koord1.t,v 1.4 2003/06/18 20:25:20 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use BBBikeXS;

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

BEGIN { plan tests => 6 }

{
    my $sub1 = \&Strassen::to_koord1;
    my $sub2 = \&Strassen::to_koord1_XS;
    ok("$sub1", "$sub2");
}

my $xy = Strassen::to_koord1("-123,+456");
ok($xy->[0], -123);
ok($xy->[1], 456);

{
    my $warn = "";
    local $SIG{__WARN__} = sub { $warn .= shift };

    $xy = Strassen::to_koord1("blafoo");
    ok($xy->[0], undef);
    ok($xy->[1], undef);
    ok($warn, qr/blafoo is expected to be of the format x,y/);
}

__END__
