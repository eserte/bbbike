# -*- perl -*-

#
# $Id: SRTShortcuts.pm,v 1.9 2004/02/20 21:53:41 eserte Exp eserte $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

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
		   add_new_layer("str",
				 "$ENV{HOME}/src/bbbike/tmp/streets.bbd-orig"
				);

#  		   {
#  		       local $main::default_line_width = 1;
#  		       main::plot_additional_layer("str", "$ENV{HOME}/src/bbbike/tmp/streets.bbd");
#  		   }
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
	      [Button => "Add streets.bbd (all GPS tracks)",
	       -command => sub {
		   my $f = "$ENV{HOME}/src/bbbike/tmp/streets.bbd";
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
		   add_new_layer("p", $f);
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
    my $map = "berlinmap";
    BBBikeEdit->draw_pp("strassen", -abk => "s");
    main::set_coord_output_sub($map);
    $SRTShortcuts::force_edit_mode = 1;
}

sub edit_in_normal_mode_landstrassen {
    require BBBikeEdit;
    my $map = "brbmap";
    BBBikeEdit->draw_pp(["landstrassen", "landstrassen2"], -abk => "l");
    main::set_coord_output_sub($map);
    $SRTShortcuts::force_edit_mode = 1;
}

sub cancel_edit_in_normal_mode {
    require BBBikeEdit;
    for my $abk (qw(s l)) {
	BBBikeEdit->draw_pp(Strassen->new, -abk => $abk);
    }
    main::set_coord_output_sub("standard");
    $SRTShortcuts::force_edit_mode = 0;
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

1;

__END__
