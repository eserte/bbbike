#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: e00_to_bbd.pl,v 1.1 2004/03/10 21:52:29 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2002 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven.rezic@berlin.de
# WWW:  http://www.rezic.de/eserte/
#

# parse places from e00 files and convert to bbd

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use Karte;
use Getopt::Long;

my %opt = (cat => "3");
if (!GetOptions(\%opt, "cat=s")) {
    die "usage!";
}

Karte::preload(qw(Standard Polar));

# search first empty line
while(<>) {
    /^$/ && last;
}

while(!eof(STDIN)) {
    $_ = <>;
    last if /^\s+-1/;
    scalar <> for (2..10);
    $_ = <>;
    chomp;
    s/^\s+//;
    my($long,$lat) = map { $_+0 } split /\s+/;
    chomp(my $name = <>);
    print "$name\t$opt{cat} ", join(",", map { int } $Karte::Polar::obj->map2standard($long,$lat)), "\n";
}

__END__
