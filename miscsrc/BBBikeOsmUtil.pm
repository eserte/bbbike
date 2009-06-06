# -*- perl -*-

#
# $Id: BBBikeOsmUtil.pm,v 1.15 2009/01/27 19:11:28 eserte Exp eserte $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/);

use vars qw($osm_layer $osm_layer_area $osm_layer_landuse $osm_layer_cover
	    %images @cover_grids %seen_grids $last_osm_file $defer_restacking
	  );

use Cwd qw(realpath);
use File::Basename qw(dirname);

use VectorUtil qw(enclosed_rectangle intersect_rectangles normalize_rectangle);

use vars qw($UNINTERESTING_TAGS);
$UNINTERESTING_TAGS = qr{^(name|created_by|source|url)$};

my $osm_download_file_qr = qr{/download_(\d+\.\d+),(\d+\.\d+),(\d+\.\d+),(\d+\.\d+)\.osm(?:\.gz|\.bz2)?$}; # XXX no support for south and west

use vars qw($OSM_API_URL $OSM_FALLBACK_API_URL);
#$OSM_API_URL = "http://www.openstreetmap.org/api/0.5";
$OSM_API_URL = "http://www.openstreetmap.org/api/0.6";
$OSM_FALLBACK_API_URL = "http://www.informationfreeway.org/api/0.6";

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
    my($x0,$y0,$x1,$y1) = get_visible_area();
    my @osm_files = osm_files_in_grid($x0,$y0,$x1,$y1);
    if (@osm_files) {
	_filter_seen_grids(\@osm_files);
	if (@osm_files) {
	    local $defer_restacking = 1;
	    plot_osm_files(\@osm_files);
	    _mark_grids_as_seen(\@osm_files);
	    plot_osm_cover_by_files(\@osm_files);
	    main::restack();
	}
    } else {
	main::status_message("No OSM tiles available in visible area");
    }
}

sub mirror_and_plot_visible_area {
    my($x0,$y0,$x1,$y1) = get_visible_area();
    my @osm_files = osm_files_in_grid($x0,$y0,$x1,$y1);
    if (@osm_files) {
	_filter_seen_grids(\@osm_files);
	if (@osm_files) {
	    my $ua = _get_ua();
	    $main::progress->Init(-label => "Mirroring...", -visible => 1);
	    my $file_i = -1;
	    for my $file (@osm_files) {
		$file_i++;
		$main::progress->Update($file_i/@osm_files);
		if (do { local $^T = time; -M $file > 0.5 }) { # mirror at most every 12 hours once
		    if ($file !~ $osm_download_file_qr) {
			main::status_message("File '$file' does not have the expected pattern '$osm_download_file_qr'", "die");
		    }
		    my($this_x0,$this_y0,$this_x1,$this_y1) = ($1, $2, $3, $4);
		    my $url = "$OSM_API_URL/map?bbox=$this_x0,$this_y0,$this_x1,$this_y1";
		    main::status_message("Mirror $url ...", "info"); $main::top->update;
		    main::IncBusy($main::top);
		    eval {
			my $resp = $ua->mirror($url, $file);
			if (!$resp->is_success) {
			    die "Could not mirror $url: " . $resp->status_line . "\n";
			}
		    };
		    my $err = $@;
		    main::DecBusy($main::top);
		    if ($err) {
			main::status_message($err, 'die');
		    }
		}
	    }
	    main::status_message("Mirroring successful, now plotting...", "info"); $main::top->update;
	    local $defer_restacking = 1;
	    plot_osm_files(\@osm_files);    
	    _mark_grids_as_seen(\@osm_files);
	    plot_osm_cover_by_files(\@osm_files);
	    main::restack();
	    $main::progress->Finish;
	    main::status_message("", "info");
	}
    } else {
	main::status_message("No OSM tiles available in visible area");
    }
}

sub get_download_url {
    my($x0,$y0,$x1,$y1) = @_;
    my $url = "$OSM_API_URL/map?bbox=$x0,$y0,$x1,$y1";
    $url;
}

sub get_fallback_download_url {
    my($x0,$y0,$x1,$y1) = @_;
    my $url = "$OSM_FALLBACK_API_URL/map?bbox=$x0,$y0,$x1,$y1";
    $url;
}

