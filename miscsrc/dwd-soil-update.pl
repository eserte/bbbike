#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023,2024,2025 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use File::Basename qw(basename);
use File::Path qw(make_path);
use Getopt::Long;
use LWP::UserAgent;
use IO::Uncompress::Gunzip qw($GunzipError);

use lib "$FindBin::RealBin/..";

use BBBikeUtil qw(bbbike_root bbbike_aux_dir);

# XXX make list of stations configurable?
my %stations = qw(
    400 Buch
    403 Dahlem
    420 Marzahn
    427 Schoenefeld
    433 Tempelhof
);
# There's also
#    430 Tegel
# but observations stopped at 20210502.

my $q;
my $soil_dwd_dir;
my $for_date;
my $as = 'text';
GetOptions(
    "q|quiet" => \$q,
    "soil-dwd-dir=s" => \$soil_dwd_dir,
    "date=s" => \$for_date,
    "as=s" => \$as,
)
    or die "usage: $0 [-q] [--soil-dwd-dir /path/to/directory] [--date YYYY-MM-DD] [--as text|json]\n";

$as =~ m{^(text|json)$}
    or die "--as can only be text (default) or json\n";
if ($as eq 'json') {
    require JSON::PP;
}

if ($for_date) {
    $for_date =~ s/-//g;
    if ($for_date !~ /^\d{8}$/) {
	die "--date value must by YYYY-MM-DD or YYYYMMDD\n";
    }
}

if (bbbike_aux_dir) {
    $soil_dwd_dir = bbbike_aux_dir . "/data/soil_dwd";
} else {
    $soil_dwd_dir = bbbike_root . "/tmp/soil_dwd";
    for my $subdir (qw(recent historical)) {
	if (!-d "$soil_dwd_dir/$subdir") {
	    warn "INFO: create $soil_dwd_dir/$subdir directory...";
	    make_path "$soil_dwd_dir/$subdir";
	}
    }
}

my $pm = do {
    if (eval { require Parallel::ForkManager; 1 }) {
	Parallel::ForkManager->new(10);
    } else {
	undef;
    }
};

my $ua = LWP::UserAgent->new;

chdir "$soil_dwd_dir/recent" or die "Can't chdir to $soil_dwd_dir/recent: $!";
FETCH_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
    my $pid = $pm and $pm->start and next FETCH_LOOP;
    warn "INFO: update station $station ($stations{$station})...\n" unless $q;
    my $url = "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/recent/derived_germany_soil_daily_recent_v2_$station.txt.gz";
    my $resp = $ua->mirror($url, basename($url));
    $resp->code < 400
	or die "Mirroring $url failed: " . $resp->dump;
    $pm and $pm->finish;
}
$pm and $pm->wait_all_children;

chdir "$soil_dwd_dir/historical" or die "Can't chdir to $soil_dwd_dir/historical: $!";
FETCH_HISTORICAL_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
    print STDERR "INFO: check for historical data from station $station ($stations{$station})... " unless $q;
    my $historical_file = "derived_germany_soil_daily_historical_v2_${station}.txt.gz";
    my $need_update;
    if (!-e $historical_file) {
	print STDERR " historical file does not exist -> need update\n";
	$need_update = 1;
    } else {
	my $last_historical_line = sub {
	    my $fh = IO::Uncompress::Gunzip->new($historical_file)
		or die "Can't gunzip $historical_file: $GunzipError\n";
	    my $last_line;
	    while(<$fh>) {
		$last_line = $_;
	    }
	    $last_line;
	}->();
	my(undef, $historical_date) = split /;/, $last_historical_line;
	my $historical_year = substr($historical_date, 0, 4);
	my $first_recent_line = sub {
	    my $recent_file = "$soil_dwd_dir/recent/derived_germany_soil_daily_recent_v2_${station}.txt.gz";
	    my $fh = IO::Uncompress::Gunzip->new($recent_file)
		or die "Can't gunzip $recent_file: $GunzipError\n";
	    <$fh>; # header
	    scalar <$fh>; # first recent line
	}->();
	my(undef, $recent_date) = split /;/, $first_recent_line;
	my $recent_year = substr($recent_date, 0, 4);
	if ($recent_year - $historical_year != 1) {
	    print STDERR " historical file not up-to-date (historical year=$historical_year vs recent year=$recent_year) -> need update\n" unless $q;
	    $need_update = 1;
	} else {
	    print STDERR " historical file is up-to-date\n" unless $q;
	}
    }
    if ($need_update) {
	my $pid = $pm and $pm->start and next FETCH_HISTORICAL_LOOP;
	my $url = "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/historical/$historical_file";
	my $resp = $ua->get($url, ':content_file' => basename($url));
	$resp->is_success
	    or die "Fetching $url failed: " . $resp->dump;
	$pm and $pm->finish;
    }
}
$pm and $pm->wait_all_children;

my $res;

# Note:
# - for v1 files the BF10 field (index 11) was printed
# - for v2 files the BFGL01_AG field (index 12) is printed
my $date_index = 1;
my $bf_index = 12;
chdir "$soil_dwd_dir/recent" or die "Can't chdir to $soil_dwd_dir/recent: $!";
for my $station (sort {$a<=>$b} keys %stations) {
    my $f = "derived_germany_soil_daily_recent_v2_${station}.txt.gz";
    my $fh = IO::Uncompress::Gunzip->new($f)
	or die "Can't gunzip $f (in directory $soil_dwd_dir/recent): $GunzipError\n";
    my $got_line;
    while(<$fh>) {
	chomp;
	if (defined $for_date) {
	    my @f = split /;/, $_;
	    next if $f[$date_index] ne $for_date;
	    $got_line = $_;
	    last;
	} else {
	    if (eof $fh) {
		$got_line = $_;
		last;
	    }
	}
    }
    my $station_id = $stations{$station}||$station;
    my $this_res;
    if ($as ne 'text') {
	$this_res->{station_id}   = $station;
	$this_res->{station_name} = $stations{$station};
    }
    if (!$got_line) {
	if ($as ne 'text') {
	    if (defined $for_date) {
		$this_res->{date} = $for_date;
	    }
	    $this_res->{BF10} = undef;
	} else {
	    printf "%-12s: no data\n", $station_id;
	}
    } else {
	my @f = split /;/, $got_line;
	my $date = $f[$date_index];
	my $bf10 = $f[$bf_index];
	if ($as ne 'text') {
	    $this_res->{date} = $date;
	    $bf10 =~ s{\s+}{}g; $bf10 += 0;
	    $this_res->{BF10} = $bf10;
	} else {
	    printf "%-12s: %s %s\n", $station_id, $date, $bf10;
	}
    }
    if ($as ne 'text') {
	$res->{$station} = $this_res;
    }
}

if ($as eq 'json') {
    print JSON::PP::encode_json($res), "\n";
}

__END__
