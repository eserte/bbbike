# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2008,2019 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  https://github.com/eserte/bbbike
#

package GPS::GpsmanData::Analyzer;

use strict;
use vars qw($VERSION);
$VERSION = '1.03';

sub new {
    my($class, $gpsman_data) = @_;
    bless { GpsmanData => $gpsman_data }, $class;
}

sub find_premature_samples {
    my($self) = @_;
    my $gps = $self->{GpsmanData};
    my @premature_waypoints;
    for my $chunk (@{ $gps->Chunks }) {
	next if $chunk->Type != $chunk->TYPE_TRACK;
	my $last_wpt;
	my @premature_candidates;
    CHUNK: {
	    for my $wpt (@{ $chunk->Track }) {
		if (defined $last_wpt &&
		    ($last_wpt->ParsedLatitude ne $wpt->ParsedLatitude ||
		     $last_wpt->ParsedLongitude ne $wpt->ParsedLongitude
		    )
		   ) {
		    last CHUNK;
		}
		push @premature_candidates, $wpt;
		$last_wpt = $wpt;
	    }
	}
	if (@premature_candidates <= 1) {
	    @premature_candidates = ();
	}
	push @premature_waypoints, @premature_candidates;
    }
    @premature_waypoints;
}

sub find_velocity_jumps {
    my($self) = @_;
    my $gps = $self->{GpsmanData};
    my @problematic_waypoints;
    for my $chunk (@{ $gps->Chunks }) {
	next if $chunk->Type != $chunk->TYPE_TRACK;
	my $last_wpt;
	my $prelast_wpt;
	for my $wpt (@{ $chunk->Track }) {
	    if (defined $last_wpt && defined $prelast_wpt) {
		my $delta_time = $wpt->Comment_to_unixtime($chunk) - $last_wpt->Comment_to_unixtime($chunk);
		if ($delta_time == 1) {
		    my $last_velocity = $chunk->wpt_velocity($prelast_wpt, $last_wpt);
		    my $this_velocity = $chunk->wpt_velocity($last_wpt, $wpt);
		    if (abs($this_velocity - $last_velocity) > 5 / 3.6) { # XXX currently hardcoded to 5 km/h delta
			push @problematic_waypoints, { wpt => $last_wpt, last_velocity => $last_velocity, this_velocity => $this_velocity };
		    }
		}
	    }
	    if (defined $last_wpt) {
		$prelast_wpt = $last_wpt;
	    }
	    $last_wpt = $wpt;
	}
    }
    @problematic_waypoints;
}

1;

__END__

=head1 NAME

GPS::GpsmanData::Analyzer - find errors in gps data

=head1 SYNOPSIS

     perl -MData::Dumper -MGPS::GpsmanData -MGPS::GpsmanData::Analyzer -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$anlzr=GPS::GpsmanData::Analyzer->new($gps);warn Dumper($anlzr->find_premature_samples)' ...

     perl -MData::Dumper -MGPS::GpsmanData -MGPS::GpsmanData::Analyzer -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$anlzr=GPS::GpsmanData::Analyzer->new($gps);warn Dumper(map { $gps->LineInfo->get_line_by_wpt($_) } $anlzr->find_premature_samples)' ...

     perl -MData::Dumper -MGPS::GpsmanData -MGPS::GpsmanData::Analyzer -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$anlzr=GPS::GpsmanData::Analyzer->new($gps);warn Dumper($anlzr->find_velocity_jumps)' ...

=cut

