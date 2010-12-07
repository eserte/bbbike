# -*- perl -*-

#
# $Id: SRTShortcuts.pm,v 1.83 2009/03/02 21:25:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): My shortcuts for BBBike
# Description (de): Meine Shortcuts für BBBike
package SRTShortcuts;
#use lib ("/home/slavenr/work2/bbbike", "/home/slavenr/work2/bbbike/lib"); # XXX for flymake
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

BEGIN {
    *M    = \&BBBikePlugin::M;
    *Mfmt = \&BBBikePlugin::Mfmt;
}

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.83 $ =~ /(\d+)\.(\d+)/);

use your qw(%MultiMap::images $BBBikeLazy::mode
	    %main::line_width %main::p_width %main::str_draw %main::p_draw
	    %main::p_obj
	    $main::lazy_plot %main::lazy_p %main::layer_active_color
	    %main::add_net
	    $main::newlayer_photo
	    @main::inslauf_selection $main::edit_normal_mode
	    $main::gps_waypoints $main::gps_waypointlength
	    $main::gps_waypointcharset $main::gps_needuniqueroutenumber
	    $main::zoom_loaded_route $main::center_loaded_route
	    $Karte::Berlinmap1996::obj $Karte::Polar::obj
	    $Tk::Config::xlib
	  );

my $bbbike_rootdir;
if (-e "$FindBin::RealBin/bbbike") {
    $bbbike_rootdir = $FindBin::RealBin;
} else {
    $bbbike_rootdir = "$ENV{HOME}/src/bbbike";
}
my $streets_track                    = "$bbbike_rootdir/tmp/streets.bbd";
my $acc_streets_track                = "$bbbike_rootdir/tmp/streets-accurate.bbd";
my $acc_cat_streets_track            = "$bbbike_rootdir/tmp/streets-accurate-categorized.bbd";
my $acc_cat_split_streets_track      = "$bbbike_rootdir/tmp/streets-accurate-categorized-split.bbd";
my %acc_cat_split_streets_byyear_track;
my @acc_cat_split_streets_years = (2008..2010);
for my $year (@acc_cat_split_streets_years) {
    $acc_cat_split_streets_byyear_track{$year} = "$bbbike_rootdir/tmp/streets-accurate-categorized-split-since$year.bbd";
}
my $other_tracks                     = "$bbbike_rootdir/tmp/other-tracks.bbd";

use vars qw($hm_layer);

use vars qw($show_situation_at_point_for_route);
use vars qw(%want_plot_type_file %layer_for_type_file);
use vars qw($want_winter_optimization);
$want_winter_optimization = '' if !defined $want_winter_optimization;

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button();
    add_keybindings();
    define_subs();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
    remove_keybindings();
    BBBikePlugin::remove_menu_button(__PACKAGE__."_menu");
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $b;
    $b = $mf->Label
	(-text => "Srt",
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "SRT Shortcuts")
	if $main::balloon;

    my $rare_or_old_menu = $mmf->Menu
	(-disabledforeground => "black",
	 -menuitems =>
	 [
	  [Button => 'GPS downloads (not on biokovo)',
	   -state => 'disabled',
	   -font => $main::font{'bold'},
	  ],
	  [Button => "Standard download all",
	   -command => sub { make_gps_target("download") },
	  ],
	  [Button => "Standard download trk only",
	   -command => sub { make_gps_target("download-trk") },
	  ],
	  [Button => "Standard download wpt only",
	   -command => sub { make_gps_target("download-wpt") },
	  ],
	  [Button => 'Not working anymore',
	   -state => 'disabled',
	   -font => $main::font{'bold'},
	  ],
	  [Button => "Edit with new GPS trk",
	   -command => sub {
	       require BBBikeEdit;
	       require BBBikeAdvanced;
	       require BBBikeLazy;
	       require File::Basename;
	       main::plot("str","s", -draw => 0);
	       #XXX del? main::switch_edit_berlin_mode();
	       main::bbbikelazy_clear();
	       main::bbbikelazy_setup();
	       
	       main::bbbikelazy_init();
	       add_new_layer("str", $streets_track);
	       
	       my $file = main::draw_gpsman_data($main::top);
	       if (defined $file) {
		   BBBikeEdit::edit_gps_track(File::Basename::basename($file));
		   BBBikeEdit::set_edit_gpsman_waypoint();
		   BBBikeEdit::editmenu($main::top);
	       } else {
		   main::status_message("No file from draw_gpsman_data", "warn");
	       }
	       main::plot('str','fz', -draw => 1);
	   }],
	 ]);

    my $do_compound = sub {
	my($text, $image) = @_;
	if ($Tk::VERSION >= 804) {
	    # Tk804 has native menu item compounds
	    if ($image) {
		($text, -image => $image, -compound => "left");
	    } else {
		if (!$SRTShortcuts::empty_image_16) {
		    $SRTShortcuts::empty_image_16 = $main::top->Photo(-data => <<EOF);
R0lGODlhEAAQAIAAAP///////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQBCgABACwA
AAAAEAAQAAACDoyPqcvtD6OctNqLsz4FADs=
EOF
		}
		($text, -image => $SRTShortcuts::empty_image_16, -compound => "left");
	    }
	} else {
	    ($text);
	}
    };

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Button => $do_compound->("Set penalty: unique matches (alltime)"),
	       -command => sub { set_penalty('tmp/unique-matches.bbd') },
	      ],
	      [Button => $do_compound->("Set penalty: unique matches (since 2008)"),
	       -command => sub { set_penalty('tmp/unique-matches-since2008.bbd') },
	      ],
	      [Button => $do_compound->("Set penalty: unique matches (since 2009)"),
	       -command => sub { set_penalty('tmp/unique-matches-since2009.bbd') },
	      ],
	      [Button => $do_compound->("Set penalty fragezeichen-outdoor-nextcheck"),
	       -command => sub { set_penalty_fragezeichen() },
	      ],
	      [Button => $do_compound->("Tracks in region"),
	       -command => sub { tracks_in_region() },
	      ],
	      [Button => $do_compound->("Update tracks and matches.bbd"),
	       -command => sub { make_gps_target("tracks tracks-accurate tracks-accurate-categorized unique-matches") },
	      ],
	      [Button => $do_compound->("Add streets-accurate-categorized-split.bbd"),
	       -command => sub {
		   add_any_streets_bbd($acc_cat_split_streets_track);
	       }
	      ],
	      (map {
		  my $year = $_;
		  [Button => $do_compound->("Add streets-accurate-categorized-split-since".$year.".bbd"),
		   -command => sub {
		       add_any_streets_bbd($acc_cat_split_streets_byyear_track{$year});
		   },
		  ]
	      } @acc_cat_split_streets_years
	      ),
	      [Cascade => $do_compound->("Add other streets...bbd"), -menuitems =>
	       [
		[Button => "Add streets.bbd (all GPS tracks)",
		 -command => sub {
		     add_any_streets_bbd($streets_track);
		 }
		],
		[Button => "Add streets-accurate.bbd (all accurate GPS tracks)",
		 -command => sub {
		     add_any_streets_bbd($acc_streets_track);
		 }
		],
		[Button => "Add streets-accurate-categorized.bbd",
		 -command => sub {
		     add_any_streets_bbd($acc_cat_streets_track);
		 }
		],
	       ],
	      ],
	      [Button => $do_compound->("Add other-tracks.bbd (other people's GPS tracks)"),
	       -command => sub {
		   add_any_streets_bbd($other_tracks);
	       }
	      ],
	      [Button => $do_compound->("Add points-all.bbd (all GPS trackpoints)"),
	       -command => sub {
		   my $f = "$bbbike_rootdir/tmp/points-all.bbd";
		   my $points_layer = add_new_layer("p", $f, Width => 20);
		   main::special_lower($points_layer . "-fg", 0);
	       }
	      ],
	      [Button => $do_compound->("Add points-symbols.bbd (with symbols)"),
	       -command => sub {
		   my $f = "$bbbike_rootdir/tmp/points-symbols.bbd";
		   my $points_layer = add_new_layer("p", $f, Width => 20);
		   main::special_lower($points_layer . "-fg", 0);
	       }
	      ],
	      [Cascade => $do_compound->('Add layer', $main::newlayer_photo), -menuitems =>
	       [
		layer_checkbutton('hm96.bbd (Höhenpunkte)', 'p',
				  "$bbbike_rootdir/misc/senat_b/hm96.bbd",
				  oncallback  => sub { $main::top->bind("<F12>"=> \&find_nearest_hoehe) },
				  offcallback => sub { $main::top->bind("<F12>"=> '') },
				 ),
		layer_checkbutton('Zebrastreifen', 'p',
				  (-e "$main::datadir/zebrastreifen"
				   ? "$main::datadir/zebrastreifen" # osm2bbd generated directories have it here
				   : "$bbbike_rootdir/misc/zebrastreifen" # the original Berlin data has it here
				  ),
				  method => 'add_new_nonlazy_layer', # lazy mode does not support bbd images yet
				 ),
		layer_checkbutton('Ortsschilder', 'p',
				  _maybe_orig_file("$main::datadir/ortsschilder"),
				  method => 'add_new_nonlazy_layer', # lazy mode does not support bbd images yet
				 ),
		layer_checkbutton('routing_helper', 'str',
				  _maybe_orig_file('routing_helper')),
		[Button => "gesperrt_car", -command => sub { add_new_nonlazy_maybe_orig_layer("sperre", "gesperrt_car") }],
## XXX no support for "sperre" type yet:
#		layer_checkbutton('gesperrt_cat', 'sperre',
#				  _maybe_orig_file('gesperrt_car')),
		layer_checkbutton('brunnels', 'str',
				  _maybe_orig_file("$main::datadir/brunnels")),
		layer_checkbutton('geocoded images', 'str',
				  "$ENV{HOME}/.bbbike/geocoded_images.bbd"),
		layer_checkbutton('fragezeichen-outdoor-nextcheck', 'str',
				  "$bbbike_rootdir/tmp/fragezeichen-outdoor-nextcheck.bbd"),
		layer_checkbutton('fragezeichen-indoor-nextcheck', 'str',
				  "$bbbike_rootdir/tmp/fragezeichen-indoor-nextcheck.bbd"),
		layer_checkbutton('fragezeichen-nextcheck', 'str',
				  "$bbbike_rootdir/tmp/fragezeichen-nextcheck.bbd"),
		layer_checkbutton('Unique matches', 'str',
				  "$bbbike_rootdir/tmp/unique-matches.bbd"),
		layer_checkbutton('Unique matches since 2008', 'str',
				  "$bbbike_rootdir/tmp/unique-matches-since2008.bbd"),
		layer_checkbutton('Unique matches since 2009', 'str',
				  "$bbbike_rootdir/tmp/unique-matches-since2009.bbd"),
		[Button => "Abdeckung",
		 -command => sub {
		     local $main::p_draw{'pp-all'} = 1;
		     add_new_layer("str", "$bbbike_rootdir/misc/abdeckung.bbd");
		 }
		],
		layer_checkbutton('Exits (ÖPNV)', 'str',
				  _maybe_orig_file("$main::datadir/exits")),
		layer_checkbutton('Kneipen/Cafes', 'str',
				  "$bbbike_rootdir/data_berlin_osm/kneipen"),
		layer_checkbutton('Restaurants', 'str',
				  "$bbbike_rootdir/data_berlin_osm/restaurants"),
	       ],
	      ],
	      [Cascade => $do_compound->('OSM Live data', $MultiMap::images{OpenStreetMap}), -menuitems =>
	       [
		[Button => "Display (and refresh) OSM tiles (Berlin)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area();
		 }],
		[Button => "Display (without refresh) OSM tiles (Berlin)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::plot_visible_area();
		 }],
		[Button => "Display (and refresh) OSM tiles (elsewhere)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area_constrained(refreshdays => 0.5);
		 }],
		[Button => "Display (without refresh) OSM tiles (elsewhere)",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::mirror_and_plot_visible_area_constrained(refreshdays => 999999);
		 }],
		[Button => "Download and display any OSM data",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::download_and_plot_visible_area(withfallback => 1);
		 }],
		[Button => "Delete OSM layer",
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::delete_osm_layer();
		 }],
		[Button => 'Show download URL',
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     my $url  = BBBikeOsmUtil::get_download_url(BBBikeOsmUtil::get_visible_area());
		     my $url2 =BBBikeOsmUtil::get_fallback_download_url(BBBikeOsmUtil::get_visible_area());
		     main::status_message("Official URL: $url\nFallback URL: $url2", "infodlg");
		 }],
		"-",
		[Button => 'Set Merkaartor Icon Style',
		 -command => sub {
		     _require_BBBikeOsmUtil();
		     BBBikeOsmUtil::choose_merkaartor_icon_style();
		 },
		],
	       ],
	      ],
	      [Cascade => $do_compound->('OSM-converted layer'), -menuitems =>
	       [
		do {
		    my @osm_layers = qw(building education motortraffic oepnv power unhandled);
		    my @menu_items = map {
			my $layer = $_;
			[Button => $layer, -command => sub { add_new_data_layer("str", "_$layer") }];
		    } @osm_layers;
		    push @menu_items, [Button => 'all of above',
				       -command => sub {
					   my @errors;
					   for my $layer (@osm_layers) {
					       eval { add_new_data_layer("str", "_$layer") };
					       push @errors, "$layer: $@" if $@;
					   }
					   if (@errors) {
					       main::status_message(join("\n", @errors), "die");
					   }
				       }];
		    @menu_items;
		},
	       ]
	      ],
	      [Cascade => $do_compound->('Berlin/Potsdam coords'), -menuitems =>
	       [
		[Button => "Add Berlin.coords.data",
		 -command => sub { add_coords_data("Berlin.coords.bbd") },
		],
# 		[Button => "Add Berlin.coords.data with labels",
# 		 -command => sub { add_coords_data("Berlin.coords.bbd", 1) },
# 		],
		[Button => "Add Berlin-by-citypart data",
		 -command => sub { choose_Berlin_by_data("$bbbike_rootdir/tmp/Berlin.coords-by-citypart") },
		],
		[Button => "Add Berlin-by-zip data",
		 -command => sub { choose_Berlin_by_data("$bbbike_rootdir/tmp/Berlin.coords-by-zip") },
		],
		[Button => "Add Potsdam.coords.data",
		 -command => sub { add_coords_data("Potsdam.coords.bbd") },
		],
# 		[Button => "Add Potsdam.coords.data with labels",
# 		 -command => sub { add_coords_data("Potsdam.coords.bbd", 1) },
# 		],
	       ]
	      ],
	      [Button => $do_compound->('VMZ'),
	       -command => sub { newvmz_process() },
	      ],
	      [Cascade => $do_compound->("Old VMZ/LBVS stuff"), -menuitems =>
	       [
		[Button => "Show recent VMZ diff (new version)",
		 -command => sub { show_new_vmz_diff() },
		],
		"-",
		[Button => $do_compound->('VMZ/LBVS lister'),
		 -command => sub { show_vmz_lbvs_files() },
		],
		"-",
		[Button => "Show recent VMZ diff",
		 -command => sub { show_vmz_diff() },
		],
		(map { [Button => "VMZ version $_", -command => [sub { show_vmz_diff($_[0]) }, $_] ] } (0 .. 5)),
		"-",
		[Button => "Show recent LBVS diff",
		 -command => sub { show_lbvs_diff() },
		],
		(map { [Button => "LBVS version $_", -command => [sub { show_lbvs_diff($_[0]) }, $_] ] } (0 .. 5)),
	       ],
	      ],
	      ($main::devel_host ? [Cascade => $do_compound->("Karte")] : ()),
	      [Button => $do_compound->("Mark Layer"),
	       -command => sub { mark_layer_dialog() },
	      ],
	      [Button => $do_compound->("Mark most recent Layer"),
	       -command => sub { mark_most_recent_layer() },
	      ],
	      [Button => $do_compound->("Current search in local bbbike.cgi"),
	       -command => sub { current_search_in_bbbike_cgi() },
	      ],
	      [Button => $do_compound->("Street name experiment"),
	       -command => sub { street_name_experiment() },
	      ],
	      [Button => $do_compound->("New GPS simplification"),
	       -command => sub { new_gps_simplification() },
	      ],
	      [Button => $do_compound->('Real street widths'),
	       -command => sub { real_street_widths() },
	      ],
	      [Button => $do_compound->('Search while type (Berlin/Potsdam streets)'),
	       -command => sub { show_bbbike_suggest_toplevel() },
	      ],
	      [Button => $do_compound->('Search while type (everything)'),
	       -command => sub { tk_suggest() },
	      ],
	      [Cascade => $do_compound->('Situation at point'), -menuitems =>
	       [
		[Button => 'For three points',
		 -command => sub { show_situation_at_point() },
		],
		[Checkbutton => 'When calculating routes',
		 -command => sub { toggle_situation_at_point_for_route() },
		 -variable => \$show_situation_at_point_for_route,
		],
	       ],
	      ],
	      [Button => $do_compound->("Load route"),
	       -command => sub { route_lister() },
	      ],
	      [Button => $do_compound->("GPS data viewer"),
	       -command => sub { gps_data_viewer() },
	      ],
	      [Button => $do_compound->("Set Garmin device defaults"),
	       -command => sub { garmin_devcap() },
	      ],
	      [Button => $do_compound->("Trafficlight circuit + GPS tracks"),
	       -command => sub {
		   require "$bbbike_rootdir/miscsrc/TrafficLightCircuitGPSTracking.pm";
		   TrafficLightCircuitGPSTracking::tk_gui($main::top);
	       },
	      ],
	      [Cascade => $do_compound->("Winter optimization"), -menuitems =>
	       [
		[Radiobutton => "Disable",
		 -variable => \$want_winter_optimization,
		 -value => '',
		 -command => sub {
		     do_winter_optimization(undef);
		 },
		],
		(
		 map {
		     if ($_ eq '-') {
			 '-';
		     } else {
			 my $winter_hardness = $_;
			 [Radiobutton => $winter_hardness,
			  -variable => \$want_winter_optimization,
			  -value => $winter_hardness,
			  -command => sub {
			      do_winter_optimization($winter_hardness);
			  },
			 ];
		     }
		 } qw(- XXX_busroute - snowy very_snowy dry_cold - grade1 grade2 grade3)
		),
	       ],
	      ],
	      "-",
	      [Cascade => $do_compound->("Rare or old"), -menu => $rare_or_old_menu],
	      "-",
	      [Button => $do_compound->("Delete this menu"),
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	     -title => "SRT Shortcuts",
	    );

