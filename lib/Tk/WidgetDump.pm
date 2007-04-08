#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: WidgetDump.pm,v 1.33 2007/04/08 19:34:18 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999-2007 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::WidgetDump;
use vars qw($VERSION);
use strict;

$VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

package # hide from CPAN indexer
  Tk::Widget;
use Tk;
use Tk::Tree;
use Tk::Balloon;

sub WidgetDump {
    my($top, %args) = @_;
    my $t = $top->Toplevel;
    $t->title("WidgetDump of $top");
    $t->geometry("620x420");
    foreach my $key (qw(Control-C q)) {
	$t->bind("<$key>" => sub { $t->destroy });
    }
    $t->{Top}  = $top;
    $t->{Args} = \%args;

    bless $t, 'Tk::WidgetDump';

    my $bf = $t->Frame->pack(-fill => 'x', -side => "bottom");

    my $hl = $t->WD_HList->pack(-fill => 'both', -expand => 1);
    $t->Advertise("HList" => $hl);

    my $rb = $bf->Button(-text => "Refresh",
			 -command => [$t, "WD_Refresh"],
			)->pack(-side => "left");
    my $cb = $bf->Button(-text => "Close",
			 -command => [$t, "WD_Close"],
			)->pack(-side => "left");
    $bf->Button(-text => "Help",
		-command => sub {
		    if (!eval { require Tk::Pod; 1}) {
			$bf->messageBox(-message => "Tk::Pod is not installed!");
			return;
		    }
		    $bf->Pod(-file => $INC{"Tk/WidgetDump.pm"},
			     -title => "Tk::WidgetDump documentation");
		})->pack(-side => "right", -anchor => "e");
    $t->bind("<Alt-r>"  => sub { $rb->invoke });
    $t->bind("<Escape>" => sub { $cb->invoke });

## NYI:
#      $t->{TrackWidgets} = 1;
#      my $balloon;
#      my $pathname;
#      $balloon = $top->Balloon
#  	(-balloonposition => 'mouse',
#  	 -motioncommand => sub {
#  	     return unless $t->{TrackWidgets};
#  	     my $ev = $top->XEvent;
#  	     my($w_under) = $top->containing($ev->X, $ev->Y);
#  	     $pathname = $w_under->PathName;
#  	     1;
#  	 });
#      $balloon->attach($top, -msg => \$pathname);
#      $bf->Checkbutton(-text => "Track",
#  		     -variable => \$t->{TrackWidgets},
#  		    )->pack(-side => 'left');
    if(0) { # not yet...
    $top->bind("<1>" => [ sub { return unless $t && Tk::Exists($t);
				shift;
				$t->SelectWidget(@_);
			    }, Ev('X'), Ev('Y') ]);
    }

}

sub WD_HList {
    my($t) = @_;

    my $top  = $t->{Top};
    my $args = $t->{Args};

    my $hl;
    $hl = $t->Scrolled('Tree', -drawbranch => 1, -header => 1,
		       #-columns => 5,
		       -columns => 4,
		       -scrollbars => "osow",
		       -selectmode => "multiple",
		       -exportselection => 1,
		       -takefocus => 1,
		       -width => 40,
		       -height => 20,
		       ($args->{-font} ? (-font => $args->{-font}) : ()),
		       -command => sub {
			   my $sw = $hl->info('data', $_[0]);
			   $t->_show_widget($sw);
		       },
		      )->pack(-fill => 'both', -expand => 1);
    $t->Advertise("Tree" => $hl);
    $hl->focus;
    $hl->headerCreate(0, -text => "Tk Name");
    $hl->headerCreate(1, -text => "Tk Class");
    $hl->headerCreate(2, -text => "Characteristics");
    $hl->headerCreate(3, -text => "Perl-Class");
    #XXX $hl->headerCreate(4, -text => "Size");
    $t->_insert_wd($hl, $top);
    if (exists $args->{-openinfo}) {
#XXX needs work
#	while(my($k,$v) = each %{ $args->{-openinfo} }) {
#	    $hl->setmode($k, $v);
#	}
    } else {
	$hl->autosetmode;
    }

    if ($hl->can("menu") and $hl->can("PostPopupMenu")) {
	my $popup_menu = $hl->Menu
	    (-menuitems =>
	     [
	      [Cascade => "~Edit", -menuitems =>
	       [
		[Button => "~Refresh", -command => sub { $t->WD_Refresh }],
		[Button => "~Close", -command => sub { $t->WD_Close }],
	       ],
	      ],
	      [Cascade => "~Font", -menuitems =>
	       [
		[Button => "~Tiny",
		 -command => sub { $hl->configure(-font => "Helvetica 6") }],
		[Button => "~Small",
		 -command => sub { $hl->configure(-font => "Helvetica 8") }],
		[Button => "~Normal",
		 -command => sub { $hl->configure(-font => "Helvetica 10") }],
		[Button => "~Large",
		 -command => sub { $hl->configure(-font => "Helvetica 18") }],
		[Button => "~Huge",
		 -command => sub { $hl->configure(-font => "Helvetica 24") }],
	       ]
	      ]
	     ]
	    );
	$hl->menu($popup_menu);
	$hl->bind("<3>" => sub {
			  my $e = $_[0]->XEvent;
			  $_[0]->PostPopupMenu($e->X, $e->Y);
		      });
    }

    $hl;
}

sub _WD_Size {
    my $w = shift;
    my $size = 0;
    eval {
	while(my($k,$v) = each %$w) {
	    if (defined $v) {
		$size += length($k) + length($v);
	    }
	}
    };
    warn $@ if $@;
    $size;
}

