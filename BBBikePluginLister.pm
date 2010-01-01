# -*- perl -*-

#
# $Id: BBBikePluginLister.pm,v 1.11 2008/02/28 20:32:23 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

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

require Tk::ItemStyle;

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
	@p = BBBikePlugin::_find_all_plugins_perl($topdir);
    };
    my $err = $@;
    if (defined &main::IncBusy && defined $top) {
	main::DecBusy($top);
    }

    if ($err) {
	main::status_message($err, "die");
    }

    my $tl = $w->Toplevel(-title => M"Plugins");
    main::set_as_toolwindow($tl);
    %main::toplevel = %main::toplevel if 0; # cease -w
    $main::toplevel{BBBikePluginLister} = $tl;
    $tl->geometry(int($w->screenwidth*0.7)."x400");

    my $outer = $tl->Frame(-border => 2, -relief => "sunken")->pack(-fill => "both", -expand => 1);
    my $header = $outer->Frame(-border => 2, -relief => "raised"
			      )->pack(-fill => 'x');
    $header->Label(-font => defined $main::font{large} ? $main::font{large} : "Helvetica 12 bold",
		   -text => "BBBike-Plugins")->pack(-anchor => "e");
    
    my $sel_bg = '#4a6984';
    my $cur_sel_widget;
    my $hl;
    $hl = $outer->Scrolled("HList",
			   -scrollbars => 'se',
			   -selectbackground => $sel_bg,
			   -selectmode => 'browse',
			   -browsecmd => sub {
			       # This is wrong if the user really
			       # browses over items: the checkbutton
			       # bg changes while the other bg stay
			       # the same.
			       my($path_i) = @_;
			       my $new_cur_sel_widget = $hl->itemCget($path_i, 0, '-widget');
			       if (Tk::Exists($cur_sel_widget) && $cur_sel_widget != $new_cur_sel_widget) {
				   $cur_sel_widget->configure(-bg => $hl->cget('-background'));
			       }
			       if (Tk::Exists($new_cur_sel_widget)) {
				   $new_cur_sel_widget->configure(-bg => $sel_bg);
			       }
			       $cur_sel_widget = $new_cur_sel_widget;
			   },
			   -header => 1,-columns => 4,
			  )->pack(-fill => "both", -expand => 1);
    $hl->anchorClear;

    if (eval {
	local $SIG{__DIE__};
	require Tk::ResizeButton;
	require BBBikeTkUtil;
	1;
    }) {
	my $headerstyle = $hl->ItemStyle('window', -padx => 0, -pady => 0);
	my $real_hl  = $hl->Subwidget('scrolled');
	my $i = 0;
	for my $column (qw(Laden Name Zusammenfassung Dateipfad)) {
	    my $label = M($column);
	    my $ii = $i;
	    # XXX Buttons should not react on click and motion, because
	    # no sorting is implemented yet. Or fix the sorting.
	    my $header = $hl->ResizeButton(-text => $label,
					   -relief => "flat",
					   -padx => 0, -pady => 0,
					   -widget => \$real_hl,
					   ## XXX Sorting does not work reliable, checkbuttons vanish
					   #($column ne "Laden" ? (-command => sub { BBBikeTkUtil::sort_hlist($real_hl, $ii) }) : ()),
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
	$hl->headerCreate(0, -text => M"Laden");
	$hl->headerCreate(1, -text => M"Name");
	$hl->headerCreate(2, -text => M"Zusammenfassung");
	$hl->headerCreate(3, -text => M"Dateipfad");
    }

    $hl->columnWidth(0, 50);
    $hl->columnWidth(1, 230);
    $hl->columnWidth(2, 400);

    @p = sort { $a->Name cmp $b->Name } @p;

    require Tk::ItemStyle;
    my(%is, %sel_is, %sel_descr_is, %bg_color);
    for my $key (qw(odd even)) {
	$bg_color{$key} = $key eq 'even' ? $hl->cget('-background') : '#dddddd';
	$is{$key}           = $hl->ItemStyle("window",
					     -pady => 0, -padx => 0,
					     -anchor => 'nw',
					     # no -background available here
					    );
	$sel_is{$key}       = $hl->ItemStyle("text",
					     -selectforeground => 'white',
					     -anchor => 'nw',
					     -background => $bg_color{$key},
					    );
	$sel_descr_is{$key} = $hl->ItemStyle('text',
					     -selectforeground => 'white',
					     -wraplength => 400,
					     -anchor => 'nw',
					     -background => $bg_color{$key},
					    );
    }

    my $path_i = 0;
    for my $plugin_def (@p) {
	my $key = $path_i % 2 == 0 ? 'even' : 'odd';
	$hl->add($path_i, -itemtype => "window", -style => $is{$key},
		 -widget => $hl->Checkbutton(-variable => \$plugin_def->[3], # XXX HACK! how to access member directly???
					     -onvalue => 1,
					     -offvalue => 0,
					     -command => sub { toggle_plugin($tl, $plugin_def, $plugin_def->[3]) },
					     -background => $bg_color{$key},
					     -highlightthickness => 0,
					    ),
		);
	$hl->itemCreate($path_i, 1, -text => $plugin_def->Name, -style => $sel_is{$key});
	$hl->itemCreate($path_i, 2, -text => $plugin_def->Description, -style => $sel_descr_is{$key});
	$hl->itemCreate($path_i, 3, -text => $plugin_def->File, -style => $sel_is{$key});
	$path_i++;
    }

    my $footer = $outer->Frame->pack(-fill => "x");
    my $cb = $footer->Button(Name => "close",
			     -command => sub { $tl->destroy })->pack(-anchor => 'e', -side => "right");
    $tl->bind('<Escape>' => sub { $cb->invoke });
    $footer->Button(-text => M"Plugins permanent machen",
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
				    $FindBin::RealBin = $FindBin::RealBin if 0; # cease -w
				    $short_path =~ s{^\Q$FindBin::RealBin\E/}{};

				    push @new_initial_plugins, $short_path . (defined $plugin_args ? "=$plugin_args" : "");
				}
			    }

			    # XXX preserve old order?
			    my $new_initial_plugins = join(",", @new_initial_plugins);

			    $main::initial_plugins = $new_initial_plugins;
			    $main::opt = $main::opt if 0; # cease -w
			    $main::opt->save_options;
			};
			if ($@) {
			    main::status_message($@, "die");
			} else {
			    main::status_message(M"Ausgewählte Plugins sind jetzt permanent", "infodlg");
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
	if ($mod->can("unregister")) {
	    $mod->unregister;
	} else {
	    main::status_message(M"Das Plugin kann nicht deregistriert werden. Falls die Pluginliste permanent gemacht wird, wird das Plugin beim nächsten Starten von BBBike nicht mehr verfügbar sein.", "warn");
	}
    }
}

1;

__END__
