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

use Getopt::Long;

use Strassen::Core;
use Strassen::StrassenNetz;

GetOptions("debug" => \my $debug)
    or die "usage: $0 [--debug]\n";

if ($debug) {
    Strassen::set_verbose(1);
}

my $s = Strassen->new_from_data_string(<<"EOF");
Grossbeerenstr.\tN 9044,9753 9073,9915 9108,10101 9145,10290
Moeckernstr.\tNH 8779,9851 8780,9968 8783,10166 8802,10290
Wartburgstr.\tN 9073,9915 8780,9968
Obentrautstr.\tN 9277,10057 9108,10101 8783,10166
EOF
my $s_net = StrassenNetz->new($s);
$s_net->make_net(UseCache => 0);

{
    # Search from Grossbeerenstr./Yorckstr. to Moeckernstr./Obentrautstr.
    my($path) = $s_net->search("9044,9753", "8783,10166");
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Wartburgstr.', 'without directed handicaps --- expected via Wartburgstr.';
}

{
    my %directed_handicap_net =
	('8780,9968' =>
	 [
	  {p => ["9044,9753", "9073,9915"],
	   pen => 100,
	  },
	 ],
	);

    # Same search, with directed handicap
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => \%directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Obentrautstr.', 'with directed handicaps --- expected via Obentrautstr.';
}


__END__
