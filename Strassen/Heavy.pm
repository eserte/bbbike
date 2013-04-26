# -*- perl -*-

#
# $Id: Heavy.pm,v 1.3 2003/01/08 20:14:46 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

package Strassen::Heavy;

BEGIN {
    if (!defined &main::mymstat) {
	eval q{
	    package main; # AUTOLOAD: ignore
	    sub mymstat { 1 }
	};
	warn $@ if $@;
    }
}

use strict;
BEGIN {
    eval 'use FindBin;
          use lib ("$FindBin::RealBin/lib");
         ';
}

BEGIN { main::mymstat("vor Strassen::Util") if defined &main::mymstat }
use Strassen::Util;
BEGIN { main::mymstat("vor Strassen::Core") if defined &main::mymstat }
use Strassen::Core;
BEGIN { main::mymstat("vor Strassen::Fast") if defined &main::mymstat }
use Strassen::Fast;
BEGIN { main::mymstat("vor Strassen::Strasse") if defined &main::mymstat }
use Strassen::Strasse;
BEGIN { main::mymstat("vor Strassen::Kreuzungen") if defined &main::mymstat }
use Strassen::Kreuzungen;
BEGIN { main::mymstat("vor Strassen::MultiStrassen") if defined &main::mymstat }
use Strassen::MultiStrassen;
BEGIN { main::mymstat("vor Strassen::StrassenNetz") if defined &main::mymstat }
use Strassen::StrassenNetz;
BEGIN { main::mymstat("Ende von Strassen::Heavy") if defined &main::mymstat }

1;

__END__
