# -*- perl -*-

#
# $Id: SRTShortcuts.pm,v 1.13 2004/05/02 20:41:06 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

my $streets_track      = "$ENV{HOME}/src/bbbike/tmp/streets.bbd";
my $orig_streets_track = "$ENV{HOME}/src/bbbike/tmp/streets.bbd-orig";
my $acc_streets_track  = "$ENV{HOME}/src/bbbike/tmp/streets-accurate.bbd";

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

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Button => "Default penalty",
	       -command => sub {
		   require BBBikeEdit;
		   $main::bbd_penalty = 1;
		   $BBBikeEdit::bbd_penalty_file = "$ENV{HOME}/src/bbbike/tmp/unique-matches.bbd";
		   if ($Strassen::datadirs[0] =~ /data_corrected/) {
		       $BBBikeEdit::bbd_penalty_file = "$ENV{HOME}/src/bbbike/tmp/unique-matches-corrected.bbd";
		   }
		   BBBikeEdit::build_bbd_penalty_for_search();
	       }],
	      [Button => "Edit with new GPS trk",
	       -command => sub {
		   require BBBikeEdit;
		   require BBBikeAdvanced;
		   require BBBikeExp;
		   require File::Basename;
		   main::plot("str","s", -draw => 0);
		   main::switch_edit_berlin_mode();
		   main::bbbikeexp_clear();
		   main::bbbikeexp_setup();

		   main::bbbikeexp_init();
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
	      [Button => "Tracks in region",
	       -command => sub {
		   require BBBikeEdit;
		   require BBBikeGPS;
		   if (@main::coords != 2) {
		       main::status_message("Expecting exactly two points forming a region", "die");
		   }
		   my @region_corners = map { @$_ } @main::coords;
		   my %seen_track;
		   my @tracks = sort grep {
		       if (!$seen_track{$_}) {
			   $seen_track{$_}++;
			   1;
		       } else {
			   0;
		       }
		   } grep { /\.trk$/ }
		       map { ($main::c->gettags($_))[1] }
			   $main::c->find(overlapping => @region_corners);
		   my $t = $main::top->Toplevel(-title => "Tracks in region");
		   $t->transient($main::top) if $main::transient;
		   my $lb = $t->Scrolled("Listbox", -scrollbars => "osoe")->pack(-fill => "both", -expand => 1);
		   $lb->insert("end", @tracks);
		   $lb->bind("<1>" => sub {
				 my $base = $lb->get(($lb->curselection)[0]);
				 my $file = BBBikeEdit::find_gpsman_file($base);
				 if (!$file) {
				     main::status_message(M("Keine Datei zu $base gefunden"));
				     return;
				 }
				 BBBikeGPS::do_draw_gpsman_data($main::top, $file, -solidcoloring => 1);
			     });
		   $t->Button(Name => "close",
			      -command => sub { $t->destroy })->pack;
	       }],
	      [Button => "My edit mode",
	       -command => sub {
		   require BBBikeEdit;
		   require BBBikeExp;
		   main::plot("str","s", -draw => 0);
		   main::switch_edit_berlin_mode();
		   main::bbbikeexp_reload_all();
		   BBBikeEdit::editmenu($main::top);
		   main::plot('str','fz', -draw => 1);
	       }],
	      [Button => "Standard upload all",
	       -command => sub { upload("upload") },
	      ],
	      [Button => "Standard upload trk only",
	       -command => sub { upload("upload-trk") },
	      ],
	      [Button => "Standard upload wpt only",
	       -command => sub { upload("upload-wpt") },
	      ],
	      [Button => "Update tracks and matches.bbd",
	       -command => sub { upload("tracks develtracks ../../tmp/unique-matches.bbd ../../tmp/unique-matches-corrected.bbd") },
	      ],
	      [Button => "Add streets-accurate.bbd (all accurate GPS tracks)",
	       -command => sub {
		   my $f = $acc_streets_track;
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   add_new_layer("str", $f);
	       }
	      ],
	      [Button => "Add streets.bbd (all GPS tracks)",
	       -command => sub {
		   my $f = $streets_track;
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   add_new_layer("str", $f);
	       }
	      ],
	      [Button => "Add points-all.bbd (all GPS trackpoints)",
	       -command => sub {
		   my $f = "$ENV{HOME}/src/bbbike/tmp/points-all.bbd";
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   add_new_layer("p", $f);
	       }
	      ],
	      [Button => "Add hm96.bbd (Höhenpunkte)",
	       -command => sub {
		   my $f = "$ENV{HOME}/src/bbbike/miscsrc/senat_b/hm96.bbd";
		   if ($main::coord_system ne 'standard') { $f .= "-orig" }
		   $hm_layer = add_new_layer("p", $f);
		   $main::top->bind("<F12>"=> \&find_nearest_hoehe);
	       }
	      ],
	      [Button => "Edit in normal mode",
	       -command => \&edit_in_normal_mode,
	      ],
	      [Button => "Edit in normal mode (landstrassen)",
	       -command => \&edit_in_normal_mode_landstrassen,
	      ],
	      [Button => "Cancel edit in normal mode",
	       -command => \&cancel_edit_in_normal_mode,
	      ],
	      [Button => "Show vmz diff",
	       -command => \&show_vmz_diff,
	      ],
	      [Button => "Show lbvs diff",
	       -command => \&show_lbvs_diff,
	      ],
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
	    );
}

