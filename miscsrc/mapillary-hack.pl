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

my $debug = 1;

my $conf_file = "$ENV{HOME}/.mapillary";
my $conf = LoadFile $conf_file;
my $client_token = $conf->{client_token} || die "Can't get client_token from $conf_file";

my $default_limit = 2000;
my $used_limit = $default_limit;
my $max_try = 10;

my $image_api_url = 'https://graph.mapillary.com/images';

my $geometry_field = 'geometry';

my($start_date, $end_date);
my $bbox;

GetOptions(
	   "to-file" => \my $to_file,
	   "region=s" => \my $region,
	   "o=s" => \my $output_filename,
	   "allow-override" => \my $allow_override,
	   "allow-overflow" => \my $allow_overflow,
	   "open"    => \my $do_open,
	   "used-limit=i" => \$used_limit,
	   "geometry-field=s" => \$geometry_field,
	   "max-try=i" => \$max_try,
	   "start-date=s" => \$start_date,
	   "end-date=s"   => \$end_date,
	   "bbox=s"       => \$bbox,
	   "debug!"       => \$debug,
	  )
    or die "usage?";

$geometry_field =~ m{^(computed_geometry|geometry)$}
    or die "Invalid --geometry-field type";

if ($output_filename && $to_file) {
    die "--to-file and -o cannot be used together";
}

if ($start_date && !$end_date) {
    $end_date = strftime "%Y-%m-%d", localtime;
}
if (!$start_date && $end_date) {
    die "Please specify --start-date.\n";
}
if (!$start_date && !$end_date) {
    my $capture_date = shift
	or die "Please specify capture date (YYYY-MM-DD)\n";
    $start_date = $end_date = $capture_date;
}
if ($to_file) {
    if ($start_date ne $end_date) {
	die "--to-file can be used only with a single day (--start-date and --end-date must be the same).\n";
    }
    if (!$region) {
	$region = 'Berlin_DE';
    }
}
if ($region && !$to_file) {
    die "--region must be used together with --to-file.\n";
}
@ARGV and die "usage!";
my($y0,$m0,$d0) = split /-/, $start_date;
if (!$d0) {
    die "start date cannot be parsed";
}
my($y1,$m1,$d1) = split /-/, $end_date;
if (!$d1) {
    die "end date cannot be parsed";
}

if ($to_file) {
    my $mod = 'Geography::' . $region;
    if (!eval "use $mod; 1") {
	die $@;
    }
    $bbox = $mod->new->bbox_wgs84;
    $output_filename = "$ENV{HOME}/.bbbike/mapillary_v4/$region/$y0/" . sprintf("%04d%02d%02d", $y0, $m0, $d0) . ".bbd";
} elsif (!$bbox) {
    die "No bounding box specified. Please use either --bbox or --to-file+--region.\n";
} else {
    $bbox = [split /,/, $bbox];
    die "Four elements expected in --bbox (lon,lat,lon,lat).\n" if @$bbox != 4;
    if ($bbox->[0]>$bbox->[2]) { ($bbox->[2],$bbox->[0]) = ($bbox->[0],$bbox->[2]) }
    if ($bbox->[1]>$bbox->[3]) { ($bbox->[3],$bbox->[1]) = ($bbox->[1],$bbox->[3]) }
}

if (-e $output_filename && !$allow_override) {
    die "Won't override $output_filename without --allow-override.\n";
}

if ($do_open && !$output_filename) {
    die "--open cannot be used without --to-file/-o\n";
}

my $start_captured_at = do {
    timelocal(0,0,0,$d0,$m0-1,$y0);
};
my $end_captured_at = do {
    timelocal(59,59,23,$d1,$m1-1,$y1) + 1;
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
print $ofh "# Fetched from mapillary for bbox=@$bbox " . (defined $region ? "($region) " : "") . "and date " . ($start_date eq $end_date ? $start_date : "$start_date-$end_date") . "\n";
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
    my $creator = $sequence->[0]->{creator}->{username};
    my $make = $sequence->[0]->{make};
    my $name = join " ",
	"start_captured_at=" . strftime("%FT%T", localtime($sequence->[0]->{captured_at}/1000)),
	(defined $creator ? "creator=$creator" : ()),
	(defined $make ? "make=$make" : ()),
	"end_captured_at="   . strftime("%FT%T", localtime($sequence->[-1]->{captured_at}/1000)),
	"start_id=$id",
	"sequence=$sequence->[0]->{sequence}",
	;
    my @coords = map { join(",", @{ $_->{$geometry_field}->{coordinates} || [] }) } @$sequence;
    print $ofh "#: url: https://www.mapillary.com/app/user/$creator?pKey=$id&focus=photo&dateFrom=$start_date&dateTo=$end_date\n";
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
    my $url = "$image_api_url?access_token=$client_token&fields=id,creator,make,$geometry_field,captured_at,sequence&bbox=" . join(",", @$bbox) . "&start_captured_at=$start_captured_at_iso&end_captured_at=$end_captured_at_iso";
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
