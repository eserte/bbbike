#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: mps_reader.pl,v 1.4 2005/02/25 01:52:30 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use GPS::MPS;
use File::Basename;
use Getopt::Long;

my $destdir = "/tmp";
my $force;

if (!GetOptions("destdir=s" => \$destdir,
		"force!" => \$force,
		"d!" => \$GPS::MPS::DEBUG,
	       )) {
    die "usage!";
}

for my $f (@ARGV) {
    my $dest = "$destdir/" . (fileparse($f, '\..+'))[0] . ".trk";
    if (-e $dest && !$force) {
	warn "$dest exists, skipping...\n";
	next;
    }
    warn "Convert $f => $dest...\n";
    open(F, $f) or die $!;
    my $out = GPS::MPS->convert_to_gpsman(\*F);
    close F;

    open(X, ">$dest") or die $!;
    print X $out;
    close X;
}

__END__