#     if ($devel_host) {
# 	for my $keysym (qw(question slash ssharp)) { # all possible and impossible places for C-?
# 	    bind_nomod($top, "<Control-$keysym>" => sub { warn "? of @_" });
# $t->bind("<Control-slash>" => sub { warn "? of @_"; Tk->break });
# $t->bind("<Control-ssharp>" => sub { warn "? of @_"; Tk->break });


    my $menu = $mmf->Subwidget(__PACKAGE__ . "_menu_menu");
    $menu->configure(-disabledforeground => "black");
    if ($main::devel_host) {
	my $map_menuitem = $menu->index("Karte");
	$menu->entryconfigure($map_menuitem,
			      -menu => main::get_map_button_menu($menu));
    }
}

sub add_keybindings {
    # same like in Merkaartor
    $main::top->bind("<Control-D>" => sub {
			 _require_BBBikeOsmUtil();
			 BBBikeOsmUtil::mirror_and_plot_visible_area();
		     });
}

sub remove_keybindings {
    $main::top->bind("<Control-D>" => undef);
}

sub tracks_in_region {
    require BBBikeEdit;
    require BBBikeGPS;
    if (@main::coords != 2) {
	main::status_message("Expecting exactly two points forming a region", "die");
    }
    my @region_corners = map { @$_ } @main::coords;
    my $parse_tag = sub {
	my($tag) = @_;
	$tag =~ s{(\.trk)(?:\s+\((.*)\))?$}{$1}; # strip comment part
	my $comment = $2;
	($tag, $comment);
    };

    my %seen_track;
    my %file_to_comment;
    my @tracks = sort grep {
	if (!$seen_track{$_}) {
	    $seen_track{$_}++;
	    1;
	} else {
	    0;
	}
    } grep {
	/\.trk($|\s)/
    } map {
	my($file, $comment) = $parse_tag->(($main::c->gettags($_))[1]);
	if ($comment) {
	    $file_to_comment{$file}->{$comment}++;
	}
	$file;
    } $main::c->find(overlapping => @region_corners);
    @tracks = map {
	my @comments;
	if ($file_to_comment{$_}) {
	    @comments = keys %{ $file_to_comment{$_} };
	}
	if (@comments) {
	    $_ . " (" . join(", ", @comments) . ")";
	} else {
	    $_;
	}
    } @tracks;

    my $t = $main::top->Toplevel(-title => "Tracks in region");
    $t->transient($main::top) if $main::transient;
    my $lb = $t->Scrolled("Listbox",
			  -selectmode => 'multiple',
			  -scrollbars => "osoe",
			  -exportselection => 0,
			 )->pack(-fill => "both", -expand => 1);
    $lb->insert("end", @tracks);
    my %old_selection;
    my %index_to_layers;
    $lb->bind("<<ListboxSelect>>" => sub {
		  my %new_selection = map{($_,1)} $lb->curselection;
		  my @add = grep { !$old_selection{$_} } keys %new_selection;
		  my @del = grep { !$new_selection{$_} } keys %old_selection;
		  for my $index (@del) {
		      my @layers = @{ $index_to_layers{$index} || [] };
		      for my $layer (@layers) {
			  my($type, $abk) = split /-/, $layer;
			  main::delete_layer($abk);
		      }
		  }
		  my @errors;
		  for my $index (@add) {
		      my $base = $lb->get($index);
		      ($base, undef) = $parse_tag->($base);
		      my $file = BBBikeEdit::find_gpsman_file($base);
		      if (!$file) {
			  push @errors, M("Keine Datei zu $base gefunden");
			  next;
		      }
		      my %plotted_layer_info;
		      BBBikeGPS::do_draw_gpsman_data($main::top, $file,
						     -solidcoloring => 1,
						     -plottedlayerinfo => \%plotted_layer_info,
						    );
		      eval { mark_most_recent_layer() }; warn $@ if $@;
		      $index_to_layers{$index} = [keys %plotted_layer_info];
		  }
		  %old_selection = %new_selection;
		  if (@errors) {
		      main::status_message(join("\n", @errors));
		  }
	      });
    {
	my $f = $t->Frame->pack(qw(-fill x));
	my $cb = $f->Button(Name => "close",
			    -command => sub { $t->destroy })->pack(qw(-side left));
	$t->bind('<Escape>' => sub { $cb->invoke });
	$f->Button(-text => M("Liste speichern"),
		   -command => sub {
		       my $outfile = $t->getSaveFile;
		       if (defined $outfile) {
			   open my $ofh, ">", $outfile
			       or main::status_message(Mfmt("Kann auf %s nicht schreiben: %s", $outfile, $!), "die");
			   print $ofh join("\n", @tracks), "\n"
			       or die $!;
		       }
		       main::status_message(Mfmt("Die Datei %s wurde geschrieben", $outfile), "infodlg");
		   },
		  )->pack(qw(-side left));
    }
}

