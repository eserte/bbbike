# -*- perl -*-

#
# $Id: BBBikeScribblePlugin.pm,v 1.4 2003/01/08 20:00:43 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# Description (en): Scribble mode
# Description (de): Freihand-Zeichnen
package BBBikeScribblePlugin;
use base qw(BBBikePlugin);

use BBBikeScribble;
use strict;

sub register {
    my $pkg = __PACKAGE__;

    $BBBikePlugin::plugins{$pkg} = $pkg;

#      if (!defined $button_image) {
#  	# ruler image is from tkruler
#  	$button_image = main::load_photo
#  	    ($main::top, 'salesman.'.$main::default_img_fmt);
#      }

    $main::map_mode_callback{main::MM_SCRIBBLE()} = \&map_mode_activate;

#      if (!defined $salesman_cursor) {
#  	main::load_cursor("salesman");
#      }

    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    if ($main::map_mode eq main::MM_SCRIBBLE() &&
	$main::map_mode_deactivate) {
	$main::map_mode_deactivate->();
    }
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
    delete $BBBikePlugin::plugins{$pkg};
}

sub activate {
    warn "XXX I thought this is unused...";
    $main::map_mode = main::MM_SCRIBBLE(); # XXX no main::
    $Tk::Babybike::scribble_mode = 1; # XXX
    $main::map_mode_deactivate = \&deactivate;
#    main::set_cursor_data($salesman_cursor);
#    main::status_message("Punkte auswählen", "info");
}

sub deactivate {
    Tk::Babybike::deselect_scribble_mode();
    $Tk::Babybike::scribble_mode = 0; # XXX
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;

    my $Radiobutton = $main::Radiobutton;
#    my $salesman_photo = main::load_photo($mf, 'salesman.' . $main::default_img_fmt);
    my $b;
    $b = $mf->$Radiobutton
	(-text => "Scr",
	 #main::image_or_text($salesman_photo, 'Salesman'),
	 -variable => \$main::map_mode,
	 -value => main::MM_SCRIBBLE(),
	 -command => \&main::set_map_mode,
	)->pack(-side => "left", -anchor => 'sw');
    $mf->Advertise(__PACKAGE__ . '_on' => $b);
    $main::balloon->attach($b, -msg => "Zeichnen")
	if $main::balloon;
#    $main::ch->attach($b, -pod => "^\\s*Salesman-Symbol");

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [
	      [Checkbutton => "~Scribble", -variable => \$Tk::Babybike::scribble_mode,
	       -command => \&Tk::Babybike::toggle_scribble_mode],
	      [Checkbutton => "Sho~w Scribble", -variable => \$Tk::Babybike::show_scribble,
	       -command => \&Tk::Babybike::set_show_scribble],
	      [Checkbutton => "Show Scribble Labels", -variable => \$Tk::Babybike::show_scribble_labels,
	       -command => \&Tk::Babybike::set_show_scribble_labels],
	      [Button => "~Load Scribble", -command => \&Tk::Babybike::load_scribble],
	      [Button => "~Save Scribble", -command => \&Tk::Babybike::save_scribble],
	     ],
	     $b,
	    );

}

sub map_mode_activate {
    $main::map_mode_deactivate->() if $main::map_mode_deactivate;
    $Tk::Babybike::c = $main::c; # XXX
    Tk::Babybike::set_scribble_mode();
    $Tk::Babybike::scribble_mode = 1; # XXX
    $main::map_mode_deactivate = \&deactivate;
}


1;

__END__
