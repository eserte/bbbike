# -*- perl -*-

#
# $Id: BBBikeAdvanced.pm,v 1.124 2005/08/25 22:17:36 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999-2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikeAdvanced;

package main;

use Config;
use strict;
use BBBikeGlobalVars;

BEGIN {
    if (!defined &M) {
	eval 'sub M ($) { @_ }'; warn $@ if $@;
    }
}

use constant MAX_LAYERS => 100;

sub start_ptksh {
    # Is there already a (withdrawn) ptksh?
    foreach my $mw0 (Tk::MainWindow::Existing()) {
	if ($mw0->title =~ /^ptksh/) {
	    $mw0->deiconify;
	    $mw0->raise;
	    return;
	}
    }
    my @perldirs = $Config{'scriptdir'};
    push @perldirs, dirname(dirname($^X)); # for the SiePerl installation
    my $perldir;
    TRY: {
        # Find the ptksh script
        for $perldir (@perldirs) {
            if (-r "$perldir/ptksh") {
	require "$perldir/ptksh";
                last TRY;
            }
        }
	$perldir = dirname($^X);
	if (-r "$perldir/ptksh") {
	    require "$perldir/ptksh";
	} else {
	    my $f = ((Tk::MainWindow::Existing())[0])->getOpenFile
		((-d $perldir ? (-initialdir => $perldir) : ()),
		 -title => "Path to ptksh",
		);
	    if (defined $f) {
		require $f;
	    } else {
		return;
	    }
	}
    } 

    # The created mainwindow is unnecessary - destroy it
    foreach my $mw0 (Tk::MainWindow::Existing()) {
	if ($mw0->title eq '$mw') {
	    $mw0->destroy;
	} elsif ($mw0->title eq 'ptksh') {
	    $mw0->protocol('WM_DELETE_WINDOW' => [$mw0, 'withdraw']);
	}
    }
}

sub advanced_option_menu {
    my $opbm = shift || $BBBike::Menubar::option_menu;
    $opbm->separator;
    $opbm->command(-label => 'Ptksh',
		   -command => \&start_ptksh,
		   ($top->screenheight < 768 && $Tk::VERSION >= 800 ? (-columnbreak => 1) : ()),
		  );
    $opbm->command(-label => 'WidgetDump',
		   -command => sub {
		       require Tk::WidgetDump;
		       $top->WidgetDump;
		   });
    my $add_pl = "$tmpdir/add.pl";
    $opbm->command(-label => "Eval $add_pl",
		   -command => sub {
		       if (-f "$add_pl") {
			   do $add_pl;
			   warn $@ if $@;
			   return;
		       }
		       if ($top->can('getOpenFile')) {
			   my $f = $top->getOpenFile
			     (-filetypes =>
			      [
			       [M("Perl-Skripte"),  ['.pl']],
			       [M("Perl-Module"),  '.pm'  ],
			       [M("Alle Dateien"),     '*',   ],
			      ]);
			   if (defined $f and -f $f) {
			       do $f;
			       warn $@ if $@;
			   }
		       } else {
			   warn "Nothing found";
		       }
		   }
		   );
    $opbm->command(-label => 'Reload modules',
		   -command => \&reload_new_modules);
    if ($devel_host) {
	$opbm->command(-label => 'Destroy all toplevels',
		       -command => \&destroy_all_toplevels);
	$opbm->command(-label => 'Re-call some subs',
		       -command => sub {
			   define_item_attribs();
			   generate_plot_functions();
			   set_bindings();
		       });
    }
    $opbm->command(-label => M"Datenverzeichnis ändern ...",
		   -command => \&change_datadir);

    $top->bind("<Pause>" => sub {
		   eval {
		       require Tk::WidgetDump;
		       $top->WidgetDump;
		   }; warn $@ if $@;
		   require Config;
		   my $perldir = $Config::Config{'scriptdir'};
		   require "$perldir/ptksh";
	       });

}

sub custom_draw_dialog {
    custom_draw(@_); # return file name
}

sub custom_draw {
    my $linetype = shift;
    my $abk      = shift or die "Missing abk";
    my $file     = shift;
    my(%args)    = @_;
    # XXX -retargs is a hack, please refactor the whole plot_additional_layer
    # and custom_draw thingy
    my $retargs  = (delete $args{-retargs}) || {};
    my $draw      = eval '\%' . $linetype . "_draw";
    my $fileref   = eval '\%' . $linetype . "_file";
    my $name_draw = eval '\%' . $linetype . "_name_draw";
    my $coord_input;

    require File::Basename;

    if (!defined $file) {
	die "Tk 800 needed"
	    unless $Tk::VERSION >= 800;
	my $get_file = sub {
	    my $_file = $top->getOpenFile
		(-filetypes =>
		 [
		  # XXX use Strassen->filetypes?
		  [M"BBD-Dateien", '.bbd'],
		  [M"BBBike-Route-Dateien", '.bbr'],
		  [M"ESRI-Shape-Dateien", '.shp'],
		  [M"MapInfo-Dateien", ['.mif','.MIF']],
		  ($advanced
		   ? [M"ARC/DCW/E00-Dateien", ['.e00','.E00']]
		   : ()
		  ),
		  ($linetype eq 'p'
		   ? [M"Gpsman-Waypoints", ['.wpt']]
		   : [M"Gpsman-Tracks oder -Routen", ['.trk', '.rte']]
		  ),
		  [M"Alle Dateien", '*'],
		 ],
		 (defined $file ? (-initialdir => $file =~ m{/$} ? $file : File::Basename::dirname($file)) : ()),
		);
	    $file = $_file if defined $_file;
	};

	if (eval { require Tk::PathEntry; 1 }) {
	    my $t = $top->Toplevel;
	    $t->title(M("Zusätzlich zeichnen"));
	    $t->transient($top) if $transient;

	    my $f;
	    $f = $t->Frame->pack(-fill => "x");
	    my $weiter = 0;
	    my $pe;
	    Tk::grid($pe = $f->PathEntry(-textvariable => \$file,
					 -selectcmd => sub {
					     $pe->focusNext;
					 },
# 					 -cancelcmd => sub {
# 					     $weiter = -1;
# 					 },
					),
		     $f->Button(-image => $t->Getimage("openfolder"),
				-command => $get_file,
				-takefocus => 0,
			       )
		    );
	    $pe->focus;
	    $f = $t->Frame->pack(-fill => "x");
	    if ($linetype eq "p") {
		Tk::grid($f->Checkbutton(-text => M"Namen zeichnen",
					 -variable => \$args{-namedraw}),
			 -sticky => "w",
			);
		Tk::grid($f->Checkbutton(-text => M"Überlappungen vermeiden",
					 -variable => \$args{-nooverlaplabel}),
			 -sticky => "w",
			);
	    }

	    {
		my $e;
		if (eval { require Tk::NumEntry; 1 }) {
		    $e = $f->NumEntry(-minvalue => 1,
				      -maxvalue => 20,
				      -textvariable => \$args{Width},
				      -width => 3,
				     );
		} else {
		    $e = $f->Entry(-width => 3,
				   -textvariable => \$args{Width});
		}
		Tk::grid($f->Label(-text => $linetype eq "p" ? M"Punktbreite" : M"Linienbreite"),
			 $e,
			 -sticky => "w",
			);
	    }
	    Tk::grid($f->Label(-text => "Kartenkoordinaten"),
		     my $om = $f->Optionmenu
		     (-variable => \$coord_input,
#XXX this causes -width to be ignored?		      -anchor => "w",
		      -width => 10,
		      -options => [ (map { [ $Karte::map{$_}->name, $_ ] } @Karte::map) ]),
		     -sticky => "w",
		    );
	    $coord_input = "Standard";

	    $f = $t->Frame->pack(-fill => "x");
	    Tk::grid($f->Button(Name => "ok",
				-command => sub {
				    $weiter = 1;
				}),
		     $f->Button(Name => "cancel",
				-command => sub {
				    $weiter = -1;
				})
		    );
	    $t->OnDestroy(sub { $weiter = -1 if !$weiter });
	    $t->waitVariable(\$weiter);
	    $t->destroy if Tk::Exists($t);

	    undef $file if $weiter == -1;

	} else {
	    $get_file->();
	}

	if (!defined $file) {
	    $draw->{$abk} = 0;
	    return;
	}
    }

    # XXX not nice, but it works...
    if ($file =~ /\.bbr$/) {
	my $tmpfile = "$tmpdir/" . basename($file);
	require Route::Heavy;
	my $s = Route::as_strassen($file);
	$s->write($tmpfile);
	$file = $tmpfile;
    }

    @BBBike::ExtFile::scrollregion = ();
    undef $BBBike::ExtFile::center_on_coord;
    $fileref->{$abk} = $file;
    # zusätzliches desc-File einlesen:
    if ($file =~ /(.*)\.bbd(\.gz)?$/) {
	my $desc_file = "$1.desc";
	warn "Try to load description file $desc_file"
	    if $verbose;
	read_desc_file($desc_file, $abk); # XXX obsolete
	handle_global_directives($file, $abk);
    }

    if ($args{-namedraw}) {
	$retargs->{NameDraw} = $args{-namedraw};
	delete $args{-namedraw};
	$name_draw->{$abk} = 1;
    }
    if ($args{-nooverlaplabel}) {
	delete $args{-nooverlaplabel};
	$no_overlap_label{$abk} = 1;
    }

    my $do_close = 1;
    $do_close = delete $args{-close} if exists $args{-close};

    # XXX the condition should be defined $default_line_width,
    # but can't use it because of the Checkbutton/Menu bug
    if ($default_line_width && (!defined $args{Width} || $args{Width} eq "")) {
	$args{Width} = $default_line_width;
    }
    if ($args{Width}) {
	$retargs->{Width} = $args{Width};
    }
    $args{-draw} = 1;
    $args{-filename} = $file;
    if (defined $coord_input && $coord_input ne "Standard") {
	$args{-map} = $coord_input;
	$retargs->{-map} = $coord_input;
    }
    plot($linetype, $abk, %args);

    for (($linetype eq 'p' ? ("$abk-img", "$abk-fg") : ($abk))) {
	$c->bind($_, "<ButtonPress-1>" => \&set_route_point);
    }

    if (@BBBike::ExtFile::scrollregion) {
	set_scrollregion(@BBBike::ExtFile::scrollregion);
    }
    if ($BBBike::ExtFile::p_attrib && $linetype eq 'p') {
	$p_attrib{$abk} = $BBBike::ExtFile::p_attrib;
    } else {
	delete $p_attrib{$abk};
    }
    if ($BBBike::ExtFile::str_attrib && $linetype eq 'str') {
	$str_attrib{$abk} = $BBBike::ExtFile::str_attrib;
    } else {
	delete $str_attrib{$abk};
    }

    if (defined $BBBike::ExtFile::center_on_coord) {
	choose_from_plz(-coord => $BBBike::ExtFile::center_on_coord);
    }

    $toplevel{"chooseort-$abk-$linetype"}->destroy
	if $toplevel{"chooseort-$abk-$linetype"} && $do_close;

    $file; # return filename
}

sub read_desc_file {
    warn "Using .desc files is obsolete, please consider to switch to global in-file directives. See bbd.pod for some information";
    my $desc_file = shift;
    my $abk = shift;
    @BBBike::ExtFile::scrollregion = ();
    if (-r $desc_file && -f $desc_file) {
	warn "Read $desc_file...\n" if $verbose;
	require Safe;
	#XXX problems!
	#require Symbol;
	#Symbol::delete_package("BBBike::ExtFile");
	my $compartment = new Safe("BBBike::ExtFile");
	if (defined $abk) {
	    $BBBike::ExtFile::abk = $BBBike::ExtFile::abk = $abk;
	}
	# $str_attrib and $p_attrib should be used in favour of
	# %str_attrib and %p_attrib
	my @shared_symbols =
	    qw(%line_width %line_length
	       %str_color  %outline_color
	       %str_attrib %p_attrib
	       $str_attrib $p_attrib
	       %category_size %category_color %category_width %category_image
	       %category_stipple
	      );
	$compartment->share(@shared_symbols);
	$compartment->rdo($desc_file);
	warn $@ if $@;
	no strict 'refs';
	for my $symbol (@shared_symbols) {
	    $symbol =~ s/^.//;
	    undef *{"BBBike::ExtFile::$symbol"};
	}
    }
}

# e.g. from .desc files
sub set_scrollregion {
    my @in = @_;
    @scrollregion = (transpose(@in[0,3]), transpose(@in[2,1]));
    $c->configure(-scrollregion => \@scrollregion);
}

sub enlarge_scrollregion {
    my @in = @_;
    my @new_scrollregion = (transpose(@in[0,3]), transpose(@in[2,1]));
    enlarge_transposed_scrollregion(@new_scrollregion);
}

sub enlarge_transposed_scrollregion {
    my @new_scrollregion = @_;
    $scrollregion[0] = $new_scrollregion[0]
	if ($new_scrollregion[0] < $scrollregion[0]);
    $scrollregion[1] = $new_scrollregion[1]
	if ($new_scrollregion[1] < $scrollregion[1]);
    $scrollregion[2] = $new_scrollregion[2]
	if ($new_scrollregion[2] > $scrollregion[2]);
    $scrollregion[3] = $new_scrollregion[3]
	if ($new_scrollregion[3] > $scrollregion[3]);
    $c->configure(-scrollregion => \@scrollregion);
}

sub _layer_tag_expr {
    my $abk = shift;
    "$abk || $abk-fg";
}

sub enlarge_scrollregion_for_layer {
    my $abk = shift;
    IncBusy($top);
    eval {
	my(@bbox) = $c->bbox(_layer_tag_expr($abk));
	if (@bbox) {
	    enlarge_transposed_scrollregion(@bbox);
	} else {
	    die "No bbox for tag $abk: maybe the layer is empty";
	}
    };
    my $err = $@;
    DecBusy($top);
    if ($err) {
	status_message($err, 'die');
    }
}

sub enlarge_scrollregion_from_descfile {
    my $f = shift;
    if (!defined $f) {
	$f = $top->getOpenFile(-filetypes => [
					      [M"Desc-Dateien", '.desc'],
					      [M"Alle Dateien", '*'],
					     ]);
    }
    if (defined $f) {
	# XXX replace with handle_global_directives function
	read_desc_file($f);
	if (@BBBike::ExtFile::scrollregion) {
	    enlarge_scrollregion(@BBBike::ExtFile::scrollregion);
	}
    }
}

sub tk_plot_additional_layer {
    my($linetype) = @_;
    plot_additional_layer($linetype);
}

