#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: BBBikeRouting.pm,v 1.4 2003/06/01 21:43:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000,2001 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeRouting;

BEGIN { $^W = 1 }

use strict;
use Class::Struct;
use BBBikeUtil;

struct('BBBikeRouting::Position' => {Street => "\$", Citypart => "\$",
				     City => "\$",
				     Coord => "\$", Multi => "\$",
				     Attribs => "\$",
				    });
struct('BBBikeRouting::Context' => {Vehicle => "\$", Scope => "\$",
				    Velocity => "\$",
				    UseXS => "\$", UseCache => "\$",
				    UseNetServer => "\$",
				    ZIPLookArgs => "\$",
				    SearchArgs => "\$", Algorithm => "\$",
				    CGI => "\$", BrowserInfo => "\$",
				    RouteInfoKm => "\$",
				    Verbose => "\$",
				    MultipleChoices => "\$",
				   });
struct('BBBikeRouting' => {Context => "BBBikeRouting::Context",
			   Start => "BBBikeRouting::Position",
			   StartChoices => "\$", # array of BBBikeRouting::Position
			   Via => "\$", # array of BBBikeRouting::Position
			   ViaChoices => "\$", # XXX not used yet
			   Goal => "BBBikeRouting::Position",
			   GoalChoices => "\$", # array of BBBikeRouting::Position
			   Dataset => "\$",
  			   Streets => "\$", ZIP => "\$",
  			   ZIPStreets => "\$", Net => "\$",
  			   Stations => "\$", Cities => "\$",
  			   Crossings => "\$",
			   Path => "\$", RouteInfo => "\$",
			   #PenaltyNets => "\$",
			  });

sub BBBikeRouting::LastVia {
    my $self = shift;
    if (ref $self->Via eq 'ARRAY') {
	$self->Via->[-1];
    } else {
	undef;
    }
}

sub BBBikeRouting::Context::ExpandedScope {
    my $self = shift;
    if    ($self->Scope eq 'city')       { [qw(city)] }
    elsif ($self->Scope eq 'region')     { [qw(city region)] }
    elsif ($self->Scope eq 'wideregion') { [qw(city region wideregion)] }
    else {
	die "Unknown scope: " . $self->Scope;
    }
}

sub init_context {
    my $self = shift;
    my $context = BBBikeRouting::Context->new;
    $self->Context($context);
    $self->Start(BBBikeRouting::Position->new);
    $self->StartChoices([]);
    $self->Goal(BBBikeRouting::Position->new);
    $self->GoalChoices([]);
    require Strassen::Dataset;
    $self->Dataset(Strassen::Dataset->new); # XXX arguments?
    $context->Vehicle("bike");
    $context->Velocity(kmh2ms(20));
    $context->Scope("city");
    $context->UseXS(1);
    $context->UseNetServer(1);
    $context->UseCache(1);
    $context->Algorithm("C-A*");
    $context->RouteInfoKm(1);
    $context->MultipleChoices(1);
    $self;
}

sub change_scope {
    my($self, $scope) = @_;
    $self->Context->Scope($scope);
    $self->Dataset(Strassen::Dataset->new); # XXX arguments?
    $self->Streets(undef);
    $self->ZIP(undef);
    $self->ZIPStreets(undef);
    $self->Net(undef);
    $self->Stations(undef);
    $self->Crossings(undef);
    $self->Cities(undef);
    $self->Path(undef);
    $self->RouteInfo(undef);
    $self->Start(BBBikeRouting::Position->new);
    $self->Via([]);
    $self->Goal(BBBikeRouting::Position->new);
}

sub init_str {
    my $self = shift;
    if (!$self->Streets) {
	my $context = $self->Context;
	require Strassen::Core;
	if ($context->Vehicle eq 'oepnv') {
	    my $sstr = $self->Dataset->get("str","b",$context->ExpandedScope);
	    $sstr = Strassen->new_copy_restricted($sstr,
						  -restrictions => [qw/S0/]);
	    my $ustr = $self->Dataset->get("str","u",$context->ExpandedScope);
	    $ustr = Strassen->new_copy_restricted($ustr,
						  -restrictions => [qw/U0/]);
	    require Strassen::MultiStrassen;
	    $self->Streets(MultiStrassen->new($sstr, $ustr));
	} else {
	    $self->Streets($self->Dataset->get("str","s",$context->ExpandedScope));
	    if ($context->Vehicle eq 'car') {
		$self->Streets(Strassen->new_copy_restricted
			       ($self->Streets, -restrictions => [qw/NN/]));
	    }
	}
    }
    $self->Streets;
}

