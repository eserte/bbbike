#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use Test::More;
	use XML::LibXML;
	1;
    }) {
	print "1..0 # skip no Test::More and/or XML::LibXML modules\n";
	exit;
    }
}

use FindBin;
use lib $FindBin::RealBin;

use BBBikeTest qw(gpxlint_string);
use File::Temp qw(tempfile);

plan tests => 11;

use_ok 'GPS::GpsmanData';

{
    my $wpt_sample_file = <<'EOF';
% Written by GPSManager 31-Jul-2010 16:54:01 (CET)
% Edit at your own risk!

!Format: DMS 2 WGS 84
!Creation: no

!W:
Friedrichstad1	26-JUL-10 11:37:07	N54 22 23.2	E9 05 41.9	symbol=user:7703	GD110:dtyp=|c"	GD110:class=|c!	GD110:colour=|c@	GD110:attrs=|C!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=|c!!!!	GD110:cat=|c!!
LaTrattoria	26-JUL-10 14:44:48	N54 22 33.8	E9 05 16.4	symbol=pizza	GD110:dtyp=|c"	GD110:class=|c!	GD110:colour=|c@	GD110:attrs=|C!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=|c!!!!	GD110:cat=|c!!
EOF
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".wpt", UNLINK => 1)
	or die $!;
    print $tmpfh $wpt_sample_file
	or die $!;
    close $tmpfh
	or die $!;

    { # non-multi test
	my $gps = GPS::GpsmanData->new;
	isa_ok($gps, "GPS::GpsmanData");
	$gps->load($tmpfile);
	pass "Loaded gpsman data";
    }

    my $gps = GPS::GpsmanMultiData->new;
    isa_ok($gps, "GPS::GpsmanMultiData");
    $gps->load($tmpfile);
    my $gpx = $gps->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);

    my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
    $root->setNamespaceDeclURI(undef, undef);
    like($root->findvalue('/gpx/wpt/@lat'), qr{54\.37311}, 'Found a latitude');
    like($root->findvalue('/gpx/wpt/@lon'), qr{9\.094972}, 'Found a longitude');
    like($root->findvalue('/gpx/wpt/name'), qr{Friedrichstad1}, 'Found a wpt name');
    like($root->findvalue('/gpx/wpt/time'), qr{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z}, 'Found a wpt time');
    like($root->findvalue('/gpx/wpt/cmt'), qr{Punkt}, 'Found a user-def symbol name')
	or diag "Please check the mapping in the bike2008 directory";
    like($root->findvalue('/gpx/wpt/cmt'), qr{Pizza}, 'Found an official symbol name');
}

__END__
