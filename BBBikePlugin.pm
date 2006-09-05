# -*- perl -*-

#
# $Id: BBBikePlugin.pm,v 1.11 2006/09/05 21:31:39 eserte Exp $
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
	if (1||$^O eq 'MSWin32') {
	    @p = _find_all_plugins_perl($topdir);
	} else {
	    @p = _find_all_plugins_unix($topdir);
	}
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
	$t->Button(-text => "Laden", # XXX Msg.pm
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
	if (/^.*\.pm$/
	    && $_ ne "BBBikePlugin.pm" # meta modules
	    && $_ ne "BBBikePluginLister.pm"
	    && $File::Find::name !~ m{/bbbike/projects/} # the www.radzeit.de directories
	    && $File::Find::name !~ m{/bbbike/BBBike-\d+\.\d+(-DEVEL)?/} # distdir
	    && $File::Find::name !~ m{/(CVS|RCS|\.svn)/}
	    && open(PM, $_)) {
	    my $curr_file = $_;
	    my $descr;
	    my $is_plugin;
	    local $_;
	    while(<PM>) {
		chomp;
		if (/BBBikePlugin/) {
		    $is_plugin++;
		    last if $descr;
		}
		if (/Description\s+\(de\)\s*[:=]\s*\"?([^\"]+)/) {#XXX english?
		    $descr = $1;
		    last if $is_plugin;
		}
	    }
	    close PM;

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

# only for Unix with modern grep
sub _find_all_plugins_unix {
    my $topdir = shift;

    require File::Basename;

    my @p;
    open(F, 'find '.$topdir.' -name "*.pm" -exec grep -l BBBikePlugin {} \; |');
    while(<F>) {
	chomp;
	next if /BBBikePlugin\.pm$/;
	my $p = BBBikePlugin::Plugin->new;
	$p->Name((File::Basename::fileparse($_, '\..*'))[0]);
	$p->File($_);
	$p->Description($_);
	push @p, $p;
    }
    close F;

    _plugin_active_check(\@p);

    @p;
}

sub _plugin_active_check {
    my($p_ref) = @_;
    for my $p (@$p_ref) {
	if ($INC{$p->File}) {
	    $p->Active(1);
	}
    }
}

sub place_menu_button {
    my($frame, $menuitems, $refwidget, $advertised_name) = @_;
    $refwidget->idletasks;    # XXX idletasks needed?
    my($x,$width) = ($refwidget->x, $refwidget->width);
    # If $refwidget is not yet mapped:
    if ($width <= 1) { $width = $refwidget->reqwidth }
    my $old_w = $frame->Subwidget($advertised_name);
    undef $old_w if !Tk::Exists($old_w);
    my $menubutton = $frame->Menubutton;
    my $menu = $menubutton->Menu(-menuitems => $menuitems);
    main::menuarrow_unmanaged($menubutton, $menu);
    if ($old_w) {
	$old_w->destroy;
    }
    $menubutton->place(-x => $x, -y => 0, -width => $width);
    $frame->Advertise($advertised_name => $menubutton);
    $frame->Advertise($advertised_name . "_menu" => $menu);
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
