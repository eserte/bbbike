#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2014,2018 Slaven Rezic. All rights reserved.
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
use Tie::IxHash;

use Strassen::Core;

my $osm_notes_rooturl_fmt = "http://www.openstreetmap.org/api/0.6/notes.json?limit=%d&closed=0&bbox=%s,%s,%s,%s";

my $o;
my $bbox;
my $limit = 10000;
GetOptions(
	   "o=s" => \$o,
	   "bbox=s" => \$bbox,
	   "limit=i" => \$limit,
	  )
    or die "usage: $0 -o file.bbd [ -bbox lon,lat,lon,lat | file | url ]\n";

my $url;
if ($bbox) {
    my(@bbox) = split /,/, $bbox;
    if (@bbox != 4) {
	die "Bounding box should contain of four elements lon,lat,lon,lat";
    }
    # the OSM API accepts only orders bbox coordinates
    @bbox[0,2] = sort { $a cmp $b } @bbox[0,2];
    @bbox[1,3] = sort { $a cmp $b } @bbox[1,3];
    $url = sprintf $osm_notes_rooturl_fmt, $limit, @bbox;
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
$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
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

    tie my %dir, 'Tie::IxHash';
    my $properties = $feature->{properties};
    next if $properties->{status} ne 'open'; # I think only open notes are interesting here
    my $url = $properties->{url};
    if ($url) {
	$dir{url} = [$url];
    }
    my @texts;
    tie my %users, 'Tie::IxHash';
    for my $comment (@{ $properties->{comments} || [] }) {
	push @texts, $comment->{text};
	my $user = $comment->{user} || "<unknown>";
	$users{$user}++;
    }
    my $name = join("; ", @texts);
    $name =~ s{[\n\t]}{ }g;
    my $users_directive = join(", ", map { "$_ ($users{$_}x)" } keys %users);
    $dir{users} = [$users_directive];
    $s->push_unparsed("# \n");
    $s->push_ext([$name, \@c, "?"], \%dir);
}
if (@{ $data->{features} } == $limit) {
    $s->push_unparsed("# \n");
    $s->push_unparsed("# WARNING: possibly the limit ($limit) was hit by this query ###\n");
}

$s->write($o);

__END__

=head1 NAME

osmnotes2bbd.pl - fetch and convert OSM notes to bbd files

=head1 EXAMPLES

Fetch all OSM notes for Berlin and convert to berlin_notes.bbd:

    osmnotes2bbd.pl -o /tmp/berlin_notes.bbd -bbox 13.088443,52.338064,13.760931,52.675279

=head1 AUTHOR

Slaven Rezic

=cut
