#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: BBBikeMapserver.pm,v 1.7 2003/02/04 23:47:14 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
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
use CGI qw(-oldstyle_urls);

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
    $self->{CGI} = CGI->new;
    $self;
}

sub new_from_cgi {
    my($class, $q, %args) = @_;
    my $self = $class->new(%args);
    my(@c) = split /!/, $q->param("coords") if defined $q->param("coords");
    $self->{Coords} = \@c;
    $self->{CGI}    = $q;
    $self;
}

sub all_layers {
    qw(gewaesser flaechen grenzen bahn qualitaet radwege orte
       handicap ampeln obst faehren
       fragezeichen blocked sehenswuerdigkeit route);
}

sub read_config {
    my($self, $file) = @_;
    {
	package BBBikeMapserver::Config;
	do($file);
	die $@ if $@;
    }

    eval {
	$self->{MAPSERVER_DIR} = $BBBikeMapserver::Config::mapserver_dir || die "mapserver_dir\n";
	$self->{MAPSERVER_PROG_RELURL} = $BBBikeMapserver::Config::mapserver_prog_relurl || die "mapserver_prog_relurl\n";
	$self->{MAPSERVER_PROG_URL} = $BBBikeMapserver::Config::mapserver_prog_url || die "mapserver_prog_url\n";
	$self->{BBD2ESRI_PROG} = $BBBikeMapserver::Config::bbd2esri_prog || die "bbd2esri_prog\n";
    };
    if ($@) {
	die "Missing variables: $@";
    }
}

