#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use FindBin;
my $doitlibdir;
BEGIN { $doitlibdir = "$ENV{HOME}/src/Doit/lib" }
use lib $doitlibdir;
use Doit;
use File::Glob 'bsd_glob';

my @copy_components = ();

my $d = Doit->init;
my $destdir = "$FindBin::RealBin/../lib";
$d->copy("$doitlibdir/Doit.pm", "$destdir");
if (@copy_components) {
    $d->mkdir("$destdir/Doit");
    for my $component (@copy_components) {
	$d->copy("$doitlibdir/Doit/$component.pm", "$destdir/Doit");
    }
}

__END__
