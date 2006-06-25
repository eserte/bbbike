#!/usr/bin/perl
# -*- perl -*-

#
# $Id: bbd_to_navigon_rte.pl,v 1.3 2006/06/25 18:05:46 eserte Exp $
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
use Getopt::Long;
use Karte::Standard;
use Karte::Polar;
use Strassen::Core;

sub usage () {
    die "usage: $0 [-fmt new|old] [-includestreetnames] [-q] bbdfile
";
}

my $fmt = "new";
my $include_streetnames = 0; # unknown or different written street names are not recognized by navigon...
my $q;
GetOptions("fmt=s" => \$fmt,
	   "includestreetnames" => \$include_streetnames,
	   "q" => \$q,)
    or usage;
my $file = shift || usage;

my $s = Strassen->new($file);
$s->init;
while(1) {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };
    if (@{ $r->[Strassen::COORDS] } != 1) {
	warn "Ignore non-point record in bbd file.\n" if !$q;
	next;
    }
    my $plz1 = undef;
    my $ort = "Berlin"; # should be variable!
    my $plz2 = undef;
    my $street = $include_streetnames ? $r->[Strassen::NAME] : undef;
    my($x,$y) = split /,/, $r->[Strassen::COORDS]->[0];
    my($lon, $lat) = $Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($x,$y));
    no warnings 'uninitialized';
    my @out;
    if ($fmt eq 'new') {
	@out = (undef,undef,undef,undef,$plz1,$ort,$plz2,$street,undef,undef,undef,$lon,$lat,undef,undef,undef,undef);
    } elsif ($fmt eq 'old') {
	@out = (undef,undef,undef,$plz1,$ort,$plz2,$street,undef,undef,undef,$lon,$lat,undef);
    } else {
	usage();
    }
    @out = map { !defined $_ ? "-" : $_ } @out;
    print join("|", @out);
    if ($fmt eq 'new') {
	print "|";
    }
    print "\n";
}

__END__
