#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mklsm.pl,v 1.2 2001/12/09 21:04:58 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2000 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use lib "$FindBin::RealBin/..";
use MetaPort;

my(@l) = localtime((stat($bbbike_archiv_path))[9]);
my $date = sprintf("%04d-%02d-%02d", $l[5]+1900, $l[4]+1, $l[3]);

print <<EOF;
Begin4
Title:          BBBike
Version:        $bbbike_version
Entered-date:   $date
Description:    An information system for bicyclists in Berlin and Brandenburg.
		With BBBike it is possible to search routes between two
		points. The routes are presented on maps of Berlin and
		Brandenburg.
Keywords:       bicycle bike information system route planner map
Author:         eserte\@cs.tu-berlin.de (Slaven Rezic)
Maintained-by:  eserte\@cs.tu-berlin.de (Slaven Rezic)
Primary-site:   http://pub.cs.tu-berlin.de/src/BBBike/$bbbike_archiv
Original-site:  http://pub.cs.tu-berlin.de/src/BBBike/$bbbike_archiv
Platforms:      FreeBSD/Linux/Unix/Windows (Perl/Tk is required)
Copying-policy: Artistic or GPL
End
EOF

__END__
