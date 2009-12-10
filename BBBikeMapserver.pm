#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: BBBikeMapserver.pm,v 1.40 2007/06/14 22:20:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003,2005 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# convert from bbbike to mapserver

package BBBikeMapserver;
use strict;
use File::Basename;
use CGI;

sub new {
    my($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{TmpDir} = $args{-tmpdir};
    if (!$self->{TmpDir}) {
	require File::Spec;
	$self->{TmpDir} = File::Spec->tmpdir();
    }
    if (!$self->{TmpDir}) {
	die "Can't set TmpDir";
    }
    CGI->import(qw(-oldstyle_urls)); # call as late as possible
    $self->{CGI} = CGI->new;
    $self;
}

sub new_from_cgi {
    my($class, $q, %args) = @_;
    my $self = $class->new(%args);
    my @c;
    if (defined $q->param("coords")) {
	for my $coords ($q->param("coords")) {
	    push @c, [ split /[!; ]/, $coords ];
	}
    }
    $self->{MultiCoords} = [@c];
    $self->{CGI}    = $q;
    $self->{DEBUG}  = $q->param("debug");
    if (defined $q->param("center")) {
	$self->{CenterTo} = $q->param("center");
    }
    $self;
}

sub get_bbox_for_scope {
    my($self, $scope) = @_;
    my $bbox = {'region'    => [-80800,-86200,108200,81600],
		'city'      => [-15700,-8800,37300,31300],
		'innercity' => [1887,6525,15337,16087],
		'potsdam'   => [-17562,-4800,-7200,2587],
	       }->{$scope};
    $bbox ? @$bbox : ();
}

sub get_bbox_string_for_scope {
    my($self, $scope) = @_;
    join(",", $self->get_bbox_for_scope($scope));
}

sub narrowest_scope {
    my($self, $x0,$y0, $x1,$y1) = @_;
    require VectorUtil;
    for my $scope ("innercity", "potsdam", "city", "region") {
	my @bbox = $self->get_bbox_for_scope($scope);
	if (VectorUtil::point_in_grid($x0,$y0,@bbox) &&
	    (!defined $x1 || VectorUtil::point_in_grid($x1,$y1,@bbox))
	   ) {
	    return $scope;
	}
    }
    "wideregion";
}

sub set_coords {
    my($self, $coords) = @_;
    if (!UNIVERSAL::isa($coords, "ARRAY")) {
	$self->{MultiCoords} = [[ $coords ]];
    } elsif (!UNIVERSAL::isa($coords->[0], "ARRAY")) {
	$self->{MultiCoords} = [ $coords ];
    } else {
	$self->{MultiCoords} = $coords;
    }
}

sub has_coords {
    my $self = shift;
    $self->{MultiCoords} && @{ $self->{MultiCoords} }
	&& @{ $self->{MultiCoords}[0] };
}

sub get_first_coord {
    my $self = shift;
    $self->{MultiCoords}[0][0];
}

sub get_last_coord {
    my $self = shift;
    $self->{MultiCoords}[-1][-1];
}

sub has_more_than_one_coord {
    my $self = shift;
    return 0 if !$self->{MultiCoords} || !@{ $self->{MultiCoords} };
    my $total = 0;
    for (@{ $self->{MultiCoords} }) {
	$total += @$_;
	return 1 if $total > 1;
    }
    0;
}

sub all_layers {
    qw(gewaesser flaechen grenzen bahn qualitaet radwege orte
       handicap ampeln obst faehren
       fragezeichen blocked sehenswuerdigkeit route
       comments_route);
}

sub read_config {
    my($self, $file, %args) = @_;
    my $lax = delete $args{'-lax'};
    die "Unhandled arguments: " . join(" ", %args) if %args;
    {
	package BBBikeMapserver::Config;
	do($file);
	die $@ if $@;
    }

    # cease -w
    if (0) {
	$BBBikeMapserver::Config::mapserver_dir	    = $BBBikeMapserver::Config::mapserver_dir;
	$BBBikeMapserver::Config::bbd2esri_prog	    = $BBBikeMapserver::Config::bbd2esri_prog;
	$BBBikeMapserver::Config::mapserver_prog_relurl = $BBBikeMapserver::Config::mapserver_prog_relurl;
	$BBBikeMapserver::Config::mapserver_prog_url    = $BBBikeMapserver::Config::mapserver_prog_url;
	$BBBikeMapserver::Config::mapserver_bin_dir	= $BBBikeMapserver::Config::mapserver_bin_dir;
	$BBBikeMapserver::Config::mapserver_cgi_bin_dir	= $BBBikeMapserver::Config::mapserver_cgi_bin_dir;
	$BBBikeMapserver::Config::mapserver_fonts_list  = $BBBikeMapserver::Config::mapserver_fonts_list;
    }

    my $die = sub {
	die @_ unless $lax;
	undef;
    };

    eval {
	$self->{MAPSERVER_DIR}	       = $BBBikeMapserver::Config::mapserver_dir || $die->("mapserver_dir\n");
	$self->{MAPSERVER_PROG_RELURL} = $BBBikeMapserver::Config::mapserver_prog_relurl || $die->("mapserver_prog_relurl\n");
	$self->{MAPSERVER_PROG_URL}    = $BBBikeMapserver::Config::mapserver_prog_url || $die->("mapserver_prog_url\n");
	$self->{BBD2ESRI_PROG}	       = $BBBikeMapserver::Config::bbd2esri_prog || $die->("bbd2esri_prog\n");
	$self->{MAPSERVER_BIN_DIR}     = $BBBikeMapserver::Config::mapserver_bin_dir; # this is optional
	$self->{MAPSERVER_CGI_BIN_DIR} = $BBBikeMapserver::Config::mapserver_cgi_bin_dir || $BBBikeMapserver::Config::mapserver_bin_dir; # this is optional
	$self->{MAPSERVER_FONTS_LIST}  = $BBBikeMapserver::Config::mapserver_fonts_list;
    };
    if ($@) {
	die "Missing variables in config file $file: $@";
    }
}

sub scope_by_map {
    my $map = shift;
    my $base = basename($map);
    if      ($base =~ /-wide.map$/) {
	return 'all,wideregion';
    } elsif ($base =~ /-b\.map$/) {
	return 'all,city';
    } elsif ($base =~ /-p\.map$/) {
	return 'all,region';
    } elsif ($base =~ /-inner-b\.map$/) {
	return 'all,city';
    } elsif ($base =~ /\.map$/) {
	return 'all,region';
    }
    undef;
}

# -scope => city, region, wideregion, or all,...
#   all,... means all scopes, but starting with the "..." scope
#   also: narrowest, needs also -mapext or center/start point
# -externshape => bool: use external shape files. Internal features cannot
#   be queried with the map server, so generally better to set to true
# -route => bool: draw route (see new_from_cgi)
# -bbbikeurl => url: URL for bbbike.cgi
# -bbbikemail => mail: mail address for bbbike mails
# -cookie => cookie: optional cookie generated by CGI::cookie()
# -passparams => bool: pass existing CGI params, but it's still possible to
#                      override params
# -layers => arrayref: layers to draw, otherwise draw passed layers (if any),
#		       otherwise draw a default set (all layers)
# -mapname => name: name of map, by default "brb"
# -mapext => "x y x y": map extents, otherwise use width and height around
#                       center or start point
# -width => int
# -height => int: set width and height of map extents in meters (by default
#                 6000m)
sub start_mapserver {
    my($self, %args) = @_;
    my $externshape = $args{'-externshape'} =
	exists $args{-externshape} ? $args{-externshape} : 0;
    my $do_route    = $args{'-route'} =
	exists $args{-route} ? $args{-route} : 1;
    my $pass        = $args{-passparams};
    my @mapext;
    if ($args{'-mapext'}) {
	@mapext = split /\s+/, $args{'-mapext'};
    }
    my $q = $self->{CGI}; # original CGI object

    if (!@mapext) {
	my($width, $height) = ($args{-width}||6000, $args{-height}||6000); # meters
	my @args;
	if (defined $args{-padx}) {
	    push @args, -padx => $args{-padx};
	}
	if (defined $args{-pady}) {
	    push @args, -pady => $args{-pady};
	}
	@mapext = $self->get_extents($width, $height, $args{-markerpoint}, @args);
    }
    $self->{MapExt} = \@mapext;

    if ($args{-scope} && $args{-scope} =~ /narrowest/) {
	my $scope = $self->narrowest_scope(@mapext);
	$args{-scope} =~ s/narrowest/$scope/;
    }

    if (!exists $args{-scope}) {
	if ($pass && defined $q->param("map")) {
	    $args{-scope} = scope_by_map($q->param("map"));
	}
	if (!exists $args{-scope}) {
	    $args{-scope} = 'city';
	}
    }
    my $scope       = $args{'-scope'};
    $self->{DEBUG}  = $args{'-debug'} if exists $args{'-debug'};

    my $map_path = $self->create_mapfile(%args);

    # send Location:
    my $cgi_prog = $self->{MAPSERVER_PROG_RELURL};
    my $url = $self->{MAPSERVER_PROG_URL};

    my $q2 = CGI->new({});
    if ($pass) {
	for my $param (qw(zoomsize program bbbikeurl bbbikemail)) {
	    $q2->param($param, $q->param($param))
		if defined $q->param($param);
	}
	if (defined $q->param("imgext")) {
	    $q2->param(mapext => $q->param("imgext"));
	}
    }

    my @layers;
    if ($args{-layers}) {
	@layers = @{ $args{-layers} };
    } elsif ($pass && $q->param("layer")) {
	@layers = $q->param("layer");
    } else {
	@layers = grep { $_ ne 'route' || $do_route } all_layers();
    }
    $q2->param(layer => @layers);

    $q2->param(zoomsize => 2)
	if !defined $q2->param("zoomsize");
    $q2->param(mapext => join(" ", @mapext))
	if !defined $q2->param("mapext");
    $q2->param(map => $map_path); # always set
    $q2->param(program => $cgi_prog)
	if !defined $q2->param("program");
    if (defined $args{-bbbikeurl}) {
	$q2->param(bbbikeurl => $args{-bbbikeurl})
	    if !defined $q2->param("bbbikeurl");
    }
    if (defined $args{-bbbikemail}) {
	$q2->param(bbbikemail => $args{-bbbikemail})
	    if !defined $q2->param("bbbikemail");
    }
    if (defined $args{-start}) {
	$q2->param(startc => $args{-start});
    }
    my @redirect_args = (-uri => "$url?" . $q2->query_string);
    if ($args{-cookie}) {
	push @redirect_args, -cookie => $args{-cookie};
    }
    print $self->{CGI}->redirect(@redirect_args);
}

sub create_mapfile {
    my($self, %args) = @_;
    my $do_route    = $args{-route};
    my $scope       = $args{-scope};
    my $externshape = $args{-externshape};
    my $mapname     = $args{-mapname} || "brb";

    my $orig_map_dir = $self->{MAPSERVER_DIR};
    my $path_for_scope = sub {
	my $scope = shift;
	my $prefix = shift || "";
	my $orig_map_path = 
	    ( $scope eq 'wideregion' ? "$orig_map_dir/${prefix}${mapname}-wide.map"
	    : $scope eq 'city'       ? "$orig_map_dir/${prefix}${mapname}-b.map"
	    : $scope eq 'innercity'  ? "$orig_map_dir/${prefix}${mapname}-inner-b.map"
	    : $scope eq 'potsdam'    ? "$orig_map_dir/${prefix}${mapname}-p.map"
	    :                          "$orig_map_dir/${prefix}${mapname}-brb.map"
	    );
	$orig_map_path;
    };
#    my $orig_map_path = $path_for_scope->($scope);
#    my $map_path = $orig_map_path;

    my $preferred_map_path;

    if ($do_route) {
	require Strassen::Util;
	require BBBikeUtil;
	# convert Coords to bbd file
	my $tmpfile1 = $self->{TmpDir} . "/bbbikems-$$.bbd";
	open(TMP1, ">$tmpfile1") or die "Can't write to $tmpfile1: $!";
	my $dist = 0;
	if ($self->{MultiCoords}) {
	    if (!$self->has_more_than_one_coord) {
		print TMP1 "\tRoute " . $self->get_first_coord . "\n";
	    } else {
		for my $line (@{ $self->{MultiCoords} }) {
		    my $old_dist = $dist;
		    for my $i (1 .. $#{$line}) {
			$dist += Strassen::Util::strecke_s(@{$line}[$i-1,$i]);
			# XXX add maybe output of $comments_net->get_point_comment
		    }
		    print TMP1 BBBikeUtil::m2km($old_dist) . " - " . BBBikeUtil::m2km($dist) . "\tRoute " . join(" ", @{$line}) . "\n";
		}
	    }
	}
	close TMP1;

	# create a new unique id
	my $prefix = "xxx-" . time . "-" . $$ . int(rand(100000));

	my @scopes;
	my $preferred_scope;
	if ($scope =~ /^all,(.*)/) {
	    $preferred_scope = $1;
	    @scopes = qw(city region wideregion innercity potsdam);
	    for my $i (0 .. $#scopes) {
		if ($scopes[$i] eq $preferred_scope) {
		    splice @scopes, $i, 1;
		    unshift @scopes, $preferred_scope;
		    last;
		}
	    }
	} else {
	    @scopes = $scope;
	}

	my @marker_args;
	if ($args{-center}) {
	    $self->{CenterTo} = $args{-center};
	}
	if ($args{-start}) {
	    @marker_args = (-start => $args{-start});
	    $self->{CenterTo} = $args{-start}
		unless defined $self->{CenterTo};
	} elsif ($self->has_more_than_one_coord) {
	    my $start = $self->get_first_coord;
	    @marker_args = (-start => $start,
			    -goal  => $self->get_last_coord,
			   );
	    $self->{CenterTo} = $start
		unless defined $self->{CenterTo};
	} elsif ($self->has_coords) { # exactly one coordinate?
	    @marker_args = (-markerpoint => $self->get_last_coord);
	    $self->{CenterTo} = $self->get_first_coord
		unless defined $self->{CenterTo};
	}
	if ($args{-markerpoint}) {
	    push @marker_args, -markerpoint => $args{-markerpoint};
	}

	my @title_args;
	if ($args{-titletext}) {
	    push @title_args, -titletext => $args{-titletext};
	    push @title_args, -titlepoint => join ",", @{$self->{MapExt}}[0, 1];
	}

	foreach my $scope (@scopes) {
	    my $orig_map_path = $path_for_scope->($scope);
	    my $map_path = $path_for_scope->($scope, "$prefix-");

	    if (!$preferred_map_path) {
		$preferred_map_path = $map_path;
	    }

	    my($tmpfh, $tmpfile2);
	    if ($externshape && -s $tmpfile1) {
		# convert bbd file to esri file
		require File::Temp;
		($tmpfh, $tmpfile2) = File::Temp::tempfile(UNLINK => 1);
		my @cmd = ($self->{BBD2ESRI_PROG},
			   $tmpfile1, "-o", $tmpfile2);
		warn "Cmd: @cmd" if $self->{DEBUG};
		system @cmd;
		if ($?) {
		    die "Error ($?) while doing @cmd";
		}
	    }

	    # copy brb.map to new map file
	    my @cmd =
		($self->{MAPSERVER_DIR} . "/mkroutemap",
		 (defined $tmpfile2
		  ? (-routeshapefile => $tmpfile2)
		  : (-routecoords => join(",", map { @$_ } @{$self->{MultiCoords}}))
		 ),
		 @marker_args,
		 @title_args,
		 (defined $scope && $scope ne "" ? (-scope => $scope) : ()),
		 $orig_map_path,
		 $map_path);
	    warn "Cmd: @cmd" if $self->{DEBUG};
	    system @cmd;
	    if ($?) {
		die "Error ($?) while doing @cmd";
	    }
	    # last $map_path is the start map
	}

	unlink $tmpfile1;
    }

    if (!$preferred_map_path) {
	$preferred_map_path = $path_for_scope->($scope);
    }

    $preferred_map_path;
}

sub get_extents {
    my($self, $width, $height, $center_to, %args) = @_;
    my $do_center = 0;
    if (!defined $center_to || $center_to eq "") {
	$center_to = $self->{CenterTo};
	$do_center = 1; # we really want to center to the specified point
    }
    if (!defined $center_to || $center_to eq "") {
	if (!$self->has_coords) {
	    # There should be a possibility to specify other
	    # Geography::* classes
	    require Geography::Berlin_DE;
	    $center_to = Geography::Berlin_DE->center;
	} else {
	    $center_to = $self->get_first_coord;
	}
    }
    my($x1,$y1) = split /,/, $center_to;
    if (!$self->has_more_than_one_coord || $do_center) {
	($x1-$width/2, $y1-$height/2, $x1+$width/2, $y1+$height/2);
    } else {
	my($x2,$y2) = split /,/, $self->{MultiCoords}[-1][-1];

	my $padx = defined $args{-padx} ? $args{-padx} : int($width/10);
	my $pady = defined $args{-pady} ? $args{-pady} : int($height/10);
	my($xdelta, $ydelta) = (0, 0);
	if ($x1-$x2 > $width/2) { $xdelta -= $width/2 - $padx }
	if ($x2-$x1 > $width/2) { $xdelta += $width/2 - $padx }
	if ($y1-$y2 > $height/2) { $ydelta -= $height/2 - $pady }
	if ($y2-$y1 > $height/2) { $ydelta += $height/2 - $pady }

	($x1 - $width/2 + $xdelta, $y1 - $height/2 + $ydelta,
	 $x1 + $width/2 + $xdelta, $y1 + $height/2 + $ydelta,
	);
    }
}

1;

__END__
