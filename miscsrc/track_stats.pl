#!/usr/bin/perl -w
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

#my $tracks_file = "$FindBin::RealBin/../tmp/streets-accurate-categorized-split.bbd";
my $tracks_file = "$FindBin::RealBin/../tmp/streets-polar.bbd";
my $gpsman_dir  = "$ENV{HOME}/src/bbbike/misc/gps_data",
my $ignore_rx;
my $start_stage;
my $state_file;
my $sortby = "difftime";
GetOptions("stage=i" => \$start_stage,
	   "state=s" => \$state_file,

	   "tracks=s" => \$tracks_file,
	   "ignorerx=s" => \$ignore_rx,

	   "gpsmandir=s" => \$gpsman_dir,

	   "sortby=s" => \$sortby,
	  ) or die "usage?";

my $state = load_state();

if (!defined $start_stage) {
    if ($state && $state->{stage}) {
	$start_stage = $state->{stage} + 1;
    }
}

if (!defined $start_stage) {
    $start_stage = 1;
}

my $max_stage = 4;
if ($start_stage < 1 || $start_stage > $max_stage) {
    die "Invalid start stage $start_stage";
}

for my $stage ($start_stage .. $max_stage) {
    print STDERR "Stage $stage... " if $stage != $max_stage; # last stage does the output, therefore be quiet
    no strict 'refs';
    &{"stage" . $stage};
    print STDERR "done\n" if $stage != $max_stage;
}

# Get tracks intersecting both lines
sub stage1 {
    die "usage: $0 from1 from2 to1 to2" if @ARGV != 4;
    my($from1,$from2, $to1,$to2) = @ARGV;
    my $trks = Strassen->new($tracks_file);
    $trks->make_grid(#Exact => 1, # XXX too slow?!
		     UseCache => 1);

    my %in_start;
    my @included;

    for my $def ([1, $from1,$from2],
		 [2, $to1,$to2]) {
	my($pass, $p1, $p2) = @$def;
	my %seen;

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

    $state->{included} = \@included;
    $state->{stage} = 1;
    save_state();
}

sub stage2 {
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
    $state->{stage} = 2;
    save_state();
}

sub stage3 {
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
    $state->{stage} = 3;
    save_state();
}

sub stage4 {
    my @cols = @{ $state->{cols} };
    my @results = @{ $state->{results} };
    my %seen_device = %{ $state->{seen_device} };
    my %stats = %{ $state->{stats} };
    my %count_per_device = %{ $state->{count_per_device} };

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

sub format_velocity { sprintf "%.1f", ms2kmh($_[0]) }
sub format_vehicles { join(", ", keys %{ $_[0] }) }
sub format_length   { sprintf "%.2f", $_[0]/1000 }
sub format_difftime { sprintf "%8s", s2hms($_[0]) }
sub format_file     { $_[0] }
sub format_diffalt  { sprintf "%.1f", $_[0] }
sub format_mount    { defined $_[0] ? sprintf "%.1f", $_[0] : undef }
sub format_device   { $_[0] }

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

 * It's probably more efficient to have the tracks file splitted

 * Grid should now about "polar" data and default the gridsize to something appropriate

 * Allow more than two points in the start and goal lines

 * If more than two points in the start and goal lines are
   implemented: iterate from the center to the ends of that lines.

 * Create a set of checks which may be automatically executed.

 * The -stage1/-stage2 options are strange. Better: just let the user
   define a -state file, and give him the possibility to enter at an
   arbitrary "stage". Default is to enter the latest stage. Every
   stage could add something to the state file.

 * It seems that it is more wise to put the diffalt value into
   comments_mount than the mount value. Then the orig file processing
   should calculate the mount value automatically.

 * For better statistics for the mount value both directions should be
   covered, not only one direction (of course, this is mostly
   meaningless for values like velocity, especially in the case of
   slopes).

 * Show "bad" points, maybe also filter out. Show statistics about bad
   points (the "~" and "~~").

 * Create a Tk interface out of the results (for instant sorting and
   filtering). This could operate on a created state file.

=cut