sub init_zip {
    my $self = shift;
    if (!$self->ZIP) {
	require PLZ;
	$self->ZIP(PLZ->new());
    }
    $self->ZIP;
}

sub init_zip_s {
    my $self = shift;
    if (!$self->ZIPStreets) {
	$self->ZIPStreets($self->init_zip->as_streets);
    }
    $self->ZIPStreets;
}

sub init_cities {
    my $self = shift;
    if (!$self->Cities) {
	$self->Cities($self->Dataset->get("p", "o", $self->Context->ExpandedScope));
    }
    $self->Cities;
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
	if ($context->Vehicle eq 'oepnv') {
	    $self->Net(StrassenNetz->new($self->Streets));
	    die "NYI XXX" if $context->Algorithm eq 'C-A*-2';
	    $self->Net->make_net(UseCache => $context->UseCache);
	    $self->init_stations;
	    $self->Net->add_umsteigebahnhoefe($self->Stations,
					      -addmapfile => 'umsteigebhf');
	} else {
	    $self->Net(StrassenNetz->new_from_best
		       (Strassen => $self->Streets,
			OnCreate => sub {
			    if ($context->Algorithm eq 'C-A*-2') {
				require Strassen::CNetFileDist;
				Strassen::CNetFile::make_net($_[0]);
				    $_[0]->make_sperre
					('gesperrt',
					 Type => ['einbahn', 'sperre',
						  'wegfuehrung']);
				# XXX make_sperre nyi
			    } else {
				$_[0]->make_net(UseCache => $context->UseCache);
				if ($context->Vehicle eq 'bike') {
				    $_[0]->make_sperre
					('gesperrt',
					 Type => ['einbahn', 'sperre',
						  'wegfuehrung']);
				} elsif ($context->Vehicle eq 'car') {
				    $_[0]->make_sperre
					('gesperrt',
					 Type => ['einbahn', 'sperre',
						  'tragen', 'wegfuehrung']);
				    $_[0]->make_sperre
					('gesperrt_car',
					 Type => ['einbahn', 'sperre',
						  'tragen', 'wegfuehrung']);
				}
			    }
			},
			NoNewFromServer => !$context->UseNetServer,
		       ));
	}
    }
    $self->Net;
}

sub init_crossings {
    my $self = shift;
    if (!$self->Crossings) {
	require Strassen::Kreuzungen;
	my $context = $self->Context;
	if ($context->Vehicle eq 'oepnv') {
	    $self->init_stations;
	    $self->Crossings(Kreuzungen->new_from_strassen(Strassen => $self->Stations, WantPos => 1, Kurvenpunkte => 1, UseCache => $context->UseCache));
	} else {
	    $self->init_str;
	    $self->Crossings(Kreuzungen->new(Strassen => $self->Streets, WantPos => 1, Kurvenpunkte => 1, UseCache => $context->UseCache));
	}
	$self->Crossings->make_grid(UseCache => $context->UseCache);
    }
    $self->Crossings;
}

sub init_stations {
    my $self = shift;
    if (!$self->Stations) {
	my $ubhf = $self->Dataset->get("p","u",$self->Context->ExpandedScope);
	my $sbhf = $self->Dataset->get("p","b",$self->Context->ExpandedScope);
	require Strassen::MultiStrassen;
	$self->Stations(MultiStrassen->new($sbhf, $ubhf));
    }
    $self->Stations;
}

foreach (qw(Start Goal)) {
    my $c='sub get_'.lc($_).'_position { shift->get_position(\''.$_.'\', @_) }';
#    warn $c;
    eval $c;
}

