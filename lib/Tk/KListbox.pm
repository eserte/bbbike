# -*- perl -*-

#
# $Id: KListbox.pm,v 1.4 1999/07/08 22:26:17 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::KListbox;
use Tk qw(Ev);
use Tk::Listbox;
use strict;
use locale;
use vars qw(@ISA $VERSION);

@ISA = qw(Tk::Derived Tk::Listbox);
$VERSION = '0.02';

Construct Tk::Widget 'KListbox';

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);
#    $w->ConfigSpecs(-cache => ['METHOD', 'cache', 'Cache', 0]);
    $w;
}

sub ClassInit {
    my($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    
    $mw->bind($class,"<KeyPress>", ['KeyPress',Ev('A')]);

    $class;
}

sub KeyPress {
    my($w, $key) = @_;
    $w->{'_ILAccel'} .= $key;
    $w->Goto($w->{'_ILAccel'});
    eval {
	$w->{'_ILAccel_afterid'}->cancel;
    };
    $w->{'_ILAccel_afterid'} = $w->after(500, ['Reset', $w]);
}

sub Goto {
    my($w, $text) = @_;
    return if (not defined $text or $text eq '');
    my $start = (length($text) == 1 ? 0 : $w->index('active'));
    $text = lc($text);
    $start = $w->{'_cache'}{$text} if (exists $w->{'_cache'}{$text});
    my $theIndex;
    my $less = 0;
    my $len = length($text);
    my $i = $start;
    # Search forward until we find a filename whose prefix is an exact match
    # with $text
    while (1) {
	my $sub = lc(substr($w->get($i), 0, $len));
	if ($text eq $sub) {
	    $theIndex = $i;
	    last;
	}
	++$i;
	$i = 0 if ($i == $w->index('end'));
	last if ($i == $start);
    }
    if (defined $theIndex) {
	$w->activate($theIndex);
#	$w->selectionSet($theIndex);
	$w->see($theIndex);
    }
}

sub Reset {
    my $w = shift;
    undef $w->{'_ILAccel'};
}

sub Cache {
    my($w, $v) = @_;
    $w->{'_cache'} = {};
    if ($v) {
	my $last = $w->index('end');
	for(my $i = 0; $i <= $last; $i++) {
	    for(my $j = 1; $j <= $v; $j++) {
		my $s = $w->get($i);
		next unless defined $s and $s ne '';
		my $beg = lc(substr($s, 0, $j));
		if (!exists $w->{'_cache'}{$beg}) {
		    $w->{'_cache'}{$beg} = $i;
		}
	    }
	}
    }
}

1;
