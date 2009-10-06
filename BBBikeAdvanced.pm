# -*- perl -*-

#
# $Id: BBBikeAdvanced.pm,v 1.209 2009/02/14 13:41:08 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1999-2008 Slaven Rezic. All rights reserved.
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

use your qw($BBBike::Menubar::option_menu
	    $BBBike::check_bbbike_temp_blockings::temp_blockings_pl
	    $BBBikeEdit::prefer_tracks
	    $BBBikeEdit::bbd_penalty_multiply $BBBikeEdit::bbd_penalty_invert
	    $BBBikeEdit::gps_penalty_multiply
	    $Devel::Trace::TRACE
	    $DB_File::DB_BTREE
	    $Karte::Standard::obj $Karte::Polar::obj
	  );

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
	# "local" probably does not work here, we're in a MainLoop...
	$Data::Dumper::Deparse = 1; # if I need a "ptksh" window, then I need more diagnostics!
	$Data::Dumper::Sortkeys = 1;

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
    $opbm->command(-label => 'Destroy all toplevels',
		   -command => \&destroy_all_toplevels);
    $opbm->command(-label => 'Re-call some subs',
		   -command => \&recall_some_subs,
		  );
    $opbm->command(-label => 'Reload photos',
		   -command => sub { %photo = (); $top->{MapImages} = {}; load_photos() },
		  );
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

