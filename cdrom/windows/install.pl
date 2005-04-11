#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: install.pl,v 1.1 1999/12/12 13:48:35 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1999 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

use FindBin;
use File::NCopy;
use File::Path;

use strict;

my $destdir = "C:/BBBike";

if ($^O ne 'MSWin32') {
    die "Installation program only for windows!";
}

my $fc = new File::NCopy
  'recursive' => 1,
  'force_write' => 1,
  ;

mkpath([$destdir], 1, 0755);
if (!-d $destdir) {
    die "Can't create $destdir: $!";
}

$fc->copy("$FindBin::RealBin/BBBike", $destdir);
$fc->copy("$FindBin::RealBin/windows", $destdir);
$fc->copy("$FindBin::RealBin/bbbike.bat", $destdir);

__END__
