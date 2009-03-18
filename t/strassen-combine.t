#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-combine.t,v 1.2 2009/03/18 23:18:47 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 2;

use Strassen::Core;
use Strassen::Combine;

use BBBikeTest 'eq_or_diff';

my $data = <<'EOF';
Unter den Linden	X 10,10 20,20
Kudamm	X 30,30 40,40
Alex	X 60,60 70,70
Kudamm	X 40,40 50,50
Alex	X 80,80 70,70
Möckernstr.	X 8824,10366 8878,10514 8922,10618
Möckernstr.	X 8922,10618 8878,10514 8824,10366
S1	SA 7421,8719 7534,8895
S1	SA 7912,9436 7985,9576
S1	SA 7534,8895 7912,9436
S1	SA 7985,9576 8046,9705
EOF

my $combined_data = <<'EOF';
Unter den Linden	X 10,10 20,20
Kudamm	X 30,30 40,40 50,50
Alex	X 60,60 70,70 80,80
Möckernstr.	X 8824,10366 8878,10514 8922,10618 8878,10514 8824,10366
S1	SA 7421,8719 7534,8895 7912,9436 7985,9576 8046,9705
EOF

my $s = Strassen->new_from_data_string($data);
my $new_s = $s->make_long_streets;
isa_ok($new_s, 'Strassen');

{
    local $TODO = "Last point is missing!!!";
    eq_or_diff($new_s->as_string, $combined_data);
}

__END__
