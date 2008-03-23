# -*- perl -*-

#
# $Id$
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
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

my $bbbike_rootdir;
if (-e "$FindBin::RealBin/bbbike") {
    $bbbike_rootdir = $FindBin::RealBin;
} else {
    $bbbike_rootdir = "$ENV{HOME}/src/bbbike";
}
my $streets_track      = "$bbbike_rootdir/tmp/streets.bbd";
my $orig_streets_track = "$bbbike_rootdir/tmp/streets.bbd-orig";
my $acc_streets_track  = "$bbbike_rootdir/tmp/streets-accurate.bbd";
my $other_tracks       = "$bbbike_rootdir/tmp/other-tracks.bbd";

use vars qw($hm_layer);

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button();
    define_subs();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
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
	       add_new_layer("str", $orig_streets_track);
	       
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

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Button => "Default penalty (unique matches)",
	       -command => \&default_penalty,
	      ],
	      [Button => "Default penalty (fragezeichen)",
	       -command => \&default_penalty_fragezeichen,
	      ],
	      [Button => "Tracks in region",
	       -command => sub { tracks_in_region() },
	      ],
	      [Button => "Update tracks and matches.bbd",
	       -command => sub { make_gps_target("tracks develtracks ../../tmp/unique-matches.bbd") },
	      ],
	      [Button => "Add streets-accurate.bbd (all accurate GPS tracks)",
	       -command => sub {
		   my $f = $acc_streets_track;
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   my $layer = add_new_layer("str", $f);
		   set_layer_highlightning($layer);
		   main::special_raise($layer, 0);
	       }
	      ],
	      [Button => "Add other-tracks.bbd (other people's GPS tracks)",
	       -command => sub {
		   my $f = $other_tracks;
		   my $layer = add_new_layer("str", $f);
		   set_layer_highlightning($layer);
		   main::special_raise($layer, 0);
	       }
	      ],
	      [Button => "Add streets.bbd (all GPS tracks)",
	       -command => sub {
		   my $f = $streets_track;
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   my $layer = add_new_layer("str", $f);
		   set_layer_highlightning($layer);
	       }
	      ],
	      [Button => "Add points-all.bbd (all GPS trackpoints)",
	       -command => sub {
		   my $f = "$bbbike_rootdir/tmp/points-all.bbd";
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   my $points_layer = add_new_layer("p", $f, Width => 20);
		   main::special_lower($points_layer . "-fg", 0);
	       }
	      ],
	      [Button => "Add hm96.bbd (Höhenpunkte)",
	       -command => sub {
		   my $f = "$bbbike_rootdir/miscsrc/senat_b/hm96.bbd";
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   $hm_layer = add_new_layer("p", $f);
		   $main::top->bind("<F12>"=> \&find_nearest_hoehe);
	       }
	      ],
	      [Button => "Add Zebrastreifen",
	       -command => sub {
		   local $main::lazy_plot = 0; # lazy mode does not support bbd images yet
		   add_new_nonlazy_layer("p", "$bbbike_rootdir/misc/zebrastreifen");
	       }
	      ],
	      [Button => "Add Abdeckung",
	       -command => sub {
		   local $main::p_draw{'pp-all'} = 1;
		   add_new_layer("str", "$bbbike_rootdir/misc/abdeckung.bbd");
	       }
	      ],
	      [Cascade => 'Berlin/Potsdam coords', -menuitems =>
	       [
		[Button => "Add Berlin.coords.data",
		 -command => sub { add_coords_data("Berlin.coords.bbd") },
		],
# 		[Button => "Add Berlin.coords.data with labels",
# 		 -command => sub { add_coords_data("Berlin.coords.bbd", 1) },
# 		],
		[Button => "Add Potsdam.coords.data",
		 -command => sub { add_coords_data("Potsdam.coords.bbd") },
		],
# 		[Button => "Add Potsdam.coords.data with labels",
# 		 -command => sub { add_coords_data("Potsdam.coords.bbd", 1) },
# 		],
	       ]
	      ],
	      [Button => "Show VMZ diff",
	       -command => sub { show_vmz_diff() },
	      ],
	      [Button => "Show LBVS diff",
	       -command => sub { show_lbvs_diff() },
	      ],
	      [Cascade => "Archive", -menuitems =>
	       [
		(map { [Button => "VMZ version $_", -command => [sub { show_vmz_diff($_[0]) }, $_] ] } (0 .. 5)),
		"-",
		(map { [Button => "LBVS version $_", -command => [sub { show_lbvs_diff($_[0]) }, $_] ] } (0 .. 5)),
	       ],
	      ],
	      ($main::devel_host ? [Cascade => "Karte"] : ()),
	      [Button => "Mark Layer",
	       -command => sub { mark_layer_dialog() },
	      ],
	      [Button => "Mark most recent Layer",
	       -command => sub { mark_most_recent_layer() },
	      ],
	      "-",
	      [Cascade => "Rare or old", -menu => $rare_or_old_menu],
	      "-",
	      [Button => "Delete this menu",
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
    my $menu = $mmf->Subwidget(__PACKAGE__ . "_menu_menu");
    if ($main::devel_host) {
	my $map_menuitem = $menu->index("Karte");
	$menu->entryconfigure($map_menuitem,
			      -menu => main::get_map_button_menu($menu));
    }
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
    $t->Button(Name => "close",
	       -command => sub { $t->destroy })->pack;
}

