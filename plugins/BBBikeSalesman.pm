# -*- perl -*-

#
# $Id: BBBikeSalesman.pm,v 1.11 2008/02/28 20:56:35 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2008 Slaven Rezic. All rights reserved.
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
	$button_image = main::load_photo($main::top, 'salesman');
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
    main::status_message(M("Punkte auswählen"), "info");
}

sub add_button {
    my $mf = $main::top->Subwidget("ModePluginFrame");
    return unless defined $mf;

    my $Radiobutton = $main::Radiobutton;
    my $salesman_check;
    my %radio_args =
	(-variable => \$main::map_mode,
	 -value    => __PACKAGE__,
	 -command  => \&main::set_map_mode,
	);
    $salesman_check = $mf->$Radiobutton
	(main::image_or_text($button_image, 'Salesman'),
	 %radio_args,
	);
    BBBikePlugin::replace_plugin_widget($mf, $salesman_check,
					__PACKAGE__ . '_on');
    BBBikePlugin::add_to_global_plugins_menu
	    (-title   => M("Kürzeste Rundreise"),
	     -topmenu => [Radiobutton => M('Kürzester Rundreisen-Modus'),
			  %radio_args,
			 ],
	    );
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
	if (!main::perlmod_install_advice('List::Permutor')) { # This is pure-perl, easier to install...
	    warn $@;
	    $cant_salesman = 1;
	    $reset->();
	    return;
	}
    }

    $salesman = new Salesman
	-net         => $main::net,
	-addnewpoint => sub { my($net, $point) = @_;
			      my $xy = main::set_coords_str($main::c); # set_coords_str also handles fragezeichen
			      return $xy if $xy;
			      main::add_new_point($net, $point); # fallback to old method
			  },
	-tk          => $main::top,
	-progress    => $main::progress,
	-searchargs  => \%main::global_search_args;
    main::make_net() if (!$main::net);
    $main::net->reset;
    main::set_cursor('salesman');

    my $t = main::redisplay_top($main::top, "salesman-end",
				-title => M("Kürzeste Rundreise"));
    return if !defined $t;
    $main::map_mode_deactivate =
	sub { $t->destroy if Tk::Exists($t) };
    $t->OnDestroy($reset);
    my $b;
    Tk::grid($t->Label(-text => M("Stationen").":"),
	     $t->Label(-textvariable => \$salesman->{NumberOfPoints}),
	     $b = $t->Button
	     (-text => M"Berechnen",
	      -command => sub {
		  if ($salesman->get_number_of_points < 3) {
		      main::status_message(M("Mindestens drei Punkte sind für die Berechnung notwendig"), "err");
		      return;
		  }
		  main::delete_route(); # XXX it would be nicer if the user could continue the existing route
		  my $newb = $t->Button
		      (-text => M"Abbruch",
		       -command => sub { $main::escape = 1 },
		      )->grid(-row => 0, -column => 2, -sticky => "eswn");
		  main::IncBusy($main::top, -except => {$t=>1});
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
		  $t->destroy if Tk::Exists($t);
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
