# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2014,2016,2017,2021,2022,2023,2026 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

package GPS::GpsmanData::Any;

use strict;
use vars qw($VERSION);
$VERSION = '1.16';

use Scalar::Util qw(openhandle);

use GPS::GpsmanData;

sub load {
    my($class, $file, %args) = @_;

    my $debug = delete $args{debug}; # some implementations support a debug option

    if ($file =~ /\.gpx(?:\.gz)?$/i) {
	$class->load_gpx($file, %args);
    } elsif ($file =~ /\.fit$/i) {
	require GPS::GpsmanData::FIT;
	delete $args{-editable}; # no support
	GPS::GpsmanData::FIT->load($file, %args);
    } elsif ($file =~ /\.mps$/i) {
	$class->load_mps($file, debug => $debug, %args);
    } elsif ($file =~ m{\.xml(?:\.gz)?$} && eval {
	require GPS::GpsmanData::SportsTracker;
	GPS::GpsmanData::SportsTracker->match($file);
    }) {
	GPS::GpsmanData::SportsTracker->load($file, %args);
    } elsif ($file =~ /\.tcx$/) {
	require GPS::GpsmanData::TCX;
	GPS::GpsmanData::TCX->load_tcx($file);
    } else {
	$class->load_gpsman($file, %args);
    }
}

