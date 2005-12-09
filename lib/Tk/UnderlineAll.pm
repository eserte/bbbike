# -*- perl -*-

#
# $Id: UnderlineAll.pm,v 1.16 2005/12/08 23:17:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright © 1997,2001,2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::UnderlineAll;

package
    Tk::Widget;
use strict;
use vars qw($VERSION);

$VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

Tk::UnderlineAll - automatically add accelerator keys to widgets

=head1 SYNOPSIS

    use Tk::UnderlineAll;
    $frame->UnderlineAll(...);

=head1 DESCRIPTION

The B<Tk::UnderlineAll> module adds a method B<UnderlineAll> to the
L<Tk::Widget> class. This method automatically adds accelarator keys
to menu buttons, menu entries and notebook pages, optionally also to
buttons, checkbuttons and radiobuttons.

=head2 OPTIONS

B<UnderlineAll> takes the following options:

=over

=item -menu => I<$boolean>

Turn on or off menu and menubutton handling. Defaults to true.

=item -notebook => I<$boolean>

Turn on or off notebook tab handling. Defaults to true.

=item -button => I<$boolean>

Turn on or off button handling. Defaults to false. Note that buttons
are all instances of L<Tk::Button> and its subclasses ---
L<Tk::Checkbutton> and L<Tk::Radiobutton> are also subclasses of
L<Tk::Button>!

=item -radiobutton =>  I<$boolean>

Turn on or off radiobutton handling. Defaults to false.

=item -checkbutton =>  I<$boolean>

Turn on or off checkbutton handling. Defaults to false.

=item -override => I<$boolean>

Override previosly defined C<-underline> settings. Defaults to false.

=item -donotuse => I<$arrayref>

An array reference of characters which should not be used in the
underlining process.

=back

=head1 BUGS

C<-override> only checks for widgets, which are actually used in
UnderlineAll. So C<-underline> options e.g. in Label widgets are
ignored. Also C<-underline> options in Menu widgets are ignored. Use
the C<-donotuse> option as a workaround.

=head1 SEE ALSO

