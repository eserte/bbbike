#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: CombineTrainStreetNets.pm,v 1.2 2003/08/24 23:26:13 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Konfigurierbar machen (z.B. auf einige Bahnarten einschraenken,
#     Berlin/Potsdam/restl. Umland)
# XXX Caching: z.Zt. wird "strassen" als Cachename verwendet, obwohl auch
#     Potsdamer Daten enthalten sind!
# XXX Wenn R/S/U-Bahn auf der gleichen Trasse verläuft, muss das in der
#     Category reflektiert werden. Evtl. muss die Routensuche auch
#     mehrere Stränge halten.
# XXX Umsteigen zwischen R/S/U-Bahn nur an den Umsteigebahnhöfen!
# XXX Penalty für Umsteigen und Einsteigen
# XXX Straßenbahnen in Potsdam und Berlin aufnehmen?
# XXX Heuristik: Hauptstraßen in Berlin besitzen eine Buslinie (20 km/h,
#     durschnittliche Wartezeit 10 Minuten)

# Dieses Modul ausprobieren:
#   bbbike -fast
#   Streets einschalten: l s u r b
#   Diese Modul nach /tmp/add.pl verlinken
#   add.pl in bbbike laden
#   in bbbike/ptksh: $net=CombineTrainStreetNets::build_custom_net() aufrufen
#   BBBikeFloodSearchPlugin laden
#   floodsearch starten

package CombineTrainStreetNets;

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
use Strassen::Core;
use Strassen::StrassenNetz;
use Strassen::MultiStrassen;
use BBBikeXS;

use Object::Iterate qw(iterate);

# $umsteige_s may be also used for debugging.
# Plot as follows in ptksh:
# plot("str", "L5", -draw => 1, -object => $CombineTrainStreetNets::umsteige_s)
# push @special_raise, "L5"
use vars qw($umsteige_s $bahn_cat_net $bike_speed);

sub build_custom_net {
    my $bahn_str = MultiStrassen->new(qw(ubahn sbahn rbahn));
    my $stations = MultiStrassen->new(qw(ubahnhof sbahnhof rbahnhof));
    my $exits    = Strassen->new(qw(exits));
    my $net = StrassenNetz->new($bahn_str);
    $net->make_net(UseCache => 1,
		   PreferCache => 1);
#XXX use or not? maybe only if no "exits" entry exists?
#    $net->add_umsteigebahnhoefe($stations,
#				-addmapfile => "umsteigebhf");
    my $rev_exits_hash = $exits->as_reverse_hash;

    $bahn_cat_net = StrassenNetz->new($bahn_str);
    $bahn_cat_net->make_net_cat(-usecache => 1);

    my $land_str = Strassen->new("landstrassen");
    my $potsdam_str = Strassen->new;
    iterate {
	if (index($_->[Strassen::NAME], "(Potsdam)") != -1) {
	    $potsdam_str->push($_);
	}
    } $land_str;
    my $berlin_str = Strassen->new("strassen");
    my $s_str = MultiStrassen->new($berlin_str, $potsdam_str);
    my $s_net = StrassenNetz->new($s_str);
    $s_net->make_net(UseCache => 1,
		     PreferCache => 1);

    warn "Start merging nets...\n";
    merge_nets($net, $s_net);
    warn "... OK\n"; # XXX remove if performance analyzed

    $main::category_color{"Ust-im"} = "#ff0000";
    $main::category_color{"Ust-ex"} = "#008000";

    $umsteige_s = Strassen->new;
    iterate {
	# XXX This is not ideal, because nearest_point only returns
	#     Crossings/Kurvenpunkte. A better implementation would
	#     add the really nearest point to the net. Maybe see also
	#     $use_exact_streetchooser in bbbike.cgi/tkbabybike.
	my $first_point = $_->[Strassen::COORDS][0];
	if (!exists $rev_exits_hash->{$first_point}) {
	    my $ret = $s_str->nearest_point($first_point,
					    FullReturn => 1);
	    if ($ret && $ret->{Coord} ne $first_point) {
		add_net2($net, $ret->{Coord}, $first_point,
			 $bahn_cat_net, "Ust");
		# implicite
		$umsteige_s->push(["", [$ret->{Coord}, $first_point], "Ust-im"]);
	    }
	}
    } $stations;

    iterate {
	my $c = $_->[Strassen::COORDS];
	for my $i (1 .. $#$c) {
	    add_net2($net, $c->[$i-1], $c->[$i],
		     $bahn_cat_net, "Ust");
	    # explicite
	    $umsteige_s->push(["", [$c->[$i-1], $c->[$i]], "Ust-ex"]);
	}
    } $exits;

    create_penalty_sub();

    $net;
}

