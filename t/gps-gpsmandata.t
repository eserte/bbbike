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
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use BBBikeTest qw(gpxlint_string eq_or_diff);
use File::Temp qw(tempfile);

plan tests => 60;

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

    {
	ok GPS::GpsmanData->check($tmpfile), 'check test for GPS.pm';
    }

    { # non-multi test
	my $gps = GPS::GpsmanData->new;
	isa_ok($gps, "GPS::GpsmanData");
	$gps->load($tmpfile);
	pass "Loaded gpsman data";

	my $wpts_before = wpts_to_string($gps);
	$gps->sort_waypoints_by_time;
	my $wpts_after = wpts_to_string($gps);
	is $wpts_after, $wpts_before, 'No change after sorting (waypoints already sorted by time)';
    }

    {
	my $gps = GPS::GpsmanMultiData->new;
	isa_ok($gps, "GPS::GpsmanMultiData");
	$gps->load($tmpfile);

	{
	    my $gpx = $gps->as_gpx(autoskipcmt => 0); # preserve comments
	    gpxlint_string($gpx);

	    my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
	    $root->setNamespaceDeclURI(undef, undef);
	    is($root->findvalue('/gpx/wpt[1]/cmt'), q{26-JUL-10 11:37:07}, 'Found first comment');
	    is($root->findvalue('/gpx/wpt[2]/cmt'), q{26-JUL-10 14:44:48}, 'Found second comment');
	}

	{
	    my $gpx = $gps->as_gpx; # autoskipcmt => 1, does not preserve date comments
	    gpxlint_string($gpx);

	    my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
	    $root->setNamespaceDeclURI(undef, undef);
	    isnt($root->findvalue('/gpx/wpt[1]/cmt'), q{26-JUL-10 11:37:07}, 'Did not find datetime-like comment');
	    is($root->findvalue('/gpx/wpt[1]/time'), q{2010-07-26T09:37:07Z}, '... but time is still set');
	    isnt($root->findvalue('/gpx/wpt[2]/cmt'), q{26-JUL-10 14:44:48}, 'Also did not find second comment');
	    is($root->findvalue('/gpx/wpt[2]/time'), q{2010-07-26T12:44:48Z}, '... but time is still set');
	}
    }

    {
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
}

{
    # Same data as before, but waypoints are not sorted by time here
    my $wpt_sample_file = <<'EOF';
% Written by GPSManager 31-Jul-2010 16:54:01 (CET)
% Edit at your own risk!

!Format: DMS 2 WGS 84
!Creation: no

!W:
LaTrattoria	26-JUL-10 14:44:48	N54 22 33.8	E9 05 16.4	symbol=pizza	GD110:dtyp=|c"	GD110:class=|c!	GD110:colour=|c@	GD110:attrs=|C!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=|c!!!!	GD110:cat=|c!!
Friedrichstad1	26-JUL-10 11:37:07	N54 22 23.2	E9 05 41.9	symbol=user:7703	GD110:dtyp=|c"	GD110:class=|c!	GD110:colour=|c@	GD110:attrs=|C!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=|c!!!!	GD110:cat=|c!!
EOF
    my($tmpfh,$tmpfile) = tempfile(SUFFIX => ".wpt", UNLINK => 1)
	or die $!;
    print $tmpfh $wpt_sample_file
	or die $!;
    close $tmpfh
	or die $!;

    my $gps = GPS::GpsmanData->new;
    $gps->load($tmpfile);
    my $wpts_before = wpts_to_string($gps);

    my @sorted_wpts = $gps->get_sorted_waypoints_by_time;
    is join(",", map { $_->Ident } @sorted_wpts), 'Friedrichstad1,LaTrattoria', 'Sort without changing GPS object';

    $gps->sort_waypoints_by_time;
    my $wpts_after = wpts_to_string($gps);
    isnt $wpts_after, $wpts_before, 'Changed object after sorting (waypoints now sorted by time)';

    is $wpts_after, 'Friedrichstad1,LaTrattoria', 'New sorting';
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
    is($gps->Chunks->[0]->Name, 'ACTIVE LOG', 'Expected first track name');
    is($gps->Chunks->[1]->TrackAttrs->{'srt:vehicle'}, 'u-bahn', 'Expected attribute in 2nd chunk');
    is($gps->Chunks->[1]->Name, 'ACTIVE LOG 12', 'Expected track name in 2nd chunk');

    my @flat_wpt = $gps->flat_track;
    is(scalar(@flat_wpt), 4, 'Found four wpts in track');
    is($flat_wpt[0]->Latitude, 52.532, 'Expected first latitude');
    like($flat_wpt[-1]->Latitude, qr{^52.5137}, 'Expected last latitude');

    my $gpx = $gps->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);

    {
	my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
	$root->setNamespaceDeclURI(undef, undef);
	is($root->findvalue('/gpx/trk[1]/name'), q{ACTIVE LOG}, 'Found 1st name');
	is($root->findvalue('/gpx/trk[2]/name'), q{ACTIVE LOG 12}, 'Found 2nd name');
    }

    {
	my($tmpfh,$tmpfile) = tempfile(UNLINK => 1, SUFFIX => '.trk')
	    or die $!;
	print $tmpfh $trk_sample_file;
	close $tmpfh or die $!;

	my @route = GPS::GpsmanMultiData->convert_to_route($tmpfile);
	is scalar(@route), 4, 'Found four points in track/route';
	is join(",", @{ $route[0] }), '14379,14107', 'expected first coordinate';
    }
}

