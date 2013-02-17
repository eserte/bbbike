# -*- perl -*-

#
# $Id: BBBikeVia.pm,v 1.20 2008/08/29 20:16:08 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeVia;

use strict;
use vars qw($VERSION $move_index $add_point);
$VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

package main;
use BBBikeGlobalVars;
#XXX
#  use vars qw(%cursor %cursor_mask $map_mode $c %do_flag %flag_photo
#  	    @search_route_points %set_route_point
#  	    $map_mode_deactivate $net @realcoords
#  	    $advanced);
use subs qw(M SRP_TYPE SRP_COORD);
## XXX Dumps core on 5.10.0:
#use subs qw(POINT_MANUELL POINT_SEARCH);

BBBikeVia::load_cursors(); # XXX move somewhere...

sub BBBikeVia::menu_entries {
    my $menu = shift;
    $menu->checkbutton(-label => M"Startflagge",
		       -variable => \$do_flag{'start'},
		       -command => sub {
			   set_flag('start');
		       },
		      );
    $menu->checkbutton(-label => M"Vias einblenden",
		       -variable => \$do_flag{'via'},
		       -command  => \&BBBikeVia::set_via_flags
		      );
    $menu->checkbutton(-label => M"Zielflagge",
		       -variable => \$do_flag{'ziel'},
		       -command => sub {
			   set_flag("ziel");
		       },
		      );

    $menu->radiobutton(-label => M"Start/Vias/Ziel verschieben",
		       -variable => \$map_mode,
		       -value    => "MM_VIA_MOVE",
		       -command  => sub {
			   set_map_mode();
			   BBBikeVia::move_via();
		       },
		      );
    $menu->radiobutton(-label => M"Start verschieben",
		       -variable => \$map_mode,
		       -value    => "MM_START_MOVE",
		       -command  => sub {
			   set_map_mode();
			   BBBikeVia::move_via();
		       },
		      );
    $menu->radiobutton(-label => M"Ziel verschieben",
		       -variable => \$map_mode,
		       -value    => "MM_GOAL_MOVE",
		       -command  => sub {
			   set_map_mode();
			   BBBikeVia::move_via();
		       },
		      );
    $menu->radiobutton(-label => M"neue Vias setzen",
		       -variable => \$map_mode,
		       -value    => "MM_VIA_ADD",
		       -command  => sub {
			   set_map_mode();
			   BBBikeVia::add_via();
		       },
		      );
    if ($advanced) {
	$menu->radiobutton(-label => M"neue Vias setzen und verschieben",
			   -variable => \$map_mode,
			   -value    => "MM_VIA_ADD_THEN_MOVE",
			   -command  => sub {
			       set_map_mode();
			       BBBikeVia::add_via();
			   },
			  );
    }
    $menu->radiobutton(-label => M"Vias löschen",
		       -variable => \$map_mode,
		       -value    => "MM_VIA_DEL",
		       -command  => sub {
			   set_map_mode();
			   BBBikeVia::delete_via();
		       },
		      );
}

# __END__ here for "use load"

sub BBBikeVia::load_cursors {
    foreach my $def (qw(via_add_nb1 via_add_nb2 via_add	via_del	via_move via_move_2)) {
	load_cursor($def);
    }
}

sub BBBikeVia::set_via_flags { # according to $do_flag{via} value
    if ($do_flag{'via'}) {
	BBBikeVia::show_via_flags();
    } else {
	BBBikeVia::delete_via_flags();
    }
}

sub BBBikeVia::show_via_flags {
    $c->delete("viaflag");
    for my $i (1 .. $#search_route_points-1) {
	my $p1 = $search_route_points[$i];
	if ($p1->[SRP_TYPE] eq POINT_MANUELL() ||
	    $p1->[SRP_TYPE] eq POINT_SEARCH()
	   ) {
	    my($x,$y) = transpose(split(/,/, $p1->[SRP_COORD]));
	    $c->createImage($x, $y,
			    -anchor => 'c',
			    -image => $flag_photo{"via"},
			    -tags => ['route', "", "viaflag", "via-$i"],
			   );
	}
    }
}

sub BBBikeVia::delete_via_flags {
    $c->delete("viaflag");
}

######################################################################
# move

sub BBBikeVia::move_via {
    if ($map_mode eq "MM_GOAL_MOVE") {
	return BBBikeVia::move_via_2($c, "ziel", -1);
    } elsif ($map_mode eq 'MM_START_MOVE') {
	return BBBikeVia::move_via_2($c, "start", 0);
    }
    set_cursor("via_move");
    $set_route_point{$map_mode} = sub {
	# do nothing
    };
    execute_and_set_map_mode_deactivate
	(sub {
	     for (qw(start via ziel)) {
		 $c->bind($_."flag", "<ButtonPress-1>", "");
	     }
	 }
	);
    for (qw(start via ziel)) {
	$c->bind($_."flag", "<ButtonPress-1>" => [\&BBBikeVia::move_via_2, $_]);
    }
    status_message(M"Zu verschiebendes Via bzw. Start oder Ziel wählen", "info");
}

