#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# XXX Temporary --- will be renamed somewhere some day!

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;
use Text::Table;
use Tie::IxHash;
use Statistics::Descriptive;
use Storable qw(lock_nstore lock_retrieve);

use BBBikeUtil qw(ms2kmh s2hms);
use GPS::GpsmanData::Any;
use Karte::Polar;
use Strassen::Core;
use VectorUtil;

my @stages = qw(filtertracks trackdata statistics output);
my %stages = map {($_,1)} @stages;

#my $tracks_file = "$FindBin::RealBin/../tmp/streets-accurate-categorized-split.bbd";
my $tracks_file = "$FindBin::RealBin/../tmp/streets-polar.bbd";
my $gpsman_dir  = "$ENV{HOME}/src/bbbike/misc/gps_data",
my $ignore_rx;
my $start_stage;
my $state_file;
my $sortby = "difftime";
my $v;
GetOptions("stage=s" => \$start_stage,
	   "state=s" => \$state_file,

	   "tracks=s" => \$tracks_file,
	   "ignorerx=s" => \$ignore_rx,

	   "gpsmandir=s" => \$gpsman_dir,

	   "sortby=s" => \$sortby,

	   "v" => \$v,
	  ) or die "usage?";

if ($v) {
    Strassen::set_verbose($v);
}

my $state = load_state();

if (!defined $start_stage) {
    if ($state && $state->{stage}) {
	$start_stage = next_stage($state->{stage});
    }
}

# don't support the old numerical stages anymore...
if ($start_stage =~ m{^\d+$}) {
    undef $start_stage;
}

if (!defined $start_stage) {
    $start_stage = 'begin';
}

if ($start_stage eq 'begin') {
    $start_stage = $stages[0];
}

if (!$stages{$start_stage}) {
    die "Invalid start stage $start_stage";
}

{
    my $stage = $start_stage;
    while() {
	my $be_quiet = $stage eq $stages[-1]; # last stage does the output, therefore be quiet
	print STDERR "Stage $stage... " if !$be_quiet;
	no strict 'refs';
	&{"stage_" . $stage};
	print STDERR "done\n"           if !$be_quiet;
	$stage = next_stage($stage);
	last if !defined $stage;
    }
}

# Get tracks intersecting both lines
sub stage_filtertracks {
    my(@from, @to);
    parse_intersection_lines(\@from, \@to);

    my $trks = Strassen->new($tracks_file);
    $trks->make_grid(#Exact => 1, # XXX Eats a lot of memory, so better not use it yet...
		     UseCache => 1);

    my %in_start;
    my @included;

    for my $def ([1, @from],
		 [2, @to]) {
	my($pass, @p) = @$def;

	my %seen;
	for my $p_i (0 .. $#p-1) {
	    my($p1, $p2) = ($p[$p_i], $p[$p_i-1]);

	    my(@grids) = keys %{{ map { ($_=>1) }
				      (join(",", $trks->grid(split /,/, $p1)),
				       join(",", $trks->grid(split /,/, $p2))) # XXX alle Gitter dazwischen auch!
				  }
			    };
	    for my $grid (@grids) {
		next if !exists $trks->{Grid}{$grid};
		for my $n (@{ $trks->{Grid}{$grid} }) {
		    my $r = $trks->get($n);
		    next if $ignore_rx && $r->[Strassen::NAME] =~ $ignore_rx;
		    next if $seen{$r->[Strassen::NAME]};
		    my($file) = $r->[Strassen::NAME] =~ m{^(\S+)};
		    next if $pass == 2 && !$in_start{$file};
		RECORD: for my $r_i (1 .. $#{ $r->[Strassen::COORDS] }) {
			my($r1,$r2) = @{$r->[Strassen::COORDS]}[$r_i-1,$r_i];
			for my $checks ([$r1, $p1],
					[$r1, $p2],
					[$r2, $p1],
					[$r2, $p2],
				       ) {
			    if ($checks->[0] eq $checks->[1]) {
				$seen{$r->[Strassen::NAME]} = 1;
				if ($pass == 1) {
				    $in_start{$file} = [$r, [$checks->[0]], [$checks->[1]]];
				} elsif ($pass == 2) {
				    push @included, [$file, $in_start{$file}, [$r, [$checks->[0]], [$checks->[1]]]];
				}
				next RECORD;
			    }
			}
			if (VectorUtil::intersect_lines(split(/,/, $p1),
							split(/,/, $p2),
							split(/,/, $r1),
							split(/,/, $r2),
						       )) {
			    $seen{$r->[Strassen::NAME]} = 1;
			    if ($pass == 1) {
				$in_start{$file} = [$r, [$r1,$r2], [$p1,$p2]];
			    } elsif ($pass == 2) {
				push @included, [$file, $in_start{$file}, [$r, [$r1,$r2], [$p1,$p2]]];
			    }
			}
		    }
		}
	    }
	}
    }

    $state->{included} = \@included;
    $state->{stage} = 'filtertracks';
    $state->{from} = \@from,
    $state->{to}   = \@to,
    save_state();
}

