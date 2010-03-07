#!/usr/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009,2010 Slaven Rezic. All rights reserved.
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
use POSIX qw(strftime);
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

my @cols_sorted = qw(file fromtime vehicles device diffalt mount velocity length difftime);

#my $tracks_file = "$FindBin::RealBin/../tmp/streets-accurate-categorized-split.bbd";
my $tracks_file = "$FindBin::RealBin/../tmp/streets-polar.bbd";
my $gpsman_dir  = "$ENV{HOME}/src/bbbike/misc/gps_data",
my $ignore_rx;
my $start_stage;
my $state_file;
my $sortby = "difftime";
my $outbbd;
my $v;
GetOptions("stage=s" => \$start_stage,
	   "state=s" => \$state_file,

	   "tracks=s" => \$tracks_file,
	   "ignorerx=s" => \$ignore_rx,

	   "gpsmandir=s" => \$gpsman_dir,

	   "sortby=s" => \$sortby,

	   "outbbd=s" => \$outbbd,

	   "v+" => \$v,
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

if (!defined $start_stage) {
    $start_stage = 'begin';
}

if ($start_stage eq 'begin') {
    $start_stage = $stages[0];
}

if ($start_stage =~ m{^(dump)$}) {
    my $func = 'stage_' . $start_stage;
    no strict 'refs';
    $func->();
    exit;
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

    my @included;

    my %ns;
    for my $def (\@from, \@to) {
	my @p = @$def;
	for my $p_i (0 .. $#p-1) {
	    my($p1, $p2) = ($p[$p_i], $p[$p_i+1]);

	    # Get all records in the selected grids.
	    my(@grids) = $trks->get_new_grids((split /,/, $p1), (split /,/, $p2));
	    for my $grid (@grids) {
		next if !exists $trks->{Grid}{$grid};
		for my $n (@{ $trks->{Grid}{$grid} }) {
		    $ns{$n} = 1;
		}
	    }
	}
    }

    use constant STAGE_SEARCH_FROM => 1;
    use constant STAGE_SEARCH_TO  => 2;
    my $stage = STAGE_SEARCH_FROM;
    my %found_from;
    # Order records by appearance in file
    for my $n (sort { $a <=> $b } keys %ns) {
	my $r = $trks->get($n);
	my $deb_r; # = $r; # XXX
	next if $ignore_rx && $r->[Strassen::NAME] =~ $ignore_rx;
	my($file) = $r->[Strassen::NAME] =~ m{^(\S+)};
    RECORD: for my $r_i (1 .. $#{ $r->[Strassen::COORDS] }) {
	    my($r1,$r2) = @{$r->[Strassen::COORDS]}[$r_i-1,$r_i];
	    for my $stage (STAGE_SEARCH_FROM, STAGE_SEARCH_TO) {
		my $fence_coords = $stage == STAGE_SEARCH_FROM ? \@from : \@to;
	    FENCE_CHECK: for my $p_i (0 .. $#$fence_coords-1) {
		    my($p1, $p2) = ($fence_coords->[$p_i],$fence_coords->[$p_i+1]);
		    for my $checks ([$r1, $p1],
				    [$r1, $p2],
				    [$r2, $p1],
				    [$r2, $p2],
				   ) {
			if ($checks->[0] eq $checks->[1]) {
			    if ($stage == STAGE_SEARCH_FROM) {
				$found_from{$file} = [$deb_r, [$checks->[0]], [$checks->[1]], [$n,$r_i-1]];
			    } else { # STAGE_SEARCH_TO
				if ($found_from{$file}) {
				    my $found_to = [$deb_r, [$checks->[0]], [$checks->[1]], [$n,$r_i-1]];
				    push @included, [$file, $found_from{$file}, $found_to];
				    delete $found_from{$file};
				}
			    }
			    next RECORD;
			}
		    }
		    if (VectorUtil::intersect_lines(split(/,/, $p1),
						    split(/,/, $p2),
						    split(/,/, $r1),
						    split(/,/, $r2),
						   )) {
			if ($stage == STAGE_SEARCH_FROM) {
			    $found_from{$file} = [$deb_r, [$r1,$r2], [$p1,$p2], [$n,$r_i-1]];
			} else { # STAGE_SEARCH_TO
			    if ($found_from{$file}) {
				my $found_to = [$deb_r, [$r1,$r2], [$p1,$p2], [$n,$r_i-1]];
				push @included, [$file, $found_from{$file}, $found_to];
				delete $found_from{$file};
			    }
			}
			next RECORD;
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
    my @outbbd_records;
    my %seen_device;
    for my $trackdef (@$included) {
	my($file, $fromdef, $todef) = @$trackdef;
	my($from1,$from2) = @{ $fromdef->[1] };
	my($to1,  $to2)   = @{ $todef->[1] };
	my($from_fence1,$from_fence2) = @{ $fromdef->[2] };
	my($to_fence1,  $to_fence2)   = @{ $todef->[2] };
	my $gps = eval { GPS::GpsmanData::Any->load("$gpsman_dir/$file") };
	if ($@) {
	    my $save_err = $@; # first error is best
	    $gps = eval { GPS::GpsmanData::Any->load("$gpsman_dir/generated/$file") };
	    if (!$gps) {
		warn "$save_err, skipping...\n";
		next;
	    }
	}
	my @outbbd_coords;
	my $stage = 'from';
	my $result;
	my $length = 0;
	my @vehicles;
	my $current_vehicle;
	my $current_brand;
	my %vehicle_to_brand;
    PARSE_TRACK: for my $chunk (@{ $gps->Chunks }) {
	    no warnings 'once';
	    my @point_objs = @{ $chunk->Points };
	    my @points = map {
		join(",", $Karte::Polar::obj->trim_accuracy($_->Longitude, $_->Latitude));
	    } @point_objs;

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
		if ($v && $v >= 2) {
		    warn "$file $stage " . $point_objs[$wpt_i]->Comment . " | $from1 $from2 | $points[$wpt_i-1] $points[$wpt_i] | " . join(" ", map { Karte::Polar::ddd2dms($_) } map { split /,/ } $points[$wpt_i-1], $points[$wpt_i])."\n";
		}
		if ($stage eq 'from') {
		    if (($points[$wpt_i-1] eq $from1 &&
			 $points[$wpt_i  ] eq $from2) ||
			($points[$wpt_i-1] eq $from2 &&
			 $points[$wpt_i  ] eq $from1)) {
			tie my %vehicles, 'Tie::IxHash';
			$vehicles{$vehicle_label} = 1;
			my($wpt1,$wpt2) = ($chunk->Points->[$wpt_i-1], $chunk->Points->[$wpt_i]);
			my($epoch1,$epoch2) = ($wpt1->Comment_to_unixtime($chunk), $wpt2->Comment_to_unixtime($chunk));
			my $epoch;
			my($intersect_wpt) = eval { _schnittpunkt_as_wpt([$from1,$from2],[$from_fence1,$from_fence2]) };
			if ($@) {
			    warn "$@...";
			    $epoch = $epoch2;
			} else {
			    $epoch = $epoch1 + ($epoch2-$epoch1)*_fraction($wpt1, $intersect_wpt, $wpt2);
			    $length = $chunk->wpt_dist($intersect_wpt,$wpt2);
#XXX warn "length corr: $length    epoch corr: " . ($epoch2-$epoch1)*_fraction($wpt1, $intersect_wpt, $wpt2) . " $from1 $from2 $epoch1 $epoch2\n";
			}
			$result = {from1    => $wpt1,
				   from2    => $wpt2,
				   from     => $intersect_wpt,
				   fromtime => $epoch,
				   vehicles => \%vehicles,
				  };
			$stage = 'to';
			if ($outbbd) {
			    if ($intersect_wpt) {
				push @outbbd_coords, $intersect_wpt->Longitude.",".$intersect_wpt->Latitude;
			    } else {
				push @outbbd_coords, $wpt2->Longitude.",".$wpt2->Latitude;
			    }
			}
		    }
		} else {	# $stage eq 'to'
		    my($wpt1,$wpt2) = ($chunk->Points->[$wpt_i-1], $chunk->Points->[$wpt_i]);
		    $length += $chunk->wpt_dist($wpt1, $wpt2);
		    push @outbbd_coords, $wpt1->Longitude.",".$wpt1->Latitude if $outbbd;
		    if (($points[$wpt_i-1] eq $to1 &&
			 $points[$wpt_i  ] eq $to2) ||
			($points[$wpt_i-1] eq $to2 &&
			 $points[$wpt_i  ] eq $to1)) {
			my($epoch1,$epoch2) = ($wpt1->Comment_to_unixtime($chunk), $wpt2->Comment_to_unixtime($chunk));
			my $epoch;
			my($intersect_wpt) = eval { _schnittpunkt_as_wpt([$to1,$to2],[$to_fence1,$to_fence2]) };
			if ($@) {
			    warn "$@...";
			    $epoch = $epoch1;
			} else {
			    $epoch = $epoch1 + ($epoch2-$epoch1)*_fraction($wpt1, $intersect_wpt, $wpt2);
#XXX warn "length corr: " . $chunk->wpt_dist($wpt1,$intersect_wpt) . "   epoch corr: " . ($epoch2-$epoch1)*_fraction($wpt1, $intersect_wpt, $wpt2). " $to1 $to2 $epoch1 $epoch2\n";
			    $length += $chunk->wpt_dist($wpt1,$intersect_wpt);
			}
			$result->{to1} = $wpt1;
			$result->{to2} = $wpt2;
			$result->{to} = $intersect_wpt;
			$result->{totime} = $epoch;
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

			for my $field (@cols_sorted) {
			    no strict 'refs';
			    $result->{'!' . $field} = &{"format_$field"}($result->{$field});
			}

			push @results, $result;

			if ($outbbd) {
			    if ($intersect_wpt) {
				push @outbbd_coords, $intersect_wpt->Longitude.",".$intersect_wpt->Latitude;
			    } else {
				push @outbbd_coords, $wpt1->Longitude.",".$wpt1->Latitude;
			    }
			    push @outbbd_records, {result => $result, coords => \@outbbd_coords};
			}

			last PARSE_TRACK;
		    }
		}
	    }
	}
    }

    if ($outbbd) {
	open my $ofh, ">", $outbbd or die "Can't write to $outbbd: $!";
	print $ofh "#: map: polar\n#:\n";
	for my $outbbd_record (@outbbd_records) {
	    my($result, $coords) = @{$outbbd_record}{qw(result coords)};
	    print $ofh "difftime=$result->{difftime} length=$result->{length}\tX @$coords\n";
	}
	close $ofh
	    or die "Error while closing $outbbd: $!";
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

    #my @cols = grep { /^!/ } keys %{ $results[0] };
    my @cols = map { "!$_" } @cols_sorted;

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

# Pseudo stage: dump state
sub stage_dump {
    require Data::Dumper;
    print Data::Dumper->new([$state],[qw(state)])->Indent(1)->Useqq(1)->Dump;

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
    sub format_fromtime { strftime("%T", localtime $_[0]) }
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
	if (!$state_file) {
	    $usage->("Please specify from/to points.");
	} elsif (!$state->{from} || !$state->{to}) {
	    $usage->("Cannot get from/to points from state file, please specify on command line.");
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

# XXX will fail if $m1 or $m2 is senkrecht :-(
sub _schnittpunkt {
    my($l1, $l2) = @_;

    my($x11,$y11,$x12,$y12) = map { split/,/ } @$l1;
    my($x21,$y21,$x22,$y22) = map { split/,/ } @$l2;

    my $m1 = ($y12-$y11)/($x12-$x11);
    my $m2 = ($y22-$y21)/($x22-$x21);

    my $x = ($m1*$x11-$m2*$x21+$y21-$y11)/($m1-$m2);
    # XXX check if $x is really between $x11..$x12 and $x21..$x22
    my $y = ($x-$x11)*$m1+$y11;
    # the same: my $y = ($x-$x21)*$m2+$y21;
    ($x, $y);
}

sub _schnittpunkt_as_wpt {
    my($l1, $l2) = @_;
    my($x, $y) = _schnittpunkt($l1, $l2);
    my $wpt = GPS::Gpsman::Waypoint->new;
    $wpt->Latitude($y);
    $wpt->Longitude($x);
    $wpt;
}

sub _fraction {
    my($first,$middle,$last) = @_;
    my $delta = $last->Latitude - $first->Latitude;
    if ($delta == 0) {
	my $delta = $last->Longitude - $first->Longitude;
	return 0 if ($delta == 0);
	return ($middle->Longitude-$first->Longitude)/$delta;
    }
    return ($middle->Latitude-$first->Latitude)/$delta;
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

 * [#A] Actually use "shortcuts" in track_stats.yml: define small (for
   goals) and large (for starts) circles around points, which then
   may be used in the actual calculations.

 * [#A] Between stage1 and stage2 another sorting/filtering stage is
   needed. Currently they may be track duplicates in the result.
   stage1 should be rewritten to return *all* intersection points.
   Another step should filter out the candidates, that is, step
   lineary through the file and find starts, then goals. Two
   consecutive starts without a goal in between would remove the
   former start. In the "symmetric" mode for mount detection, the
   detection for goal - start sequences could also be done here.

   UPDATE: the stage_filtertracks algorithm is now better. What still
   may happen: a relation may be covered multiple times in one track
   file. Currently stage_filtertracks might handle this, but
   stage_trackdata probably not.

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

 * [#B] Detect the broken altimeter and undef those values.

 * [#B] The state file could have the input variants in, that is,
   coordinates, input file timestamps, so the script may detect all
   stages should be done.

 * [#B] More statistical columns: wind direction/speed at the date of
   the route. Maybe min/max values are necessary. Temperature.

 * [#C] It's probably more efficient to have the tracks file splitted

 * [#C] Maybe also allow multiple start/goal lines.

 * [#C] If more than two points in the start and goal lines are
   implemented: iterate from the center to the ends of that lines.

 * [#C] It seems that it is more wise to put the diffalt value into
   comments_mount than the mount value. Then the orig file processing
   should calculate the mount value automatically.

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

 * More than two points in the start and goal lines are now possible.

=head1 PROBLEMS

 * Currently the algorithm assumes that the floating point coordinates
   already generated in the bbd file and the floating point
   coordinates generated when reading the gpsman tracks use the same
   rounding rules. This does not need to be true, especially if both
   steps was done on different machines.

=head1 SEE ALSO

L<GPS::GpsmanData::Stats> - a module providing statistics about one
track file (length, duration, min/avg/max speed etc.). This script
does statistics using multiple tracks between the same start and goal
region.

=cut