{
    # track sample with DDD
    my $trk_sample_file = <<'EOF';
% Written by /home/e/eserte/src/bbbike/bbbike Wed Dec 28 19:10:26 2005
% Edit at your own risk!

!Format: DDD 1 WGS 84
!Creation: yes

!T:	TRACK
	31-Dec-1989 01:00:00	N53.0945536138593	E12.8748931621168	0
	31-Dec-1989 01:00:00	N53.0943054383567	E12.8761002946735	0
!T:	TRACK
	31-Dec-1989 01:00:00	N53.0940612438672	E12.877531259314	0
	31-Dec-1989 01:00:00	N53.0933655007711	E12.8813741665033	0
EOF

    my $gps = GPS::GpsmanMultiData->new;
    $gps->parse($trk_sample_file);

    is(scalar @{ $gps->Chunks }, 2, 'Expected number of chunks');

    is($gps->Chunks->[0]->Points->[0]->Latitude, 53.0945536138593, 'Expected first latitude');
    is($gps->Chunks->[0]->Points->[0]->Longitude, 12.8748931621168, 'Expected first longitude');

    is($gps->Chunks->[-1]->Points->[-1]->Latitude, 53.0933655007711, 'Expected last latitude');
    is($gps->Chunks->[-1]->Points->[-1]->Longitude, 12.8813741665033, 'Expected last longitude');

    my $gpx = $gps->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);

    {
	my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
	$root->setNamespaceDeclURI(undef, undef);
	is($root->findvalue('/gpx/trk[1]/name'), q{TRACK}, 'Found 1st name');
	is($root->findvalue('/gpx/trk[1]/trkseg/trkpt[1]/@lat'), 53.0945536138593, 'First latitude in gpx');
	is($root->findvalue('/gpx/trk[1]/trkseg/trkpt[1]/@lon'), 12.8748931621168, 'First longitude in gpx');
	is($root->findvalue('/gpx/trk[2]/name'), q{TRACK}, 'Found 2nd name');
	is($root->findvalue('/gpx/trk[2]/trkseg/trkpt[2]/@lat'), 53.0933655007711, 'Last latitude in gpx');
	is($root->findvalue('/gpx/trk[2]/trkseg/trkpt[2]/@lon'), 12.8813741665033, 'Last longitude in gpx');
    }

    {
	local $TODO = "Should create a DDD file again";
	my $trk_written = $gps->as_string;
	eq_or_diff $trk_written, $trk_sample_file, 'Roundtrip';
    }
}