sub WD_Refresh {
    my $t = shift;
    my %args;
    my %openinfo;
    my $hl = $t->Subwidget("HList");
    foreach ($hl->info('children')) {
	$openinfo{$_} = $hl->getmode($_);
    }
    my $first_seen = $hl->nearest($hl->height/2);
    my $see;
    if (defined $first_seen) {
	$see = $hl->info("data",$first_seen);
    }
    my %pack_info = $hl->packInfo;

    $hl->destroy;
    $hl = $t->WD_HList($t->{Top}, $t->{Args});
    $hl->pack(%pack_info);
    $t->Advertise("HList" => $hl);

    if (defined $see) {
	$t->see($see);
    }
}

sub WD_Close {
    my $t = shift;
    $t->destroy;
}

######################################################################

package Tk::WidgetDump;
use base qw(Tk::Toplevel);

use File::Basename;

use vars qw(%ref2widget);

sub Flash {
    my $wd = shift;
    my $w = shift;
    eval {
	# Wenn ein Widget während eines Flashs nochmal ausgewählt wird,
	# muss es erst einmal zurückgesetzt werden.
	if (defined $wd->{OldRepeat}) {
	    $wd->{OldRepeat}->cancel;
	    if (defined $wd->{OldBg}) {
		$wd->{OldWidget}->configure(-background => $wd->{OldBg});
	    }
	}

	my $old_bg = $w->cget(-background);
	# leicht verzögern, damit -background nicht vom Blinken verfälscht wird
	$w->after(10, sub { $w->configure(-background => "red") });
	$w->Tk::raise;
	my $i = 0;

	my $flash_rep;
	$flash_rep = $w->repeat
	  (500,
	   sub {
	       if ($i % 2 == 0) {
		   $w->configure(-background => "red");
	       } else {
		   $w->configure(-background => $old_bg);
	       }
	       if (++$i > 8) {
		   $flash_rep->cancel;
		   undef $wd->{OldRepeat};
		   $w->configure(-background => $old_bg);
	       }
	   });

	$wd->{OldWidget} = $w;
	$wd->{OldBg}     = $old_bg;
        $wd->{OldRepeat} = $flash_rep;
    };
    warn $@ if $@;
}

sub SelectWidget {
    my $wd = shift;
    my($X,$Y) = @_;
    my $w = $wd->containing($X, $Y);
    return unless $w;

    my $hl = $wd->Subwidget("Tree");
    my $c = ($hl->info("children"))[0];
    while (defined $c and $c ne "") {
	if ($w eq $hl->info('data', $c)) {
	    $hl->see($c);
	    $hl->anchorSet($c);
	    last;
	}
	$c = $hl->info("next", $c);
    }

    $wd->_show_widget($w);
}