sub plot_additional_sperre_layer {
    plot_additional_layer("sperre");
}

# Called from last cmdline (initial layers)
sub plot_additional_layer_cmdline {
    my($layer_def, %args) = @_;
    my($layer_type, $layer_filename) = split /=/, $layer_def, 2;
    if (!defined $layer_type) {
	($layer_type, $layer_filename) = ('str', $layer_def);
    }
    plot_additional_layer($layer_type, $layer_filename, %args);
}

sub plot_additional_layer {
    my($linetype, $file, %args) = @_;
    my $abk = next_free_layer();
    if (!defined $abk) {
	status_message(M"Keine Layer frei!", 'error');
	return;
    }
    if ($linetype eq 'sperre') {
  	$abk = "$abk-sperre";
    }
    warn "Use new Layer $abk\n";
    add_to_stack($abk, "before", "pp");
    if ($linetype !~ /^(str|p|sperre)$/) {
#XXXdel	$str_draw{$abk} = 1;
#    } elsif ($linetype eq 'p') {
#XXXdel	$p_draw{$abk} = 1;
#    } else {
	die "Unknown linetype $linetype, should be str, sperre or p";
    }

    my @args;
    {
	# "sperre" linetype should be "p" for drawing, but still "sperre"
	# for the last loaded menu
	my $linetype_for_menu = $linetype;
	if ($linetype eq 'sperre') {
	    $linetype = 'p';
	}
	$args{-retargs} = {};
	if (defined $file) {
	    custom_draw($linetype, $abk, $file, %args);
	} else {
	    $file = custom_draw_dialog($linetype, $abk, undef, %args);
	}
	@args = %{ $args{-retargs} };
	push @args, -linetype => $linetype_for_menu;
    }

    if (defined $file) {
	if ($linetype eq 'sperre' && $net) {
	    my $s = $p_obj{$abk} || Strassen->new($file);
	    $net->make_sperre($s, Type => "all");
	}
	my $add_def;
	if (@args) {
	    $add_def = "\t" . join "\t", @args;
	}
	add_last_loaded($file, $last_loaded_layers_obj, $add_def);
	save_last_loaded($last_loaded_layers_obj);
    }

    Hooks::get_hooks("after_new_layer")->execute;
    $abk;
}

sub additional_layer_dialog {
    my(%args) = @_;
    my $title = delete $args{-title} || M"Straßen/Punkte auswählen";
    my $cb    = delete $args{-cb};         # callback for all layers
    my $p_cb  = delete $args{-pcb} || $cb; # callback for point layers
    my $s_cb  = delete $args{-scb} || $cb; # callback for street layers
    my $token = delete $args{-token};

    my $t;
    if (defined $token) {
	$t = redisplay_top($top, $token,
			   -title => $title);
	return if !defined $t;
    } else {
	$t = $top->Toplevel;
	$t->title($title);
	$t->transient($top) if $transient;
    }
    $t->geometry("300x400");
    require Tk::Pane;
    my $f = $t->Scrolled("Pane", -scrollbars => "osoe",
			 -sticky => 'nw',
			)->pack(-fill => "both", -expand => 1);
    my($delete_pane,$fill_pane);
    $delete_pane = sub {
	$f->Walk(sub {
		     $_[0]->destroy
			 if (Tk::Exists($_[0]) &&
			     ($_[0]->isa("Tk::Button") || $_[0]->isa("Tk::Label")));
		 });
    };
    $fill_pane = sub {
	for my $i (1..MAX_LAYERS) {
	    my $abk = "L$i";
	    if ($str_draw{$abk}) {
		$f->Button(-text => "Straßen $abk ($str_file{$abk})",
			   -command => sub {
			       $s_cb->($abk);
			   })->pack(-anchor => "w");
	    }
	    if ($p_draw{$abk}) {
		$f->Button(-text => "Punkte $abk ($p_file{$abk})",
			   -command => sub {
			       $p_cb->($abk);
			   })->pack(-anchor => "w");
	    }
	}
    };
    $fill_pane->();

    $t->Button(Name => "close",
	       -command => sub {
		   $t->destroy;
	       })->pack(-anchor => "w");

    my $tpath = $t->PathName;
    for my $hook (qw(after_new_layer after_delete_layer)) {
	Hooks::get_hooks($hook)->add
		(sub { $delete_pane->(); $fill_pane->() }, $tpath);
    }
    $t->OnDestroy
	(sub {
	     for my $hook (qw(after_new_layer after_delete_layer)) {
		 Hooks::get_hooks($hook)->del($tpath);
	     }
	 });
}

sub select_layers_for_net_dialog {
    my $t = $top->Toplevel;
    $t->title(M("Layer auswählen"));
    $t->transient($top) if $transient;
    $t->geometry("300x400");
    require Tk::Pane;
    my $f = $t->Scrolled("Pane", -scrollbars => "osoe",
			 -sticky => 'nw',
			)->pack(-fill => "both", -expand => 1);

    my %_custom_net_str = %custom_net_str;
    for my $i (1..MAX_LAYERS) {
	my $abk = "L$i";
	if ($str_draw{$abk}) {
	    $f->Checkbutton(-text => "Straßen $abk ($str_file{$abk})",
			    -variable => \$_custom_net_str{$abk},
			   )->pack(-anchor => "w");
	}
    }

    my $wait = 0;
    {
	my $f = $t->Frame->pack(-fill => "x");
	$f->Button(Name => "ok",
		   -command => sub {
		       $wait = +1;
		   })->pack(-side => "left");
	$f->Button(Name => "close",
		   -command => sub {
		       $wait = -1;
		   })->pack(-side => "left");
    }
    $t->OnDestroy(sub { $wait = -1 });
    $t->waitVariable(\$wait);
    if ($wait > 0) {
	my $changed = 0;
	while(my($k,$v) = each %_custom_net_str) {
	    $changed++ if $custom_net_str{$k} != $v;
	    $custom_net_str{$k} = $v;
	}
	make_net() if $changed;
    }
    $t->destroy if Tk::Exists($t);
}


sub choose_from_additional_layer {
    additional_layer_dialog
	(-title => M"Straßen/Punkte auswählen",
	 -scb => sub {
	     my $abk = shift;
	     choose_ort('s', $abk, -rebuild => 1);
	 },
	 -pcb => sub {
	     my $abk = shift;
	     choose_ort('p', $abk, -rebuild => 1);
	 },
	 -token => 'choose_from_additional_layer',
	);
}

sub delete_additional_layer {
    my $t = $top->Toplevel;
    my $tpath = $t->PathName;
    $t->title(M"Zusätzliche Layer löschen");
    $t->transient($top) if $transient;
    $t->geometry("300x400");
    require Tk::Pane;
    my $f = $t->Scrolled("Pane", -scrollbars => "osoe",
			 -sticky => 'nw',
			)->pack(-fill => "both", -expand => 1);

    my($delete_pane,$fill_pane);
    $delete_pane = sub {
	$f->Walk(sub {
		     $_[0]->destroy
			 if (Tk::Exists($_[0]) &&
			     ($_[0]->isa("Tk::Button") || $_[0]->isa("Tk::Label")));
		 });
    };
    $fill_pane = sub {
	my $seen = 0;
	for my $i (1..MAX_LAYERS) {
	    my $abk = "L$i";
	    if ($str_draw{$abk} || $p_draw{$abk}) {
		my(@files);
		push @files, $str_file{$abk} if $str_file{$abk};
		push @files, $p_file{$abk}   if $p_file{$abk};
		my $files = "";
		if (@files) {
		    $files = "(" .join(",", @files) . ")";
		}
		$f->Button
		    (-text => "Layer $abk $files",
		     -command => sub {
			 if ($str_draw{$abk}) {
			     $str_draw{$abk} = 0;
			     plot('str',$abk);
			     delete $str_file{$abk};
			 }
			 if ($p_draw{$abk}) {
			     $p_draw{$abk} = 0;
			     plot('p',$abk);
			     delete $p_file{$abk};
			 }
			 $f->after(20, sub {
				       $delete_pane->();
				       $fill_pane->();
				       Hooks::get_hooks("after_delete_layer")->execute_except($tpath);
				   });
		     })->pack(-anchor => "w");
		$seen++;
	    }
	}
	if (!$seen) {
	    $f->Label(-text => M"Keine zusätzlichen Layer vorhanden")->pack(-anchor => "w");
	}
    };

    $fill_pane->();
    $t->Button(Name => "close",
	       -command => sub {
		   $t->destroy;
	       })->pack(-anchor => "w");

    for my $hook (qw(after_new_layer after_delete_layer)) {
	Hooks::get_hooks($hook)->add
		(sub { $delete_pane->(); $fill_pane->() }, $tpath);
    }
    $t->OnDestroy
	(sub {
	     for my $hook (qw(after_new_layer after_delete_layer)) {
		 Hooks::get_hooks($hook)->del($tpath);
	     }
	 });

}

sub tk_zoom_view_for_layer {
    additional_layer_dialog
	(-title => M"Ausschnitt an Layer anpassen",
	 -cb => sub {
	     my $abk = shift;
	     zoom_view_for_layer($abk);
	 },
	 -token => 'choose_from_additional_layer',
	);
}

sub zoom_view_for_layer {
    my $abk = shift;
    IncBusy($top);
    eval {
	my(@bbox) = $c->bbox(_layer_tag_expr($abk));
	if (@bbox) {
	    zoom_view(@bbox);
	} else {
	    die "No bbox for tag $abk: maybe the layer is empty";
	}
    };
    my $err = $@;
    DecBusy($top);
    if ($err) {
	status_message($err, 'die');
    }
}

sub tk_set_scrollregion_for_layer {
    additional_layer_dialog
	(-title => M"Scrollregion an Layer anpassen",
	 -cb => sub {
	     my $abk = shift;
	     set_scrollregion_for_layer($abk);
	 },
	 -token => 'choose_from_additional_layer',
	);
}

sub set_scrollregion_for_layer {
    my $abk = shift;
    IncBusy($top);
    eval {
	my(@bbox) = $c->bbox(_layer_tag_expr($abk));
	if (@bbox) {
	    @scrollregion = @bbox;
	    $c->configure(-scrollregion => [@scrollregion]);
	} else {
	    die "No bbox for tag $abk: maybe the layer is empty";
	}
    };
    my $err = $@;
    DecBusy($top);
    if ($err) {
	status_message($err, 'die');
    }
}

sub tk_enlarge_scrollregion_for_layer {
    additional_layer_dialog
	(-title => M"Scrollregion für Layer vergrößern",
	 -cb => sub {
	     my $abk = shift;
	     enlarge_scrollregion_for_layer($abk);
	 },
	 -token => 'choose_from_additional_layer',
	);
}

sub change_datadir {
    require Tk::DirTree;
    my $t = $top->Toplevel;
    $t->title(M"Neues Datenverzeichnis wählen");
    my $newdir = $datadir;
    my $ok = 0;
    my $f = $t->Frame->pack(-fill => "x", -side => "bottom");
    my $d = $t->Scrolled('DirTree',
			 -scrollbars => 'osoe',
			 -width => 35,
			 -height => 20,
			 -selectmode => 'browse',
			 -exportselection => 1,
			 -browsecmd => sub { $newdir = shift },
			 -command   => sub { $ok = 1 },
			)->pack(-fill => "both", -expand => 1);
    $d->chdir($newdir);
    $f->Button(Name => 'ok',
	       -command => sub { $ok = 1 })->pack(-side => 'left');
    $f->Button(Name => 'cancel',
	       -command => sub { $ok = -1 })->pack(-side => 'left');
    $f->waitVariable(\$ok);
    if ($ok == 1) {
	set_datadir($newdir);
    }
    $t->destroy;
}

use vars qw($standard_command_index $editstandard_command_index
	    @edit_mode_any_cmd);

$without_zoom_factor = 1 if !defined $without_zoom_factor;

