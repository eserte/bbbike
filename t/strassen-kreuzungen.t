#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

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

use Strassen::Kreuzungen;

use Strassen::Core;
use Strassen::StrassenNetz;

my $s = Strassen->new("$FindBin::RealBin/../data/strassen");
my @common_args = (Strassen => $s,
		   WantPos => 1,
		   Kurvenpunkte => 1,
		   UseCache => 1,
		  );
my $kr1 = Kreuzungen->new(@common_args);
isa_ok($kr1, "Kreuzungen");

my $ampeln = Strassen->new("$FindBin::RealBin/../data/ampeln");
my $vf     = Strassen->new("$FindBin::RealBin/../data/vorfahrt");
my $handicap_net  = StrassenNetz->new(Strassen->new("$FindBin::RealBin/../data/handicap_s"));
my $qualitaet_net = StrassenNetz->new(Strassen->new("$FindBin::RealBin/../data/qualitaet_s"));
$handicap_net->make_net_cat;
$qualitaet_net->make_net_cat;
my $kr2 = Kreuzungen::MoreContext->new(@common_args,
				       Ampeln => $ampeln->get_hashref_by_cat,
				       Vf     => $vf,
				       HandicapNet => $handicap_net,
				       QualitaetNet => $qualitaet_net,
				      );
isa_ok($kr2, "Kreuzungen");
isa_ok($kr2, "Kreuzungen::MoreContext");

for my $kr ($kr1, $kr2) {
    my $at_point     = "9229,8785"; # Dudenstr./Mehringdamm
    my $before_point = "9272,8781"; # Platz der Luftbr�cke
    my $after_point  = "9227,8890"; # Mehringdamm

    for ($at_point, $before_point, $after_point) {
	ok($kr->get($_), "Got simple entry for point <$_> (with @{[ ref $kr ]})")
	    or diag("This may fail if data in <strassen> changed");
	ok($kr->get_records($_), "Got complex entry for point <$_>"); 
    }

    my %situation = $kr->situation_at_point($at_point, $before_point, $after_point);
    is($situation{before_street}->[Strassen::NAME()], "Platz der Luftbr�cke", "Street before");
    is($situation{after_street}->[Strassen::NAME()],  "Mehringdamm", "Street after");

    is $kr->get_crossing_name($at_point), 'Dudenstr./Mehringdamm/Platz der Luftbr�cke/Tempelhofer Damm', 'get_crossing_name';
    is $kr->get_crossing_name($before_point), 'Platz der Luftbr�cke', 'get_crossing_name, "Kurvenpoint"';
    is $kr->get_crossing_name($after_point), 'Mehringdamm/Schwiebusser Str.', 'get_crossing_name';

    is $kr->get_crossing_name($after_point, sep => " "), 'Mehringdamm Schwiebusser Str.', 'get_crossing_name, changed separator';
}