{
    my $rte_sample_file = <<'EOF';
% Written by GPSManager 07-Nov-2010 12:14:27 (CET)
% Edit at your own risk!

!Format: DMS 1 WGS 84
!Creation: no

!R:	Seume -  Ebe		width=2	colour=#48C1BC	mapbak=
Seumestr.		N52 30 37.4	E13 27 45.1	symbol=dot	GD110:dtyp=|c"	GD110:class=|C$	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c!!/~d8|c!~r|_k|c!!"!!!|C#|c6!!	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|R$|Z	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!	GD110:addr=|c!
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

    my $gps_multi = GPS::GpsmanMultiData->new;
    $gps_multi->load($tmpfile);
    my $gpx = $gps_multi->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);

    {
	my $root = XML::LibXML->new->parse_string($gpx)->documentElement;
	$root->setNamespaceDeclURI(undef, undef);
	is($root->findvalue('/gpx/rte[1]/name'), q{Seume -  Ebe}, 'Found 1st name in route');
    }
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
    $gpsman_rte =~ s{^% Written by .*\[GPS::GpsmanData\].*\n}{}; # normalize
    my $expected = <<'EOF';

!Format: DMS 0 WGS 84
!Creation: no

!R:	Test route
wpt1		N52 30 00.0	E13 30 00.0	symbol=small_city	GD110:class=|C$
wpt2		N52 36 00.0	E13 35 59.9	symbol=small_city	GD110:class=|C$
EOF
    is $gpsman_rte, $expected;
}

{
    my $rte_sample_file = <<'EOF';
% Written by GPSManager 02-Jun-2012 12:25:01 (CET)
% Edit at your own risk!

!Format: DMS 2 WGS 84
!Creation: no

!R:	frzbhlzost 33		width=2	colour=#48C1BC	mapbak=
Neue Grunstr.		N52 30 38.6	E13 24 21.3	symbol=dot	GD110:dtyp=|c"	GD110:class=|C"	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c|R%!|C!|c!~p|Z|Z|c$|_%|c*!|_IWy|C)	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|Z|Z|c!!	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!
!RS:			GD210:class=|c$!
WP-000000297		N52 30 40.5	E13 24 21.2	symbol=dot	GD110:dtyp=|c"	GD110:class=|C"	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c|R%!|C!|c"~p|Z|Z|c$|_%|c*!|_aWw|C)	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|Z|Z|c!!	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!
!NB:	Original name: 
Original name: WP-000000000

!RS:			GD210:class=|c$!
<- -Fischerinsel)		N52 30 42.6	E13 24 20.7	symbol=dot	GD110:dtyp=|c"	GD110:class=|C"	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c|R%!|C!|c!~p|Z|Z|c$|_%|c*!|_||Wq|C)	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|Z|Z|c!!	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!
!RS:			GD210:class=|c$!
Fischerinsel [Woh ->		N52 30 44.2	E13 24 18.5	symbol=dot	GD110:dtyp=|c"	GD110:class=|C"	GD110:colour=|c@	GD110:attrs=|C!	GD110:subclass=|c|R%!|C!|c!~p|Z|Z|c$|_%|c*!|C2|_WT|C)	GD110:depth=QY|c%|_i	GD110:state=|cAA	GD110:country=|cAA	GD110:ete=~|Z|Z|c!!	GD110:temp=QY|c%|_i	GD110:time=~|R$|Z	GD110:cat=|c!!
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

    is scalar @{ $gps->Track }, 4;

    my $gps_multi = GPS::GpsmanMultiData->new;
    $gps_multi->load($tmpfile);
    my $gpx = $gps_multi->as_gpx(symtocmt => 1);
    gpxlint_string($gpx);
}

{
    # track + waypoint
    my $gpsman_sample_file = <<'EOF';
!Format: DMS 0 WGS 84
!Creation: no

!T:	1. Dessau-Wittenberg
	12-Aug-2013 08:54:33	N51 50 24.7	E12 14 01.3	67.9
	12-Aug-2013 08:54:39	N51 50 24.5	E12 14 01.2	68.4
!W:
Bauhaus Dessau		N51 50 20.8	E12 13 36.3
EOF
    my $gps = GPS::GpsmanMultiData->new;
    $gps->parse($gpsman_sample_file);
    my @track = $gps->flat_track;
    is scalar @track, 2, 'Found two waypoints in track (waypoints ignored)';
}

sub wpts_to_string {
    my $gps = shift;
    join(",", map { $_->Ident } @{ $gps->Waypoints });
}

__END__
