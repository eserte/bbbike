# -*- perl -*-

#
# $Id: Any.pm,v 1.8 2009/01/13 22:11:04 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Any;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use GPS::GpsmanData;

sub load {
    my($class, $file, %args) = @_;

    if ($file =~ /\.mps$/i) {
	$class->load_mps($file, %args);
    } elsif ($file =~ /\.gpx$/i) {
	$class->load_gpx($file, %args);
    } elsif ($file =~ /\.gpx\.gz$/i) {
	require File::Temp;
	require IO::Zlib;
	my $fh = IO::Zlib->new;
	$fh->open($file, "rb")
	    or die "Can't open gzipped file '$file' : $!";
	# Unfortunately XML::Twig cannot handle IO::Zlib globs, so
	# create a temporary
	my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_tmp.gpx");
	{
	    local $/ = 8192;
	    while(<$fh>) {
		print $tmpfh $_;
	    }
	    close $tmpfh
		or die "While writing to temporary file '$tmpfile': $!";
	}
	$class->load_gpx($tmpfile, %args);
    } elsif ($file =~ m{\.xml(?:\.gz)?$} && eval {
	require GPS::GpsmanData::SportsTracker;
	GPS::GpsmanData::SportsTracker->match($file);
    }) {
	GPS::GpsmanData::SportsTracker->load($file, %args);
    } else {
	$class->load_gpsman($file, %args);
    }
}

sub load_mps {
    my($class, $file, %args) = @_;

    require File::Temp;
    require GPS::MPS;
    
    my $mps = GPS::MPS->new;
    open MPSFH, $file or die "Can't open $file: $!";
    my $gpsman_data = $mps->convert_to_gpsman(\*MPSFH);
    close MPSFH;
    my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1,
					       SUFFIX => ".trk");
    print $tmpfh $gpsman_data;
    close $tmpfh;

    $class->load_gpsman($tmpfile, %args);
}

sub load_gpx {
    my($class, $file, %args) = @_;

    my $gpsman = GPS::GpsmanMultiData->new;

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

    my $latlong2xy_twig = sub {
	my($node) = @_;
	my $lat = $node->att("lat");
	my $lon = $node->att("lon");
	($lat, $lon);
    };

    my $gpsman_time_to_time = sub {
	my $time = shift;
	my($Y,$M,$D,$h,$m,$s,$ms,$tz) = $time =~ m{^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z?$};
	if (!defined $Y) {
	    die "Cannot parse time <$time>";
	}
	if (defined $ms) {
	    $s += "0".$ms;
	}
	# XXX timezone?!
	my $gpsman_time = sprintf "%02d-%s-%04d %02d:%02d:%02d", $D, $number_to_monthabbrev{$M+0}, $Y, $h, $m, $s;
    };

    require XML::Twig;

    my $twig = XML::Twig->new;
    $twig->parsefile($file);

    my @wpts;

    my($root) = $twig->children;
    for my $wpt_or_trk ($root->children) {
	if ($wpt_or_trk->name eq 'wpt') {
	    my $wpt_in = $wpt_or_trk;
	    my $name;
	    my $gpsman_time;
	    for my $wpt_child ($wpt_in->children) {
		if ($wpt_child->name eq 'name') {
		    $name = $wpt_child->children_text;
		} elsif ($wpt_child->name eq 'time') {
		    my $time = $wpt_child->children_text;
		    $gpsman_time = $gpsman_time_to_time->($time);
		}
	    }
	    my($lat, $lon) = $latlong2xy_twig->($wpt_in);
	    my $wpt = GPS::Gpsman::Waypoint->new;
	    $wpt->Ident($name);
	    $wpt->Accuracy(0);
	    $wpt->Latitude($lat);
	    $wpt->Longitude($lon);
	    $wpt->Comment($gpsman_time) if $gpsman_time;
	    push @wpts, $wpt;
	} elsif ($wpt_or_trk->name eq 'trk') {
	    my $trk = $wpt_or_trk;
	    my $name;
	    my $trkseg;
	    for my $trk_child ($trk->children) {
		if ($trk_child->name eq 'name') {
		    $name = $trk_child->children_text;
		} elsif ($trk_child->name eq 'trkseg') {
		    if ($trkseg) {
			push @{ $gpsman->{Chunks} }, $trkseg;
			undef $trkseg;
		    }
		    $trkseg = GPS::GpsmanData->new;
		    $trkseg->Type($trkseg->TYPE_TRACK);
		    $trkseg->Name($name);
		    $trkseg->TrackAttrs({});
		    my @data;
		    for my $trkpt ($trk_child->children) {
			my $trkpt_name = $trkpt->name;
			if ($trkpt_name eq 'trkpt') {
			    my($lat, $lon) = $latlong2xy_twig->($trkpt);
			    my $wpt = GPS::Gpsman::Waypoint->new;
			    $wpt->Ident("");
			    $wpt->Accuracy(0);
			    $wpt->Latitude($lat);
			    $wpt->Longitude($lon);
			    for my $trkpt_child ($trkpt->children) {
				if ($trkpt_child->name eq 'ele') {
				    $wpt->Altitude($trkpt_child->children_text);
				} elsif ($trkpt_child->name eq 'time') {
				    my $time = $trkpt_child->children_text;
				    my $gpsman_time = $gpsman_time_to_time->($time);
				    $wpt->Comment($gpsman_time);
				}
			    }

			    push @data, $wpt;
			} elsif ($trkpt_name =~ m{^srt:}) { # XXX this assumes xmlns:srt, which does not have to be correct!
			    $trkseg->TrackAttrs->{$trkpt_name} = $trkpt->children_text;
			}
		    }
		    $trkseg->Track(\@data);
		}
	    }

	    if ($trkseg) {
		push @{ $gpsman->{Chunks} }, $trkseg;
		undef $trkseg;
	    }
	} elsif ($wpt_or_trk->name =~ m{^(?:metadata|extensions)$}) {
	    # ignore
	} else {
	    die "No support for " . $wpt_or_trk->name . " planned";
	}
    }

    if (@wpts) {
	my $wpts = GPS::GpsmanData->new;
	$wpts->Type(GPS::GpsmanData::TYPE_WAYPOINT);
	$wpts->Waypoints(\@wpts);
	push @{ $gpsman->{Chunks} }, $wpts;
    }

    $gpsman;
}

sub load_gpsman {
    my($class, $file, %args) = @_;
    my %constructor_args;
    for (qw(-editable)) {
	$constructor_args{$_} = delete $args{$_};
    }
    my $gps = GPS::GpsmanMultiData->new(%constructor_args);
    $gps->load($file);
    $gps;
}

1;

__END__