# A return value of undef means multiple matches or no match. Please look
# into $self->...Choices.
sub resolve_position {
    my $self = shift;
    my $pos_o = shift;
    my $choices_o = shift;
    my $street = shift || $pos_o->Street;
    my $citypart = shift || $pos_o->Citypart;
    my(%args) = @_;
    my $context = $self->Context;

    if ($context->Vehicle eq 'oepnv') {
	my $ret = $self->Stations->get_by_name($street, 0);
	if (!$ret) {
	    $ret = $self->Stations->get_by_name("^(?i:\Q$street\E)", 1);
	}
	if ($ret) {
	    $pos_o->Street($ret->[Strassen::NAME()]);
	    $pos_o->Citypart(undef);
	    $pos_o->Coord($ret->[Strassen::COORDS()]->[0]);
	    return;
	} # else fallback to streets
    }

    if (defined $pos_o->City) {
	my $city = $pos_o->City;
	my $cities = $self->init_cities;
	my $ret = $cities->get_by_name($city, 0);
	if (!$ret) {
	    $ret = $cities->get_by_name("^(?i:\Q$city\E)", 1);
	}
	if ($ret) {
	    $pos_o->City($ret->[Strassen::NAME()]);
	    $pos_o->Street(undef);
	    $pos_o->Citypart(undef);
	    $pos_o->Coord($ret->[Strassen::COORDS()]->[0]);
	    return;
	} # else fallback
	warn "Can't find city $city in @{[ $cities->file ]}, fallback to streets";
    }

    if ($street =~ m|/|) { # StreetA/StreetB
	my(@streets) = split m|/|, $street;
	my %coords;
	$self->init_str; # for $self->Streets
	for my $s (@streets) {
	    my(@r) = $self->Streets->get_all_by_name("^(?i:" . quotemeta($s) . ".*)", 1);
	    if (!@r) {
		warn "Can't find $s in file @{[ $self->Streets->file ]}\n";
		last;
	    }
	    if (!keys %coords) {
		for my $r (@r) {
		    for my $c (@{ $r->[Strassen::COORDS()] }) {
			$coords{$c} = 1;
		    }
		}
	    } else {
		for my $r (@r) {
		    for my $c (@{ $r->[Strassen::COORDS()] }) {
			if (exists $coords{$c}) {
			    $pos_o->Street($street);
			    $pos_o->Citypart(undef);
			    $pos_o->Coord($c);
			    return;
			}
		    }
		}
	    }
	}
	warn "Fallback to PLZ method with $streets[0]\n";
	$street = $streets[0];
    }

    if ($context->Scope eq 'city') {
	$self->init_zip;
	my $return_multiple = $context->MultipleChoices;
	my(@from_res) = $self->ZIP->look_loop_best
	    (PLZ::split_street($street),
	     MultiZIP => !$return_multiple,
	     MultiCitypart => !$return_multiple,
	     Agrep => 'default',
	     (defined $citypart ? (Citypart => $citypart) : ()),
	     ($context->ZIPLookArgs ? @{ $context->ZIPLookArgs } : ()),
	    );

	if (@{ $from_res[0] }) {
	    # remove entries without coord
	    for(my $i = 0; $i <= $#{ $from_res[0] }; $i++) {
		if (!$from_res[0]->[$i][PLZ::LOOK_COORD()]) {
		    splice @{ $from_res[0] }, $i, 1;
		    $i--;
		}
	    }
	}

	return undef if (!@{ $from_res[0] });

	if (@{ $from_res[0] } > 1 && $context->MultipleChoices) {
	    @$choices_o = ();
	    for (@{ $from_res[0] }) {
		my $new_pos = BBBikeRouting::Position->new;
		$new_pos->Street  ($_->[PLZ::LOOK_NAME()]);
		$new_pos->Citypart($_->[PLZ::LOOK_CITYPART()]);
		$new_pos->Coord   ($_->[PLZ::LOOK_COORD()]);
		push @$choices_o, $new_pos;
	    }
	    return undef;
	}

	my $from_data = $from_res[0]->[0];
	$pos_o->Street  ($from_data->[PLZ::LOOK_NAME()]);
	$pos_o->Citypart($from_data->[PLZ::LOOK_CITYPART()]);
	$pos_o->Coord   ($from_data->[PLZ::LOOK_COORD()]);
    } else {
	$self->init_str; # for $self->Streets
	# rx or not?
	my $r = $self->Streets->get_by_name("^(?i:" . quotemeta($street) . ".*)", 1);
	if (!$r) {
	    die "Can't find $street in file @{[ $self->Streets->file ]}";
	}
	$pos_o->Street($r->[Strassen::NAME()]);
	$pos_o->Citypart(undef);
	$pos_o->Coord($r->[Strassen::COORDS()]->[0]);
    }

    $self->fix_position($pos_o);
}

sub get_position {
    my $self = shift;
    my $type = ucfirst(shift); # start or goal
    my $pos_o = $self->$type();
    my $choices = $type . "Choices";
    my $choices_o = $self->$choices();
    $self->resolve_position($pos_o, $choices_o);
}

sub fix_position {
    my($self, $pos_o) = @_;
    $self->init_net;
    if (!$self->Net->reachable($pos_o->Coord)) {
	$self->init_crossings;
	$pos_o->Coord(($self->Crossings->nearest_loop(split /,/, $pos_o->Coord))[0]);
	if ($self->Context->Vehicle eq 'oepnv') {
	    $self->init_crossings;
	    $pos_o->Street($self->Crossings->get_first($pos_o->Coord));
	}
    }
    $pos_o->Coord;
}

