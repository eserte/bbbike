# -*- perl -*-

#
# $Id: BBBikeRuler.pm,v 1.11 2003/06/17 21:29:17 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# Description (en): measure distances and angles
# Description (de): Entfernungen und Winkel messen
package BBBikeRuler;
use BBBikePlugin;
@BBBikeRuler::ISA = qw(BBBikePlugin);

use strict;
use vars qw($button_image $ruler_cursor $old_motion
	    $c_x $c_y $m_x $m_y $real_x $real_y $real_height
	    $aftertask $circle $gpsman_tracks $gpsman_track_tag $old_message);

use BBBikeUtil;
use Hooks;

sub register {
    my $pkg = __PACKAGE__;

    $BBBikePlugins::plugins{$pkg} = $pkg;

    if (!defined $button_image) {
	# ruler image is from tkruler
	$button_image = $main::top->Pixmap
	    (-data => <<EOF);
/* XPM */
static char * mini_ruler_xpm[] = {
"16 16 3 1",
" 	s None c None",
".	c #000000",
"+	c #FFDEAD",
"                ",
"                ",
"                ",
"                ",
"................",
".+++.+++.+++.+++",
".+++.+++.+++.+++",
"++++.+++++++++++",
"++++++++++++++++",
"++++++++++++++++",
"++++++++++++++++",
"++++++++++++++++",
"                ",
"                ",
"                ",
"                "};
EOF
    }

    $main::map_mode_callback{$pkg} = \&map_mode_activate;

    if (!defined $ruler_cursor) {
	$ruler_cursor = <<EOF;
#define ruler_width 17
#define ruler_height 8
#define ruler_x_hot 0
#define ruler_y_hot 4
static unsigned char ruler_bits[] = {
   0xff, 0xff, 0x01, 0x11, 0x11, 0x01, 0x11, 0x11, 0x01, 0x01, 0x00, 0x01,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
EOF
    }

    add_button();

    # XXX Leider reicht das hier nicht. Anscheinend ist
    # std_transparent_binding zu eingeschränkt, es wird nur nach Straßen
    # unterhalb geschaut, aber nicht nach anderen Punkten, die auch einen
    # Balloon haben könnten
    main::std_transparent_binding("ruler");
}

sub activate {
    $main::map_mode = __PACKAGE__;
    main::set_cursor_data($ruler_cursor);
    main::status_message("Cursor bewegen", "info");
    $old_motion = $main::c->CanvasBind("<Motion>");
    $main::c->CanvasBind("<Motion>" => \&motion);
    undef $real_height;

    Hooks::get_hooks("after_resize")->add(\&resize, __PACKAGE__);
}

sub deactivate {
    $main::c->delete("ruler");
    $main::c->CanvasBind("<Motion>" => $old_motion);

    Hooks::get_hooks("after_resize")->del(__PACKAGE__);
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;
    my $Radiobutton = $main::Radiobutton;
    my $b = $mf->$Radiobutton
	(main::image_or_text($button_image, 'Ruler'),
	 -variable => \$main::map_mode,
	 -value => __PACKAGE__,
	 -command => \&main::set_map_mode);
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "Ruler")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     # XXX Msg.pm
	     [[Checkbutton => "~Kreis",
	       -variable => \$circle, -command => sub { toggle_circle() }],
	      [Checkbutton => "~GPSMan-Tracks vermessen",
	       -variable => \$gpsman_tracks],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	    );
}

sub map_mode_activate {
    $main::map_mode_deactivate->() if $main::map_mode_deactivate;
    activate();
    $main::map_mode_deactivate = \&deactivate;
}

sub button {
    my($c,$e) = @_;
    ($c_x,$c_y) = ($c->canvasx($e->x), $c->canvasy($e->y));
    if ($aftertask) {
	$c->afterCancel($aftertask);
	undef $aftertask;
    }
    my $l = 3;
    my $fill = "blue";
    $c->delete("ruler");
    my(@tags) = $c->gettags($c->current_item(-ignorerx => "^ruler\$"));
    if ($gpsman_tracks) {
	if ($tags[1] && $tags[1] =~ /abstime=/) {
	    $gpsman_track_tag = $tags[1];
	} else {
	    undef $gpsman_track_tag;
	    return;
	}
    }
    if (@tags >= 2 && $tags[0] =~ /^L\d+/ && $tags[2] =~ /^([-+]?[\d\.]+)/) {
	$real_height = $1;
    } else {
	undef $real_height;
    }
    $c->createOval($c_x,$c_y,$c_x,$c_y, -tags => ["ruler", "ruler-circle"],
		   -outline => $fill,
		   -state => $circle ? "normal" : "hidden");
    $c->createLine($c_x-$l,$c_y-$l,$c_x+$l,$c_y+$l,
		   -width => 2, -fill => $fill,
		   -tags => ["ruler","rulerpoint"]);
    $c->createLine($c_x-$l,$c_y+$l,$c_x+$l,$c_y-$l,
		   -width => 2, -fill => $fill,
		   -tags => ["ruler","rulerpoint"]);
    $c->createLine($c_x-$l,$c_y+$l,$c_x-$l,$c_y+$l, -fill => $fill,
		   -tags => ["ruler","rulerline"]);
    ($real_x, $real_y) = main::anti_transpose($c_x, $c_y);
}

sub _fmt_time {
    my $secs = shift;
    if ($secs < 3600) {
	s2ms($secs) . " min";
    } else {
	s2hm($secs) . " h";
    }
}

