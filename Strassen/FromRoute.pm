# -*- perl -*-

#
# $Id: FromRoute.pm,v 1.3 2005/07/26 19:30:42 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::FromRoute;

=head1 NAME

Strassen::FromRoute - support for any format Route.pm can handle

=cut

use strict;
use vars qw(@ISA);

require Strassen::Core;
require Route;
require Route::Heavy;

@ISA = 'Strassen';

sub new {
    my($class, $filename, %args) = @_;

    my $name = $args{name};
    if ($args{usebasename}) {
	($name) = fileparse($filename, "\\..+\$");
    }
    my $cat = $args{cat};
    my $str = Route::as_strassen($filename, name => $name, fuzzy => 1);
    if (!$str) {
	die "Die Datei <$filename> enthält keine Route."
    }
    $str;
}

1;
