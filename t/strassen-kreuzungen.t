#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strassen-kreuzungen.t,v 1.3 2009/02/01 16:25:57 eserte Exp $
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
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

plan tests => 18;

use_ok "Strassen::Kreuzungen";

use Strassen::Core;

my $s = Strassen->new("$FindBin::RealBin/../data/strassen");
my $kr = Kreuzungen->new(Strassen => $s,
			 WantPos => 1,
			 Kurvenpunkte => 1,
			 UseCache => 1,
			);
isa_ok($kr, "Kreuzungen");

{
    my $at_point     = "9229,8785"; # Dudenstr./Mehringdamm
    my $before_point = "9272,8781"; # Platz der Luftbrücke
    my $after_point  = "9227,8890"; # Mehringdamm

    for ($at_point, $before_point, $after_point) {
	ok($kr->get($_), "Got simple entry for point <$_>")
	    or diag("This may fail if data in <strassen> changed");
	ok($kr->get_records($_), "Got complex entry for point <$_>"); 
    }

    my %situation = $kr->situation_at_point($at_point, $before_point, $after_point);
    is($situation{before_street}->[Strassen::NAME()], "Platz der Luftbrücke", "Street before");
    is($situation{after_street}->[Strassen::NAME()],  "Mehringdamm", "Street after");

#require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([\%situation],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

}

{
    no warnings qw(qw);
    # Wilhelmstr. -> Wilhelmstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9378,10539));
	is($situation{action}, '', q{It's "straight"});
    }

    # Wilhelmstr. -> Stresemannstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9250,10563));
	like($situation{action}, qr{^(half-)?left$}, q{It's "left" or "half-left", we accept both});
    }

    # Wilhelmstr. -> Franz-Stampfer-Str.
    {
	my %situation = situation_at_point_inorder($kr, qw(9404,10250 9388,10393 9509,10391));
	is($situation{action}, 'right', q{It's "right"});
    }

    # Viktoria-Quartier -> Methfesselstr.
    {
	my %situation = situation_at_point_inorder($kr, qw(9026,8916 9111,9036 9063,8935));
	is($situation{action}, 'sharp-right', q{It's "sharp-right"});
    }

    # Methfesselstr. -> Viktoria-Quartier
    {
	my %situation = situation_at_point_inorder($kr, qw(9063,8935 9111,9036 9026,8916));
	is($situation{action}, 'sharp-left', q{It's "sharp-left"});
    }

    # Wilhelmshöhe
    {
	my %situation = situation_at_point_inorder($kr, qw(9186,9107 9155,9029 9149,8961));
	is($situation{action}, '', q{No crossing, no action"});
    }
}

{
    local $TODO = "Suboptimal results";
    no warnings qw(qw);

    {
	# Skalitzer/Schlesisches Tor
	my %situation = situation_at_point_inorder($kr, qw(13015,10659 12985,10665 12899,10595));
	is($situation{action}, '', q{Should be "straight", because it's the main street});
    }

    {
	# Oberbaumstr.
	my %situation = situation_at_point_inorder($kr, qw(13206,10651 13178,10623 13015,10659));
	is($situation{action}, '', q{Should be "straight", because it's the main street});
    }
}

sub situation_at_point_inorder {
    my($kr, $before_point, $at_point, $after_point) = @_;
    $kr->situation_at_point($at_point, $before_point, $after_point);
}

__END__
