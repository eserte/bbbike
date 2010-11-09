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

plan tests => 21;

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

{
    my $trk_sample_file = <<'EOF';
% Written by GPSManager 13-Jul-2004 18:19:37 (CET)
% Edit at your own risk!

!Format: DMS 2 WGS 84
!Creation: no

!T:	ACTIVE LOG	width=2	colour=#8b0000	GD312:display=|c"	srt:vehicle=pedes
	13-Jul-2004 10:59:43	N52 31 55.2	E13 27 47.7	~13.1151123047
	13-Jul-2004 11:00:00	N52 31 54.7	E13 27 46.6	~13.1151123047
!T:	ACTIVE LOG 12	srt:vehicle=u-bahn
	13-Jul-2004 11:19:07	N52 30 46.3	E13 31 57.2	15.9990234375
	13-Jul-2004 11:19:23	N52 30 49.6	E13 32 10.1	15.5184326172
!TS:
EOF

    my $gps = GPS::GpsmanMultiData->new;
    $gps->parse($trk_sample_file);

    is(scalar @{ $gps->Chunks }, 3, 'Expected number of chunks');

    is($gps->Chunks->[0]->TrackAttrs->{'srt:vehicle'}, 'pedes', 'Expected attribute');
    is($gps->Chunks->[1]->TrackAttrs->{'srt:vehicle'}, 'u-bahn', 'Expected attribute in 2nd chunk');

    my @flat_wpt = $gps->flat_track;
    is(scalar(@flat_wpt), 4, 'Found four wpts in track');
    is($flat_wpt[0]->Latitude, 52.532, 'Expected first latitude');
    like($flat_wpt[-1]->Latitude, qr{^52.5137}, 'Expected last latitude');

    my $gpx = $gps->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);
}

{
    my $rte_sample_file = <<'EOF';
% Written by GPSManager 07-Nov-2010 12:14:27 (CET)
% Edit at your own risk!

!Format: DMS 1 WGS 84
!Creation: no

!R:	Seume -  Ebe		width=2	colour=#48C1BC	mapbak=
Seumestr.		N52 30 37.4	E13 27 45.1	symbol=dot	GD110:dtyp=|c"	GD110:class=|C$	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c!!/~d8|c!~r|_k|c!!"!!!|C#|c6!!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!	GD110:addr=|c!
!RS:			GD210:class=|c$!
Eberhard-Roters-Platz		N52 29 10.1	E13 22 57.7	symbol=dot	GD110:dtyp=|c"	GD110:class=|C$	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c!!/~d8|c!~|Zj|c$!"!!!|C>|c(!!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!	GD110:addr=|c!

EOF
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => '.rte', UNLINK => 1)
	or die $!;
    print $tmpfh $rte_sample_file
	or die $!;
    close $tmpfh
	or die $!;

    my $gps = GPS::GpsmanData->new;
    $gps->load($tmpfile);
    pass 'Loaded gpsman route file';

    is scalar @{ $gps->Track }, 2;
}

{
    # parts taken from BBBikeGPS::GpsmanRoute
    my $gd = GPS::GpsmanData->new;
    $gd->change_position_format("DDD");
    $gd->Type(GPS::GpsmanData::TYPE_ROUTE());
    $gd->Name('Test route');
    for my $wpt (
		 { ident => "wpt1", lat => 52.5, lon => 13.5},
		 { ident => "wpt2", lat => 52.6, lon => 13.6},
		) {
	my $gpsman_wpt = GPS::Gpsman::Waypoint->new;
	$gpsman_wpt->Ident($wpt->{ident});
	$gpsman_wpt->Latitude($wpt->{lat});
	$gpsman_wpt->Longitude($wpt->{lon});
	my $symbol = 'small_city';
	$gpsman_wpt->Symbol($symbol);
	$gpsman_wpt->HiddenAttributes({'GD110:class'=>'|C$'}); # XXX setting waypoint class to 0x80 (map point waypoint)
							       # XXX There should be better support in Gps::GpsmanData for this
	$gd->push_waypoint($gpsman_wpt);
    }
    my $gpsman_rte = $gd->as_string;
    $gpsman_rte =~ s{^% Written by .*\[GPS::GpsmanData\]\n}{}; # normalize
    my $expected = <<'EOF';

!Format: DMS 0 WGS 84
!Creation: no

!R:	Test route
wpt1		N52 30 00.0	E13 30 00.0	symbol=small_city	GD110:class=|C$
wpt2		N52 36 00.0	E13 35 59.9	symbol=small_city	GD110:class=|C$
EOF
    is $gpsman_rte, $expected;
}


__END__
