#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: common.pl,v 1.2 2003/01/08 20:58:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# Scheidemannstr/Entlastungsstr => UdL/Glinkastr.
# check for handicap_s feature
TEST5:
{
    require Strassen::Dataset;
    my $sd = Strassen::Dataset->new;
    my $handicap_net = $sd->get_net("str", "h", "city");
    my $handicap_penalty = {q0 => 1,
			    q1 => 2,
			    q2 => 3,
			    q3 => 4};

    require BBBikeRouting;
    my $routing = BBBikeRouting->new->init_context;
    $routing->Start->Street("Scheidemann/Entlastung");
    $routing->resolve_position($routing->Start);
    ok(defined $routing->Start->Coord);
    $routing->Goal->Street("Unter den Linden/Glinka");
    $routing->resolve_position($routing->Goal);
    ok(defined $routing->Goal->Coord);

    my(@arr) = Strassen::Inline::search_c(
        $net, $routing->Start->Coord, $routing->Goal->Coord,
	-penaltysub => sub {
	    my($next_node, $last_node, $pen) = @_;
	    if (defined $last_node and
		exists $handicap_net->{$last_node}{$next_node}) {
		$pen *= $handicap_penalty->{$handicap_net->{$last_node}{$next_node}}; # Handicapzuschlag
	    }
	    $pen;
        },
    );

    ok(scalar @arr);
}

__END__