sub WidgetInfo {
    my $wd = shift;
    my $w = shift;

    $wd->{WidgetInfoWidget} = $w;

    my $wi = $wd->_get_widget_info_window;
    $wi->title("Widget Info for " . $w);

    my $txt = $wi->Subwidget("Information");
    $txt->delete("1.0", "end");

    $txt->insert("end", "Configuration:\n\n", "title");
    $txt->insert("end", "Option Switch\tOptionDB Name\tOptionDB Class\tDefault Value\tCurrent Value\n", "title");
    foreach my $c ($w->configure) {
	$txt->insert("end",
		     join("\t", map { !defined $_ ? "<undef>" : $_ } @$c),
		     ["widgetlink",
		      "config-" . $w . ($c->[0]||"") . "-" . ($c->[2]||"")],
		     "\n");
    }
    $txt->insert("end", "\n");

    my $insert_method = sub {
	my($meth, $label) = @_;
	$label = $meth if !defined $label;
	$txt->insert("end", "$label:\t" . $w->$meth() . "\n");
    };

    $txt->insert("end", "Miscellaneous:\n\n", "title");

    $insert_method->("name", "Name");
    $insert_method->("PathName");
    $insert_method->("Class");

    $Tk::WidgetDump::ref2widget{$w} = $w;

    $txt->insert("end", "Self:\t" . $w . "\n");
    if (defined $w->parent) {
	$txt->insert("end", "Parent:\t" . $w->parent,
		     ["widgetlink", "href-" . $w->parent], "\n");
	$Tk::WidgetDump::ref2widget{$w->parent} = $w->parent;
    }

    if (defined $w->toplevel) {
	$txt->insert("end", "Toplevel:\t" . $w->toplevel,
		     ["widgetlink", "href-" . $w->toplevel],
		     "\n");
	$Tk::WidgetDump::ref2widget{$w->toplevel} = $w->toplevel;
    }

    if (defined $w->MainWindow) {
	$txt->insert("end", "MainWindow:\t" . $w->MainWindow,
		     ["widgetlink", "href-" . $w->MainWindow],
		     "\n");
	$Tk::WidgetDump::ref2widget{$w->MainWindow} = $w->MainWindow;
    }

    my @children = $w->children;
    if (@children) {
	$txt->insert("end", "Children:");
	my $tab = "\t";
	my $c_count=0;
	foreach my $sw (@children) {
	    $txt->insert("end", $tab . $sw,
			 ["widgetlink", "href-" . $sw],
			 "\n");
	    $Tk::WidgetDump::ref2widget{$sw} = $sw;
	    $tab = "\t";
	    if ($c_count > 10) {
		$txt->insert("end", $tab . "...");
	    }
	}
    }
    my @subwidgets = keys %{ $w->{SubWidget} };
    if (@subwidgets) {
	$txt->insert("end", "Subwidgets:");
	my $tab = "\t";
	my $c_count=0;
	foreach my $sw_name (@subwidgets) {
	    my $sw = $w->Subwidget($sw_name);
	    $txt->insert("end", $tab . $sw_name . " => " . $sw,
			 ["widgetlink", "href-" . $sw],
			 "\n");
	    $Tk::WidgetDump::ref2widget{$sw} = $sw;
	    $tab = "\t";
	    if ($c_count > 10) {
		$txt->insert("end", $tab . "...");
	    }
	}
    }

    $insert_method->("manager", "GeomManager");
    my $manager = $w->manager;
    if ($manager) {
	my $info_cmd = ($manager eq 'tixForm' ? 'formInfo' : $manager.'Info');
	my %info = eval { $w->$info_cmd() };
	warn $@ if $@;
	if (keys %info) {
	    my $need_comma;
	    my %win_info;
	    $txt->insert("end", "    info:\t");
	    if ($info{-in}) {
		$win_info{-in} = delete $info{-in};
		$txt->insert("end", "-in => $win_info{-in}",
			     ["widgetlink", "href-" . $win_info{-in}]);
		$Tk::WidgetDump::ref2widget{$win_info{-in}} = $win_info{-in};
		$need_comma++;
	    }
	    my $info = ($need_comma ? ", " : "") .
		join(", ", map { "$_ => $info{$_}" } keys %info);
	    $txt->insert("end", $info . "\n");
	}
    }
    eval {
	my(@wrapper) = $w->wrapper;
	if (@wrapper) {
	    $txt->insert("end", "wrapper:\t" . join(", ", @wrapper) . "\n");
	}
    };
    $insert_method->("geometry");
    $insert_method->("rootx");
    $insert_method->("rooty");
    $insert_method->("vrootx");
    $insert_method->("vrooty");
    $insert_method->("x");
    $insert_method->("y");
    $insert_method->("width");
    $insert_method->("height");
    $insert_method->("reqwidth");
    $insert_method->("reqheight");
    $insert_method->("id");
    $insert_method->("ismapped");
    $insert_method->("viewable");

# XXX bindtags
# XXX bind?

    $txt->insert("end", "\nServer:\n");
    $insert_method->("server", "    id");
    $insert_method->("visual", "    visual");
#XXX dokumentiert, aber nicht vorhanden?!
#    $insert_method->("visualid", "    visualid");
    $insert_method->("visualsavailable", "    visualsavailable");

    $txt->insert("end", "\nRoot window:\n");
    $insert_method->("vrootwidth", "    vrootwidth");
    $insert_method->("vrootheight", "    vrootheight");

    $txt->insert("end", "\nScreen:\n");
    $insert_method->("screen", "    id");
    $insert_method->("screencells", "    cells");
    $insert_method->("screenwidth", "    width");
    $insert_method->("screenheight", "    height");
    $insert_method->("screenmmwidth", "    width (mm)");
    $insert_method->("screenmmheight", "    height (mm)");
    $insert_method->("screenvisual", "    visual");

    $txt->insert("end", "\nColor map:\n");
    $insert_method->("cells", "    cells");
    $insert_method->("colormapfull", "    full");
    $insert_method->("depth", "    depth");

    $txt->insert("end", "\n");

    {
	my $b = $txt->Button(-text => "Flash widget",
			     -command => sub {
				 $wd->Flash($w);
			     });
	$txt->windowCreate("end", -window => $b);
    }
    my $b = $txt->Button(-text => "Method call",
			 -command => sub {
			     $wd->method_call($w);
			 });
    $txt->windowCreate("end",
		       -window => $b,
		       );

    if ($w->isa('Tk::Canvas')) {
	my $b = $txt->Button(-text => "Canvas dump",
			     -command => sub {
				 $wd->canvas_dump($w);
			     });
	$txt->windowCreate("end",
			   -window => $b,
			  );
    }

    my $ObjScanner;
    if (!eval {
		require Tk::ObjEditor;
		$ObjScanner = "ObjEditor";
		$Storable::forgive_me = $Storable::forgive_me = 1; # XXX hack to prevent problems with code refs
		1;
	    }) {
	eval { require Tk::ObjScanner;
	       $ObjScanner = "ObjScanner";
	       1;
	   };
    }

    if (defined $ObjScanner) {
	my $b = $txt->Button
	    (-text => $ObjScanner,
	     -command => sub {
		 my $t = $b->Toplevel(-title => $ObjScanner);
		 my $os = $t->$ObjScanner
		     (caller => $w,
		      title  => "$ObjScanner $w",
		      background       => 'white',
		      selectbackground => 'beige',
		      foldImage => $t->Photo(-file => Tk->findINC('folder.xpm')),
		      openImage => $t->Photo(-file => Tk->findINC('openfolder.xpm')),
		      itemImage => $t->Photo(-file => Tk->findINC('textfile.xpm')))->pack(-fill => "both", -expand => 1);
	     });
	$txt->windowCreate("end", -window => $b);
    }

    $b = $txt->Button
	(-text => "Show bindings",
	 -command => [$wd, 'show_bindings', $w]);
    $txt->windowCreate("end",
		       -window => $b,
		      );

}

sub show_bindings {
    my($wd, $w) = @_;
    my $t = $wd->Toplevel(-title => 'Bindings');
    my $ttxt = $t->Scrolled('ROText')->pack(-fill => 'both',
					    -expand => 1);
    _text_link_config($ttxt, sub { _bind_text_tag($_[0], $wd) } );
    foreach my $bindtag ($w->bindtags) {
	$ttxt->insert("end", "Bind tag: $bindtag\n\n");
	foreach my $bind ($w->Tk::bind($bindtag)) {
	    my $cb = $w->Tk::bind($bindtag, $bind);
	    my $label;
	    if (UNIVERSAL::isa($cb, 'ARRAY')) {
		$label = join ",", @$cb;
	    } else {
		$label = $cb;
	    }
	    $ttxt->insert("end", $bind . " => ");
	    $ttxt->insert("end", $label,
			  ["widgetlink",
			   "bind-" . $w . "|" . $bindtag . "|" . $bind]);
	    $ttxt->insert("end", "\n");
	}
	$ttxt->insert("end", "\n");
    }
}