sub set_coord_interactive {
    my $t = redisplay_top($top, 'set_coord_interactive',
			  -title => M"Punktkoordinaten setzen");
    return if !defined $t;

    my $coord_menu;
    my $coord_output = $coord_output;
    {
	require Tk::Optionmenu;
	my $f = $t->Frame->pack;
	$f->Label(-text => M("Koordinatensystem").":")->pack(-side => "left");
	$coord_menu = $f->Optionmenu(-variable => \$coord_output,
				     -options => [ (map { [ $Karte::map{$_}->name, $_ ] } @Karte::map), "canvas" ])->pack(-side => "left");
    }

    my($valx, $valy);
    my(%val2, %val3);
    my $set_sub = sub {
	my($orig) = @_;
	if ($orig == 2) {
	    require Karte::Polar;
	    $valx = Karte::Polar::dms2ddd($val2{'X'}->[0], $val2{'X'}->[1], $val2{'X'}->[2]);
	    $valy = Karte::Polar::dms2ddd($val2{'Y'}->[0], $val2{'Y'}->[1], $val2{'Y'}->[2]);
	} elsif ($orig == 3) {
	    require Karte::Polar;
	    $valx = Karte::Polar::dmm2ddd($val3{'X'}->[0], $val3{'X'}->[1]);
	    $valy = Karte::Polar::dmm2ddd($val3{'Y'}->[0], $val3{'Y'}->[1]);
	}
	my($setx, $sety);
	if ($coord_output eq 'canvas') {
	    ($setx, $sety) = ($valx, $valy);
	} else {
	    ($setx, $sety) = transpose($Karte::map{$coord_output}->map2standard($valx, $valy));
	}
	mark_point('-x' => $setx, '-y' => $sety,
		   -clever_center => 1);
    };

    my $f1 = $t->Frame->pack(-anchor => "w");
    my $lx = $f1->Label(-text => "X:");
    my $ex = $f1->Entry(-textvariable => \$valx);
    my $ly = $f1->Label(-text => "Y:");
    my $ey = $f1->Entry(-textvariable => \$valy);
    my $get_selection_sub = sub {
	my $interactive = shift;

	my $error_msg = sub {
	    my $msg = shift;
	    if ($interactive) {
		$f1->messageBox(-icon => "error",
				-message => $msg);
	    } else {
		warn $msg;
	    }
	};

	my $s;
        Tk::catch {
	    $s = $f1->SelectionGet('-selection' => ($os eq 'win'
						    ? "CLIPBOARD"
						    : "PRIMARY"));
	};
	if (defined $s && $s =~ /^\s*([NS]\d+\s+\d+\s+[\d\.]+)
				  \s+([EW]\d+\s+\d+\s+[\d\.]+)
                                  \s*$
                                /x) {
	    my($lat,$long) = ($1, $2);
	    require Karte::Polar;
	    my $y = Karte::Polar::dms_string2ddd($lat);
	    my $x = Karte::Polar::dms_string2ddd($long);
	    if (defined $x && defined $y) {
		($valx, $valy) = ($x, $y);
		$set_sub->(1);
	    } else {
		$error_msg->("Can't parse selection $s");
	    }
	} elsif (defined $s and $s =~ /\d/) {
	    $s =~ s/^[^\d.+-]+//;
	    $s =~ s/[^\d.+-]+$//;
	    my($x,$y) = split(/[^\d.+-]+/, $s);
	    if (defined $x and defined $y) {
		($valx, $valy) = ($x, $y);
		$set_sub->(1);
	    } else {
		$error_msg->("Can't parse selection $s");
	    }
	} else {
	    $error_msg->("No useable selection");
	}
    };
    my $selb = $f1->Button
	(-text => M"Selection",
	 -command => sub { $get_selection_sub->(1) });
    my $sb = $f1->Button(-text => M"Setzen",
			 -command => sub { $set_sub->(1) },
			);
    my $autocheck = 0;
    my $acb;
    my $auto_sub = sub {
	$get_selection_sub->(0);
	$set_sub->(1);
	$f1->after(100, sub {
		       $acb->invoke;
		       $acb->invoke;
		   });
    };
    $acb = $f1->Checkbutton
	(-text => M"Auto-detect",
	 -variable => \$autocheck,
	 -command => sub {
	     if ($autocheck) {
		 $f1->SelectionOwn(-command => $auto_sub);
		 # Hack to reinstall SelectionOwn handler
	     } else {
		 $f1->SelectionOwn;
	     }
	 });

    $lx->grid($ex, $selb, $acb);
    $ly->grid($ey, $sb);
    $ex->focus;

    my $polar_f;
    {
	my $f = $polar_f = $t->Frame->pack(-anchor => "w");
	for my $def (["DMS", 2],
		     ["DMM", 3],
		    ) {
	    my($dms_type, $set_sub_type) = @$def;
	    my $ff = $polar_f->Frame->pack(-anchor => "w");
	    my %label = ('Y' => M"geog. Breite ($dms_type)",
			 'X' => M"geog. Länge ($dms_type)",
			);
	    for my $ord ('Y', 'X') {
		my @e2;
		push @e2, $ff->Label(-text => $label{$ord} . ":");
		if ($dms_type eq 'DMS') {
		    for my $i (0 .. 2) {
			push @e2, $ff->Entry(-textvariable => \$val2{$ord}->[$i],
					     # seconds: place for decimal and one digit after decimal
					     -width => ($i == 2 ? 4 : 2));
			if ($i == 0) {
			    push @e2, $ff->Label(-text => "°");
			} elsif ($i == 1) {
			    push @e2, $ff->Label(-text => "'");
			} elsif ($i == 2) {
			    push @e2, $ff->Label(-text => "\"");
			    if ($ord eq 'X') {
				push @e2, $ff->Button(-text => M"Setzen",
						      -command => sub { $set_sub->($set_sub_type) },
						     );
			    }
			}
		    }
		} else {
		    push @e2, $ff->Entry(-textvariable => \$val3{$ord}->[0],
					 -width => 2);
		    push @e2, $ff->Label(-text => "°");
		    push @e2, $ff->Entry(-textvariable => \$val3{$ord}->[1],
					 -width => 6);
		    push @e2, $ff->Label(-text => "'");
		    if ($ord eq 'X') {
			push @e2, $ff->Button(-text => M"Setzen",
					      -command => sub { $set_sub->($set_sub_type) },
					     );
		    }
		}
		my $first = shift @e2;
		$first->grid(@e2);
	    }
	}
    }

    {
	# combined:
	# www.berliner-stadtplan.com, www.berlinonline.de, old Stadtplan-
	# dienst

	my $f = $t->Frame->pack(-anchor => "w", -fill => "x");
	$f->Label(-text => M"Stadtplan-URL")->pack(-side => "left");
	my $url;
	$f->Entry(-textvariable => \$url)->pack(-side => "left", -fill => "x", -expand => 1);
	$f->Button
	    (-text => M"Selection",
	     -command => sub {
		 Tk::catch {
		     $url
			 = $f1->SelectionGet('-selection' => ($os eq 'win'
							      ? "CLIPBOARD"
							      : "PRIMARY"));
		     $url =~ s/\n//g;
		 };
	     })->pack(-side => "left");
	$f->Button
	    (-text => M"Setzen",
	     -command => sub {
		 if (0 && $url =~ m{gps=(\d+)%7C(\d+)}) {
		     # XXX passt nicht ...
		     my($x, $y) = ($1, $2);
		     require Karte::Polar;
		     my $x_ddd = 13 + $x/10000;
		     my $y_ddd = 52 + $y/10000;
warn "$x $y $x_ddd $y_ddd";
		     my($tx,$ty) = transpose($Karte::Polar::obj->map2standard($x_ddd, $y_ddd));
		     mark_point('-x' => $tx, '-y' => $ty,
				-clever_center => 1);
		 } elsif ($url =~ m{x_wgs/(.*?)/y_wgs/(.*?)/}    ||
			  $url =~ m{x_wgs=(.*?)[&;]y_wgs=([\.\d]+)}
			 ) {
		     my($x, $y) = ($1, $2);
		     require Karte::Polar;
		     my $x_ddd = Karte::Polar::dmm2ddd(13, $x);
		     my $y_ddd = Karte::Polar::dmm2ddd(52, $y);
		     my($tx,$ty) = transpose($Karte::Polar::obj->map2standard($x_ddd, $y_ddd));
		     mark_point('-x' => $tx, '-y' => $ty,
				-clever_center => 1);
		 } elsif ($url =~ /ADR_ZIP=(\d+)&ADR_STREET=(.+?)&ADR_HOUSE=(.*)/) {
		     my($zip, $street, $hnr) = ($1, $2, $3);
		     local @INC = @INC;
		     push @INC, "$FindBin::RealBin/miscsrc";
		     require TelbuchDBApprox;
		     my $tb = TelbuchDBApprox->new(-approxhnr => 1);
		     my(@res) = $tb->search("$street $hnr", $zip);
		     if (!@res) {
			 status_message(M("Kein Ergebnis gefunden"), "die");
		     }
		     my($x,$y) = transpose(split /,/, $res[0]->{Coord});
		     mark_point('-x' => $x, '-y' => $y,
				-clever_center => 1);
		 } elsif ($url =~ /LL=%2B([0-9.]+)%2B([0-9.]+)/) {
 		     $valx = $2;
 		     $valy = $1;
 		     $coord_output = 'polar';
 		     $coord_menu->setOption('polar'); # XXX $Karte::map{'polar'}->name); #XXX should be better in Tk
 		     $set_sub->(1);

		 } else {
		     status_message("Can't parse <$url>", "die");
		 }
	     })->pack(-side => "left");
    }

    my $coord_menu_sub = sub {
	if ($coord_output eq 'polar') {
	    $polar_f->Walk(sub { eval { $_[0]->configure(-state => "normal") } });
	} else {
	    $polar_f->Walk(sub { eval { $_[0]->configure(-state => "disabled") } });
	}
    };

    $coord_menu->configure(-command => $coord_menu_sub);
    $coord_menu_sub->();

    $t->Popup(@popup_style);
}

sub set_line_coord_interactive {
    if (!defined $coord_output ||
	!$Karte::map{$coord_output}) {
	die M"Karte-Objekt nicht definiert... Aus/Eingabe richtig setzen!\n";
	return;
    }

    my $t = redisplay_top($top, 'set_line_coord_interactive',
			  -title => M"Linienkoordinaten setzen");
    return if !defined $t;

    my $set_sub = sub {
	my(@mark_args) = @_;
	my @coords = ();
	my $s = $t->SelectionGet('-selection' => ($os eq 'win'
						  ? "CLIPBOARD"
						  : "PRIMARY"));
	while ($s =~ /([-+]?[0-9\.]+),([-+]?[0-9\.]+)/g) {
	    push @coords, [$1,$2];
	}
	my @line_coords;
	foreach (@coords) {
	    my($valx,$valy) = @$_;
	    my($setx, $sety) = transpose($Karte::map{$coord_output}->map2standard($valx, $valy));
	    push @line_coords, [$setx, $sety];
	}
	mark_street(-coords => \@line_coords,
		    -type => 's',
		    @mark_args,
		   );
    };

    my $b = $t->Button
	(-text => M"Selection setzen",
	 -command => sub {
	     $set_sub->(-clever_center => 1);
	 })->pack;
    $b->bind("<3>" => sub {
		 $set_sub->(-dont_center => 1);
	     });
}

sub add_search_menu_entries {
    my $sbm = shift;
    $sbm->checkbutton(-label => M"Such-Statistik",
		      -variable => \$search_stat);
    $sbm->checkbutton(-label => M"Visual Search",
		      -variable => \$search_visual,
		      -command => sub {
			  if (!$search_visual) {
			      $c->delete("visual");
			  }
		      });
    my $search_algorithm = $global_search_args{'Algorithm'} || "A*";
    $sbm->cascade(-label => M"Algorithmus");
    {
	my $asbm = $sbm->Menu(-title => M"Algorithmus");
	$sbm->entryconfigure("last", -menu => $asbm);
	foreach my $a ('A*', 'C-A*', 'C-A*-2', 'srt') {
	    $asbm->radiobutton
		(-label => $a,
		 -variable => \$search_algorithm,
		 -value => $a,
		 -command => sub {
		     my $old_search_algo = $global_search_args{'Algorithm'};
		     $global_search_args{'Algorithm'} = $search_algorithm;
		     if ($net) {
			 if (   ($search_algorithm =~ /^C-A\*-2/ &&
			         $old_search_algo  !~ /^C-A\*-2/)
			     ||
				($search_algorithm !~ /^C-A\*-2/ &&
				 $old_search_algo  =~ /^C-A\*-2/)
			    ) {
			     undef $net;
			     warn "undef net";
			 }
		     }
		 }
		);
	}
    }
    $sbm->separator;
}

sub add_search_net_menu_entries {
    my $sbm = shift;
    $sbm->cascade(-label => M"Netz ändern");
    my $nsbm = $sbm->Menu(-title => M"Netz ändern");
    $sbm->entryconfigure('last', -menu => $nsbm);
    foreach my $def ([M"Straßen",  's'],
		     [M"U/S-Bahn", 'us'],
		     [M"R-Bahn", 'r'],
		     [M"Gesamtes Bahnnetz", 'rus'],
		     [M"Custom", 'custom'],
		    ) {
	my($label, $value) = @$def;
	$nsbm->radiobutton(-label => $label,
			   -variable => \$net_type,
			   -value => $value,
			   -command => \&change_net_type,
			  );
    }
    $nsbm->checkbutton(-label => M"Add fragezeichen",
		       -variable => \$add_net{fz},
		       -command => \&change_net_type,
		      );
    $nsbm->checkbutton(-label => M"Add custom",
		       -variable => \$add_net{custom},
		       -command => \&change_net_type,
		      );
    if ($devel_host) {
	$nsbm->checkbutton(-label => M"Add IS data",
			   -variable => \$add_net{is},
			   -command => \&change_net_type,
			  );
    }
    $nsbm->command(-label => M"Layer für Custom auswählen",
		   -command => sub {
		       select_layers_for_net_dialog();
		   });
}

