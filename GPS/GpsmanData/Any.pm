# -*- perl -*-

#
# $Id: Any.pm,v 1.3 2008/06/21 13:02:43 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use GPS::GpsmanData;

sub load {
    my($class, $file, %args) = @_;

    if ($file =~ /\.mps$/i) {
	$class->load_mps($file, %args);
    } elsif ($file =~ /\.gpx$/i) {
	$class->load_gpx($file, %args);
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

    require XML::Twig;

    my $twig = XML::Twig->new;
    $twig->parsefile($file);

    my($root) = $twig->children;
    for my $wpt_or_trk ($root->children) {
	if ($wpt_or_trk->name eq 'wpt') {
	    die "No support for wpt in gpx files yet";
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
		    my @data;
		    for my $trkpt ($trk_child->children) {
			next if $trkpt->name ne 'trkpt';
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
				my($Y,$M,$D,$h,$m,$s) = $time =~ m{^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$};
				if (!defined $Y) {
				    die "Cannot parse time <$time>";
				}
				# XXX timezone?!
				my $gpsman_time = sprintf "%02d-%s-%04d %02d:%02d:%02d", $D, $number_to_monthabbrev{$M+0}, $Y, $h, $m, $s;
				$wpt->Comment($gpsman_time);
			    }
			}

			push @data, $wpt;
		    }

		    $trkseg->Track(\@data);
		}
	    }

	    if ($trkseg) {
		push @{ $gpsman->{Chunks} }, $trkseg;
		undef $trkseg;
	    }
	} else {
	    die "No support for " . $wpt_or_trk->name . " planned";
	}
    }

    $gpsman;
}

sub load_gpsman {
    my($class, $file, %args) = @_;
    my $gps = GPS::GpsmanMultiData->new;
    $gps->load($file);
    $gps;
}

1;

__END__