sub create_penalty_sub {
    use constant R_SPEED     => 60;
    use constant S_SPEED     => 35;
    use constant U_SPEED     => 30; # siehe auch BVG-Statistik
    use constant BIKE_SPEED  => 15; # if not set otherwise
    use constant PEDES_SPEED => 4;  # wegen Treppen nur 4 km/h
    # XXX Evtl. brauche ich hier eine 3-Punkt-Penalty sub, um
    #     Umsteigebeziehungen feststellen zu können. Kann bbbike bzw.
    #     StrassenNetz damit umgehen?
    $bike_speed = defined &main::get_active_speed ? main::get_active_speed() : BIKE_SPEED;
    $main::penalty_subs{'street_bahn_net'} = sub {
	my($p, $next_node, $last_node) = @_;
	my $cat = $bahn_cat_net->{Net}{$next_node}{$last_node} ||
		  $bahn_cat_net->{Net}{$last_node}{$next_node};
	if (!defined $cat) {
	    # Straße
	    $p *= (R_SPEED / $bike_speed);
	} elsif ($cat =~ /^Ust/) {
	    $p *= (R_SPEED / PEDES_SPEED);
	} elsif ($cat =~ /^R/) {
	    $p *= 1;
	} elsif ($cat =~ /^S/) {
	    $p *= (R_SPEED / S_SPEED);
	} elsif ($cat =~ /^U/) {
	    $p *= (R_SPEED / U_SPEED);
	}
	$p;
    };
}

# XXX move to StrassenNetz
# XXX maybe add artificial Net2Name and {Strassen}{Data} entries
#     (e.g. "Zugang zum Bhf. ...")
sub add_net2 {
    my($net, $p1, $p2, $bahn_cat_net, $cat) = @_;
    my $s = Strassen::Util::strecke_s($p1, $p2);
    $net->{Net}{$p1}{$p2} = $s;
    $net->{Net}{$p2}{$p1} = $s;

    $bahn_cat_net->{Net}{$p1}{$p2} = $cat;
    $bahn_cat_net->{Net}{$p2}{$p1} = $cat;
}

# XXX move to StrassenNetz
sub merge_nets {
    my($dest_net, $add_net) = @_;
    # XXX this is not clean, as maybe independent Strassen objects are
    #     changed
    my $add_pos = scalar @{ $dest_net->{Strassen}{Data} };
    push @{ $dest_net->{Strassen}{Data} }, @{ $add_net->{Strassen}{Data} };
    my $Net = $dest_net->{Net};
    my $Net2Name = $dest_net->{Net2Name};
    my $add_Net2Name = $add_net->{Net2Name};
    while(my($p1,$v) = each %{$add_net->{Net}}) {
	while(my($p2,$s) = each %$v) {
	    $Net->{$p1}{$p2} = $s;
	    $Net2Name->{$p1}{$p2} =
		(exists $add_Net2Name->{$p1}{$p2}
		 ? $add_Net2Name->{$p1}{$p2}
		 : $add_Net2Name->{$p2}{$p1}
		) + $add_pos;
	}
    }
}

1;

__END__