L<Tk::Menu>, L<Tk::Button>, L<Tk::Widget>, L<Tk::autobind> (which
seems to implement a subset of Tk::UnderlineAll's capabilities).

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 1997,2001,2005 Slaven Rezic. All rights reserved. This
module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

sub UnderlineAll {
    my $widget = shift;
    my %args = @_;

    my(@menu, @menubutton, @notebookpage, @buttons);
    my $sub = \&Tk::UnderlineAll::findUnderlineExt;

    # collect all relevant children
    my @c;
    push @c, $widget;
    if ($widget->can('Descendants')) {
	push @c, $widget->Descendants;
    }

    my $do_menu = delete $args{-menu};
    if (!defined $do_menu) { $do_menu = 1 }
    my $do_notebook = delete $args{-notebook};
    if (!defined $do_notebook) { $do_notebook = 1 }
    my $do_button = delete $args{-button} || 0;
    if (exists $args{-buttons}) {
	$do_button = delete $args{-buttons}; # backwards compatibility
    }
    my $do_checkbutton = delete $args{-checkbutton} || 0;
    my $do_radiobutton = delete $args{-radiobutton} || 0;
    if ($args{-donotuse}) {
	my %do_not_use = map {(lc($_),1)} @{ $args{-donotuse} };
	$args{-donotuse} = \%do_not_use;
    }

    my $c;
    foreach $c (@c) {
	if ($do_menu && $c->isa('Tk::Menu')) {
	    push @menu, $c;
	} elsif ($do_menu && $c->isa('Tk::Menubutton')) {
	    push @menubutton, [$c, $c->cget(-text)];
	} elsif ($do_notebook && $c->isa('Tk::NoteBook')) {
	    push @notebookpage, $c;
	} elsif ($do_button && $c->isa('Tk::Button')) {
	    push @buttons, [$c, $c->cget(-text)];
	} elsif ($do_radiobutton && $c->isa('Tk::Radiobutton')) {
	    push @buttons, [$c, $c->cget(-text)];
	} elsif ($do_checkbutton && $c->isa('Tk::Checkbutton')) {
	    push @buttons, [$c, $c->cget(-text)];
	}
    }

    if (@buttons) {
	&$sub(\@buttons, %args);
	my $b;
	foreach $b (@buttons) {
	    if (defined $b->[2]) {
		$b->[0]->configure(-underline => $b->[2]);
		$widget->toplevel->bind
		    ("<Alt-Key-" . lc(substr($b->[1], $b->[2], 1)) . ">"
		     => sub { $b->[0]->invoke });
	    }
	}
    }

    if (@menubutton) {
	&$sub(\@menubutton, %args);
	my $mb;
	foreach $mb (@menubutton) {
	    $mb->[0]->configure(-underline => $mb->[2]) if defined $mb->[2];
	    my $menu = $mb->[0]->cget('-menu');
	    push @menu, $menu if defined $menu;
	}
    }

    if (@menu) {
	my %menu_seen;
	my $menu;
	foreach $menu (@menu) {
	    unless ($menu_seen{$menu}) {
		Tk::UnderlineAll::doMenu($menu, $sub);
		$menu_seen{$menu}++;
	    }
	}
    }

    if (@notebookpage) {
	my $nb;
	foreach $nb (@notebookpage) {
	    my $pg;
	    my @pages;
	    foreach $pg (@{$nb->{'windows'}}) {
		push(@pages, [$pg, $nb->pagecget($pg, '-label')]);
	    }
	    &$sub(\@pages, %args);
	    if ($Tk::VERSION >= 400.204) {
		my $pge;
		foreach $pge (@pages) {
		    $nb->pageconfigure($pge->[0], -underline => $pge->[2])
			if defined $pge->[2];
		}
	    }
	}
    }
}

package Tk::UnderlineAll;

sub doMenu {
    my($menu, $sub) = @_;
    my @menuentry;
    my $i;
    my $last = $menu->index('last');
    if ($last ne "none") {
	for $i (0 .. $last) {
	    my $menu_type = $menu->type($i);
	    if (defined $menu_type &&
		$menu_type ne 'separator' &&
		$menu_type ne 'tearoff') {
		push(@menuentry, [$i, $menu->entrycget($i, '-label')]);
		if ($menu_type eq 'cascade') {
		    doMenu($menu->entrycget($i, '-menu'), $sub);
		}
	    }
	}
    }
    &$sub(\@menuentry);
    my $me;
    foreach $me (@menuentry) {
	$menu->entryconfigure($me->[0], -underline => $me->[2])
	  if defined $me->[2];
    }
}

sub findUnderlineSimple {
    my $arr = shift;
    my %args = @_;

    my %charUsed;
    my $o;
    foreach $o (@$arr) {
	my $i;
	for $i (0 .. length($o->[1])-1) {
	    my $ch = lc(substr($o->[1], $i, 1));
	    if (!exists $charUsed{$ch}) {
		$o->[2] = $i;
		$charUsed{$ch}++;
		last;
	    }
	}
    }
    $arr;
}

sub findUnderlineExt {
    my $arr_ref = shift;
    my %args = @_;

    my %charUsed;
    if ($args{-donotuse}) {
	%charUsed = %{ $args{-donotuse} };
    }

    my @arr = @$arr_ref;
    if (!$args{-override}) {
 	my $i2 = 0;
 	for(my $i=0; $i<=$#arr; $i++) {
 	    my $b = $arr[$i];
 	    eval { # cget(-underline) does not work with menu items...
 		my $und = $b->[0]->cget(-underline);
 		if ($und > -1) {
 		    $charUsed{substr($b->[1], $und, 1)}++;
 		    splice @arr, $i, 1;
 		    $arr_ref->[$i2]->[2] = $und;
 		    $i--;
 		}
 	    };
 	    $i2++;
 	}
    }

    my $i;
    my @wordIndex = (0 .. $#arr);
    my @chIndex = (0 .. $#arr);
    my $tryword = 0;
    my $ss;
    while (@wordIndex) {
	$ss = q{\W*} . q{\w+\W+} x $tryword;
	for($i=0; $i <= $#wordIndex; $i++) {
	    if ($arr[$wordIndex[$i]]->[1] !~ /^($ss)(.)/) {
		splice(@wordIndex, $i, 1);
		$i--;
	    } else {
		my $ch = lc($2);
		my $len = length($1);
		if (!exists $charUsed{$ch} && $ch =~ /\w/) {
		    $arr[$wordIndex[$i]]->[2] = $len;
		    $charUsed{$ch}++;
		    splice(@wordIndex, $i, 1);
		    splice(@chIndex, $i, 1);
		    $i--;
		}
	    }
	}
	$tryword++;
    }

    my $trychar = 0;
    while (@chIndex) {
	for($i=0; $i <= $#chIndex; $i++) {
	    if (length($arr[$chIndex[$i]]->[1]) <= $trychar) {
		splice(@chIndex, $i, 1);
		$i--;
	    } else {
		my $ch = lc(substr($arr[$chIndex[$i]]->[1], $trychar, 1));
		if (!exists $charUsed{$ch} && $ch =~ /\w/) {
		    $arr[$chIndex[$i]]->[2] = $trychar;
		    $charUsed{$ch}++;
		    splice(@chIndex, $i, 1);
		    $i--;
		}
	    }
	}
	$trychar++;
    }

    \@arr;
}

1;
