# -*- perl -*-

#
# $Id: Util.pm,v 1.4 2007/03/31 20:03:12 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package GPS::Util;

use strict;
use vars qw($VERSION @EXPORT);
$VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw(Exporter);

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
