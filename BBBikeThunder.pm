# -*- perl -*-

#
# $Id: BBBikeThunder.pm,v 1.10 2003/08/24 23:33:50 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# This is my first attempt in writing a bbbike "plugin"
# Description (en): measure the distance from lightning
# Description (de): Entfernung zum Blitz grafisch messen
package BBBikeThunder;
use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($stage $old_scale
	    $real_x $real_y $canvas_x $canvas_y $canvas_radius $real_radius
	    $lightning_time $lightning_repeat
	    $button_image $lightning_cursor $thunder_cursor);

use enum qw(:STAGE_ POSITION LIGHTNING THUNDER THUNDER_DIRECTION
	    DIRECTION LIGHTNING_DIRECTION);

use constant MAX_TIME => 30;

use Hooks;
use BBBikeUtil;

sub register {

    if (!defined $button_image) {
	$button_image = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDwAPAOMAAP///8u+GvTxE8e6Gvf1Yca4G/XyKvTxGMy/Gff1X9DEGe/rE8m7Gvj2
cPTxE/TxEyH5BAEKAA8ALAAAAAAPAA8AAAQ2EMgZhB0zU0uKzoVxCN63WaUJIGjhmkVCFqip
WNbCwK3QpCASgAbUeIiqYPGDTA5rzqZzmIwAADs=
EOF
    }

    if (!defined $lightning_cursor) {
	$lightning_cursor = <<EOF;
#define lightning_cursor_width 16
#define lightning_cursor_height 16
#define lightning_cursor_x_hot 5
#define lightning_cursor_y_hot 15
static unsigned char lightning_cursor_bits[] = {
   0x80, 0x0f, 0x80, 0x07, 0xc0, 0x03, 0xc0, 0x01, 0xe0, 0x00, 0xe0, 0x60,
   0x70, 0x3c, 0x30, 0x1f, 0xf8, 0x0d, 0x38, 0x06, 0x04, 0x02, 0x00, 0x01,
   0x80, 0x01, 0x80, 0x00, 0x40, 0x00, 0x20, 0x00};
EOF
    }

    if (!defined $thunder_cursor) {
	$thunder_cursor = <<EOF;
#define thunder_cursor_width 16
#define thunder_cursor_height 16
#define thunder_cursor_x_hot 7
#define thunder_cursor_y_hot 10
static unsigned char thunder_cursor_bits[] = {
   0x00, 0x03, 0x80, 0x03, 0x80, 0x01, 0xc0, 0x00, 0xc0, 0x1c, 0x60, 0x0f,
   0xe0, 0x0d, 0x10, 0x06, 0x00, 0x03, 0x00, 0x01, 0x80, 0x00, 0x08, 0x10,
   0x30, 0x0c, 0xc6, 0x63, 0x0c, 0x30, 0xf0, 0x0f};
EOF
    }

    add_button();
}

sub activate {
    $main::map_mode = 'BBBikeThunder';
    $stage = STAGE_POSITION;
    my $cursorfile = defined &main::build_text_cursor ? main::build_text_cursor("Curr Pos") : undef;
    $main::c->configure(-cursor => $cursorfile);
    main::status_message("Derzeitige Position markieren", "info");
    Hooks::get_hooks("after_resize")->add
	    (sub {
		 if (defined $real_x) {
		     ($canvas_x, $canvas_y) = main::transpose($real_x, $real_y);
		     position($main::c);
		 }
	     },
	     "BBBikeThunder");
}

sub deactivate {
    stop_circle();
    Hooks::get_hooks("after_resize")->del("BBBikeThunder");
}

sub add_button {
    my $mf  = $main::top->Subwidget("ModePluginFrame");
    my $mmf = $main::top->Subwidget("ModeMenuPluginFrame");
    return unless defined $mf;
    my $Radiobutton = $main::Radiobutton;
    my $b = $mf->$Radiobutton
	(main::image_or_text($button_image, 'Thunder'),
	 -variable => \$main::map_mode,
	 -value => 'BBBikeThunder',
	 -command => sub {
	     $main::map_mode_deactivate->() if $main::map_mode_deactivate;
	     activate();
	     $main::map_mode_deactivate = \&deactivate;
	 });
    BBBikePlugin::replace_plugin_widget($mf, $b, __PACKAGE__.'_on');
    $main::balloon->attach($b, -msg => "Lightning/Thunder")
	if $main::balloon;

    BBBikePlugin::place_menu_button
	    ($mmf,
	     [[Button => "~Reset", -command => sub { thunder_reset() }],
	     ],
	     $b,
	     __PACKAGE__."_menu",
	    );
}

