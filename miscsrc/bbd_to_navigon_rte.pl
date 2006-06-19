#!/usr/bin/perl
# -*- perl -*-

#
# $Id: bbd_to_navigon_rte.pl,v 1.1 2006/06/19 19:45:47 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Converts a bbd points route (as created by "Simulate upload to Garmin",
# the /tmp/gpsdump-points.bbd file) to navigon rte file

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
use Karte::Standard;
use Karte::Polar;
use Strassen::Core;

my $file = shift || die "bbd file?";

my $s = Strassen->new($file);
$s->init;
while(1) {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };
    die "Can handle only point bbd files" if @{ $r->[Strassen::COORDS] } != 1;
    my $plz1 = undef;
    my $ort = "Berlin"; # should be variable!
    my $plz2 = undef;
    my $street = $r->[Strassen::NAME];
    my($x,$y) = split /,/, $r->[Strassen::COORDS]->[0];
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($x,$y));
    no warnings 'uninitialized';
    my @out = (undef,undef,undef,$plz1,$ort,$plz2,$street,undef,undef,undef,$lon,$lat,undef);
    @out = map { !defined $_ ? "-" : $_ } @out;
    print join("|", @out), "\n";
}

__END__
