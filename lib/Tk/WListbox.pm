# -*- perl -*-

#
# $Id: WListbox.pm,v 1.3 1998/09/23 22:25:06 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1997 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::WListbox;
use Tk::Listbox;
use strict;
use locale;
use vars qw(@ISA $VERSION);

import Tk qw(Ev);

@ISA = qw(Tk::Derived Tk::Listbox);
$VERSION = '0.02';

Construct Tk::Widget 'WListbox';

sub Populate {
    my($w, $args) = @_;
    $w->SUPER::Populate($args);
    $w->ConfigSpecs(-overwrap => ['PASSIVE', 'overwrap', 'Overwrap', 1]);
    $w;
}

sub ClassInit {
    my($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);
    
    $mw->bind($class,"<KeyPress>", ['AdvanceKey',Ev('A')]);

    $class;
}

sub AdvanceKey {
    my($w, $ch) = @_;
    $ch = lc($ch);
#warn $ch;
    return unless $ch =~ /[\040-\177\200-\377]/; # only printables
    my $begin = $w->index('active');
    if (!defined $begin) {
	$begin = 0;
    } else {
	$begin++;
    }
    my $end = $w->index('end') - 1;
    my $i = $begin;
    #  first check without Busy
    if ($i <= $end and lc(substr($w->get($i), 0, 1)) eq $ch) {
	$w->activate($i);
	$w->see($i);
	return;
    }
    $w->Busy;
    my $overwrap = ($begin != 0 && $w->cget(-overwrap));
#warn "i:$i begin:$begin end:$end $overwrap:$overwrap";
  LOOP:
    while (1) {
	while($i <= $end) {
#warn $i;
#warn lc(substr($w->get($i), 0, 1)). " eq " .lc($ch);
	    if (lc(substr($w->get($i), 0, 1)) eq $ch) {
		$w->activate($i);
		$w->see($i);
#warn "got it";
		last LOOP;
	    }
	    $i++;
	}
	if ($overwrap) {
	    $overwrap = 0;
	    $i = 0;
	    $end = $begin;
	} else {
	    $w->bell;
	    last LOOP;
	}
    }
    $w->Unbusy;
}

1;

