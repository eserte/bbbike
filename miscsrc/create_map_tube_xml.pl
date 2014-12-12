#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use File::Basename qw(basename);
use Getopt::Long;
use XML::LibXML;

use Strassen::Core;
use Strassen::CoreHeavy;
use Strassen::Combine;
use Strassen::MultiStrassen;

my $do_berlin_specialities = 1;
my $output_format = 'Map::Tube';

sub usage (;$) {
    my $msg = shift;
    warn $msg if $msg;
    die "usage: $0 [--output-format=Map::Tube|Map::Metro] [--no-ubahn] [--no-sbahn]\n";
}

my $do_ubahn = 1;
my $do_sbahn = 1;
GetOptions(
	   "output-format=s" => \$output_format,
	   "ubahn!" => \$do_ubahn,
	   "sbahn!" => \$do_sbahn,
	  )
    or usage;

$output_format =~ m{^(Map::Tube|Map::Metro)$}
    or usage("Invalid output format '$output_format'\n");

my $datadir = "$FindBin::RealBin/../data";
my $s = MultiStrassen->new(
			   ($do_ubahn ? "$datadir/ubahn" : ()),
			   ($do_sbahn ? "$datadir/sbahn" : ()),
			  );
my $p = MultiStrassen->new(
			   ($do_ubahn ? "$datadir/ubahnhof" : ()),
			   ($do_sbahn ? "$datadir/sbahnhof" : ()),
			  );
my $coord2station = $p->as_reverse_hash;

my $new_s = Strassen->new;

$s->init;
while() {
    my $r = $s->next;
    my @c = @{ $r->[Strassen::COORDS] };
    last if !@c;
    next if ($r->[Strassen::CAT]||'') =~ m{^[US](0|Bau)};
    for my $name (split /,/, $r->[Strassen::NAME]) {
	$new_s->push([$name, [@c], 'X']);
    }
}

$new_s = $new_s->make_long_streets;


#     # Ringbahn
#     $line2stations{'S41/S42'} = $line2stations{'S41'};
#     delete $line2stations{'S41'};
#     delete $line2stations{'S42'};
#     push @{ $line2stations{'S41/S42'} }, $line2stations{'S41/S42'}->[0];
# }

my $id_counter = 1;
my %station2id;
my %stationid2links;
my %line2stations;
my %line2id;
my %segment2lines;

sub add_segment {
    my($firststation, $nextstation, $line) = @_;
    if (exists $segment2lines{$nextstation} &&
	exists $segment2lines{$nextstation}{$firststation}) {
	push @{ $segment2lines{$nextstation}{$firststation} }, $line;
    } else {
	push @{ $segment2lines{$firststation}{$nextstation} }, $line;
    }
}

$new_s->init;
while() {
    my $r = $new_s->next;
    my @c = @{ $r->[Strassen::COORDS] };
    last if !@c;
    my $line = $r->[Strassen::NAME];

    if ($do_berlin_specialities) {
	next if $line eq 'S42';
	if ($line eq 'S41') {
	    $line = 'S41/S42';
	}
    }

    my $firststation;
    my $laststation;
    for my $c (@c) {
	if ($coord2station->{$c}) {
	    my $station = $coord2station->{$c}->[0];
	    $station =~ s{\s+\(.*\)$}{};

	    if (defined $laststation && $laststation eq $station) {
		# may happen: U5 Alexanderplatz - Alexanderplatz
		next;
	    }

	    if ($output_format eq 'Map::Tube') {
		my $station_id = ($station2id{$station} ||= $id_counter++);
		if (defined $laststation) {
		    my $laststation_id = $station2id{$laststation};
		    push @{ $stationid2links{$laststation_id}->{$station_id} }, $line;
		    push @{ $stationid2links{$station_id}->{$laststation_id} }, $line;
		}
	    } elsif ($output_format eq 'Map::Metro') {
		if (!exists $line2id{$line}) {
		    (my $id = $line) =~ s{[^A-Za-z0-9]}{}g;
		    $line2id{$line} = $id;
		}
		push @{ $line2stations{$line} }, $station;
		if (defined $laststation) {
		    add_segment($laststation, $station, $line);
		}
	    } else {
		die 'NYI';
	    }

	    if (!defined $firststation) {
		$firststation = $station;
	    }
	    $laststation = $station;
	}
    }

    # valid for all circle lines
    if ($do_berlin_specialities && $line eq 'S41/S42') {
	if ($output_format eq 'Map::Tube') {
	    my $laststation_id = $station2id{$laststation};
	    my $firststation_id = $station2id{$firststation};
	    push @{ $stationid2links{$laststation_id}->{$firststation_id} }, $line;
	    push @{ $stationid2links{$firststation_id}->{$laststation_id} }, $line;
	} elsif ($output_format eq 'Map::Metro') {
#XXX	    add_segment($line2stations{$line}[-1]}, $line2stations{$line}[0], $line);
	} else {
	    die 'NYI';
	}
    }
}

if ($output_format eq 'Map::Tube') {
    my $fmtid = sub { sprintf 'S%03d', $_[0] };

    my $doc = XML::LibXML::Document->new('1.0', 'utf-8');
    $doc->addChild($doc->createComment('Created by ' . basename(__FILE__) . ' (part of BBBike)'));
    my $tube = $doc->createElement('tube');
    $doc->setDocumentElement($tube);
    my $stations = $tube->addNewChild(undef, 'stations');
    for my $station (sort keys %station2id) {
	my $id = $station2id{$station};
	my @link_ids = keys %{ $stationid2links{$id} };
	my %lines = map { ($_ => 1) } map { @$_ } values %{ $stationid2links{$id} };
	my @lines = sort keys %lines;
	my $station_node = $stations->addNewChild(undef, 'station');
	$station_node->setAttribute('id', $fmtid->($id));
	utf8::upgrade($station); # This smells like an XML::LibXML bug
	$station_node->setAttribute('name', $station);
	$station_node->setAttribute('line', join(',', @lines));
	$station_node->setAttribute('link', join(',', map { $fmtid->($_) } @link_ids));
    }

    print $doc->serialize(1);
} elsif ($output_format eq 'Map::Metro') {
    binmode STDOUT, ':utf8';
    print "--stations\n\n";
    my %seen_station;
    for my $line (sort keys %line2stations) {
	print "# $line\n";
	for my $station (@{ $line2stations{$line} }) {
	    next if $seen_station{$station}++;
	    print $station, "\n";
	}
	print "\n";
    }
    print "--transfers\n\n"; # XXX net yet
    print "--lines\n\n";
    for my $line (sort keys %line2id) {
	print "$line2id{$line}|$line|\n";
    }
    print "\n";

    print "--segments\n\n";
    for my $firststation (sort keys %segment2lines) {
	my $v = $segment2lines{$firststation};
	for my $nextstation (sort keys %$v) {
	    my $lines = join(',', map { $line2id{$_} } @{ $v->{$nextstation} });
	    print "$lines|$firststation|$nextstation\n";
	}
    }
} else {
    die 'NYI';
}

__END__

=head1 NAME

create_map_tube_xml.pl - create data file for Map::Tube::Berlin

=head1 DESCRIPTION

B<create_map_tube_xml.pl> creates a L<Map::Tube>-compatible XML file
containing the Berlin U/S-Bahn network.

=cut