sub BBBikeVia::move_via_2 {
    my($c, $type, $move_index) = @_;

    if (defined $move_index) {
	$BBBikeVia::move_index = $move_index;
    } else {
	$BBBikeVia::move_index = BBBikeVia::_find_point_from_tags();
	return if !defined $BBBikeVia::move_index;
    }

    set_cursor("via_move_2");
    $set_route_point{$map_mode} = \&BBBikeVia::move_via_action;
    $alt_set_route_point{$map_mode} = \&BBBikeVia::move_via_alt_action;
    for (qw(start via ziel)) {
	$c->bind($_."flag", "<ButtonPress-1>" => "");
    }
    my $point_text = !defined $type ? M("Punkt zum Verschieben wählen") : Mfmt("Punkt wählen, wohin %s verschoben werden soll", ($type eq 'start' ? M("der Start") : M("das " . ucfirst($type))));
    status_message($point_text, "info");
}

sub BBBikeVia::move_via_action {
    my $coord = set_coords($c);
    if (!defined $coord) {
	status_message(M("Punkt muss auf einer Straße liegen"), "info");
	# do not change status
    } else {
	if (!$search_route_points[$BBBikeVia::move_index]) {
	    status_message(M"Kein Punkt zu verschieben", "die");
	}
	$search_route_points[$BBBikeVia::move_index]->[SRP_COORD] = $coord;
	re_search();
	BBBikeVia::move_via_cont();
    }
}

# XXX still flaky!
sub BBBikeVia::move_via_alt_action {
    my $c = shift;
    my $e = $c->XEvent;
    my($xx, $yy) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my($ax, $ay) = map { int } anti_transpose($xx, $yy);
    my $coord = "$ax,$ay";
    $search_route_points[$BBBikeVia::move_index]->[SRP_COORD] = $coord;
    $search_route_points[$BBBikeVia::move_index]->[SRP_TYPE] = POINT_MANUELL();
    re_search();
    BBBikeVia::move_via_cont();
}

sub BBBikeVia::move_via_cont {
    if ($map_mode =~ /ADD_THEN_MOVE$/) {
	BBBikeVia::add_via();
    } else {
	BBBikeVia::move_via();
    }
}

######################################################################
# add

sub BBBikeVia::add_via {
    set_cursor("via_add");
    $set_route_point{$map_mode} = \&BBBikeVia::add_via_2;
    execute_and_set_map_mode_deactivate
	(sub {
	     for (qw(start via ziel)) {
		 $c->bind($_."flag", "<ButtonPress-1>", "");
	     }
	     BBBikeVia::unmark_all();
	 }
	);
    status_message(M"Neuen Via-Punkt wählen", "info");
}

sub BBBikeVia::add_via_2 {
    my $coord = set_coords($c);
    if (!defined $coord) {
	status_message(M("Punkt muss auf einer Straße liegen"), "info");
	# do not change status
	return;
    }
    delete $set_route_point{$map_mode};
    $BBBikeVia::add_point = $coord;

    if (@search_route_points == 2) {
	splice @search_route_points,
	    1,
	    0,
	    [$BBBikeVia::add_point, POINT_SEARCH()];
	re_search();
	return BBBikeVia::add_via_cont(1);
    }

    my($found_tag, @tags) = find_below($c, 'route');
    if ($found_tag) {
	# Click on route
	if ($tags[1] =~ /route-(\d+)/) {
	    my $route_nr = $1;
	    my %srp_to_index;
	    for my $inx (0 .. $#search_route_points) {
		$srp_to_index{$search_route_points[$inx]->[0]} = $inx;
	    }
	    for my $i ($route_nr .. $#realcoords) { # XXX off-by-one?
		my $xy = join(",", @{$realcoords[$i]});
		if (exists $srp_to_index{$xy}) {
		    splice @search_route_points,
			$srp_to_index{$xy},
			0,
			[$BBBikeVia::add_point, POINT_SEARCH()];
		    re_search();
		    return BBBikeVia::add_via_cont($srp_to_index{$xy});
		}
	    }
	    warn "Can't find route-$route_nr in realcoords\n";
	} else {
	    warn "Can't find route number in @tags\n";
	}
    }

    BBBikeVia::mark_new_via_point();

    BBBikeVia::add_via_2_2();
}

sub BBBikeVia::add_via_2_2 {
    set_cursor("via_add_nb1");
    for (qw(start via ziel)) {
	$c->bind($_."flag", "<ButtonPress-1>" => \&BBBikeVia::add_via_3);
    }
    BBBikeVia::unmark_neighbours();
    status_message(M"Ersten Nachbarn (Start, Via oder Ziel) wählen", "info");
}

sub BBBikeVia::add_via_3 {
    $BBBikeVia::add_nb1_index = BBBikeVia::_find_point_from_tags();
    return if !defined $BBBikeVia::add_nb1_index;
    set_cursor("via_add_nb2");
    for (qw(start via ziel)) {
	$c->bind($_."flag", "<ButtonPress-1>" => \&BBBikeVia::add_via_action);
    }
    my $common = M"Zweiten Nachbarn (Start, Via oder Ziel) wählen";
    if ($BBBikeVia::add_nb1_index == 0) {
	status_message($common . " " . M"bzw. noch einmal Start für neuen Startpunkt",
		       "info");
    } elsif ($BBBikeVia::add_nb1_index == $#search_route_points) {
	status_message($common . " " . M"bzw. noch einmal Ziel für neuen Zielpunkt",
		       "info");
    } else {
	status_message($common, "info");
    }
    BBBikeVia::mark_neighbours();
}