sub make_gps_target {
    my $rule = shift;
    if (fork == 0) {
	exec(qw(xterm -e sh -c),
	     'cd ' . $bbbike_rootdir . '/misc/gps_data && make ' . $rule . '; echo Ready; sleep 9999');
	die $!;
    }
}

# Width support for now only for p layers
sub add_new_layer {
    my($type, $file, %args) = @_;
    my $free_layer = main::next_free_layer($type);
    $main::line_width{$free_layer} = [(1)x6];
    if (exists $args{Width}) {
	$main::p_width{$free_layer} = $args{Width};
    }
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
    Hooks::get_hooks("after_new_layer")->execute;
    $free_layer;
}

sub add_new_nonlazy_layer {
    my($type, $file, %args) = @_;
    require BBBikeAdvanced;
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

sub _vmz_lbvs_splitter {
    my($line) = @_;
    my($type, $content, $id);
    if ($line =~ m{¦}) {
	# new style
	($type, $content, $id) = split /¦/, $line, 3;
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
    show_any_diff("$ENV{HOME}/cache/misc/diffvmz.bbd$version", "vmz");
}

sub show_lbvs_diff {
    my($version) = @_;
    main::plot("str",'l', -draw => 1);
    main::make_net();
    if (defined $version) { $version = ".$version" }
    show_any_diff("$ENV{HOME}/cache/misc/difflbvs.bbd$version", "lbvs");
}

sub show_any_diff {
    my($file, $diff_type) = @_;
    # To pre-generate cache:
    # XXX make sure that only ONE check_bbbike_temp_blockings process
    # runs at a time...
    system("$bbbike_rootdir/miscsrc/check_bbbike_temp_blockings >/dev/null 2>&1 &");
    require BBBikeAdvanced;
    require File::Basename;
    my $abk = main::plot_additional_layer("str", $file);
    my $token = "chooseort-" . File::Basename::basename($file) . "-str";
    my $t = main::redisplay_top($main::top, $token, -title => $file);
    if (!$t) {
	$t = $main::toplevel{$token};
	$_->destroy for ($t->children);
    } else {
	$t->geometry($t->screenwidth-20 . "x" . 260 . "+0-20");
    }
    {
	local $^T = time;
	$t->Label(-text => "Modtime: " . scalar(localtime((stat($file))[9])) .
		  sprintf " (%.1f days ago)", (-M $file)
		 )->pack(-anchor => "w");
    }
    my $f;
    my $hide_ignored;
    $t->Checkbutton(-text => "Hide ignored and unchanged",
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
		    })->pack(-anchor => "w");
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

sub define_subs {
    package main;
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

sub default_penalty {
    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 0;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/tmp/unique-matches.bbd";
    BBBikeEdit::build_bbd_penalty_for_search();
}

sub default_penalty_fragezeichen {
    $main::add_net{fz} = 1;
    main::change_net_type();

    require BBBikeEdit;
    $main::bbd_penalty = 1;
    $BBBikeEdit::bbd_penalty_invert = 1;
    $BBBikeEdit::bbd_penalty_file = "$bbbike_rootdir/data/fragezeichen";

    BBBikeEdit::build_bbd_penalty_for_search();
}

# XXX $namedraw does not work
sub add_coords_data {
    my($file, $namedraw) = @_;
    my $f = "$bbbike_rootdir/tmp/$file";
    if ($main::coord_system ne 'standard') { $f .= "-orig" }
    add_new_layer("p", $f, NameDraw => $namedraw);
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
    my $s = $main::str_obj{$abk};
    if (!$s) {
	if ($main::str_file{$abk}) {
	    $s = Strassen->new($main::str_file{$abk});
	}
	if (!$s) {
	    main::status_message("Cannot get street object for <$abk>", "die");
	}
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

1;

__END__