sub advanced_coord_menu {
    my $bpcm = shift;
    $bpcm->command
      (-label => M"Straßen-Editor",
       -command => sub {
	   require BBBikeEdit;
	   BBBikeEdit::editmenu($top);
       });
    $bpcm->separator;
    $bpcm->command(-label => M"Koordinatenliste zeigen",
		   -command => \&show_coord_list);
    $bpcm->command(-label => M"Path to Selection",
		   -command => \&path_to_selection);
    $bpcm->command(-label => M"Koordinaten setzen",
		   -command => \&set_coord_interactive);
    $bpcm->command(-label => M"Linienkoordinaten setzen",
		   -command => \&set_line_coord_interactive);
    $bpcm->separator;
    {
	$bpcm->checkbutton(-label => M"Kreuzungen/Kurvenpunkte (pp) zeichnen (zukünftige Layer)",
			   -variable => \$p_draw{'pp'});
	push(@edit_mode_cmd,
	     sub {
		 $p_draw{'pp'} = 1;
	     });
	push(@standard_mode_cmd,
             sub {
		 $p_draw{'pp'} = 0;
	     });
	$bpcm->checkbutton(-label => M"pp für alle zukünftigen Layer",
			   -variable => \$p_draw{'pp-all'});
    }
    $bpcm->cascade(-label => M('Kurvenpunkte'));
    {
	my $csm = $bpcm->Menu(-title => M('Kurvenpunkte'));
	$bpcm->entryconfigure('last', -menu => $csm);
	my $coldef;
	foreach $coldef ([M"rot", '#800000'],
			 [M"grün", '#008000'],
			) {
	    $csm->radiobutton(-label    => $coldef->[0],
			      -variable => \$pp_color,
			      -value    => $coldef->[1],
			      -command  => sub {
				  $c->itemconfigure('pp',
						    -fill => $pp_color);
			      },
			     );
	}
    }
    $bpcm->checkbutton(-label => M"Präfix-Ausgabe",
		       -variable => \$use_current_coord_prefix,
		      );
    $bpcm->checkbutton(-label => M"Plätze zeichnen",
		       -variable => \$p_draw{'pl'},
		       -command => sub { plot('p','pl') },
		      );
#XXX del:
#     # XXX should move someday to bbbike, main streets menu
#     $bpcm->cascade(-label => M"Kommentare zeichnen");
#     {
# 	my $c_bpcm = $bpcm->Menu(-title => M"Kommentare zeichnen");
# 	$bpcm->entryconfigure("last", -menu => $c_bpcm);
# 	foreach my $_type (@comments_types) {
# 	    my $type = my $label = $_type;
# 	    my $def = 'comm-' . $type;
# 	    $c_bpcm->checkbutton
# 		(-label => $label,
# 		 -variable => \$str_draw{$def},
# 		 -command => sub {
# 		     my $file  = "comments_" . $type . ($edit_mode ? "-orig" : "");
# 		     plot('str', $def, Filename => $file);
# 		 },
# 		);
# 	}
#     }

    $bpcm->command(-label => M"Neu laden",
		   -command => \&reload_all,
		   -accelerator => 'Ctrl-R',
		  );
    $bpcm->separator;

    $bpcm->cascade(-label => M"Edit-Modus");
    {
	my $c_bpcm = $bpcm->Menu(-title => M"Edit-Modus");
	$bpcm->entryconfigure("last", -menu => $c_bpcm);
	$c_bpcm->command
	    (-label => M"Edit-Modus",
	     -command => sub { switch_edit_standard_mode() },
	    );
	$editstandard_command_index = $c_bpcm->index('last');
	$c_bpcm->command
	    (-label => M"Standard-Modus",
	     -command => sub { switch_standard_mode() },
	    );
	$standard_command_index = $c_bpcm->index('last');
	$c_bpcm->command
	    (-label => M"Andere Edit-Modi",
	     -command => sub { choose_edit_any_mode() },
	     );
    }
    $bpcm->cascade(-label => "Obsolete Editierfunktionen");
    {
	my $o_bpcm = $bpcm->Menu(-title => "Obsolete Editierfunktionen");
	$bpcm->entryconfigure("last", -menu => $o_bpcm);
	foreach my $def ({Label => M"Radwege",
			  Type  => 'radweg'},
			 {Label => M"Ampelschaltung",
			  Type  => 'ampel'},
			 {Label => M"Label",
			  Type  => 'label'},
			 {Label => M"Vorfahrt",
			  Type  => 'vorfahrt'}) {
	    $o_bpcm->cascade(-label => $def->{Label});
	    my $m = $o_bpcm->Menu(-title => $def->{Label});
	    $o_bpcm->entryconfigure('last', -menu => $m);
	    $m->checkbutton(-label => $def->{Label} . M"-Modus",
			    -variable => \$special_edit,
			    -onvalue => $def->{Type},
			    -offvalue => '',
			    -command => sub {
				require BBBikeEdit;
				# XXX move to autouse
				eval $def->{Type} . "_edit_toggle()";
				warn $@ if $@;
			    });
	    $m->command(-label => 'Undef all',
			-command => sub {
			    require BBBikeEdit;
			    # XXX move to autouse
			    eval $def->{Type} . "_undef_all()";
			    warn $@ if $@;
			});
	    $m->command(-label => M"Speichern als...",
			-command => sub {
			    require BBBikeEdit;
			    # XXX move to autouse
			    eval $def->{Type} . "_save_as()";
			    warn $@ if $@;
			});
	}
	$o_bpcm->checkbutton
	    (-label => M"Point-Editor",
	     -variable => \$special_edit,
	     -onvalue => "point",
	     -offvalue => "",
	     -command => sub {
		 if ($special_edit eq 'point') {
		     require PointEdit;
		     my $p = new MasterPunkte "$FindBin::RealBin/misc/masterpoints-orig";
		     $p->read;
		     if (!$net) { make_net() }
		     all_crossings();
		     $point_editor = new PointEdit
			 MasterPunkte => $p,
			     Net => $net,
				 Crossings => $crossings,
				     Top => $top;
		 } elsif ($point_editor) {
		     $point_editor->delete;
		     undef $point_editor;
		 }
	     });
	$o_bpcm->command
	    (-label => M"Beziehungs-Editor",
	     -command => sub {
		 require BBBikeEdit;
		 BBBikeEdit::create_relation_menu($top);
	     });
    }
    $bpcm->separator;
    $bpcm->cascade(-label => M"Aus/Eingabe");
    {
	my $ausm = $bpcm->Menu(-title => M"Aus/Eingabe");
	$bpcm->entryconfigure('last', -menu => $ausm);
	foreach (@Karte::map, qw(canvas)) {
	    my $name = (ref $Karte::map{$_} && $Karte::map{$_}->can('name')
			? $Karte::map{$_}->name
			: $_);
	    $ausm->radiobutton(-label => $name,
			       -variable => \$coord_output,
			       -value => $_,
			       -command => sub { set_coord_output_sub() },
			       );
	    my $index = $ausm->index('last');
	    if ($_ eq 'canvas') {
		push @edit_mode_brb_cmd, sub { $ausm->invoke($index) };
		push @edit_mode_b_cmd, sub { $ausm->invoke($index) };
	    } elsif ($_ eq 'standard') {
		push @edit_mode_standard_cmd, sub { $ausm->invoke($index) };
	    }
	}
	$ausm->checkbutton(-label => "Integer",
			   -variable => \$coord_output_int,
			  );
	$ausm->checkbutton(-label => "Without zoom factor",
			   -variable => \$without_zoom_factor,
			  );
    }

    $bpcm->cascade(-label => M"Koordinatensystem");
    {
	my $csm = $bpcm->Menu(-title => M"Koordinatensystem");
	$bpcm->entryconfigure('last', -menu => $csm);
	foreach (@Karte::map, qw(canvas)) {
	    my $o = $Karte::map{$_};
	    my $name = (ref $o && $o->can('name')
			? $o->name
			: $_);
	    $csm->radiobutton(-label => $name,
			      -value => $_,
			      -variable => \$coord_system,
			      -command => sub { set_coord_system($o) },
			      );
	    if ($_ eq 'brbmap') {
		my $index = $csm->index('last');
		push @edit_mode_brb_cmd, sub { $csm->invoke($index) };
	    } elsif ($_ eq 'berlinmap') {
		my $index = $csm->index('last');
		push @edit_mode_b_cmd, sub { $csm->invoke($index) };
	    } elsif ($_ eq 'standard') {
		my $index = $csm->index('last');
		push @standard_mode_cmd, sub { $csm->invoke($index) };
		push @edit_mode_standard_cmd, sub { $csm->invoke($index) };
	    }
	}
    }
    $bpcm->separator;
    $bpcm->command
      (-label => M"GPS-Punkte-Editor",
       -command => sub {
	   require BBBikeEdit;
	   BBBikeEdit::set_edit_gpsman_waypoint();
       });
    $bpcm->command
	(-label => M"GPS-Track bearbeiten",
	 -command => sub {
	     require BBBikeEdit;
	     BBBikeEdit::edit_gps_track_mode();
	 });
    $bpcm->command
	(-label => M"GPS-Track mit Waypoints anzeigen",
	 -command => sub {
	     require BBBikeEdit;
	     $main::global_draw_gpsman_data_p = 1; # XXX don't qualify
	     $main::global_draw_gpsman_data_s = 1;
	     BBBikeEdit::show_gps_track_mode();
	 });
    $bpcm->command
	(-label => M"GPS-Track ohne Waypoints anzeigen",
	 -command => sub {
	     require BBBikeEdit;
	     $main::global_draw_gpsman_data_p = 0; # XXX don't qualify
	     $main::global_draw_gpsman_data_s = 1;
	     BBBikeEdit::show_gps_track_mode();
	 });
    $bpcm->command
	(-label => M"GPS-Track nur mit Waypoints anzeigen",
	 -command => sub {
	     require BBBikeEdit;
	     $main::global_draw_gpsman_data_p = 1; # XXX don't qualify
	     $main::global_draw_gpsman_data_s = 0;
	     BBBikeEdit::show_gps_track_mode();
	 });
    $bpcm->checkbutton
	(-label => M"Bahn-Tracks bevorzugen",
	 -variable => \$BBBikeEdit::prefer_tracks,
	 -onvalue => 'bahn',
	 -offvalue => 'street',
	);
}

sub stderr_menu {
    my $opbm = shift;
    $opbm->checkbutton(-label => M"Status nach STDERR",
		       -variable => \$stderr);
    $opbm->checkbutton
	(-label => M"STDERR in ein Fenster",
	 -variable => \$stderr_window,
	 -command => \&stderr_window_command,
	);
}

sub stderr_window_command {
    if ($stderr_window) {
	if (!eval { require Tk::Stderr; Tk::Stderr->VERSION(1.2); }) {
	    if (!perlmod_install_advice("Tk::Stderr")) {
		$stderr_window = 0;
		return;
	    }
	}
	my $errwin = $top->StderrWindow;
	if (!$errwin || !Tk::Exists($errwin)) {
	    $top->InitStderr;
	    $errwin = $top->StderrWindow;
	    $errwin->title("BBBike - " . M("STDERR-Fenster"));
	} else {
	    $errwin = $top->RedirectStderr(1);
	}
    } elsif ($top->can("RedirectStderr")) {
	$top->RedirectStderr(0);
    }
}

sub penalty_menu {
    my $bpcm = shift;

    my @koeffs = (0.25, 0.5, 0.8, 1, 1.2, 1.5, 2, 2.5, 3, 3.5, 4, 6, 8, 10, 12, 15, 20);

    $bpcm->cascade(-label => M"Penalty");
    my $pen_m = $bpcm->Menu(-title => M"Penalty");
    $bpcm->entryconfigure('last', -menu => $pen_m);

    ######################################################################

    my $penalty_nolighting = 0;
    my $penalty_nolighting_koeff = 2;
    $pen_m->checkbutton
      (-label => M"Penalty für unbeleuchtete Straßen",
       -variable => \$penalty_nolighting,
       -command => sub {
	   if ($penalty_nolighting) {

	       my $s = new Strassen "nolighting";
	       die "Can't get nolighting" if !$s;
	       my $net = new StrassenNetz $s;
	       $net->make_net;

	       $penalty_subs{'nolightingpenalty'} = sub {
		   my($p, $next_node, $last_node) = @_;
		   if ($net->{Net}{$next_node}{$last_node} ||
		       $net->{Net}{$last_node}{$next_node}) {
		       $p *= $penalty_nolighting_koeff;
		   }
		   $p;
	       };
	   } else {
	       delete $penalty_subs{'nolightingpenalty'};
	   }
       });
    $pen_m->cascade(-label => M("Penalty-Koeffizient")." ...");
    {
	my $c_bpcm = $pen_m->Menu(-title => M("Penalty-Koeffizient")." ...");
	$pen_m->entryconfigure("last", -menu => $c_bpcm);
	foreach my $koeff (@koeffs) {
	    $c_bpcm->radiobutton(-label => $koeff,
				 -variable => \$penalty_nolighting_koeff,
				 -value => $koeff);
	}
    }
    $pen_m->separator;

    ######################################################################

    my $penalty_tram = 0;
    my $penalty_tram_koeff = 2;
    $pen_m->checkbutton
      (-label => M"Penalty für Straßenbahn auf Fahrbahn",
       -variable => \$penalty_tram,
       -command => sub {
	   if ($penalty_tram) {

	       my $s = new Strassen "comments_tram";
	       die "Can't get comments_tram" if !$s;
	       my $net = new StrassenNetz $s;
	       $net->make_net;

	       $penalty_subs{'trampenalty'} = sub {
		   my($p, $next_node, $last_node) = @_;
		   if ($net->{Net}{$next_node}{$last_node} ||
		       $net->{Net}{$last_node}{$next_node}) {
		       $p *= $penalty_tram_koeff;
		   }
		   $p;
	       };
	   } else {
	       delete $penalty_subs{'trampenalty'};
	   }
       });
    $pen_m->cascade(-label => M("Penalty-Koeffizient")." ...");
    {
	my $c_bpcm = $pen_m->Menu(-title => M("Penalty-Koeffizient")." ...");
	$pen_m->entryconfigure("last", -menu => $c_bpcm);
	foreach my $koeff (@koeffs) {
	    $c_bpcm->radiobutton(-label => $koeff,
				 -variable => \$penalty_tram_koeff,
				 -value => $koeff);
	}
    }
    $pen_m->separator;

    ######################################################################

    my $penalty_on_current_route = 0;
    my $penalty_on_current_route_koeff = 2;
    $pen_m->checkbutton
      (-label => M"Penalty für aktuelle Route",
       -variable => \$penalty_on_current_route,
       -command => sub {
	   if ($penalty_on_current_route) {
	       my %realcoords_hash;
	       foreach (@realcoords) {
		   $realcoords_hash{join(",",@$_)}++;
	       }

	       $penalty_subs{'currentroutepenalty'} = sub {
		   my($p, $next_node) = @_;
		   if ($realcoords_hash{$next_node}) {
		       $p *= $penalty_on_current_route_koeff;
		   }
		   $p;
	       };
	   } else {
	       delete $penalty_subs{'currentroutepenalty'};
	   }
       });
    $pen_m->cascade(-label => M("Penalty-Koeffizient")." ...");
    {
	my $c_bpcm = $pen_m->Menu(-title => M("Penalty-Koeffizient")." ...");
	$pen_m->entryconfigure("last", -menu => $c_bpcm);
	foreach my $koeff (@koeffs) {
	    $c_bpcm->radiobutton(-label => $koeff,
				 -variable => \$penalty_on_current_route_koeff,
				 -value => $koeff);
	}
    }
    $pen_m->separator;

    ######################################################################

    use vars qw($bbd_penalty);
    $bbd_penalty = 0;
    $pen_m->checkbutton
      (-label => M"Penalty für BBD-Datei",
       -variable => \$bbd_penalty,
       -command => sub {
	   if ($bbd_penalty) {
	       require BBBikeEdit;
	       BBBikeEdit::build_bbd_penalty_for_search();
	   } else {
	       delete $penalty_subs{'bbdpenalty'};
	   }
       });
    $pen_m->command
      (-label => M"BBD-Datei auswählen",
       -command => sub {
	   require BBBikeEdit;
	   BBBikeEdit::choose_bbd_file_for_penalty();
       });
#    $pen_m->cascade(-label => M("Penalty-Koeffizient")." ...");
    $BBBikeEdit::bbd_penalty_koeff = 2
	if !defined $BBBikeEdit::bbd_penalty_koeff;
    $pen_m->command
	(-label => M("Penalty-Koeffizient")." ...",
	 -command => sub
	 {
	     my $t = redisplay_top($top, "bbd-koeff", -title => M"Penalty-Koeffizient für BBD-Datei");
	     return if !defined $t;
	     require Tk::LogScale;
	     Tk::grid($t->Label(-text => M"Koeffizient"),
		      $t->Entry(-textvariable => \$BBBikeEdit::bbd_penalty_koeff)
		     );
	     Tk::grid($t->LogScale(-from => 0.25, -to => 20,
				   -resolution => 0.01,
				   -showvalue => 0,
				   -orient => 'horiz',
				   -variable => \$BBBikeEdit::bbd_penalty_koeff,
				   -command => sub {
				       $BBBikeEdit::bbd_penalty_koeff =
					   sprintf "%.2f", $BBBikeEdit::bbd_penalty_koeff,;
				   }
				  ),
		      -columnspan => 2, -sticky => "we"
		     );
	     Tk::grid($t->Checkbutton(-text => M"Multiplizieren",
				      -variable => \$BBBikeEdit::bbd_penalty_multiply,
				     ),
		      -columnspan => 2, -sticky => "w"
		     );
	     Tk::grid($t->Checkbutton(-text => M"Daten invertieren",
				      -variable => \$BBBikeEdit::bbd_penalty_invert,
				      -command => sub {
					  BBBikeEdit::build_bbd_penalty_for_search();
				      },
				     ),
		      -columnspan => 2, -sticky => "w"
		     );
	     Tk::grid($t->Button(Name => "close",
				 -command => sub { $t->withdraw }),
		      -columnspan => 2, -sticky => "we"
		     );
	     $t->protocol("WM_DELETE_WINDOW" => sub { $t->withdraw });
	 }
	);
    $pen_m->separator;

    ######################################################################

    use vars qw($st_net_penalty);
    $st_net_penalty = 0;
    $pen_m->checkbutton
      (-label => M"Penalty für Net/Storable-Datei",
       -variable => \$st_net_penalty,
       -command => sub {
	   if ($st_net_penalty) {
	       require BBBikeEdit;
	       BBBikeEdit::build_st_net_penalty_for_search();
	   } else {
	       delete $penalty_subs{'stnetpenalty'};
	   }
       });
    $pen_m->command
      (-label => M"Net/Storable-Datei auswählen",
       -command => sub {
	   require BBBikeEdit;
	   BBBikeEdit::choose_st_net_file_for_penalty();
       });
    $BBBikeEdit::st_net_koeff = 1
 	if !defined $BBBikeEdit::st_net_koeff;
     $pen_m->command
 	(-label => M("Penalty-Koeffizient")." ...",
	 -command => sub
	 {
	     my $t = redisplay_top($top, "bbd-koeff", -title => M"Penalty-Koeffizient für Net/Storable-Datei");
	     return if !defined $t;
	     Tk::grid($t->Label(-text => M"Koeffizient"),
		      $t->Entry(-textvariable => \$BBBikeEdit::st_net_koeff)
		     );
	     {
		 my $f = $t->Frame;
		 Tk::grid($f, -columnspan => 2, -sticky => "we");

		 Tk::grid($f->Label(-text => M"Schwächen"),
			  $f->LogScale(-from => 0.25, -to => 4,
				       -resolution => 0.1,
				       -showvalue => 0,
				       -orient => 'horiz',
				       -variable => \$BBBikeEdit::st_net_koeff,
				       -command => sub {
					   $BBBikeEdit::st_net_koeff =
					       sprintf "%.2f", $BBBikeEdit::st_net_koeff,;
				       }
				      ),
			  $f->Label(-text => M"Verstärken"),
			  -sticky => "we",
			 );
	     }
	     Tk::grid($t->Button(Name => "close",
				 -command => sub { $t->withdraw }),
		      -columnspan => 2, -sticky => "we"
		     );
	     $t->protocol("WM_DELETE_WINDOW" => sub { $t->withdraw });
	 }
	);
    $pen_m->separator;

    ######################################################################

    my $gps_search_penalty = 0;
    $pen_m->checkbutton
      (-label => M"Penalty für besuchte GPS-Punkte",
       -variable => \$gps_search_penalty,
       -command => sub {
	   if ($gps_search_penalty) {
	       require BBBikeEdit;
	       BBBikeEdit::build_gps_penalty_for_search();
	   } else {
	       delete $penalty_subs{'gpspenalty'};
	   }
       });
    $pen_m->cascade(-label => M("Penalty-Koeffizient")." ...");
    {
	$BBBikeEdit::gps_penalty_koeff = 2
	    if !defined $BBBikeEdit::gps_penalty_koeff;
	my $c_bpcm = $pen_m->Menu(-title => M("Penalty-Koeffizient")." ...");
	$pen_m->entryconfigure("last", -menu => $c_bpcm);
	foreach my $koeff (@koeffs) {
	    $c_bpcm->radiobutton(-label => $koeff,
				 -variable => \$BBBikeEdit::gps_penalty_koeff,
				 -value => $koeff);
	}
	$c_bpcm->separator;
	$c_bpcm->checkbutton(-label => M"Multiplizieren",
			     -variable => \$BBBikeEdit::gps_penalty_multiply,
			    );
    }

}