sub show_binding_details {
    my($wd, $widget, $bindtag, $bind) = @_;
    my $t = $wd->Toplevel(-title => "Binding details");
    my $ttxt = $t->Scrolled("ROText")->pack(-fill => "both", -expand => 1);
    my $cb = $widget->Tk::bind($bindtag, $bind);
    $ttxt->insert("end", "Binding <$bind> for bindtag <$bindtag>:\n");
    require Data::Dumper;
    my $txt;
    my $dd = Data::Dumper->new([$cb],[]);
    if ($dd->can("Deparse")) {
	$txt = $dd->Deparse(1)->Useqq(1)->Dump;
    } else {
	$txt = "Sorry, your version of Data::Dumper is not capable to deparse the CODE reference.";
    }
    $ttxt->insert("end", $txt);
}

sub _show_widget {
    my($wd, $w) = @_;
    $wd->Flash($w);
    $wd->WidgetInfo($w);
}

sub see {
    my($wd, $w) = @_;
    my $tree = $wd->Subwidget("Tree");
    my $entry = ($tree->info("children"))[0];
    while (defined $entry and $entry ne "") {
	if ($tree->info("data", $entry) eq $w) {
	    $tree->see($entry);
	    return;
	}
	$entry = $tree->info("next", $entry);
    }
    warn "Widget $w not found in Widget tree\n";
}

sub _edit_config {
    my($wd, $w, $opt, $class) = @_;

    my $val;
    eval {
	$val = $w->cget($opt);
    };
    if ($@) {
	warn $@;
	return;
    }
    my $oldval = $val;

    my $t = $wd->Toplevel(-title => "Edit config");
    my $set_sub = sub {
	eval {
	    $w->configure($opt => $val);
	};
	warn $@ if $@;
    };
    $t->Label(-text => "Edit $opt for $w:")->pack(-side => "left");
    my $e;
    $e = eval 'Tk::WidgetDump::' . $class . '->entry($t, \$val, $set_sub)';
    #warn $@ if $@;
    if ($@) {
	$e = eval 'Tk::WidgetDump::Entry->entry($t, \$val, $set_sub)';
	warn $@ if $@;
    }
#XXX ja?
#     $t->Button(-text => "Undef and close",
# 	       -command => sub {
# 		   $val = undef;
# 		   $set_sub->();
# 		   $t->destroy;
# 	       }
# 	      )->pack(-side => "left");
    $t->Button(-text => "Close",
	       -command => [$t, 'destroy'],
	      )->pack(-side => "left");
    $e->focus if Tk::Exists($e);
    $t->bind("<Escape>" => [$t, 'destroy']);
}

sub method_call {
    my($wd, $w) = @_;

    my $t = $wd->Toplevel(-title => "Method call");
    my $f = $t->Frame->pack(-fill => "x");
    my $eval;
    $f->Label(-text => "Method call on $w")->pack(-side => "left");
    my $e = $f->_hist_entry({-textvariable => \$eval},
			    {-match => 1, -dup => 0})->pack(-side => "left");
    $e->focus;
    my $ww = $w;
    my $text;
    my $doit = sub {
	if ($e->can('historyAdd')) {
	    $e->historyAdd;
	}
	$ww = $ww; # XXX ???????
	my $cmd = '$ww->' . $eval;
	my(@res) = eval($cmd);
	require Data::Dumper;
	my $res = Data::Dumper->Dumpxs([\@res, $@],[$cmd, 'Error']) .
	          "\@res = <@res>\n";
	warn $res;
	$text->delete("1.0", "end");
	$text->insert("end", $res);
    };
    $e->bind("<Return>" => $doit);
    $f->Button(-text => "Execute!", -command => $doit)->pack(-side => "left");
    $f->Button(-text => "Close", -command => [$t, "destroy"])->pack(-side => "left");
    $text = $t->Scrolled("ROText", -scrollbars => "osoe",
			 -font => "courier 10", # XXX do not hardcode
			 -width => 40, -height => 5)->pack(-fill => "both", -expand => 1);
}

sub _text_link_config {
    my($txt, $code) = @_;
    $txt->tagConfigure(qw/widgetlink -underline 1/);
    $txt->tagConfigure(qw/hot        -foreground red/);
    $txt->tagBind(qw/widgetlink <ButtonRelease-1>/ => $code);
    $txt->{last_line} = '';
    $txt->tagBind(qw/widgetlink <Enter>/ => sub {
	my($text) = @_;
	my $e = $text->XEvent;
	my($x, $y) = ($e->x, $e->y);
	$txt->{last_line} = $text->index("\@$x,$y linestart");
	$text->tagAdd('hot', $txt->{last_line}, $txt->{last_line}." lineend");
	$text->configure(qw/-cursor hand2/);
    });
    $txt->tagBind(qw/widgetlink <Leave>/ => sub {
	my($text) = @_;
	$text->tagRemove(qw/hot 1.0 end/);
	$text->configure(qw/-cursor xterm/);
    });
    $txt->tagBind(qw/widgetlink <Motion>/ => sub {
	my($text) = @_;
	my $e = $text->XEvent;
	my($x, $y) = ($e->x, $e->y);
	my $new_line = $text->index("\@$x,$y linestart");
	if ($new_line ne $txt->{last_line}) {
	    $text->tagRemove(qw/hot 1.0 end/);
	    $txt->{last_line} = $new_line;
	    $text->tagAdd('hot', $txt->{last_line}, $txt->{last_line}." lineend");
	}
    });
    $txt->tagConfigure("title", -font => "Helvetica 10 bold"); # XXX do not hardcode!
}