sub upload {
    my $rule = shift;
    if (fork == 0) {
	exec(qw(xterm -e sh -c),
	     'cd $HOME/src/bbbike/misc/gps_data && make ' . $rule . '; sleep 9999');
	die $!;
    }
}

sub add_new_layer {
    my($type, $file) = @_;
    my $free_layer = main::next_free_layer($type);
    $main::line_width{$free_layer} = [(1)x6];
    if (!$BBBikeExp::mode) {
	require BBBikeExp;
	BBBikeExp::bbbikeexp_empty_setup();
	main::bbbikeexp_add_data($type, $free_layer, $file);
	main::bbbikeexp_init();
    } else {
	main::bbbikeexp_add_data($type, $free_layer, $file);
    }
    Hooks::get_hooks("after_new_layer")->execute;
    $free_layer;
}

sub show_vmz_diff {
    require BBBikeAdvanced;
    my $abk = main::plot_additional_layer("str", "$ENV{HOME}/cache/misc/diffvmz.bbd");
    main::choose_ort("str", $abk);
}

sub show_lbvs_diff {
    require BBBikeAdvanced;
    my $abk = main::plot_additional_layer("str", "$ENV{HOME}/cache/misc/difflbvs.bbd");
    main::choose_ort("str", $abk);
}

sub edit_in_normal_mode {
    require BBBikeEdit;
    my $map = "standard";
    if (0) {
	BBBikeEdit->draw_pp("strassen", -abk => "s");
    } else {
	require BBBikeExp;
	BBBikeExp::bbbikeexp_add_data_by_subs
		("p","pp",
		 init      => sub {
		     BBBikeEdit->draw_pp_init_code("strassen", -abk => "s")
		 },
		 draw      => \&BBBikeEdit::draw_pp_draw_code,
		 post_draw => \&BBBikeEdit::draw_pp_post_draw_code,
		);
    }
    main::set_coord_output_sub($map);
    $SRTShortcuts::force_edit_mode = 1;
    $main::use_current_coord_prefix = 0;
    $main::coord_prefix = undef;
    main::set_map_mode(&main::MM_BUTTONPOINT);
}

sub edit_in_normal_mode_landstrassen {
    require BBBikeEdit;
    my $map = "standard";
    if (0) {
	BBBikeEdit->draw_pp(["landstrassen", "landstrassen2"], -abk => "l");
    } else {
	require BBBikeExp;
	BBBikeExp::bbbikeexp_add_data_by_subs
		("p","pp",
		 init      => sub {
		     BBBikeEdit->draw_pp_init_code(["landstrassen", "landstrassen2"], -abk => "l")
		 },
		 draw      => \&BBBikeEdit::draw_pp_draw_code,
		 post_draw => \&BBBikeEdit::draw_pp_post_draw_code,
		);
    }
    main::set_coord_output_sub($map);
    $SRTShortcuts::force_edit_mode = 1;
    $main::use_current_coord_prefix = 0;
    $main::coord_prefix = undef;
    main::set_map_mode(&main::MM_BUTTONPOINT);
}

sub cancel_edit_in_normal_mode {
    require BBBikeEdit;
    for my $abk (qw(s l)) {
	BBBikeEdit->draw_pp([], -abk => $abk);
    }
    main::set_coord_output_sub("standard");
    $SRTShortcuts::force_edit_mode = 0;
    $main::use_current_coord_prefix = 0;
    $main::coord_prefix = undef;
}

sub define_subs {
    package main;
    *show_info_ext = sub {
	my($c, @tags) = @_;
	warn "$c - $tags[3] - @tags ";
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
    my $nearest = $main::exp_p{$hm_layer}->nearest_point($xy, FullReturn => 1);
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

1;

__END__
