# -*- perl -*-

#
# $Id: BBBikeViewImages.pm,v 1.7 2006/07/03 12:05:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
#

package BBBikeViewImages;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION $image_viewer_toplevel);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

my $iso_date_rx = qr{(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})};

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
    my $current_inx = $c->find(withtag => "current");
    my($img_x, $img_y) = $c->coords($current_inx);
    my @all_image_inx = sort {
	my(@tags_a) = $c->gettags($a);
	my(@tags_b) = $c->gettags($b);
	my($date_a) = $tags_a[1] =~ $iso_date_rx;
	my($date_b) = $tags_b[1] =~ $iso_date_rx;
	$date_a cmp $date_b;
    } grep {
	my(@tags) = $c->gettags($_);
	# Could be tag inx 1 or 2
	grep { /^Image:/ } @tags;
	#my $name = $tags[1];
	#$name =~ /^Image:/;
    } $c->find("overlapping",
	       $img_x-10, $img_y-10,
	       $img_x+10, $img_y+10);
    show_image_viewer(-canvas    => $c,
		      -allimages => \@all_image_inx,
		      -current   => $current_inx,
		     );
}

sub show_image_viewer {
    my(%args) = @_;
    my($c, $all_image_inx, $current_inx) = @args{qw(-canvas
						    -allimages
						    -current)};

    my(@tags) = $c->gettags($current_inx);
    my $name = $tags[1]; # XXX should also check for inx=2!
    if ($name =~ /^Image:\s*\"([^\"]+)\"/) {
	my $abs_file = $1;
	if (!-e $abs_file) {
	    main::status_message("Kann die Datei $abs_file nicht finden", "die");
	}
	my($date) = $name =~ $iso_date_rx;
	if (!defined $image_viewer_toplevel || !Tk::Exists($image_viewer_toplevel)) {
	    $image_viewer_toplevel = $main::top->Toplevel(-title => "Image viewer");
	    my $f = $image_viewer_toplevel->Frame->pack(-fill => "x", -side => "bottom");
	    my $prev_button = $f->Button(-text => "<<")->pack(-side => "left");
	    $image_viewer_toplevel->Advertise(PrevButton => $prev_button);
	    my $next_button = $f->Button(-text => ">>")->pack(-side => "left");
	    $image_viewer_toplevel->Advertise(NextButton => $next_button);
	    my $date_label = $f->Label->pack(-side => "left");
	    $image_viewer_toplevel->Advertise(DateLabel => $date_label);
	    my $image_viewer_label = $image_viewer_toplevel->Label->pack(-fill => "both", -expand => 1,
									 -side => "bottom");
	    $image_viewer_toplevel->Advertise(ImageLabel => $image_viewer_label);

	    $image_viewer_toplevel->OnDestroy
		(sub {
		     my $p = $image_viewer_toplevel->{"photo"};
		     if ($p) {
			 $p->delete;
		     }
		 });
	}
	my $p = $image_viewer_toplevel->{"photo"};
	if ($p) {
	    $p->delete;
	    $image_viewer_toplevel->{"photo"} = undef;
	}
	$p = main::image_from_file($main::top, $abs_file);
	if (!$p) {
	    main::status_message("Kann die Datei $abs_file nicht als Bild interpretieren", "die");
	}
	$image_viewer_toplevel->Subwidget("ImageLabel")->configure(-image => $p);

	my $next_image_index = sub {
	    my($dir) = @_;
	    my $new_inx;
	    my $i = -1;
	    for my $inx (@$all_image_inx) {
		$i++;
		if ($inx == $current_inx) {
		    my $ii = $i+$dir;
		    if ($ii >= 0) {
			$new_inx = $all_image_inx->[$ii];
			last;
		    }
		}
	    }
	    $new_inx;
	};

	my $prev_inx = $next_image_index->(-1);
	my $next_inx = $next_image_index->(+1);

	my @args = (\&show_image_viewer, -canvas => $c, -allimages => $all_image_inx, '-current');
	if (defined $prev_inx) {
	    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-command => [@args, $prev_inx],
								       -state => "normal");
	} else {
	    $image_viewer_toplevel->Subwidget("PrevButton")->configure(-state => "disabled");
	}
	if (defined $next_inx) {
	    $image_viewer_toplevel->Subwidget("NextButton")->configure(-command => [@args, $next_inx],
								       -state => "normal");
	} else {
	    $image_viewer_toplevel->Subwidget("NextButton")->configure(-state => "disabled");
	}

	$image_viewer_toplevel->Subwidget("DateLabel")->configure(-text => $date);

	$image_viewer_toplevel->{"photo"} = $p;
	$image_viewer_toplevel->deiconify;
	$image_viewer_toplevel->raise;
    }
}


1;