sub motion {
    my($c) = @_;
    my $message = "";
    return if !defined $real_x;
    my $e = $c->XEvent;
    ($m_x,$m_y) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my($new_real_x, $new_real_y) = main::anti_transpose($m_x, $m_y);
    my $deg = atan2($new_real_y-$real_y, $new_real_x-$real_x);
    $deg = 2*pi-$deg+pi/2;
    if ($deg < 0) {
	$deg += 2*pi;
    }

    # Distance-related
    my $dist = sqrt(sqr($new_real_x-$real_x)+
		    sqr($new_real_y-$real_y));

    if ($gpsman_tracks && $gpsman_track_tag) {
	my(@tags) = $c->gettags($c->current_item(-ignorerx => "^ruler\$"));
	if ($gpsman_tracks && $tags[1] && $tags[1] =~ /dist=([\d\.]+).*?time=([\d:]+).*abstime=([\d:]+)/) {
	    my($dist2,$time2,$abstime2) = ($1, $2, $3);
	    $time2 = _min2sec($time2);
	    $abstime2 = _hms2sec($abstime2);
	    $gpsman_track_tag =~ /dist=([\d\.]+).*?time=([\d:]+).*abstime=([\d:]+)/;
	    my($dist1,$time1,$abstime1) = ($1, $2, $3);
	    if ($time2 != $time1 && $abstime2 != $abstime1) {
		$time1 = _min2sec($time1);
		$abstime1 = _hms2sec($abstime1);
		if ($abstime2 < $abstime1) { $abstime2 += 86400 }
		$message  = "Zeit: " . _fmt_time($time2-$time1) . "; ";
		$message .= sprintf "Dist: %.3fkm; ", $dist2-$dist1;
		$message .= sprintf "Speed: %.1fkm/h; ", ((($dist2-$dist1)*1000/($time2-$time1))*3.6);
		$message .= "Abszeit: " . _fmt_time($abstime2-$abstime1) . "; ";
		$message .= sprintf "Absspeed: %.1fkm/h; ", ((($dist2-$dist1)*1000/($abstime2-$abstime1))*3.6);
		$message .= sprintf "Luft-Dist: %.3fkm; ", $dist/1000;
		$message .= sprintf "Luft-Speed: %.1fkm/h", (($dist/($time2-$time1))*3.6);
		$old_message = $message;
	    } else {
		$message = "(" . $old_message . ")";
	    }
	} else {
	    $message = "(" . $old_message . ")";
	}
    } else {
	$message = sprintf("Winkel: %d°; Dist: %dm",
			   rad2deg($deg)%360, $dist);
	if (@main::speed) {
	    for my $speed (@main::speed) {
		$message .= ", \@ $speed km/h: " . _fmt_time($dist/($speed/3.6));
	    }
	}
	# Manhatten-Distance-related
	my $manh_dist = abs($new_real_x-$real_x)+abs($new_real_y-$real_y);
	$message .= sprintf "; Manh.-Dist: %dm", $manh_dist;
	if (@main::speed) {
	    for my $speed (@main::speed) {
		$message .= ", \@ $speed km/h: " . _fmt_time($manh_dist/($speed/3.6));
	    }
	}

	# misc:
	if (defined $real_height) {
	    $message .= sprintf ", Höhe: %.1fm", $real_height;
	}
    }

    main::status_message($message, "info");
    $c->coords("rulerline", $c_x, $c_y, $m_x, $m_y);
    if ($circle) {
	my $r = sqrt(sqr($m_x-$c_x)+sqr($m_y-$c_y));
	$main::c->coords("ruler-circle", $c_x-$r,$c_y-$r,$c_x+$r,$c_y+$r);
    }
    if ($aftertask) {
	$c->afterCancel($aftertask);
    }
    $aftertask = $c->after(150, sub { show_height($c, $dist, $message) });
}

sub show_height {
    my($c, $dist, $message) = @_;
    my $height;
    my(@tags) = $c->gettags($c->current_item(-ignorerx => "^ruler\$"));
    if (@tags >= 2 && $tags[0] =~ /^L\d+/ && $tags[2] =~ /^([-+]?[\d\.]+)/) {
	$height = $1;
    }
    if (defined $real_height && defined $height && $dist) {
	my $delta = abs($real_height-$height);
	my $message = $message;
	$message .= sprintf(", Höhenunterschied: -> %.1fm = %.1fm (%.1f%%)",
			    $height, $delta,
			    $delta/$dist*100
			   );
	main::status_message($message, "info");
    }
}

sub resize {
    my($scalefactor) = @_;
    $c_x *= $scalefactor;
    $c_y *= $scalefactor;
    ($real_x, $real_y) = main::anti_transpose($c_x, $c_y);
}

sub toggle_circle {
    if ($circle) {
	if ($main::map_mode eq __PACKAGE__) {
	    my $r = sqrt(sqr($m_x-$c_x)+sqr($m_y-$c_y));
	    $main::c->coords("ruler-circle", $c_x-$r,$c_y-$r,$c_x+$r,$c_y+$r);
	    $main::c->itemconfigure("ruler-circle", -state => "normal");
	}
    } else {
	if ($main::map_mode eq __PACKAGE__) {
	    $main::c->itemconfigure("ruler-circle", -state => "hidden");
	}
    }
}

sub _min2sec {
    my($min) = @_;
    my($m,$s) = split /:/, $min;
    $m*60+$s;
}

sub _hms2sec {
    my($hms) = @_;
    my($h,$m,$s) = split /:/, $hms;
    $h*3600+$m*60+$s;
}

1;

__END__