# Find basic data for matched tracks (velocity, diffalt etc.)
sub stage_trackdata {
    my $included = $state->{included};
    my @results;
    my %seen_device;
    for my $trackdef (@$included) {
	my($file, $fromdef, $todef) = @$trackdef;
	my($from1,$from2) = @{ $fromdef->[1] };
	my($to1,  $to2)   = @{ $todef->[1] };
	my $gps = eval { GPS::GpsmanData::Any->load("$gpsman_dir/$file") };
	if ($@) {
	    my $save_err = $@; # first error is best
	    $gps = eval { GPS::GpsmanData::Any->load("$gpsman_dir/generated/$file") };
	    if (!$gps) {
		warn "$save_err, skipping...\n";
		next;
	    }
	}
	my $stage = 'from';
	my $result;
	my $length = 0;
	my @vehicles;
	my $current_vehicle;
	my $current_brand;
	my %vehicle_to_brand;
    PARSE_TRACK: {
	    for my $chunk (@{ $gps->Chunks }) {
		no warnings 'once';
		my @points = map {
		    join(",", $Karte::Polar::obj->trim_accuracy($_->Longitude, $_->Latitude));
		} @{ $chunk->Points };

		my $track_attrs = $chunk->TrackAttrs;
		if ($track_attrs->{'srt:vehicle'}) {
		    $current_vehicle = $track_attrs->{'srt:vehicle'} || '?';
		}
		$current_brand = undef;
		if (!$track_attrs->{'srt:brand'}) {
		    if (defined $current_vehicle && $vehicle_to_brand{$current_vehicle}) {
			$current_brand = $vehicle_to_brand{$current_vehicle};
		    }
		} else {
		    if (defined $current_vehicle) {
			$current_brand = $vehicle_to_brand{$current_vehicle} = $track_attrs->{'srt:brand'};
		    }
		}
		my $vehicle_label = defined $current_vehicle ? ($current_vehicle . (defined $current_brand ? " ($current_brand)" : '')) : '?';

		if ($stage eq 'to') {
		    # new chunk, maybe new vehicle?
		    $result->{vehicles}->{$vehicle_label}++;
		}
		for my $wpt_i (1 .. $#points) {
		    if ($stage eq 'from') {
			if (($points[$wpt_i-1] eq $from1 &&
			     $points[$wpt_i  ] eq $from2) ||
			    ($points[$wpt_i-1] eq $from2 &&
			     $points[$wpt_i  ] eq $from1)) {
			    tie my %vehicles, 'Tie::IxHash';
			    $vehicles{$vehicle_label} = 1;
			    $result = {from1    => $chunk->Points->[$wpt_i-1],
				       from2    => $chunk->Points->[$wpt_i  ],
				       fromtime => $chunk->Points->[$wpt_i]->Comment_to_unixtime($chunk),
				       vehicles => \%vehicles,
				      };
			    $stage = 'to';
			}
		    } else { # $stage eq 'to'
			$length += $chunk->wpt_dist($chunk->Points->[$wpt_i-1], $chunk->Points->[$wpt_i]);
			if (($points[$wpt_i-1] eq $to1 &&
			     $points[$wpt_i  ] eq $to2) ||
			    ($points[$wpt_i-1] eq $to2 &&
			     $points[$wpt_i  ] eq $to1)) {
			    $result->{to1} = $chunk->Points->[$wpt_i-1];
			    $result->{to2} = $chunk->Points->[$wpt_i  ];
			    $result->{totime} = $chunk->Points->[$wpt_i]->Comment_to_unixtime($chunk);
			    $result->{difftime} = $result->{totime} - $result->{fromtime};
			    $result->{length} = $length;
			    $result->{velocity} = $result->{length} / $result->{difftime};
			    $result->{file} = $file;
			    $result->{device} = guess_device($result);
			    $seen_device{$result->{device}} = 1;
			    $result->{diffalt} = $chunk->Points->[$wpt_i]->Altitude - $result->{from2}->Altitude;
			    if ($length) {
				$result->{mount} = 100 * $result->{diffalt} / $length;
			    } else {
				$result->{mount} = undef;
			    }
			    $result->{date} = guess_date($result);

			    for my $field (qw(velocity vehicles length difftime file diffalt mount device)) {
				no strict 'refs';
				$result->{'!' . $field} = &{"format_$field"}($result->{$field});
			    }

			    push @results, $result;
			    last PARSE_TRACK;
			}
		    }
		}
	    }
	}
    }

    $state->{results} = \@results;
    $state->{seen_device} = \%seen_device;
    $state->{stage} = 'trackdata';
    save_state();
}

