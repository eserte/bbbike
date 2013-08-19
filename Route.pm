# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998,2000,2001,2012,2013 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

package Route;

use strict;
#use AutoLoader 'AUTOLOAD';

use vars qw($coords_ref $realcoords_ref $search_route_points_ref
	    @EXPORT @ISA $VERSION);

$VERSION = '2.00';

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(POINT_SEARCH POINT_MANUELL);

use constant POINT_SEARCH  => 'a';
use constant POINT_MANUELL => 'm';

use BBBikeUtil qw(sqr);

sub new {
    my $class = shift;
    if (@_ == 1 && $_[0]->isa('Route')) {
	my $new;
	require Data::Dumper;
	eval Data::Dumper->Dumpxs([$_[0]], ['new']);
	die $@ if $@;
	return $new;
    } else {
	my %args = @_;
	bless \%args, $class;
    }
}

# $realcoords_ref is [[x,y], [x,y], ...]
sub new_from_realcoords {
    my($class, $realcoords_ref, %opts) = @_;
    my $searchroutepoints = delete $opts{-searchroutepoints};
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my $obj = $class->new;
    $obj->{Path} = [ @$realcoords_ref ];
    if ($searchroutepoints) {
	$obj->{SearchRoutePoints} = $searchroutepoints;
    }
    $obj->{From} = join ",", @{$obj->{Path}[0]};
    $obj->{To}   = join ",", @{$obj->{Path}[-1]};

    require Strassen::Util;
    my $len = 0;
    for my $i (0 .. $#$realcoords_ref-1) {
	$len += Strassen::Util::strecke($realcoords_ref->[$i],
					$realcoords_ref->[$i+1]);
    }
    $obj->{Len} = $len;

    $obj;
}

