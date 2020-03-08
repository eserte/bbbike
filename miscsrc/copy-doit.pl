#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2020 Slaven Rezic. All rights reserved.
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

my @copy_components = qw(Brew File Git Lwp);

my $d = Doit->init;
my $bbbike_rootdir = "$FindBin::RealBin/..";
my $destdir = "$bbbike_rootdir/lib";
$d->copy("$doitlibdir/Doit.pm", "$destdir");
if (@copy_components) {
    $d->mkdir("$destdir/Doit");
    my $updates;
    for my $component (@copy_components) {
	$updates++ if $d->copy("$doitlibdir/Doit/$component.pm", "$destdir/Doit");
	$d->change_file("$bbbike_rootdir/MANIFEST",
			{add_if_missing => "lib/Doit/$component.pm",
			 add_after => '^lib/Doit\.pm$',
			},
		       );
    }
    if ($updates) {
	$d->system('prove', "$bbbike_rootdir/t/basic.t");
    }
}

__END__
