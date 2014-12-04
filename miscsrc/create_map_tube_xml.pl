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
use XML::LibXML;

use Strassen::Core;
use Strassen::CoreHeavy;
use Strassen::Combine;
use Strassen::MultiStrassen;

my $do_berlin_specialities = 1;

my $datadir = "$FindBin::RealBin/../data";
my $s = MultiStrassen->new("$datadir/ubahn", "$datadir/sbahn");
my $p = MultiStrassen->new("$datadir/ubahnhof", "$datadir/sbahnhof");
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
	    my $station_id = ($station2id{$station} ||= $id_counter++);
	    if (defined $laststation) {
		my $laststation_id = $station2id{$laststation};
		push @{ $stationid2links{$laststation_id}->{$station_id} }, $line;
		push @{ $stationid2links{$station_id}->{$laststation_id} }, $line;
	    }
	    if (!defined $firststation) {
		$firststation = $station;
	    }
	    $laststation = $station;
	}
    }

    # valid for all circle lines
    if ($do_berlin_specialities && $line eq 'S41/S42') {
	my $laststation_id = $station2id{$laststation};
	my $firststation_id = $station2id{$firststation};
	push @{ $stationid2links{$laststation_id}->{$firststation_id} }, $line;
	push @{ $stationid2links{$firststation_id}->{$laststation_id} }, $line;
    }
}

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

__END__

=head1 NAME

create_map_tube_xml.pl - create data file for Map::Tube::Berlin

=head1 DESCRIPTION

B<create_map_tube_xml.pl> creates a L<Map::Tube>-compatible XML file
containing the Berlin U/S-Bahn network.

=cut