for my $kr ($kr1, $kr2) {
    no warnings qw(qw);

    # not at streets
    {
	my %situation = situation_at_point_inorder_unchecked($kr, qw(10009,10387 10044,10220 10256,10220));
	is_deeply($situation{neighbors}, [], 'No streets, no neighbors');
	is($situation{before_street}, undef, 'No street before');
	is($situation{after_street}, undef, 'No street after');
    }

    # Luckauer Str.: constructed point in middle, but probably missing in nets
    {
	my %situation = situation_at_point_inorder_unchecked($kr, qw(11105,10945 11126,10985 11150,11030));
	is_deeply($situation{neighbors}, [], 'Currently cannot resolve any neighbors'); # XXX Should this be fixed?
	is($situation{action}, '', q{Constructed point in middle -> straight});
    }

    # Adalbertstr.: constructed point at the end, but probably missing in nets
    {
	my %situation = situation_at_point_inorder_unchecked($kr, qw(11505,10744 11556,10869 11593,10956));
	is($situation{after_street}, undef, 'Currently cannot resolve after street'); # XXX Should this be fixed?
	is($situation{action}, '', q{Constructed point at end -> straight});
    }

    # Adalbertstr.: constructed point at the begin, but probably missing in nets
    {
	my %situation = situation_at_point_inorder_unchecked($kr, qw(11484,10694 11505,10744 11556,10869));
	is($situation{before_street}, undef, 'Currently cannot resolve before street'); # XXX Should this be fixed?
	is($situation{action}, '', q{Constructed point at begin -> straight});
    }

    # Wilhelmstr. -> Wilhelmstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9384,10536));
	is($situation{action}, '', q{It's "straight"} . " (with @{[ ref $kr ]})");
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, 'traffic_light', "Here's a traffic light");
	}
    }

    # Wilhelmstr.: drive back (= 180�)
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9404,10250));
	is($situation{action}, 'back', q{Driving back"} . " (with @{[ ref $kr ]})");
    }

    # Hohenstaufenstr./M�nchener Str. (umdrehen < 180�)
    {
	my %situation = situation_at_point_inorder($kr, qw(6209,9772 6237,9772 6209,9773));
	is($situation{action}, 'back', q{Driving back, not quite 180 degrees});
    }

    # Wilhelmstr. -> Stresemannstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9353,10421));
	like($situation{action}, qr{^(half-)?left$}, q{It's "left" or "half-left", we accept both});
    }

    # Wilhelmstr. -> Franz-Stampfer-Str.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9527,10389));
	is($situation{action}, 'right', q{It's "right"});
    }

    # Prinzessinnenstr. -> Oranienstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(11145,10638 10965,10851 11049,10816));
	is($situation{action}, 'sharp-right', q{It's "sharp-right"});
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, '', "Here's nothing else");
	}
    }

    # Oranienstr. -> Prinzessinnenstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(11049,10816 10965,10851 11145,10638));
	is($situation{action}, 'sharp-left', q{It's "sharp-left"});
    }

    # Wilhelmsh�he
    {
	my %situation = situation_at_point_inorder($kr, qw(9186,9107 9155,9029 9149,8961));
	is($situation{action}, '', q{No crossing, no action"});
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, '', "Here's nothing else");
	}
    }

    # Bergmannstr., Fu�g�ngerampel
    {
	my %situation = situation_at_point_inorder($kr, qw(9505,9306 9489,9309 9309,9347));
	is($situation{action}, '', q{No crossing, no action"});
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, 'traffic_light_pedestrian', "pedestrian's traffic light");
	}
    }

    # R�dersdorfer Str.
    {
	my %situation = situation_at_point_inorder($kr, qw(13295,11792 13173,11788 13161,11795));
	is($situation{action}, '', q{Ruedersdorfer.: straight"});
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, 'right_of_way', "Ruedersdorfer.: right of way, straight");
	}
    }

    # R�dersdorfer/Wedekindstr
    {
	my %situation = situation_at_point_inorder($kr, qw(13052,11867 13066,11854 13217,11936));
	is($situation{action}, 'left', "Ruedersdorfer/Wedekindstr");
	local $TODO = "situation_at_point_inorder needs Vorfahrt detection based on street categories";
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, 'bent_right_of_way', "Ruedersdorfer/Wedekindstr.: bent right of way");
	}
    }

    # Bergmannstr./S�dstern
    {
	my %situation = situation_at_point_inorder($kr, qw(10366,9233 10547,9233 10564,9292));
	is($situation{action}, 'left', "Bergmannstr/Suedstern");
	if ($kr == $kr2) {
	    is($situation{traffic_rule}, 'bent_right_of_way', "Bergmannstr/Suedstern: bent right of way");
	}
    }

    # Bergmannstr., Kopfsteinpflaster
    if ($kr == $kr2) {
	{
	    my %situation = situation_at_point_inorder($kr, qw(10123,9233 10001,9234 9973,9232));
	    is($situation{quality_cat}, 'Q2', 'Bergmannstr.: Q2 begins');
	}
	{
	    my %situation = situation_at_point_inorder($kr, qw(9973,9232 10001,9234 10123,9233));
	    is($situation{quality_cat}, 'Q0', 'Bergmannstr.: Q2 ends, Q0 begins');
	}
    }

    # S�dstern, Fu�g�nger
    if ($kr == $kr2) {
	{
	    my %situation = situation_at_point_inorder($kr, qw(10905,9472 10749,9342 10741,9344));
	    is($situation{handicap_cat}, 'q3', 'Suedstern: q3 begins');
	}
	{
	    my %situation = situation_at_point_inorder($kr, qw(10741,9344 10749,9342 10905,9472));
	    is($situation{handicap_cat}, 'q0', 'Suedstern: q3 ends, q0 begins');
	}
    }

    {
	# Viktoriapark -> Gro�beerenstr.
	my %situation = situation_at_point_inorder($kr, qw(9007,9264 8970,9323 9000,9509));
	is($situation{action}, '', q{This is not straight, not right}); # it would be right with HALF_ANGLE=30
    }

    {
	# R�dersdorfer Str./Parkplatz
	my %situation = situation_at_point_inorder($kr, qw(13161,11795 13173,11788 13295,11792));
	is($situation{action}, '', q{Die Parkplatzeinfahrt sollte hier kein "links" verursachen.}); # it does with HALF_ANGLE=30
    }

    {
	# Fuldastr./Weichselpark
	my %situation = situation_at_point_inorder($kr, qw(12836,8980 12902,9066 12909,9085));
	is($situation{action}, '');
    }

}

