#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2015 Slaven Rezic. All rights reserved.
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
my $include_lines_file;

sub usage (;$) {
    my $msg = shift;
    warn $msg if $msg;
    die "usage: $0 [--output-format=Map::Tube|Map::Metro] [--include-lines=...] [--no-ubahn] [--no-sbahn]\n";
}

my $do_ubahn = 1;
my $do_sbahn = 1;
GetOptions(
	   "output-format=s" => \$output_format,
	   "ubahn!" => \$do_ubahn,
	   "sbahn!" => \$do_sbahn,
	   'include-lines=s' => \$include_lines_file,
	  )
    or usage;

$output_format =~ m{^(Map::Tube|Map::Metro)$}
    or usage("Invalid output format '$output_format'\n");

my $datadir = "$FindBin::RealBin/../data";
my $s = MultiStrassen->new(
			   ($do_ubahn ? "$datadir/ubahn" : ()),
			   ($do_sbahn ? "$datadir/sbahn" : ()),
			  );
my $p;
{
    my @p;
    push @p, Strassen->new("$datadir/ubahnhof", UseLocalDirectives => 1) if $do_ubahn;
    push @p, Strassen->new("$datadir/sbahnhof", UseLocalDirectives => 1) if $do_sbahn;
    $p = MultiStrassen->new(@p);
}
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
    push @{ $segment2lines{$firststation}{$nextstation} }, $line;
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
	    $station = normalize_station($station);

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
		    #(my $id = $line) =~ s{[^A-Za-z0-9]}{}g;
		    ## XXX a hack because of https://rt.cpan.org/Ticket/Display.html?id=100895
		    my $id;
		    if ($line =~ m{^U(\d+)}) {
			$id = $1;
		    } elsif ($line =~ m{^S(\d+)}) {
			$id = 1000 + $1;
		    } else {
			die "Cannot create line id for '$line'";
		    }
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

my %other_links; # Id => { Type => [id, id, ...], ... }, ...
{
    $p->init;
    while() {
	my $r = $p->next;
	my @c = @{ $r->[Strassen::COORDS] };
	last if !@c;
	my $dir = $p->get_directives;
	if ($dir && $dir->{map_tube_other_link}) {
	    my $station = normalize_station($r->[Strassen::NAME]);
	    my $station_id = $station2id{$station};
	    if (!defined $station_id) {
		die "ERROR: no station id for '$station' found";
	    }
	    my %this_other_links;
	    for my $this_other_link (@{ $dir->{map_tube_other_link} }) {
		my($type, $other_station) = split /:/, $this_other_link, 2;
		$other_station = normalize_station($other_station);
		my $other_station_id = $station2id{$other_station};
		if (!defined $other_station_id) {
		    die "ERROR: no other station id for '$other_station' found";
		}
		push @{ $this_other_links{$type} }, $other_station_id;
	    }
	    $other_links{$station_id} = \%this_other_links;
	}
    }
}

if ($output_format eq 'Map::Tube') {
    my $fmtid = sub { sprintf 'S%03d', $_[0] };

    my $doc = XML::LibXML::Document->new('1.0', 'utf-8');
    $doc->addChild($doc->createComment('Created by ' . basename(__FILE__) . ' (part of BBBike)'));
    my $tube = $doc->createElement('tube');
    $doc->setDocumentElement($tube);
    $tube->setAttribute(name => 'Berlin Metro');
    if ($include_lines_file) {
 	my $include_lines_contents = do { local $/; open my $fh, $include_lines_file or die $!; <$fh> };
 	my $fragment = XML::LibXML->new->parse_balanced_chunk($include_lines_contents);
	my $lines = $tube->addNewChild(undef, 'lines');
	for my $line ($fragment->findnodes('//line')) {
	    $lines->appendChild($line);
	}
    }
    my $stations = $tube->addNewChild(undef, 'stations');
    for my $station (sort keys %station2id) {
	my $id = $station2id{$station};
	my @link_ids = keys %{ $stationid2links{$id} };
	my %lines = map { ($_ => 1) } map { @$_ } values %{ $stationid2links{$id} };
	my @lines = sort keys %lines;
	my $this_other_links = $other_links{$id};
	my $station_node = $stations->addNewChild(undef, 'station');
	$station_node->setAttribute('id', $fmtid->($id));
	utf8::upgrade($station); # This smells like an XML::LibXML bug
	$station_node->setAttribute('name', $station);
	$station_node->setAttribute('line', join(',', @lines));
	$station_node->setAttribute('link', join(',', map { $fmtid->($_) } @link_ids));
	if ($this_other_links) {
	    my $other_link_text = join ',', map { $_ . ':' . join('|', map { $fmtid->($_) } @{ $this_other_links->{$_} }) } keys %$this_other_links;
	    $station_node->setAttribute('other_link', $other_link_text);
	}
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

sub normalize_station {
    my $station = shift;
    $station =~ s{\s+\(.*\)$}{};
    $station;
}

__END__

=head1 NAME

create_map_tube_xml.pl - create data file for Map::Tube::Berlin

=head1 DESCRIPTION

B<create_map_tube_xml.pl> creates a L<Map::Tube>-compatible XML file
containing the Berlin U/S-Bahn network.

With the yet experimental option C<--output-format=Map::Metro> it's
possible to create map files for L<Map::Metro> plugins.

With C<--no-sbahn> and C<--no-ubahn> it's possible to exclude the
S-Bahn resp. U-Bahn net from the result.

=cut