# Return true if there was a modification.
# Arguments: $oper_name
#   $oper_name is something like "insert" or "delete"
### AutoLoad Sub
sub _insert_points_and_co ($) {
    my $oper_name = shift;
    my $vstr = ($verbose ? " -v" : "");
    my $ret = 0;
    eval {
	require "$FindBin::RealBin/miscsrc/insert_points";
	my @args = (-operation => $oper_name,
		    (-e "$datadir/.custom_files" ? (-addfilelist => "$datadir/.custom_files") : ()),
		    "-useint", # XXX but not for polar coordinates
		    -datadir => $datadir,
		    -bbbikerootdir => $FindBin::RealBin,
		    "-tk",
		    ($vstr ne "" ? $vstr : ()),
		   );
#XXX:
# 	if (!$SRTShortcuts::force_edit_mode) {
# 	    push @args, (
# 			 (!defined $edit_mode || $edit_mode eq '' ? "-noorig" : ()),
# 			 ($coord_system_obj->coordsys eq 'B' || !defined $edit_mode || $edit_mode eq '' ? () : (-coordsys => $coord_system_obj->coordsys)),
# 			);
# 	}
	warn "@args\n";
	my $modify_ret = BBBikeModify::process(@args);
	$ret = $modify_ret == BBBikeModify::RET_MODIFIED();

	# clear the selection (sometimes)
	if ($modify_ret != BBBikeModify::RET_ERROR() && $oper_name ne "grep") {
	    delete_route();
	}
    };
    warn $@ if $@;
    $ret;
}

sub insert_points { _insert_points_and_co("insert")     }
sub insert_multi_points { _insert_points_and_co("insertmulti") }
sub change_points { _insert_points_and_co("change")     }
sub change_line   { _insert_points_and_co("changeline") }
sub grep_point    { _insert_points_and_co("grep")       }
sub grep_line	  { _insert_points_and_co("grepline")   }
sub delete_point  { _insert_points_and_co("delete")     }
sub delete_lines  { _insert_points_and_co("deletelines") }
sub change_poly_points {
    # XXX NYI
}

sub find_canvas_item_file {
    my $ev = $_[0]->XEvent;
    my($X,$Y) = ($ev->X, $ev->Y);
    my $w = $_[0]->containing($X,$Y);
    my($abk, $pos);
    if ($w || $w eq $c) {
	my(@tags) = $c->gettags('current');
	$abk = $tags[0];
	for my $tag_i (4, 3) {
	    if (defined $tags[$tag_i] && $tags[$tag_i] =~ /-(\d+)$/) {
		$pos = $1;
		last;
	    }
	}
    }
    if (defined $abk && (exists $str_file{$abk} ||
			 exists $p_file{$abk})) {
	my($p_f, $str_f);
	if (exists $p_file{$abk}) {
	    $p_f = (file_name_is_absolute($p_file{$abk})
		    ? "$p_file{$abk}-orig"
		    : "$datadir/$p_file{$abk}-orig"
		   );
	    if (-r $p_f) {
		my $linenumber = "";
		if (defined $pos) {
		    $linenumber = Strassen::get_linenumber($p_f, $pos);
		    if (defined $linenumber) {
			$linenumber = "+$linenumber";
		    }
		}
		system("emacsclient -n $linenumber $p_f");
	    }
	}
	if (exists $str_file{$abk}) {
	    $str_f = (file_name_is_absolute($str_file{$abk})
		      ? "$str_file{$abk}-orig"
		      : "$datadir/$str_file{$abk}-orig"
		     );
	    if (exists $str_file{$abk} && -r $str_f && $p_f ne $str_f) {
		my $linenumber = "";
		if (defined $pos) {
		    $linenumber = Strassen::get_linenumber($str_f, $pos);
		    if (defined $linenumber) {
			$linenumber = "+$linenumber";
		    }
		}
		system("emacsclient -n $linenumber $str_f");
	    }
	}
    } else {
	system("emacsclient -n $datadir");
    }
}

sub advanced_bindings {
    $top->bind("<F2>" => \&insert_points);
    $top->bind("<F3>" => \&change_points);
    $top->bind("<F8>" => sub {
		   my $ev = $_[0]->XEvent;
		   my($X,$Y) = ($ev->X, $ev->Y);
		   my $w = $_[0]->containing($X,$Y);
		   return if !$w || $w ne $c;

		   require BBBikeEdit;
		   my $e = BBBikeEdit->create;
		   $e->click;
	       });
    $top->bind("<F9>" => sub { find_canvas_item_file(@_) });
}

sub destroy_all_toplevels {
    while(my($token, $w) = each %toplevel) {
	warn "Trying to destroy toplevel $token...\n";
	$w->destroy if Tk::Exists($w);
	delete $toplevel{$token};
    }

    # Special toplevels:
    my $w = $top->Subwidget("Statistics");
    $w->destroy if Tk::Exists($w);
}

use vars qw(%module_time %module_check $main_check_time);

$main_check_time = -M $0;

### AutoLoad Sub
sub check_new_modules {
    no strict 'refs';
    my $pkg = shift;
    $pkg = 'main' if (!defined $pkg);
    my $loop = shift || 0;
    die "Recursion break on $pkg", return if $loop > 10;
    #warn "checking new modules for $pkg..." if $verbose; # nervig
    my %inc = %{$pkg."::INC"};
    while(my($k, $v) = each %inc) {
	# only record BBBike-related and own modules
	next if $v !~ /bbbike/i && $v !~ /\Q$ENV{HOME}/;
	next if exists $module_time{$v};
	$module_time{$v} = (stat($v))[9];
	warn "recorded $module_time{$v} for $k\n" if $verbose;
    }
    $module_check{$pkg}++ if defined $pkg;
    my @stash_keys = keys %{$pkg."::"};
    foreach my $sym (@stash_keys) {
	if ($sym =~ /^(.*)::$/) {
	    my $subpkg = ($pkg eq 'main'
			  ? $1
			  : $pkg . "::" . $1);
	    if (!exists $module_check{$subpkg}) {
		check_new_modules($subpkg, $loop+1);
	    }
	}
    }
}

### AutoLoad Sub
sub reload_new_modules {
    my @check_c;
    while(my($k, $v) = each %module_time) {
	my $now = (stat($k))[9];
	next if $v >= $now;
	next if $k =~ /^\Q$tmpdir\/bbbike_reload/;
	print STDERR "Reloading $k...\n";
	eval { do $k };
	push @check_c, $k;
	warn "*** $@" if $@;
	$module_time{$k} = $now;
    }
    if ($tmpdir && -M $0 < $main_check_time) {
	if (open(MAIN, $0)) {
	    my $tmpfile = "$tmpdir/bbbike_reload_$$.pl";
	    $tmpfiles{$tmpfile}++;
	    if (open(SAVEMAIN, ">$tmpfile")) {
		my $found = 0;
		while(<MAIN>) {
		    if ($found) {
			print SAVEMAIN $_;
		    } elsif (/RELOADER_START/) {
			$found++;
			print SAVEMAIN "# line $. $0\n";
		    }
		}
		close SAVEMAIN;
		if (!$found) {
		    print STDERR "WARNING: RELOADER_START tag not found!\n";
		}
		print STDERR "Reloading main...\n";
		eval { do $tmpfile };
		if (!$@) {
		    unlink $tmpfile;
		    if ($verbose) {
			warn "Re-call some functions in main script...\n";
		    }
		    eval {
			generate_plot_functions();
			set_bindings();
		    };
		    warn $@ if $@;
		} else {
		    warn "*** Found errors: $@";
		}
	    } else {
		warn "Can't write to $tmpfile: $!";
	    }
	    close MAIN;
	    push @check_c, $0;
	} else {
	    warn "Can't open $0: $!";
	}
	$main_check_time = -M $0;
    }

    # Check reloaded files for compile errors...
    if (@check_c && $os eq 'unix') {
	pipe(RDR, WTR);
	if (fork == 0) {
	    close RDR;
	    my @problems;
	    for my $f (@check_c) {
		my @cmd = ($^X, "-I$FindBin::RealBin/lib", "-I$FindBin::RealBin", "-c", $f);
		warn "@cmd\n";
		system @cmd;
		if ($? != 0) {
		    push @problems, $f;
		}
	    }
	    if (@problems) {
		print WTR join("\n", @problems), "\n";
	    }
	    close WTR;
	    CORE::exit(0);
	}
	close WTR;
	$top->fileevent
	    (\*RDR, 'readable',
	     sub {
		 my $buf = "";
		 while(<RDR>) {
		     $buf .= $_;
		 }
		 if ($buf ne "") {
		     $top->messageBox
			 (-icon => "error",
			  -type => "Ok",
			  -message => "Compile problems with the following files:\n" . $buf,
			 );
		 }
		 close RDR;
		 $top->fileevent(\*RDR, 'readable', '');
	     }
	    );
    }
}

############################################################
# Selection-Kram (Koordinatenliste, buttonpoint et al.)
#