sub make_gps_target {
    my $rule = shift;
    if (fork == 0) {
	exec(qw(xterm -e sh -c),
	     'cd ' . $bbbike_rootdir . '/misc/gps_data && make ' . $rule . '; echo Ready; sleep 9999');
	die $!;
    }
}

sub add_new_data_layer {
    my($type, $file, %args) = @_;
    add_new_layer($type, _maybe_orig_file("$main::datadir/$file"));
}

# Width support for now only for p layers
sub add_new_layer {
    my($type, $file, %args) = @_;
    my $free_layer = main::next_free_layer($type);
    $main::line_width{$free_layer} = [(1)x6];
    if (exists $args{Width}) {
	$main::p_width{$free_layer} = $args{Width};
    }
    $layer_for_type_file{"$type $file"} = $free_layer;
    if (!$BBBikeLazy::mode) {
	require BBBikeLazy;
	BBBikeLazy::bbbikelazy_empty_setup();
	main::handle_global_directives($file, $free_layer);
	main::bbbikelazy_add_data($type, $free_layer, $file);
	main::bbbikelazy_init();
    } else {
	main::handle_global_directives($file, $free_layer);
	main::bbbikelazy_add_data($type, $free_layer, $file);
    }
    # XXX add_to_stack functionality gots destroyed by calling once the layer_editor, because it used special_raise for *all*. get rid of special_raise/lower!
    main::add_to_stack($free_layer, "before", "pp");
    Hooks::get_hooks("after_new_layer")->execute;
    $free_layer;
}

sub toggle_new_layer {
    my($type, $file, %args) = @_;
    my $method = delete $args{method} || 'add_new_layer';
    if (!$layer_for_type_file{"$type $file"}) {
	eval {
	    no strict 'refs';
	    &{$method}($type, $file, %args);
	};
	if ($@) {
	    $want_plot_type_file{"$type $file"} = 0;
	    main::status_message("Cannot toggle layer: $@", 'die');
	}
    } else {
	eval {
	    my $layer = $layer_for_type_file{"$type $file"};
	    delete $main::str_draw{$layer};
	    delete $main::p_draw{$layer};
	    if ($type eq 'p') {
		$main::c->delete($layer.'-fg');
		$main::c->delete($layer.'-img');
	    } else {
		$main::c->delete($layer);
	    }
	    delete $layer_for_type_file{"$type $file"};
	    BBBikeLazy::bbbikelazy_remove_data($type, $layer);
	};
	if ($@) {
	    $want_plot_type_file{"$type $file"} = 1;
	    main::status_message("Cannot toggle layer: $@", 'die');
	}
    }
}

sub layer_checkbutton {
    my($label, $type, $file, %args) = @_;
    my $oncallback  = delete $args{oncallback};
    my $offcallback = delete $args{offcallback};
    [Checkbutton => $label,
     -variable => "$type $file",
     -command => sub {
	 my $key = "$type $file";
	 my $layer = toggle_new_layer($type, $file);
	 if ($oncallback && $layer_for_type_file{"$key"}) {
	     $oncallback->($layer, $type, $file);
	 } elsif ($offcallback && !$layer_for_type_file{"$key"}) {
	     $offcallback->($layer, $type, $file);
	 }   
     },
    ];
}

sub add_new_nonlazy_maybe_orig_layer {
    my($type, $file, %args) = @_;
    add_new_nonlazy_layer($type, _maybe_orig_file($file), %args);
}

sub add_new_nonlazy_layer {
    my($type, $file, %args) = @_;
    require BBBikeAdvanced;
    local $main::lazy_plot = 0; # lazy mode does not support bbd images yet
    main::plot_additional_layer($type, $file, %args);
}

sub set_layer_highlightning {
    my $layer = shift;
    $main::layer_active_color{$layer} = 'red';
#     $main::layer_post_enter_command{$layer} = sub {
# 	#$main::c->raise("current")
# 	$name_tag = ($main::c->gettags("current"))[1];
# 	$main::c->
#     };
}

######################################################################
# VMZ/LBVS

# The "done" file which remembers what is already done.
use vars qw($vmz_lbvs_directory $vmz_lbvs_done_file);
$vmz_lbvs_directory = "$ENV{HOME}/cache/misc";
$vmz_lbvs_done_file = "$vmz_lbvs_directory/vmz_lbvs_done";

sub md5_file {
    my($file) = @_;
    require Digest::MD5;
    my $ctx = Digest::MD5->new;
    open my $fh, $file
	or die "Can't open $file: $!";
    $ctx->addfile($fh);
    my $digest = $ctx->hexdigest;
}

sub newvmz_process {
    my $bbd = "$vmz_lbvs_directory/diffnewvmz.bbd";
    rename $bbd, "$vmz_lbvs_directory/diffnewvmz.old.bbd";
    my @cmd = ($^X, "$bbbike_rootdir/miscsrc/VMZTool.pm",
	       "-oldstore", "$vmz_lbvs_directory/newvmz.yaml",
	       "-newstore", "$vmz_lbvs_directory/newvmz.new.yaml",
	       "-outbbd", $bbd,
	      );
    system(@cmd);
    if (!-s $bbd) {
	main::status_message("Error while running @cmd, no bbd file $bbd created", "die");
    }
    show_new_vmz_diff();
}

sub show_vmz_lbvs_files {
    require File::Basename;
    my $t = $main::top->Toplevel(-title => "VMZ/LBVS files");
    fill_vmz_lbvs_files($t);
}

sub fill_vmz_lbvs_files {
    my $t = shift;
    return if !Tk::Exists($t);
    $_->destroy for ($t->children);
    my @files;
    opendir my $DIRH, $vmz_lbvs_directory
	or die "Cannot open $vmz_lbvs_directory directory: $!";
    while(defined(my $f = readdir $DIRH)) {
	if ($f =~ m{^diff(lbvs|vmz)\.bbd(\.\d+)?$}) {
	    push @files, "$vmz_lbvs_directory/$f";
	}
    }
    my %files_undone = map {($_,1)} get_undone_files($vmz_lbvs_done_file, \@files);
    for my $file (sort @files) {
	$t->Button(-text => File::Basename::basename($file) . " (" . ($files_undone{$file} ? "UNDONE" : "DONE") . ")",
		   -foreground => $files_undone{$file} ? 'red' : 'DarkSeaGreen4',
		   ($files_undone{$file} ? (-font => $main::font{'bold'}) : ()),
		   -command => sub {
		       show_any_diff($file, ($file =~ m{lbvs} ? "lbvs" : "vmz"), $t);
		   },
		  )->pack(-fill => 'x', -anchor => 'w');
    }
}

sub _vmz_lbvs_splitter {
    my($line) = @_;
    my($type, $content, $id);
    if ($line =~ m{¦}) {
	# new style
	($type, $content, $id) = split /¦/, $line; # ignore everything after 3rd column
    } else {
	($type, $content) = split /:\s+/, $line, 2;
    }
    ($type, $content, $id);
}

sub _vmz_lbvs_columnwidths {
    (200, 900, 200);
}

sub show_vmz_diff {
    my($version) = @_;
    if (defined $version) { $version = ".$version" }
    show_any_diff("$vmz_lbvs_directory/diffvmz.bbd$version", "vmz");
}

sub show_lbvs_diff {
    my($version) = @_;
    unless ($main::str_draw{l}) {
	main::plot("str",'l', -draw => 1);
	main::make_net();
    }
    if (defined $version) { $version = ".$version" }
    show_any_diff("$vmz_lbvs_directory/difflbvs.bbd$version", "lbvs");
}

sub show_new_vmz_diff {
    my($version) = @_;
    unless ($main::str_draw{l}) {
	main::plot("str",'l', -draw => 1);
	main::make_net();
    }
    if (defined $version) { $version = ".$version" }
    show_any_diff("$vmz_lbvs_directory/diffnewvmz.bbd$version", "newvmz");
}

