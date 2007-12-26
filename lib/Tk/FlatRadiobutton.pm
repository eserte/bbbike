# -*- perl -*-

#
# $Id: FlatRadiobutton.pm,v 1.3 2007/10/19 20:55:49 eserte Exp $
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

$VERSION = '0.07';

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

=head1 NAME

Tk::FlatRadiobutton - an alternative radiobutton implementation for perl/Tk

=head1 SYNOPSIS

    use Tk::FlatRadiobutton;
    $mw->FlatRadiobutton->pack;

=head1 DESCRIPTION

B<Tk::FlatRadiobutton> is an alternative radiobutton implementation.
Please refer to the L<Tk::FlatCheckbox> documentation for a list of
valid options.

=head1 SEE ALSO

L<Tk::FlatCheckbox>, L<Tk::Radiobutton>

=head1 AUTHOR

Slaven ReziE<0x107> <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2001,2007 Slaven ReziE<0x107>. All rights reserved.
This module is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
