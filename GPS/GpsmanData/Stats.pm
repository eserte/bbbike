# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Stats;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

BEGIN {
    # I don't want to depend on a non-core accessor module:
    no strict 'refs';
    for (qw(GpsmanData Accuracy Stats
	  )) {
	my $acc = $_;
	*{$acc} = sub {
	    my $self = shift;
	    if (@_) {
		$self->{$acc} = $_[0];
	    }
	    $self->{$acc};
	};
    }
}

sub new {
    my($class, $gpsmandata, %args) = @_;
    my $self = bless {}, $class;
    die 'GPS::GpsmanMultiData object is mandatory' if !$gpsmandata || !$gpsmandata->isa('GPS::GpsmanMultiData');
    $self->GpsmanData($gpsmandata);
    my $accuracy = defined $args{accuracy} ? delete $args{accuracy} : 0;
    $self->Accuracy($accuracy);
    die 'Unhandled arguments: ' . join(' ', %args) if %args;
    $self;
}

sub run_stats {
    my($self) = @_;
    my $gpsmandata = $self->GpsmanData;
    my $accepted_accuracy = $self->Accuracy;

    my $duration = 0;
    my $dist = 0;
    my $max_speed = undef;
    my $min_speed = undef;
    my %vehicles;

    my($bbox_minx, $bbox_miny, $bbox_maxx, $bbox_maxy);

    my @chunk_stats;
    my $last_vehicle;

    for my $chunk (@{ $gpsmandata->Chunks }) {
	my $chunk_duration = 0;
	my $chunk_dist = 0;
	my $chunk_max_speed = undef;
	my $chunk_min_speed = undef;

	my $vehicle = $chunk->TrackAttrs->{'srt:vehicle'} || $last_vehicle;
	$last_vehicle = $vehicle;

	my($chunk_bbox_minx, $chunk_bbox_miny, $chunk_bbox_maxx, $chunk_bbox_maxy);

	my $last_wpt;
	for my $wpt (@{ $chunk->Track }) {
	    next if $wpt->Accuracy > $accepted_accuracy;
	    if (defined $last_wpt) {
		my $time0 = $last_wpt->Comment_to_unixtime($chunk);
		my $time1 = $wpt->Comment_to_unixtime($chunk);
		my $hop_duration = $time1-$time0;
		my $hop_dist = $chunk->wpt_dist($last_wpt, $wpt);
		if ($hop_duration > 0) { # negative duration may happen if the GPS clock was adjusted in midst
		    my $hop_speed = $hop_dist / $hop_duration;
		    if (!defined $chunk_max_speed || $hop_speed > $chunk_max_speed) {
			$chunk_max_speed = $hop_speed;
		    }
		    if (!defined $chunk_min_speed || $hop_speed < $chunk_min_speed) {
			$chunk_min_speed = $hop_speed;
		    }
		    $chunk_duration += $hop_duration;
		}
		$chunk_dist += $hop_dist;
	    }

	    if (!defined $chunk_bbox_minx || $chunk_bbox_minx > $wpt->Longitude) {
		$chunk_bbox_minx = $wpt->Longitude;
	    }
	    if (!defined $chunk_bbox_maxx || $chunk_bbox_maxx < $wpt->Longitude) {
		$chunk_bbox_maxx = $wpt->Longitude;
	    }
	    if (!defined $chunk_bbox_miny || $chunk_bbox_miny > $wpt->Latitude) {
		$chunk_bbox_miny = $wpt->Latitude;
	    }
	    if (!defined $chunk_bbox_maxy || $chunk_bbox_maxy < $wpt->Latitude) {
		$chunk_bbox_maxy = $wpt->Latitude;
	    }

	    $last_wpt = $wpt;
	}

	push @chunk_stats, { duration  => $chunk_duration,
			     dist      => $chunk_dist,
			     avg_speed => ($chunk_duration ? $chunk_dist/$chunk_duration : undef),
			     max_speed => $chunk_max_speed,
			     min_speed => $chunk_min_speed,
			     vehicle   => $vehicle,
			     bbox      => [$chunk_bbox_minx, $chunk_bbox_miny, $chunk_bbox_maxx, $chunk_bbox_maxy],
			   };

	$duration += $chunk_duration;
	$dist += $chunk_dist;
	if (defined $chunk_max_speed && (!defined $max_speed || $chunk_max_speed > $max_speed)) {
	    $max_speed = $chunk_max_speed;
	}
	if (defined $chunk_min_speed && (!defined $min_speed || $chunk_min_speed < $min_speed)) {
	    $min_speed = $chunk_min_speed;
	}

	$vehicles{$vehicle}++ if defined $vehicle;

	if (defined $chunk_bbox_minx && (!defined $bbox_minx || $bbox_minx > $chunk_bbox_minx)) {
	    $bbox_minx = $chunk_bbox_minx;
	}
	if (defined $chunk_bbox_miny && (!defined $bbox_miny || $bbox_miny > $chunk_bbox_miny)) {
	    $bbox_miny = $chunk_bbox_miny;
	}
	if (defined $chunk_bbox_maxx && (!defined $bbox_maxx || $bbox_maxx < $chunk_bbox_maxx)) {
	    $bbox_maxx = $chunk_bbox_maxx;
	}
	if (defined $chunk_bbox_maxy && (!defined $bbox_maxy || $bbox_maxy > $chunk_bbox_maxy)) {
	    $bbox_maxy = $chunk_bbox_maxy;
	}
    }

    my %per_vehicle_stats;
    for my $chunk_stat (@chunk_stats) {
	if (defined(my $vehicle = $chunk_stat->{vehicle})) {
	    $per_vehicle_stats{$vehicle}->{duration} += $chunk_stat->{duration} if defined $chunk_stat->{duration};
	    $per_vehicle_stats{$vehicle}->{dist}     += $chunk_stat->{dist}     if defined $chunk_stat->{dist};
	}
    }
    for my $key (keys %per_vehicle_stats) {
	$per_vehicle_stats{$key}->{avg_speed} = (defined $per_vehicle_stats{$key}->{duration} ? $per_vehicle_stats{$key}->{dist}/$per_vehicle_stats{$key}->{duration} : undef);
    }

    $self->Stats({ chunk_stats => \@chunk_stats,
		   per_vehicle_stats => \%per_vehicle_stats,
		   duration  => $duration,
		   dist      => $dist,
		   max_speed => $max_speed,
		   min_speed => $min_speed,
		   avg_speed => ($duration ? $dist/$duration : undef),
		   vehicles  => [keys %vehicles],
		   bbox      => [$bbox_minx, $bbox_miny, $bbox_maxx, $bbox_maxy],
		 });
}

sub human_readable {
    my $self = shift;

    require BBBikeUtil;
    require Storable;

    my $make_dump_output = sub {
	my $data = shift;
	for my $key (qw(min_speed max_speed avg_speed)) {
	    if (defined $data->{$key}) {
		$data->{$key} = sprintf "%.1f km/h", BBBikeUtil::ms2kmh($data->{$key});
	    }
	}
	$data->{dist} = BBBikeUtil::m2km($data->{dist}, 3) if defined $data->{dist};
	$data->{duration} = BBBikeUtil::s2hms($data->{duration}) if defined $data->{duration};
    };

    my $stats = Storable::dclone($self->Stats);
    $make_dump_output->($stats);
    for my $chunk (@{ $stats->{chunk_stats} }) {
	$make_dump_output->($chunk);
    }
    for my $vehicle_data (values %{ $stats->{per_vehicle_stats} }) {
	$make_dump_output->($vehicle_data);
    }

    $stats;
}

1;

__END__

=head1 EXAMPLES

Dump statistics for a track:

    perl -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g); $s->run_stats; print Dump $s->human_readable' /tmp/20090829.trk

=cut
