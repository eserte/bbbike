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
} else {
    eval 'use Test::NoWarnings';
}

my $s = Strassen->new_from_data_string(<<"EOF");
# for turn penalty test
Grossbeerenstr.\tN 9044,9753 9073,9915 9108,10101 9145,10290
Moeckernstr.\tNH 8779,9851 8780,9968 8783,10166 8802,10290
Wartenburgstr.\tN 9073,9915 8780,9968
Obentrautstr.\tN 9277,10057 9108,10101 8783,10166
# for kerb (Bordstein) tests
Singerstr.\tN 11920,12266 12084,12235 12295,12197 12532,12150
Kleine Andreasstr.\tN 12064,12171 12211,12128 12279,12113
Krautstr.\tN 12002,12008 12021,12066 12064,12171 12084,12235 12118,12462
Andreasstr.\tNH 12238,11931 12279,12113 12295,12197 12345,12435
# more kerb tests
Lindenstr.\tH 9770,10590 9795,10512 9858,10350 9873,10285
Alte Jakobstr.\tN 9858,10350 9914,10401 9955,10501 9992,10626
Neuenburger Str.\tN 9795,10512 9848,10526 9853,10543 9955,10501 10178,10411
EOF
my $dh_len = Strassen->new_from_data_string(<<"EOF");
Simulate penalty in left turn from Grossbeerenstr. to Wartenburgstr.\tDH:len=100 9044,9753 9073,9915 8780,9968
EOF
my $dh_time = Strassen->new_from_data_string(<<"EOF");
Simulate penalty in left turn from Grossbeerenstr. to Wartenburgstr.\tDH:t=18 9044,9753 9073,9915 8780,9968
EOF
my $dh_len_time = Strassen->new_from_data_string(<<"EOF");
Simulate penalty in left turn from Grossbeerenstr. to Wartenburgstr.\tDH:t=9:len=50 9044,9753 9073,9915 8780,9968
EOF
my $dh_kerb = Strassen->new_from_data_string(<<"EOF");
Simulate kerb in Kleine Andreasstr.\tDH:kerb_up 12064,12171 12211,12128 12279,12113
Simulate kerb in Kleine Andreasstr.\tDH:kerb_down 12279,12113 12211,12128 12064,12171
Simulate first kerb in Neuenburger Str.\tDH:kerb_up 9770,10590 9795,10512 9848,10526
Simulate second kerb in Neuenburger Str.\tDH:kerb_down 9848,10526 9853,10543 9955,10501
EOF

my $s_net = StrassenNetz->new($s);
$s_net->make_net(UseCache => 0);

# Turn tests
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
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_time, speed => 20);
    # Same search, with directed handicap, time based
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Obentrautstr.', 'with directed handicaps, time based --- expected via Obentrautstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_time, speed => 5);
    # Same search, with directed handicap, time based
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Wartenburgstr.', 'with directed handicaps, time based --- low speed, still expected via Wartenburgstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info,
	[
	 {
	  "lost_time" => 18,
	  "add_len" => undef,
	  "path_begin_i" => 0,
	  "path_end_i" => 2
	 }
	], 'routing through a directed handicap with pen only'
	    or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_len_time, speed => 20);
    # Same search, with directed handicap, combined length+time based
    my($path) = $s_net->search("9044,9753", "8783,10166", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Obentrautstr.', 'with directed handicaps, length+time based --- expected via Obentrautstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

# Kerb (Bordstein) tests
{
    # Search from Singer/Kraut to Andreas/Lange Str.
    my($path) = $s_net->search("12084,12235", "12238,11931");
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Kleine Andreasstr.', 'without kerb optimization --- expected via Kleine Andreasstr.';
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, vehicle => '');
    # Same search, with directed handicap
    my($path) = $s_net->search("12084,12235", "12238,11931", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Andreasstr.', 'with directed handicaps, kerb optimization --- expected via Andreasstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));

    my $directed_handicap_net_2 = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, vehicle => 'normal');
    is_deeply $directed_handicap_net_2, $directed_handicap_net, '"normal" is an alias for ""';
}

{
    # Search from Lindenstr. to Alte Jakobstr.
    my($path) = $s_net->search("9770,10590", "10178,10411");
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Neuenburger Str.', 'without kerb optimization --- expected via Neuenburger Str.';
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, vehicle => '');
    # Same search, with directed handicap
    my($path) = $s_net->search("9770,10590", "10178,10411", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Neuenburger Str.', 'with kerb optimization using normal vehicle, but not "enough" --- expected via Neuenburger Str.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info,
	[
	 {
	  'add_len' => undef,
	  'lost_time' => '4',
	  'path_begin_i' => 0,
	  'path_end_i' => 2
	 },
	 {
	  'add_len' => undef,
	  'lost_time' => '2',
	  'path_begin_i' => 2,
	  'path_end_i' => 4
	 }
	], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, kerb_up_time => 4, kerb_down_time => 2);
    # Same search, with directed handicap
    my($path) = $s_net->search("9770,10590", "10178,10411", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Neuenburger Str.', 'with kerb optimization specified with kerb_time, but not "enough" --- now expected via Neuenburger Str.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info,
	[
	 {
	  'add_len' => undef,
	  'lost_time' => '4',
	  'path_begin_i' => 0,
	  'path_end_i' => 2
	 },
	 {
	  'add_len' => undef,
	  'lost_time' => '2',
	  'path_begin_i' => 2,
	  'path_end_i' => 4
	 }
	], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, vehicle => 'heavybike');
    # Same search, with directed handicap
    my($path) = $s_net->search("9770,10590", "10178,10411", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Alte Jakobstr.', 'with kerb optimization using heavy bike --- now expected via Alte Jakobstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_kerb, speed => 20, kerb_up_time => 60, kerb_down_time => 40);
    # Same search, with directed handicap
    my($path) = $s_net->search("9770,10590", "10178,10411", DirectedHandicap => $directed_handicap_net);
    my @route_info = $s_net->route_info(Route => $path);
    is $route_info[1]->{Street}, 'Alte Jakobstr.', 'with kerb optimization specified with high kerb_time --- now expected via Alte Jakobstr.';
    my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
    is_deeply \@directed_handicap_info, [], 'not routing through directed handicaps'
	or diag(explain(\@directed_handicap_info));
}

__END__
