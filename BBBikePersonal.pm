# -*- perl -*-

#
# $Id: BBBikePersonal.pm,v 1.4 2003/01/06 02:44:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
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

sub filename {
    "$main::bbbike_configdir/personal.bbd";
}

sub str_object {
    my $force = shift;
    return $p if $p && !$force;

    my $personal = filename();
    $p = eval { Strassen->new($personal) };
    if (!$p) {
	main::status_message(Mfmt("Die Datei <%s> konnte nicht geladen werden: $@", $personal), "info");
	$p = Strassen->new();
    }
    $p;
}

sub dialog {
    str_object(1);
    main::choose_ort("p","personal",
		     -data => $p,
		     -nodraw => 1,
		     -additionalframe => \&buttonframe,
		     -ondestroy => \&cleanup,
		     -rebuild => 1,
		    );
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
    $container->Button(-text => M("Löschen"),
		       -command => [\&del, $toplevel])->pack(-fill => "x");
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
    my($sel) = $lb->curselection;
    if (!defined $sel) {
	main::status_message(M("Keine Auswahl"),"err");
	return;
    }
    $lb->get($sel);
}

sub set_map_mode_customchoose {
    $oldmode = $main::map_mode
	unless $main::map_mode eq main::MM_CUSTOMCHOOSE();
    $main::map_mode = main::MM_CUSTOMCHOOSE();
    $main::c->configure(-cursor => "hand2");
    main::status_message("Punkt auswählen", "info");
}

sub choose {
    my($c,$e) = @_;
    my($x, $y) = ($c->canvasx($e->x), $c->canvasy($e->y));
    my($tx,$ty) = main::anti_transpose($x,$y);
    main::set_map_mode($oldmode) if defined $oldmode;
    undef $oldmode;
    main::status_message("", "info");
    ($tx,$ty);
}

sub get_name {
    my($t, $oldname) = @_;
    my $te = $t->Toplevel(-title => "Name");
    $te->transient($t);
    $te->Label(-text => "Name:")->pack(-side => "left");
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
    $p->push([$name, [$coords], $cat]);
    $p->write(filename());
    dialog();
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
    my($oldname, $newname, $newpoint, $delete) = @_;
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
		$p->set_current([$newname,$newpoint,$r->[Strassen::CAT]]);
	    }
	    $p->write(filename());
	    dialog();
	    return 1;
	}
    }
    main::status_message(Mfmt("Konnte <%s> nicht in der persönlichen Datei finden", $oldname), "err");
    0;
}

1;

__END__
