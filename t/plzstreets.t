#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Test::More 'no_plan';

use PLZ;
use Strassen::Core;

my $s = Strassen->new_from_data_string(<<EOF);
Dudenstr.	H 9229,8785 9076,8783 8982,8781 8866,8780 8763,8780 8594,8777 8472,8776 8425,8775 8389,8775 8298,8774 8209,8773
Chausseestr. (Mitte, Wedding, Gesundbrunnen)	H 9212,13471 9207,13493 9094,13641 9042,13707 8935,13844 8879,13913 8831,13973 8732,14098 8654,14194 8607,14253 8527,14352 8442,14456 8406,14507 8346,14576 8286,14635 8246,14675 8232,14689 8153,14769
Chausseestr. (Wannsee)	H -7180,378 -7122,439 -7089,472 -7059,578 -7002,667 -6955,742 -6950,752 -6922,791 -6864,878 -6805,1075
EOF

my $plzdata = PLZ->new_data_from_streets($s);
is $plzdata, <<EOF;
Dudenstr.|||8594,8777
Chausseestr.|Gesundbrunnen||8654,14194
Chausseestr.|Mitte||8654,14194
Chausseestr.|Wedding||8654,14194
Chausseestr.|Wannsee||-7002,667
EOF

__END__