for my $kr ($kr1, $kr2) {
    local $TODO = "Suboptimal results";
    no warnings qw(qw);

    {
	# Skalitzer/Schlesisches Tor
	my %situation = situation_at_point_inorder($kr, qw(13015,10659 12985,10665 12930,10621));
	is($situation{action}, '', q{Should be "straight", because it's the main street} . " (with @{[ ref $kr ]})");
    }

    {
	# Oberbaumstr.
	my %situation = situation_at_point_inorder($kr, qw(13178,10623 13082,10634 13015,10659));
	is($situation{action}, '', q{Should detect that the more straight street is an one-way street in the wrong direction});
    }

    {
	# Oberbaumstr./Falkensteinstr.
	my %situation = situation_at_point_inorder($kr, qw(13206,10651 13178,10623 13082,10634));
	is($situation{action}, '', q{Should be "straight", because it's the main street});
    }

    {
	# K�rtestr./S�dstern
	my %situation = situation_at_point_inorder($kr, qw(10905,9472 10749,9342 10713,9260));
	is($situation{action}, '', q{Should be "straight", because it's the main street});
    }

    {
	# Flughafenstr. -> Fuldastr.
	my %situation = situation_at_point_inorder($kr, qw(12349,8464 12494,8501 12551,8612));
	is($situation{action}, 'XXX', q{Komplizierte Wegfuehrung (zuerst links, dann rechts), benoetigt eine gesonderte Beschreibung});
    }

    {
	# Molkenmarkt
	my %situation = situation_at_point_inorder($kr, qw(10697,12303 10746,12364 10831,12371));
	is($situation{action}, 'half-right', q{Need some indication that it's not Stralauer Str. to the right, but the Platz});
    }

    {
	# Nostitz/Arndtstr.
	my %situation = situation_at_point_inorder($kr, qw(9505,9306 9487,9209 9553,9196));
	is($situation{action}, 'left', q{Der Strassenname aendert sich, es sind 90 Grad --- sollte "links" ausgeben});
    }
}

sub situation_at_point_inorder {
    my($kr, $before_point, $at_point, $after_point) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my %situation = situation_at_point_inorder_unchecked($kr, $before_point, $at_point, $after_point);
    local $TODO = ""; # these should always pass, regardless of the current $TODO setting
    ok($situation{before_street}, "Got street before - $before_point $at_point");
    ok($situation{after_street}, "Got street after - $at_point $after_point");
    %situation;
}

sub situation_at_point_inorder_unchecked {
    my($kr, $before_point, $at_point, $after_point) = @_;
    $kr->situation_at_point($at_point, $before_point, $after_point);
}

__END__