sub download_and_plot_visible_area {
    my(%args) = @_;
    my $withfallback = delete $args{withfallback};
    die "Unhandled args: " . join(" ", %args) if %args;

    my($x0,$y0,$x1,$y1) = get_visible_area();
    my $url  = get_download_url($x0,$y0,$x1,$y1);
    my $url2 = get_fallback_download_url($x0,$y0,$x1,$y1);
    require File::Temp;
    my $ua = _get_ua();
    my(undef,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => ".osm");
    local $defer_restacking = 1;
    main::status_message("Download $url to $tmpfile...", "info");
    warn "Latest downloaded temporary .osm file is $tmpfile\n";
    main::IncBusy($main::top);
    eval {
	my $resp = $ua->get($url, ':content_file' => $tmpfile);
	if (!$resp->is_success) {
	    if ($withfallback) {
		my $resp2 = $ua->get($url2, ':content_file' => $tmpfile);
		if (!$resp->is_success) {
		    die "Could not download $url: " . $resp->status_line . " and $url2: " . $resp2->status_line . "\n";
		}
	    } else {
		die "Could not download $url: " . $resp->status_line . "\n";
	    }
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
    plot_osm_cover($x0,$y0,$x1,$y1);
    main::restack();
}

sub get_visible_area {
    my $c = $main::c;
    my(@corners) = $c->get_corners;
    require Karte::Polar;
    require Karte::Standard;
    my($x0,$y0,$x1,$y1) = ($Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(main::anti_transpose(@corners[0,1]))),
			   $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map(main::anti_transpose(@corners[2,3]))));
    normalize_rectangle($x0,$y0,$x1,$y1);
}

sub osm_files_in_grid {
    my($x0,$y0,$x1,$y1) = @_;

    my $osm_download_dir = dirname(dirname(realpath(__FILE__))) . "/misc/download/osm";
    my $berlin_dir = "$osm_download_dir/berlin";
    my @osm_files = glob("$berlin_dir/download_*.osm*");
    if (!@osm_files) {
	die "No osm files in $berlin_dir found. Did you run downloadosm?\n";
    }

    my @res_files;

    for my $f (@osm_files) {
	my($fx0,$fy0,$fx1,$fy1) = $f =~ $osm_download_file_qr;
	($fx0,$fy0,$fx1,$fy1) = normalize_rectangle($fx0,$fy0,$fx1,$fy1);
	if (_contains_rectangle($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1)) {
	    push @res_files, $f;
	}
    }

    @res_files;
}

sub _filter_seen_grids {
    my $osm_files_ref = shift;
    my @new_osm_files;
    for (@$osm_files_ref) {
	my($x0,$y0) = $_ =~ $osm_download_file_qr;
	if (!$seen_grids{"$x0,$y0"}) {
	    push @new_osm_files, $_;
	}
    }
    @$osm_files_ref = @new_osm_files;
}

sub _mark_grids_as_seen {
    my $osm_files_ref = shift;
    for (@$osm_files_ref) {
	my($x0,$y0) = $_ =~ $osm_download_file_qr;
	$seen_grids{"$x0,$y0"}++;
    }
}