sub canvas_config {
    my($wd, $c, $item) = @_;
    my $t = $wd->Toplevel(-title => "Canvas config of item $item");

    my $txt = $t->Scrolled("ROText",
			   -tabs => [map { (5*$_) . "c" } (1 .. 8)],
			   -scrollbars => "osow",
			   -wrap => "none",
			  )->pack(-fill => "both", -expand => 1);
    _text_link_config($txt, sub { _bind_text_tag($_[0], $wd) } );

    $txt->insert("end", "Canvas Item Configuration:\n\n", "title");
    $txt->insert("end", "Option\tDefault Value\tCurrent Value\n", "title");
    foreach my $cc ($c->itemconfigure($item)) {
	my @cc = @{$cc}[0,3,4];
	$txt->insert("end",
		     join("\t", map { !defined $_ ? "<undef>" : $_ } @cc),
		     ["widgetlink", "cconfig-" . $c . "-" . $item . $cc[0]],
		     "\n"
		    );
    }

    $txt->insert("end", "\nCoords\n",
		 ["widgetlink", "ccoords-" . $c . "-" . $item],
		 "\n"
		);

}

sub canvas_dump {
    my($wd, $c) = @_;
    my $t = $wd->Toplevel(-title => "Canvas dump of $c");
    require Tk::ROText;
    my $txt = $t->Scrolled("ROText", -scrollbars => "osow",
			   -tabs => [map { (3*$_) . "c" } (1 .. 3)],
			  )->pack(-fill => "both", -expand => 1);
    _text_link_config($txt, sub { _bind_text_tag($_[0], $wd) } );

    $txt->insert("end", "Canvas Dump\n\n", "title");
    $txt->insert("end", "Item number\tType\tTag list\n", "title");
    foreach my $i ($c->find("all")) {
	$txt->insert("end", "$i\t" . $c->type($i) . "\t[" .
		     join(",",$c->gettags($i)) . "]",
		     ["widgetlink", "c-" . $c . "-" . $i],
		     "\n");
    }

}

sub edit_canvas_config {
    my($wd, $c, $item, $opt) = @_;

    my $val;
    eval {
	$val = $c->itemcget($item, $opt);
    };
    if ($@) {
	warn $@;
	return;
    }
    my $oldval = $val;

    my $t = $wd->Toplevel(-title => "Edit canvas config");
    my $set_sub = sub {
	eval {
	    $c->itemconfigure($item, $opt => $val);
	};
	warn $@ if $@;
    };
    $t->Label(-text => "Edit $opt for canvas item $item:")->pack(-side => "left");
    my $e;
    $e = eval 'Tk::WidgetDump::Entry->entry($t, \$val, $set_sub)';
    warn $@ if $@;
    $e->focus if Tk::Exists($e);
    $t->bind("<Escape>" => [$t, 'destroy']);
#XXX ja?
#     $t->Button(-text => "Undef and close",
# 	       -command => sub {
# 		   $val = undef;
# 		   $set_sub->();
# 		   $t->destroy;
# 	       }
# 	      )->pack(-side => "left");
    $t->Button(-text => "Close", -command => [$t, "destroy"])->pack(-side => "left");
}

sub edit_canvas_coords {
    my($wd, $c, $item) = @_;

    my $val;
    eval {
	$val = join(",", $c->coords($item));
    };
    if ($@) {
	warn $@;
	return;
    }
    my $oldval = $val;

    my $t = $wd->Toplevel(-title => "Edit canvas coords");
    my $set_sub = sub {
	eval {
	    my @c = split(/,/, $val);
	    $c->coords($item, @c);
	};
	warn $@ if $@;
    };
    $t->Label(-text => "Edit coords for canvas item $item:")->pack(-side => "left");
    my $e;
    $e = eval 'Tk::WidgetDump::Entry->entry($t, \$val, $set_sub)';
    warn $@ if $@;
    $e->focus if Tk::Exists($e);
    $t->bind("<Escape>" => [$t, 'destroy']);
    $t->Button(-text => "Close", -command => [$t, "destroy"]);
}

sub _insert_wd {
    my($wd, $hl, $top, $par) = @_;
    my $i = 0;
    foreach my $cw ($top->children) {
	my $path = (defined $par ? $par . $hl->cget(-separator) : '') . $i;
	my($name, $class, $size, $ref);
	eval {
	    $name  = $cw->Name  || "No name";
	    $class = $cw->Class || "No class";
	    $size  = $cw->_WD_Size;
	    $ref   = ref($cw)   || "No ref";
	};
	warn $@ if $@;
	$hl->add($path, -text => $name, -data => $cw);
	$hl->itemCreate($path, 1, -text => $class);
	if ($cw->can('_WD_Characteristics')) {
	    my $char = $cw->_WD_Characteristics;
	    if (!defined $char) { $char = "???" }
	    $hl->itemCreate($path, 2, -text => $char);
	}
	$hl->itemCreate($path, 3, -text => $ref);
	#XXX$hl->itemCreate($path, 4, -text => $size);
	$wd->_insert_wd($hl, $cw, $path);
	#if ($cw->can('_WD_Children')) {
	#    $cw->_WD_Children;
	#}
	$i++;
    }
}

sub _delete_all {
    my($hl) = @_;
    $hl->delete("all");
}

sub _label_title {
    my $w = shift;
    if (defined $w->cget(-image) and 
	$w->cget(-image) ne "") {
	my $image = "(image)";
	eval {
	    my $i = $w->cget(-image);
	    if ($i->cget(-file) ne "") {
		$image = _crop(basename($i->cget(-file))) . " (image)";
	    }
	};
	$image;
    } elsif (defined $w->cget(-textvariable) and
	     $w->cget(-textvariable) ne "") {
	_crop($ { $w->cget(-textvariable) });
    } else {
	_crop($w->cget(-text));
    }
}