# Gibt den angewählten Punkt aus.
# Ausgegeben wird: Name (soweit vorhanden), Canvas-Koordinaten und
# die Koordinaten abhängig von $coord_output_sub (gewöhnlich berlinmap).
# Außerdem werden die $coord_output_sub-Koordinaten in die Selection
# geschrieben.
### AutoLoad Sub
sub buttonpoint {
    my($x, $y, $current) = @_;
    $c->SelectionOwn(-command => sub {
			 @inslauf_selection = ();
			 # kein reset_ext_selection, weil dann beim Anklicken
			 # auf $coordlist_lbox die Selection verschwindet
			 @ext_selection = ();
		     });
    my $prefix = (defined $coord_prefix
		  ? $coord_prefix
		  : ($use_current_coord_prefix
		     ? $coord_system_obj->coordsys
		     : ''
		    )
		 );
    if (defined $x) {
	my $coord = sprintf "$prefix%s,%s", $coord_output_sub->($x, $y);
	push(@inslauf_selection, $coord);
	$c->clipboardAppend(" $coord") if $use_clipboard;
	my $ext = prepare_selection_line
	    (-name => "?",
	     -coord1 => Route::_coord_as_string([$x,$y]),
	     -coord2 => $coord);
	push_ext_selection($ext);
	print STDERR $ext, "\n";
    } else {
	$current = 'current' if !defined $current;
	my(@tags) = $c->gettags($current);
	return if !@tags || !defined $tags[0];
	if ($tags[0] eq 'p'    ||
	    $tags[0] eq 'o'    ||
	    $tags[0] eq 'pp'   ||
	    $tags[0] =~ /^lsa/ ||
	    $tags[0] =~ /^L\d+/||
	    $tags[0] eq 'fz'   ||
	    $tags[0] =~ /^kn/
	   ) {
	    my($tag, $s);
	    $tag = $tags[1];
	    if ($tags[0] eq 'p') {
		my($cx, $cy) = $koord->get($tag);
		my($x, $y) = $coord_output_sub->($cx, $cy);
		$s = prepare_selection_line
		    (-name => substr(Strassen::strip_bezirk($names[$tag]),
				     0, 40),
		     -coord1 => Route::_coord_as_string([$cx,$cy]),
		     -coord2 => Route::_coord_as_string([$x,$y]),
		     -tag => $tag);
		push(@inslauf_selection, $tag);
		$c->clipboardAppend(" $tag") if $use_clipboard;
		push_ext_selection($s);
	    } elsif ($tags[0] eq 'pp' || $tags[0] =~ /^lsa/ ||
		     $tags[0] =~ /^L\d+/) {
		my $use_prefix = 1;
		my($x, $y) = $coord_output_sub->
		  (@{Strassen::to_koord1($tags[1])});
		if ($tags[2] =~ m|^(.*\.wpt)/(\d+)/|) {
		    my($wpt_file,$wpt_nr) = ($1,$2);
		    system q{gnuclient -batch -eval '(find-file "~/src/bbbike/misc/gps_data/}.$wpt_file.q{") (goto-char (point-min)) (search-forward-regexp "^}.$wpt_nr.q{\t")'};
		} elsif ($tags[2] =~ /^ORIG:(.*),(.*)$/) {
		    ($x, $y) = ($1, $2);
		    $use_prefix = 0;
		}
		# XXX verallgemeinern!!!
		my $crossing = "?";
		if ($edit_mode) { # XXX $edit_normal_mode too?
		    all_crossings();
		}
		if (exists $crossings->{$tags[1]}) {
		    $crossing = join("/", map { Strassen::strip_bezirk($_) }
				              @{ $crossings->{$tags[1]} });
		}
		$s = prepare_selection_line
		    (-name => $crossing,
		     -coord1 => $tags[1],
		     -coord2 => Route::_coord_as_string([$x,$y]));
		my $str = ($use_prefix ? $prefix : "") . Route::_coord_as_string([$x,$y]);
		push(@inslauf_selection, $str);
		$c->clipboardAppend(" $str") if $use_clipboard;
		push_ext_selection($s);
	    } elsif ($tags[0] eq 'o' ||
		     $tags[0] eq 'fz') {
		my($cx, $cy) = anti_transpose($c->coords($current));
		my($x, $y) = $coord_output_sub->($cx, $cy);
		my $name = ($tags[0] eq 'o'
			    ? substr(Strassen::strip_bezirk($tag), 0, 40)
			    : $tags[1]);
		$s = prepare_selection_line
		  (-name => $name,
		   -coord1 => Route::_coord_as_string([$cx,$cy]),
		   -coord2 => Route::_coord_as_string([$x,$y]));
		my $str = $prefix . Route::_coord_as_string([$x,$y]);
		push(@inslauf_selection, $str);
		$c->clipboardAppend(" $str") if $use_clipboard;
		push_ext_selection($s);
	    } else {
		die "Tag $tags[0] wird für das Aufzeichnen von Punkten nicht unterstützt";
	    }
	    $s .= "\n";
	    print STDERR $s;
	}
    }
}

### AutoLoad Sub
sub prepare_selection_line {
    my(%args) = @_;
    if ($os eq 'win') { # XXX
	if (0) { # XXX
	    $args{-coord1} . " ";
	} else {
	    sprintf("%-13s %-33s\n",
		    $args{-coord1},
		    substr($args{-name}, 0, 33));
	}
    } else { # XXX old
	sprintf("%-40s %-15s %-15s",
		$args{-name}, $args{-coord1}, $args{-coord2})
	    . (exists $args{-tag} ? " $args{-tag}" : "");
    }
}

### AutoLoad Sub
sub push_ext_selection {
    my(@a) = @_;
    push @ext_selection, @a;
    if (defined $coordlist_lbox && Tk::Exists($coordlist_lbox)) {
	if (subw_isa($coordlist_lbox, 'Tk::Text')) {
	    $coordlist_lbox->insert('end', join($coordlist_lbox_nl,
						@a) . $coordlist_lbox_nl);
	} else {
	    $coordlist_lbox->insert('end', @a);
	}
	$coordlist_lbox->see('end');
    }
}

### AutoLoad Sub
sub reset_ext_selection {
    @ext_selection = ();
    if (defined $coordlist_lbox && Tk::Exists($coordlist_lbox)) {
	if (subw_isa($coordlist_lbox, 'Tk::Text')) {
	    $coordlist_lbox->delete("1.0", 'end');
	} else {
	    $coordlist_lbox->delete(0, 'end');
	}
    }
}

### AutoLoad Sub
sub reset_selection {
    @inslauf_selection = ();
    $c->clipboardClear() if $use_clipboard;
    reset_ext_selection();
}

### AutoLoad Sub
sub show_coord_list {
    my $coordlist_top = redisplay_top($top, 'coordlist',
				      -title => M"Koordinatenliste");
    return if !defined $coordlist_top;
    if (1 || $os eq 'win') { # XXX (1) # unter Win32 funktionieren Selections anders
	require Tk::ROText;
	$coordlist_lbox = $coordlist_top->Scrolled
	    ('ROText', -font => $font{'fixed'},
	     -width => 80,
	     -scrollbars => 'osoe')->pack;
	$coordlist_lbox_nl = "";
    } else {
	$coordlist_lbox = $coordlist_top->Scrolled
	    ('Listbox', -font => $font{'fixed'},
	     -width => 80,
	     -selectmode => 'extended',
	     -scrollbars => 'osoe')->pack;
    }
    if (@ext_selection) {
	$coordlist_lbox->insert('end',
				(subw_isa($coordlist_lbox, 'Tk::Text')
				 ? join($coordlist_lbox_nl, @ext_selection)
				 : @ext_selection));
    }
    $coordlist_top->Button
      (Name => 'end',
       -command => sub { $coordlist_top->destroy },
      )->pack;
    $coordlist_top->Popup(@popup_style);
}

######################################################################
#
# Zusätzliche Zeichenfunktionen
#

# Zeichnet Haltestellen-Informationen aus der Hafas-Datenbank.
# Funktioniert nur für ältere Daten.
# Fraglich, ob diese Funktion noch benötigt wird...
### AutoLoad Sub
sub ploths {
    status_message("");

    $c->delete("p");		# evtl. alte Koordinaten löschen
    if (!$p_draw{'p'}) {
	return;
    }

    my $anzahl_eindeutig;
    eval {
	require Fahrinfo;
	my $eh = tie @names, 'Fahrinfo::Eind_haltestellen';
	if (!$koord) {
	    $koord = new Fahrinfo::Koord $eh;
	}
	$anzahl_eindeutig = $eh->{'haltestellen'}{'anzahl_eindeutig'};
    };
    if ($@) {
	status_message($@, 'err');
	return;
    }

    destroy_delayed_restack();

    IncBusy($top);
    $progress->Init(-dependents => $c,
		    -label => 'Haltestellen');
    eval {
	# mit nextdirect geht es am schnellsten
	$koord->initnextdirect;
	for my $i (0 .. $anzahl_eindeutig-1) {
	    my ($tx, $ty) = transpose($koord->nextdirect);
	    $progress->Update($i/$anzahl_eindeutig)
	      if $i % 80 == 0;
	    $c->createLine
	      ($tx, $ty, $tx, $ty,
	       -tags => ['p', $i]);
	}

	$c->itemconfigure('p',
			  -capstyle => 'round',
			  -width => 5,
			  -fill => 'blue',
			 );
	restack_delayed();
    };
    $progress->Finish;
    DecBusy($top);
}

######################################################################
#
# Edit/Standard-Modus
#

# Löscht die aktiven Straßen und Punkte und merkt sie sich in
# für das spätere Wiederzeichnen in set_remember_plot.
### AutoLoad Sub
sub remove_plot {
    undef @remember_plot_str;
    my $abk;
    foreach $abk (keys %str_draw) {
	if ($str_draw{$abk}) {
	    $str_draw{$abk} = 0;
	    plot('str',$abk);
	    push @remember_plot_str, $abk;
	}
	if (defined $str_obj{$abk}) {
	    undef $str_obj{$abk};
	}
    }
    undef @remember_plot_p;
    foreach $abk (keys %p_draw) {
	next if $abk =~ /^pp/;
	if ($p_draw{$abk}) {
	    $p_draw{$abk} = 0;
	    plot('p',$abk);
	    push @remember_plot_p, $abk;
	}
    }
    delete_map();
    $map_draw = 0; # XXX
}

# Zeichnet die Strecken und Punkte neu, die in remove_plot() gelöscht wurden.
### AutoLoad Sub
sub set_remember_plot {
    my $abk;
    $progress->InitGroup;
    foreach $abk (@remember_plot_str) {
	if (!$str_draw{$abk}) {
	    $str_draw{$abk} = 1;
	    plot('str',$abk);
	}
    }
    foreach $abk (@remember_plot_p) {
	if (!$p_draw{$abk}) {
	    $p_draw{$abk} = 1;
	    plot('p',$abk);
	}
    }
    $progress->FinishGroup;
}

# Schaltet in einen der folgenden Modi um.
### AutoLoad Sub
sub switch_mode {
    my $mode = shift;
    if ($mode eq 'std') {
	switch_standard_mode(@_);
    } elsif ($mode eq 'std-no-orig') {
	switch_edit_standard_mode(@_);
    } elsif ($mode eq 'b') {
	switch_edit_berlin_mode(@_);
    } elsif ($mode eq 'brb') {
	switch_edit_brb_mode(@_);
    } else {
	die "Unknown mode for switch_mode: $mode";
    }
}

# Schaltet in den Standard-Modus um.
### AutoLoad Sub
sub switch_standard_mode {
    my $init = shift;
    IncBusy($top) unless $init;
    eval {
	my($oldx, $oldy) =
	    $coord_system_obj->map2standard
		(anti_transpose($c->get_center));
	remove_plot() unless $init;
	foreach (@standard_mode_cmd) { $_->() }

	# Special handling for hoehe (here also needed?)
	delete $p_obj{hoehe};
	%hoehe = ();

	$map_mode = MM_SEARCH();
	gui_set_edit_mode(0);
	$do_flag{'start'} = $do_flag{'ziel'} = 1; # XXX better solution
	set_remember_plot() unless $init;
	$ampelstatus_label_text = "";
	$c->center_view
	    (transpose($coord_system_obj->standard2map($oldx, $oldy)),
	     NoSmoothScroll => 1);
    };
    my $err = $@;
    DecBusy($top) unless $init;
    status_message($err, "die") if $err;
}

sub set_edit_mode {
    my($flag) = @_;
    $edit_mode_flag = $flag if defined $flag;
    if ($edit_mode_flag) {
	#XXX del switch_edit_berlin_mode();
	switch_edit_standard_mode();
    } else {
	switch_standard_mode();
    }
    set_map_mode();
}

# Schaltet in den Edit-Standard-Modus um.
### AutoLoad Sub
sub switch_edit_standard_mode {
    my $init = shift;
    IncBusy($top) unless $init;
    eval {
	my($oldx, $oldy) =
	    $coord_system_obj->map2standard
		(anti_transpose($c->get_center));
	remove_plot() unless $init;
	foreach (@edit_mode_cmd) { $_->() }
	foreach (@edit_mode_standard_cmd) { $_->() }

	# Special handling for hoehe, because it's preloaded
	delete $p_obj{hoehe};
	%hoehe = ();

	$map_mode = MM_BUTTONPOINT();
	$use_current_coord_prefix = 0;
	$coord_prefix = "";
	gui_set_edit_mode('std-no-orig');
	$do_flag{'start'} = $do_flag{'ziel'} = 1; # XXX better solution
	local $lazy_plot = 1;
	set_remember_plot() unless $init;

	$p_draw{'pp'} = 1; # XXX This is also set in @edit_mode_cmd,
                           # but maybe setting there is too late?

	$c->center_view
	    (transpose($coord_system_obj->standard2map($oldx, $oldy)),
	     NoSmoothScroll => 1);
	if ($unit_km eq 'km') {
	    change_unit();
	}
    };
    my $err = $@;
    DecBusy($top) unless $init;
    status_message($err, "die") if $err;
}

# Schaltet in den Edit-Mode für Berlin um.
### AutoLoad Sub
sub switch_edit_berlin_mode {
    my $init = shift;
    my($oldx, $oldy) =
      $coord_system_obj->map2standard
	(anti_transpose($c->get_center));
    remove_plot() unless $init;
    foreach (@edit_mode_cmd) { $_->() }
    foreach (@edit_mode_b_cmd) { $_->() }
    $map_mode = MM_BUTTONPOINT();
    $use_current_coord_prefix = 0;
    $coord_prefix = undef;
    $wasserstadt = 1;
    $wasserumland = 0;
    $str_far_away{'w'} = 0;
    gui_set_edit_mode('b');
    $do_flag{'start'} = $do_flag{'ziel'} = 0;
    set_remember_plot() unless $init;
    $c->center_view
	(transpose($coord_system_obj->standard2map($oldx, $oldy)),
	 NoSmoothScroll => 1);
}

# Schaltet in den Edit-Mode für das Umland (Brandenburg) um.
### AutoLoad Sub
sub switch_edit_brb_mode {
    my $init = shift;
    my($oldx, $oldy) =
      $coord_system_obj->map2standard
	(anti_transpose($c->get_center));
    remove_plot() unless $init;
    foreach (@edit_mode_cmd) { $_->() }
    foreach (@edit_mode_brb_cmd) { $_->() }
    $map_mode = MM_BUTTONPOINT();
    $use_current_coord_prefix = 1;
    $coord_prefix = undef;
    $wasserstadt = 0;
    $wasserumland = 1;
    $place_category = 0;
    gui_set_edit_mode('brb');
    $do_flag{'start'} = $do_flag{'ziel'} = 0;
    set_remember_plot() unless $init;
    $c->center_view
	(transpose($coord_system_obj->standard2map($oldx, $oldy)),
	 NoSmoothScroll => 1);
}

