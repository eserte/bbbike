# -*- perl -*-

#
# $Id: BBBikeViewImages.pm,v 1.1 2005/04/28 20:53:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
#

package BBBikeViewImages;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $image_viewer_toplevel $image_viewer_label);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

sub register {
    add_button();
}

sub add_button {
    my $mf  = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;
    my $Radiobutton = $main::Radiobutton;
    my $b = $mf->$Radiobutton
	(#main::image_or_text($button_image, 'Thunder'),
	 -text => "Img",
	 -variable => \$main::map_mode,
	 -value => 'BBBikeViewImages',
	 -command => sub {
	     $main::map_mode_deactivate->() if $main::map_mode_deactivate;
	     activate();
	     $main::map_mode_deactivate = \&deactivate;
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "Image Viewer")
	if $main::balloon;
}

sub activate {
    $main::map_mode = 'BBBikeViewImages';
    main::status_message("Auf Thumbnails klicken", "info");
}

sub deactivate {
}

sub button {
    my($c, $e) = @_;
    my(@tags) = $c->gettags("current");
    my $name = $tags[1];
    if ($name =~ /^Image:\s*(\S+)/) {
	my $abs_file = $1;
	if (!-e $abs_file) {
	    main::status_message("Kann die Datei $abs_file nicht finden", "die");
	}
	if (!defined $image_viewer_toplevel || !Tk::Exists($image_viewer_toplevel)) {
	    $image_viewer_toplevel = $main::top->Toplevel(-title => "Image viewer");
	    $image_viewer_label = $image_viewer_toplevel->Label->pack(-fill => "both", -expand => 1);
	    $image_viewer_toplevel->OnDestroy
		(sub {
		     my $p = $image_viewer_toplevel->Subwidget("photo");
		     if ($p) {
			 $p->delete;
		     }
		 });
	}
	my $p = $image_viewer_toplevel->Subwidget("photo");
	if ($p) {
	    $p->delete;
	    $image_viewer_toplevel->Advertise(photo => undef);
	}
	$p = main::image_from_file($main::top, $abs_file);
	if (!$p) {
	    main::status_message("Kann die Datei $abs_file nicht als Bild interpretieren", "die");
	}
	$image_viewer_label->configure(-image => $p);
	$image_viewer_toplevel->Advertise(photo => $p);
    }
}


1;
