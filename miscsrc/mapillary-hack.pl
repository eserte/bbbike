#!/usr/bin/env pistachio-perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2021 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use lib "$ENV{HOME}/src/bbbike";

use Getopt::Long;
use JSON::XS qw(decode_json);
use LWP::UserAgent;
use POSIX qw(floor strftime);
use Time::Moment;
use Time::Local;
use YAML::XS qw(LoadFile);

use Geography::Berlin_DE;

my $debug = 1;

my $conf_file = "$ENV{HOME}/.mapillary";
my $conf = LoadFile $conf_file;
my $client_token = $conf->{client_token} || die "Can't get client_token from $conf_file";

my $image_api_url = 'https://graph.mapillary.com/images';

GetOptions("to-file" => \my $to_file)
    or die "usage?";

my $capture_date = shift
    or die "Please specify capture date (YYYY-MM-DD)\n";
@ARGV and die "usage!";
my($y,$m,$d) = split /-/, $capture_date;
if (!$d) {
    die "capture date cannot be parsed";
}

my($ofh, $output_filename);
if ($to_file) {
    $output_filename = "$ENV{HOME}/.bbbike/mapillary_v4/Berlin_DE/$y/" . sprintf("%04d%02d%02d", $y, $m, $d) . ".bbd";
    open $ofh, ">", "$output_filename~"
	or die "Can't write to $output_filename~: $!";
} else {
    $ofh = \*STDOUT;
}    

my $bbox = Geography::Berlin_DE->new->bbox_wgs84;
my $start_captured_at = do {
    timelocal(0,0,0,$d,$m-1,$y);
#    timelocal(0,0,12,$d,$m-1,$y);
};
my $end_captured_at = do {
    timelocal(59,59,23,$d,$m-1,$y) + 1;
#    timelocal(59,14,12,$d,$m-1,$y) + 1;
};

my $ua = LWP::UserAgent->new(keep_alive => 1);

my $data = fetch_images($start_captured_at, $end_captured_at);
@$data = sort {
    $a->{sequence} cmp $b->{sequence} || $a->{captured_at} <=> $b->{captured_at}
} @$data;

my @sequences;
for my $image (@$data) {
    if (!@sequences || $sequences[-1]->[0]->{sequence} ne $image->{sequence}) {
	push @sequences, [];
    }
    push @{ $sequences[-1] }, $image;
}

print $ofh "#: map: polar\n";
print $ofh "#\n";
print $ofh "# Fetched from mapillary for bbox=@$bbox (Berlin) and date $capture_date\n";
for my $sequence (@sequences) {
    my $name = join " ",
	"start_captured_at=" . strftime("%FT%T", localtime($sequence->[0]->{captured_at}/1000)),
	"end_captured_at="   . strftime("%FT%T", localtime($sequence->[-1]->{captured_at}/1000)),
	"start_id=$sequence->[0]->{id}",
	"sequence=$sequence->[0]->{sequence}",
	;
    my @coords = map { join(",", @{ $_->{computed_geometry}->{coordinates} }) } @$sequence;
    print $ofh "$name\tX @coords\n";
}

if ($output_filename) {
    close $ofh
	or die "Error while writing file: $!";
    rename "$output_filename~", $output_filename
	or die "Error while renaming to $output_filename: $!";
    warn "INFO: written to $output_filename\n";
}

sub fetch_images {
    my($start_captured_at, $end_captured_at) = @_;
    my $start_captured_at_iso = Time::Moment->from_epoch($start_captured_at)->strftime("%FT%TZ");
    my $end_captured_at_iso   = Time::Moment->from_epoch($end_captured_at)  ->strftime("%FT%TZ");
    warn "INFO: Fetching $start_captured_at_iso .. $end_captured_at_iso...\n" if $debug;
    my $url = "$image_api_url?access_token=$client_token&fields=id,computed_geometry,captured_at,sequence&bbox=" . join(",", @$bbox) . "&start_captured_at=$start_captured_at_iso&end_captured_at=$end_captured_at_iso";

    my $data;
    my $max_try = 5;
    for my $try (1..$max_try) {
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    warn "Try $try/$max_try: " . $resp->dump;
	} else {
	    my $content = $resp->decoded_content;
	    $data = eval { decode_json $content };
	    if (!$data) {
		warn "Decoding JSON failed: $@";
	    } else {
		if (!$data->{data} || ref $data->{data} ne 'ARRAY') {
		    warn "Mapillary error: $content";
		    undef $data;
		} else {
		    # success, set $data
		    $data = $data->{data};
		    last;
		}
	    }
	}
	if ($try < $max_try) {
	    warn "INFO: sleep for $try seconds...\n" if $debug;
	    sleep $try;
	}
    }
    if (!$data) {
	die "Fetching $url failed permanently";
    }

    my $default_limit = 2000;
    if (@$data > $default_limit) {
	die "Unexpected: more than $default_limit items in result (" . scalar(@$data) . ")";
    }
    if (@$data == $default_limit) {
	my $interval = $end_captured_at - $start_captured_at;
	if ($interval < 60) {
	    die "Interval is/got too small: $interval ($start_captured_at_iso .. $end_captured_at_iso)";
	}
	my $middle_captured_at = $start_captured_at + floor($interval/2);
	my $data1 = fetch_images($start_captured_at, $middle_captured_at);
	my $data2 = fetch_images($middle_captured_at, $end_captured_at);
	return [@$data1, @$data2];
    } else {
	$data;
    }
}

__END__
