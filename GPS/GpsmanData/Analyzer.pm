# -*- perl -*-

#
# $Id: Analyzer.pm,v 1.2 2008/12/29 17:58:38 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Analyzer;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

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

1;

__END__

=head1 NAME

GPS::GpsmanData::Analyzer - find errors in gps data

=head1 SYNOPSIS

     perl -MData::Dumper -MGPS::GpsmanData -MGPS::GpsmanData::Analyzer -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$anlzr=GPS::GpsmanData::Analyzer->new($gps);warn Dumper($anlzr->find_premature_samples)' ...

     perl -MData::Dumper -MGPS::GpsmanData -MGPS::GpsmanData::Analyzer -e '$gps=GPS::GpsmanMultiData->new(-editable => 1);$gps->load(shift);$anlzr=GPS::GpsmanData::Analyzer->new($gps);warn Dumper(map { $gps->LineInfo->get_line_by_wpt($_) } $anlzr->find_premature_samples)' ...

=cut