sub plot_osm_files {
    my($osm_files) = @_;
    require XML::LibXML; # XXX too lazy for XML::LibXML::Reader, and
                         # this is also supposed to work for small
                         # files only
    my $c = $main::c;
    my $map_conv = _get_map_conv();

    if (!$osm_layer) {
	$osm_layer = main::next_free_layer();
	$osm_layer_area = $osm_layer . "-bg";
	$osm_layer_landuse = $osm_layer . "-landuse";
	$osm_layer_cover = $osm_layer . "-cover";
	for my $abk ($osm_layer, $osm_layer_area, $osm_layer_cover, $osm_layer_landuse) {
	    $main::str_obj{$abk} = Strassen::Dummy->new; # XXX just for the layer editor, not useful for anything else
	}
	$main::layer_name{$osm_layer} = "OpenStreetMap (fg)";
	$main::layer_name{$osm_layer_area} = "OpenStreetMap (bg)";
	$main::layer_name{$osm_layer_cover} = "OpenStreetMap (cover)";
	$main::layer_name{$osm_layer_landuse} = "OpenStreetMap (landuse)";
	$main::layer_icon{$osm_layer} = $images{OsmLogo};
	$main::layer_icon{$osm_layer_area} = $images{OsmLogo};
	$main::layer_icon{$osm_layer_cover} = $images{OsmLogo};
	$main::layer_icon{$osm_layer_landuse} = $images{OsmLogo};
	main::add_to_stack($osm_layer, "below", "pp");
	main::add_to_stack($osm_layer_area, "below", "f");
	main::add_to_stack($osm_layer_landuse, "lowermost", undef);
	main::add_to_stack($osm_layer_cover, "above", $osm_layer_landuse);
	main::std_str_binding($osm_layer);
	main::std_str_binding($osm_layer_area);
	main::std_str_binding($osm_layer_landuse);
    }

    if (!$main::str_draw{$osm_layer}) { # XXX just check this one, maybe not enough!
	for my $abk ($osm_layer, $osm_layer_area, $osm_layer_cover, $osm_layer_landuse) {
	    $main::str_draw{$abk} = 1; # XXX also for layer editor
	}
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
		my $k = $tag->getAttribute('k');
		my $v = $tag->getAttribute('v');
		$k = "<undef k>" if !defined $k;
		$v = "<undef v>" if !defined $v;
		$tag{$k} = $v;
	    }
	    if (exists $tag{name} || exists $tag{amenity}) {
		my $uninteresting_tags = join(" ",
					      "user=" . $node->getAttribute("user"),
					      "timestamp=" . $node->getAttribute("timestamp"),
					      (map { "$_=$tag{$_}" } keys %tag)
					     );
		$c->createLine($cx,$cy,$cx,$cy,
			       -fill => '#800000',
			       -width => 4,
			       -capstyle => $main::capstyle_round,
			       -tags => [$osm_layer, $tag{name}||$tag{amenity}, $uninteresting_tags, 'osm', 'osm-node-' . $id],
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
	    } elsif (exists $tag{'addr:interpolation'}) {
		$item_args{'-dash'} = '. ';
	    } elsif (exists $tag{'tunnel'}) {
		$item_args{'-dash'} = [10,2];
	    } elsif (exists $tag{'highway'} && $tag{'highway'} =~ m{^(footway|steps|pedestrian|track|path|service|bridleway)$}) {
		$item_args{'-dash'} = '--'; # may be interesting, but distinguish it from "official" streets
	    } elsif (exists $tag{'highway'} && $tag{'highway'} =~ m{^(planned|construction)$}) {
		$item_args{'-dash'} = '.'; 
	    } elsif (exists $tag{'boundary'}) {
		$item_args{'-dash'} = '.-'; # looks like a boundary, n'est-ce pas?
	    } elsif (exists $tag{'obsolete_boundary'}) {
		next;
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
					      "user=" . ($way->getAttribute("user")||"<undef>"),
					      "timestamp=" . ($way->getAttribute("timestamp")||"<undef>"),
					      (map { "$_=$tag{$_}" } grep { $_ =~ $UNINTERESTING_TAGS } keys %tag)
					     );
		my @tags = ((exists $tag{name} ? $tag{name}.' ' : '') . $tags, $uninteresting_tags, 'osm', 'osm-way-' . $id);
		my $is_area = (exists $tag{'area'} ? $tag{'area'} eq 'yes' :
			       exists $tag{'landuse'} ? 1 :
			       $nodes[0] eq $nodes[-1]
			      );
		if ($is_area) {
		    my $light_color = '#a0b0a0';
		    my $dark_color  = '#a06060';
		    if ((exists $tag{'natural'} && $tag{'natural'} eq 'water') ||
			(exists $tag{'waterway'})
		       ) {
			$light_color = '#a0a0b0';
			$dark_color = '#6060a0';
		    } elsif (exists $tag{'building'} && $tag{'building'} eq 'yes') {
			$light_color = '#b0a0b0';
			$dark_color = '#a060a0';
		    } elsif ((exists $tag{'amenity'} && $tag{'amenity'} eq 'parking') ||
			     (exists $tag{'highway'})
			    ) {
			$light_color = '#b0b2b2';
			$dark_color = '#707272';
		    }
		    $c->createPolygon(@coordlist,
				      -fill => $light_color,
				      -outline => $dark_color,
				      %item_args,
				      -tags => [$tag{landuse} ? $osm_layer_landuse : $osm_layer_area, @tags],
				     );
		} else {
		    my $color = '#c05000';
		    if ((exists $tag{'natural'} && $tag{'natural'} eq 'water') ||
			(exists $tag{'waterway'})
		       ) {
			$color = '#6060a0';
		    }
		    $c->createLine(@coordlist,
				   -fill => $color,
				   -width => 2,
				   %item_args,
				   %line_item_args,
				   -tags => [$osm_layer, @tags],
				  );
		}
	    }
	}
    }

    if (!$defer_restacking) {
	main::restack();
    }
}

sub plot_osm_cover {
    _plot_osm_cover_no_restack(@_);
    if (!$defer_restacking) {
	main::restack();
    }
}

sub _plot_osm_cover_no_restack {
    my($x0,$y0,$x1,$y1) = @_;
    my $c = $main::c;
    my $map_conv = _get_map_conv();
    $c->createRectangle($map_conv->($x0,$y0),
			$map_conv->($x1,$y1),
			-stipple => '@'.$FindBin::RealBin.'/images/stiplite.xbm',
			-fill => '#ffdead',
			-state => 'disabled', # no balloon interaction
			-tags => ['osm', $osm_layer_cover],
		       );
}