sub load_mps {
    my($class, $file, %args) = @_;

    my $debug = delete $args{debug};

    require File::Temp;
    require GPS::MPS;

    if ($debug) {
	no warnings 'once';
	$GPS::MPS::DEBUG = 1;
    }
    
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
    my($class, $file_or_fh, %args) = @_;

    if ($file_or_fh =~ /\.gpx\.gz$/i) {
	require File::Temp;
	require IO::Zlib;
	my $fh = IO::Zlib->new;
	$fh->open($file_or_fh, "rb")
	    or die "Can't open gzipped file '$file_or_fh' : $!";
	# Unfortunately some XML parsers cannot handle IO::Zlib globs,
	# so create a temporary
	my($tmpfh,$tmpfile) = File::Temp::tempfile(UNLINK => 1, SUFFIX => "_tmp.gpx");
	{
	    local $/ = 8192;
	    while(<$fh>) {
		print $tmpfh $_;
	    }
	    close $tmpfh
		or die "While writing to temporary file '$tmpfile': $!";
	}
	$file_or_fh = "$tmpfile";
    }

    my $timeoffset = delete $args{timeoffset};
    my $type_to_vehicle = delete $args{typetovehicle};
    my $guess_device = delete $args{guessdevice};

    require Time::Local;

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

    my %activity_type_to_vehicle =
	('cycling'  => 'bike',
	 'walking'  => 'pedes',
	 'running'  => 'pedes',
	 'hiking'   => 'pedes',
	 'swimming' => 'swim',
	 'kayaking' => 'kayak',
	);

    my $gpx_time_to_epoch = sub {
	my $time = shift;
	my($Y,$M,$D,$h,$m,$s,$ms,$tz) = $time =~ m{^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?Z?$};
	if (!defined $Y) {
	    die "Cannot parse time <$time>";
	}
	if (defined $ms) {
	    $s += "0".$ms;
	}
	Time::Local::timegm($s,$m,$h,$D,$M-1,$Y);
    };

    # Setup a subroutine to be fired after parsing the first
    # coordinate. This is needed for the timeoffset=>"automatic"
    # feature. In this case we need to get longitude, latitude and
    # epoch of a point; and this is used to determine the timeoffset
    # with the help of Time::Zone::By4D and DateTime* modules. To be
    # more complicated, the subroutine also takes an $addcode
    # parameter. This is used for track and route gpx files to change
    # the TimeOffset member afterwards. After the first call this
    # subroutine deletes itself.
    my $first_coordinate_event;
    if ($timeoffset && $timeoffset eq 'automatic') {
	my $delete_first_coordinate_event = sub {
	    undef $first_coordinate_event;
	};
	$first_coordinate_event = sub {
	    my($lon,$lat,$epoch,$addcode) = @_;
	    require Time::Zone::By4D;
	    $timeoffset = Time::Zone::By4D::get_timeoffset($lon,$lat,$epoch) / 3600;
	    $addcode->() if $addcode;
	    $delete_first_coordinate_event->();
	};
    }

    require GPS::GpsmanData::GarminGPX;

    my $xmlmodule = delete $args{xmlmodule};
    if (!defined $xmlmodule) {
	$xmlmodule = eval { require XML::Twig; 1 } ? 'XML::Twig' : 'XML::LibXML';
    }

    my($node_name, $node_children, $node_text, $node_att, $node_findvalue);
    my $root;

    if ($xmlmodule eq 'XML::Twig') {
	require XML::Twig;
	my $twig = XML::Twig->new;
	if (openhandle $file_or_fh) {
	    $twig->parse($file_or_fh);
	} else {
	    $twig->parsefile($file_or_fh);
	}
	$root        = $twig->root;
	$node_name      = sub { $_[0]->name };
	$node_children  = sub { $_[0]->children };
	$node_text      = sub { $_[0]->children_text };
	$node_att       = sub { $_[0]->att($_[1]) };
	$node_findvalue = sub { $_[0]->findvalue($_[1]) };
    } elsif ($xmlmodule eq 'XML::LibXML') {
	require XML::LibXML;
	my $parser = XML::LibXML->new;
	my $doc;
	if (openhandle $file_or_fh) {
	    $doc = $parser->parse_fh($file_or_fh);
	} else {
	    $doc = $parser->parse_file($file_or_fh);
	}
	$root        = $doc->documentElement;
	$node_name      = sub { $_[0]->nodeName };
	$node_children  = sub { grep { $_->nodeType == 1 } $_[0]->childNodes };
	$node_text      = sub { $_[0]->textContent };
	$node_att       = sub { $_[0]->getAttribute($_[1]) };
	$node_findvalue = sub {
	    my $xpc = XML::LibXML::XPathContext->new($_[0]);
	    $xpc->registerNs('gpxx', 'http://www.garmin.com/xmlschemas/GpxExtensions/v3');
	    $xpc->findvalue($_[1]);
	};
    } else {
	die "Unsupported xmlmodule: $xmlmodule";
    }

    my $latlong2xy = sub {
	my($node) = @_;
	my $lat = $node_att->($node, "lat");
	my $lon = $node_att->($node, "lon");
	($lat, $lon);
    };

    my @wpts;

    my $creator = $node_att->($root, 'creator');
    my $gps_device;
    if (defined $creator) {
	if ($creator =~ m{^( etrex
			  |  montana
			  |  oregon
			  |  monterra
			  |  dakota
			  |  colorado
			  |  gpsmap
			  )}ix) { # heuristics: looks like a GPS device (see also: https://en.wikipedia.org/wiki/List_of_Garmin_products)
	    $gps_device = $creator;
	} elsif ($creator =~ m{^Guru Maps/}) {
	    $gps_device = 'Guru Maps'; # may be an iOS or Android device
	}
    }

    my $garmin_userdef_symbols_set;

    for my $wpt_or_trk ($node_children->($root)) {
	if ($node_name->($wpt_or_trk) eq 'wpt') {
	    my $wpt_in = $wpt_or_trk;
	    my $name;
	    my $comment;
	    my $vehicle;
	    my $epoch;
	    my $gpsman_symbol;
	    my $ele;
	    for my $wpt_child ($node_children->($wpt_in)) {
		if ($node_name->($wpt_child) eq 'name') {
		    $name = $node_text->($wpt_child);
		} elsif ($node_name->($wpt_child) eq 'cmt') {
		    $comment = $node_text->($wpt_child);
		} elsif ($node_name->($wpt_child) eq 'ele') {
		    $ele = $node_text->($wpt_child);
		} elsif ($node_name->($wpt_child) eq 'time') {
		    my $time = $node_text->($wpt_child);
		    $epoch = $gpx_time_to_epoch->($time);
		} elsif ($node_name->($wpt_child) eq 'sym') {
		    my $sym = $node_text->($wpt_child);
		    ($gpsman_symbol, my($this_garmin_userdef_symbols_set)) = GPS::GpsmanData::GarminGPX::garmin_symbol_name_to_gpsman_symbol_name_set($sym);
		    if ($this_garmin_userdef_symbols_set) {
			if (!$garmin_userdef_symbols_set) {
			    $garmin_userdef_symbols_set = $this_garmin_userdef_symbols_set;
			} elsif ($garmin_userdef_symbols_set ne $this_garmin_userdef_symbols_set) {
			    warn "WARNING: garmin userdef symbols from different sets used in one file, cannot deal with this situation ($garmin_userdef_symbols_set != $this_garmin_userdef_symbols_set)";
			}
		    }
		}
	    }
	    my($lat, $lon) = $latlong2xy->($wpt_in);
	    $first_coordinate_event->($lon, $lat, $epoch) if $first_coordinate_event && $epoch;
	    my $wpt = GPS::Gpsman::Waypoint->new;
	    $wpt->Ident($name);
	    $wpt->Accuracy(0);
	    $wpt->Latitude($lat);
	    $wpt->Longitude($lon);
	    $wpt->Altitude($ele) if defined $ele;
	    $wpt->unixtime_to_DateTime($epoch, $timeoffset) if $epoch;
	    if (defined $comment) {
		$comment =~ s{\n}{ }g;
		$wpt->Comment($comment);
	    }
	    $wpt->Symbol($gpsman_symbol) if defined $gpsman_symbol;
	    push @wpts, $wpt;
	} elsif ($node_name->($wpt_or_trk) eq 'trk') {
	    my $trk = $wpt_or_trk;
	    my $name;
	    my $comment;
	    my($vehicle, $brand);
	    my $trkseg;
	    my $track_display_color;
	    my $is_first_segment = 1;
	    for my $trk_child ($node_children->($trk)) {
		if ($node_name->($trk_child) eq 'name') {
		    $name = $node_text->($trk_child);
		} elsif ($node_name->($trk_child) eq 'cmt') {
		    $comment = $node_text->($trk_child);
		} elsif ($node_name->($trk_child) eq 'extensions') {
		    $track_display_color = $node_findvalue->($trk_child, './gpxx:TrackExtension/gpxx:DisplayColor');
		    if (defined $track_display_color) {
			$track_display_color = GPS::GpsmanData::GarminGPX::garmin_to_gpsman_color($track_display_color);
		    }
		    for my $extensions_node ($node_children->($trk_child)) {
			if ($node_name->($extensions_node) eq 'srt:vehicle') {
			    $vehicle = $node_text->($extensions_node);
			} elsif ($node_name->($extensions_node) eq 'srt:brand') {
			    $brand = $node_text->($extensions_node);
			}
		    }
		} elsif ($node_name->($trk_child) eq 'type') {
		    if ($type_to_vehicle) {
			my $type = $node_text->($trk_child);
			$vehicle = $activity_type_to_vehicle{ lc($type) };
		    }
		} elsif ($node_name->($trk_child) eq 'desc') {
		    if ($guess_device && !defined $gps_device) {
			my $desc = $node_text->($trk_child);
			if ($desc =~ / recorded on (.*)/) { # fit2gpx would generate something like "Cycling (generic) recorded on Garmin Fenix5_plus"
			    $gps_device = $1;
			}
		    }
		} elsif ($node_name->($trk_child) eq 'trkseg') {
		    if ($trkseg) {
			push @{ $gpsman->{Chunks} }, $trkseg;
			undef $trkseg;
		    }
		    $trkseg = GPS::GpsmanData->new;
		    $trkseg->Type($trkseg->TYPE_TRACK);
		    $trkseg->TimeOffset($timeoffset) if defined $timeoffset;
		    if ($is_first_segment) {
			$trkseg->IsTrackSegment(0);
			$trkseg->Name($name);
			$trkseg->Comment($comment) if defined $comment;
			$trkseg->TrackAttrs({
					     (defined $track_display_color ? (colour => $track_display_color) : ()),
					     (defined $gps_device ? ('srt:device' => $gps_device) : ()),
					     (defined $vehicle ? ('srt:vehicle' => $vehicle) : ()),
					     (defined $brand ? ('srt:brand' => $brand) : ()),
					    });
			$is_first_segment = 0;
		    } else {
			$trkseg->IsTrackSegment(1);
		    }
		    my @data;
		    for my $trkpt ($node_children->($trk_child)) {
			my $trkpt_name = $node_name->($trkpt);
			if ($trkpt_name eq 'trkpt') {
			    my($lat, $lon) = $latlong2xy->($trkpt);
			    my $wpt = GPS::Gpsman::Waypoint->new;
			    $wpt->Ident("");
			    my $accuracy;
			    $wpt->Latitude($lat);
			    $wpt->Longitude($lon);
			    for my $trkpt_child ($node_children->($trkpt)) {
				if ($node_name->($trkpt_child) eq 'ele') {
				    $wpt->Altitude($node_text->($trkpt_child));
				} elsif ($node_name->($trkpt_child) eq 'time') {
				    my $time = $node_text->($trkpt_child);
				    my $epoch = $gpx_time_to_epoch->($time);
				    $first_coordinate_event->($lon, $lat, $epoch, sub { $trkseg->TimeOffset($timeoffset) }) if $first_coordinate_event;
				    $wpt->unixtime_to_DateTime($epoch, $trkseg);
				} elsif ($node_name->($trkpt_child) eq 'srt:accuracy') {
				    $accuracy = $node_text->($trkpt_child) || 0;
				} elsif (!defined $accuracy && $node_name->($trkpt_child) eq 'hdop') {
				    my $hdop_value = $node_text->($trkpt_child)+0;
				    # XXX The used values here need to be evaluated!
				    if ($hdop_value >= 50) {
					$accuracy = 2;
				    } elsif ($hdop_value >= 10) {
					$accuracy = 1;
				    } else {
					$accuracy = 0;
				    }
				}
			    }
			    if (!defined $accuracy) {
				if ($lat == 0 && $lon == 0) { # happens e.g. in fit files from fenix5s, for the first points
				    $accuracy = 2;
				} else {
				    $accuracy = 0;
				}
			    }
			    $wpt->Accuracy($accuracy);

			    push @data, $wpt;
			} elsif ($trkpt_name =~ m{^srt:}) { # XXX this assumes xmlns:srt, which does not have to be correct!
			    if (!$trkseg->TrackAttrs) {
				$trkseg->TrackAttrs({});
			    }
			    $trkseg->TrackAttrs->{$trkpt_name} = $node_text->($trkpt);
			}
		    }
		    $trkseg->Track(\@data);
		}
	    }

	    if ($trkseg) {
		push @{ $gpsman->{Chunks} }, $trkseg;
		undef $trkseg;
	    }
	} elsif ($node_name->($wpt_or_trk) =~ m{^(?:metadata|extensions)$}) {
	    # ignore
	} elsif ($node_name->($wpt_or_trk) =~ m{^(?:name|desc|author|email|url|urlname|time|keywords|bounds)$}) {
	    # ignore GPX 1.0 elements
	} elsif ($node_name->($wpt_or_trk) eq 'rte') {
	    my $rte = $wpt_or_trk;
	    my $gpsman_rte = GPS::GpsmanData->new;
	    $gpsman_rte->Type($gpsman_rte->TYPE_ROUTE);
	    $gpsman_rte->TimeOffset($timeoffset) if defined $timeoffset;
	    # XXX Name? TrackAttrs?
	    my @data;
	    for my $rte_child ($node_children->($rte)) {
		if ($node_name->($rte_child) eq 'rtept') {
		    my($lat, $lon) = $latlong2xy->($rte_child);
		    my $wpt = GPS::Gpsman::Waypoint->new;
		    my $name = '';
		    for my $rtept_child ($node_children->($rte_child)) {
			if ($node_name->($rtept_child) eq 'name') {
			    $name = $node_text->($rtept_child);
			} elsif ($node_name->($rtept_child) eq 'ele') {
			    $wpt->Altitude($node_text->($rtept_child));
			} elsif ($node_name->($rtept_child) eq 'time') {
			    my $time = $node_text->($rtept_child);
			    my $epoch = $gpx_time_to_epoch->($time);
			    $first_coordinate_event->($lon, $lat, $epoch, sub { $gpsman_rte->TimeOffset($timeoffset) }) if $first_coordinate_event;
			    $wpt->unixtime_to_DateTime($epoch, $gpsman_rte);
			}
		    }
		    $wpt->Ident($name);
		    $wpt->Accuracy(0);
		    $wpt->Latitude($lat);
		    $wpt->Longitude($lon);
		    $wpt->Comment(''); # XXX get from somewhere?
		    push @data, $wpt;
		}
	    }
	    $gpsman_rte->Track(\@data);
	    push @{ $gpsman->{Chunks} }, $gpsman_rte;
	} else {
	    die "No support for " . $node_name->($wpt_or_trk) . " planned";
	}
    }

    if (@wpts) {
	my $wpts = GPS::GpsmanData->new;
	$wpts->Type(GPS::GpsmanData::TYPE_WAYPOINT);
	$wpts->TimeOffset($timeoffset) if defined $timeoffset;
	$wpts->Waypoints(\@wpts);
	push @{ $gpsman->{Chunks} }, $wpts;
	$wpts->TrackAttrs({
			   (defined $garmin_userdef_symbols_set ? ('srt:garmin_userdef_symbols_set' => $garmin_userdef_symbols_set) : ()),
			   (defined $gps_device ? ('srt:device' => $gps_device) : ()),
			  });
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

=head1 NAME

GPS::GpsmanData::Any - support for loading GPS files

=head1 SYNOPSIS

    use GPS::GpsmanData::Any;
    my $gps = GPS::GpsmanData::Any->load($gps_file);

=head1 DESCRIPTION

Try to recognize a number of GPS file formats and load into a
L<GPS::GpsmanData>-compatible format. Currently the following file
formats are recognized:

=over

=item * MPS (by extension)

=item * GPX (by extension)

=item * compressed GPX (by extension C<.gpx.gz>)

=item * Nokia Sports Tracker files (by extension C<.xml>)

=item * compressed Nokia Sports Tracker files (by extension C<.xml.gz>)

=back

Other files are treated as GPSMan files.

=head2 GPX FILES

GPX files can also be converted directly (without checking the
filename suffix) using the C<load_gpx> method:

    $gps = GPS::GpsmanData::Any->load_gpx($gpx_file);

This method also accepts a filehandle instead of a file name.

Optional argument is C<timeoffset>, which may be set to a number for
the time offset to UTC in hours, or to C<automatic>, for automatically
determining the time offset using L<Time::Zone::By4D>.

Optional argument is C<xmlmodule>, which may be set to C<XML::Twig> or
C<XML::LibXML> to explicitly choose the XML parser. If not specified,
C<XML::Twig> is preferred and C<XML::LibXML> is used as fallback.

Currently there's support for waypoint (C<< <wpt> >>), track (C<<
<trk> >>), and route (C<< <rte> >>) elements.

The C<creator> attribute is handled specially: if the creator is
recognized as a GPS device (currently there's a hardcoded list of
Garmin devices), then this one is transformed into a pseudo GPSMan
attribute C<srt:device>.

=head1 AUTHOR

Slaven Rezic

=cut
