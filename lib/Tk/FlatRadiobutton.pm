# -*- perl -*-

#
# $Id: FlatRadiobutton.pm,v 1.1 2007/10/13 21:36:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::FlatRadiobutton;
use base qw(Tk::FlatCheckbox);
Tk::FlatCheckbox->VERSION(0.05);

use strict;
use vars qw($VERSION @ISA);
Construct Tk::Widget 'FlatRadiobutton';

$VERSION = '0.06';

sub Populate {
    my($w,$args) = @_;

    if ($args->{-offvalue}) {
	die "-offvalue is not allowed in " . __PACKAGE__;
    }
    if ($args->{-onvalue}) {
	warn "-onvalue should not be used, but rather -value";
    }

    $w->SUPER::Populate($args);

    $w->ConfigSpecs(-value => '-onvalue');
}

sub invoke {
    my $w = shift;
    return if $w->{Configure}{'state'};
    $w->SUPER::invoke(@_);
}

1;

__END__