sub BBBikeVia::mark_neighbours {
    BBBikeVia::unmark_neighbours();
    my $mark_point = sub {
	my($index) = @_;
	my($x, $y) = transpose(split /,/, $search_route_points[$index]->[0]);
	$c->createLine($x,$y,$x,$y,
		       -capstyle => $capstyle_round,
		       -width => 10,
		       -fill => "red",
		       -tags => ["neighbourmarker", BBBikeVia::_get_tag_name_from_index($index)],
		      );
    };
    if ($BBBikeVia::add_nb1_index > 0) {
	$mark_point->($BBBikeVia::add_nb1_index-1);
    } else {
	$mark_point->(0);
    }
    if ($BBBikeVia::add_nb1_index < $#search_route_points) {
	$mark_point->($BBBikeVia::add_nb1_index+1);
    } else {
	$mark_point->($#search_route_points);
    }
}

sub BBBikeVia::mark_new_via_point {
    my($x, $y) = transpose(split /,/, $BBBikeVia::add_point);
    $c->createLine($x,$y,$x,$y,
		   -capstyle => $capstyle_round,
		   -width => 10,
		   -fill => "green",
		   -tags => "vianewpoint",
		  );
}

sub BBBikeVia::unmark_neighbours {
    $c->delete("neighbourmarker");
}

sub BBBikeVia::unmark_all {
    BBBikeVia::unmark_neighbours();
    $c->delete("vianewpoint");
}

sub BBBikeVia::add_via_action {
    $BBBikeVia::add_nb2_index = BBBikeVia::_find_point_from_tags();
    return if !defined $BBBikeVia::add_nb2_index;

    my $move_index;
    if (abs($BBBikeVia::add_nb1_index - $BBBikeVia::add_nb2_index) == 1) {
	$move_index = max($BBBikeVia::add_nb1_index, $BBBikeVia::add_nb2_index);
	splice @search_route_points,
	    $move_index,
	    0,
	    [$BBBikeVia::add_point, POINT_SEARCH()];
    } elsif ($BBBikeVia::add_nb1_index == 0 && $BBBikeVia::add_nb2_index == 0) {
	unshift @search_route_points, [$BBBikeVia::add_point, POINT_MANUELL()];
	$search_route_points[1]->[SRP_TYPE] = POINT_SEARCH();
	$move_index = 1;
    } elsif ($BBBikeVia::add_nb1_index == $#search_route_points && $BBBikeVia::add_nb2_index == $#search_route_points) {
	push @search_route_points, [$BBBikeVia::add_point, POINT_SEARCH()];
	$move_index = $#search_route_points;
    } else {
	status_message(M"Keine Nachbarn, bitte noch einmal versuchen", "error");
	return BBBikeVia::add_via_2_2();
    }

    re_search();
    BBBikeVia::add_via_cont($move_index);
}

sub BBBikeVia::add_via_cont {
    my $move_index = shift;
    if ($map_mode =~ /THEN_MOVE$/) {
	BBBikeVia::move_via_2($main::c, '', $move_index);
    } else {
	BBBikeVia::add_via();
    }
}

######################################################################
# delete

sub BBBikeVia::delete_via {
    set_cursor("via_del");
    $set_route_point{$map_mode} = sub {
	# do nothing
    };
    execute_and_set_map_mode_deactivate
	(sub {
	     $c->bind("viaflag", "<ButtonPress-1>", "");
	 }
	);
    $c->bind("viaflag", "<ButtonPress-1>" => \&BBBikeVia::delete_action);
    status_message(M"Zu löschenden Via-Punkt auswählen", "info");
}

sub BBBikeVia::delete_action {
    my $del_point = BBBikeVia::_find_point_from_tags();
    return if !defined $del_point;

    splice @search_route_points, $del_point, 1;

    re_search();
    BBBikeVia::delete_via();
}

######################################################################

sub BBBikeVia::_find_point_from_tags {
    my($found_item, @tags) = find_below_rx($c, ['^via-\d+', '^(?:start|ziel)flag$']);
    if (defined $found_item) {
	for my $tag (@tags) {
	    if ($tag =~ /^via-(\d+)/) {
		return $1;
	    } elsif ($tag eq 'startflag') {
		return 0;
	    } elsif ($tag eq 'zielflag') {
		return $#search_route_points;
	    }
	}
    }
    warn "Can't find point in @tags";
    return undef;
}

sub BBBikeVia::_get_tag_name_from_index {
    my($index) = @_;
    if ($index == 0) {
	"startflag";
    } elsif ($index == $#search_route_points) {
	"zielflag";
    } else {
	("viaflag", "via-$index");
    }
}


1;

__END__
