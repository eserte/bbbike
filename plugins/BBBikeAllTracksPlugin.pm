# -*- perl -*-

#
# $Id: BBBikeAllTracksPlugin.pm,v 1.2 2008/12/31 17:13:21 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2007 Slaven Rezic. All rights reserved.
#

# Very hackish for now. Needs more configuration options.
# E.g.
# [x] hold persistent
# Also, a list of recently used directories. Maybe this list could hold
# the mapping of directory -> persistent bbd file

# Need progress bars

# Need better titles/names for everything, including the package name itself.

# XXX better descriptions
# Description (en): Manage GPS tracks
# Description (de): GPS-Tracks managen
package BBBikeAllTracksPlugin; # better package name

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use File::Glob qw(bsd_glob);
use File::Basename qw(basename dirname);

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};

    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }

    BBBikePlugin::remove_menu_button($pkg."_menu");

    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my $mf  = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;
    my %cmd_args =
	(-command  => sub {
	     show_dialog();
	 },
	);
    my $b = $mf->Button
	(#main::image_or_text($button_image, 'Thunder'),
	 -text => "ALL GPS", # XXX better name, maybe also an icon
	 %cmd_args
	);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "All GPS Tracks") # XXX better description
	if $main::balloon;

    # XXX Everything should be localized
    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      "-",
	      [Button => "Dieses Menü löschen",
	       -command => sub {
		   $mmf->after(100, sub {
				   unregister();
			       });
	       }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	     -title => "ALL GPS Tracks", # XXX better title
	     -topmenu => [Command => 'Select',
			  %cmd_args,
			 ],
	    );

    my $menu = $mmf->Subwidget(__PACKAGE__."_menu")->menu;
}

sub show_dialog {
    my $t = $main::top->Toplevel;
    # XXX better layout, half-persistent toplevel, transiency etc.
    $t->Label(-text => "Directory with GPSMAN tracks")->pack;
    my $dir;
    $t->Entry(-textvariable => \$dir)->pack;
    $t->Button(-text => "Choose...",
	       -command => sub {
		   $dir = $t->chooseDirectory;
	       })->pack;
    $t->Button(-text => "Show",
	       -command => sub {
		   if (defined $dir && -d $dir) {
		       run($dir);
		   } else {
		       main::status_message("Please select a valid directory first", "err");
		   }
	       },
	      )->pack;
}

sub run {
    my($dir) = @_;
    # gpsman2bbd functionality should be moved to a module, probably
    # or maybe use any2bbd instead, as it supports anything?
    my $gpsman2bbd = "$FindBin::RealBin/miscsrc/gpsman2bbd.pl";
    if (!-e $gpsman2bbd) {
	main::status_message("$gpsman2bbd does not exist or is not executable", "die");
    }
    my $persistent_bbd;
    if ($main::bbbike_configdir) {
	$persistent_bbd = "$main::bbbike_configdir/all_gps_streets.bbd";
    } else {
	require File::Spec;
	$persistent_bbd = File::Spec->catfile(File::Spec->tmpdir, "all_gps_streets.bbd");
    }
    my @cmd = ($^X,
	       $gpsman2bbd, "-update", bsd_glob("$dir/*.trk"), "-breakmin", 2,
	       "-destdir", dirname($persistent_bbd), "-deststreets", basename($persistent_bbd),
	      );
    system @cmd;
    if ($? != 0) {
	main::status_message("Error running @cmd: $?", "die");
    }
    my $layer = add_new_layer("str", $persistent_bbd);
    set_layer_highlightning($layer);
    main::special_raise($layer, 0);
}

# Taken from SRTShortcuts:
sub add_new_layer {
    my($type, $file, %args) = @_;
    my $free_layer = main::next_free_layer($type);
    $main::line_width{$free_layer} = [(1)x6]; # XXX hmmm, "6" should not be hardcoded
    if (exists $args{Width}) {
	$main::p_width{$free_layer} = $args{Width};
    }
    if (!$BBBikeLazy::mode) {
	require BBBikeLazy;
	BBBikeLazy::bbbikelazy_empty_setup();
	main::bbbikelazy_add_data($type, $free_layer, $file);
	main::bbbikelazy_init();
    } else {
	main::bbbikelazy_add_data($type, $free_layer, $file);
    }
    Hooks::get_hooks("after_new_layer")->execute;
    $free_layer;
}

# Taken from SRTShortcuts:
sub set_layer_highlightning {
    my $layer = shift;
    $main::layer_active_color{$layer} = 'red';
#     $main::layer_post_enter_command{$layer} = sub {
# 	#$main::c->raise("current")
# 	$name_tag = ($main::c->gettags("current"))[1];
# 	$main::c->
#     };
}

1;
