# -*- perl -*-

#
# $Id: BBBikePersonal.pm,v 1.7 2006/09/23 20:32:28 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2006,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package BBBikePersonal;
use strict;
use vars qw($oldmode $p);

use Strassen;

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

use vars qw($show_places $can_toggle_flag);

if (!defined $can_toggle_flag) {
    $can_toggle_flag = $main::advanced ? 1 : 0;
}

sub filename {
    "$main::bbbike_configdir/personal.bbd";
}

sub str_object {
    my $force = shift;
    return $p if $p && !$force;

    my $personal = filename();
    $p = eval { Strassen->new($personal) };
    if (!$p) {
	# Expected for first time. And we never know if it's the first time.
	main::status_message(Mfmt("Die Datei <%s> konnte nicht geladen werden: $@", $personal), "info");
	$p = Strassen->new();
    }
    $p;
}

sub dialog {
    my(%args) = @_;
    my $see = delete $args{-see};
    str_object(1);
    my $linetype = "p";
    my $type = "personal";
    my $container = $main::toplevel{"chooseort-$type-$linetype"};
    if (Tk::Exists($container)) {
	$_->destroy for ($container->children);
	delete $main::toplevel{"chooseort-$type-$linetype"}; # XXX hacky...
    } else {
	undef $container;
    }
    main::choose_ort($linetype, $type,
		     -data => $p,
		     -nodraw => 1,
		     -additionalframe => \&buttonframe,
		     -ondestroy => \&cleanup,
		     -rebuild => 1,
		     -container => $container,
		     -popup => $container ? 0 : 1,
		     ($can_toggle_flag ?
		      (-splitter => sub {
			   my(undef, $inx) = @_;
			   my $r = $p->get($inx);
			   ($r->[Strassen::NAME], $r->[Strassen::CAT]);
		       }
		      ) : ()
		     ),
		     ($see ? (-see => $see) : ()),
		    );
    if ($container) {
	$main::toplevel{"chooseort-$type-$linetype"} = $container; # XXX hacky...
    }

    # XXX why $p gets deleted in choose_ort???
    $p = str_object();
}

sub buttonframe {
    my($toplevel, $container) = @_;
    $container->Button(-text => M("Hinzufügen"),
		       -command => [\&add, $toplevel])->pack(-fill => "x");
    $container->Button(-text => M("Namen ändern"),
		       -command => [\&change_name, $toplevel])->pack(-fill => "x");
    $container->Button(-text => M("Punkt ändern"),
		       -command => [\&change_point, $toplevel])->pack(-fill => "x");
    if ($can_toggle_flag) {
	$container->Button(-text => M("Flag umschalten"), # XXX en translation missing
			   -command => [\&toggle_flag, $toplevel])->pack(-fill => "x");
    }
    $container->Button(-text => M("Löschen"),
		       -command => [\&del, $toplevel])->pack(-fill => "x");
    $show_places = 0;
    $container->Checkbutton(-text => M("Alle zeigen"),
			    -command => \&toggle_show,
			    -variable => \$show_places,
			   )->pack(-fill => "x");
}

sub add {
    my $t = shift;

    set_map_mode_customchoose();

    $main::customchoosecmd = sub {
	my($tx,$ty) = choose(@_);
	my $name = get_name($t);
	return if !defined $name || $name eq '';
	add_file($name, "X", "$tx,$ty");
    };
}

sub change_name {
    my $t = shift;
    my $oldname = get_current_name($t);
    return if !defined $oldname;
    my $newname = get_name($t, $oldname);
    return if ($newname eq $oldname);
    return if !defined $newname || $newname eq '';
    change_file_name($oldname, $newname);
}

sub change_point {
    my $t = shift;
    my $oldname = get_current_name($t);
    return if !defined $oldname;

    set_map_mode_customchoose();

    $main::customchoosecmd = sub {
	my($tx,$ty) = choose(@_);
	change_file_point($oldname, "$tx,$ty");
    };

}

sub toggle_flag {
    my $t = shift;
    my $oldname = get_current_name($t);
    return if !defined $oldname;
    my $oldcat = get_current_cat($t);
    return if !defined $oldcat;
    my $newcat = $oldcat eq 'X' ? 'X:GPS' : 'X';
    change_file($oldname, undef, undef, undef, $newcat);
}

sub del {
    my $t = shift;
    my $oldname = get_current_name($t);
    return if !defined $oldname;

    return unless
	$t->messageBox(-message => Mfmt("Den Eintrag <%s> wirklich löschen?", $oldname),
		       -type => "YesNo") =~ /yes/i; # XXX language!
    delete_file_name($oldname);
}

sub _lb { shift->Subwidget("Listbox") }