sub _crop {
    my $txt = shift;
    if (defined $txt && length($txt) > 30) {
	substr($txt, 0, 30) . "...";
    } else {
	$txt;
    }
}

sub _bind_text_tag {
    my($text, $wd) = @_;

    my $index = $text->index('current');
    my @tags = $text->tagNames($index);

    my $i = _lsearch('href\-.*', @tags);
    if ($i >= 0) {
	my($href) = $tags[$i] =~ /href-(.*)/;
	my $widget = $ref2widget{$href};
	$wd->_show_widget($widget);
	return;
    }

    $i = _lsearch('config\-.*', @tags);
    if ($i >= 0) {
	if ($tags[$i] =~ /^config-(.*)(-.*)-(.*)$/) {
	    my $w_name = $1;
	    my $opt = $2;
	    my $class = $3;
	    my $widget = $ref2widget{$w_name};
	    $wd->_edit_config($widget, $opt, $class);
	    return;
	}
    }

    $i = _lsearch('c\-.*', @tags);
    if ($i >= 0) {
	if ($tags[$i] =~ /^c-(.*)-(.*)$/) {
	    my $w_name = $1;
	    my $item = $2;
	    #my $canv_opt = $3;
	    my $widget = $ref2widget{$w_name};
	    $wd->canvas_config($widget, $item);
	    return;
	}
    }

    $i = _lsearch('cconfig\-.*', @tags);
    if ($i >= 0) {
	if ($tags[$i] =~ /^cconfig-(.*)-(.*)(-.*)$/) {
	    my $w_name = $1;
	    my $item = $2;
	    my $opt = $3;
	    my $widget = $ref2widget{$w_name};
	    $wd->edit_canvas_config($widget, $item, $opt);
	    return;
	}
    }

    $i = _lsearch('ccoords\-.*', @tags);
    if ($i >= 0) {
	if ($tags[$i] =~ /^ccoords-(.*)-(.*)$/) {
	    my $w_name = $1;
	    my $item = $2;
	    my $widget = $ref2widget{$w_name};
	    $wd->edit_canvas_coords($widget, $item);
	    return;
	}
    }

    $i = _lsearch('bind\-.*', @tags);
    if ($i >= 0) {
	if ($tags[$i] =~ /^bind-(.*)\|(.*)\|(.*)$/) {
	    my $w_name = $1;
	    my $bindtag = $2;
	    my $bind = $3;
	    my $widget = $ref2widget{$w_name};
	    $wd->show_binding_details($widget, $bindtag, $bind);
	    return;
	}
    }
    warn "Can't match $tags[$i]";
}

sub _get_widget_info_window {
    my $wd = shift;

    my $wi = $wd->Subwidget("WidgetInfo");

    if ($wi and Tk::Exists($wi)) {
	$wi->raise;
	return $wi;
    }

    $wi = $wd->Component(Toplevel => "WidgetInfo");
    $wi->title("Widget Info");
    if ($wi->screenwidth > 930 and
	$wi->screenheight > 450) {
	$wi->geometry("930x450");
    }

    require Tk::ROText;
    my $bf = $wi->Frame->pack(-fill => 'x', -side => "bottom");

    my $txt = $wi->Scrolled("ROText",
			    -tabs => [map { (5*$_) . "c" } (1 .. 8)],
			    -wrap => "none",
			   )->pack(-expand => 1, -fill => "both");
    _text_link_config($txt, sub { _bind_text_tag($_[0], $wd) } );

    $wi->Advertise("Information" => $txt);

    my $rb = $bf->Button(-text => "Refresh",
			-command => sub {
			    $wd->WidgetInfo($wd->{WidgetInfoWidget});
			})->pack(-side => "left");
    my $cb = $bf->Button(-text => "Close",
			-command => sub { $wi->destroy }
			)->pack(-side => "left");
    $wi->Advertise(Close => $cb);

    $wi;
}

sub _lsearch {

    # Search the list using the supplied regular expression and return it's
    # ordinal, or -1 if not found.

    my($regexp, @list) = @_;
    my($i);

    for ($i=0; $i<=$#list; $i++) {
        return $i if $list[$i] =~ /$regexp/;
    }
    return -1;

} # end lsearch

# XXX weitermachen
# die Idee: die gesamten Konfigurationsdaten aller Widgets per configure
# feststellen und als String schreiben. Und das für alle Children des
# Widgets. Zusätzlich die pack/grid/etc.-Information feststellen.
# Das alles gibt dann ein Perl-Programm. Parents bei der Rekursion merken.
# sub dump_as_perl {
#     my $top = shift;
    
# }

# sub dump_widget {
#     my $w = shift;
#     foreach $cdef ($w->configure) {
# #	if (defined $cdef->[4]) {
# #	    
#     }
# }

# REPO BEGIN
# REPO NAME _hist_entry /home/e/eserte/src/repository 
# REPO MD5 904022626019f774e4c0039cd8eecf78
sub Tk::Widget::_hist_entry {
    my($top, $entry_args, $hist_entry_args) = @_;
    my $Entry = "Entry";
    my @extra_args;
    eval {
	require Tk::HistEntry;
        Tk::HistEntry->VERSION(0.33);
	$Entry = "SimpleHistEntry";
	@extra_args = %$hist_entry_args;
    };
    $top->$Entry(%$entry_args);
}
# REPO END

package # hide from CPAN indexer
  Tk::Toplevel;
sub _WD_Characteristics {
    my $w = shift;
    Tk::WidgetDump::_crop($w->title) . " (" . $w->geometry . ")";
}

