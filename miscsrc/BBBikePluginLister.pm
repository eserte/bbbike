# -*- perl -*-

#
# $Id: BBBikePluginLister.pm,v 1.3 2006/09/11 22:18:33 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikePluginLister;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

require BBBikePlugin;

sub plugin_lister {
    my($w, $topdir) = @_;

    if (!$topdir) {
	require Cwd;
	$topdir = Cwd::cwd();
    }

    my $top = $w->MainWindow;
    if (defined &main::IncBusy) {
	main::IncBusy($top);
    }
    my @p;
    eval {
	local $SIG{__DIE__};
	if (1||$^O eq 'MSWin32') {
	    @p = BBBikePlugin::_find_all_plugins_perl($topdir);
	} else {
	    @p = BBBikePlugin::_find_all_plugins_unix($topdir);
	}
    };
    my $err = $@;
    if (defined &main::IncBusy && defined $top) {
	main::DecBusy($top);
    }

    if ($err) {
	main::status_message($err, "die");
    }

    my $tl = $w->Toplevel(-title => "Plugins");
    main::set_as_toolwindow($tl);
    $main::toplevel{BBBikePluginLister} = $tl;
    $tl->geometry(int($w->screenwidth*0.7)."x400");

    my $outer = $tl->Frame(-border => 2, -relief => "sunken")->pack(-fill => "both", -expand => 1);
    my $header = $outer->Frame(-border => 2, -relief => "raised"
			      )->pack(-fill => 'x');
    $header->Label(-font => defined $main::font{large} ? $main::font{large} : "Helvetica 12 bold",
		   -text => "BBBike-Plugins")->pack(-anchor => "e");
    
    my $hl = $outer->Scrolled("HList",
			      -scrollbars => 'se',
			      -header => 1,-columns => 4)->pack(-fill => "both", -expand => 1);

    if (eval {
	local $SIG{__DIE__};
	require Tk::resizeButton;
	require BBBikeTkUtil;
	1;
    }) {
	my $headerstyle = $hl->ItemStyle('window', -padx => 0, -pady => 0);
	my $real_hl  = $hl->Subwidget('scrolled');
	my $i = 0;
	for my $title (qw(Laden Name Zusammenfassung Dateipfad)) {
	    my $ii = $i;
	    my $header = $hl->resizeButton(-text => $title,
					   -relief => "flat",
					   -padx => 0, -pady => 0,
					   -widget => \$real_hl,
					   ## XXX Sorting does not work reliable, checkbuttons vanish
					   #($title ne "Laden" ? (-command => sub { BBBikeTkUtil::sort_hlist($real_hl, $ii) }) : ()),
					   -column => $i,
					   -anchor => 'w',
					  );
	    $hl->headerCreate($i,
			      -itemtype => 'window',
			      -widget => $header,
			      -style => $headerstyle,
			     );
	    $i++;
	}
    } else {
	warn $@;
	$hl->headerCreate(0, -text => "Laden");
	$hl->headerCreate(1, -text => "Name");
	$hl->headerCreate(2, -text => "Zusammenfassung");
	$hl->headerCreate(3, -text => "Dateipfad");
    }

    $hl->columnWidth(0, 50);
    $hl->columnWidth(1, 230);
    $hl->columnWidth(2, 400);

    @p = sort { $a->Name cmp $b->Name } @p;

    require Tk::ItemStyle;

    my $path_i = 0;
    for my $plugin_def (@p) {
	my $is = $hl->ItemStyle("window", -pady => 0, -padx => 0);
	$hl->add($path_i, -itemtype => "window", -style => $is,
		 -widget => $hl->Checkbutton(-variable => \$plugin_def->[3], # XXX HACK! how to access member directly???
					     -onvalue => 1,
					     -offvalue => 0,
					     -command => sub { toggle_plugin($tl, $plugin_def, $plugin_def->[3]) },
					     -background => $hl->cget('-background'),
					     -highlightthickness => 0,
					    ),
		);
	$hl->itemCreate($path_i, 1, -text => $plugin_def->Name);
	$hl->itemCreate($path_i, 2, -text => $plugin_def->Description);
	$hl->itemCreate($path_i, 3, -text => $plugin_def->File);
	$path_i++;
    }

    my $footer = $outer->Frame->pack(-fill => "x");
    $footer->Button(Name => "close",
		    -command => sub { $tl->destroy })->pack(-anchor => 'e', -side => "right");
    $footer->Button(-text => "Plugins permanent machen",
		    -command => sub {
			eval {
			    local $SIG{__DIE__};
			    my @plugins = split /,/, $main::initial_plugins;
			    my %plugins_args;
			    for my $plugin_def (@plugins) {
				my($file, $plugin_args);
				if ($plugin_def =~ /^(.*)=(.*)$/) {
				    $file = $1;
				    $plugins_args{$file} = $2;
				}
			    }

			    my @new_initial_plugins;
			    for my $p (@p) {
				if ($p->Active) {
				    my $plugin_args;
				    (my $path = $p->File) =~ s{^/+}{};
				    while($path) {
					if (exists $plugins_args{$path}) {
					    $plugin_args = $plugins_args{$path};
					    last;
					}
					$path =~ s{^[^/]+}{};
					$path =~ s{^/+}{};
				    }

				    my $short_path = $p->File;
				    $short_path =~ s{^\Q$FindBin::RealBin\E/}{};

				    push @new_initial_plugins, $short_path . (defined $plugin_args ? "=$plugin_args" : "");
				}
			    }

			    # XXX preserve old order?
			    my $new_initial_plugins = join(",", @new_initial_plugins);

			    $main::initial_plugins = $new_initial_plugins;
			    $main::opt->save_options;
			};
			if ($@) {
			    main::status_message($@, "die");
			} else {
			    main::status_message("Ausgewählte Plugins sind jetzt permanent", "infodlg");
			}
		    })->pack(-anchor => 'e', -side => "right");
}

sub toggle_plugin {
    my($w, $plugin_def, $cb) = @_;
    if ($cb) {
	main::load_plugin($plugin_def->File);
    } else {
	require File::Basename;
	my($mod) = File::Basename::fileparse($plugin_def->File, '\..*');
	if ($mod->can("deregister")) {
	    $mod->deregister;
	} else {
	    main::status_message("Das Plugin kann nicht deregistriert werden. Beim nächsten Starten von BBBike wird es nicht mehr verfügbar sein.", "warn");
	}
    }
}

1;

__END__
