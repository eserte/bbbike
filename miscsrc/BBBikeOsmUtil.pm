# -*- perl -*-

#
# $Id: BBBikeOsmUtil.pm,v 1.3 2009/01/17 23:51:56 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeOsmUtil;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use vars qw($osm_layer $osm_layer_area);

use Cwd qw(realpath);
use File::Basename qw(dirname);

use VectorUtil qw(enclosed_rectangle intersect_rectangles normalize_rectangle);

{
    # XXX
    package Strassen::Dummy;
    sub new { bless {}, shift }
    sub is_current { 1 } # dummy for reload XXX could remember visible files and really check modified date...
}

sub plot_visible_area {
    my $c = $main::c;
    my(@corners) = $c->get_corners;
    require Karte::Polar;
    require Karte::Standard;
    my($x0,$y0,$x1,$y1) = ($Karte::Polar::obj->standard2map(main::anti_transpose(@corners[0,1])), 
			   $Karte::Polar::obj->standard2map(main::anti_transpose(@corners[2,3])));
    ($x0,$y0,$x1,$y1) = normalize_rectangle($x0,$y0,$x1,$y1);
    my @osm_files = osm_files_in_grid($x0,$y0,$x1,$y1);
    plot_osm_files(\@osm_files);    
}

sub osm_files_in_grid {
    my($x0,$y0,$x1,$y1) = @_;

    my $osm_download_dir = dirname(dirname(realpath(__FILE__))) . "/misc/download/osm";
    my $berlin_dir = "$osm_download_dir/berlin";
    my @osm_files = glob("$berlin_dir/download_*.osm");
    if (!@osm_files) {
	die "No osm files in $berlin_dir found. Did you run downloadosm?\n";
    }

    my @res_files;

    for my $f (@osm_files) {
	my($fx0,$fy0,$fx1,$fy1) = $f =~ m{/download_(\d+\.\d+),(\d+\.\d+),(\d+\.\d+),(\d+\.\d+)\.osm$}; # XXX no support for south and west
	($fx0,$fy0,$fx1,$fy1) = normalize_rectangle($fx0,$fy0,$fx1,$fy1);
	if (_contains_rectangle($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1)) {
	    push @res_files, $f;
	}
    }

    @res_files;
}