package # hide from CPAN indexer
  Tk::Label;
sub _WD_Characteristics {
    my $w = shift;
    Tk::WidgetDump::_label_title($w);
}

package # hide from CPAN indexer
  Tk::Button;
sub _WD_Characteristics {
    my $w = shift;
    Tk::WidgetDump::_label_title($w);
}

package # hide from CPAN indexer
  Tk::Menu;
sub _WD_Characteristics {
    my $w = shift;
    my $title = $w->cget(-title) || "(no title)";
    Tk::WidgetDump::_crop($title) . " (" . $w->cget("-type") . ")";
}

sub _WD_Children {
    my $w = shift;
    my $end = $w->index("end");
    for my $i (0 .. $end) {
	warn $w->type($i);
    }
}


package # hide from CPAN indexer
  Tk::Menubutton;
sub _WD_Characteristics {
    my $w = shift;
    Tk::WidgetDump::_label_title($w);
}

package # hide from CPAN indexer
  Tk::Listbox;
sub _WD_Characteristics {
    my $w = shift;
    my $first_elem = $w->get(0);
    if (defined $first_elem) {
        Tk::WidgetDump::_crop($first_elem) . " ...";
    } else {
	"";
    }
}

package # hide from CPAN indexer
  Tk::HList;
sub _WD_Characteristics {
    my $w = shift;
    my $res = "";
    eval {
	my($first_entry) = $w->info("children");
	$res = Tk::WidgetDump::_crop($w->itemCget($first_entry, 0, -text)) . " ...";
    };
    $res;
}

# XXX bei Refresh openlist merken und wiederherstellen

######################################################################

package Tk::WidgetDump::Entry;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $e = $p->_hist_entry({-textvariable => $valref},
			    {-match => 1, -dup => 0});
    $e->bind("<Return>" => sub {
	if ($e->can('historyAdd')) {
	    $e->historyAdd;
	}
	$set_sub->();
    });
    $e->pack(-side => "left");
}

package Tk::WidgetDump::BrowseEntry;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    require Tk::BrowseEntry;
    my $e = $p->BrowseEntry(-textvariable => $valref,
			    -browsecmd => $set_sub)->pack(-side => "left");

    $e->insert("end", $class->entries);
    $e->bind("<Return>" => $set_sub);
    $e;
}

package Tk::WidgetDump::_MyNumEntry;
eval {
    require Tk::NumEntry;
    @Tk::WidgetDump::_MyNumEntry::ISA = qw(Tk::NumEntry);
    Construct Tk::Widget '_MyNumEntry';
    sub Populate {
	my($w, $args) = @_;
	$w->SUPER::Populate($args);
	$w->ConfigSpecs(-setcmd => ['CALLBACK']);
    }
    sub incdec {
	my $w = shift;
	my $r = $w->Tk::NumEntry::incdec(@_);
	$w->Callback(-setcmd => $w);
	$r;
    }
};
warn $@ if $@;
$Tk::WidgetDump::_MyNumEntry::can_mynumentry = 1 unless $@;

package Tk::WidgetDump::NumEntry;
sub entry {
    eval {
	die "No NumEntry"
	    if !$Tk::WidgetDump::_MyNumEntry::can_mynumentry;
    };
    if ($@) {
	warn $@;
	shift->Tk::WidgetDump::Entry::entry(@_);
    } else {
	my($class, $p, $valref, $set_sub) = @_;
	my $e = $p->_MyNumEntry
	    (-textvariable => $valref,
	     -value => $$valref,
	     -setcmd => sub { $set_sub->() },
	     -command => sub { $set_sub->() }
	    )->pack(-side => "left");
	$e->bind("<Return>" => $set_sub);
	$e;
    }
}

package Tk::WidgetDump::Bool;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $e = $p->Checkbutton(-variable => $valref,
			    -onvalue => 1,
			    -offvalue => 0,
			    -command => $set_sub)->pack(-side => "left");

    $e->insert("end", $class->entries);
    $e->bind("<Return>" => $set_sub);
    $e;
}

package Tk::WidgetDump::Color;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    require Tk::BrowseEntry;
    my $e = $p->BrowseEntry(-textvariable => $valref,
			    -browsecmd => $set_sub)->pack(-side => "left");

    $e->insert("end", sort
	              keys %{+{
                        map { $_ =~ s/^\s+//; ((split(/\s+/, $_, 4))[3] => 1) }
                        split(/\n/, `showrgb`)
		      }}
	      );
    $e->bind("<Return>" => $set_sub);
    $e;
}

package Tk::WidgetDump::Background;
use base qw(Tk::WidgetDump::Color);

package Tk::WidgetDump::HighlightBackground;
use base qw(Tk::WidgetDump::Color);

package Tk::WidgetDump::HighlightColor;
use base qw(Tk::WidgetDump::Color);

package Tk::WidgetDump::Foreground;
use base qw(Tk::WidgetDump::Color);

package Tk::WidgetDump::Font;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $f = $p->Frame->pack(-side => "left");
    my $e = $p->Entry(-textvariable => $valref)->pack(-side => "left");
    $p->Button(-text => "Browse",
	       -command => sub {
		   if (!eval { require Tk::FontDialog; 1 }) {
		       $p->messageBox(-message => "Tk::FontDialog is not installed!");
		       return;
		   }
		   my $new_font = $f->FontDialog(-initfont => $$valref)->Show;
		   if (defined $new_font) {
		       $$valref = $new_font;
		       $set_sub->();
		   }
	       }
	      )->pack(-side => "left");
    $e->bind("<Return>" => $set_sub);
    $f;
}

package Tk::WidgetDump::Relief;
use base qw(Tk::WidgetDump::BrowseEntry);
sub entries { qw(raised sunken flat ridge solid groove) }