my $custom_draw_directory;
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
    my $center_beginning = 0;

    $custom_draw_directory = $datadir if !defined $custom_draw_directory;

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
					 (!defined $file ? (-initialdir => $custom_draw_directory) : ()),
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
	    Tk::grid($f->Checkbutton(-text => M"Namen zeichnen",
				     -variable => \$args{-namedraw}),
		     -sticky => "w",
		    );
	    if ($linetype eq "p") {
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
	    Tk::grid($f->Label(-text => M"Kartenkoordinaten"),
		     my $om = $f->Optionmenu
		     (-variable => \$coord_input,
#XXX this causes -width to be ignored?		      -anchor => "w",
		      -width => 10,
		      -options => [ (map { [ $Karte::map{$_}->name, $_ ] } @Karte::map) ]),
		     -sticky => "w",
		    );
	    $coord_input = "Standard";

	    Tk::grid($f->Label(-text => M"Auf Anfang zentrieren"),
		     $f->Checkbutton(-variable => \$center_beginning),
		     -sticky => "w");

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

	$custom_draw_directory = File::Basename::dirname($file);

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
    if ($linetype eq 'p') {
	delete $p_obj{$abk};
    } else {
	delete $str_obj{$abk};
    }
    plot($linetype, $abk, %args);

    # XXX The bindings should also be recycled if the layer is deleted!
    for (($linetype eq 'p' ? ("$abk-img", "$abk-fg") : ($abk))) {
	$c->bind($_, "<ButtonRelease-1>" => \&set_route_point);
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

    my $coord;
    if (defined $BBBike::ExtFile::center_on_coord) {
	$coord = $BBBike::ExtFile::center_on_coord;
    } elsif ($center_beginning) {
	my $obj = $linetype eq 'p' ? \%p_obj : \%str_obj;
	if ($obj->{$abk}) {
	    my $r = $obj->{$abk}->get(0);
	    if ($r) {
		$coord = $r->[Strassen::COORDS()]->[0];
		my $conv = $obj->{$abk}->get_conversion; # XXX %conv_args???
		if ($conv) {
		    $coord = $conv->($coord);
		}
	    }
	}
    }
    if (defined $coord) {
	choose_from_plz(-coord => $coord);
    }

    $toplevel{"chooseort-$abk-$linetype"}->destroy
	if $toplevel{"chooseort-$abk-$linetype"} && $do_close;

    $file; # return filename
}

sub read_desc_file {
    warn "Using .desc files is obsolete, please consider to switch to global in-file directives. See doc/bbd.pod for some information";
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
    "$abk || $abk-fg || $abk-img";
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
    if ($linetype !~ /^(str|p|sperre)$/) {
#XXXdel	$str_draw{$abk} = 1;
#    } elsif ($linetype eq 'p') {
#XXXdel	$p_draw{$abk} = 1;
#    } else {
	die "Unknown linetype $linetype, should be str, sperre or p";
    }
    warn "Use new Layer $abk\n";
    add_to_stack($abk, "before", "pp");

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
	my @pack_opts = qw(-fill x -expand 1 -anchor w);
	my @b_opts = qw(-justify left -anchor w);
	## not sure if this is really necessary, we have at least the titlebar
	#$f->Label(-text => $title, -font => $font{large}, @b_opts)->pack(@pack_opts);
	for my $i (1..MAX_LAYERS) {
	    my $abk = "L$i";
	    if ($str_draw{$abk}) {
		$f->Button(-text => "Straßen $abk ($str_file{$abk})",
			   @b_opts,
			   -command => sub {
			       $s_cb->($abk);
			   })->pack(@pack_opts);
	    }
	    if ($p_draw{$abk}) {
		$f->Button(-text => "Punkte $abk ($p_file{$abk})",
			   @b_opts,
			   -command => sub {
			       $p_cb->($abk);
			   })->pack(@pack_opts);
	    }
	    if ($p_draw{"$abk-sperre"}) {
		$f->Button(-text => "Sperrungen $abk (" . $p_file{"$abk-sperre"} . ")",
			   @b_opts,
			   -command => sub {
			       $p_cb->($abk . "-sperre");
			   })->pack(@pack_opts);
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

# XXX missing "sperre" layer types
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
	    if ($str_draw{$abk} || $p_draw{$abk} || $p_draw{"$abk-sperre"}) {
		my(@files);
		push @files, $str_file{$abk} if $str_file{$abk};
		push @files, $p_file{$abk}   if $p_file{$abk};
		push @files, $p_file{"$abk-sperre"} if $p_file{"$abk-sperre"};
		my $files = "";
		if (@files) {
		    $files = "(" .join(",", @files) . ")";
		}
		$f->Button
		    (-text => "Layer $abk $files",
		     -command => sub {
			 delete_layer_without_hooks($abk);
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

sub delete_layer_without_hooks {
    my($abk) = @_;
    if ($str_draw{$abk}) {
	$str_draw{$abk} = 0;
	plot('str',$abk);
	plot('str',$abk,Canvas => $overview_canvas,-draw => 0) if $overview_canvas;
	delete $str_file{$abk};
	delete $str_obj{$abk};
    }
    if ($p_draw{$abk}) {
	$p_draw{$abk} = 0;
	plot('p',$abk);
	# XXX overview canvas?
	delete $p_file{$abk};
	delete $p_obj{$abk};
    }
    if ($p_draw{"$abk-sperre"}) {
	$p_draw{"$abk-sperre"} = 0;
	plot('p',"$abk-sperre");
	# XXX overview canvas?
	delete $p_file{"$abk-sperre"};
	# XXX This should also undo the net changes
    }
}

sub delete_layer {
    my($abk) = @_;
    delete_layer_without_hooks($abk);
    Hooks::get_hooks("after_delete_layer")->execute;
}

sub tk_draw_layer_in_overview {
    additional_layer_dialog
	(-title => M"Layer in Übersichtskarte zeichnen",
	 -cb => sub {
	     my $abk = shift;
	     draw_layer_in_overview($abk);
	 },
	 -token => 'choose_from_additional_layer',
	);
}

sub draw_layer_in_overview {
    my $abk = shift;
    if (!$overview_canvas) {
	# XXX maybe remember for later instead
	status_message(M"Die Übersichtskarte ist noch nicht verfügbar.", "info");
	return;
    }
    # XXX support for point layers missing
    plotstr($abk,
	    Canvas => $overview_canvas,
	   );
    # XXX it's not possible to remove layers!
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

    my $fill_coordsystem_list;
    my $use_full_coordsystem_list = 0;

    my $coord_menu;
    my $coord_output = $coord_output;
    {
	require Tk::Optionmenu;
	my $f = $t->Frame->pack(-anchor => "w", -fill => "x");
	$f->Label(-text => M("Koordinatensystem").":")->pack(-side => "left");
	$coord_menu = $f->Optionmenu(-variable => \$coord_output,
				    )->pack(-side => "left", -fill => "x");
	$fill_coordsystem_list = sub {
	    my @coordsystem_list = ((map { [ $Karte::map{$_}->name, $_ ] } @Karte::map), "canvas");
	    if (!$use_full_coordsystem_list) {
		@coordsystem_list = grep {
		    ref $_ eq 'ARRAY' &&
			$_->[1] =~ /^(polar|standard|gps|gdf)$/;
		} @coordsystem_list;
	    }
	    $coord_menu->configure(-options => [ @coordsystem_list ]);
	};
	$fill_coordsystem_list->();
    }
    {
	my $f = $t->Frame->pack(-anchor => "w", -fill => "x");
	$f->Checkbutton(-text => "erweiterte Liste",
			-variable => \$use_full_coordsystem_list,
			-command => $fill_coordsystem_list,
		       )->pack(-side => "right");
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
	# www.berliner-stadtplan.com, www.berlinonline.de

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
		 my $ret = parse_url_for_coords($url);
		 my($x_s, $y_s, $x_ddd, $y_ddd) = @{$ret}{qw(x_s y_s x_ddd y_ddd)};
		 if (defined $x_s) {
		     my($tx,$ty) = transpose($x_s, $y_s);
		     mark_point('-x' => $tx, '-y' => $ty, -clever_center => 1);
		 }
		 if (defined $x_ddd) {
		     $coord_output = "polar";
		     $coord_menu->setOption('polar'); # XXX $Karte::map{'polar'}->name); #XXX should be better in Tk
		     $valx = $x_ddd;
		     $valy = $y_ddd;
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

sub parse_url_for_coords {
    my($url, %args) = @_;
    my $q = $args{quiet};
    my($x_ddd, $y_ddd); # polar/DDD
    my($x_s, $y_s); # BBBike coordinates
    if (0 && $url =~ m{gps=(\d+)%7C(\d+)}) {
	# XXX passt nicht ...
	my($x, $y) = ($1, $2);
	require Karte::Polar;
	$x_ddd = 13 + $x/10000;
	$y_ddd = 52 + $y/10000;
	warn "$x $y $x_ddd $y_ddd";
    } elsif ($url =~ m{x_wgs/(.*?)/y_wgs/(.*?)/}    || # berliner-stadtplan old
	     $url =~ m{x_wgs=(.*?)[&;]y_wgs=([\.\d]+)}
	    ) {
	my($x, $y) = ($1, $2);
	require Karte::Polar;
	$x_ddd = Karte::Polar::dmm2ddd(13, $x);
	$y_ddd = Karte::Polar::dmm2ddd(52, $y);
    } elsif ($url =~ m{x_wgsv=([\d\.]+)&y_wgsv=([\d\.]+)}) { # berliner-stadtpan new (2007-07-24)
	($x_ddd, $y_ddd) = ($1, $2);
    } elsif ($url =~ m{/gps_x/(\d+),(\d+)/gps_y/(\d+),(\d+)}) { # berliner-stadtplan24 (ca. 2007-08-10)
	($x_ddd, $y_ddd) = ($1.".".$2, $3.".".$4);
    } elsif ($url =~ /ADR_ZIP=(\d+)&ADR_STREET=(.+?)&ADR_HOUSE=(.*)/) {
	my($zip, $street, $hnr) = ($1, $2, $3);
	local @INC = @INC;
	push @INC, "$FindBin::RealBin/miscsrc";
	require TelbuchDBApprox;
	my $tb = TelbuchDBApprox->new(-approxhnr => 1);
	my(@res) = $tb->search("$street $hnr", $zip);
	if (!@res) {
	    return if $q;
	    status_message(M("Kein Ergebnis gefunden"), "die");
	}
	($x_s,$y_s) = split /,/, $res[0]->{Coord};
    } elsif ($url =~ /params=(\d+)_(\d+)_(?:([\d\.]+)_)?([NS])_(\d+)_(\d+)_(?:([\d\.]+)_)?([EW])/) { # wikipedia mapsources, deg min (sec)
	$y_ddd = $1 + $2/60 + $3/3600;
	$y_ddd *= -1 if $4 eq 'S';
	$x_ddd = $5 + $6/60 + $7/3600;
	$x_ddd *= -1 if $8 eq 'W';
    } elsif ($url =~ /params=(\d+)\.(\d+)_([NS])_(\d+)\.(\d+)_([EW])/) { # wikipedia mapsources, decimal degrees
	$y_ddd = sprintf "%s.%s", $1, $2;
	$y_ddd *= -1 if $3 eq 'S';
	$x_ddd = sprintf "%s.%s", $4, $5;
	$x_ddd *= -1 if $6 eq 'W';
    } elsif ($url =~ m{[\?&]ll=([0-9.]+),([0-9.]+)}) { # google maps
	$x_ddd = $2;
	$y_ddd = $1;
    } elsif ($url =~ m{ll=([0-9.]+),([0-9.]+)}) {
	$x_ddd = $2;
	$y_ddd = $1;
    } elsif ($url =~ /LL=%2B([0-9.]+)%2B([0-9.]+)/) {
	$x_ddd = $2;
	$y_ddd = $1;
    } elsif ($url =~ /lat=([0-9.]+).*long?=([0-9.]+)/) { # e.g. goyellow.de
	$x_ddd = $2;
	$y_ddd = $1;
    } elsif ($url =~ /long?=([0-9.]+).*lat=([0-9.]+)/) { # e.g. goyellow.de new
	$x_ddd = $1;
	$y_ddd = $2;
    } elsif ($url =~ /cp=([0-9.]+)~([0-9.]+)&/) { # e.g. maps.live.com
	$x_ddd = $2;
	$y_ddd = $1;
    } elsif ($url =~ /lt=([0-9.]+)&ln=([0-9.]+)/) { # e.g. www.panoramio.com
	$x_ddd = $2;
	$y_ddd = $1;
    }

    if (defined $x_ddd && defined $y_ddd) {
	($x_s,$y_s) = $Karte::Polar::obj->map2standard($x_ddd, $y_ddd);
    } elsif (defined $x_s && defined $y_s) {
	($x_ddd,$y_ddd) = $Karte::Polar::obj->standard2map($x_s, $y_s);
    }

    return if (!defined $x_s);

    return { x_ddd => $x_ddd,
	     y_ddd => $y_ddd,
	     x_s   => $x_s,
	     y_s   => $y_s,
	   };
}

sub set_line_coord_interactive {
    my(%args) = @_;
    if (!defined $coord_output ||
	!$Karte::map{$coord_output}) {
	die M"Karte-Objekt nicht definiert... Aus/Eingabe richtig setzen!\n";
	return;
    }

    my $t = redisplay_top($top, 'set_line_coord_interactive',
			  -title => M"Linienkoordinaten setzen",
			  -geometry => $args{-geometry},
			 );
    return if !defined $t;

    my $map = "auto-detect";

    my $set_sub = sub {
	my(@mark_args) = @_;
	my @coords = ();
	my @selection_types = ('PRIMARY', 'CLIPBOARD');
	if ($os eq 'win') {
	    @selection_types = ('CLIPBOARD');
	}
	for my $selection_type (@selection_types) {
	    my $s = eval { $t->SelectionGet('-selection' => $selection_type) };
	    next if $@;
	    if ($map eq 'postgis') {
		while ($s =~ /(?:MULTI)?(?:POINT|LINESTRING|POLYGON)\(([\d \.\)\(,]+)\)/g) {
		    (my $coords = $1) =~ s{\),\(}{,}g;
		    $coords =~ s{[\(\)]}{}g;
		    my @_coords = split /,/, $coords;
		    for (@_coords) {
			my($x, $y) = split / /, $_;
			push @coords, [$x,$y]; # XXX assume always standard coordinates here, maybe should also auto-detect?
		    }
		}
	    } else {
		while ($s =~ /([-+]?[0-9\.]+),([-+]?[0-9\.]+)/g) {
		    my($x,$y) = ($1,$2);
		    my $_map = $map;
		    if ($map eq 'auto-detect') {
			if ($x =~ m{\.} && $y =~ m{\.} && $x <= 180 && $x >= -180 && $y <= 90 && $y >= -90) {
			    $_map = "polar";
			} else {
			    $_map = "standard";
			}
		    }
		    if ($_map eq 'polar') {
			($x,$y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($x,$y));
		    }
		    push @coords, [$x,$y];
		}
		while ($s =~ m{(\d+)°(\d+)'(\d+(?:\.\d+)?)"([NS]).*?(\d+)°(\d+)'(\d+(?:\.\d+)?)"([EW])}g) {
		    # sigh, it seems that I have to use the ugly $1...$8 list :-(
		    my($lat_deg,$lat_min,$lat_sec,$lat_sgn,
		       $lon_deg,$lon_min,$lon_sec,$lon_sgn) = ($1,$2,$3,$4,$5,$6,$7,$8);
		    my $lat = $lat_deg + $lat_min/60 + $lat_sec/3600;
		    $lat *= -1 if $lat_sgn =~ m{s}i;
		    my $lon = $lon_deg + $lon_min/60 + $lon_sec/3600;
		    $lon *= -1 if $lon_sgn =~ m{w}i;
		    my($x,$y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon,$lat));
		    push @coords, [$x,$y];
		}
	    }
	    last if (@coords); # otherwise try the other selection type
	}
	if (!@coords) {
	    warn "No coordinates found in any of the selections";
	    return;
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
	(-text => M("Selection setzen") . " (F11)",
	 -command => sub {
	     $set_sub->(-clever_center => 1);
	 })->pack;
    $b->bind("<3>" => sub {
		 $set_sub->(-dont_center => 1);
	     });
    $top->bind("<F11>" => sub { $b->invoke });

    $t->Label(-text => "Koordinatensystem:")->pack(-anchor => "w");
    $t->Radiobutton(-variable => \$map,
		    -value => "auto-detect",
		    -text => "Auto-detect")->pack(-anchor => "w");
    $t->Radiobutton(-variable => \$map,
		    -value => "standard",
		    -text => "Standard (BBBike)")->pack(-anchor => "w");
    $t->Radiobutton(-variable => \$map,
		    -value => "polar",
		    -text => "WGS 84")->pack(-anchor => "w");
    $t->Radiobutton(-variable => \$map,
		    -value => "postgis",
		    -text => "PostGIS-styled")->pack(-anchor => "w");
}

sub coord_to_markers_dialog {
    my(%args) = @_;
    my $t = redisplay_top($top, 'coord_to_markers_dialog',
			  -title => M"Koordinaten aus Selection",
			  -geometry => $args{-geometry},
			 );
    return if !defined $t;

    my @marker_points;
    my $marker_points_no = 0;
    my $orig_steady_mark = $steady_mark;
    $steady_mark = 1;
    my $cur_index = 0;

    my $update_marker_points = sub {
	$marker_points_no = scalar @marker_points;
	if ($marker_points_no == 0) {
	    delete_markers();
	} else {
	    my @transposed_marker_points;
	    for (@marker_points) {
		my($tx,$ty) = transpose($_->[0][0], $_->[0][1]);
		push @transposed_marker_points, [[$tx,$ty]];
	    }
	    mark_street(-coords => \@transposed_marker_points,
			## I think I prefer centering to the last point
			#-clever_center => 1,
		       );
	}
    };

    my $center_to_point = sub {
	my($index) = @_;
	my($tx,$ty) = transpose($marker_points[$index]->[0][0],
				$marker_points[$index]->[0][1]);
	mark_point(-point => "$tx,$ty",
		   -dont_mark => 1);
    };

    my $repeater;
    my $last_sel;
    $repeater = $t->repeat
	(1000, sub {
	     if (!Tk::Exists($t)) {
		 $repeater->cancel;
		 return;
	     }
	     my $s;
	     Tk::catch {
		 $s = $t->SelectionGet('-selection' => ($os eq 'win'
							 ? "CLIPBOARD"
							 : "PRIMARY"));
	     };
	     if (defined $s) {
		 return if (defined $last_sel && $s eq $last_sel);
		 $last_sel = $s;
		 my $ret = parse_url_for_coords($s, quiet => 1);
		 if ($ret) {
		     push @marker_points, [[$ret->{x_s}, $ret->{y_s}]];
		     $update_marker_points->();
		 } else {
		     if ($verbose && $verbose >= 2) {
			 warn "Can't parse coords in url <$s>\n";
		     }
		 }
	     }
	 });

    Tk::grid($t->Label(-text => M("Punkte erkannt").":"),
	     $t->Label(-textvariable => \$marker_points_no),
	     -sticky => "ew");
    Tk::grid($t->Button(-text => M"Letzten Punkt löschen",
			-command => sub {
			    pop @marker_points if @marker_points;
			    $update_marker_points->();
			},
		       ),
	     -columnspan => 2,
	     -sticky => "ew");
    Tk::grid($t->Button(-text => M"Reset",
			-command => sub {
			    @marker_points = ();
			    $cur_index = 0;
			    $update_marker_points->();
			},
		       ),
	     -columnspan => 2,
	     -sticky => "ew");
    {
	my $f;
	Tk::grid($f = $t->Frame,
		 -columnspan => 2,
		 -sticky => "ew");
	$f->Button(-text => "<<",
		   -command => sub {
		       return if !@marker_points;
		       $cur_index--;
		       if ($cur_index < 0) {
			   $cur_index = $#marker_points;
		       }
		       $center_to_point->($cur_index);
		   },
		  )->pack(-side => "left", -fill => "x");
	$f->Button(-text => ">>",
		   -command => sub {
		       return if !@marker_points;
		       $cur_index++;
		       if ($cur_index > $#marker_points) {
			   $cur_index = 0;
		       }
		       $center_to_point->($cur_index);
		   },
		  )->pack(-side => "left", -fill => "x");
	$f->Label(-text => "Index:")->pack(-side => "left");
	$f->Label(-textvariable => \$cur_index)->pack(-side => "left");
    }
    Tk::grid($t->Button(-text => M"Dump to STDERR",
			-command => sub {
			    print STDERR join("\n", map { join(" ", map { join(",", map { int } @$_) } @$_) } @marker_points), "\n";
			},
		       ),
	     -columnspan => 2,
	     -sticky => "ew");
    Tk::grid($t->Button(Name => "close",
			-command => sub {
			    $t->destroy;
			},
		       ),
	     -columnspan => 2,
	     -sticky => "ew");
    $t->OnDestroy(sub { $steady_mark = $orig_steady_mark; });
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
    foreach my $def ([M"Straßen (Fahrrad)",  's'],
		     ($devel_host ? [M"Straßen (Auto)", 's-car'] : ()),
		     (!$skip_features{'u-bahn'} || !$skip_features{'s-bahn'} ? [M"U/S-Bahn", 'us'] : ()),
		     (!$skip_features{'r-bahn'} ? [M"R-Bahn", 'r'] : ()),
		     (!$skip_features{'u-bahn'} || !$skip_features{'s-bahn'} || !$skip_features{'r-bahn'} ? [M"Gesamtes Bahnnetz", 'rus'] : ()),
		     [M"Wasserrouten", 'wr'],
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
    # XXX check whether this is significant in any way, and if not:
    # delete! Also change_net_type has to be amended, maybe.
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
    $bpcm->command(-label => M"Koordinaten setzen",
		   -command => \&set_coord_interactive);
    $bpcm->command(-label => M"Linienkoordinaten setzen",
		   -command => \&set_line_coord_interactive);
    $bpcm->command(-label => M"Koordinaten aus Selection",
		   -command => \&coord_to_markers_dialog);
    $bpcm->separator;
    $bpcm->command(-label => M"Koordinatenliste zeigen",
		   -command => \&show_coord_list);
    $bpcm->command(-label => M"Path to Selection",
		   -command => \&path_to_selection);
    $bpcm->command(-label => M"Marks to Path",
		   -command => \&marks_to_path);
    $bpcm->command(-label => M"Marks to Selection",
		   -command => \&marks_to_selection);
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
    $bpcm->cascade(-label => M('Kurvenpunkte/Kreuzungen'));
    {
	my $csm = $bpcm->Menu(-title => M('Kurvenpunkte/Kreuzungen'));
	$bpcm->entryconfigure('last', -menu => $csm);
	foreach my $coldef ([M"Kurvenpunkte rot", '#800000'],
			    [M"Kurvenpunkte grün", '#008000'],
			    [M"Kurvenpunkte blau", '#000080'],
			    [M"Kurvenpunkte schwarz", '#000000'],
			   ) {
	    $csm->radiobutton(-label    => $coldef->[0],
			      -variable => ref $pp_color ? \$pp_color->[0] : \$pp_color,
			      -value    => $coldef->[1],
			      -command  => sub { pp_color() },
			     );
	}
	if (0 && ref $pp_color) { # not yet used
	    $csm->separator;
	    foreach my $coldef ([M"Kreuzungen blau", 'blue'],
				[M"Kreuzungen schwarz", 'black'],
			       ) {
		$csm->radiobutton(-label    => $coldef->[0],
				  -variable => \$pp_color->[1],
				  -value    => $coldef->[1],
				  -command  => sub { pp_color() },
				 );
	    }
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

    $bpcm->command(-label => M"Schnelles Neuladen von Änderungen",
		   -command => sub { reload_all() },
		   -accelerator => 'Ctrl-R',
		  );
    $bpcm->command(-label => M"Gründliches Neuladen von Änderungen",
		   -command => sub { reload_all(force => 1) },
		  );
    $bpcm->checkbutton(-label => M"Lazy drawing für alle Layer",
		       -variable => \$lazy_plot,
		      );
    $bpcm->cascade(-label => M"Markierungen");
    {
	my $c_bpcm = $bpcm->Menu(-title => M"Markierungen");
	$bpcm->entryconfigure("last", -menu => $c_bpcm);
	$c_bpcm->command
	    (-label => M"Verschieben der Markierung",
	     -command => sub { require BBBikeEdit;
			       BBBikeEdit::move_marks_by_delta();
			   },
	    );
	$c_bpcm->command
	    (-label => M"Reset mark_adjusted-Tag",
	     -command => sub { require BBBikeEdit;
			       BBBikeEdit::reset_map_adjusted_tag();
			   },
	    );
    }
## XXX NYI:
#    $bpcm->command(-label => M"Neuzeichnen aller Layer",
#		   -command => sub { reload_all_unconditionally() },
#		  );
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
	    if ($_ eq 'polar') {
		$ausm->radiobutton(-label => $name . ' (DMS)',
				   -variable => \$coord_output,
				   -value => "$_:dms",
				   -command => sub { set_coord_output_sub() },
				  );
	    }
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
    if ($stderr_window && defined $Devel::Trace::TRACE) {
	warn <<EOF;
**********************************************************************
* NOTE: It seems that -d:Trace is requested. It's a bad idea
*       to use this together with Tk::Stderr, so the latter
*       is disabled.
**********************************************************************
EOF
	return;
    }
    if ($stderr_window) {
	if (!eval { require Tk::Stderr; Tk::Stderr->VERSION(1.2); }) {
	    if (!perlmod_install_advice("Tk::Stderr")) {
		$stderr_window = 0;
		return;
	    }
	}
	if (!$Tk::Stderr::__STDERR_PATCHED__) {

	    # See https://rt.cpan.org/Ticket/Display.html?id=20718

	    local $^W = 0; # redefined...

	    *Tk::Stderr::Handle::TIEHANDLE = sub {
		my ($class, $window) = @_;
		bless { w => $window, pid => $$ }, $class;
	    };

	    *Tk::Stderr::Handle::PRINT = sub {
		my $self = shift;
		if ($self->{pid} != $$) {
		    # child window, use fallback
		    print STDOUT "@_";
		} else {
		    my $window = $self->{w};
		    my $text = $window->Subwidget('text');
		    if ($text) {
			$text->insert('end', $_) foreach (@_);
			$text->see('end');
			$window->deiconify;
			$window->raise;
			$window->focus;
		    } else {
			# no window yet, use fallback
			print STDOUT "@_";
		    }
		}
	    };

	    $Tk::Stderr::__STDERR_PATCHED__ = 1;
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
    my $ret = 0;
    IncBusy($top);
    eval {
	require "$FindBin::RealBin/miscsrc/insert_points";
	my @args = (-operation => $oper_name,
		    (-e "$datadir/.custom_files" ? (-addfilelist => "$datadir/.custom_files") : ()),
		    "-useint", # XXX but not for polar coordinates
		    -datadir => $datadir,
		    -bbbikerootdir => $FindBin::RealBin,
		    "-tk",
		    ($verbose ? "-v" : ()),
		    @inslauf_selection,
		   );
#XXX:
# 	if (!$SRTShortcuts::force_edit_mode) {
# 	    push @args, (
# 			 (!defined $edit_mode || $edit_mode eq '' ? "-noorig" : ()),
# 			 ($coord_system_obj->coordsys eq 'B' || !defined $edit_mode || $edit_mode eq '' ? () : (-coordsys => $coord_system_obj->coordsys)),
# 			);
# 	}
	warn "@args\n" if $verbose;
	my $modify_ret = BBBikeModify::process(@args);
	$ret = $modify_ret == BBBikeModify::RET_MODIFIED();

	# clear the selection (sometimes)
	if ($modify_ret != BBBikeModify::RET_ERROR() && $oper_name !~ m{^grep}) {
	    delete_route();
	}
    };
    warn $@ if $@;
    DecBusy($top);
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
sub smooth_line   {
    if (@inslauf_selection != 3) {
	status_message("Es müssen genau drei Punkte selektiert sein. Der mittlere Punkt ist der zu verschiebende Punkt für die Glättung.", "err");
	return;
    }
    require VectorUtil;
    require Strassen::Util;
    my($x1,$y1,$p1,$p2,$x2,$y2) = map { split /,/, $_ } @inslauf_selection;
    my($new_p1,$new_p2) = map { int_round($_) } VectorUtil::project_point_on_line($p1,$p2,$x1,$y1,$x2,$y2);
    my($tx1,$ty1,$tx2,$ty2) = (transpose($p1,$p2), transpose($new_p1,$new_p2));
    $c->createLine($tx1,$ty1,$tx2,$ty2,
		   -arrow => 'last',
		   -arrowshape => [3,5,3],
		   -tags => 'smooth_line_movement',
		  );
    $c->createLine($tx2-3,$ty2-3,$tx2+3,$ty2+3,-tags => 'smooth_line_movement');
    $c->createLine($tx2-3,$ty2+3,$tx2+3,$ty2-3,-tags => 'smooth_line_movement');
    main::status_message("Mittleren Punkt um " . (sprintf "%.1f", Strassen::Util::strecke([$p1,$p2],[$new_p1,$new_p2])) . "m verschieben?", "info");
    @inslauf_selection = ("$p1,$p2", "$new_p1,$new_p2");
    my $done;
    eval {
	$done = change_points();
    };
    my $err = $@;
    $c->delete('smooth_line_movement');
    delete_route(); # to avoid confusion about change of @inslauf_selection
    if ($err) {
	status_message($err, 'die');
    }
    $done;
}
sub change_poly_points {
    # XXX NYI
}

sub change_points_maybe_reload {
    change_points(@_);
    $BBBikeEdit::auto_reload = $BBBikeEdit::auto_reload if 0; # peacify -w
    if ($BBBikeEdit::auto_reload) {
	reload_all();
    }
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
    $top->bind("<F3>" => \&change_points_maybe_reload);
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

sub recall_some_subs {
    my @info;
    my $has_errors = 0;
    push @info, "Reloading autoused functions";
    while(my($k,$v) = each %autouse_func) {
	(my $module = $k) =~ s{::}{/}g;
	$module .= ".pm";
	delete $INC{$module};
	eval "use autouse $k => qw(" . join(" ", @$v) . ");";
	if ($@) {
	    push @info, "Can't autouse $k: $@";
	    $has_errors++;
	}
    }
    push @info, "Redefining item attributes"; 
    define_item_attribs();
    push @info, "Generating plot functions";
    generate_plot_functions();
    push @info, "Reset bindings";
    set_bindings();
    push @info, "Reload message catalog";
    Msg::setup_file();
    if ($has_errors) {
	status_message(join("\n",@info), "die");
    }
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
	$v = "" if !defined $v; # may happen (in 5.10.x only?), to cease warnings
	# only record BBBike-related and own modules
	next if $v !~ /bbbike/i && $v !~ /\Q$ENV{HOME}/;
	next if exists $module_time{$v};
	my $modtime = (stat($v))[9];
	if (defined $modtime) { # may be undefined for temporary "reload" files
	    $module_time{$v} = $modtime;
	    warn "recorded $module_time{$v} for $k\n" if $verbose;
	}
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
	next if ($v||0) >= ($now||0);
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

# Gibt den angewählten Punkt auf STDERR aus.
# Ausgegeben wird: Name (soweit vorhanden), Canvas-Koordinaten und
# die Koordinaten abhängig von $coord_output_sub (gewöhnlich berlinmap).
# Außerdem werden die $coord_output_sub-Koordinaten in die Selection
# geschrieben.
# Return-Value: $x, $y (u.U. an den nächsten Punkt normalisiert)
### AutoLoad Sub
sub buttonpoint {
    my($x, $y, $current) = @_;
    my($rx,$ry) = ($x,$y);
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
	clipboardAppendToken($coord);
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
	if ($tags[0] eq 'o'    ||
	    $tags[0] eq 'pp'   ||
	    $tags[0] =~ /^lsa/ ||
	    $tags[0] =~ /^L\d+/||
	    $tags[0] eq 'fz'   ||
	    $tags[0] =~ /^kn/
	   ) {
	    my($tag, $s);
	    $tag = $tags[1];
	    if ($tags[0] eq 'pp' || $tags[0] =~ /^lsa/ ||
		$tags[0] =~ /^L\d+/) {
		my $use_prefix = 1;
		($rx,$ry) = @{Strassen::to_koord1($tags[1])};
		my($x, $y) = $coord_output_sub->($rx,$ry);
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
		clipboardAppendToken($str);
		push_ext_selection($s);
	    } elsif ($tags[0] eq 'o' ||
		     $tags[0] eq 'fz') {
		my($cx, $cy);
		if ($tags[0] eq 'o') {
		    ($cx, $cy) = split /,/, $tags[1];
		}
		if (!defined $cx || !defined $cy) {
		    ($cx, $cy) = anti_transpose($c->coords($current));
		}
		($rx,$ry) = ($cx,$cy);
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
		clipboardAppendToken($str);
		push_ext_selection($s);
	    } else {
		die "Tag $tags[0] wird für das Aufzeichnen von Punkten nicht unterstützt";
	    }
	    $s .= "\n";
	    print STDERR $s;
	}
    }
    ($rx,$ry);
}

### AutoLoad Sub
sub clipboardAppendToken {
    if ($use_clipboard) {
	my($token) = @_;
	if (eval { $c->clipboard('get') } ne '') {
	    $c->clipboardAppend(" ");
	}
	$c->clipboardAppend($token);
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
	# ... and for ampeln
	delete $p_obj{lsa};

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
	# ... and for ampeln
	delete $p_obj{lsa};

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
	if ($unit_s eq 'km') {
	    change_unit('m');
	}
    };
    my $err = $@;
    DecBusy($top) unless $init;
    status_message($err, "die") if $err;

    # Better when editing:
    while(my($type, $cats) = each %str_restrict) {
	while(my($cat, $v) = each %$cats) {
	    $cats->{$cat} = 1 if !$cats->{$cat};
	}
    }
#     $str_restrict{qs}->{Q0} = 1;
#     $str_restrict{ql}->{Q0} = 1;
#     $str_restrict{hs}->{q0} = 1;
#     $str_restrict{hl}->{q0} = 1;
    # This is not switched back when changing to normal mode.
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

use vars qw(@search_anything_history);

# Full text search
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

    require Tk::LabFrame;

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
			@p_file  {qw/u b r o pl/},
			# additional scoped files XXX
			"brunnels",
			"wasserumland", "wasserumland2", "landstrassen2",
			"orte2",
		       );
    if ($advanced) {
	push @search_files, $str_file{fz};
	# kn(eipen) is outdated, do it only here
	push @search_files, $p_file{kn};
    }
    if ($devel_host) {
	push @search_files, map { defined } @p_file{qw(/ki rest/)};
    }

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

    my $sort = "alpha"; # XXX make global and/or configurable
    my $search_type = "rx"; # XXX make global and/or configurable
    my $focus_transfer = 0; # XXX dito

    my $probably_can_string_similarity = module_exists("String::Similarity");
    use constant STRING_SIMILARITY_LEVEL => 0.75;
    my $probably_can_string_approx = module_exists("String::Approx");
    use constant STRING_APPROX_ERRORS => 2;

    my $do_search = sub {
	return if $s eq '';

	if ($search_type eq 'similarity' && !eval { require String::Similarity; 1 }) {
	    perlmod_install_advice("String::Similarity");
	    $search_type = 'substr';
	    return;
	} elsif ($search_type eq 'approx' && !eval { require String::Approx; 1 }) {
	    perlmod_install_advice("String::Approx");
	    $search_type = 'approx';
	    return;
	}

	my $s_rx;
	my $s_munged;
	if ($search_type eq 'substr') {
	    $s_rx = quotemeta($s);
	} elsif ($search_type eq '^substr') {
	    $s_rx = "^" . quotemeta($s);
	} elsif ($search_type eq 'similarity') {
	    $s_munged = lc $s;
	} elsif ($search_type eq 'approx') {
	    $s_munged = lc $s;
	} else {
	    $s_rx = $s;
	    $s_rx =~ s{([sS])traße}{($1traße|$1tr\\.)};
	}
	my $need_utf8_upgrade = $] >= 5.008 && ((defined $s_munged && eval { require Encode; Encode::is_utf8($s_munged) }) ||
						(defined $s_rx     && eval { require Encode; Encode::is_utf8($s_rx) }));
	my $may_utf8_downgrade = $] >= 5.008 && $need_utf8_upgrade && eval { require Encode; Encode::encode("iso-8859-1", Encode::FB_CROAK()); 1 };

### fork in eval is evil ??? (check it, it seems to work for 5.8.0 + FreeBSD)
	IncBusy($t);
	eval {
	    my %found_in;
	    my %title;
	    my $has_egrep = is_in_path("egrep");
	    foreach my $search_file (@search_files) {
		my @matches;
		my $pid;
		#XXX grep is now completely disabled because:
		# * better testing of the public release (non $devel_host)
		# * no support for alias matching
		# Restrictions because of:
		#   possible fork problems
		#                  no String::Similarity support
		#                                        direct grep cannot handle utf-8
		#                                                                                        do we have grep at all?
		if (0 && $devel_host && !defined $s_munged && (!$need_utf8_upgrade || $may_utf8_downgrade) && $has_egrep) {
		    my $s_rx = $s_rx;
		    if ($may_utf8_downgrade) {
			$s_rx = Encode::encode("iso-8859-1", $s_rx);
		    }
		    $pid = open(GREP, "-|");
		    if (!$pid) {
			require POSIX;
			exec("egrep", "-i", $s_rx, $search_file) || warn "Can't exec program grep with $search_file: $!";
			POSIX::_exit();
		    }
		} else {
		    open(GREP, $search_file) || do {
			warn "Can't open $search_file: $!";
			next;
		    }
		}
		binmode GREP;
	    BBD_LINE:
		while(<GREP>) {
		    chomp;
		    utf8::upgrade($_) if $need_utf8_upgrade;
		    if (defined $s_munged) {
			if (/^#:\s*encoding:\s*(.*)/) {
			    Strassen::switch_encoding(\*GREP, $1);
			}
			next if /^\#/;
			my($rec) = Strassen::parse($_);
			my $name = lc $rec->[Strassen::NAME()];
			if ($search_type eq 'similarity') {
			    next if String::Similarity::similarity($name, $s_munged, STRING_SIMILARITY_LEVEL) < STRING_SIMILARITY_LEVEL;
			} else { # $search_type eq 'approx'
			    next if !String::Approx::amatch($s_munged, ['i', STRING_APPROX_ERRORS], $name);
			}
			push @matches, $rec;
			$matches[-1]->[3] = [];
		    } else {
			if (!defined $pid) { # we have to do the grep ourselves
			    if (/^#:\s*encoding:\s*(.*)/) {
				Strassen::switch_encoding(\*GREP, $1);
			    }
			    if (/^#:\s*alias(_wide):?\s*($s_rx.*)$/i) {
				my $alias = $1;
				while(<GREP>) {
				    next if /^#/;
				    my $non_aliased_rec = Strassen::parse($_);
				    $non_aliased_rec->[Strassen::NAME()] .= " ($1)";
				    $non_aliased_rec->[3] = [];
				    push @matches, $non_aliased_rec;
				    next BBD_LINE;
				}
			    } else {
				next unless /$s_rx.*\t/i;
			    }
			}
			next if /^\#/;
			push @matches, Strassen::parse($_);
			$matches[-1]->[3] = [];
		    }
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
	    my %plz_search_args;
	    if ($search_type eq 'similarity') {
		$plz_search_args{Agrep} = 1;
	    } elsif ($search_type eq 'substr' || $search_type eq 'rx') {
		# für rx: Notlösung XXX
		$plz_search_args{GrepType} = "grep-substr";
	    }

	    for my $i (0 .. $#plz) {
		my @plz_matches = $plz[$i]->look($s, %plz_search_args);
		if (@plz_matches) {
		    # in Strassen-Format umwandeln
		    my @matches;
		    foreach (@plz_matches) {
			push @matches, [$_->[&PLZ::LOOK_NAME] . " (".$_->[&PLZ::LOOK_CITYPART] .
					($_->[&PLZ::LOOK_ZIP] ne "" ? ", $_->[&PLZ::LOOK_ZIP]" : "") .
					")", [$_->[&PLZ::LOOK_COORD]], "X", []];
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
		    @sorted_matches =
			map  { $_->[1] }
			sort { $a->[0] cmp $b->[0] }
			map  {
			    (my $sortname = $_->[0]) =~ s{^\(}{};
			    [$sortname, $_];
			} @$matches;
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
    $f1->Label(-text => M("Nach").":", -padx => 0, -pady => 0,
	       -underline => 0,
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
    $t->bind("<Alt-Key-n>" => sub { $e->focus });

    $f1->Button(Name => 'search',
		-command => $do_search,
		-padx => 4,
		-pady => 2,
	       )->pack(-side => "left");


    {
 	package Tk::ListboxSearchAnything;
 	use base qw(Tk::Listbox);
 	Construct Tk::Widget 'ListboxSearchAnything';
 	*UpDown = sub {
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
 	};
    }

    $lb = $t->Scrolled("ListboxSearchAnything", -scrollbars => "osoe",
		       -width => 32,
		       -height => 12,
		      )->pack(-fill => "both", -expand => 1);
    {
	my $f = $t->LabFrame(-label => M("Suchart"),
			     -labelside => "acrosstop",
			    )->pack(-fill => "x");
	for my $cb_def (["Regulärer Ausdruck", "rx"],
			["Teilstring", "substr"],
			["Teilstring am Anfang", "^substr"],
			($devel_host ?
			 (
			  ($probably_can_string_similarity ? ["Ungenaue Suche (String::Similarity)", "similarity"] : ()),
			  ($probably_can_string_approx ? ["Ungenaue Suche (String::Approx)", "approx"] : ()),
			 ) :
			 (
			  # XXX check which one will be used
			  $probably_can_string_similarity ? ["Ungenaue Suche", "similarity"] : ()
			  #($probably_can_string_approx ? ["Ungenaue Suche", "approx"] : ()),
			 )
			)
		       ) {
	    my($text, $search_type_value) = @$cb_def;
	    $f->Radiobutton(-text => M($text),
			    -variable => \$search_type,
			    -value => $search_type_value,
			   )->pack(-anchor => "w");
	}
    }
    $lb->Subwidget("scrolled")->{SortTypeRef} = \$sort;
    {
	my $f = $t->LabFrame(-label => M("Suchergebnis sortieren"),
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
    {
	my $f = $t->LabFrame(-label => M("Fokus nach Auswahl"),
			     -labelside => "acrosstop",
			    )->pack(-fill => "x");
	$f->Radiobutton(-text => M("Suchfenster"),
			-variable => \$focus_transfer,
			-value => 0,
		       )->pack(-anchor => "w");
	$f->Radiobutton(-text => M("Karte"),
			-variable => \$focus_transfer,
			-value => 1,
		       )->pack(-anchor => "w");
    }

    my $cb;
    {
	my $f = $t->Frame->pack(-fill => "x");
	$cb = $f->Button(Name => 'close',
			 -command => sub {
			     $t->withdraw;
			     #$t->destroy;
			 })->pack(-side => "right");
    }
    $t->protocol(WM_DELETE_WINDOW => sub { $cb->invoke });

    my $_select = sub {
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
	    return 1;
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
	    return 1;
	} else {
	    return 0;
	}
    };
    my $select = sub {
	my $ret = $_select->(@_);
	if ($ret && $focus_transfer) {
	    $top->focusForce;
	}
	$ret;
    };

    $lb->bind("<Double-1>" => $select);
    $lb->bind("<Return>" => $select);

    $t->bind('<<CloseWin>>' => sub { $cb->invoke });

    if ($t->can('UnderlineAll')) { $t->UnderlineAll(-radiobutton => 1, -donotuse => ['N']) }

    $t->Popup(@popup_style);

    if (defined $s) {
	$do_search->();
    }
}

use vars qw($gps_animation_om $gps_animation_om2);

### AutoLoad Sub
sub gps_animation_update_optionmenu {
    for my $om ($gps_animation_om, $gps_animation_om2) {
	if (defined $om && Tk::Exists($om)) {
	    $om->configure(-options => []); # empty old
	    for my $i (0 .. MAX_LAYERS) {
		my $abk = "L$i";
		if ($str_draw{$abk} && $str_file{$abk} =~ /gpsspeed/) {
		    $om->addOptions([$str_file{$abk} => $i]);
		}
	    }
	    if ($om eq $gps_animation_om2) {
		$om->addOptions(["" => ""]);
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
    $t->gridColumnconfigure(0,  -weight => 0);
    $t->gridColumnconfigure($_, -weight => 1) for (1..2);
    my $can_2nd_track = eval { require DB_File; 1 };
    my %track2_cache;
    if ($can_2nd_track) {
	tie %track2_cache, 'DB_File', undef, undef, undef, $DB_File::DB_BTREE
	    or warn $!, undef $can_2nd_track;
    }
    my($trackfile, $trackfile2);
    my($track_abk, $track_abk2);
    my $track_i = 0;
    my $anim_timer;
    my($start_b, $skip_b);
    my $row = 0;
    my $is_first_om = 1;
    for my $def ([\$trackfile,  \$track_abk,  \$gps_animation_om],
		 [\$trackfile2, \$track_abk2, \$gps_animation_om2],
		) {
	my($trackfile_ref, $track_abk_ref, $om_ref) = @$def;
	my $om = $t->Optionmenu(-textvariable => $trackfile_ref,
				-variable => $track_abk_ref,
				-command => sub {
				    $t->afterCancel($anim_timer)
					if defined $anim_timer;
				    undef $anim_timer;
				    if (!$is_first_om) {
					%track2_cache = ();
				    }
				    $track_i = 0;
				    $start_b->configure(-text => M"Start")
					if $start_b && $is_first_om;
				})->grid(-row => $row++, -column => 0, -columnspan => 3, -sticky => "w");
	$$om_ref = $om;
	$is_first_om = 0;
	last if !$can_2nd_track;
    }
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
		     -resolution => 1, # a -resolution of 10 would make 0 the lowest possible value!
		     -showvalue => 1,
		     -variable => \$speed,
		    );
    # XXX ist LogScale hier eine gute Idee?
    eval {
	# XXX LogScale und -variable sollte wieder gehen, check!
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
    $t->Label(-text => M"Zeitraffer-Faktor")->grid(-row => $row, -column => 0, -sticky => "w");
    $t->$Scale(-from => 1,
	       -to => 500, -orient => "horiz",
	       %scaleargs)->grid(-row => $row, -column => 1, -columnspan => 2, -sticky => "ew");
    $row++;

    for (1 .. 2) {
	$c->createRectangle(0,0,0,0,-width=>2,-outline => $_ eq 1 ? "#c08000" : "#80c000", -tags => ["gpsanimrect$_", "gpsanimrect"]);
    }

    my $dir = +1;
    my($curr_speed, $curr_time, $curr_dist, $curr_abs_time);

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

	my @abstime = $name1 =~ /abstime=(\d+):(\d+):(\d+)/;
	$curr_abs_time = sprintf "%02d:%02d:%02d", @abstime;

	my $other_tag1;
	if ($track_abk2 ne "" && $track_abk2 ne $track_abk) {
	    if (!%track2_cache) {
		my $track_i2 = 0;
		while(1) {
		    my($other_name) = ($c->gettags("L${track_abk2}-".$track_i2))[1];
		    last if !$other_name;
		    my @other_abstime = $other_name =~ /abstime=(\d+):(\d+):(\d+)/;
		    my $other_abstime = $other_abstime[0]*3600 + $other_abstime[1]*60 + $other_abstime[2];
		    $other_abstime = sprintf "%05d", $other_abstime; # leading zeros necessary for string comparison
		    $track2_cache{$other_abstime} = $track_i2;
		    $track_i2++;
		}
	    }

	    my $abstime = $abstime[0]*3600 + $abstime[1]*60 + $abstime[2];
	    my $key = sprintf "%0d", $abstime;
	    my $val;
	    (tied %track2_cache)->seq($key, $val, DB_File::R_CURSOR());
	    my $nearest_i = $val;
	    if (defined $nearest_i) {
		$other_tag1 = "L${track_abk2}-".$nearest_i;
	    }
	}

	$anim_timer =
	    $t->after(1000*abs($time1-$time0)/$speed, sub {
		      my $item = $c->find(withtag => $tag1);
		      my($x,$y) = $c->coords($item);
		      my $pad = 5;
		      $c->coords("gpsanimrect1", $x-$pad,$y-$pad,$x+$pad,$y+$pad);
		      $c->center_view($x,$y);
		      if (defined $other_tag1) {
			  my $item = $c->find(withtag => $other_tag1);
			  my($x,$y) = $c->coords($item);
			  $c->coords("gpsanimrect2", $x-$pad,$y-$pad,$x+$pad,$y+$pad);
		      }
		      $track_i+=$dir;
		      if ($track_i < 0) {
			  # XXX set start button
			  warn "Stopped track...";
			  return;
		      }
		      $next_track_point->();
		  });
    };

    $t->Label(-text => M"Geschwindigkeit: ")->grid(-row => $row, -column => 0, -sticky => "w");
    $t->Label(-textvariable => \$curr_speed)->grid(-row => $row, -column => 1, -sticky => "w");
    $t->Label(-text => M"km/h")->grid(-row => $row, -column => 2, -sticky => "w");
    $row++;

    $t->Label(-text => M"Distanz: ")->grid(-row => $row, -column => 0, -sticky => "w");
    $t->Label(-textvariable => \$curr_dist)->grid(-row => $row, -column => 1, -sticky => "w");
    $t->Label(-text => M"km")->grid(-row => $row, -column => 2, -sticky => "w");
    $row++;

    $t->Label(-text => M"Fahrzeit: ")->grid(-row => $row, -column => 0, -sticky => "w");
    $t->Label(-textvariable => \$curr_time)->grid(-row => $row, -column => 1, -sticky => "w");
    $row++;

    $t->Label(-text => M"Zeit: ")->grid(-row => $row, -column => 0, -sticky => "w");
    $t->Label(-textvariable => \$curr_abs_time)->grid(-row => $row, -column => 1, -sticky => "w");
    $row++;

    my $before_close_window = sub {
	$t->afterCancel($anim_timer) if defined $anim_timer;
	$c->delete("gpsanimrect");
    };

    {
	my $f = $t->Frame->grid(-row => $row, -column => 0, -columnspan => 3);
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
		       $before_close_window->();
		       $t->destroy;
		   })->pack(-side => "left");
    }
    $t->OnDestroy($before_close_window);
    $t->Popup(@popup_style);
}

use vars qw(%xbase);

sub get_dbf_info {
    my($dbf_file, $index) = @_;
    if (!$xbase{$dbf_file}) {
	if (!eval { require XBase; 1 }) {
	    perlmod_install_advice("XBase");
	    return;
	}
	$xbase{$dbf_file} = XBase->new($dbf_file) or do {
	    warn XBase->errstr;
	    return undef;
	};
    }
    join(":", $xbase{$dbf_file}->get_record($index));
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

sub marks_to_path {
    my @mark_items = $c->find(withtag => "show");
    delete_route();
    for my $item (@mark_items) {
	my @coords = $c->coords($item);
	for(my $xy_i = 0; $xy_i < $#coords; $xy_i+=2) {
	    my($xx,$yy) = @coords[$xy_i, $xy_i+1];
	    my($x,$y) = anti_transpose($xx,$yy);
	    addpoint_xy($x,$y,$xx,$yy);
	}
    }
}

sub marks_to_selection {
    marks_to_path();
    path_to_selection();
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
	status_message(M"Genau zwei Koordinaten erwartet!", "error");
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

sub map_button {
    my($misc_frame, $curr_row, $col_ref) = @_;

    my $map_photo = load_photo($misc_frame, 'map');
    my $karte_check = $misc_frame->$Checkbutton
	(image_or_text($map_photo, 'Map'),
	 -variable => \$map_draw,
	 -command => sub { getmap($c->get_center, undef, -from_check => 1) },
	)->grid(-row => $curr_row, -column => $$col_ref, -sticky => 's');
    $balloon->attach($karte_check, -msg => M"reale Karte");
    $ch->attach($karte_check, -pod => "^\\s*Karten-Symbol");

    my $kcmb = $misc_frame->Menubutton;
    my $kcm = get_map_button_menu($kcmb);
    menuright($karte_check, $kcm);
    menuarrow($kcmb, $kcm, $$col_ref++,
	      -menulabel => M"Karte", -special => 'LAYER');
}

sub get_map_button_menu {
    my($kcmb) = @_;

    my $kcm = $kcmb->Menu(-title => M"reale Karte");
    my $set_default_type;

    $kcm->checkbutton(-label => M"Karte einblenden",
		      -variable => \$map_draw,
		      -command => sub {
			  getmap($c->get_center, undef, -from_check => 1);
		      }
		     );

    $kcm->cascade(-label => M"Kartentypen");
    {
	my $kcms = $kcm->Menu(-title => M"Automatische Anpassung");
	$kcm->entryconfigure('last', -menu => $kcms);
	foreach (@Karte::map) {
	    my $o = $Karte::map{$_};
	    if ($o->can('coord')) { # check auf Karten-Funktion
		$kcms->radiobutton(-label => $o->name,
				   -variable => \$map_default_type,
				   -value => $o->token,
				  );
	    }
	    if ($_ eq 'brbmap') {
		my $index = $kcm->index('last');
		push @edit_mode_brb_cmd, sub { $kcm->invoke($index) };
	    } elsif ($_ eq 'berlinmap') {
		my $index = $kcm->index('last');
		push @edit_mode_b_cmd, sub { $kcm->invoke($index) };
	    }
	}
    }

    $kcm->separator;
    $kcm->checkbutton(-label => M"WWW",
		      -variable => \$do_wwwmap,
		     );
    $kcm->checkbutton(-label => M"WWW-Cache",
		      -variable => \$use_wwwcache,
		     );
    $kcm->separator;
    $kcm->checkbutton(-label => M"Fallback",
		      -variable => \$use_map_fallback,
		     );
    $kcm->checkbutton(-label => M"mit Umgebung",
		      -variable => \$map_surround,
		     );
    $kcm->checkbutton(-label => M"mehrere Karten",
		      -variable => \$dont_delete_map,
		     );
    $kcm->command(-label => M"Karten löschen",
		  -command => \&delete_map,
		 );
    if ($advanced) {
	$kcm->command(-label => M"Karten um Delta verschieben",
		      -command => \&adjust_map_by_delta,
		     );
	$kcm->command(-label => M"Reset map_adjusted-Tag",
		      -command => \&reset_map_adjusted_tag,
		     );
    }
    $kcm->separator;
    foreach my $color ([M"Farbe (Photo)", 'color'],
		       [M"Farbe (Pixmap)", 'pixmap'],
		       [M"Graustufen", 'gray'],
		       [M"Schwarz/Weiß", 'mono'],
		      ) {
	$kcm->radiobutton(-label => $color->[0],
			  -variable => \$map_color,
			  -value => $color->[1],
			 );
    }
    menu_entry_up_down($kcm, $tag_group{'map'});

    $kcm;
}

sub special_raise_taggroup {
    my($tags, $delay) = @_;
    for my $tag (@$tags) { special_raise($tag, 1) }
    restack() unless $delay;
}

sub special_lower_taggroup {
    my($tags, $delay) = @_;
    for my $tag (reverse @$tags) { special_lower($tag, 1) }
    restack() unless $delay;
}


# REPO BEGIN
# REPO NAME module_exists /home/e/eserte/work/srezic-repository 
# REPO MD5 c80b6d60e318450d245a0f78d516153b

=head2 module_exists($module)

Return true if the module exists in @INC

=cut

sub module_exists {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return 1 if $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return 1;
	}
    }
    return 0;
}
# REPO END

1;

__END__