# Schaltet in den Edit-Mode für beliebige Karten um.
### AutoLoad Sub
sub switch_edit_any_mode {
    my($map, $init) = @_;
    my($oldx, $oldy) =
      $coord_system_obj->map2standard
	(anti_transpose($c->get_center));
    remove_plot() unless $init;
    foreach (@edit_mode_cmd) { $_->() }
    foreach (@edit_mode_any_cmd) { $_->() }
    $map_mode = MM_BUTTONPOINT();
    $map_default_type = $coord_system;
    $use_current_coord_prefix = 1;
    $coord_prefix = undef;
    gui_set_edit_mode($map);
    $do_flag{'start'} = $do_flag{'ziel'} = 0;
    set_remember_plot() unless $init;
    $c->center_view
	(transpose($coord_system_obj->standard2map($oldx, $oldy)),
	 NoSmoothScroll => 1);
}

# Schaltet in den Edit-Mode für beliebige Karten um.
### AutoLoad Sub
sub choose_edit_any_mode {
    my $t = $top->Toplevel(-title => M"Editmodus wählen");
    $t->transient($top) if $transient;
    my $choose_coord_system;
    foreach (@Karte::map, qw(canvas)) {
	my $o = $Karte::map{$_};
	my $name = (ref $o && $o->can('name')
		    ? $o->name
		    : $_);
	$t->Radiobutton(-text => $name,
			-value => $_,
			-variable => \$choose_coord_system,
			)->pack(-anchor => "w");
    }
    {
	my $f = $t->Frame->pack;
	my $okb = $f->Button
	    (Name => "ok",
	     -command => sub {
		 if (!defined $choose_coord_system) {
		     $t->messageBox(-message => "Bitte Editmodus auswählen");
		     return;
		 }
		 $coord_system = $choose_coord_system;
		 set_coord_system($Karte::map{$coord_system});
		 switch_edit_any_mode($coord_system, 0);
		   $t->destroy;
	     })->pack(-side => "left");
	$t->bind("<Return>" => sub { $okb->invoke });
	my $cb = $f->Button
	    (Name => "cancel",
	     -command => sub { $t->destroy })->pack(-side => "left");
	$t->bind("<Escape>" => sub { $cb->invoke });
    }
    $t->Popup(@popup_style);
}

# Erzeugt einen Hash aller Kreuzungen
### AutoLoad Sub
sub all_crossings {
    if (!keys %$crossings) {
	my $s = new Strassen "strassen-orig";
	$crossings = $s->all_crossings(RetType => 'hash',
				       UseCache => 1);
    }
}

### AutoLoad Sub
sub search_movie {
    if (!eval { require "miscsrc/kino-berlin.pl" }) {
	return status_message(Mfmt("Das Programm kino-berlin.pl konnte nicht geladen werden: %s", $@), "error");
    }
    Kino::Berlin::init("$FindBin::RealBin/miscsrc");

    my $start;
    if (!@search_route_points || !$search_route_points[0]->[0]) {
	if (defined $center_on_str) {
	    my $plz = new PLZ;
	    my @res = $plz->look($center_on_str);
	    if (@res) {
		$start = $res[0]->[3];
	    }
	}
	die "Startpunkt nicht gesetzt" if !$start;
    } else {
	$start = $search_route_points[0]->[0];
    }

    my $entry_t = $top->Toplevel(-title => "Movie");
    my $movie;
    my $entry = $entry_t->Entry(-textvariable => \$movie)->pack;
    $entry_t->idletasks;
    $entry->focus;
    $entry_t->bind("<<CloseWin>>" => sub { $entry_t->destroy });
    $entry->bind
	("<Return>" => sub {
	     my @res;
	     IncBusy($top);
	     eval {
		 @res = Kino::Berlin::search_nearest_cinema($movie, $start);
	     };
	     warn $@ if $@;
	     DecBusy($top);

	     if (@res) {
		 my $coords;
		 Kino::Berlin::tk_result
			 ($top, \@res,
			  -variable  => \$coords,
			  -selsignal => sub {
			      print $coords, "\n";
			      $start = $search_route_points[0]->[0] || $start;
			      set_route_start($start);
			      set_route_ziel($coords);
			      zoom_view();
			  },
			  -getstartcoords => sub {
			      $search_route_points[0]->[0] || $start;
			  },
			  -transient => $top,
			 );
	     }

	     $entry_t->destroy;

	 });
    $entry_t->Popup(@popup_style);
}

use vars qw(@search_anything_history);

### AutoLoad Sub
sub search_anything {
    my($s) = @_;

    my $token = "search-anything";
    my $t = redisplay_top($top, $token,
			  -title => M"Suchen",
			 );
    if (!defined $t) {
	my $t = $toplevel{$token};
	$t->Subwidget("Entry")->tabFocus;
	return;
    }

    require File::Basename;

    require PLZ;
    my @plz = PLZ->new;
    my @plz_labels = "PLZ-Datenbank (Berlin)";
    eval {
	my $plz = PLZ->new("$datadir/Potsdam.coords.data");
	die "Can't get Potsdam data" if (!$plz);
	push @plz, $plz;
	push @plz_labels, "PLZ-Datenbank (Potsdam)";
    };
    warn $@ if $@;

    # XXX do a dump, blocking, unix-only search in datadir
    my @search_files = (@str_file{qw/s l u b r w f v e/},
			@p_file  {qw/u b r o pl kn ki rest/},
			# additional scoped files XXX
			"brunnels",
			"wasserumland", "wasserumland2", "landstrassen2",
			"orte2",
		       );
    @search_files = map {
	file_name_is_absolute($_) && -r $_ ? $_ :
	    "$datadir/$_" ? "$datadir/$_" : ()
	} @search_files;
    my %file_to_abbrev;
    while(my($k,$v) = each %str_file) {
	$file_to_abbrev{$v} = ['s', $k];
    }
    while(my($k,$v) = each %p_file) {
	$file_to_abbrev{$v} = ['p', $k];
    }
    # additional scoped files
    $file_to_abbrev{"wasserumland"}   = ['s', 'w'];
    $file_to_abbrev{"wasserumland2"}  = ['s', 'w'];
    $file_to_abbrev{"landstrassen2"}  = ['s', 'l'];
    $file_to_abbrev{"orte2"}	      = ['p', 'o'];

    my $lb;
    my $e;
    my @inx2match;

    my $sort = "alpha"; # XXX make global or configurable

    my $do_search = sub {
	return if $s eq '';
### fork in eval is evil ??? (check it, it seems to work for 5.8.0 + FreeBSD)
	IncBusy($t);
	eval {
	    my %found_in;
	    my %title;
	    foreach my $search_file (@search_files) {
		my @matches;
		my $pid;
		if (0 && is_in_path("grep")) { # XXX do not fork
		    $pid = open(GREP, "-|");
		    if (!$pid) {
			exec("grep", "-i", $s, $search_file) || warn "Can't exec program grep with $search_file: $!";
			CORE::exit();
		    }
		} else {
		    # non-Unix compatibility
		    open(GREP, $search_file) || do {
			warn "Can't open $search_file: $!";
			next;
		    }
		}
		while(<GREP>) {
		    chomp;
		    if (!defined $pid) {
			next unless /$s/i;
		    }
		    push @matches, Strassen::parse($_);
		    $matches[-1]->[3] = [];
		}
		close GREP;
		if (@matches) {
		    my $file = File::Basename::basename($search_file);
		    $found_in{$file} = \@matches;
		    my $glob_dir = Strassen->get_global_directives($search_file);
		    eval {
			my $lang = $Msg::lang || "de"; # XXX get from $var or func
			$title{$file} = ($glob_dir->{"title.$Msg::lang"} || $glob_dir->{"title.de"})->[0];
			$title{$file} .= " ($file)";
		    };
		    if ($@ || !$title{$file}) {
			require Safe;
			my $s = Safe->new('BBBike::Search');
			undef $BBBike::Search::title;
			$s->rdo($search_file.".desc");
			if (defined $BBBike::Search::title) {
			    if (ref $BBBike::Search::title eq 'HASH') {
				my $lang = $Msg::lang || "de";
				$title{$file} = $BBBike::Search::title->{$lang} ||
				    $BBBike::Search::title->{"de"};
			    } else {
				$title{$file} = $BBBike::Search::title;
			    }
			    $title{$file} .= " ($file)";
			} else {
			    $title{$file} = $file;
			}
		    }
		}
	    }

	    # special case: PLZ files
	    for my $i (0 .. $#plz) {
		my @plz_matches = $plz[$i]->look($s);
		if (@plz_matches) {
		    # in Strassen-Format umwandeln
		    my @matches;
		    foreach (@plz_matches) {
			push @matches, [$_->[&PLZ::LOOK_NAME] . " (".$_->[&PLZ::LOOK_CITYPART].")", [$_->[&PLZ::LOOK_COORD]], "X", []];
		    }
		    $found_in{$plz_labels[$i]} = \@matches;
		}
	    }

	    $lb->delete(0, "end");
	    die M("Nichts gefunden")."\n" if !keys %found_in;

	    $lb->focus;
	    if ($e->can('historyAdd') && $e->can('history')) {
		$e->historyAdd;
		@search_anything_history = $e->history;
	    }

	    @inx2match = ();

	    my %sort_order = ('strassen' => 100,
			      'PLZ-Datenbank (Berlin)' => 90,
			      'PLZ-Datenbank (Potsdam)' => 89,
			      'orte' => 80,
			      'orte2' => 79,
			      'landstrassen' => 70,
			      'landstrassen2' => 69,
			      'brunnels' => 60,
			     );

	    foreach my $file (sort {
		my $base_a = File::Basename::basename($a);
		my $base_b = File::Basename::basename($b);
		my $order_a = $sort_order{$base_a} || 0;
		my $order_b = $sort_order{$base_b} || 0;
		if ($order_a == $order_b) {
		    $base_a cmp $base_b;
		} else {
		    $order_b <=> $order_a;
		}
	    } keys %found_in) {
		my $matches = $found_in{$file};
		$lb->insert("end", ($title{$file} || $file).":");
		$lb->itemconfigure("end", -foreground => "#0000a0")
		    if $lb->Subwidget("scrolled")->can("itemconfigure");
		push @inx2match, undef;
		my @sorted_matches;
		my $indent = " "x2;
		if ($sort eq 'dist') {
		    my($center) = join(",",anti_transpose($c->get_center));
		    @sorted_matches = map {
			$_->[1];
		    } sort {
			$a->[0] <=> $b->[0];
		    } map {
			my $match = $_;
			my $nearest = min(map {
			    Strassen::Util::strecke_s($center, $_);
			} @{$match->[Strassen::COORDS()]});
			[$nearest, $match];
		    } @$matches;
		} elsif ($sort eq 'cat') {
		    my $cat_stack_mapping = Strassen->default_cat_stack_mapping();
		    @sorted_matches = sort {
			my $cmp = $cat_stack_mapping->{$b->[Strassen::CAT()]} <=> $cat_stack_mapping->{$a->[Strassen::CAT()]};
			if ($cmp == 0) {
			    $a->[Strassen::NAME()] cmp $b->[Strassen::NAME()];
			} else {
			    $cmp;
			}
		    } @$matches;
		    $indent = " "x4;
		} else { # $sort eq 'alpha'
		    @sorted_matches = sort { $a->[0] cmp $b->[0] } @$matches;
		}

		my $last_name;
		my $last_cat;
		foreach my $match (@sorted_matches) {
		    if (defined $last_name && $last_name eq $match->[0]) {
			push @{ $inx2match[-1]->[3] }, $match->[1];
		    } else {
			my $this_cat = $match->[Strassen::CAT()];
			if ($sort eq 'cat' &&
			    $file !~ /^PLZ-Datenbank/ &&
			    (!defined $last_cat || $last_cat ne $this_cat)) {
			    my $cat_name = $category_attrib{$this_cat}->[ATTRIB_PLURAL];
			    if (!defined $cat_name) {
				$cat_name = $this_cat;
			    }
			    $lb->insert("end", "  " . $cat_name);
			    $lb->itemconfigure("end", -foreground => "#000060")
				if $lb->Subwidget("scrolled")->can("itemconfigure");
			    $last_cat = $this_cat;
			    push @inx2match, "";
			}
			$lb->insert("end", $indent . $match->[0]);
			push @inx2match, $match;
			$last_name = $match->[0];
		    }
		}
	    }
	    $lb->activate(1); # first entry is a headline, so use 2nd one
	    $lb->selectionSet(1);
	};
	my $err = $@;
	DecBusy($t);
	if ($err) {
	    status_message($err, 'err');
	}
    };

    $t->transient($top) if $transient;
    my $f1 = $t->Frame->pack(-fill => 'x');
    $f1->Label(-text => "Suchen:", -padx => 0, -pady => 0,
	      )->pack(-side => "left");
    my $Entry = 'Entry';
    my @Entry_args;
    eval {
	require Tk::HistEntry;
	Tk::HistEntry->VERSION(0.37);
	@Entry_args = (-match => 1, -dup => 0);
	$Entry = 'SimpleHistEntry';
    };
    $e = $f1->$Entry(-textvariable => \$s, @Entry_args)->pack(-side => "left", -fill => "x");
    if ($e->can('history')) {
	$e->history(\@search_anything_history);
    }
    $t->Advertise(Entry => $e);
    $e->focus;
    $e->bind("<Return>" => $do_search);

    {
	package Tk::ListboxSearchAnything;
	use base qw(Tk::Listbox);
	Construct Tk::Widget 'ListboxSearchAnything';
	sub UpDown {
	    my($w, $amount) = @_;
	    my $new_amount = $amount;
	    my $new_inx = $w->index('active')+$amount;
	    my $inc = ($amount > 0 ? 1 : -1);
	    if (${ $w->{SortTypeRef} } eq 'cat') {
		while($w->get($new_inx) =~ /^(\S|  \S)/) { # headline or category line
		    $new_inx+=$inc;
		    $new_amount+=$inc;
		    last if ($w->index("end") <= $new_inx);
		}
	    } else {
		if ($w->get($new_inx) =~ /^\S/) { # is a headline?
		    $new_amount+=$inc;
		}
	    }
	    $w->SUPER::UpDown($new_amount);
	}
    }

    $lb = $t->Scrolled("ListboxSearchAnything", -scrollbars => "osoe",
		       -width => 32,
		       -height => 12,
		      )->pack(-fill => "both", -expand => 1);
    $lb->Subwidget("scrolled")->{SortTypeRef} = \$sort;
    {
	my $f = $t->LabFrame(-label => M("Sortieren"),
			     -labelside => "acrosstop",
			    )->pack(-fill => "x");
	for my $cb_def (["Alphabetisch",    "alpha"],
			["nach Entfernung", "dist"],
			["nach Kategorie",  "cat"],
		       ) {
	    my($text, $sort_value) = @$cb_def;
	    $f->Radiobutton(-text => M($text),
			    -variable => \$sort,
			    -value => $sort_value,
			    -command => $do_search,
			   )->pack(-anchor => "w");
	}
    }
    my $cb;
    {
	my $f = $t->Frame->pack(-fill => "x");
	$cb = $f->Button(Name => 'close',
			 -command => sub {
			     $t->withdraw;
			     #$t->destroy;
			 })->pack(-side => "right");
	$f->Button(Name => 'search',
		   -command => $do_search,
		  )->pack(-side => "right");
    }
    $t->protocol(WM_DELETE_WINDOW => sub { $cb->invoke });

    my $select = sub {
	my($inx) = ($lb->curselection)[0];
	return unless defined $inx;
	my $match = $inx2match[$inx];

	if (!defined $match) {
	    my $f = $lb->get($inx);
	    return if !$f;
	    my $abbrev = $file_to_abbrev{$f};
	    return if !$abbrev;
	    choose_ort(@$abbrev);
	    return;
	}

	my $transpose;
	if ($coord_system ne "standard") {
	    $transpose = sub {
		my($x,$y) = @_;
		transpose($coord_system_obj->standard2map($x, $y));
	    };
	} else {
	    $transpose = \&transpose;
	}

	if (@{$match->[1]} == 1) {
	    return if !defined $match->[1][0];
	    my($xy) = $match->[1][0];
	    mark_point(-coords => [[[ $transpose->(split /,/, $xy) ]]],
		       -clever_center => 1);
	} elsif (@{$match->[1]} > 1) {
	    my @line_coords_array;
	    foreach my $polyline ($match->[1], @{ $match->[3] }) {
		my @line_coords;
		foreach (@$polyline) {
		    push @line_coords, [ $transpose->(split /,/, $_) ];
		}
		push @line_coords_array, \@line_coords;
	    }
	    mark_street(-coords => [@line_coords_array],
			-clever_center => 1);
	}
    };
    $lb->bind("<Double-1>" => $select);
    $lb->bind("<Return>" => $select);

    $t->bind('<<CloseWin>>' => sub { $cb->invoke });
    $t->Popup(@popup_style);

    if (defined $s) {
	$do_search->();
    }
}