sub show_any_diff {
    my($file, $diff_type, $listener) = @_;
    # To pre-generate cache:
    # XXX make sure that only ONE check_bbbike_temp_blockings process
    # runs at a time...
    system("$bbbike_rootdir/miscsrc/check_bbbike_temp_blockings >/dev/null 2>&1 &");
    require BBBikeAdvanced;
    require File::Basename;
    # XXX note: still a race condition possible! Would be better to
    # open a filehandle and pass this to both the md5 calculation and
    # the plotting.
    my $digest = md5_file($file);
    my $abk = main::plot_additional_layer("str", $file);
    my $token = "chooseort-" . File::Basename::basename($file) . "-str";
    my $t = main::redisplay_top($main::top, $token, -title => $file);
    if (!$t) {
	# XXX delete_layer does not happen here. $abk is never recorded.
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    } else {
	$t->geometry($t->screenwidth-20 . "x" . 260 . "+0-20");
    }
    $t->OnDestroy(sub { main::delete_layer($abk) });
    {
	local $^T = time;
	$t->Label(-text => "Modtime: " . scalar(localtime((stat($file))[9])) .
		  sprintf " (%.1f days ago)", (-M $file)
		 )->pack(-anchor => "w");
    }
    my $f;
    my $hide_ignored;
    {
	my $ff = $t->Frame->pack(-fill => 'x');
	$ff->Checkbutton(-text => "Hide ignored and unchanged",
			 -variable => \$hide_ignored,
			 -command => sub {
			     my $hl = $f->Subwidget("Listbox");
			     if ($hide_ignored) {
				 for ($hl->info("children")) {
				     if ($hl->entrycget($_, "-text") =~ /(ignore|unchanged)/i) {
					 $hl->hide("entry", $_);
				     }
				 }
			     } else {
				 for ($hl->info("children")) {
				     $hl->show("entry", $_);
				 }
			     }
			 })->pack(-anchor => "w", -side => 'left');
	$ff->Button(-text => "Mark done",
		    -command => sub {
			my $ans = $t->messageBox(-message => "Mark file " . File::Basename::basename($file) . " as done?",
						 -type => "YesNo",
						 -icon => 'question',
						);
			if ($ans =~ m{yes}i) {
			    add_done_file($vmz_lbvs_done_file, $file, $digest);
			    if ($listener && Tk::Exists($listener)) {
				fill_vmz_lbvs_files($listener);
				$listener->raise;
			    }
			    if ($diff_type eq 'newvmz') {
				{
				    my @rename = ("$vmz_lbvs_directory/newvmz.yaml", "$vmz_lbvs_directory/newvmz.old.yaml");
				    rename $rename[0], $rename[1]
					or main::status_message("Cannot rename @rename: $!", "warn");
				}
				{
				    my @rename = ("$vmz_lbvs_directory/newvmz.new.yaml", "$vmz_lbvs_directory/newvmz.yaml");
				    rename $rename[0], $rename[1]
					or main::status_message("Cannot rename @rename: $!", "warn");
				}
				require File::Copy;
				require POSIX;
				my $today = POSIX::strftime("%Y%m%d", localtime);
				my @copy = ("$vmz_lbvs_directory/newvmz.yaml",
					    "$vmz_lbvs_directory/archive/newvmz-$today.yaml");
				File::Copy::copy(@copy)
					or main::status_message("Cannot copy @copy: $!", "warn");
			    }
			    $t->destroy;
			}
		    })->pack(-anchor => 'e', -side => 'right');
    }
    $f = $t->Frame->pack(-fill => "both", -expand => 1);
    main::choose_ort("str", $abk,
		     -splitter => \&_vmz_lbvs_splitter,
		     -columnwidths => [ _vmz_lbvs_columnwidths() ],
		     # XXX Maybe implement -infocallback (an info
		     # button in the choose_ort window) some time, but
		     # not that urgent
		     (0 && $diff_type eq 'lbvs' ? (-infocallback => sub {
						       my($w, %args) = @_;
						       $args{-file} = $file;
						       _lbvs_info_callback($w, %args);
						   }) : ()),
		     -container => $f,
		     -ondestroy => sub { $t->destroy },
		    );
}

sub _lbvs_info_callback {
    my($w, %args) = @_;
    my $index = $args{"-index"};
    my $file = $args{"-file"};
    my $info_file = $file . "-info";
    my $token = "lbvsinfo-$file";
    my $t = main::redisplay_top($main::top, $token, -title => M("Information"));
    if (!$t) {
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    }
    my $txt = $t->Scrolled("ROText", -scrollbars => "eos")->pack(qw(-fill both -expand 1));

    require DB_File;
    my $text = "No info for index $index in info file $info_file available.";
    if (tie my %info, "DB_File", $info_file, &Fcntl::O_RDONLY) {
	$text = $info{$index};
    }
    $txt->insert("end", $text);
}

sub load_digest_file {
    my $digest_file = shift;
    my $digest_done;
    if (-e $digest_file) {
	require Safe;
	my $c = Safe->new;
	$digest_done = $c->rdo($digest_file) || {};
    }
    $digest_done;
}

sub get_undone_files {
    my($digest_file, $files_ref) = @_;
    my $digest_done = load_digest_file($digest_file);
    my @files_undone;
    for my $file (@$files_ref) {
	my $digest = md5_file($file);
	if (!exists $digest_done->{$digest}) {
	    push @files_undone, $file;
	}
    }
    @files_undone;
}

sub add_done_file {
    my($digest_file, $file, $digest) = @_;
    my $digest_done = load_digest_file($digest_file);
    if (!defined $digest) {
	$digest = md5_file($file);
    }
    $digest_done->{$digest} = $file;
    require Data::Dumper;
    open my $ofh, ">", "$digest_file~"
	or die "Can't write to $digest_file~: $!";
    print $ofh Data::Dumper->new([$digest_done],[qw(digest_done)])->Indent(1)->Useqq(1)->Dump;
    close $ofh
	or die $!;
    rename "$digest_file~", $digest_file
	or die "Can't rename $digest_file~ to $digest_file: $!";
}

######################################################################

sub define_subs {
    package main;
    no warnings 'once';
    *show_info_ext = sub {
	my($c, @tags) = @_;
	#warn "$c - $tags[3] - @tags ";
	my $res;
	if (defined $tags[3] && $tags[3] =~ /^(\d{4}-\d{2}-\d{2})$/ &&
	    open(F, "$ENV{HOME}/private/docs/rad/radstat.data")) {
	    (my $date = $tags[3]) =~ s/-//g;
	    while(<F>) {
		if (index($_, $date) == 0) {
		    chomp;
		    $res = "Radtour:\n" . join "\n", split /\|/, $_;
		    $res =~ s//\n    /g;
		    last;
		}
	    }
	    close F;
	}
	$res;
    };
}

sub find_nearest_hoehe {
    my @inslauf_selection = @main::inslauf_selection;
    if (!@inslauf_selection) {
	main::status_message("No point in selection!", "warn");
	return;
    }
    if (@inslauf_selection > 1) {
	main::status_message("Multiple points in selection!", "warn");
	return;
    }
    my $xy = $Karte::Berlinmap1996::obj->map2standard_s($inslauf_selection[0]);
    my $nearest = $main::lazy_p{$hm_layer}->nearest_point($xy, FullReturn => 1);
    if (!$nearest) {
	main::status_message("No nearest point found", "warn");
	return;
    }
    my $obj = $nearest->{StreetObj};
    (my $elevation) = $obj->[Strassen::NAME()] =~ /^([+-]?\d+\.\d)/;
    my $selbuf = "$elevation\tX $inslauf_selection[0]\n";

    $main::c->SelectionHandle
	(sub {
	     my($offset, $maxbytes) = @_;
	     substr($selbuf, $offset, $maxbytes);
	 });
}

sub set_penalty {
    my $filefrag = shift;
    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 0;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/$filefrag";
    BBBikeEdit::build_bbd_penalty_for_search();
}

sub set_penalty_fragezeichen {
    $main::add_net{fz} = 1;
    main::change_net_type();

    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 1;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/tmp/fragezeichen-outdoor-nextcheck.bbd";
    BBBikeEdit::build_bbd_penalty_for_search();
}

# XXX $namedraw does not work
sub add_coords_data {
    my($file, $namedraw) = @_;
    require File::Spec;
    my $abs_file = File::Spec->file_name_is_absolute($file) ? $file : _maybe_orig_file("$bbbike_rootdir/tmp/$file");
    add_new_layer("p", $abs_file, NameDraw => $namedraw);
}

sub choose_Berlin_by_data {
    my($directory) = @_;
    require Encode;
    require File::Basename;
    require File::Glob;
    my $t = $main::top->Toplevel;
    my $lb = $t->Scrolled('Listbox', -scrollbars => "osoe")->pack(qw(-fill both -expand 1));
    $lb->insert("end", map { File::Basename::basename($_) } File::Glob::bsd_glob("$directory/*"));
    $lb->bind("<Double-1>" => sub {
		  my(@cursel) = $lb->curselection;
		  my $basename = $lb->get($cursel[0]);
		  $basename = Encode::encode("iso-8859-1", $basename);
		  add_coords_data("$directory/$basename");
	      });
}

sub add_any_streets_bbd {
    my $f = shift;
    my $layer = add_new_layer("str", _maybe_orig_file($f));
    set_layer_highlightning($layer);
    main::special_raise($layer, 0);
}

sub mark_layer_dialog {
    main::additional_layer_dialog
	    (-title => "Layer markieren",
	     -cb => \&mark_layer,
	     -token => 'mark_additional_layer',
	    );
}

sub mark_layer {
    my $abk = shift;
    my $s;
 TRY_LAYER: {
	$s = $main::str_obj{$abk};
	last TRY_LAYER if $s;
	if ($main::str_file{$abk}) {
	    $s = Strassen->new($main::str_file{$abk});
	    last TRY_LAYER if $s;
	}

	$s = $main::p_obj{$abk};
	last TRY_LAYER if $s;
	if ($main::p_file{$abk}) {
	    $s = Strassen->new($main::p_file{$abk});
	    last TRY_LAYER if $s;
	}
	main::status_message("Cannot get street or point object for <$abk>", "die");
    }
    my @mc;
    $s->init;
    while(1) {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	push @mc, [ map { [ main::transpose(split /,/) ] } @{ $r->[Strassen::COORDS()] }];
    }
    if (@mc) {
	main::mark_street(-coords => [@mc], -dont_scroll => 1, -dont_center => 1);
    } else {
	main::status_message("No points found in street object", "info");
    }
}

sub mark_most_recent_layer {
    mark_layer($main::most_recent_str_layer)
	if defined $main::most_recent_str_layer;
}