package Tk::WidgetDump::Anchor;
use base qw(Tk::WidgetDump::BrowseEntry);
sub entries { qw(center n ne e se s sw w nw) }

package Tk::WidgetDump::Justify;
use base qw(Tk::WidgetDump::BrowseEntry);
sub entries { qw(left center right) }

package Tk::WidgetDump::Cursor;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $f = $p->Frame->pack(-side => "left");
    require Tk::BrowseEntry;
    require Tk::Config;
    my $e = $p->BrowseEntry(-textvariable => $valref,
			    -browsecmd => $set_sub)->pack(-side => "left");
    (my $xinc = $Tk::Config::xinc) =~ s/^-I//;
    if (open(CF, "$xinc/X11/cursorfont.h")) {
	while(<CF>) {
	    chomp;
	    if (/#define\s+XC_(\S+)/) {
		$e->insert("end", $1);
	    }
	}
	close CF;
    } else {
	warn "Can't open cursorfont.h";
    }
    $p->Button(-text => "Bitmapfile",
	       -command => sub {
		   my $file = $f->getOpenFile;
		   if (defined $file) {
		       $$valref = ['@' . $file, "black"];
		       $set_sub->();
		   }
	       }
	      )->pack(-side => "left");
    $e->bind("<Return>" => $set_sub);
    $f;
}

$Tk::Config::xinc = $Tk::Config::xinc if 0; # peacify -w

package Tk::WidgetDump::Command;
use base qw(Tk::WidgetDump::Entry);

package Tk::WidgetDump::Image;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $f = $p->Frame->pack(-side => "left");
    my $e = $p->Entry(-textvariable => $valref)->pack(-side => "left");
    $p->Button(-text => "Browse",
	       -command => sub {
		   my $file = $f->getOpenFile;
		   if (defined $file) {
		       my $photo = $p->Photo(-file => $file);
		       # XXX image cache
		       if ($photo) {
			   $$valref = $photo;
			   $set_sub->();
		       }
		   }
	       }
	      )->pack(-side => "left");
    $e->bind("<Return>" => sub {
		 if ($$valref eq '') {
		     undef $$valref;
		 }
		 $set_sub->();
	     });
    $f;
}

package Tk::WidgetDump::Tile;
use base qw(Tk::WidgetDump::Image);

package Tk::WidgetDump::Bitmap;
sub entry {
    my($class, $p, $valref, $set_sub) = @_;
    my $f = $p->Frame->pack(-side => "left");
    my $e = $p->Entry(-textvariable => $valref)->pack(-side => "left");
    $p->Button(-text => "Browse",
	       -command => sub {
		   my $file = $f->getOpenFile;
		   if (defined $file) {
		       $$valref = '@' . $file;
		       $set_sub->();
		   }
	       }
	      )->pack(-side => "left");
    $e->bind("<Return>" => $set_sub);
    $f;
}

package Tk::WidgetDump::Pixels;
use base qw(Tk::WidgetDump::NumEntry);

package Tk::WidgetDump::BorderWidth;
use base qw(Tk::WidgetDump::Pixels);

package Tk::WidgetDump::Height;
use base qw(Tk::WidgetDump::Pixels);

package Tk::WidgetDump::Width;
use base qw(Tk::WidgetDump::Pixels);

package Tk::WidgetDump::HighlightThickness;
use base qw(Tk::WidgetDump::Pixels);

package Tk::WidgetDump::Pad;
use base qw(Tk::WidgetDump::Pixels);

package Tk::WidgetDump::Underline;
use base qw(Tk::WidgetDump::NumEntry);


return 1 if caller;

######################################################################

package main;

# self-test
my $top = MainWindow->new;
$top->Canvas->pack->createLine(0,0,100,100);
#$top->withdraw;
$top->WidgetDump;
$top->WidgetDump;
Tk::MainLoop;

__END__

=head1 NAME

Tk::WidgetDump - dump the widget hierarchie

=head1 SYNOPSIS

In a script:

    use Tk::WidgetDump;
    $mw = new MainWindow;
    $mw->WidgetDump;

From the command line for a quick widget option test:

    perl -MTk -MTk::WidgetDump -e '$mw=tkinit; $mw->Button->pack; $mw->WidgetDump; MainLoop'

=head1 DESCRIPTION

C<Tk::WidgetDump> helps in debugging Perl/Tk applications. By calling
the C<WidgetDump> method, a new toplevel with the widget hierarchie
will be displayed. The hierarchie can always be refreshed by the
B<Refresh> button (e.g. if new widgets are added after calling the
C<WidgetDump> method).

By double-clicking on a widget entry, the widget flashes and a new
toplevel is opened containing the configuration options of the widget.
It also displays other characteristics of the widget like children and
parent widgets, size, position, geometry management and server
parameters. Configuration values can also be changed on the fly.
Furthermore it is possible:

=over 4

=item *

to navigate to the children or parents

=item *

to call widget methods interactively

=item *

to display internal widget data with L<Tk::ObjScanner|Tk::ObjScanner>
(if available)

=back

If you want to call widget methods, you have to enter the method name
with arguments only, e.g. (for creating a line on a canvas):

     createLine(0,0,100,100)

Because C<WidgetDump> is a pseudo widget, it cannot be configured
itself.

=head1 BUGS

=over

=item * Changing configuration values

You have to hit <Return> to see the changes. The changes are not
reflected in the configuration window, you have to hit the "Refresh"
button.

=item * Tk::WidgetDump does not follow the conventions of a "real"
widget (ConfiSpecs etc.)

=item * The number of open windows may be confusing

=back

=head1 AUTHOR

Slaven Rezic (slaven@rezic.de)

=head1 SEE ALSO

Tk(3).

=cut
