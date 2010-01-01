# -*- perl -*-

#
# $Id: BBBikePlugin.pm,v 1.20 2008/02/28 20:52:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikePlugin;
use strict;
use vars qw($VERSION %plugins);
$VERSION = 0.02;

use Class::Struct;
struct('BBBikePlugin::Plugin' => [Name => "\$", File => "\$", Description => "\$", Active => "\$"]);

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

use vars qw(%advertised_name_to_title);

sub register {
    die "This package does not define the register method";
}

sub find_all_plugins {
    my $topdir = shift || ".";
    my $top = shift;

    if (defined &main::IncBusy && defined $top) {
	main::IncBusy($top);
    }

    my @p;
    eval {
	@p = _find_all_plugins_perl($topdir);
    };

    my $err = $@;

    if (defined &main::IncBusy && defined $top) {
	main::DecBusy($top);
    }

    die $err if $err;

    @p = sort { $a->Name cmp $b->Name } @p;

    if (defined $top && Tk::Exists($top)) {
	my $t = $top->Toplevel(-title => 'Plugins');
	if ($main::transient) {
	    $t->transient($top);
	}
	my $lb = $t->Scrolled("Listbox", -scrollbars => "osoe")->pack(-fill => "both", -expand => 1);
	$lb->insert("end", map { $_->Name } @p);
	my $doit = sub {
	    my($cur) = $lb->curselection;
	    if (defined $cur) {
		main::load_plugin($p[$cur]->File);
	    }
	};
	$lb->bind("<Double-1>" => $doit);
	if ($main::balloon) {
	    $main::balloon->attach($lb->Subwidget("scrolled"),
				   -msg => [map { $_->Description || $_->File } @p]);
	}
	$t->Button(-text => M("Laden"),
		   -command => $doit)->pack(-fill => "x");
	$t->Button(Name => "close",
		   -command => sub { $t->destroy })->pack(-fill => "x");
    }
}

sub _find_all_plugins_perl {
    my $topdir = shift;

    require File::Find;
    my @p;
    my $wanted = sub {
	if (   $File::Find::name =~ m{^\Q$topdir\E/projects/} # the www.radzeit.de directories
	    || $File::Find::name =~ m{^\Q$topdir\E/BBBike-\d+\.\d+(-DEVEL)?/} # distdir
	    || $File::Find::name =~ m{/(CVS|RCS|\.svn|\.git)/}) {
	    $File::Find::prune = 1;
	    return;
	}
	if (/^.*\.pm$/
	    && $_ ne "BBBikePlugin.pm" # meta modules
	    && $_ ne "BBBikePluginLister.pm"
	    && open(PM, $_)) {
	    my $curr_file = $_;
	    my $descr_lang;
	    my $descr_fallback;
	    my $is_plugin;
	    local $_;
	    while(<PM>) {
		chomp;
		if (/BBBikePlugin/) {
		    $is_plugin++;
		    last if $descr_lang;
		}
		if ($Msg::lang && /Description\s+\($Msg::lang\)\s*[:=]\s*\"?([^\"]+)/) {
		    $descr_lang = $1;
		    last if $is_plugin;
		} elsif (/Description\s+\(de\)\s*[:=]\s*\"?([^\"]+)/) { # fallback to german
		    $descr_fallback = $1;
		    last if $is_plugin;
		}
	    }
	    close PM;
	    my $descr = $descr_lang || $descr_fallback;

	    if ($is_plugin) {
		my $p = BBBikePlugin::Plugin->new;
		$curr_file =~ s/\..*$//;
		$p->Name($curr_file);
		$p->File($File::Find::name);
		$p->Description($descr);
		push @p, $p;
	    }
	}
    };

    File::Find::find($wanted, $topdir);

    _plugin_active_check(\@p);

    @p;
}

