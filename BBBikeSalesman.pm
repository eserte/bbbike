# -*- perl -*-

#
# $Id: BBBikeSalesman.pm,v 1.6 2003/01/08 20:00:19 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# Description (en): Traveling Salesman Problem
# Description (de): Problem des Handlungsreisenden
package BBBikeSalesman;
use base qw(BBBikePlugin);

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use strict;
use vars qw($button_image $salesman_cursor $cant_salesman $salesman);

sub register {
    my $pkg = __PACKAGE__;

    $BBBikePlugin::plugins{$pkg} = $pkg;

    if (!defined $button_image) {
	# ruler image is from tkruler
	$button_image = main::load_photo
	    ($main::top, 'salesman.'.$main::default_img_fmt);
    }

    $main::map_mode_callback{$pkg} = \&map_mode_activate;

    if (!defined $salesman_cursor) {
	main::load_cursor("salesman");
    }

    add_button();
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    if ($main::map_mode eq $pkg &&
	$main::map_mode_deactivate) {
	$main::map_mode_deactivate->();
    }
    my $mf = $main::top->Subwidget("ModePluginFrame");
    my $subw = $mf->Subwidget($pkg . '_on');
    if (Tk::Exists($subw)) { $subw->destroy }
    delete $BBBikePlugin::plugins{$pkg};
}

sub activate {
    $main::map_mode = __PACKAGE__;
    main::set_cursor_data($salesman_cursor);
    main::status_message("Punkte auswählen", "info");
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;

    my $Radiobutton = $main::Radiobutton;
    my $salesman_photo = main::load_photo($mf, 'salesman.' . $main::default_img_fmt);
    my $salesman_check;
    $salesman_check = $mf->$Radiobutton
	(main::image_or_text($salesman_photo, 'Salesman'),
	 -variable => \$main::map_mode,
	 -value => __PACKAGE__,
	 -command => \&main::set_map_mode,
	)->pack(-side => "left", -anchor => 'sw');
    $mf->Advertise(__PACKAGE__ . '_on' => $salesman_check);
    $main::balloon->attach($salesman_check, -msg => M"Kürzeste Rundreise")
	if $main::balloon;
    $main::ch->attach($salesman_check, -pod => "^\\s*Salesman-Symbol");
}

sub map_mode_activate {
    $main::map_mode_deactivate->() if $main::map_mode_deactivate;

    my $reset = sub {
	main::set_map_mode(main::MM_SEARCH());
    };
    if ($cant_salesman) {
	$reset->();
	return;
    }
    eval {
	require Salesman;
    };
    if ($@) {
	if (!main::perlmod_install_advice('List::Permutor')) {
	    warn $@;
	    $cant_salesman = 1;
	    $reset->();
	    return;
	}
    }

    $salesman = new Salesman
	-net         => $main::net,
	-addnewpoint => \&main::add_new_point,
	-tk          => $main::top,
	-progress    => $main::progress,
	-searchargs  => \%main::global_search_args;
    main::make_net() if (!$main::net);
    $main::net->reset;
    main::set_cursor('salesman');

    my $t = main::redisplay_top($main::top, "salesman-end",
				-title => "Salesman");
    return if !defined $t;
    $main::map_mode_deactivate =
	sub { $t->destroy if Tk::Exists($t) };
    $t->OnDestroy($reset);
    my $b;
    Tk::grid($t->Label(-text => "Stationen:"),
	     $t->Label(-textvariable => \$salesman->{NumberOfPoints}),
	     $b = $t->Button
	     (-text => M"Berechnen",
	      -command => sub {
		  main::delete_route(); # XXX it would be nicer if the user could continue the existing route
		  my $newb = $t->Button
		      (-text => M"Abbruch",
		       -command => sub { $main::escape = 1 },
		      )->grid(-row => 0, -column => 2, -sticky => "eswn");
		  main::IncBusy($main::top);
		  #$t->Busy;
		  eval {
		      my(@path) = $salesman->best_path;
		      if (@path) {
			  push @main::search_route_points, [$path[0], main::POINT_MANUELL()];
			  foreach (@path[1..$#path]) {
			      push @main::search_route_points, [$_, main::POINT_SEARCH()];
			  }
			  main::re_search();
		      }
		  };
		  my $err = $@;
		  #$t->Unbusy;
		  main::DecBusy($main::top);
		  $t->destroy;
		  $reset->();

		  if ($err) {
		      die $err;
		  }
	      }),
	    );
    $t->bind('<<CloseWin>>' => sub { $t->destroy });
    $t->protocol('WM_DELETE_WINDOW' => sub { $t->destroy });
    $t->Popup(@main::popup_style);
}

sub itembutton {
    my($c,$e) = @_;
    my($xx, $yy) = ($c->canvasx($e->x), $c->canvasy($e->y));
    if ($salesman->add_point(join(",", main::anti_transpose($xx, $yy)))) {
	main::set_flag('start', $xx, $yy, "leaveold");
    }
}

1;

__END__
