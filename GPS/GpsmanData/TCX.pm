# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::TCX;

use strict;
use warnings;
our $VERSION = '0.01';

use Scalar::Util qw(openhandle);
use Time::Local qw(timegm);
use XML::LibXML;

use GPS::GpsmanData;

sub load_tcx {
    my($class, $file_or_fh, %args) = @_;

    my $gpsman = GPS::GpsmanMultiData->new;

    my $doc;
    if (openhandle $file_or_fh) {
	$doc = XML::LibXML->load_xml(IO => $file_or_fh);
    } else {
	$doc = XML::LibXML->load_xml(location => $file_or_fh);
    }

    # remove namespaces
    for my $node ($doc->findnodes('//*')) {
	$node->setNodeName($node->nodeName);
    }

    my $root = $doc->documentElement;

    my $gpx_time_to_epoch = sub {
	my $time = shift;
	my($Y,$M,$D,$h,$m,$s,$ms,$tz) = $time =~ m{^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z?$};
	if (!defined $Y) {
	    die "Cannot parse time <$time>";
	}
	if (defined $ms) {
	    $s += "0".$ms;
	}
	timegm $s,$m,$h,$D,$M-1,$Y;
    };

    my $is_first_segment = 1;
    for my $activity ($root->findnodes('/*[local-name()="TrainingCenterDatabase"]/*[local-name()="Activities"]/*[local-name()="Activity"]')) {
	my $vehicle;
	{
	    my $raw_vehicle = $activity->findvalue('./@Sport');
	    if ($raw_vehicle =~ m{^(Biking|Mountain Biking|Cycling|Bike)$}i) {
		$vehicle = 'bike';
	    } elsif ($raw_vehicle =~ m{^(Running|Hiking|Walking)$}i) {
		$vehicle = 'pedes';
	    } elsif ($raw_vehicle =~ m{^(Swimming)$}i) {
		$vehicle = 'swim';
	    } elsif ($raw_vehicle =~ m{^(Rowing)$}i) {
		$vehicle = 'boat';
	    } elsif ($raw_vehicle =~ m{^(Kayaking)$}i) {
		$vehicle = 'kayak';
	    } else {
		warn "Don't know how to handle Sport '$raw_vehicle'";
	    }
	}
	for my $track ($activity->findnodes('./*[local-name()="Lap"]/*[local-name()="Track"]')) {
	    my $trkseg = GPS::GpsmanData->new;
	    $trkseg->Type($trkseg->TYPE_TRACK);
	    if ($is_first_segment) {
		$trkseg->IsTrackSegment(0);
		$trkseg->Name($activity->findvalue('./*[local-name()="Name"]'));
		$trkseg->TrackAttrs({
				     (defined $vehicle ? ('srt:vehicle' => $vehicle) : ()),
				    });
		$is_first_segment = 0;
	    } else {
		$trkseg->IsTrackSegment(1);
	    }
	    my @data;
	    for my $trackpoint ($track->findnodes('./*[local-name()="Trackpoint"]')) {
		my $wpt = GPS::Gpsman::Waypoint->new;
		$wpt->Ident("");
		$wpt->Latitude($trackpoint->findvalue('./*[local-name()="Position"]/*[local-name()="LatitudeDegrees"]'));
		$wpt->Longitude($trackpoint->findvalue('./*[local-name()="Position"]/*[local-name()="LongitudeDegrees"]'));
		my $ele = $trackpoint->findvalue('./*[local-name()="AltitudeMeters"]');
		if (defined $ele && $ele ne '') {
		    $wpt->Altitude($ele);
		}
		my $epoch = $gpx_time_to_epoch->($trackpoint->findvalue('./*[local-name()="Time"]'));
		$wpt->unixtime_to_DateTime($epoch, $trkseg);
		push @data, $wpt;
	    }
	    if (@data) {
		$trkseg->Track(\@data);
		push @{ $gpsman->{Chunks} }, $trkseg;
	    }
	}
    }

    $gpsman;
}

1;

__END__
