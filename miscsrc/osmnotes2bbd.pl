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

use Getopt::Long;
use JSON::XS qw(decode_json);
use LWP::UserAgent;

use Strassen::Core;

my $osm_notes_rooturl_fmt = "http://www.openstreetmap.org/api/0.6/notes.json?bbox=%s,%s,%s,%s";

my $o;
my $bbox;
GetOptions(
	   "o=s" => \$o,
	   "bbox=s" => \$bbox,
	  )
    or die "usage: $0 -o file.bbd [ -bbox lon,lat,lon,lat | file | url ]\n";

my $url;
if ($bbox) {
    my(@bbox) = split /,/, $bbox;
    if (@bbox != 4) {
	die "Bounding box should contain of four elements lon,lat,lon,lat";
    }
    $url = sprintf $osm_notes_rooturl_fmt, @bbox;
} else {
    $url = shift
	or die "Please specify file or URL or a bbox with -bbox";
}

if (!$o) {
    die "Please specify output bbd file";
}

if ($url !~ m{^https?:}) {
    require File::Spec;
    $url = "file://" . File::Spec->rel2abs($url);
}

my $ua = LWP::UserAgent->new;
my $resp = $ua->get($url);
if (!$resp->is_success) {
    die "Fetching '$url' failed: " . $resp->status_line;
}
my $json = $resp->decoded_content(charset => 'none');
my $data = decode_json $json;

my $s = Strassen->new;
$s->set_global_directive(encoding => 'utf-8');
$s->set_global_directive(map => 'polar');

for my $feature (@{ $data->{features} || [] }) {
    if ($feature->{type} ne 'Feature') {
	warn "Skip unexpected feature type '$feature->{type}'...\n";
	next;
    }

    my $geometry = $feature->{geometry};
    if ($geometry->{type} ne 'Point') {
	warn "Skip unexpected geometry type '$geometry->{type}'...\n";
	next;
    }
    my @c = join(",", @{ $geometry->{coordinates} }[0,1]);

    my %dir;
    my $properties = $feature->{properties};
    next if $properties->{status} ne 'open'; # XXX 
    my $url = $properties->{url};
    if ($url) {
	$dir{url} = [$url];
    }
    my @texts;
    for my $comment (@{ $properties->{comments} || [] }) {
	push @texts, $comment->{text};
    }
    my $name = join("; ", @texts);
    $name =~ s{[\n\t]}{ }g;
    $s->push_ext([$name, \@c, "?"], \%dir);
}

print $s->write($o);

__END__

=head1 NAME

osmnotes2bbd.pl - fetch and convert OSM notes to bbd files

=head1 EXAMPLES

Fetch all OSM notes for Berlin and convert to berlin_notes.bbd:

    osmnotes2bbd.pl -o /tmp/berlin_notes.bbd -bbox 13.088443,52.338064,13.760931,52.675279

=head1 AUTHOR

Slaven Rezic

=cut
