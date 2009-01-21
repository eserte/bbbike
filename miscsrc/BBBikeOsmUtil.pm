# -*- perl -*-

#
# $Id: BBBikeOsmUtil.pm,v 1.7 2009/01/21 23:34:24 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use vars qw($osm_layer $osm_layer_area %images $last_osm_file);

use Cwd qw(realpath);
use File::Basename qw(dirname);

use VectorUtil qw(enclosed_rectangle intersect_rectangles normalize_rectangle);

use vars qw($UNINTERESTING_TAGS);
$UNINTERESTING_TAGS = qr{^(name|created_by|source|url)$};

sub register {
    _create_images();
}

{
    # XXX
    package Strassen::Dummy;
    sub new { bless {}, shift }
    sub is_current { 1 } # dummy for reload XXX could remember visible files and really check modified date...
}

sub plot_visible_area {
    my($x0,$y0,$x1,$y1) = _get_visible_area();
    my @osm_files = osm_files_in_grid($x0,$y0,$x1,$y1);
    plot_osm_files(\@osm_files);    
}

sub download_and_plot_visible_area {
    my($x0,$y0,$x1,$y1) = _get_visible_area();
    require File::Temp;
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->agent("BBBike/$main::VERSION (BBBikeOsmUtil/$VERSION LWP/$LWP::VERSION");
    my(undef,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => ".osm");
    my $url = "http://www.openstreetmap.org/api/0.5/map?bbox=$x0,$y0,$x1,$y1";
    main::status_message("Download $url to $tmpfile...", "info");
    warn "Latest downloaded temporary .osm file is $tmpfile\n";
    main::IncBusy($main::top);
    eval {
	my $resp = $ua->get($url, ':content_file' => $tmpfile);
	if (!$resp->is_success) {
	    die "Could not download $url: " . $resp->status_line . "\n";
	}
	main::status_message("Download successful, now plotting $tmpfile...", "info"); $main::top->update;
	plot_osm_files([$tmpfile]);
	main::status_message("", "info");
    };
    my $err = $@;
    main::DecBusy($main::top);
    if ($err) {
	main::status_message($err, 'die');
    }

    if (defined $last_osm_file) {
	unlink $last_osm_file;
    }
    $last_osm_file = $tmpfile;
}

sub _get_visible_area {
    my $c = $main::c;
    my(@corners) = $c->get_corners;
    require Karte::Polar;
    require Karte::Standard;
    my($x0,$y0,$x1,$y1) = ($Karte::Polar::obj->standard2map(main::anti_transpose(@corners[0,1])), 
			   $Karte::Polar::obj->standard2map(main::anti_transpose(@corners[2,3])));
    normalize_rectangle($x0,$y0,$x1,$y1);
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
	$main::layer_name{$osm_layer} = "OpenStreetMap (fg)";
	$main::layer_name{$osm_layer_area} = "OpenStreetMap (bg)";
	$main::layer_icon{$osm_layer} = $images{OsmLogo};
	$main::layer_icon{$osm_layer_area} = $images{OsmLogo};
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
		my $uninteresting_tags = join(" ",
					      "user=" . $node->getAttribute("user"),
					      "timestamp=" . $node->getAttribute("timestamp"),
					      (map { "$_=$tag{$_}" } keys %tag)
					     );
		$c->createLine($cx,$cy,$cx,$cy,
			       -fill => '#800000',
			       -width => 4,
			       -capstyle => $main::capstyle_round,
			       -tags => [$osm_layer, $tag{name}, $uninteresting_tags, 'osm', 'osm-node-' . $id],
			      );
	    }
	}
    }

    for my $osm_file (@$osm_files) {
	my $root = XML::LibXML->new->parse_file($osm_file)->documentElement;
	for my $way ($root->findnodes('/osm/way')) {
	    my $visible = $way->getAttribute('visible');
	    next if $visible && $visible eq 'false';
	    my $id = $way->getAttribute('id');
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
		my $tags = join(" ", map { "$_=$tag{$_}" } grep { $_ !~ $UNINTERESTING_TAGS } keys %tag);
		my $uninteresting_tags = join(" ",
					      "user=" . $way->getAttribute("user"),
					      "timestamp=" . $way->getAttribute("timestamp"),
					      (map { "$_=$tag{$_}" } grep { $_ =~ $UNINTERESTING_TAGS } keys %tag)
					     );
		my @tags = ((exists $tag{name} ? $tag{name}.' ' : '') . $tags, $uninteresting_tags, 'osm', 'osm-way-' . $id);
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

sub _create_images {
    if (!defined $images{OsmLogo}) {
	# wget http://upload.wikimedia.org/wikipedia/commons/b/b0/Openstreetmap_logo.svg
	# convert  -geometry 16x16 Openstreetmap_logo.svg  Openstreetmap_logo.png
	$images{OsmLogo} = $main::top->Photo(-format => 'png',
					     -data => <<'EOF');
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
cF9sb2dvLnN2Z2nx98oAAAAASUVORK5CYII=
EOF
    }
}

# TODO:
# support for main::show_info to show way xml and history xml:
#  GET http://www.openstreetmap.org/api/0.5/way/22495210/history
#  GET http://www.openstreetmap.org/api/0.5/way/22495210

1;

__END__
