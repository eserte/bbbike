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

use strict;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use Cwd qw(realpath);
use File::Basename qw(basename);
use Getopt::Long;

use BBBikeYAML 'DumpFile', 'LoadFile';

GetOptions(
	   "destdir=s" => \my $destdir,
	   "q|quiet"   => \my $quiet,
	  )
    or die "usage: $0 [--quiet] --destdir directory yamlfile ...\n";

if (!$destdir) {
    die "Please specify --destdir for generated summary files.\n";
}

for my $f (@ARGV) {
    my $dest = "$destdir/" . basename($f);
    next if -s $dest && -M $dest < -M $f;
    unless ($quiet) { warn "$dest\n" }
    if (-e $dest && realpath($f) eq realpath($dest)) {
	die "Source ($f) and destination ($dest) are the same file --- usage error?\n";
    }
    my $d = LoadFile($f);
    for (qw(bbox chunk_stats per_vehicle_stats route tag)) {
	delete $d->{$_}
    }
    DumpFile "$dest~", $d;
    rename "$dest~", $dest
	or die "Error renaming $dest~ to $dest: $!";
}

__END__
