# -*- perl -*-

#
# $Id: BBBikePlugin.pm,v 1.5 2003/01/08 18:48:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
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
struct('BBBikePlugin::Plugin' => [Name => "\$", File => "\$", Description => "\$"]);

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
	$lb->bind("<1>" => sub {
		      my $cur = $lb->curselection;
		      if (defined $cur) {
			  main::load_plugin($p[$cur]->File);
		      }
		  });
	if ($main::balloon) {
	    $main::balloon->attach($lb->Subwidget("scrolled"),
				   -msg => [map { $_->Description } @p]);
	}
	$t->Button(Name => "close",
		   -command => sub { $t->destroy })->pack(-fill => "x");
    }
}

sub _find_all_plugins_perl {
    my $topdir = shift;

    require File::Find;
    my @p;
    my $wanted = sub {
	if (/^.*\.pm$/ && $_ ne "BBBikePlugin.pm" && open(PM, $_)) {
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
		$p->Description($descr || $File::Find::name);
		push @p, $p;
	    }
	}
    };

    File::Find::find($wanted, $topdir);

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

    @p;
}

sub place_menu_button {
    my($frame, $menuitems, $refwidget) = @_;
    $refwidget->idletasks;    # XXX idletasks needed?
    my($x,$width) = ($refwidget->x, $refwidget->width);
    my $menubutton = $frame->Menubutton;
    my $menu = $menubutton->Menu(-menuitems => $menuitems);
    main::menuarrow_unmanaged($menubutton, $menu);
    $menubutton->place(-x => $x, -y => 0, -width => $width);
}

1;
