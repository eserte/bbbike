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
# for h=qX,len tests
Alexanderstr.\tHH 11252,12644 11329,12497 11340,12443 11355,12331
Schillingstr.\tN 11340,12443 11353,12436 11462,12384
# for tl tests
Karl-Marx-Allee\tHH 12360,12505 12596,12472 12612,12470 12869,12425
Koppenstr.\tN 12573,12227 12596,12472 12632,12630
Puschkinallee\tHH 14495,9609 14318,9688 14271,9712 14196,9749 13999,9842
Puschkinallee - Elsenstr.\tHH 14271,9712 14250,9756 14244,9812
Elsenstr.\tHH 14289,9870 14244,9812 14196,9749 14089,9610
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
my $dh_h_qX = Strassen->new_from_data_string(<<"EOF");
Linker Gehweg Alexanderstr.\tDH:h=q3,55 11329,12497 11340,12443 11353,12436
EOF
my $dh_tl = Strassen->new_from_data_string(<<"EOF");
Puschkinallee: Ampel\tDH:tl 14318,9688 14271,9712 14196,9749
Koppenstr./Karl-Marx-Allee: Fußgängerampel\tDH:tl=20 12573,12227 12596,12472 12632,12630
Koppenstr./Karl-Marx-Allee: Fußgängerampel\tDH:tl=20 12632,12630 12596,12472 12573,12227
Koppenstr./Karl-Marx-Allee: Fußgängerampel\tDH:tl=20 12573,12227 12596,12472 12360,12505
Koppenstr./Karl-Marx-Allee: Fußgängerampel\tDH:tl=20 12360,12505 12596,12472 12632,12630
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
	  "lost_time_tl" => undef,
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
	  'lost_time' => 4,
	  'lost_time_tl' => undef,
	  'path_begin_i' => 0,
	  'path_end_i' => 2
	 },
	 {
	  'add_len' => undef,
	  'lost_time' => 2,
	  'lost_time_tl' => undef,
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
	  'lost_time' => 4,
	  'lost_time_tl' => undef,
	  'path_begin_i' => 0,
	  'path_end_i' => 2
	 },
	 {
	  'add_len' => undef,
	  'lost_time' => 2,
	  'lost_time_tl' => undef,
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

# h=qX,len tests
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_h_qX, speed => 20, vehicle => '');
    like "@warnings", qr{\QDH:h=qX category encountered, but no handicap_penalty provided (warn only once) at }, 'expected warning';
}

{
    my $directed_handicap_net;
    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	$directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_h_qX, speed => 18, vehicle => '', handicap_penalty => { q0=>1, q1=>1.2, q2=>1.5, q3=>2 });
	is "@warnings", '', 'no warning';
    }

    # Search from Alexanderstr. to Schillingstr.
    {
	my($path) = $s_net->search("11252,12644", "11462,12384", DirectedHandicap => $directed_handicap_net);
	my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
	# Calculation is:
	# 18km/h = 5m/s
	# for 55m: t=11s
	# Penalty(q3)=2 -> 9km/h
	# for 55m: t=22s
	# -> diff is 11s
	is $directed_handicap_info[0]->{lost_time}, 11, 'expected 11s lost time';
    }

    # Search from Alexanderstr. to Alexanderstr. (without handicaps)
    {
	my($path) = $s_net->search("11252,12644", "11355,12331", DirectedHandicap => $directed_handicap_net);
	my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
	is_deeply \@directed_handicap_info, [], 'no handicaps';
    }
}

# trafficlight tests
{
    my $directed_handicap_net = StrassenNetz->make_net_directedhandicap($dh_tl, speed => 25, default_lost_trafficlight_time => 15);

    {
	my($path) = $s_net->search("14495,9609", "13999,9842", DirectedHandicap => $directed_handicap_net);
	my @route_info = $s_net->route_info(Route => $path);
	is $route_info[0]->{Street}, 'Puschkinallee';
	is scalar(@route_info), 1, 'straight forward';

	my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
	is_deeply \@directed_handicap_info,
	    [
	     {
	      "add_len" => undef,
	      "lost_time" => 0,
	      "lost_time_tl" => 15,
	      "path_begin_i" => 1,
	      "path_end_i" => 3
	     }
	    ], 'default lost_time_tl (15s)';
    }

    {
	# Normally the Ampeln->Net would contain the same traffic
	# lights as defined in $dh_tl. But just for demonstration of
	# the effect it's not defined here, leading to a strange route
	# avoiding the traffic lights in $dh_tl.
	my($path) = $s_net->search("14495,9609", "13999,9842", DirectedHandicap => $directed_handicap_net, Ampeln => { Net => {}, Penalty => 100 });
	my @route_info = $s_net->route_info(Route => $path);
	is $route_info[1]->{Street}, "(Puschkinallee -) Elsenstr.", 'strange route';

	my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
	is_deeply \@directed_handicap_info, [];
    }

    {
	my($path) = $s_net->search("12360,12505", "12632,12630", DirectedHandicap => $directed_handicap_net);
	my @directed_handicap_info = StrassenNetz->directedhandicap_get_losses($directed_handicap_net, $path);
	is_deeply \@directed_handicap_info,
	    [
	     {
	      "add_len" => undef,
	      "lost_time" => 0,
	      "lost_time_tl" => 20,
	      "path_begin_i" => 0,
	      "path_end_i" => 2
	     }
	    ], 'tl-specific lost_time_tl (20s instead of 15s)';
    }

}


__END__