sub plot_osm_files {
    my($osm_files) = @_;
    require XML::LibXML; # XXX too lazy for XML::LibXML::Reader, and
                         # this is also supposed to work for small
                         # files only
    require Karte::Polar;
    require Karte::Standard;
    my $c = $main::c;
    my $transpose = \&main::transpose;
    my $map_conv = sub {
	my($lon, $lat) = @_;
	my($x, $y) = $Karte::Polar::obj->map2standard($lon, $lat);
	$transpose->($x, $y);
    };

    if (!$osm_layer) {
	$osm_layer = main::next_free_layer();
	$osm_layer_area = $osm_layer . "-bg";
	$main::str_obj{$osm_layer} = Strassen::Dummy->new; # XXX just for the layer editor, not useful for anything else
	$main::str_draw{$osm_layer} = 1; # XXX also for layer editor
	$main::str_obj{$osm_layer_area} = Strassen::Dummy->new; # XXX just for the layer editor, not useful for anything else
	$main::str_draw{$osm_layer_area} = 1; # XXX also for layer editor
	main::add_to_stack($osm_layer, "before", "pp");
	main::add_to_stack($osm_layer_area, "before", "f");
	main::std_str_binding($osm_layer);
	main::std_str_binding($osm_layer_area);
	Hooks::get_hooks("after_new_layer")->execute;
    }

    my %node2ll;
    for my $osm_file (@$osm_files) {
	my $root = XML::LibXML->new->parse_file($osm_file)->documentElement;
	for my $node ($root->findnodes('/osm/node')) {
	    my $id = $node->getAttribute('id');
	    next if exists $node2ll{$id};
	    my $lat = $node->getAttribute('lat');
	    my $lon = $node->getAttribute('lon');
	    my($cx,$cy) = $map_conv->($lon,$lat);
	    $node2ll{$id} = "$cx,$cy";
	    my %tag;
	    for my $tag ($node->findnodes('./tag')) {
		$tag{$tag->getAttribute('k')} = $tag->getAttribute('v');
	    }
	    if (exists $tag{name}) {
		$c->createLine($cx,$cy,$cx,$cy,
			       -fill => '#800000',
			       -width => 4,
			       -capstyle => $main::capstyle_round,
			       -tags => [$osm_layer, $tag{name}, 'osm'],
			      );
	    }
	}
    }

    for my $osm_file (@$osm_files) {
	my $root = XML::LibXML->new->parse_file($osm_file)->documentElement;
	for my $way ($root->findnodes('/osm/way')) {
	    my $visible = $way->getAttribute('visible');
	    next if $visible && $visible eq 'false';
	    my @nodes = map { $_->textContent } $way->findnodes('./nd/@ref');
	    my %tag;
	    for my $tag ($way->findnodes('./tag')) {
		$tag{$tag->getAttribute('k')} = $tag->getAttribute('v');
	    }

	    my %item_args;
	    my %line_item_args;
	    # following some stuff which is not that interesting for BBBike editing
	    if ((exists $tag{'railway'} && $tag{'railway'} =~ m{^(?:abandoned|disused)$}) ||
		(exists $tag{'man_made'} && $tag{'man_made'} eq 'pipeline')
	       ) {
		$item_args{'-dash'} = '.  ';
	    } elsif (exists $tag{'power'}) {
		$item_args{'-dash'} = '.   ';
		$item_args{'-width'} = 1;
	    } elsif (exists $tag{'tunnel'}) {
		$item_args{'-dash'} = [10,2];
	    } elsif (exists $tag{'highway'} && $tag{'highway'} =~ m{^(footway|pedestrian|track|path|service|bridleway)$}) {
		$item_args{'-dash'} = '--'; # may be interesting, but distinguish it from "official" streets
	    } elsif (exists $tag{'highway'} && $tag{'highway'} =~ m{^(planned|construction)$}) {
		$item_args{'-dash'} = '.'; 
	    } elsif (exists $tag{'boundary'}) {
		$item_args{'-dash'} = '.-'; # looks like a boundary, n'est-ce pas?
	    }
	    if (exists $tag{'oneway'}) {
		if ($tag{'oneway'} eq '-1') {
		    $line_item_args{'-arrow'} = 'first';
		} elsif ($tag{'oneway'} =~ m{^(?:yes|true)$}) {
		    $line_item_args{'-arrow'} = 'last';
		}
	    }

	    my @coordlist = map { (split /,/, $node2ll{$_}) } @nodes;
	    if (@coordlist < 4) {
		warn "Not enough coords for way $tag{name}";
	    } else {
		my $tags = join(" ", map { "$_=$tag{$_}" } grep { $_ !~ m{^(name|created_by|source|url)$} } keys %tag);
		my @tags = ((exists $tag{name} ? $tag{name}.' ' : '') . $tags, 'osm');
		if ($nodes[0] eq $nodes[-1]) {
		    $c->createPolygon(@coordlist,
				      -fill => '#a0b0a0',
				      -outline => '#a06060',
				      %item_args,
				      -tags => [$osm_layer_area, @tags, ($tag{landuse} ? "osm-landuse" : ())],
				     );
		} else {
		    $c->createLine(@coordlist,
				   -fill => '#c05000',
				   -width => 2,
				   %item_args,
				   %line_item_args,
				   -tags => [$osm_layer, @tags],
				  );
		}
	    }
	}
    }

    $c->lower($osm_layer_area);
    $c->lower("osm-landuse"); # downmost
}

sub delete_osm_layer {
    $main::c->delete("osm");
}

sub _contains_rectangle {
    my($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1) = @_;
    return (enclosed_rectangle($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1) ||
	    enclosed_rectangle($fx0,$fy0,$fx1,$fy1, $x0,$y0,$x1,$y1) ||
	    intersect_rectangles($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1)
	   );
}

1;

__END__
