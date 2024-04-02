# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2010,2013,2016,2017,2020,2024 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Stats;

use strict;
use vars qw($VERSION);
$VERSION = '0.08';

use POSIX qw(strftime);

use Time::Zone::By4D ();

use constant ISODATE_FMT => "%Y-%m-%dT%H:%M:%S";

BEGIN {
    # I don't want to depend on a non-core accessor module:
    no strict 'refs';
    for (qw(GpsmanData Accuracy Stats Areas
	    Places PlacesKreuzungen PlacesHash
	    _AreaBbox _NameToPoly
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
    die 'GPS::GpsmanMultiDatao object is mandatory' if !$gpsmandata || !$gpsmandata->isa('GPS::GpsmanMultiData');
    $self->GpsmanData($gpsmandata);
    my $accuracy = defined $args{accuracy} ? delete $args{accuracy} : 0;
    $self->Accuracy($accuracy);
    if (exists $args{areas}) {
	$self->Areas(delete $args{areas});
    }
    if (exists $args{places}) {
	$self->Places(delete $args{places});
    }
    die 'Unhandled arguments: ' . join(' ', %args) if %args;
    $self;
}

sub run_stats {
    my($self, %args) = @_;
    my $with_nightride = delete $args{with_nightride};
    my $missing_vehicle_fallback = delete $args{missing_vehicle_fallback};
    my $missing_route_area_fallback = delete $args{missing_route_area_fallback};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    if ($with_nightride) {
	require Astro::Sunrise;
	require DateTime;
    }

    my $gpsmandata = $self->GpsmanData;
    my $accepted_accuracy = $self->Accuracy;

    my $duration = 0;
    my $dist = 0;
    my $max_speed = undef;
    my $min_speed = undef;
    my %vehicles;
    my %tags;
    my($min_epoch, $min_wpt);
    my($max_epoch, $max_wpt);

    my($bbox_minx, $bbox_miny, $bbox_maxx, $bbox_maxy);

    my @chunk_stats;
    my $last_vehicle;

    my($start_wpt, $farthest_wpt, $goal_wpt);
    my $max_dist_from_start;
    my $nightride_seconds;
    my $used_missing_vehicle_fallback;

    for my $chunk (@{ $gpsmandata->Chunks }) {
	next if $chunk->Type ne $chunk->TYPE_TRACK;

	my $chunk_duration = 0;
	my $chunk_dist = 0;
	my $chunk_max_speed = undef;
	my $chunk_min_speed = undef;

	my $track_attrs = $chunk->TrackAttrs || {};
	my $vehicle = $track_attrs->{'srt:vehicle'} || $last_vehicle;
	$last_vehicle = $vehicle;
	my $tag = $track_attrs->{'srt:tag'};

	my($chunk_bbox_minx, $chunk_bbox_miny, $chunk_bbox_maxx, $chunk_bbox_maxy);

	my($chunk_min_epoch, $chunk_min_wpt);
	my($chunk_max_epoch, $chunk_max_wpt);

	my $sunrise_epoch;
	my $sunset_epoch;
	if ($with_nightride && ((defined $vehicle && $vehicle eq 'bike') || (!defined $vehicle && $missing_vehicle_fallback)) && @{ $chunk->Track }) {
	    # XXX The algorithm probably fails in some situations, i.e.
	    # if a chunk crosses day/night changes twice or more
	    #
	    # XXX Question: should we use first and last waypoint here,
	    # or the first and last one with accepted accuracy? Both
	    # approaches have cons and pros:
	    # - with the current implementation the duration may be
	    #   smaller than the nightride time, which could be confusing
	    # - having a too small nightride time could be fatal (battery
	    #   lifetime could be smaller than calculated)
	    my $first_wpt = $chunk->Track->[0];
	    my $first_epoch = $first_wpt->Comment_to_unixtime($chunk);
	    my $last_wpt = $chunk->Track->[-1];
	    my $last_epoch = $last_wpt->Comment_to_unixtime($chunk);
	    my $dt = DateTime->from_epoch(epoch => $first_epoch);
	    my($sunrise, $sunset) = Astro::Sunrise::sunrise({
							     year  => $dt->year,
							     month => $dt->month,
							     day   => $dt->day,
							     lon   => $first_wpt->Longitude,
							     lat   => $first_wpt->Latitude,
							     tz    => $dt->offset*3600,
							     isdst => $dt->is_dst,
							    });

	    for my $def (
			 [$sunrise, \$sunrise_epoch, "00:00"],
			 [$sunset,  \$sunset_epoch,  "23:59"], # XXX 23:59:59 would be better
			) {
		my($hhmm, $epochref, $fallback) = @$def;
		$hhmm ||= $fallback;
		if (my($hh,$mm) = $hhmm =~ m{^(\d+):(\d+)}) {
		    $$epochref = DateTime->new(year   => $dt->year,
					       month  => $dt->month,
					       day    => $dt->day,
					       hour   => $hh,
					       minute => $mm,
					       second => 0,
					      )->epoch;
		} else {
		    die "Unexpected: cannot parse '$hhmm'";
		}
	    }

	    my $first_is_night = $first_epoch < $sunrise_epoch || $first_epoch > $sunset_epoch;
	    my $last_is_night  = $last_epoch  < $sunrise_epoch || $last_epoch  > $sunset_epoch;
	    my $this_nightride_seconds;
	    if ($first_is_night && $last_is_night) {
		# complete night ride
		$this_nightride_seconds = ($last_epoch - $first_epoch);
	    } elsif ($first_is_night && !$last_is_night) {
		# morning ride
		$this_nightride_seconds = ($sunrise_epoch - $first_epoch);
	    } elsif (!$first_is_night && $last_is_night) {
		# evening ride
		$this_nightride_seconds = ($last_epoch - $sunset_epoch);
	    }
	    if ($this_nightride_seconds) {
		$nightride_seconds += $this_nightride_seconds;
		if (!defined $vehicle && $missing_vehicle_fallback) {
		    $used_missing_vehicle_fallback = 1;
		}
	    }
	}

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
		if (!defined $chunk_min_epoch) {
		    $chunk_min_epoch = $time0;
		    $chunk_min_wpt = $last_wpt;
		}
		my $time1 = $wpt->Comment_to_unixtime($chunk);
		$chunk_max_epoch = $time1;
		$chunk_max_wpt = $wpt;
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
		$chunk_bbox_minx = $wpt->Longitude + 0;
	    }
	    if (!defined $chunk_bbox_maxx || $chunk_bbox_maxx < $wpt->Longitude) {
		$chunk_bbox_maxx = $wpt->Longitude + 0;
	    }
	    if (!defined $chunk_bbox_miny || $chunk_bbox_miny > $wpt->Latitude) {
		$chunk_bbox_miny = $wpt->Latitude + 0;
	    }
	    if (!defined $chunk_bbox_maxy || $chunk_bbox_maxy < $wpt->Latitude) {
		$chunk_bbox_maxy = $wpt->Latitude + 0;
	    }

	    $last_wpt = $wpt;
	}

	push @chunk_stats, { duration  => $chunk_duration,
			     dist      => $chunk_dist,
			     avg_speed => ($chunk_duration ? $chunk_dist/$chunk_duration : undef),
			     max_speed => $chunk_max_speed,
			     min_speed => $chunk_min_speed,
			     vehicle   => $vehicle,
			     (defined $tag ? (tags => [split /\s+/, $tag]) : ()),
			     bbox      => [$chunk_bbox_minx, $chunk_bbox_miny, $chunk_bbox_maxx, $chunk_bbox_maxy],
			     (defined $chunk_min_epoch ? (min_datetime => _get_wpt_isodate($chunk_min_epoch, $chunk_min_wpt)) : ()),
			     (defined $chunk_max_epoch ? (max_datetime => _get_wpt_isodate($chunk_max_epoch, $chunk_max_wpt)) : ()),
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

	if (defined $tag) {
	    for my $single_tag (split /\s+/, $tag) {
		$tags{$single_tag}++
	    }
	}

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

	if (defined $chunk_min_epoch && (!defined $min_epoch || $chunk_min_epoch < $min_epoch)) {
	    $min_epoch = $chunk_min_epoch;
	    $min_wpt   = $chunk_min_wpt;
	}
	if (defined $chunk_max_epoch && (!defined $max_epoch || $chunk_max_epoch > $max_epoch)) {
	    $max_epoch = $chunk_max_epoch;
	    $max_wpt   = $chunk_max_wpt;
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

    $self->_init_areas;
    my @route_areas;
    for my $route_wpt (@route_wpts) {
	my($x,$y) = ($route_wpt->Longitude, $route_wpt->Latitude);
	my $route_area = $self->_find_area($x,$y, missing_route_area_fallback => $missing_route_area_fallback);
	push @route_areas, $route_area;  # area or place or undef for unknown area
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
		   vehicles  => [sort { $per_vehicle_stats{$b}->{dist} <=> $per_vehicle_stats{$a}->{dist} } keys %vehicles],
		   tags      => [sort keys %tags],
		   bbox      => [$bbox_minx, $bbox_miny, $bbox_maxx, $bbox_maxy],
		   route     => [map { $_->Longitude . ',' . $_->Latitude } @route_wpts],
		   route_areas => [@route_areas],
		   (defined $min_epoch ? (min_datetime => _get_wpt_isodate($min_epoch, $min_wpt)) : ()),
		   (defined $max_epoch ? (max_datetime => _get_wpt_isodate($max_epoch, $max_wpt)) : ()),
		   ($with_nightride ? (nightride => $nightride_seconds) : ()),
		   ($used_missing_vehicle_fallback ? (nightride_with_missing_vehicle_fallback => 1) : ()),
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
	$data->{nightride} = BBBikeUtil::s2hms($data->{nightride}) if defined $data->{nightride};
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
sub _init_areas {
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
    $self->_AreaBbox($area_bbox);
    $self->_NameToPoly($name_to_poly);
}

sub _find_area {
    my($self, $x, $y, %args) = @_;
    my $missing_route_area_fallback = delete $args{missing_route_area_fallback};
    die "Unhandled arguments: " . join(" ", %args) if %args;

    my $area_bbox = $self->_AreaBbox;
    my $name_to_poly = $self->_NameToPoly;
    if ($area_bbox && VectorUtil::point_in_grid($x,$y,@$area_bbox)) {
	while(my($name,$poly) = each %$name_to_poly) {
	    if (VectorUtil::point_in_polygon([$x,$y], $poly)) {
		keys %$name_to_poly; # reset iterator!!!
		return $name;
	    }
	}
    }

    my $place = $self->_find_nearest_place($x,$y);

    if (!defined $place && $missing_route_area_fallback) {
	$place = $missing_route_area_fallback->($x,$y);
    }

    return $place;
}

sub _find_nearest_place {
    my($self,$px,$py) = @_;
    if (!$self->PlacesKreuzungen) {
	if ($self->Places) {
	    require Strassen::Kreuzungen;
	    my $s_hash = $self->Places->get_hashref;
	    $self->PlacesHash($s_hash);
	    my $kr = Kreuzungen->new_from_strassen(Strassen => $self->Places);
	    $self->PlacesKreuzungen($kr);
	}
    }
    if ($self->PlacesKreuzungen) {
	# XXX Should rather stay in WGS84 coordinates :-(
	require Karte::Polar;
	require Karte::Standard;
	$Karte::Polar::obj = $Karte::Polar::obj if 0; # cease -w
	my($sx,$sy) = $Karte::Polar::obj->map2standard($px,$py);
	my($best) = $self->PlacesKreuzungen->nearest_loop($sx,$sy,IncludeDistance=>1,BestOnly=>1,UseCache=>1);
	if ($best && $best->[1] < 10_000) {
	    return $self->PlacesHash->{$best->[0]};
	} else {
	    return undef;
	}
    } else {
	return undef;
    }
}

sub _get_wpt_isodate {
    my($epoch, $wpt) = @_;
    if ($wpt) {
	my $offset      = Time::Zone::By4D::get_timeoffset($wpt->Longitude, $wpt->Latitude, $epoch);
	my $offset_8601 = Time::Zone::By4D::get_iso8601_timeoffset($wpt->Longitude, $wpt->Latitude, $epoch);
	strftime(ISODATE_FMT, gmtime($epoch + $offset)) . $offset_8601;
    } else {
	strftime(ISODATE_FMT, localtime($epoch));
    }
}

1;

__END__

=head1 NAME

GPS::GpsmanData::Stats - run statistics on gpsman data

=head1 SYNOPSIS

    use GPS::GpsmanData::Any;
    use GPS::GpsmanData::Stats;
    my $gps = GPS::GpsmanData::Any->load($filename);
    my $stats = GPS::GpsmanData::Stats->new($gps);
    $stats->run_stats;
    print Data::Dumper::Dumper($stats->human_readable);

=head1 DESCRIPTION

B<GPS::GpsmanData::Stats> calculates some statistics on gpsman data
(resp. any GPS file format supported by L<GPS::GpsmanData::Any>, e.g.
GPX).

=head1 EXAMPLES

Dump statistics for a track:

    perl -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g); $s->run_stats; print Dump $s->human_readable' /tmp/20090829.trk

Dump statistics for a track with Berlin and Potsdam area detection
(using the "areas" parameter):

    perl -Ilib -MStrassen::MultiStrassen -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$areas = MultiStrassen->new("data/berlin_ortsteile", "data/potsdam"); $g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g, areas => $areas); $s->run_stats; print Dump $s->human_readable' misc/gps_data/20100821.trk

Dump statistics for a track with nearest orte detection
(using the "areas" parameter):

    perl -Ilib -MStrassen::MultiStrassen -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML -e '$areas = MultiStrassen->new("data/orte", "data/orte2"); $g = GPS::GpsmanData::Any->load(shift); $s = GPS::GpsmanData::Stats->new($g, places => $places); $s->run_stats; print Dump $s->human_readable' misc/gps_data/20100821.trk

It is possible to combine the C<areas> and C<places> options; the
C<areas> detection has precedence over C<places>.

Dump statistics for all tracks in F<misc/gps_data>:

    mkdir /tmp/trkstats
    perl -MGPS::GpsmanData::Any -MGPS::GpsmanData::Stats -MYAML=DumpFile -MFile::Basename -e 'for $f (@ARGV) { $dest = "/tmp/trkstats/"; if ($f =~ m{/generated/}) { $dest .= "generated-" } $dest .= basename($f); $dest .= ".yml"; next if -s $dest && -M $dest < -M $f; warn $dest; $g = GPS::GpsmanData::Any->load($f); $s = GPS::GpsmanData::Stats->new($g); $s->run_stats; DumpFile $dest, $s->human_readable }' misc/gps_data/*.trk misc/gps_data/generated/*.trk

=cut
