# -*- perl -*-

#
# $Id: $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Tk::TextProgress;
use vars qw($VERSION);
use strict;

$VERSION = '0.01';

sub new       { bless {}, $_[0] }
sub InitGroup { }
sub Init      { $_[0]->Update(0) }

sub Update {
    my($w, $frac, %args) = @_;
    $frac = 0 unless defined $frac;
    print STDERR int($frac*100) . "%    \r";
}

sub UpdateFloat { print STDERR "*" }
sub Finish      { print STDERR "\r".(" "x79)."\r" }
sub FinishGroup { }

1;

__END__