sub current_search_in_bbbike_cgi {
    if (@main::search_route_points < 2) {
	main::status_message("Not enough points", "die");
    }
    if (@main::search_route_points > 3) {
	main::status_message("Too many points, bbbike.cgi only supports one via", "die");
    }
    my $inx = 0;
    my($start, $via, $goal);
    $start = $main::search_route_points[$inx++]->[0];
    if (@main::search_route_points == 3) {
	$via = $main::search_route_points[$inx++]->[0];
    }
    $goal = $main::search_route_points[$inx]->[0];

    require CGI;
    my $qs = CGI->new({ startc => $start,
			($via ? (viac => $via) : ()),
			zielc => $goal,
			pref_seen => 1, # gelogen
		      })->query_string;
    my $url = "http://localhost/bbbike/cgi/bbbike.cgi?$qs";
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

# XXX BBBikeOsmUtil should probably behave like a plugin? or not?
sub _require_BBBikeOsmUtil {
    require Cwd; require File::Basename; local @INC = (@INC, Cwd::realpath(File::Basename::dirname(__FILE__)));
    require BBBikeOsmUtil;
    BBBikeOsmUtil::register();
}

sub _maybe_orig_file {
    my $file = shift;
    return $file if !$main::edit_normal_mode;
    require File::Spec;
    if (File::Spec->file_name_is_absolute($file)) {
	return $file.'-orig' if -f $file.'-orig';
	return $file;
    } else {
	# assume it exists, without checking
	return $file.'-orig';
    }
}

sub route_lister {
    require "$bbbike_rootdir/miscsrc/BBBikeRouteLister.pm";
    my $show_route = sub {
	my $file = shift;
	if (defined $file) {
	    local $main::zoom_loaded_route = 0; # not good for large routes
	    local $main::center_loaded_route = 1; # but this is OK
	    main::load_save_route(0, $file);
	}
    };
    my $file = BBBikeRouteLister->new($main::top, -browse => sub { $show_route->(shift) })->Show;
    $show_route->($file);
}

######################################################################
# Experiments
#

######################################################################
# Nice street labels
#
# currently only executable using
#    SRTShortcuts::street_name_experiment()
# in ptksh or using the SRTShortcuts menu
#
# Known problems:
# - Overlapping street labels
# - Tk's canvas does not deal correctly with rotated fonts, as the bbox
#   calculation is wrong. This is sometimes visible when scrolling or parts
#   of the canvas were obscured. Forcing a redisplay somehow helps.
# - Zooming does not force a recalculation of labels (possible solution:
#   see lazy drawing below)
# - Printing of rotated fonts does not work at all. Probably best is for
#   now to hide all street labels before printing and restore them after
# Minor problems:
# - The angle has to be normalized in 5° steps, otherwise the calculation would
#   take too long. Maybe a smaller angle could be used, or this restriction
#   removed completely with lazy drawing (see below)
# - Mathematical background/explanation for reversing street names is missing
# Improvement possibilities
# - Lazy drawing, and deleting of invisible parts. This would also help in
#   reducing the huge memory consumption in the Xorg server.
# - Splitting labels for long streets (e.g. "Oranienstr." -> "Oranien" "str.")
#   and putting the first part at the beginning and the second part at the end
#   (normal cartographic style)
# - Thicker streets, so labels fit into the streets
#
use constant LABELS_INSIDE_STREET => 1; # yes/no
use constant STREET_NAME_EXPERIMENT_DEBUGGING => 0; # yes/no
my %font_char_length;

{
my $street_name_experiment_preinit_already_warned;
# XXX This sub must currently be physically before
# street_name_experiment() (because of pi import)
sub street_name_experiment_preinit {
    require Tk::Config;
    require Strassen::Core;
    require Strassen::CoreHeavy;
    require Strassen::MultiStrassen;
    require Strassen::Strasse;
    require Strassen::Util;
    use BBBikeUtil qw(pi schnittwinkel sum);
    use VectorUtil qw(move_point_orthogonal);
    if ($Tk::Config::xlib !~ /-lXft\b/) {
	if (!$street_name_experiment_preinit_already_warned) {
	    main::status_message("Sorry, this experiment needs Tk with freetype support! Consider to recompile Tk with XFT=1", "die");
	    $street_name_experiment_preinit_already_warned = 1;
	} else {
	    die; # silently
	}
    }
}

# "pre-loop-globals"
my($delta_HH, $delta_N, $default_fontsize, $fontsize);
my $get_rot_matrix;
my($regular_font, $bold_font);
my $tag;
my($ascent, $descent);

# "strassen-object globals"
my $tag_label;

sub street_name_experiment {
    street_name_experiment_preinit();

    main::IncBusy($main::top);
    ## XXX progress bar does not work --- hiding of dependent canvas does not work
    #$main::progress->Init(-dependents => $main::c, -label => 'Street labels');
    eval {
	street_name_experiment_init();

	$main::c->delete($tag);

	for my $def ([Strassen->new("strassen"), "s-label"],
		     [Strassen->new("fragezeichen"), "s-label"],
		     [do {
			 my $potsdam_s;
			 my $ls = Strassen->new("landstrassen");
			 $ls->grepstreets(sub { $_->[Strassen::NAME()] =~ m{\Q(Potsdam)} });
		     }, "l-label"],
		    ) {
	    my($s, $tag_label) = @$def;
	    street_name_experiment_init_strassen($s, $tag_label);
	    $s->init;
	    #our $xxx=0;
	    #my $anzahl_eindeutig = $s->count; my $s_i = 0;
	    while(1) {
		# XXX progress stuff does not work anymore, since I am not using MultiStrassen anymore
		# XXX it didn't work before, either
		#$main::progress->Update($s_i/$anzahl_eindeutig) if ($s_i % 500 == 0);
	    #$xxx++;last if $xxx > 100;
		my $use_bold;
		my $rec = $s->next;
		my $cat = $rec->[Strassen::CAT()];
		next if $cat =~ m{::igndisp};
		my $c = $rec->[Strassen::COORDS()];
		last if !@$c;
		my $name = $rec->[Strassen::NAME()];
		$use_bold = 1 if $cat =~ m{^(H|HH|B)$};
		# The same street continued? Without interruptions?
		while (1) {
		    my $peek = $s->peek;
		    my $peek_c = $peek->[Strassen::COORDS()];
		    if (!@$peek_c ||
			!($peek->[Strassen::NAME()] eq $name &&
			  $peek_c->[0] eq $c->[-1])) {
			last;
		    }
		    push @$c, @{$peek_c}[1..$#$peek_c];
		    if (!$use_bold) {
			$use_bold = 1 if $peek->[Strassen::CAT()] =~ m{^(H|HH|B)$};
		    }
		    $s->next;
		}
		next if @$c < 2 || $c->[0] eq $c->[-1];

		street_name_experiment_one($name, $c, $use_bold);
	    }
	}
    };
    my $err = $@;
    #$main::progress->Finish;
    main::DecBusy($main::top);
    main::status_message($err, "die") if $err;
	
}

sub street_name_experiment_init {
    # half widths of street signatures
    $delta_HH = main::get_line_width('s-HH')/2;
    $delta_N  = main::get_line_width('s-N')/2;

    $default_fontsize = 12;	# default of sans
    $fontsize = ($main::scale > 7   ? 12   :
		 $main::scale > 5.5 ? 11.3 :
		 $main::scale > 4   ? 11   :
		 $main::scale > 3   ? 10.5 :
		 $main::scale > 2   ? 10   :
		 $main::scale > 1.3 ? 9    :
		                      8
		);

    # XXX Taken from Tk::RotFont
    # Erstellt eine Rotationsmatrix für freetype
    # XXX rot-Funktion auslagern (CanvasRotText)
    #use constant ANGLE_STEPS => 10;
    use constant ANGLE_STEPS => 5;
    $get_rot_matrix = sub {
	my($r, $size) = @_;
	$r = int(($r/pi)*((360+ANGLE_STEPS/2)/ANGLE_STEPS))/(360/ANGLE_STEPS)*pi; # ANGLE_STEPS°-Schritte erzwingen, um den X-Server zu entlasten
	if (abs($r - pi) < 0.1) {
	    $r = 3.2;
	} elsif (abs($r + pi) < 0.1) {
	    $r = -3.1;
	}
	my $mat;
	my $a1 = $size*cos($r);
	my $s1 = sin($r);
	foreach ($a1, $size*$s1, $size*-$s1, $a1) {
	    if ($mat) {
		$mat .= " ";
	    }
	    $mat .= $_;
	}
	'matrix=' . $mat;
    };

    ## The normal Vera font, usually
    $regular_font = "sans:size=$fontsize";
    $bold_font    = "sans:size=$fontsize:style=bold";
    ## A condensed font
    # $regular_font = "Nimbus Sans L:size=$fontsize:style=ReguCond";
    # $bold_font    = "Nimbus Sans L:size=$fontsize:style=BoldCond";

    $tag = "experiment-strname";

    my %font_metrics = $main::c->fontMetrics($regular_font); # assume bold metrics are the same
    ($ascent, $descent) = @font_metrics{qw(-ascent -descent)};
}

sub street_name_experiment_init_strassen {
    my(undef, $set_tag_label) = @_;
    $tag_label = $set_tag_label;
}

sub street_name_experiment_one {
    my($name, $c, $use_bold) = @_;
    return if !defined $name || $name eq ''; # may happen with osm data

    my($x1,$y1,$x2,$y2) = (main::transpose(split(/,/, $c->[0])),
			   main::transpose(split(/,/, $c->[-1]))
			  );
    my $using_font = $use_bold ? $bold_font : $regular_font;
    $font_char_length{$using_font} ||= {};
    my $char_length = $font_char_length{$using_font};
    $name = Strasse::strip_bezirk($name);
    $name =~ s{:.*}{};	    # strip fragezeichen/qualitaet description
    my $street_length = Strassen::Util::strecke([$x1,$y1], [$x2,$y2]);
    # fontMeasure is slow, so cache single character width, at the
    # expense of accuracy (kerning!)
    my $text_length = sum map { $char_length->{$_} ||= $main::c->fontMeasure($using_font, $_) } split //, $name;
    if ($street_length < $text_length) {
	if (STREET_NAME_EXPERIMENT_DEBUGGING) {
	    warn "too long: '$name', street length is $street_length\n";
	}
	return;
    }

    # find center of polyline
    my $etappe_length = $street_length;
    {
	# Note: working with untransposed coords here
	my $real_street_length = 0;
	my @c = map { [split /,/] } @$c;
	for my $i (1 .. $#c) {
	    $real_street_length += Strassen::Util::strecke($c[$i-1], $c[$i]);
	}
	my $current_street_length = 0;
	for my $i (1 .. $#c) {
	    $current_street_length += Strassen::Util::strecke($c[$i-1], $c[$i]);
	    if ($current_street_length > $real_street_length/2) {
		# Look back and forth for additional lines which
		# does not change the angle of the middle line
		# (only by a tolerant value). This was an bad
		# example: Kochstr. (in Kreuzberg). This may also
		# lead to worse results, see Apostel-Paulus-Str.
		use constant TOLERANT_ANGLE => 3/180*pi;
		my $begin_i = $i-1;
		my $end_i = $i;
		while ($end_i < $#c) {
		    my($deg, undef) = schnittwinkel(@{ $c[$i-1] }, @{ $c[$i] }, @{ $c[$end_i+1] });
		    last if ($deg > TOLERANT_ANGLE);
		    $end_i++;
		}
		while ($begin_i > 0) {
		    my($deg, undef) = schnittwinkel(@{ $c[$begin_i-1] }, @{ $c[$i-1] }, @{ $c[$i] });
		    last if ($deg > TOLERANT_ANGLE);
		    $begin_i--;
		}
		($x1,$y1,$x2,$y2) = (main::transpose(@{ $c[$begin_i] }),
				     main::transpose(@{ $c[$end_i] })
				    );
		$etappe_length = Strassen::Util::strecke([$x1,$y1], [$x2,$y2]);
		last;
	    }
	}
    }

    return if !$etappe_length;

    my $r = -atan2($y2-$y1, $x2-$x1);
    if (1) {
	$r = 2*pi - $r;
    }
    if (($r > pi && $r <= pi*1.5) ||
	($r > 2.5*pi && $r <= pi*3)) { # XXXX auf dem Kopf stehend! XXX mathematisch herausfinden, nicht empirisch!
	($x1,$y1,$x2,$y2) = ($x2,$y2,$x1,$y1);
	$r = -atan2($y2-$y1, $x2-$x1);
	if (1) {
	    $r = 2*pi - $r;
	}
    }
    my $matrix = $get_rot_matrix->($r, $fontsize/$default_fontsize);
    #my $deg = $r*180/pi; print STDERR "$name $deg $matrix\n";

    my $fac = ($etappe_length-$text_length)/(2*$etappe_length);
    my($xm,$ym) = (int(($x2-$x1)*$fac+$x1), int(($y2-$y1)*$fac+$y1));
    if (LABELS_INSIDE_STREET) {
	# Street labels should be on the street, European style! So
	# move the labels a little bit towards the center of the
	# street. On the other hand, this may obscure additional map
	# signatures (lik equality, vorfahrt etc.).
	my $delta = $descent + $ascent/2 - ($use_bold ? $delta_HH : $delta_N);
	($xm,$ym) = move_point_orthogonal($xm,$ym,$x1,$y1,$x2,$y2,$delta);
    }
    $main::c->createText($xm,$ym,
			 -text => $name,
			 -anchor => "sw",
			 -font => $using_font . ":$matrix",
			 -state => "disabled",
			 -tags => [$tag, $tag_label],
			);
    if (STREET_NAME_EXPERIMENT_DEBUGGING) {
	$main::c->createLine($x1,$y1,$x2,$y2, -arrow => "last", -tags => $tag);
	$main::c->createLine($xm,$ym,$xm,$ym+1, -capstyle=>"round",-width=>4, -tags => $tag);
    }
}
} # scope for street_name_experiment* functions

######################################################################
# GPS data viewer
sub gps_data_viewer {
    my($gps_file) = @_;

    require BBBikeEdit;
    require BBBikeUtil;
    require GPS::GpsmanData::Any;
    require GPS::GpsmanData::Tk;
    require Karte::Polar;
    require Tk::PathEntry;
    my $t = $main::top->Toplevel(-title => "GPS data viewer");
    $main::toplevel{gps_data_viewer} = $t; # XXX what about an existing GPS data viewer?
    $t->geometry("1000x400");
    my $gps_view;
    my $gps;

    use vars qw($gps_data_viewer_file $gps_data_dir);
    $gps_data_dir = "$FindBin::RealBin/misc/gps_data" if !defined $gps_data_dir;
    $gps_data_viewer_file = $gps_data_dir             if !defined $gps_data_viewer_file;
    $gps_data_viewer_file = $FindBin::RealBin         if !defined $gps_data_viewer_file;

    my $show_file = sub {
	if (defined $gps_data_viewer_file) {
	    #XXX do it as late as possible, before the first edit operation: BBBikeEdit::ask_for_co($main::top, $gps_data_viewer_file);
	    $gps = GPS::GpsmanData::Any->load($gps_data_viewer_file, -editable => 1);
	    $gps_view->associate_object($gps);
	}
    };
    my $show_and_plot_file = sub {
	if (defined $gps_data_viewer_file) {
	    $show_file->();
	    if ($BBBikeEdit::recent_gps_point_layer) {
		main::delete_layer($BBBikeEdit::recent_gps_point_layer);
		undef $BBBikeEdit::recent_gps_point_layer;
	    }
	    if ($BBBikeEdit::recent_gps_street_layer) {
		main::delete_layer($BBBikeEdit::recent_gps_street_layer);
		undef $BBBikeEdit::recent_gps_street_layer;
	    }
	    BBBikeEdit::edit_gps_track($gps_data_viewer_file);
	}
    };
    
    {
	my $f = $t->Frame->pack(qw(-fill x));
	$f->Label(-text => "File:")->pack(qw(-side left));
	my $pe =
	    $f->PathEntry
		(-textvariable => \$gps_data_viewer_file,
		 -width => BBBikeUtil::max(length($gps_data_viewer_file), 40),
		)->pack(-fill => "x", -expand => 1, -side => "left");
	$pe->focus;
	my $showb = 
	    $f->Button(-text => "Show",
		       -command => sub {
			   $show_file->();
		       }
		      )->pack(-side => "left");
	my $plotandshowb =
	    $f->Button(-text => "Show & Plot",
		       -command => sub {
			   $show_and_plot_file->();
		       }
		      )->pack(-side => "left");
	$pe->configure(-selectcmd => sub {
			   $plotandshowb->focus;
		       });
    }

    my $vehicles_to_brands;
    if (-r "$gps_data_dir/vehicles_brands.yml" && eval { require YAML::Syck; 1 }) {
	$vehicles_to_brands = YAML::Syck::LoadFile("$gps_data_dir/vehicles_brands.yml");
    }
    my $gps_devices;
    if (-r "$gps_data_dir/gps_devices.yml" && eval { require YAML::Syck; 1 }) {
	$gps_devices = YAML::Syck::LoadFile("$gps_data_dir/gps_devices.yml");
    }

    $gps_view = $t->GpsmanData(-command => sub {
				   my(%args) = @_;
				   my $wpt = $args{-wpt};
				   if ($wpt) {
				       my($x,$y) = $Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude);
				       main::mark_point(-coords => [[[ main::transpose($x,$y) ]]],
							-clever_center => 1,
							-inactive => 1,
						       );
				   }
			       },
			       -selectforeground => 'black',
			       -selectbackground => 'green',
			       -velocity => 'per_vehicle',
			       -vehiclestobrands => $vehicles_to_brands,
			       -gpsdevices => $gps_devices,
			      )->pack(qw(-fill both -expand 1));

    {
	my $f = $t->Frame->pack(qw(-fill x));
	$f->Button(-text => "Select premature points",
		   -command => sub {
		       require GPS::GpsmanData::Analyzer;
		       my $anlzr = GPS::GpsmanData::Analyzer->new($gps);
		       my @wpts = $anlzr->find_premature_samples;
		       if (@wpts) {
			   $gps_view->select_items(grep { defined $_ } $gps_view->find_items_by_wpts(@wpts));
			   # XXX this is bad: dialog is modal and it's not possible to view all the selection
			   # XXX also, at least LongDialog should be used here
			   my $yn = $t->messageBox(-message => "Remove selected " . scalar(@wpts) . " item(s)?",
						   -type => "YesNo");
			   if (lc $yn eq 'yes') {
			       my $edit = GPS::GpsmanData::DirectEdit->new($gps);
			       my @lines = grep { defined $_ } map { $gps->LineInfo->get_line_by_wpt($_) } @wpts;
			       my @operations = $edit->remove_lines(\@lines, -dryrun => 1);
			       # XXX very bad formatting, maybe use a custom DialogBox here?
			       my $yn = $t->messageBox(-message => "Are you sure?\n" . join("\n", map { join " ", @$_ } @operations),
						       -type => "YesNo");
			       if (lc $yn eq 'yes') {
				   $edit->run_operations(\@operations);
				   $gps_view->reload;
				   my @operations = $edit->remove_empty_track_segments(-dryrun => 1);
				   if (@operations) {
				       my $yn = $t->messageBox(-message => "Remove empty track segments?\n" . join("\n", map { join " ", @$_ } @operations),
							       -type => "YesNo");
				       if (lc $yn eq 'yes') {
					   $edit->run_operations(\@operations);
					   $gps_view->reload;
				       }
				   }
			       }
			   }
		       }
		   })->pack(-side => "left");
	$f->Button(-text => "Set accuracy for selection",
		   -command => sub {
		       my @sel_items = $gps_view->get_selected_items;
		       my @wpts = grep { defined } map { $gps_view->wpt_by_item($_) } @sel_items;
		       my $last_accuracy;
		       for (@wpts) {
			   if (!defined $last_accuracy) {
			       $last_accuracy = $_->Accuracy;
			   } elsif ($last_accuracy != $_->Accuracy) {
			       my $yn = $t->messageBox(-message => "Differing accuracies in selected waypoints. Proceed nevertheless?",
						       -type => "YesNo");
			       return if (lc $yn ne 'yes');
			   }
		       }
		       require Tk::DialogBox;
		       my $dlg = $t->DialogBox(-title => "Accuracy", -buttons => ["OK", "Cancel"]);
		       $dlg->add("Label", -text => "Set accuracy to:")->pack;
		       my $new_accuracy = $last_accuracy;
		       $dlg->add("Radiobutton", -value => 0, -text => "!", -variable => \$new_accuracy)->pack;
		       $dlg->add("Radiobutton", -value => 1, -text => "~", -variable => \$new_accuracy)->pack;
		       $dlg->add("Radiobutton", -value => 2, -text => "~~", -variable => \$new_accuracy)->pack;
		       my $answer = $dlg->Show;
		       return if ($answer ne 'OK');
		       return if $new_accuracy == $last_accuracy;
		       my $edit = GPS::GpsmanData::DirectEdit->new($gps);
		       my @lines = grep { defined $_ } map { $gps->LineInfo->get_line_by_wpt($_) } @wpts;
		       $edit->set_accuracies(\@lines, $new_accuracy);
		       $gps_view->reload;
		   })->pack(-side => "left");
	$f->Button(-text => 'Statistics',
		   -command => sub {
		       require GPS::GpsmanData::Stats;
		       require YAML::Syck;
		       my $stats = GPS::GpsmanData::Stats->new($gps);
		       $stats->run_stats;
		       my $tt = $t->Toplevel(-title => 'GPS data statistics');
		       my $txt = $tt->Scrolled('ROText', -width => 30, -scrollbars => 'osoe')->pack(qw(-fill both -expand 1));
		       $txt->insert('end', YAML::Syck::Dump($stats->human_readable));
		       $tt->Button(-text => 'Close', -command => sub { $tt->destroy })->pack;
		   })->pack(-side => 'left');
    }

    if (defined $gps_file) {
	$gps_data_viewer_file = $gps_file;
	$show_and_plot_file->();
    }
}

######################################################################
# New GPS simplification

use vars qw($gps_simplification_route_street_layer $gps_simplification_route_point_layer
	    $gps_simplification_route_street_file  $gps_simplification_route_point_file
	  );

sub new_gps_simplification {
    if ($gps_simplification_route_street_layer) {
	main::delete_layer($gps_simplification_route_street_layer);
	undef $gps_simplification_route_street_layer;
    }
    if ($gps_simplification_route_street_file &&
	-f $gps_simplification_route_street_file) {
	unlink $gps_simplification_route_street_file;
    }
    if ($gps_simplification_route_point_layer) {
	main::delete_layer($gps_simplification_route_point_layer);
	undef $gps_simplification_route_point_layer;
    }
    if ($gps_simplification_route_point_file &&
	-f $gps_simplification_route_point_file) {
	unlink $gps_simplification_route_point_file;
    }

    if (!@main::realcoords) {
	main::status_message("No route available", "die");
    }
    my $route = Route->new_from_realcoords(\@main::realcoords);
    require Route::Simplify;
    if (!$main::net) {
	main::make_net();
    }
    my($strobj) = $main::net->sourceobjects; # XXX is this correct for multistrassen?
    my $res = $route->simplify_for_gps
	(-streetobj => $strobj,
	 -netobj => $main::net,
	 -routetoname => [StrassenNetz::simplify_route_to_name
			  ([$main::net->route_to_name([@main::realcoords],-startindex=>0,-combinestreet=>0)],
			   -minangle => 5, -samestreet => 1)
			 ],
	 -showcrossings => 0,
	 -waypointlength => 14, # XXX check if 15 are possible?
	 -waypointcharset=>"latin1",
	);
    my @c;
    my $p = Strassen->new;
    for my $wpt (@{ $res->{wpt} }) {
	my $xy = $wpt->{origlon}.",".$wpt->{origlat};
	push @c, $xy;
	$p->push([$wpt->{ident}, [$xy], "X"]);
    }
    push @c, map { $_->{origlon}.",".$_->{origlat} } $res->{wpt}->[-1];

    my $s = Strassen->new;
    $s->push(["", \@c, "X"]);

    require File::Temp;
    {
	(my($tmpfh),$gps_simplification_route_point_file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_p.bbd");
	print $tmpfh $p->as_string
	    or die $!;
	close $tmpfh
	    or die $!;
	$gps_simplification_route_point_layer = main::plot_additional_layer("p", $gps_simplification_route_point_file, -namedraw => 1);
    }

    {
	(my($tmpfh),$gps_simplification_route_street_file) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_s.bbd");
	print $tmpfh $s->as_string
	    or die $!;
	close $tmpfh
	    or die $!;
	$gps_simplification_route_street_layer = main::plot_additional_layer("str", $gps_simplification_route_street_file);
    }
}

######################################################################
# Real street widths

use vars qw($real_street_widths_s %real_street_widths_pos_to_width);
    
sub real_street_widths {
    use constant LANE_WIDTH => 3; # rough estimates
    use constant PEDESTRIAN_PATHS_WIDTH => 2 * 2.5;
    use constant MEDIAL_STRIP_WIDTH => 2;
    my %cat_to_width = ('B'  => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH + MEDIAL_STRIP_WIDTH,
			'HH' => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH + MEDIAL_STRIP_WIDTH,
			'H'  => 6 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'NH' => 4 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'N'  => 4 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH,
			'NN' => 2 * LANE_WIDTH,
		       );
    my $px_per_m = do {
	my($x0) = main::transpose(0,0);
	my($x1) = main::transpose(1,0);
	abs($x1-$x0);
    };
    my $pos_to_width = \%real_street_widths_pos_to_width;
    if (!$real_street_widths_s || !$real_street_widths_s->is_current) {
	my $s = Strassen->new("strassen-orig", UseLocalDirectives => 1);
	%real_street_widths_pos_to_width = ();
	$s->init;
	while(1) {
	    my $r = $s->next;
	    last if !@{ $r->[Strassen::COORDS()] };
	    my $dir = $s->get_directives;
	    my $w;
	    my $street_width_dir = $dir->{street_width};
	    if ($street_width_dir) {
		if ($street_width_dir->[0] =~ m{^([\d\.]+)m}) {
		    $w = $1;
		} elsif ($street_width_dir->[0] =~ m{(\d+)\s*lanes?}) {
		    $w = $1 * LANE_WIDTH + PEDESTRIAN_PATHS_WIDTH;
		    if ($street_width_dir->[0] =~ m{medial\s+strip}) {
			$w += MEDIAL_STRIP_WIDTH;
		    }
		} else {
		    warn "Cannot parse street_width directive <$street_width_dir->[0]>";
		}
	    } else {
		my $carriageway_width_dir = $dir->{carriageway_width};
		if ($carriageway_width_dir && $carriageway_width_dir->[0] =~ m{^([\d\.]+)m}) {
		    $w = $1 + PEDESTRIAN_PATHS_WIDTH;
		}
	    }
	    if (!$w) {
		$w = $cat_to_width{$r->[Strassen::CAT()]};
	    }
	    if ($w) {
		$pos_to_width->{$s->pos} = $w;
	    }
	}
	$real_street_widths_s = $s;
    }
    for my $item ($main::c->find(withtag => 's')) {
	my(@tags) = $main::c->gettags($item);
	my($index) = $tags[3] =~ m{^s-(\d+)};
	next if !defined $index;
	if (exists $pos_to_width->{$index}) {
	    $main::c->itemconfigure($item, -width => $pos_to_width->{$index}*$px_per_m);
	}
    }
}

######################################################################
# Search while typing feature

sub build_suggest_list {
    require File::Basename;
    my $ignore_qr = qr{(?:
			 qualitaet_s
		       | qualitaat_l
		       | handicap_s
		       | handicap_l
		       | gesperrt
		       | gesperrt_car
		       | comments_[^/]*
		       | ampelschaltung
		       | relation_gps
		       )}x;
    my @files = grep { !m{/${ignore_qr}-orig$}x } glob("$main::datadir/*-orig");
    if (!@files) {
	# Oh, no -orig files available. Assume an osm-converted
	# directory or bbbike from a distribution package
	@files = grep { !m{/${ignore_qr}$}x } grep { !m{/[^/]*\.[^/]*$} } glob("$main::datadir/*");
    }
    if (!@files) {
	main::status_message("Can't use this feature, no suitable files found in $main::datadir.", "error");
	return;
    }
    my %map;
    for my $file (@files) {
	my $s = eval { Strassen->new($file) };
	if ($s) {
	    my $base = File::Basename::basename($file);
	    $s->init;
	    while(1) {
		my $r = $s->next;
		last if !@{ $r->[Strassen::COORDS()] };
		my $name = $r->[Strassen::NAME()];
		next if $name =~ m{^(\s*|[\d\.]+)$};
		$map{$name . " ($base)"} = $r->[Strassen::COORDS()][0];
	    }
	}
    }
    map { [$_, $map{$_}] } sort keys %map;
}

sub tk_suggest {
    my @suggest_list = build_suggest_list();
    my $t = $main::top->Toplevel(-title => "Search");
    my $search;
    my $k2l = $t->Scrolled("K2Listbox",
			   -width => 40,
			   -scrollbars => "osoe",
			   -textvariable => \$search,
			  )->pack(qw(-expand 1 -fill both));
    $k2l->focus;
    $k2l->autocomplete;
    $k2l->insert("end", map { join("\t", @$_) } @suggest_list);
    my $show_cb = sub {
	my($name, $coord) = split /\t/, $search;
	if (!$coord) {
	    main::status_message("Please enter something!", "warn");
	} else {
	    main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
			     -clever_center => 1,
			     -inactive => 1,
			    );
	}
    };
    $t->Button(-text => "Show",
	       -command => $show_cb,
	      )->pack;
    $t->bind("<Return>" => sub { # hack:
		 $k2l->focusNext; # to trigger focusout
		 $t->after(100, $show_cb);
	     });
}

######################################################################
# Situation at point, debugging helper

sub _get_kreuzungen {
    our $kreuzungen;
    return $kreuzungen if $kreuzungen;
    require Strassen::Kreuzungen;
    my $ampeln = Strassen->new("$main::datadir/ampeln");
    my $vf     = Strassen->new("$main::datadir/vorfahrt");
    $kreuzungen = Kreuzungen::MoreContext->new(Strassen => $main::str_obj{'s'},
					       AllPoints => 1, # auch Kurvenpunkte
					       WantPos => 1, # for get_records
					       Ampeln => $ampeln->get_hashref_by_cat,
					       Vf     => $vf,
					       HandicapNet => main::make_handicap_net(),
					       QualitaetNet => main::make_qualitaet_net(),
					      );
}

sub show_situation_at_point {
    my $kreuzungen = _get_kreuzungen();
    if (@main::realcoords != 3) {
	main::status_message('Must be three coordinates in route!', 'error');
	return;
    }
    require Data::Dumper;
    my @p = map { join ",", @$_ } @main::realcoords[1,0,2];
    my %result = $kreuzungen->situation_at_point(@p);
    my $txt = $main::top->Subwidget('SituationAtPoint');
    $txt = undef if !Tk::Exists($txt);
    if (!$txt) {
	my $tl = $main::top->Toplevel(-title => "Situation at point");
	$txt = $tl->Scrolled("ROText", -scrollbars => "osoe")->pack(qw(-fill both -expand 1));
	$main::top->Advertise('SituationAtPoint' => $txt);
    }
    $txt->delete('1.0','end');
    $txt->insert('end', "For points @p\n");
    $txt->insert('end', Data::Dumper->new([\%result],[qw()])->Indent(1)->Useqq(1)->Dump);
    $txt->toplevel->raise;
}

sub toggle_situation_at_point_for_route {
    my $hookname_add = __PACKAGE__ . "_show_situation_at_point_for_route";
    my $hookname_del = __PACKAGE__ . "_show_situation_at_point_for_route-delete";
    if ($show_situation_at_point_for_route) {
	Hooks::get_hooks("new_route")->add(\&show_situation_at_point_for_route, $hookname_add);
	Hooks::get_hooks("del_route")->add(\&delete_situation_at_point_for_route, $hookname_del);
	show_situation_at_point_for_route();
    } else {
	Hooks::get_hooks("new_route")->del($hookname_add);
	Hooks::get_hooks("del_route")->del($hookname_del);
	delete_situation_at_point_for_route();
    }
}

sub show_situation_at_point_for_route {
    my $kreuzungen = _get_kreuzungen();
    if (!@main::realcoords) {
	return;
    }
    my @search_route = @{ main::get_act_search_route() };
    my %point_to_dir;
    for my $i (0 .. $#search_route) {
	my $coord = join(",", @{ $main::realcoords[$search_route[$i+1]->[StrassenNetz::ROUTE_ARRAYINX()][0]] });
	my $direction = {'l' => 'left',
			 'r' => 'right',
			 '' => '',
			}->{$search_route[$i]->[StrassenNetz::ROUTE_DIR()]};
	my $angle = $search_route[$i]->[StrassenNetz::ROUTE_ANGLE()];
	my $extra = $search_route[$i]->[StrassenNetz::ROUTE_EXTRA()];
	my $important = $extra && $extra->{ImportantAngle};
	# Heuristik from bbbike.cgi
	if (!$angle) { $angle = 0 }
	$angle = int($angle/10)*10;
	if ($angle < 30 && !$important) {
	    $direction = "";
	} elsif ($angle <= 45) {
	    $direction = 'half-' . $direction . " $angle°";
	} else {
	    $direction .= " $angle°";
	}
	if (exists $point_to_dir{$coord}) {
	    $point_to_dir{$coord} .= "; $direction";
	} else {
	    $point_to_dir{$coord} = $direction;
	}
    }

    delete_situation_at_point_for_route();
    for my $i (1 .. $#main::realcoords-1) {
	my @p = map { join ",", @$_ } @main::realcoords[$i,$i-1,$i+1];
	my %result = $kreuzungen->situation_at_point(@p);
	$main::c->createText(main::transpose(@{$main::realcoords[$i]}),
			     -text => $result{action} . (exists $point_to_dir{$p[0]} ? " ($point_to_dir{$p[0]})" : ""),
			     -anchor => 'w',
			     -tags => ['situation_at_point'],
			    );
    }
}

sub delete_situation_at_point_for_route {
    $main::c->delete('situation_at_point');
}

######################################################################
# Visualize nets (debugging helper)

sub net_to_strassen {
    my($net, $payload_is_name) = @_;
    my $file = $main::top->getSaveFile;
    return if !$file;
    my $s = Strassen->new;
    my %used_cat;
    while(my($c1,$v) = each %{ $net->{Net} }) {
	while(my($c2,$payload) = each %$v) {
	    my($name, $cat) = $payload_is_name ? ($payload, "X") : ($payload, $payload);
	    $used_cat{$cat}++;
	    $s->push([$name, [$c1, $c2], "$cat;"]);
	}
    }

    my $color_i = 0;
    my @colors = (qw(green red blue orange black darkblue yellow), '#ffdead');
    my %color;
    for my $cat (sort { $used_cat{$b} <=> $used_cat{$a} } keys %used_cat) {
	$color{$cat} = $colors[$color_i++];
	last if $color_i > $#colors;
    }
    $s->set_global_directives({
			       map { ("category_color.$_" => [$color{$_}]) } keys %color
			      });
    $s->write($file);
}

sub visualize_N_RW_net {
    if (!$main::N_RW_net) {
	main::status_message("\$N_RW_net does not exist --- please do one search with N_RW opt turned on first!", "error");
	return;
    }
    my %cat_to_color = ( 'N' => 'green',
			 'N_RW' => 'blue',
			 'H_RW' => 'orange',
			 'H' => 'red',
		       );
    main::IncBusy($main::top);
    eval {
	$main::c->delete('N_RW_net');
	while(my($c1,$v) = each %{ $main::N_RW_net->{Net} }) {
	    while(my($c2,$cat) = each %$v) {
		$main::c->createLine(main::transpose(split /,/, $c1),
				     main::transpose(split /,/, $c2),
				     -width => 2,
				     -fill => $cat_to_color{$cat} || 'black',
				     -tags => 'N_RW_net',
				);
	    }
	}
    };
    my $err = $@;
    main::DecBusy($main::top);
    main::status_message($err, "die") if $err;
}

######################################################################
# BBBikeSuggest

sub show_bbbike_suggest_toplevel {
    my(%args) = @_;
    require File::Temp;
    require Strassen::Strasse;
    require "$FindBin::RealBin/babybike/lib/BBBikeSuggest.pm";
    my $suggest = BBBikeSuggest->new;
    my($ofh,$sorted_zipfile) = File::Temp::tempfile(SUFFIX => ".data", UNLINK => 1);
    my $srcfile;
    my $is_opensearch_file;
    my %alias2street;
    my $is_utf8;
    my $plz;
    for my $def (["$main::datadir/opensearch.streetnames", 1, 1],
		 ["$main::datadir/Berlin.coords.data", 0, 0], # check for this file, but possibly use the combined cache file
		) {
	my($try_srcfile, $try_is_opensearch_file, $try_is_utf8) = @$def;
	if (-s $try_srcfile) {
	    if (!$is_opensearch_file) {
		$plz = main::make_plz();
		$srcfile = $plz->{File};
		main::status_message("Should never happen: Keine PLZ-Datenbank vorhanden!", 'die') if (!$plz);
	    } else {
		$srcfile = $try_srcfile;
	    }
	    $is_opensearch_file = $try_is_opensearch_file;
	    $is_utf8 = $try_is_utf8;
	    last;
	}
    }
    if (!$srcfile) {
	main::status_message("Sorry, no data file suitable for BBBikeSuggest found", "err");
	return;
    }
    {
	local $ENV{LANG} = $ENV{LC_CTYPE} = $ENV{LC_ALL} = $is_utf8 ? 'en_US.utf8' : 'C';
	open my $fh, "-|", 'sort', $srcfile
	    or die "Cannot sort $srcfile: $!";
	binmode $fh, ':utf8' if $is_utf8;
	while(<$fh>) {
	    if ($is_opensearch_file) {
		chomp;
		my($alias, $street) = split /\t/, $_;
		print $ofh join("|", $alias, "", "", "0,0"), "\n";
		if ($street) {
		    $alias2street{$alias} = $street;
		}
	    } else {
		print $ofh $_;
	    }
	}
	close $fh
	    or die "Cannot sort $srcfile: $!";
    }
    $suggest->set_zipfile($sorted_zipfile);
    my $t = main::redisplay_top($main::top, 'bbbike_suggest', -force => 1, -title => 'Search street', %args);
    main::set_as_toolwindow($t);
    my $w = $suggest->suggest_widget
	($t, -selectcmd => sub {
	     my $w = shift;
	     my $str = $w->get;
	     my $coord;
	     if (!$is_opensearch_file) {
		 ($str,my(@cityparts)) = Strasse::split_street_citypart($str);
		 my($matchref) = $plz->look_loop
		     ($str, Agrep => 3, Max => 1,
		      (@cityparts ? (Citypart => \@cityparts) : ()),
		     );
		 my(@match) = @$matchref;
		 main::status_message("Strange, no match for $str (@cityparts) found...", 'die') if (!@match);
		 $coord = $match[0]->[PLZ::LOOK_COORD()];
	     } else {
		 if (exists $alias2street{$str}) {
		     $str = $alias2street{$str};
		 }
		 my $s = $main::str_obj{s} || die "No strassen object available";
		 $s->init;
		 while(1) {
		     my $r = $s->next;
		     my $c = $r->[Strassen::COORDS()];
		     last if !@$c;
		     if ($str eq $r->[Strassen::NAME()]) {
			 $coord = $c->[$#$c/2];
			 last;
		     }
		 }
		 if (!$coord) {
		     main::status_message("Strange, no match for $str found...", 'die');
		 }
	     }
	     main::mark_point(-coords => [[[ main::transpose(split /,/, $coord) ]]],
			      -clever_center => 1,
			      -inactive => 1);
	 });
    $w->pack;
    $w->focus;
}

######################################################################
# Garmin devcap

sub garmin_devcap {
    require YAML::Syck;
    my $devcap_data = YAML::Syck::LoadFile("$FindBin::RealBin/misc/garmin_devcap.yaml");
    my $t = $main::top->Toplevel(-title => 'Garmin devices');
    my $lb = $t->Scrolled('Listbox', -scrollbars => 'osoe', -selectmode => 'single')->pack(qw(-fill both -expand 1));
    my @data;
    for my $prod_id (sort { $b <=> $a } keys %$devcap_data) { # younger devices (with larger product ids) first
	my $name = $devcap_data->{$prod_id}->{name};
	push @data, [$name, $prod_id];
	$lb->insert('end', $name);
    }
    my $f = $t->Frame->pack(qw(-fill x));
    $f->Button(-text => 'Use device',
	       -command => sub {
		   my($sel) = $lb->curselection;
		   if (!defined $sel) {
		       main::status_message('Please select a device', 'err');
		       return;
		   }
		   my $device_data = $devcap_data->{$data[$sel]->[1]};
		   for my $def (['wpts_in_route',       \$main::gps_waypoints],
				['wpt_length',          \$main::gps_waypointlength],
				['wpt_charset',         \$main::gps_waypointcharset],
				['unique_route_number', \$main::gps_needuniqueroutenumber],
			       ) {
		       my($data_key, $ref) = @$def;
		       if (exists $device_data->{$data_key}) {
			   $$ref = $device_data->{$data_key};
		       }
		   }
	       })->pack(qw(-side left));
    $f->Button(-text => 'Cancel',
	       -command => sub {
		   $t->destroy;
	       })->pack(qw(-side left));
}

######################################################################
# Winter optimization
sub do_winter_optimization {
    my($winter_hardness) = @_;
    if (!defined $winter_hardness) {
	delete $main::penalty_subs{'winteroptimization'};
    } else {
	# XXX Taken from bbbike.cgi and changed slightly
	require JSON::XS;
	my $penalty;
	for my $try (1 .. 2) {
	    for my $dir ("$bbbike_rootdir/tmp", @Strassen::datadirs) {
		my $f = "$dir/winter_optimization.$winter_hardness.json";
		if (-r $f && -s $f) {
		    my $json = do { open my $fh, $f or die $!; local $/; <$fh> };
		    $penalty = JSON::XS->new->decode($json);
		    #$penalty = Storable::retrieve($f);
		    last;
		}
	    }
	    if (!$penalty) {
		if ($try == 2) {
		    die "Can't find winter_optimization.$winter_hardness.json in @Strassen::datadirs and cannot build...";
		} else {
		    my @cmd = ($^X, "$bbbike_rootdir/miscsrc/winter_optimization.pl", "-as-json", "-winter-hardness", $winter_hardness, "-one-instance");
		    main::IncBusy($main::top);
		    eval {
			system @cmd;
			if ($? != 0) {
			    die "The command <@cmd> failed";
			}
		    };
		    my $err = $@;
		    main::DecBusy($main::top);
		    if ($err) {
			# Reset everything
			delete $main::penalty_subs{'winteroptimization'};
			$want_winter_optimization = '';
			main::status_message($err, "die");
		    }
		}
	    } else {
		last;
	    }
	}

	my $koeff = 1;
##XXX implement?
# 	if ($q->param('pref_winter') eq 'WI1') {
# 	    $koeff = 0.5;
# 	}

	$main::penalty_subs{'winteroptimization'} = sub {
	    my($pen, $next_node, $last_node) = @_;
	    if (exists $penalty->{$last_node.",".$next_node}) {
		my $this_penalty = $penalty->{$last_node.",".$next_node};
		$this_penalty = $koeff * $this_penalty + (100-$koeff*100)
		    if $koeff != 1;
		if ($this_penalty < 1) {
		    $this_penalty = 1;
		}		# avoid div by zero or negative values
		$pen *= (100 / $this_penalty);
	    }
	    $pen;
	};
    }
}

1;

__END__