sub get_current_name {
    my $t = shift;
    my $lb = _lb($t);
    if ($lb->isa('Tk::HList')) {
	my $lb_index = $lb->info('anchor');
	if (!defined $lb_index) {
	    main::status_message(M("Keine Auswahl"),"err");
	    return;
	}
	$lb->itemCget($lb_index, 0, '-text');
    } else {
	my($sel) = $lb->curselection;
	if (!defined $sel) {
	    main::status_message(M("Keine Auswahl"),"err");
	    return;
	}
	$lb->get($sel);
    }
}

sub get_current_cat {
    my $t = shift;
    my $lb = _lb($t);
    if ($lb->isa('Tk::HList')) {
	my $lb_index = $lb->info('anchor');
	if (!defined $lb_index) {
	    main::status_message(M("Keine Auswahl"),"err");
	    return;
	}
	$lb->itemCget($lb_index, 1, '-text');
    } else {
	# XXX not implemented in Listbox/non-splitter mode
	undef;
    }
}

sub set_map_mode_customchoose {
    $oldmode = $main::map_mode
	unless $main::map_mode eq main::MM_CUSTOMCHOOSE();
    $main::map_mode = main::MM_CUSTOMCHOOSE();
    $main::c->configure(-cursor => "hand2");
    main::status_message(M"Punkt auswählen", "infoauto");
}

sub choose {
    my($c,$e) = @_;
    my($x, $y) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my($tx,$ty) = main::anti_transpose($x,$y);
    main::set_map_mode($oldmode) if defined $oldmode;
    undef $oldmode;
    #main::status_message("", "info");
    main::info_auto_popdown();
    ($tx,$ty);
}

sub get_name {
    my($t, $oldname) = @_;
    my $te = $t->Toplevel(-title => M"Name");
    $te->transient($t);
    $te->Label(-text => M("Name").":")->pack(-side => "left");
    my $e = $te->Entry(-textvariable => \$oldname)->pack(-side => "left");
    $e->focus;
    my $wait = 0;
    $e->bind("<Return>" => sub { $wait = 1 });
    $e->bind("<Escape>" => sub { $wait = -1 });
    $te->OnDestroy(sub { $wait = -1 });
    $te->waitVariable(\$wait);
    $te->destroy if Tk::Exists($te);
    return undef if ($oldname eq '');
    if (has_duplicate($oldname)) {
	$t->messageBox(-message => Mfmt("Der Name <%s> existiert bereits", $oldname));
	return undef;
    }
    if ($wait) {
	$oldname;
    } else {
	undef;
    }
}

sub has_duplicate {
    my $name = shift;
    $p->init;
    while(1) {
	my $r = $p->next;
	last if !@{$r->[Strassen::COORDS]};
	if ($name eq $r->[Strassen::NAME]) {
	    return 1;
	}
    }
    0;
}

sub cleanup {
    my $t = shift;
    $t->destroy if Tk::Exists($t);
    if (defined $oldmode) {
	main::set_map_mode($oldmode);
	undef $oldmode;
    }
    undef $p;
}

sub add_file {
    my($name, $cat, $coords) = @_;
    maybe_upgrade_encoding($name);
    $p->push([$name, [$coords], $cat]);
    $p->write(filename());
    dialog(-see => $name);
}

sub change_file_point {
    my($oldname, $newpoint) = @_;
    change_file($oldname, undef, $newpoint);
}

sub change_file_name {
    my($oldname, $newname) = @_;
    change_file($oldname, $newname, undef);
}

sub delete_file_name {
    my $oldname = shift;
    change_file($oldname, undef, undef, 1);
}

sub change_file {
    my($oldname, $newname, $newpoint, $delete, $newcat) = @_;
    maybe_upgrade_encoding($newname);
    $p->init;
    while(1) {
	my $r = $p->next;
	last if !@{$r->[Strassen::COORDS]};
	if ($r->[Strassen::NAME] eq $oldname) {
	    if ($delete) {
		$p->delete_current;
	    } else {
		$newpoint = join(" ",@{$r->[Strassen::COORDS]})
		    unless defined $newpoint;
		$newname = $oldname
		    unless defined $newname;
		$newcat = $r->[Strassen::CAT]
		    unless defined $newcat;
		$p->set_current([$newname,$newpoint,$newcat]);
	    }
	    $p->write(filename());
	    dialog(-see => $newname);
	    return 1;
	}
    }
    main::status_message(Mfmt("Konnte <%s> nicht in der persönlichen Datei finden", $oldname), "err");
    0;
}

sub toggle_show {
    if ($show_places) {
	require BBBikeAdvanced;
	main::custom_draw("p", "personal", filename(),
			  -namedraw => 1, -close => 0,
			  -nooverlaplabel => 1);
    } else {
	main::plot('p', "personal", -draw => 0);
    }
}

sub maybe_upgrade_encoding {
    my($newname) = @_;
    return if !defined $newname;
    if ($newname =~ m{[^\0-\xff]} && ($p->get_global_directive('encoding')||'') ne 'utf-8') {
	my $glob_dir = $p->get_global_directives;
	$glob_dir->{encoding} = ['utf-8'];
	$p->set_global_directives($glob_dir);
    }
}

1;

__END__
