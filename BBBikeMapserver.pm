#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: BBBikeMapserver.pm,v 1.5 2003/01/02 20:53:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# convert from bbbike to mapserver

package BBBikeMapserver;
use strict;
use File::Basename;

sub new {
    my($class, %args) = @_;
    my $self = bless {}, $class;
    $self->{TmpDir} = $args{-tmpdir} || die "-tmpdir argument is missing";
    $self;
}

sub new_from_cgi {
    my($class, $q, %args) = @_;
    my $self = $class->new(%args);
    my(@c) = split /!/, $q->param("coords");
    $self->{Coords} = \@c;
    $self->{CGI}    = $q;
    $self;
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

    my $orig_map_dir = "/home/e/eserte/src/bbbike/mapserver/brb";
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

	foreach my $scope (@scopes) {
	    $map_path = $path_for_scope->($scope, "$prefix-");

	    my $tmpfile2;
	    if ($externshape) {
		# convert bbd file to esri file
		$tmpfile2 = $self->{TmpDir} . "/bbbikems-${prefix}";
		# XXX do not hardcode path!!!
		system("/home/e/eserte/src/bbbike/miscsrc/bbd2esri",
		       $tmpfile1, "-o", $tmpfile2);
	    }

	    # copy brb.map to new map file
	    # XXX do not hardcode paths!!!
	    system("/home/e/eserte/src/bbbike/mapserver/brb/mkroutemap",
		   (defined $tmpfile2
		    ? (-routeshapefile => $tmpfile2)
		    : (-routecoords => join(",",@{$self->{Coords}}))
		   ),
		   -start => $self->{Coords}[0],
		   -goal => $self->{Coords}[-1],
		   -scope => $scope,
		   $orig_map_path,
		   $map_path);
	    # last $map_path is the start map
	}

	unlink $tmpfile1;
    }

    # send Location:
    # XXX do not hardcode URL and paths!!!
    my $cgi_prog = "/~eserte/cgi/mapserv.cgi";
    my $cgi_prog_esc = CGI::escape($cgi_prog);
    my $url = "http://www$cgi_prog";
    my($width, $height) = (6000, 6000); # meters
    my(@mapext) = $self->get_extents($width, $height);
    my $mapext_esc = CGI::escape(join(" ", @mapext));
    my $map_esc = CGI::escape($map_path);
    # XXX make configurable
    my @layers = qw(gewaesser flaechen grenzen bahn qualitaet radwege orte
		    handicap ampeln obst faehren);
    push @layers, "route" if $do_route;

    my $layers = join("&", map { "layer=$_" } @layers);
    my @param = ("zoomsize=2",
		 "mapext=$mapext_esc",
		 "map=$map_esc",
		 "program=$cgi_prog_esc",
		 $layers,
		);
    if (defined $args{-bbbikeurl}) {
	push @param, "bbbikeurl=" . CGI::escape($args{-bbbikeurl});
    }
    if (defined $args{-bbbikemail}) {
	push @param, "bbbikemail=" . CGI::escape($args{-bbbikemail});
    }
    print $self->{CGI}->redirect("$url?" . join("&", @param));
}

sub get_extents {
    my($self, $width, $height) = @_;
    my($x1,$y1) = split /,/, $self->{Coords}[0];
    if (@{$self->{Coords}} == 1) {
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