# Calculate statistics on data, total and per-device
sub stage_statistics {
    my @results = @{ $state->{results} };
    my %seen_device = %{ $state->{seen_device} };

    my @cols = grep { /^!/ } keys %{ $results[0] };

    my %stats;
    my %count_per_device;
    for my $col (@cols) {
	(my $numeric_field = $col) =~ s{^!}{};
	next if $numeric_field !~ m{^(difftime|length|velocity|diffalt|mount)$};

	my %s;
	$s{ALL} = Statistics::Descriptive::Full->new;
	$s{ALL}->add_data(map { $_->{$numeric_field} } @results);

	for my $device (keys %seen_device) {
	    $s{$device} = Statistics::Descriptive::Full->new;
	    my @filtered_results = grep { $_->{device} eq $device } @results;
	    $s{$device}->add_data(map { $_->{$numeric_field} } @filtered_results);
	    $count_per_device{$device} = scalar @filtered_results;
	}

	for my $device ('ALL', keys %seen_device) {
	    no strict 'refs';
	    $stats{$device}->{median}->{$col}             = &{"format_" . $numeric_field}($s{$device}->median);
	    $stats{$device}->{mean}->{$col}               = &{"format_" . $numeric_field}($s{$device}->mean);
	    $stats{$device}->{standard_deviation}->{$col} = &{"format_" . $numeric_field}($s{$device}->standard_deviation);
	    $stats{$device}->{percentile_25}->{$col}      = &{"format_" . $numeric_field}($s{$device}->percentile(25));
	    $stats{$device}->{percentile_75}->{$col}      = &{"format_" . $numeric_field}($s{$device}->percentile(75));
	}
    }

    $state->{stats} = \%stats;
    $state->{cols}  = \@cols;
    $state->{count_per_device} = \%count_per_device;
    $state->{stage} = 'statistics';
    save_state();
}

# Sort and print table
sub stage_output {
    my @cols = @{ $state->{cols} };
    my @results = @{ $state->{results} };
    my %seen_device = %{ $state->{seen_device} };
    my %stats = %{ $state->{stats} };
    my %count_per_device = %{ $state->{count_per_device} };

    if (!@results) {
	print "No data\n";
	return;
    }

    die "Invalid -sortby" if !exists $results[0]->{$sortby};
    @results = sort { $a->{$sortby} <=> $b->{$sortby} } @results;

    my $tb = Text::Table->new('', map { /^!(.*)/; $1 } @cols);
    $tb->load(map { [ '', @{$_}{@cols} ] } @results);
    for my $device ('ALL', keys %seen_device) {
	$tb->load(['---']);
	if ($device ne 'ALL') {
	    $tb->load(["- $device ($count_per_device{$device})"]);
	}
	for my $stat_method (keys %{ $stats{$device} }) {
	    $tb->load([$stat_method, map { $stats{$device}->{$stat_method}->{$_} || '' } @cols]);
	}
    }
    print $tb->table, "\n";
}

sub load_state {
    return if !defined $state_file;
    if (-e $state_file) {
	my $state = lock_retrieve $state_file;
	return $state;
    }
    return {};
}

sub save_state {
    return if !defined $state_file;
    lock_nstore $state, $state_file;
}

{
    no warnings 'uninitialized';

    sub format_velocity { sprintf "%.1f", ms2kmh($_[0]) }
    sub format_vehicles { join(", ", keys %{ $_[0] }) }
    sub format_length   { sprintf "%.2f", $_[0]/1000 }
    sub format_difftime { sprintf "%8s", s2hms($_[0]) }
    sub format_file     { $_[0] }
    sub format_diffalt  { sprintf "%.1f", $_[0] }
    sub format_mount    { defined $_[0] ? sprintf "%.1f", $_[0] : undef }
    sub format_device   { $_[0] }
}

sub guess_device {
    my $result = shift;
    my($year, $month, $day) = $result->{file} =~ m{^(2\d{3})(\d{2})(\d{2})};
    if (defined $year) {
	if ($year <= 2005 ||
	    ($year == 2006 && $month <= 2) # XXX approx.!
	   ) {
	    return "etrex venture";
	} elsif (($year <= 2007) ||
	    ($year == 2007 && ($month <= 11 ||
			       $day < 24))
	   ) {
	    return "etrex vista";
	} else {
	    return "etrex vista hcx";
	}
    } elsif ($result->{file} =~ m{^W\d{13,14}}) { # for some reason, the time string may have only 5 chars
	return "n95";
    } else {
	return undef;
    }
}

sub guess_date {
    my $file = $_[0]->{file};
    if ($file =~ m{^(\d{8})\D}) {
	return $1;
    } elsif ($file =~ m{^W(\d{8})\d}) {
	return $1;
    } else {
	return undef; # XXX maybe look into the file?
    }
}

