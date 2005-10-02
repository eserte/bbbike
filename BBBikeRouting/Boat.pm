# -*- perl -*-

#
# $Id: Boat.pm,v 1.2 2005/10/01 22:50:45 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeRouting::Boat;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use base qw(BBBikeRouting);

sub init_str {
    my $self = shift;
    if (!$self->Streets) {
	my $context = $self->Context;
	require Strassen::Core;
	my $str = $self->Dataset->get("str","wr",$context->ExpandedScope);
	$self->Streets($str);
    }
    $self->Streets;
}

sub init_net {
    my $self = shift;
    if (!$self->Net) {
	require Strassen::StrassenNetz;
	my $context = $self->Context;
	$self->init_str;
	if ($context->UseXS) {
	    eval q{ use BBBikeXS };
	}
	$self->Net(StrassenNetz->new($self->Streets));
	die "NYI XXX" if $context->Algorithm eq 'C-A*-2';
	$self->Net->make_net(UseCache => $context->UseCache,
			     PreferCache => $context->PreferCache);
	$self->init_stations;
    }
    $self->Net;
}

sub do_init_crossings {
    my $self = shift;
    $self->do_init_crossings_with_stations;
}

sub init_stations {
    my $self = shift;
    if (!$self->Stations) {
	my $anlege = $self->Dataset->get("p","wr",$self->Context->ExpandedScope);
	$self->Stations($anlege);
    }
    $self->Stations;
}

sub resolve_position {
    my $self = shift;
    my $pos_o = shift;
    my $choices_o = shift;
    my $street = shift || $pos_o->Street;
    my $citypart = shift || $pos_o->Citypart;
    my(%args) = @_;
    my $fixposition = $args{fixposition};
    if (!defined $fixposition) { $fixposition = 1 }
    my $context = $self->Context;

    my $ret = $self->Stations->get_by_name($street, 0);
    if (!$ret) {
	$ret = $self->Stations->get_by_name("^(?i:\Q$street\E)", 1);
    }
    if ($ret) {
	$pos_o->Street($ret->[Strassen::NAME()]);
	$pos_o->Citypart(undef);
	$pos_o->Coord($ret->[Strassen::COORDS()]->[0]);
	return $pos_o->Coord;
    } else {
	die "Can't find $street";
    }
}

sub fix_position {
    my($self, $pos_o) = @_;
    $self->init_net;
    if (!$self->Net->reachable($pos_o->Coord)) {
	$self->init_crossings;
	$pos_o->Coord($self->Crossings->nearest_loop(split(/,/, $pos_o->Coord), BestOnly => 1, UseCache => $self->Context->UseCache));
	$self->init_crossings; # XXX überflüssig?
	$pos_o->Street($self->Crossings->get_first($pos_o->Coord));
    }
    $pos_o->Coord;
}

1;

__END__
