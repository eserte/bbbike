# -*- perl -*-

#
# $Id: SportsTracker.pm,v 1.1 2009/01/13 22:06:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Support for XML files produced by Nokia Sports Tracker

package GPS::GpsmanData::SportsTracker;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use XML::LibXML::Reader;

use GPS::GpsmanData;

sub match {
    my($class, $file) = @_;
    my $reader = $class->open_reader($file);
    $reader->nextElement == 1 && $reader->name eq 'workout';
}

sub open_reader {
    my($class, $file) = @_;
    if ($file =~ m{\.gz$}) {
	require IO::Zlib;
	my $fh = IO::Zlib->new;
	$fh->open($file, "rb")
	    or die "Can't open gzipped file '$file': $!";
	XML::LibXML::Reader->new(IO => $fh);
    } else {
	XML::LibXML::Reader->new(location => $file);
    }
}

sub load {
    my($class, $file, %args) = @_;

    my $reader = $class->open_reader($file);
    my $gpsman = GPS::GpsmanMultiData->new;

    # XXX duplicated from ::Any
    my %number_to_monthabbrev = do {
	my %m2n = ('Jan' => 1,
		   'Feb' => 2,
		   'Mar' => 3,
		   'Apr' => 4,
		   'May' => 5,
		   'Jun' => 6,
		   'Jul' => 7,
		   'Aug' => 8,
		   'Sep' => 9,
		   'Oct' => 10,
		   'Nov' => 11,
		   'Dec' => 12,
		  );
	reverse %m2n;
    };

    # XXX nearly duplicated from ::Any (but without T)
    my $gpsman_time_to_time = sub {
	my $time = shift;
	my($Y,$M,$D,$h,$m,$s,$ms,$tz) = $time =~ m{^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\.\d+)?Z?$};
	if (!defined $Y) {
	    die "Cannot parse time <$time>";
	}
	if (defined $ms) {
	    $s += "0".$ms;
	}
	# XXX timezone?!
	my $gpsman_time = sprintf "%02d-%s-%04d %02d:%02d:%02d", $D, $number_to_monthabbrev{$M+0}, $Y, $h, $m, $s;
    };

    my @gps_fix_lost;

 PARSE: {
	$reader->nextElement("activity") == 1
	    or die "Cannot find activity element";
	my $activity = $reader->copyCurrentNode(1);
	my $activity_name = $activity->findvalue("./name"); # XXX use name or oid?
	my $srt_vehicle = ($activity_name eq 'Walking' ? 'pedes' :
			   $activity_name eq 'Running' ? 'pedes' :
			   $activity_name eq 'Cycling' ? 'bike' :
			   undef);

	$reader->nextElement("events") == 1
	    or die "Cannot find events element";
	my $events = $reader->copyCurrentNode(1);
	for my $event_lost_time ($events->findnodes('./event[/type/@value="8"]/realtime')) {
	    push @gps_fix_lost, $event_lost_time->textContent;
	}

	$reader->nextElement("eventlocations") == 1
	    or die "Cannot find eventlocations element";
	my $trkseg;
	while ($reader->nextElement("eventlocation") == 1) {
	    my $eventlocation = $reader->copyCurrentNode(1);
	    my $realtime = $eventlocation->findvalue("./realtime");
	    if (@gps_fix_lost && $realtime > $gps_fix_lost[0]) {
		shift @gps_fix_lost;
		if ($trkseg) {
		    $gpsman->push_chunk($trkseg);
		    undef $trkseg;
		}
	    }
	    my $lat = $eventlocation->findvalue("./latitude");
	    my $lon = $eventlocation->findvalue("./longitude");
	    my $alt = $eventlocation->findvalue("./altitude");
	    my $fixq = $eventlocation->findvalue("./fixquality");
	    if ($lat == 0 and $lon == 0 and $fixq == 4) {
		warn "Detected obviously wrong eventlocation with lon=0, lat=0, and fixquality=4, skipping...\n";
		next;
	    }
	    if (!$trkseg) {
		$trkseg = GPS::GpsmanData->new;
		$trkseg->Type($trkseg->TYPE_TRACK);
		$trkseg->Name($file); # XXX?
		$trkseg->TrackAttrs({
				     (defined $srt_vehicle ? ('srt:vehicle' => $srt_vehicle) : ()),
				    });
	    }
	    my $wpt = GPS::Gpsman::Waypoint->new;
	    $wpt->Ident("");
	    $wpt->Accuracy($fixq >= 3 ? 0 : $fixq == 2 ? 1 : 2);
	    $wpt->Latitude($lat);
	    $wpt->Longitude($lon);
	    $wpt->Altitude($alt);
	    $wpt->Comment($gpsman_time_to_time->($realtime));
	    $trkseg->push_waypoint($wpt);
	}
	if ($trkseg) {
	    $gpsman->push_chunk($trkseg);
	    undef $trkseg;
	}
    }

    $gpsman;
}

1;

__END__