# -scope => city, region, wideregion, or all,...
#   all,... means all scopes, but starting with the "..." scope
# -externshape => bool: use external shape files. Internal features cannot
#   be queried with the map server, so generally better to set to true
# -route => bool: draw route (see new_from_cgi)
# -bbbikeurl => url: URL for bbbike.cgi
# -bbbikemail => mail: mail address for bbbike mails
sub start_mapserver {
    my($self, %args) = @_;
    my $scope = exists $args{-scope} ? $args{-scope} : 'city';
    my $externshape = exists $args{-externshape} ? $args{-externshape} : 0;

    my $do_route = exists $args{-route} ? $args{-route} : 1;

    my $orig_map_dir = $self->{MAPSERVER_DIR};
    my $path_for_scope = sub {
	my $scope = shift;
	my $prefix = shift || "";
	my $orig_map_path = ($scope eq 'wideregion'
			     ? "$orig_map_dir/${prefix}brb-wide.map"
			     : $scope eq 'city'
			     ? "$orig_map_dir/${prefix}brb-b.map"
			     : "$orig_map_dir/${prefix}brb.map"
			    );
	$orig_map_path;
    };
    my $orig_map_path = $path_for_scope->($scope);
    my $map_path = $orig_map_path;

    if ($do_route) {
	require Strassen::Util;
	require BBBikeUtil;
	# convert Coords to bbd file
	my $tmpfile1 = $self->{TmpDir} . "/bbbikems-$$.bbd";
	open(TMP1, ">$tmpfile1") or die "Can't write to $tmpfile1: $!";
	my $dist = 0;
	for my $i (1 .. $#{$self->{Coords}}) {
	    my $old_dist = $dist;
	    $dist += Strassen::Util::strecke_s(@{$self->{Coords}}[$i-1,$i]);
	    # XXX add maybe output of $comments_net->get_point_comment
	    print TMP1 BBBikeUtil::m2km($old_dist) . " - " . BBBikeUtil::m2km($dist) . "\tRoute " . join(" ", @{$self->{Coords}}[$i-1,$i]) . "\n";
	}
	close TMP1;

	# create a new unique id
	my $prefix = "xxx-" . time . "-" . $$;

	my @scopes;
	my $preferred_scope;
	if ($scope =~ /^all,(.*)/) {
	    my $preferred_scope = $1;
	    @scopes = qw(city region wideregion);
	    for my $i (0 .. $#scopes) {
		if ($scopes[$i] eq $preferred_scope) {
		    splice @scopes, $i, 1;
		    push @scopes, $preferred_scope;
		}
	    }
	} else {
	    @scopes = $scope;
	}

	my @marker_args;
	if ($args{-start}) {
	    @marker_args = (-start => $args{-start});
	    $self->{CenterTo} = $args{-start};
	} elsif (@{$self->{Coords}} > 1) {
	    @marker_args = (-start => $self->{Coords}[0],
			    -goal => $self->{Coords}[-1]);
	    $self->{CenterTo} = $self->{Coords}[0];
	} else {
	    @marker_args = (-markerpoint => $self->{Coords}[-1]);
	    $self->{CenterTo} = $self->{Coords}[0];
	}

	foreach my $scope (@scopes) {
	    $map_path = $path_for_scope->($scope, "$prefix-");

	    my $tmpfile2;
	    if ($externshape) {
		# convert bbd file to esri file
		$tmpfile2 = $self->{TmpDir} . "/bbbikems-${prefix}";
		my @cmd = ($self->{BBD2ESRI_PROG},
			   $tmpfile1, "-o", $tmpfile2);
		system @cmd;
		if ($?) {
		    die "Error while doing @cmd";
		}
	    }

	    # copy brb.map to new map file
	    my @cmd =
		($self->{MAPSERVER_DIR} . "/mkroutemap",
		 (defined $tmpfile2
		  ? (-routeshapefile => $tmpfile2)
		  : (-routecoords => join(",",@{$self->{Coords}}))
		 ),
		 @marker_args,
		 -scope => $scope,
		 $orig_map_path,
		 $map_path);
	    system @cmd;
	    if ($?) {
		die "Error while doing @cmd";
	    }
	    # last $map_path is the start map
	}

	unlink $tmpfile1;
    }

    # send Location:
    my $cgi_prog = $self->{MAPSERVER_PROG_RELURL};
#XXX del esc versions
#    my $cgi_prog_esc = CGI::escape($cgi_prog);
    my $url = $self->{MAPSERVER_PROG_URL};
    my($width, $height) = ($args{-width}||6000, $args{-height}||6000); # meters
    my(@mapext) = $self->get_extents($width, $height);
#    my $mapext_esc = CGI::escape(join(" ", @mapext));
#    my $map_esc = CGI::escape($map_path);
    my @layers;
    if ($args{-layers}) {
	@layers = @{ $args{-layers} };
    } else {
	@layers = grep { $_ ne 'route' || $do_route } all_layers();
    }
#    my $layers = join("&", map { "layer=$_" } @layers);
    my $q2 = CGI->new({});
    $q2->param(zoomsize => 2);
    $q2->param(mapext => join(" ", @mapext));
    $q2->param(map => $map_path);
    $q2->param(program => $cgi_prog);
    for (@layers) {
	$q2->param(layer => $_);
    }
    if (defined $args{-bbbikeurl}) {
#	push @param, "bbbikeurl=" . CGI::escape($args{-bbbikeurl});
	$q2->param(bbbikeurl => $args{-bbbikeurl});
    }
    if (defined $args{-bbbikemail}) {
#	push @param, "bbbikemail=" . CGI::escape($args{-bbbikemail});
	$q2->param(bbbikemail => $args{-bbbikemail});
    }
    if (defined $args{-start}) {
	$q2->param(startc => $args{-start});
    }
#    print $self->{CGI}->redirect("$url?" . join("&", @param));
    print $self->{CGI}->redirect("$url?" . $q2->query_string);
}

sub get_extents {
    my($self, $width, $height) = @_;
    my $center_to = $self->{CenterTo};
    if (!defined $center_to) {
	if (!$self->{Coords} || !$self->{Coords}[0]) {
	    # Default is Brandenburger Tor, do not hardcode XXX
	    $center_to = ["8593,12243"];
	} else {
	    $center_to = $self->{Coords}[0];
	}
    }
    my($x1,$y1) = split /,/, $center_to;
    if (!$self->{Coords} || @{$self->{Coords}} <= 1) {
	($x1-$width/2, $y1-$height/2, $x1+$width/2, $y1+$height/2);
    } else {
	my($x2,$y2) = split /,/, $self->{Coords}[-1];

	my $airx = 100;
	my $airy = 100;
	my($xdelta, $ydelta) = (0, 0);
	if ($x1-$x2 > $width/2) { $xdelta -= $width/2 - $airx }
	if ($x2-$x1 > $width/2) { $xdelta += $width/2 - $airx }
	if ($y1-$y2 > $height/2) { $ydelta -= $height/2 - $airy }
	if ($y2-$y1 > $height/2) { $ydelta += $height/2 - $airy }

	($x1 - $width/2 + $xdelta, $y1 - $height/2 + $ydelta,
	 $x1 + $width/2 + $xdelta, $y1 + $height/2 + $ydelta,
	);
    }
}

1;

__END__