sub search {
    my $self = shift;

    $self->init_net;

    my $continued = 0;
    my $start_coord;
    if (ref $self->Via eq 'ARRAY' && @{$self->Via} > 0) {
	$self->get_position("LastVia") if $self->LastVia && !$self->LastVia->Coord;
	$start_coord = $self->LastVia->Coord;
	$continued = 1;
    } else {
	$self->get_position("Start") if !$self->Start->Coord;
	$start_coord = $self->Start->Coord;
    }
    $self->get_position("Goal") if !$self->Goal->Coord;

    die "No start coordinate after using get_position" if !$start_coord;
    die "No goal coordinate after using get_position" if !$self->Goal->Coord;

    my $context = $self->Context;

    my($res) = $self->Net->search
	($start_coord, $self->Goal->Coord,
	 Tragen => ($context->Vehicle eq 'bike'),
	 $context->Velocity ? (Velocity => $context->Velocity) : (),
	 $context->SearchArgs ? @{ $context->SearchArgs } : (),
	 $context->Algorithm ? (Algorithm => $context->Algorithm) : (),
	 $context->Verbose ? (Stat => 1) : (),
	);
    if (!$res) {
	die "No route found between $start_coord and " . $self->Goal->Coord;
    }

    if ($continued && $self->Path) {
	if (defined $res) {
	    $self->Path([@{ $self->Path },
			 @{ $res }]);
	}
	my $whole;
	{
	    local $^W; # supress "numeric" warnings
	    $whole = $self->RouteInfo->[-1]->{Whole} + 0;
	}
	my @new_route_info = $self->Net->route_info(Route => $res,
						    Km    => $context->RouteInfoKm);
	for (@new_route_info) {
	    my($num,$unit) = split /\s+/, $_->{Whole};
	    $_->{Whole} = ($num+$whole) . " $unit";
	}
	$self->RouteInfo([@{ $self->RouteInfo }, @new_route_info ]);
    } else {
	$self->Path([]);
	if (defined $res) {
	    $self->Path($res);
	}
	$self->RouteInfo([$self->Net->route_info(Route => $self->Path,
						 Km    => $context->RouteInfoKm)]);
    }
}

# Prepare for a continued search. Call ->search after this method.
sub continue {
    my($self, $position) = @_;
    $self->Via([]) if ref $self->Via ne 'ARRAY';
    push @{ $self->Via }, $self->Goal;
    $self->Goal($position);
}

# Add a new point _without a search_ to an existing route. If there
# is no existing route, set the point as start point. The software
# using BBBikeRouting.pm should take care that there is no search
# from or to a freely added position.
sub add_position {
    my($self, $position, %args) = @_;
    my $is_start = 0;
    if (!$self->Path || scalar @{$self->Path} == 0) {
	$is_start = 1;
	$self->RouteInfo([]);
	$self->Path([]);
    }
    $position->Attribs("free"); # XXX preserve existing attributes?
    if (!$is_start) {
	$self->Via([]) if ref $self->Via ne 'ARRAY';
	push @{ $self->Via }, $self->Goal;
	$self->Goal($position);
    } else {
	$self->Start($position);
    }
    push @{ $self->Path }, [split /,/, $position->Coord];
    if (!$is_start) {
	require Strassen::Util;
	require BBBikeUtil;
	my $hop = Strassen::Util::strecke(@{$self->Path}[-2,-1]);
	my $whole;
	{
	    local $^W; # supress "numeric" warnings
	    $whole = $self->RouteInfo->[-1]->{Whole} + 0
		if $self->RouteInfo->[-1];
	    $whole += BBBikeUtil::m2km($hop);
	    $whole .= " km";
	}
	push @{ $self->RouteInfo },
	    {Hop => BBBikeUtil::m2km($hop),
	     Whole => $whole,
	     Way => "", # XXX
	     Angle => "", # XXX
	     Direction => "", # XXX
	     Street => "???",
	     Coords => join(",",@{$self->Path->[-2]}),
	    };
    }
}

sub delete_to_last_via {
    my($self) = @_;
    if (ref $self->Via eq 'ARRAY' && @{$self->Via} > 0) {
	my $via = pop @{$self->Via};
	while(@{$self->Path}) {
	    my $last = pop @{$self->Path};
	    last if (join(",", @$last) eq $via->Coord);
	}
	if (@{$self->Path}) {
	    my $new_goal = BBBikeRouting::Position->new;
	    $new_goal->Coord(join(",", @{ $self->Path->[-1] }));
	    $self->Goal($new_goal);
	}
	$self->RouteInfo([$self->Net->route_info(Route => $self->Path,
						 Km    => $self->Context->RouteInfoKm)]);
    }
}

sub inc {
    eval <<'EOF';
use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/lib",
	 "$FindBin::RealBin/data",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 "$FindBin::RealBin/../data",
	);
EOF
    warn $@ if $@;
}

1;

__END__