sub parse_intersection_lines {
    my($from_ref, $to_ref) = @_;

    my $usage = sub {
	my $msg = shift;
	if ($msg) { warn $msg . "\n" }
	die "usage: $0 [options] from1 from2 ... : to1 to2 ...";
    };
    if (!@ARGV) {
	# get from state
	if (!$state) {
	    $usage->("Please specify from/to points.");
	} elsif ($state && (!$state->{from} || !$state->{to})) {
	    $usage->("Cannot get from/to from state file, please specify on command line.");
	}
	@$from_ref = @{ $state->{from} };
	@$to_ref   = @{ $state->{to} };
    } else {
	my $var = $from_ref;
	my $colon_seen;
	for my $i (0 .. $#ARGV) {
	    if ($ARGV[$i] eq ':') {
		if ($colon_seen) {
		    $usage->("Colon have to appear exactly once.");
		}
		$colon_seen = 1;
		if (@$from_ref < 2) {
		    $usage->("At least two from points need to be supplied.");
		}
		$var = $to_ref;
		next;
	    }
	    push @$var, $ARGV[$i];
	}
	if (!$colon_seen) {
	    $usage->("Colon have to be used to separate from and to points.");
	}
	if (@$to_ref < 2) {
	    $usage->("At least two to points need to be supplied.");
	}
    }
}

sub next_stage {
    my $this_stage = shift;
    for my $i (0 .. $#stages-1) {
	if ($this_stage eq $stages[$i]) {
	    return $stages[$i+1];
	}
    }
    undef;
}

__END__

=head1 HOWTO

 Create a streets-polar.bbd with all tracks in WGS84 coordinate system (see tracks-polar rule in misc/gps_data).

 Set bbbike's output coordinate system to "polar" (WGS-84)

 Activate to edit/select mode ("Koordinaten in Zwischenablage")

 Select two points forming the "start line" and two points forming the "goal line"

 Run the stage 1 of the programm (may take longer to create the grid):

   ./track_stats.pl <coord1> <coord2> <coord3> <coord4> -stage1 /tmp/something

 Run the stage 2 of the programm

   ./track_stats.pl -stage2 /tmp/something

=head1 TODO

 * [#A] Allow more than two points in the start and goal lines. Maybe
   also allow multiple start/goal lines.

 * [#C] If more than two points in the start and goal lines are
   implemented: iterate from the center to the ends of that lines.

 * [#C] It seems that it is more wise to put the diffalt value into
   comments_mount than the mount value. Then the orig file processing
   should calculate the mount value automatically.

 * [#B] For better statistics for the mount value both directions should be
   covered, not only one direction (of course, this is mostly
   meaningless for values like velocity, especially in the case of
   slopes). This could be an additional option, which should also be
   definable in track_stats.yml.

 * [#B] Show "bad" points, maybe also filter out. Show statistics about bad
   points (the "~" and "~~").

 * [#B] Create a Tk interface out of the results (for instant sorting and
   filtering). This could operate on a created state file.

 * [#B] Create an interface which is usable from within BBBike to
   immediately get results. This could use a temporary state file for
   fast sorting, which could be optionally made "persistent" by naming
   it.

 * [#A] Between stage1 and stage2 another sorting/filtering stage is
   needed. Currently they may be track duplicates in the result.
   stage1 should be rewritten to return *all* intersection points.
   Another step should filter out the candidates, that is, step
   lineary through the file and find starts, then goals. Two
   consecutive starts without a goal in between would remove the
   former start. In the "symmetric" mode for mount detection, the
   detection for goal - start sequences could also be done here.

 * [#B] Detect the broken altimeter and undef those values.

 * [#B] The state file could have the input variants in, that is,
   coordinates, input file timestamps, so the script may detect all
   stages should be done.

 * [#C] It's probably more efficient to have the tracks file splitted

=head1 DONE

 * See F<misc/gps_data/SlayMakefile> and
   F<misc/gps_data/track_stats.yml> for a list of routes which is
   automatically processed.

 * C<-state> may be given to save the state, for faster processing.
   Ideally, if the state file contains the state of last stage, then
   displaying the table is quite fast. The user may specify C<-stage>
   to start the processing at a given state, e.g. to force
   recalculation.

 * Strassen::Core was changed to know about "polar" data and default
   the gridsize to 0.01°, which seems to be very good and speeds up
   calculation a lot. Yeah, much better. Calculation time went down
   from 10 minutes or so to 2 minutes. And filtertracks is not
   anymore the slowest part.

=head1 PROBLEMS

 * Currently the algorithm assumes that the floating point coordinates
   already generated in the bbd file and the floating point
   coordinates generated when reading the gpsman tracks use the same
   rounding rules. This does not need to be true, especially if both
   steps was done on different machines.

=cut
