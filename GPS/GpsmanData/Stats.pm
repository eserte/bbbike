# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Stats;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

BEGIN {
    # I don't want to depend on a non-core accessor module:
    no strict 'refs';
    for (qw(GpsmanData Accuracy Stats Areas
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
    if (exists $args{areas}) {
	$self->Areas(delete $args{areas});
    }
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

    my($start_wpt, $farthest_wpt, $goal_wpt);
    my $max_dist_from_start;

    my($area_bbox, $name_to_poly) = $self->_process_areas;

    for my $chunk (@{ $gpsmandata->Chunks }) {
	next if $chunk->Type ne $chunk->TYPE_TRACK;

	my $chunk_duration = 0;
	my $chunk_dist = 0;
	my $chunk_max_speed = undef;
	my $chunk_min_speed = undef;

	my $track_attrs = $chunk->TrackAttrs || {};
	my $vehicle = $track_attrs->{'srt:vehicle'} || $last_vehicle;
	$last_vehicle = $vehicle;

	my($chunk_bbox_minx, $chunk_bbox_miny, $chunk_bbox_maxx, $chunk_bbox_maxy);

	my $last_wpt;
	for my $wpt (@{ $chunk->Track }) {
	    next if $wpt->Accuracy > $accepted_accuracy;

	    if (!defined $start_wpt) {
		$start_wpt = $wpt;
	    } else {
		my $dist_from_start = $chunk->wpt_dist($start_wpt, $wpt);
		if (!defined $max_dist_from_start || $dist_from_start > $max_dist_from_start) {
		    $max_dist_from_start = $dist_from_start;
		    $farthest_wpt = $wpt;
		}
	    }

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
	if (defined $chunk_bbox_maxy && (!defined $bbox_maxy || $bbox_maxy < $chunk_bbox_maxy)) {
	    $bbox_maxy = $chunk_bbox_maxy;
	}
    }
    
 FIND_GOAL_WPT: {
	for(my $chunk_i = $#{ $gpsmandata->Chunks }; $chunk_i >= 0; $chunk_i--) {
	    my $chunk = $gpsmandata->Chunks->[$chunk_i];
	    next if $chunk->Type ne $chunk->TYPE_TRACK;
	    for(my $wpt_i = $#{ $chunk->Track }; $wpt_i >= 0; $wpt_i--) {
		my $wpt = $chunk->Track->[$wpt_i];
		next if $wpt->Accuracy > $accepted_accuracy;
		$goal_wpt = $wpt;
		last FIND_GOAL_WPT;
	    }
	}
    }

    my @route_wpts;
    if (defined $farthest_wpt && defined $goal_wpt && 
	$farthest_wpt->Longitude . ',' . $farthest_wpt->Latitude ne $goal_wpt->Longitude . ',' . $goal_wpt->Latitude) {
	push @route_wpts, $farthest_wpt;
    }
    unshift @route_wpts, $start_wpt if defined $start_wpt;
    push @route_wpts, $goal_wpt if defined $goal_wpt;

    my @route_areas;
    if ($area_bbox) {
	for my $route_wpt (@route_wpts) {
	    my($x,$y) = ($route_wpt->Longitude, $route_wpt->Latitude);
	FIND_AREA: {
		if (VectorUtil::point_in_grid($x,$y,@$area_bbox)) {
		    while(my($name,$poly) = each %$name_to_poly) {
			if (VectorUtil::point_in_polygon([$x,$y], $poly)) {
			    keys %$name_to_poly; # reset iterator!!!
			    push @route_areas, $name;
			    last FIND_AREA;
			}
		    }
		}
		push @route_areas, undef; # unknown area
	    }
	}
    }

    my %per_vehicle_stats;
    for my $chunk_stat (@chunk_stats) {
	if (defined(my $vehicle = $chunk_stat->{vehicle})) {
	    $per_vehicle_stats{$vehicle}->{duration} += $chunk_stat->{duration} if defined $chunk_stat->{duration};
	    $per_vehicle_stats{$vehicle}->{dist}     += $chunk_stat->{dist}     if defined $chunk_stat->{dist};
	    $per_vehicle_stats{$vehicle}->{min_speed} = $chunk_stat->{min_speed}
		if defined $chunk_stat->{min_speed} && (!defined $per_vehicle_stats{$vehicle}->{min_speed} ||
							$per_vehicle_stats{$vehicle}->{min_speed} > $chunk_stat->{min_speed});
	    $per_vehicle_stats{$vehicle}->{max_speed} = $chunk_stat->{max_speed}
		if defined $chunk_stat->{max_speed} && (!defined $per_vehicle_stats{$vehicle}->{max_speed} ||
							$per_vehicle_stats{$vehicle}->{max_speed} < $chunk_stat->{max_speed});
	}
    }
    for my $key (keys %per_vehicle_stats) {
	$per_vehicle_stats{$key}->{avg_speed} = ($per_vehicle_stats{$key}->{duration} ? $per_vehicle_stats{$key}->{dist}/$per_vehicle_stats{$key}->{duration} : undef);
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
		   route     => [map { $_->Longitude . ',' . $_->Latitude } @route_wpts],
		   route_aras => [@route_areas],
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

######################################################################
# Helpers
sub _process_areas {
    my($self) = @_;
    my $area_bbox;
    my $name_to_poly;
    if ($self->Areas) {
	require VectorUtil;
	my $s = $self->Areas;
	$s->init_for_iterator(__PACKAGE__);
	my @bboxes;
	my $convsub = $s->get_conversion(-tomap => 'polar');
	while() {
	    my $r = $s->next_for_iterator(__PACKAGE__);
	    my @c = @{ $r->[Strassen::COORDS()] };
	    last if !@c;
	    my $poly = [map { [split(/,/, $convsub->($_))] } @c];
	    push @bboxes, VectorUtil::bbox_of_polygon($poly);
	    $name_to_poly->{$r->[Strassen::NAME()]} = $poly;
	}
	$area_bbox = VectorUtil::combine_bboxes(@bboxes);
    }
    ($area_bbox, $name_to_poly);
}

1;

__END__

=head1 EXAMPLES

Dump statistics for a track:

    perl -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g); $s->run_stats; print Dump $s->human_readable' /tmp/20090829.trk

Dump statistics for a track with Berlin and Potsdam area detection
(using the "areas" parameter):

    perl -Ilib -MStrassen::MultiStrassen -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$areas = MultiStrassen->new("data/berlin_ortsteile", "data/potsdam"); $g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g, areas => $areas); $s->run_stats; print Dump $s->human_readable' misc/gps_data/20100821.trk

Dump statistics for all tracks in F<misc/gps_data>:

    mkdir /tmp/trkstats
    perl -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML=DumpFile -MFile::Basename -e 'for $f (@ARGV) { $dest = "/tmp/trkstats/"; if ($f =~ m{/generated/}) { $dest .= "generated-" } $dest .= basename($f); $dest .= ".yml"; next if -s $dest && -M $dest < -M $f; warn $dest; $g = GPS::GpsmanData::Any->load($f); $s = GPS::GpsmanData::Stats->new($g); $s->run_stats; DumpFile $dest, $s->human_readable }' misc/gps_data/*.trk misc/gps_data/generated/*.trk

=cut