sub plot_osm_cover_by_files {
    my($osm_files_ref) = @_;
    for my $file (@$osm_files_ref) {
	if (my($x0,$y0,$x1,$y1) = $file =~ $osm_download_file_qr) {
	    push @cover_grids, [$x0, $y0, $x1, $y1];
	    #_plot_osm_cover_no_restack($x0,$y0,$x1,$y1); # old negative implementation
	} else {
	    warn "Unexpected: file '$file' does not match '$osm_download_file_qr', ignoring for cover plotting...";
	}
    }
    _draw_cover_grids(); # new positive implementation
    if (!$defer_restacking) {
	main::restack();
    }
}

sub delete_osm_layer {
    $main::c->delete("osm");
    for my $abk ($osm_layer, $osm_layer_area, $osm_layer_cover, $osm_layer_landuse) {
	$main::str_draw{$abk} = 0; # XXX also for layer editor
    }
    Hooks::get_hooks("after_delete_layer")->execute;
    @cover_grids = ();
    %seen_grids = ();
}

sub _contains_rectangle {
    my($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1) = @_;
    return (enclosed_rectangle($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1) ||
	    enclosed_rectangle($fx0,$fy0,$fx1,$fy1, $x0,$y0,$x1,$y1) ||
	    intersect_rectangles($x0,$y0,$x1,$y1, $fx0,$fy0,$fx1,$fy1)
	   );
}

sub _sort_cover_grids {
    @cover_grids = sort {
	my $h = $a->[0] <=> $b->[0];
	if ($h == 0) {
	    return $a->[1] <=> $b->[1];
	} else {
	    return $h;
	}
    } @cover_grids;
}

sub _draw_cover_grids {
    $main::c->delete($osm_layer_cover);
    return if !@cover_grids;
    _sort_cover_grids();
    use List::Util qw(reduce);
    use constant MARGIN_X => 0.05;
    use constant MARGIN_Y => 0.05;
    my $max_y = (reduce { $a->[1] > $b->[1] ? $a : $b } @cover_grids)->[1] + MARGIN_Y;
    my $min_y = (reduce { $a->[3] < $b->[3] ? $a : $b } @cover_grids)->[3] - MARGIN_Y;
    my @c = ([$cover_grids[0]->[0] - MARGIN_X,
	      $max_y,
	     ]);
    my $last_x;
    for my $i (0 .. $#cover_grids) {
	my $this_x = $cover_grids[$i]->[0];
	if (defined $last_x && $last_x != $this_x) {
	    push @c, [$last_x, $max_y];
	    undef $last_x;
	}
	if (!defined $last_x) {
	    push @c, [$this_x, $max_y];
	    $last_x = $this_x;
	}
	push @c, ([$this_x, $cover_grids[$i]->[3]],
		  [$cover_grids[$i]->[2], $cover_grids[$i]->[3]],
		  [$cover_grids[$i]->[2], $cover_grids[$i]->[1]],
		  [$this_x, $cover_grids[$i]->[1]],
		 );
    }
    push @c, [$last_x, $max_y];
    push @c, ([$cover_grids[-1]->[2] + MARGIN_X, $max_y],
	      [$cover_grids[-1]->[2] + MARGIN_X, $min_y],
	      [$cover_grids[0]->[0] - MARGIN_X, $min_y],
	      [$cover_grids[0]->[0] - MARGIN_X, $max_y],
	     );

    my $map_conv = _get_map_conv();
    @c = map { $map_conv->(@$_) } @c;
    $main::c->createPolygon(@c,
			    -stipple => '@'.$FindBin::RealBin.'/images/stiplite.xbm',
			    -fill => 'red',
			    -state => 'disabled',
			    -tags => ['osm', $osm_layer_cover],
			   );
    if (0) {
	# a debugging helper
	$main::c->createLine(@c,
			     -fill => "darkred",
			     -dash => '.   ',
			     -state => 'disabled',
			     -tags => ['osm', $osm_layer_cover],
			    );
    }
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

sub _get_ua {
    require LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    #$ua->agent($ua->agent . " BBBike/$main::VERSION BBBikeOsmUtil/$VERSION");
    $ua->default_headers->push_header("Accept-Encoding" => "gzip");
    $ua;
}

sub _get_map_conv {
    require Karte::Polar;
    require Karte::Standard;
    my $transpose = \&main::transpose;
    my $map_conv = sub {
	my($lon, $lat) = @_;
	my($x, $y) = $Karte::Polar::obj->map2standard($lon, $lat);
	$transpose->($x, $y);
    };
    $map_conv;
}

# TODO:
# support for main::show_info to show way xml and history xml:
#  GET http://www.openstreetmap.org/api/0.5/way/22495210/history
#  GET http://www.openstreetmap.org/api/0.5/way/22495210

1;

__END__