use vars qw($gps_animation_om);

### AutoLoad Sub
sub gps_animation_update_optionmenu {
    if (defined $gps_animation_om && Tk::Exists($gps_animation_om)) {
	my $om = $gps_animation_om;
	$om->configure(-options => []); # empty old
	for my $i (0 .. MAX_LAYERS) {
	    my $abk = "L$i";
	    if ($str_draw{$abk} && $str_file{$abk} =~ /gpsspeed/) {
		$om->addOptions([$str_file{$abk} => $i]);
	    }
	}
    }
}

### AutoLoad Sub
sub gps_animation {
    my $top = shift;
    my $t = redisplay_top($top, "gps-track-animation",
			  -title => M"GPS-Track-Animation");
    return if !defined $t;
    $t->transient($top) if $transient;
    my $trackfile;
    my $track_abk;
    my $track_i = 0;
    my $anim_timer;
    my($start_b, $skip_b);
    my $om = $t->Optionmenu(-textvariable => \$trackfile,
			    -variable => \$track_abk,
			    -command => sub {
				$t->afterCancel($anim_timer)
				    if defined $anim_timer;
				undef $anim_timer;
				$track_i = 0;
				$start_b->configure(-text => M"Start")
				    if $start_b;
			    })->pack;
    $gps_animation_om = $om;
    gps_animation_update_optionmenu();

    # Hooks
    my $tpath = $t->PathName;
    for my $hook (qw(after_new_layer after_delete_layer)) {
	Hooks::get_hooks($hook)->add(\&gps_animation_update_optionmenu, $tpath);
    }
    $t->OnDestroy
	(sub {
	     for my $hook (qw(after_new_layer after_delete_layer)) {
		 Hooks::get_hooks($hook)->del($tpath);
	     }
	 });

    my $speed;
    my $Scale = "Scale";
    my %scaleargs = (-bigincrement => 20,
		     -resolution => 10,
		     -showvalue => 1,
		     -variable => \$speed,
		    );
    # XXX ist LogScale hier eine gute Idee?
    eval {
	die "Ich kriege LogScale und -variable hier nicht zum Laufen XXX";
	require Tk::LogScale;
	require Tie::Watch;
	$Scale = "LogScale";
	my $_speed;
	%scaleargs = (-resolution => 0.01,
		      -variable => \$_speed,
		      -command => sub { warn $_speed; $speed = int $_speed },
		      -showvalue => 0);
    };
    $t->$Scale(-from => 1,
	       -to => 500, -orient => "horiz",
	       %scaleargs)->pack(-fill => "x");
    $c->createRectangle(0,0,0,0,-width=>2,-outline => "#c08000", -tags => "gpsanimrect");

    my $dir = +1;
    my($curr_speed, $curr_time, $curr_dist);

    my $next_track_point;
    $next_track_point = sub {
	my($tag1,$tag0) = ("L${track_abk}-" . ($track_i+$dir),
			   "L${track_abk}-" . ($track_i));
	my($name1, $name0) =
	    (($c->gettags($tag1))[1], ($c->gettags($tag0))[1]);
	my($time1min,$time1sec) = $name1 =~ /time=(\d+):(\d+)min/;
	my($time0min,$time0sec) = $name0 =~ /time=(\d+):(\d+)min/;
	if (!defined $time1min || !defined $time0min) {
	    # XXX set buttons
	    warn "Stopped track...";
	    return;
	}
	my $time1 = $time1min*60+$time1sec;
	my $time0 = $time0min*60+$time0sec;

	$curr_time  = "$time1min:$time1sec";
	($curr_speed) = $name1 =~ m|(\d+)\s*km/h|;
	($curr_dist)  = $name1 =~ m|dist=([\d\.]+)|;

	$anim_timer =
	    $t->after(1000*abs($time1-$time0)/$speed, sub {
		      my $item = $c->find(withtag => $tag1);
		      my($x,$y) = $c->coords($item);
		      my $pad = 5;
		      $c->coords("gpsanimrect", $x-$pad,$y-$pad,$x+$pad,$y+$pad);
		      $c->center_view($x,$y);
		      $track_i+=$dir;
		      if ($track_i < 0) {
			  # XXX set start button
			  warn "Stopped track...";
			  return;
		      }
		      $next_track_point->();
		  });
    };

    {
	my $f = $t->Frame->pack(-anchor => "w");
	$f->Label(-text => M"Geschwindigkeit: ")->pack(-side => "left");
	$f->Label(-textvariable => \$curr_speed)->pack(-side => "left");
	$f->Label(-text => M"km/h")->pack(-side => "left");
    }

    {
	my $f = $t->Frame->pack(-anchor => "w");
	$f->Label(-text => M"Distanz: ")->pack(-side => "left");
	$f->Label(-textvariable => \$curr_dist)->pack(-side => "left");
	$f->Label(-text => M"km")->pack(-side => "left");
    }

    {
	my $f = $t->Frame->pack(-anchor => "w");
	$f->Label(-text => M"Zeit: ")->pack(-side => "left");
	$f->Label(-textvariable => \$curr_time)->pack(-side => "left");
    }

    {
	my $f = $t->Frame->pack;
	$start_b = $f->Button(-text => M"Start",
		   -command => sub {
		       if ($start_b->cget(-text) eq M"Start") {
			   $skip_b->configure(-state => "normal");
			   $start_b->configure(-text => M"Pause");
			   $track_i = 0;
			   $next_track_point->();
		       } elsif ($start_b->cget(-text) eq M"Fortsetzen") {
			   $start_b->configure(-text => M"Pause");
			   $next_track_point->();
		       } else {
			   $start_b->configure(-text => M"Fortsetzen");
			   $t->afterCancel($anim_timer)
			       if defined $anim_timer;
		       }
		   })->pack(-side => "left");
	$f->Button(-text => "<=>",
		   -command => sub {
		       $dir = $dir == 1 ? -1 : +1;
		   })->pack(-side => "left");
	$skip_b = $f->Button(-text => M"Überspringen",
		   -state => 'disabled',
		   -command => sub {
		       $t->afterCancel($anim_timer)
			   if defined $anim_timer;
		       $track_i++;
		       $next_track_point->();
		   })->pack(-side => "left");
	$f->Button(-text => M"Schließen",
		   -command => sub {
		       $t->destroy;
		   })->pack(-side => "left");
    }
    $t->OnDestroy(sub {
		      $t->afterCancel($anim_timer) if defined $anim_timer;
		      $c->delete("gpsanimrect");
		  });
    $t->Popup(@popup_style);
}

use vars qw(%xbase);

sub get_dbf_info {
    my($dbf_file, $index) = @_;
    if (!$xbase{$dbf_file}) {
	require XBase;
	$xbase{$dbf_file} = XBase->new($dbf_file) or do {
	    warn XBase->errstr;
	    return undef;
	};
    }
    join(":", $xbase{$dbf_file}->get_record($index-1));
}

sub build_text_cursor {
    my $text = shift;
    if (length($text) > 8) {
	warn "`$text' may be too long for cursor";
    }
    (my $file_frag = $text) =~ s/[^A-Za-z0-9_-]/_/g;
    my $cursor_file = "$tmpdir/cursor_" . $file_frag . ".xbm";
    my $cursor_spec = ['@' . $cursor_file, $cursor_file, "black", "white"];
    if (-r $cursor_file) {
	return $cursor_spec;
    }

    my $ptr = Tk::findINC("images/ptr.xbm");
    if (!$ptr) {
	warn "Cannot find ptr.xbm in @INC";
	return undef;
    }

    if (!is_in_path("pbmtext") ||
	!is_in_path("pnmcat") ||
	!is_in_path("xbmtopbm") ||
	!is_in_path("pbmtoxbm") ||
	!is_in_path("pnmcrop")
       ) {
	warn "Netpbm seems to be missing";
	return undef;
    }

    my $tmp1file = "/tmp/cursortext.$$.pbm";
    my $tmp2file = "/tmp/cursorptr.$$.pbm";
    system("pbmtext \"$text\" | pnmcrop > $tmp1file");
    system("xbmtopbm $ptr > $tmp2file");
    system("pnmcat -white -lr -jbottom $tmp2file $tmp1file | pbmtoxbm | $^X -nle 's/(#define.*height.*)/\$1\\n#define noname_x_hot 1\\n#define noname_y_hot 1\\n/; print' > $cursor_file");

    unlink $tmp1file;
    unlink $tmp2file;

    if (-s $cursor_file) {
	return $cursor_spec;
    } else {
	warn "Errors while building $cursor_file";
	return undef;
    }
}

sub path_to_selection {
    @inslauf_selection = map {
	join ",", $coord_system_obj->trim_accuracy(@$_)
    } @realcoords;
    $c->SelectionOwn;
    standard_selection_handle();
}

sub active_temp_blockings_for_date_dialog {
    $show_active_temp_blockings = 1;
    require Tk::DateEntry;
    Tk::DateEntry->VERSION("1.38");
    require POSIX;
    require Time::Local;
    require Data::Dumper;
    eval {
	require "$FindBin::RealBin/miscsrc/check_bbbike_temp_blockings";
    }; warn $@ if $@;

    my @future;
    if (BBBike::check_bbbike_temp_blockings->can("process")) {
	BBBike::check_bbbike_temp_blockings::process(-f => $BBBike::check_bbbike_temp_blockings::temp_blockings_pl);
	BBBike::check_bbbike_temp_blockings::load_file();
	@future = BBBike::check_bbbike_temp_blockings::return_future();
    }
    use Data::Dumper;warn Dumper \@future;

    my $t = $top->Toplevel(-title => "Datum");
    $t->transient($top) if $transient;
    my $date = POSIX::strftime("%Y/%m/%d", localtime);
    {
	my $f = $t->Frame->pack(-fill => "x");
	Tk::grid($f->Label(-text => "Sperrungen für Datum: "),
		 $f->DateEntry
		 (-dateformat => 2,
		  -textvariable => \$date,
		  -configcmd => sub {
		      my(%args) = @_;
		      if (@future && $args{-date}) {
			  my($d,$m,$y) = @{ $args{-date} };
			  my $t1 = Time::Local::timelocal(0,0,0,$d,$m-1,$y-1900);
			  my $t2 = Time::Local::timelocal(59,59,23,$d,$m-1,$y-1900);
			  for my $rec (@future) {
			      next if (defined $rec->{from} && $t1 < $rec->{from});
			      next if (defined $rec->{until} && $t2 > $rec->{until});
			      $args{-datewidget}->configure(-bg => "red");
			  }
		      }
		  },
		 )
		);
    }

    {
	my $f = $t->Frame->pack;
	Tk::grid($f->Button
		 (Name => 'ok',
		  -command => sub {
		      $t->destroy;
		      my($y,$m,$d) = split m{/}, $date;
		      my $now = Time::Local::timelocal(0,0,0,$d,$m-1,$y-1900);
		      activate_temp_blockings($show_active_temp_blockings, -now => $now);
		  }),
		 $f->Button(Name => 'cancel',
			    -command => sub {
				$t->destroy;
			    }));
    }

    if (@future) {
	my $txt = $t->Scrolled("ROText", -scrollbars => "osoe",
			       -font => "Courier 9",
			       -width => 40, -height => 5)->pack(-fill => "both", -expand => 1);
	for my $rec (@future) {
	    $rec->{fromdate} = scalar localtime $rec->{from}
		if $rec->{from};
	    $rec->{untildate} = scalar localtime $rec->{until}
		if $rec->{until};
	}
	my $dump;
	if (eval { require YAML; 1 }) {
	    $dump = YAML::Dump(\@future);
	} else {
	    $dump = Data::Dumper->new([@future], [])->Indent(1)->Dump;
	}
	$txt->insert("end", $dump);
    }
}

sub adjust_map_by_delta {
    if (@coords != 2) {
	status_message("Genau zwei Koordinaten erwartet!", "error");
	return;
    }
    my $dx = $coords[1]->[0] - $coords[0]->[0];
    my $dy = $coords[1]->[1] - $coords[0]->[1];
 MAPITEMS:
    for my $i ($c->find("withtag" => "map")) {
	my @t = $c->gettags($i);
	for (@t) {
	    next MAPITEMS if ($_ eq 'map_adjusted');
	}
	$c->move($i, $dx, $dy);
	$c->addtag("map_adjusted", withtag => $i);
    }
}

sub reset_map_adjusted_tag {
    $c->dtag("map_adjusted");
}

1;

__END__
