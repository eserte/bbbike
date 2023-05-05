#!/usr/bin/env pistachio-perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2021,2022,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use lib "$ENV{HOME}/src/bbbike";

use File::Basename qw(dirname);
use File::Path qw(make_path);
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

my $default_limit = 2000;
my $used_limit = $default_limit;
my $max_try = 10;

my $image_api_url = 'https://graph.mapillary.com/images';

my $region = 'Berlin_DE';

my $geometry_field = 'geometry';

GetOptions(
	   "to-file" => \my $to_file,
	   "allow-override" => \my $allow_override,
	   "allow-overflow" => \my $allow_overflow,
	   "open"    => \my $do_open,
	   "used-limit=i" => \$used_limit,
	   "geometry-field=s" => \$geometry_field,
	   "max-try=i" => \$max_try,
	  )
    or die "usage?";

$geometry_field =~ m{^(computed_geometry|geometry)$}
    or die "Invalid --geometry-field type";

if ($do_open && !$to_file) {
    die "--open cannot be used without --to-file\n";
}

my $capture_date = shift
    or die "Please specify capture date (YYYY-MM-DD)\n";
@ARGV and die "usage!";
my($y,$m,$d) = split /-/, $capture_date;
if (!$d) {
    die "capture date cannot be parsed";
}

my $output_filename;
if ($to_file) {
    $output_filename = "$ENV{HOME}/.bbbike/mapillary_v4/$region/$y/" . sprintf("%04d%02d%02d", $y, $m, $d) . ".bbd";
    if (-e $output_filename && !$allow_override) {
	die "Won't override $output_filename without --allow-override.\n";
    }
}

my $bbox = Geography::Berlin_DE->new->bbox_wgs84; # XXX use $region?
my $start_captured_at = do {
    timelocal(0,0,0,$d,$m-1,$y);
#    timelocal(0,0,12,$d,$m-1,$y);
};
my $end_captured_at = do {
    timelocal(59,59,23,$d,$m-1,$y) + 1;
#    timelocal(59,14,12,$d,$m-1,$y) + 1;
};

my $ua = LWP::UserAgent->new(keep_alive => 1);

my @overflows;
my $data = fetch_images($start_captured_at, $end_captured_at);
@$data = sort {
    $a->{sequence} cmp $b->{sequence} || $a->{captured_at} <=> $b->{captured_at}
} @$data;

if (!@$data) {
    warn "INFO: no data found\n";
    exit 0;
}

my @sequences;
for my $image (@$data) {
    if (!@sequences || $sequences[-1]->[0]->{sequence} ne $image->{sequence}) {
	push @sequences, [];
    }
    push @{ $sequences[-1] }, $image;
}

my $ofh;
if (defined $output_filename) {
    my $output_dirname = dirname $output_filename;
    if (!-d $output_dirname) {
	make_path $output_dirname;
    }
    open $ofh, ">", "$output_filename~"
	or die "Can't write to $output_filename~: $!";
} else {
    $ofh = \*STDOUT;
}    

print $ofh "#: map: polar\n";
print $ofh "#: line_arrow: last\n";
print $ofh "#\n";
print $ofh "# Fetched from mapillary for bbox=@$bbox ($region) and date $capture_date\n";
print $ofh "# Used geometry field: $geometry_field\n";
print $ofh "#\n";
if (@overflows) {
    print $ofh "# Detected overflows:\n";
    for my $overflow (@overflows) {
	print $ofh "# $overflow\n";
    }
    print $ofh "#\n";
}
for my $sequence (@sequences) {
    my $id = $sequence->[0]->{id};
    my $name = join " ",
	"start_captured_at=" . strftime("%FT%T", localtime($sequence->[0]->{captured_at}/1000)),
	"end_captured_at="   . strftime("%FT%T", localtime($sequence->[-1]->{captured_at}/1000)),
	"start_id=$id",
	"sequence=$sequence->[0]->{sequence}",
	;
    my @coords = map { join(",", @{ $_->{$geometry_field}->{coordinates} || [] }) } @$sequence;
    print $ofh "#: url: https://www.mapillary.com/app/?pKey=$id&focus=photo&dateFrom=$capture_date&dateTo=$capture_date\n";
    print $ofh "$name\tX @coords\n";
}

if ($output_filename) {
    close $ofh
	or die "Error while writing file: $!";
    rename "$output_filename~", $output_filename
	or die "Error while renaming to $output_filename: $!";
    warn "INFO: written to $output_filename\n";
}

if ($do_open) {
    system 'bbbikeclient', '-strlist', $output_filename;
}

sub fetch_images {
    my($start_captured_at, $end_captured_at) = @_;
    my $start_captured_at_iso = Time::Moment->from_epoch($start_captured_at)->strftime("%FT%TZ");
    my $end_captured_at_iso   = Time::Moment->from_epoch($end_captured_at)  ->strftime("%FT%TZ");
    warn "INFO: Fetching $start_captured_at_iso .. $end_captured_at_iso...\n" if $debug;
    my $url = "$image_api_url?access_token=$client_token&fields=id,$geometry_field,captured_at,sequence&bbox=" . join(",", @$bbox) . "&start_captured_at=$start_captured_at_iso&end_captured_at=$end_captured_at_iso";

    my $data;
    for my $try (1..$max_try) {
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    my $error_data = eval { decode_json $resp->decoded_content };
	    my $msg = "Try $try/$max_try: ";
	    if ($error_data && ref $error_data eq 'HASH' && ($error_data->{error}->{error_user_title}//"") =~ m{^(Query Timeout)$}) {
		my $e = $error_data->{error};
		$msg .= "$e->{error_user_title}: $e->{error_user_msg}";
	    } else {
		$msg .= $resp->dump;
	    }
	    warn $msg, "\n";
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
	    my $sleep = $try * 2;
	    warn "INFO: sleep for $sleep seconds...\n" if $debug;
	    sleep $sleep;
	}
    }
    if (!$data) {
	die "Fetching " . scrambled_url($url) . " failed permanently";
    }

    if (@$data > $default_limit) {
	die "Unexpected: more than $default_limit items in result (" . scalar(@$data) . ")";
    }
    if (@$data >= $used_limit) {
	my $interval = $end_captured_at - $start_captured_at;
	if ($interval < 60) {
	    if ($allow_overflow) {
		push @overflows, "$start_captured_at_iso .. $end_captured_at_iso";
		return [@$data];
	    } else {
		die "Interval is/got too small: $interval ($start_captured_at_iso .. $end_captured_at_iso). Ignore this error using --allow-overflow.\n";
	    }
	}
	my $middle_captured_at = $start_captured_at + floor($interval/2);
	my $data1 = fetch_images($start_captured_at, $middle_captured_at);
	my $data2 = fetch_images($middle_captured_at, $end_captured_at);
	return [@$data1, @$data2];
    } else {
	$data;
    }
}

sub scrambled_url {
    my $url = shift;
    if (eval { require URI; require URI::QueryParam; 1 }) {
	my $u = URI->new($url);
	$u->query_param('access_token', '...');
	$url = $u->as_string;
    } else {
	$url =~ s{\?.*}{?...};
    }
    $url;
}

__END__