sub _plugin_active_check {
    my($p_ref) = @_;
    for my $p (@$p_ref) {
	my $short_file = $p->File;
	$short_file =~ s{^\Q$FindBin::RealBin\E/*}{};
	if ($INC{$p->File} || $INC{$short_file}) {
	    $p->Active(1);
	}
    }
}

sub place_menu_button {
    my($frame, $menuitems, $refwidget, $advertised_name, %args) = @_;
    my $title = delete $args{-title};
    my $addglobalmenu = exists $args{-noaddglobalmenu} ? !delete $args{-noaddglobalmenu} : 1;
    my $topmenu = delete $args{-topmenu};
    my $subtitlehack = delete $args{-subtitlehack};
    $refwidget->idletasks;    # XXX idletasks needed?
    my($x,$width) = ($refwidget->x, $refwidget->width);
    # If $refwidget is not yet mapped:
    if ($width <= 1) { $width = $refwidget->reqwidth }
    my $old_w = $frame->Subwidget($advertised_name);
    undef $old_w if !Tk::Exists($old_w);
    my $menubutton = $frame->Menubutton;
    my $menu = $menubutton->Menu(-menuitems => $menuitems,
				 (defined $title ? (-title => $title) : ()),
				);
    ## XXX Does not work, reason unclear
    #$menu->configure(-disabledforeground => $menubutton->cget(-foreground)) if $subtitlehack;
    main::menuarrow_unmanaged($menubutton, $menu,
			      (defined $title ? (-menulabel => $title) : ()),
			     );
    if ($old_w) {
	$old_w->destroy;
    }
    $menubutton->place(-x => $x, -y => 0, -width => $width);
    $frame->Advertise($advertised_name => $menubutton);
    $frame->Advertise($advertised_name . "_menu" => $menu);
    if ($addglobalmenu) {
	add_to_global_plugins_menu(-topmenu   => $topmenu,
				   -menuitems => $menuitems,
				   -title     => $title,
				   -advertisedname => $advertised_name,
				   -subtitlehack => $subtitlehack,
				  );
    }
}

sub add_to_global_plugins_menu {
    my(%args) = @_;

    my $topmenu   = delete $args{-topmenu}; # maybe be single or multiple menu items
    my $menuitems = delete $args{-menuitems} || [];
    my $title     = delete $args{-title};
    my $advertised_name = delete $args{-advertisedname};
    my $subtitlehack = delete $args{-subtitlehack};

    if (Tk::Exists($BBBike::Menubar::plugins_menu)) {
	my $m = $BBBike::Menubar::plugins_menu;
	my $need_separator = 1;
	for my $m_inx (0 .. $m->index("end")) {
	    if ($m->type($m_inx) eq 'separator') {
		$need_separator = 0;
		last;
	    }
	}
	if ($need_separator) {
	    $m->separator;
	}
	my @menuitems = @$menuitems;
	if ($topmenu) {
	    if (ref $topmenu->[0] eq 'ARRAY') {
		unshift @menuitems, @$topmenu;
	    } else {
		unshift @menuitems, $topmenu;
	    }
	}
	my $menu = $m->cascade(-label => $title,
			       -menuitems => \@menuitems,
			      );
## Does not work, there's no -disabledforeground option for cascades:
# 	if ($subtitlehack) {
# 	    $menu->configure(-disabledforeground => 'black'); # XXX?
# 	}

	if ($advertised_name) {
	    $advertised_name_to_title{$advertised_name} = $title;
	}
    }
}

sub remove_menu_button {
    my($advertised_name) = @_;
    my $frame = $main::top->Subwidget("ModeMenuPluginFrame");
    my $menu = $frame->Subwidget($advertised_name . "_menu");
    if ($menu) { $menu->destroy }
    my $menubutton = $frame->Subwidget($advertised_name);
    my $mb_p = $menubutton->parent;
    if ($menubutton) {
	my(%place_info) = $menubutton->placeInfo;
	my $mb_w = $menubutton->width;
	my $mb_x = $place_info{"-x"};
	$menubutton->placeForget;
	$menubutton->destroy;
	for my $other_mb ($mb_p->children) {
	    my(%other_place_info) = $other_mb->placeInfo;
	    next if $other_place_info{"-x"} <= $mb_x;
	    $other_mb->place(-x => $other_place_info{"-x"} - $mb_w);
	}
    }
    remove_from_global_plugins_menu($advertised_name);
}

sub remove_from_global_plugins_menu {
    my($advertised_name) = @_;
    if (Tk::Exists($BBBike::Menubar::plugins_menu) and
	my $title = $advertised_name_to_title{$advertised_name}) {
	my $m = $BBBike::Menubar::plugins_menu;
	for my $m_inx (0 .. $m->index("end")) {
	    my $entry_label = eval { $m->entrycget($m_inx, '-label') };
	    $entry_label = "" if !defined $entry_label;
	    if ($entry_label eq $title) {
		$m->delete($m_inx);
		last;
	    }
	}
    }
}

sub replace_plugin_widget {
    my($parent, $widget, $advertised_name) = @_;

    my $old_w = $parent->Subwidget($advertised_name);
    undef $old_w if !Tk::Exists($old_w);

    if ($old_w) {
	$widget->pack(-after => $old_w, -side => "left", -anchor => 'sw');
	$old_w->destroy;
    } else {
	$widget->pack(-side => "left", -anchor => 'sw');
    }
    $parent->Advertise($advertised_name => $widget);
}

1;
