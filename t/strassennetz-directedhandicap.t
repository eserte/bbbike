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
Wartenburgstr.\tN 9073,9915 8780,9968
Obentrautstr.\tN 9277,10057 9108,10101 8783,10166
EOF
my $dh_len = Strassen->new_from_data_string(<<"EOF");
Simulate penalty in left turn from Grossbeerenstr. to Wartenburgstr.\tDH:len=100 9044,9753 9073,9915 8780,9968
EOF
my $dh_time = Strassen->new_from_data_string(<<"EOF");
Simulate penalty in left turn from Grossbeerenstr. to Wartenburgstr.\tDH:t=18 9044,9753 9073,9915 8780,9968
EOF

my $s_net = StrassenNetz->new($s);
$s_net->make_net(UseCache => 0);

{
    # Search from Grossbeerenstr./Yorckstr. to Moeckernstr./Obentrautstr.
    my($path) = $s_net->search("9044,9753", "8783,10166");
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Wartenburgstr.', 'without directed handicaps --- expected via Wartenburgstr.';
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_len, speed => 20);
    # Same search, with directed handicap, length based
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Obentrautstr.', 'with directed handicaps, length based --- expected via Obentrautstr.';
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_time, speed => 20);
    # Same search, with directed handicap, time based
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Obentrautstr.', 'with directed handicaps, time based --- expected via Obentrautstr.';
}


__END__
