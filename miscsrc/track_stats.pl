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

# XXX Temporary --- will be moved somewhere some day!

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;
use Text::Table;
use Tie::IxHash;
use Statistics::Descriptive;

use BBBikeUtil qw(ms2kmh s2hms);
use GPS::GpsmanData::Any;
use Karte::Polar;
use Strassen::Core;
use VectorUtil;

#my $tracks_file = "$FindBin::RealBin/../tmp/streets-accurate-categorized-split.bbd";
my $tracks_file = "$FindBin::RealBin/../tmp/streets-polar.bbd";
my $gpsman_dir  = "$ENV{HOME}/src/bbbike/misc/gps_data",
my $ignore_rx;
my $stage1;
my $stage2;
my $sortby = "difftime";
GetOptions("stage1=s" => \$stage1,
	   "stage2=s" => \$stage2,

	   "tracks=s" => \$tracks_file,
	   "ignorerx=s" => \$ignore_rx,

	   "gpsmandir=s" => \$gpsman_dir,

	   "sortby=s" => \$sortby,
	  ) or die "usage?";

if ($stage2) {
    stage2();
} else {
    stage1();
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

    my $ofh;
    if ($stage1) {
	open $ofh, ">", $stage1
	    or die "Can't write to $stage1: $!";
    } else {
	$ofh = \*STDERR;
    }
    require Data::Dumper;
    print $ofh Data::Dumper->new([\@included],[qw()])->Indent(1)->Useqq(1)->Purity(1)->Dump;
}

sub stage2 {
    use vars qw($VAR1);
    do $stage2;
    my $included = $VAR1;
    if (!$included) {
	die "Cannot load from $stage2 (maybe: $@)";
    }
    my @results;
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
			    $result->{diffalt} = $chunk->Points->[$wpt_i]->Altitude - $result->{from2}->Altitude;
			    if ($length) {
				$result->{mount} = 100 * $result->{diffalt} / $length;
			    } else {
				$result->{mount} = undef;
			    }

			    for my $field (qw(velocity vehicles length difftime file diffalt mount)) {
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

    die "Invalid -sortby" if !exists $results[0]->{$sortby};

    @results = sort { $a->{$sortby} <=> $b->{$sortby} } @results;

    my @cols = grep { /^!/ } keys %{ $results[0] };

    my %stats;
    for my $col (@cols) {
	(my $numeric_field = $col) =~ s{^!}{};
	next if $numeric_field !~ m{^(difftime|length|velocity|diffalt|mount)$};
	my $s = Statistics::Descriptive::Full->new;
	$s->add_data(map { $_->{$numeric_field} } @results);
	no strict 'refs';
	$stats{median}->{$col}             = &{"format_" . $numeric_field}($s->median);
	$stats{mean}->{$col}               = &{"format_" . $numeric_field}($s->mean);
	$stats{standard_deviation}->{$col} = &{"format_" . $numeric_field}($s->standard_deviation);
	$stats{percentile_25}->{$col}      = &{"format_" . $numeric_field}($s->percentile(25));
	$stats{percentile_75}->{$col}      = &{"format_" . $numeric_field}($s->percentile(75));
    }

    my $tb = Text::Table->new('', map { /^!(.*)/; $1 } @cols);
    $tb->load(map { [ '', @{$_}{@cols} ] } @results);
    $tb->load(['---']);
    for my $stat_method (keys %stats) {
	$tb->load([$stat_method, map { $stats{$stat_method}->{$_} || '' } @cols]);
    }
    print $tb->table, "\n";

}

sub format_velocity { sprintf "%.1f", ms2kmh($_[0]) }
sub format_vehicles { join(", ", keys %{ $_[0] }) }
sub format_length   { sprintf "%.2f", $_[0]/1000 }
sub format_difftime { sprintf "%8s", s2hms($_[0]) }
sub format_file     { $_[0] }
sub format_diffalt  { sprintf "%.1f", $_[0] }
sub format_mount    { defined $_[0] ? sprintf "%.1f", $_[0] : undef }

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

=cut
