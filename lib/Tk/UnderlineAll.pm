# -*- perl -*-

#
# $Id: UnderlineAll.pm,v 1.11 2001/08/26 11:26:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright © 1997,2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

package Tk::UnderlineAll;

package
    Tk::Widget;
use strict;
use vars qw($VERSION);

$VERSION = '0.04';

=head2 UnderlineAll

    use Tk::UnderlineAll;
    $frame->UnderlineAll;

Add automatically assigned accelarators to menu buttons, menu entries and
notebook pages.

=head2 TODO

    - add options: -sub (findUnderlineExt or findUnderlineSimple)
                   -menu     => 1
                   -notebook => 1
                   -button   => 0
                   -override => 0 (previously set -underline)

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

    my $c;
    foreach $c (@c) {
	if ($c->isa('Tk::Menu')) {
	    push @menu, $c;
	} elsif ($c->isa('Tk::Menubutton')) {
	    push @menubutton, [$c, $c->cget(-text)];
	} elsif ($c->isa('Tk::NoteBook')) {
	    push @notebookpage, $c;
	} elsif ($c->isa('Tk::Button')) {
	    push @buttons, [$c, $c->cget(-text)];
	}
    }

    if ($args{-buttons}) {
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

    &$sub(\@menubutton, %args);
    my $mb;
    foreach $mb (@menubutton) {
	$mb->[0]->configure(-underline => $mb->[2]) if defined $mb->[2];
	my $menu = $mb->[0]->cget('-menu');
	push @menu, $menu if defined $menu;
    }

    my %menu_seen;
    my $menu;
    foreach $menu (@menu) {
	unless ($menu_seen{$menu}) {
	    Tk::UnderlineAll::doMenu($menu, $sub);
	    $menu_seen{$menu}++;
	}
    }

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

package Tk::UnderlineAll;

sub doMenu {
    my($menu, $sub) = @_;
    my @menuentry;
    my $i;
    # XXX gibt warnings wenn -tearoff => 0 spezifiert ist
    for $i (0 .. $menu->index('last')) {
	if ($menu->type($i) ne 'separator' &&
	    $menu->type($i) ne 'tearoff') {
	    push(@menuentry, [$i, $menu->entrycget($i, '-label')]);
	    if ($menu->type($i) eq 'cascade') {
		doMenu($menu->entrycget($i, '-menu'), $sub);
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