sub button {
    if ($stage == STAGE_POSITION) {
	position(@_);
	main::set_cursor_data($lightning_cursor);
	$stage = STAGE_LIGHTNING;
	main::status_message("Auf einen Blitz warten...", "info");
    } elsif ($stage == STAGE_LIGHTNING) {
	lightning(@_);
    } elsif ($stage == STAGE_THUNDER) {
	thunder(@_);
    } elsif ($stage == STAGE_THUNDER_DIRECTION) {
	thunder(@_);
	direction(@_);
    } elsif ($stage == STAGE_DIRECTION) {
	direction(@_);
    } elsif ($stage == STAGE_LIGHTNING_DIRECTION) {
	lightning(@_);
	direction(@_);
    }
}

sub position {
    my $c = shift;
    $c->delete("thunder_position");
    if (@_) {
	my $e = shift;
	($canvas_x, $canvas_y) = ($c->canvasx($e->x),
				  $c->canvasy($e->y));
	($real_x, $real_y) = main::anti_transpose($canvas_x, $canvas_y);
    }
    $c->createLine($canvas_x,$canvas_y,
		   $canvas_x+1,$canvas_y,
		   -fill => 'blue', -capstyle => 'projecting',
		   -width => 8, -tags => ['thunder', 'thunder_position']);
}

sub direction {
    my($c, $e) = @_;

    my($x1,$y1) = ($canvas_x, $canvas_y);
    my($x2,$y2) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my $n0 = sqrt(sqr($x2-$x1) + sqr($y2-$y1));
    my($dx,$dy) = (($x2-$x1)/$n0, ($y2-$y1)/$n0);
    my($x3,$y3) = ($x1+$dx*($canvas_radius+15),$y1+$dy*($canvas_radius+15));
    $c->delete("thunder_line");
    my $ci = $c->createLine($x1,$y1, $x3,$y3,
			    -fill => 'blue', -width => 2,
			    -tags => ['thunder', 'thunder_line']);
    $c->lower($ci);
    $c->createText($x3,$y3, -text => m2km($real_radius),
		   -tags => ['thunder', 'thunder_line']);

}

sub lightning {
    my($c, $e) = @_;
    $lightning_time = Tk::timeofday();
    stop_circle();
    $c->delete("thunder_circle");
    my $ci = $c->createOval($canvas_x, $canvas_y, $canvas_x, $canvas_y,
			    -outline => 'blue', -width => 2,
			    -tags => ['thunder', 'thunder_circle']
			   );
    $c->lower($ci);
    $lightning_repeat = $c->repeat(50, [\&lightning_circle, $c]);
    $stage = STAGE_THUNDER_DIRECTION;
    main::status_message("Auf den zugehörigen Donner warten...", "info");
    main::set_cursor_data($thunder_cursor);
}

sub thunder {
    stop_circle();
    $stage = STAGE_LIGHTNING;
    main::status_message("Auf einen Blitz warten...", "info");
    main::set_cursor_data($lightning_cursor);
}

sub lightning_circle {
    my $c = shift;
    my $delta = Tk::timeofday() - $lightning_time;
    if ($delta > MAX_TIME) {
	stop_circle();
	return;
    }
    use constant SPEED_SOUND => 331;
    $real_radius   = $delta * SPEED_SOUND; 
    $canvas_radius = (main::transpose($real_radius, 0))[0] -
	             (main::transpose(0, 0))[0];
    $c->coords('thunder_circle',
	       $canvas_x-$canvas_radius, $canvas_y-$canvas_radius,
	       $canvas_x+$canvas_radius, $canvas_y+$canvas_radius);
    $c->idletasks;

}

sub stop_circle {
    if (defined $lightning_repeat) {
	$lightning_repeat->cancel;
	undef $lightning_repeat;
    }
}

sub thunder_reset {
    deactivate();
    $main::c->delete("thunder");
}

$main::Radiobutton = $main::Radiobutton if 0; # peacify -w

1;

__END__
