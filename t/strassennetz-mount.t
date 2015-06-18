#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 $FindBin::RealBin,
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use BikePower ();
use Strassen::Core;
use Strassen::StrassenNetz;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan 'no_plan';

use BBBikeTest qw(using_bbbike_test_data);
using_bbbike_test_data;

my $s = Strassen->new('strassen');
my $net = StrassenNetz->new($s);
$net->make_net;

my $heights = Strassen->new('hoehe');
my %heights = %{ $heights->get_hashref };

my $mount_net = StrassenNetz->new($s);
isa_ok $mount_net, 'StrassenNetz';
$mount_net->make_net_steigung($net, \%heights);

my $bp_obj = BikePower->new(
			    '-no-ini' => 1,
			    Wc => 70, Wm => 15,
			    'A_c' => 0.4925155, # upright
			   );
my $act_power = 50;

my %mount_penalty; # a cache
my %extra_args;
$extra_args{Steigung} =
    {
     Net => $mount_net,
     Penalty => \%mount_penalty,
     PenaltySub => sub { steigung_penalty($_[0], $act_power) },
    };

my $c1 = '22060,-260'; # Dahmestr./Binswangersteig (Bohnsdorf)
my $c2 = '22145,208'; # Grottewitzstr.
my $route_point_with_mount = '21968,-15'; # Buntzelstr.
my $route_point_without_mount = '22169,14'; # Waltersdorfer Str.

{
    # with slope optimization
    my($path) = $net->search($c1, $c2, %extra_args);
    $path = [ map { join ",", @$_ } @$path ];
    ok( !(grep { $_ eq $route_point_with_mount } @$path), 'path not via Buntzelstr. (because of mount)')
	or diag(explain($path));
    ok( (grep { $_ eq $route_point_without_mount } @$path), 'path via Waltersdorfer Str. (because of mount)')
	or diag(explain($path));
}

{
    # no slope optimization
    my($path) = $net->search($c1, $c2);
    $path = [ map { join ",", @$_ } @$path ];
    ok( (grep { $_ eq $route_point_with_mount } @$path), 'path via Buntzelstr. (no slope optimization)');
    ok( !(grep { $_ eq $route_point_without_mount } @$path), 'path not via Waltersdorfer Str. (no slope optimization)');
}

# XXX The following functions are taken from bbbike (Perl/Tk) and MUST be refactored! vvv
sub steigung_penalty {
    my($steigung, $act_power) = @_;
    max_speed(power2speed($act_power, -grade => $steigung/1000));
}
sub max_speed {
    my($speed_belag) = @_;
    my $speed_radler = get_active_speed();
    if ($speed_belag <= 0) {
	require Carp;
	Carp::cluck("Division by zero protection");
	return $speed_radler;
    }
    ($speed_belag >= $speed_radler
     ? 1
     : $speed_radler/$speed_belag);
}
sub power2speed {
    my($power, %args) = @_;
    return if !$bp_obj;
    my $new_bp_obj = clone BikePower $bp_obj;
    $new_bp_obj->given('P');
    $new_bp_obj->headwind(0);
    my $grade = $args{-grade} || 0;
    $new_bp_obj->grade($grade);
    $new_bp_obj->power($power);
    $new_bp_obj->calc;
    $new_bp_obj->velocity*3.6;
}
sub get_active_speed {
    power2speed($act_power);
}
# XXX ^^^

__END__
