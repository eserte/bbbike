# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2002,2006,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package GPS::Util;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = '1.05';

use Exporter 'import';

@EXPORT = qw(eliminate_umlauts);

use BBBikeUtil qw();

sub eliminate_umlauts {
    my $s = shift;
    $s = BBBikeUtil::umlauts_for_german_locale($s);
    $s =~ s/[\200-\377]/_/g; # Ignore everything else. Maybe I should
                             # use Text::Unidecode if available?
    $s;
}

1;

__END__
