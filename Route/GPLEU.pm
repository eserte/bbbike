# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Route::GPLEU;

use strict;
use warnings;
our $VERSION = '0.01';

use Exporter 'import';
our @EXPORT = qw(gple_to_gpleu gpleu_to_gple);

sub gple_to_gpleu ($) {
    my $s = shift;
    $s =~ tr/?@[\\]^`{|}~/0123456789-/;
    $s;
}

sub gpleu_to_gple ($) {
    my $s = shift;
    $s =~ tr/0123456789-/?@[\\]^`{|}~/;
    $s;
}

1;

__END__
