# -*- perl -*-

#
# $Id: Geography.pm,v 1.3 2000/03/17 01:47:44 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Geography;

sub new {
    my($class, $city, $country, @args) = @_;
    my $pkg = 'Geography::' . ucfirst(lc($city)) . '_' . uc($country);
    my $obj = eval 'use ' . $pkg . '; ' . $pkg . '->new(@args)';
    $obj;
}

# XXX smarter? look at existing data directories?
sub default {
    Geography::new("Berlin", "DE");
}

1;

__END__