sub concat {
    my(@r) = @_;
    my %args;
    while (@r && !$r[0]) {
	shift @r;
    }
    while (@r && !$r[$#r]) {
	pop @r;
    }
    if (!@r) {
	return Route->new;
    }

    $args{From}       = $r[0]->from;
    $args{To}         = $r[$#r]->to;
    $args{Via}        = [];
    $args{Len}        = 0;
    $args{Penalty}    = 0;
    $args{Path}       = [];
    $args{PathCanvas} = [];
    $args{Ampeln}     = undef;
    $args{Transpose}  = $r[0]->transpose;
    for(my $i = 0; $i <= $#r; $i++) {
	my @p = $r[$i]->path_list;
	if ($i > 0) {
	    my $first = shift @p;
	    push @{$args{Via}}, $first; # XXX check on correctness
	}
	$args{Len}     += $r[$i]->len;
	$args{Penalty} += $r[$i]->penalty;
	push @{$args{Path}}, @p;
	my $ampeln = $r[$i]->ampeln;
	if (defined $ampeln) {
	    $args{Ampeln} += $ampeln;
	}
	if (defined $r[$i]->path_canvas) {
	    push @{$args{PathCanvas}}, $r[$i]->path_canvas_list;
	}
    }
    Route->new(%args);
}

sub from             { $_[0]->{From} }
sub to               { $_[0]->{To}   }
sub via              { $_[0]->{Via}  }
sub via_list         { @{$_[0]->{Via}}  }
sub len              { $_[0]->{Len}  }
sub penalty          { $_[0]->{Penalty}  }
# Path in der Form: [[x1,y1], [x2,y2], ...]
sub path             { $_[0]->{Path} }
sub path_list        { $_[0]->{Path} ? @{$_[0]->{Path}} : () }
# Path in der Form: ["x1,y1", "x2,y2", ...]
sub path_s           { [ map { _coord_as_string($_) } @{$_[0]->{Path}} ] }
sub path_s_list      { $_[0]->{Path} ? map { _coord_as_string($_) } @{$_[0]->{Path}} : () }
# Path in Canvas-Koordinaten
sub path_canvas      { $_[0]->{PathCanvas} }
sub path_canvas_list { @{$_[0]->{PathCanvas}} }
sub is_empty         { !defined $_[0]->{Path} || scalar $_[0]->{Path} == 0 }
sub ampeln           { $_[0]->{Ampeln} } # XXX deprecated...
sub trafficlights    { $_[0]->{Ampeln} }
sub coord_system     { $_[0]->{CoordSystem} || 'Standard' }
sub transpose        { $_[0]->{Transpose} }
sub nearest_node     { $_[0]->{NearestNode} }
sub set_nearest_node { $_[0]->{NearestNode} = $_[1] }
sub set_to           { $_[0]->{To} = $_[1] }

# erstellt eine String-Repräsentation der Route: x1,y1;x2,y2;...
sub as_string        { $_[0]->_as_string(";") }
sub as_cgi_string    { $_[0]->_as_string("!") } # ; ist schlecht bei CGI.pm

# following return a reference, not a copy
sub _realcoords        { $_[0]->{Path} }
sub _searchroutepoints { $_[0]->{SearchRoutePoints} }

sub new_from_cgi_string {
    my($class, $cgi_string) = @_;
    $class->new_from_realcoords([ map { [ split /,/ ] } split(/!/, $cgi_string) ]);
}

sub _as_string {
    my($self, $sep) = @_;
    my $route_ref = $self->path;
    my @res;
    for(my $i = 0; $i <= $#{$route_ref}; $i++) {
	push(@res, "$route_ref->[$i][0],$route_ref->[$i][1]");
    }
    join($sep, @res);
}

# einfacher Rückweg (ohne neue Suche)
sub rueckweg {
    my $self = shift;
    @{$self->{Path}}       = reverse @{$self->{Path}};
    @{$self->{PathCanvas}} = reverse @{$self->{PathCanvas}};
    @{$self->{Via}}        = reverse @{$self->{Via}};
    my $swap      = $self->{From};
    $self->{From} = $self->{To};
    $self->{To}   = $swap;
}

sub add {
    my($self, $x, $y, $cx, $cy, $as_via) = @_;
    my $xy = [$x, $y];
    push @{$self->{Path}}, $xy;
    push @{$self->{PathCanvas}}, [$cx, $cy]
	if defined $cx;
    if ($as_via) {
	push @{$self->{Via}}, $xy;
    }
    $self->{Ampeln} += 0; # XXX
    if (!defined $self->{From}) {
	$self->{From} = _coord_as_string($xy);
    } else {
	$self->{Len} += _strecke($self->{Path}[$#{$self->{Path}}-1], $xy);
	# XXX penalty fehlt
    }
    $self->{To} = _coord_as_string($xy);
}

sub dellast {
    my $self = shift;
    my $popped = pop @{$self->{Path}};
    pop @{$self->{PathCanvas}};
    if ($popped eq $self->{Via}[$#{$self->{Via}}]) { # XXX?
	pop @{$self->{Via}};
    }
    $self->{To} = _coord_as_string($self->{Path}[$#{$self->{Path}}]);
    if (!@{$self->{Path}}) {
	$self->{From} = undef;
	# XXX check on empty Via and PathCanvas
    }
    if (@{$self->{Path}}) {
	$self->{Len} -= _strecke($self->{Path}[$#{$self->{Path}}], $popped);
	# XXX penalty fehlt
    }
    $self->{Ampeln} -= 0; # XXX
}

sub reset {
    my $self = shift;
    $self->{Path}       = [];
    $self->{PathCanvas} = [];
    $self->{Via}        = [];
    $self->{From}       = undef;
    $self->{To}         = undef;
    $self->{Len}        = 0;
    $self->{Penalty}    = 0;
    $self->{Ampeln}     = 0;
}

# Simplify the given $route, with the help of a StrassenNetz object
# to level
#     0: just copy
#     1: return Route only with points with different street names
#     2: return Route only with points with different angles
sub simplify {
    my($orig_route, $net, $level) = @_;
    if ($level == 0) { # just copy
	new Route $orig_route;
    } else {
	require Strassen;
	my $route = new Route;
	my @route_list = $net->route_to_name($orig_route->path);
	if ($level == 1) {
	    my $last_name;
	    my $n = 0;
	    foreach my $e (@route_list) {
		if (defined $last_name &&
		    $last_name eq $e->[&StrassenNetz::ROUTE_NAME]) {
		    if ($n == $#route_list) {
			$route->add(@{$orig_route->path->[$e->[&StrassenNetz::ROUTE_ARRAYINX][1]]})
		    } else {
			next;
		    }
		}
		$route->add(@{$orig_route->path->[$e->[&StrassenNetz::ROUTE_ARRAYINX][0]]})
	    } continue {
		$n++;
	    }
	} else { # level == 2
	    my $n = 0;
	    foreach my $e (@route_list) {
		if ($e->[&StrassenNetz::ROUTE_ANGLE] >= 30 || $n == $#route_list) {
		    $route->add(@{$orig_route->path->[$e->[&StrassenNetz::ROUTE_ARRAYINX][0]]})
		}
	    } continue {
		$n++;
	    }
	}

	$route;
    }
}

# Simplify the route to contain max. $max points.
# Return a path list (like the path_list method).
sub path_list_max {
    my($self, $net, $max) = @_;
    my $best_route;
    foreach my $level (1 .. 2) {
	my $new_route = $self->simplify($net, $level);
	if ($new_route->path_list <= $max) {
	    return $new_route->path_list;
	} elsif (!defined $best_route ||
		 $new_route->path_list < $best_route->path_list) {
	    $best_route = $new_route;
	}
    }
    return $best_route->path_list;
}

sub add_trafficlights {
    my $self = shift;
    my $net  = shift; # ampel-Net
    return unless defined $net;
    my $ampeln = 0;
    foreach my $xy (@{ $self->path_s }) {
	$ampeln++ if (exists $net->{$xy});
    }
    $self->{Ampeln} = $ampeln;
}

sub scale {
    my($self, $scalefactor) = @_;
    foreach (@{$self->{PathCanvas}}) {
	$_->[0] *= $scalefactor;
	$_->[1] *= $scalefactor;
    }
}

# Argument: [x1,y1], [x2, y2]
sub _strecke {
    CORE::sqrt(sqr($_[0]->[0] - $_[1]->[0]) +
	       sqr($_[0]->[1] - $_[1]->[1]));
}

# Return "x,y"
sub _coord_as_string {
    my $coord = shift;
    "$coord->[0],$coord->[1]";
}

# $new_coord_system ist der Modulnamen-Teil nach Karte::
sub change_coord_system {
    my($self, $new_coord_system) = @_;
    require Karte;
    eval q{require Karte::} . $self->coord_system;
    eval q{require Karte::} . $new_coord_system;
    my $from_obj = eval q{$Karte::} . $self->coord_system . q{::obj};
    my $to_obj   = eval q{$Karte::} . $new_coord_system . q{::obj};
    foreach (@{$self->{PathCanvas}}) {
	($_->[0], $_->[1]) = $from_obj->map2map($to_obj, @$_);
    }
    $self->{CoordSystem} = $new_coord_system;
    # XXX transpose ändern?!
}

sub make_path_canvas {
    my $self = shift;
    die if !defined $self->transpose;
    $self->{PathCanvas} = [];
    foreach ($self->path_list) {
	push @{$self->{PathCanvas}}, [$self->transpose(@$_)];
    }
}

sub make_new {
    my $self = shift;
    if (@{$self->{Path}}) {
	$self->{From} = _coord_as_string($self->{Path}[0]);
	$self->{To}   = _coord_as_string($self->{Path}{$#{$self->{Path}}});
    }
    $self->make_path_canvas;
    $self->{Len} = 0;
    $self->{Penalty} = 0;
    my $i;
    for($i = 1; $i <= $#{$self->{Path}}; $i++) {
	$self->{Len} += _strecke($self->{Path}[$i-1],
				 $self->{Path}[$i]);
	# XXX Penalty fehlt!
	$self->{Ampeln}+=0; #  XXX, auch ab 0 anfangen!
    }
}

sub load_as_object {
    my($class, $file, %args) = @_;
    my $res = Route::load($file, undef, %args);
    $class->new_from_realcoords($res->{RealCoords}, -searchroutepoints => $res->{SearchRoutePoints});
}

sub save_object {
    my($self, $file) = @_;
    Route::save(
		-realcoords        => $self->_realcoords,
		-searchroutepoints => $self->_searchroutepoints,
		-file              => $file
	       );
}

######################################################################
# NON-OO FUNCTIONS

# Lädt eine Route ein und gibt @realcoords heraus.
sub load {
    my($file, undef, %args) = @_; # 2nd argument used to be the "context", but is not used anymore

    my @realcoords;
    my @search_route_points;

    my $ret;

    my $matching_type;

    TRY: {
	my %gps_args = (-fuzzy => $args{-fuzzy});
	require GPS;
	foreach my $gps (GPS->all()) {
	    my $check = 0;
	    eval {
		warn "Magic check for $gps...\n" if ($main::verbose && $main::verbose >= 2);
		my $mod = GPS->preload($gps);
		if ($mod->check($file, %gps_args)) {
		    warn "Trying $mod...\n" if ($main::verbose);
		    @realcoords = $mod->convert_to_route($file, %gps_args);
		    $check = 1;
		}
	    }; warn $@ if $@;
	    if ($check) {
		$matching_type = $gps;
		last TRY;
	    }
	}

	open my $F, $file
	    or die "Die Datei $file kann nicht geöffnet werden: $!";
	my $line = <$F>;

	my $check_sub = sub {
	    my $no_do = shift;

	    if ($line =~ /^[^\t]*\t\S+ .*\d,[-+]?\d/) { # prefixe werden nicht erkannt
		# eine Strassen-Datei
		$ret = {
			IsStrFile => 1,
			Type => "bbd",
		       };
		return;
	    } elsif (!$no_do) {
		undef $coords_ref;
		undef $realcoords_ref;
		undef $search_route_points_ref;

		require Safe;
		my $compartment = new Safe;
		$compartment->share(qw($realcoords_ref
				       $coords_ref
				       $search_route_points_ref
				      ));
		# XXX Ugly hack following: somehow Devel::Cover and
		# Safe don't play well together. So I simply turn off
		# Safe.pm if Devel::Cover usage is detected...
		if ($Devel::Cover::VERSION) {
		    do $file;
		} else {
		    $compartment->rdo($file);
		}

		die "Die Datei <$file> enthält keine Route."
		    if (!defined $realcoords_ref);

		@realcoords = @$realcoords_ref;
		if (defined $coords_ref) {
		    warn "Achtung: <$file> enthält altes Routen-Format.\n".
			"Koordinaten können verschoben sein!\n";
		}
		if (defined $search_route_points_ref) {
		    @search_route_points = @$search_route_points_ref;
		} else {
		    @search_route_points =
			([join(",",@{ $realcoords[0] }), POINT_MANUELL],
			 [join(",",@{ $realcoords[-1] }), POINT_MANUELL]);
		}

		$matching_type = "bbr";
	    } elsif ($no_do) {
		die;
	    }
	};

	if ($args{'-fuzzy'}) {
	    eval {
		$check_sub->();
	    };
	    if ($@) {
		while(<$F>) {
		    $line = $_;
		    eval {
			$check_sub->('nodo');
		    };
		    last if (!$@ || $ret);
		}
	    }
	} else {
	    $check_sub->();
	}

	close $F;
    }

    if ($ret) {
	return $ret;
    }

    +{
      RealCoords        => \@realcoords,
      SearchRoutePoints => \@search_route_points,
      Type              => $matching_type,
     };
}

sub save {
    my(%args) = @_;
    my $obj = delete $args{-object}; # the same as the return value of load
    if ($obj) {
	$args{-realcoords} = $obj->{RealCoords};
	$args{-searchroutepoints} = $obj->{SearchRoutePoints};
    }
    die "-file?"       if !$args{-file};
    die "-realcoords?" if !$args{-realcoords};
    $args{-searchroutepoints} = [] if !$args{-searchroutepoints};

    my $SAVE;
    if (!open($SAVE, ">$args{-file}")) {
	die "Die Datei <$args{-file}> kann nicht geschrieben werden ($!)\n";
    }
    print $SAVE "#BBBike route\n";
    eval {
	require Data::Dumper;
	$Data::Dumper::Indent = 0;
	print $SAVE Data::Dumper->Dump([$args{-realcoords},
				       $args{-searchroutepoints},
				      ],
				      ['realcoords_ref',
				       'search_route_points_ref',
				      ]);
    };
    if ($@) {
	print $SAVE
	    "$realcoords_ref = [",
		join(",", map { "[".join(",", @$_)."]" }
		          @{ $args{-realcoords} }),
	     "];\n",
	     "$search_route_points_ref = [",
		 join(",", map { "[".join(",", @$_)."]" }
		          @{ $args{-searchroutepoints} }),
	     "];\n";
    }
    close $SAVE;
}

1;
