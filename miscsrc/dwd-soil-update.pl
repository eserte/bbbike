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
my $has_lwp = eval { require LWP::UserAgent; 1 };
if (!$has_lwp) {
    require HTTP::Tiny;
}
use IO::Uncompress::Gunzip qw($GunzipError);
use IO::Uncompress::Unzip qw($UnzipError);

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
# Mapping to 5-digit station IDs for hourly precipitation data
my %precip_stations = qw(
    400 00400
    403 00403
    420 00420
    427 00427
    433 00433
);
# There's also
#    430 Tegel
# but observations stopped at 20210502.

my $q;
my $soil_dwd_dir;
my $for_date;
my $as = 'text';
my $adjust_by_precip;
my $precip_factor = 4.0; # +4% nFK per 1mm rain
my $precip_max = 120;
GetOptions(
    "q|quiet" => \$q,
    "soil-dwd-dir=s" => \$soil_dwd_dir,
    "date=s" => \$for_date,
    "as=s" => \$as,
    "adjust-by-precip" => \$adjust_by_precip,
    "precip-factor=f" => \$precip_factor,
    "precip-max=i" => \$precip_max,
)
    or die "usage: $0 [-q] [--soil-dwd-dir /path/to/directory] [--date YYYY-MM-DD] [--as text|json|mapping] [--adjust-by-precip] [--precip-factor factor] [--precip-max max_bf10]\n";

$as =~ m{^(text|json|mapping)$}
    or die "--as can only be text (default) or json or mapping\n";
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
}
for my $subdir (qw(recent historical precip)) {
    if (!-d "$soil_dwd_dir/$subdir") {
	warn "INFO: create $soil_dwd_dir/$subdir directory...";
	make_path "$soil_dwd_dir/$subdir";
    }
}

my $pm = do {
    if (eval { require Parallel::ForkManager; 1 }) {
	Parallel::ForkManager->new(10);
    } else {
	undef;
    }
};

my $ua = $has_lwp ? LWP::UserAgent->new : HTTP::Tiny->new;

chdir "$soil_dwd_dir/recent" or die "Can't chdir to $soil_dwd_dir/recent: $!";
FETCH_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
    my $pid = $pm and $pm->start and next FETCH_LOOP;
    warn "INFO: update station $station ($stations{$station})...\n" unless $q;
    my $url = "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/recent/derived_germany_soil_daily_recent_v2_$station.txt.gz";
    $url =~ s{^https:}{http:} if !$has_lwp;
    if ($has_lwp) {
	my $resp = $ua->mirror($url, basename($url));
	$resp->code < 400
	    or die "Mirroring $url failed: " . $resp->dump;
    } else {
	my $resp = $ua->mirror($url, basename($url));
	$resp->{success}
	    or die "Mirroring $url failed: $resp->{status} $resp->{reason}";
    }
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
	$url =~ s{^https:}{http:} if !$has_lwp;
	if ($has_lwp) {
	    my $resp = $ua->get($url, ':content_file' => basename($url));
	    $resp->is_success
		or die "Fetching $url failed: " . $resp->dump;
	} else {
	    my $resp = $ua->mirror($url, basename($url));
	    $resp->{success}
		or die "Mirroring $url failed: $resp->{status} $resp->{reason}";
	}
	$pm and $pm->finish;
    }
}
$pm and $pm->wait_all_children;

if ($adjust_by_precip) {
    my $precip_dir = "$soil_dwd_dir/precip";
    FETCH_PRECIP_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
	my $precip_station = $precip_stations{$station};
	next if !$precip_station;

	my $pid = $pm and $pm->start and next FETCH_PRECIP_LOOP;
	warn "INFO: update precipitation for station $station ($stations{$station})...\n" unless $q;
	for my $type (qw(hourly 10min)) {
	    my $url = ($type eq 'hourly')
		? "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/hourly/precipitation/recent/stundenwerte_RR_${precip_station}_akt.zip"
		: "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/10_minutes/precipitation/now/10minutenwerte_nieder_${precip_station}_now.zip";
	    my $target = "$precip_dir/precip_${type}_${precip_station}.zip";
	    $url =~ s{^https:}{http:} if !$has_lwp;
	    if ($has_lwp) {
		my $resp = $ua->mirror($url, $target);
		# 404 is acceptable for 'now' files
		$resp->code < 400 || ($type eq '10min' && $resp->code == 404)
		    or die "Mirroring $url failed: " . $resp->dump;
	    } else {
		my $resp = $ua->mirror($url, $target);
		$resp->{success} || ($type eq '10min' && $resp->{status} == 404)
		    or die "Mirroring $url failed: $resp->{status} $resp->{reason}";
	    }
	}
	$pm and $pm->finish;
    }
    $pm and $pm->wait_all_children;
}

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
	if (defined $for_date) {
	    $this_res->{date} = $for_date;
	}
	$this_res->{BF10} = undef;
    } else {
	my @f = split /;/, $got_line;
	my $date = $f[$date_index];
	my $bf10 = $f[$bf_index];
	$date =~ s{\s+}{}g;
	$bf10 =~ s{\s+}{}g; $bf10 += 0;
	$this_res->{date} = $date;
	$this_res->{BF10} = $bf10;
    }

    if ($as eq 'text') {
	if (!defined $this_res->{BF10}) {
	    printf "%-12s: no data\n", $station_id;
	} else {
	    printf "%-12s: %s %s\n", $station_id, $this_res->{date}, $this_res->{BF10};
	}
    }
    if ($adjust_by_precip && $this_res->{date} && defined $this_res->{BF10}) {
	my $precip_station = $precip_stations{$station};
	my %precip_by_10min;
	for my $type (qw(hourly 10min)) {
	    my $precip_file = "$soil_dwd_dir/precip/precip_${type}_${precip_station}.zip";
	    if (-e $precip_file) {
		my $u = IO::Uncompress::Unzip->new($precip_file)
		    or die "Can't open $precip_file: $UnzipError";
		while (my $status = $u->nextStream) {
		    my $name = $u->getHeaderInfo->{Name};
		    if ($name =~ /^produkt_(rr_stunde|zehn_now_rr)_.*\.txt$/) {
			my $header = <$u>;
			my @cols = split /;/, $header;
			my $date_idx;
			my $precip_idx;
			for my $i (0 .. $#cols) {
			    my $col = $cols[$i];
			    $col =~ s/^\s+|\s+$//g;
			    $date_idx = $i if $col eq 'MESS_DATUM';
			    $precip_idx = $i if $col =~ /^(R1|RWS_10)$/;
			}
			if (defined $date_idx && defined $precip_idx) {
			    # soil date is YYYYMMDD, hourly date is YYYYMMDDHH, 10min is YYYYMMDDHHMM
			    my $soil_date_limit = $this_res->{date} . "23" . ($type eq '10min' ? "59" : "");
			    while (<$u>) {
				my @f = split /;/, $_;
				my $m_date = $f[$date_idx];
				$m_date =~ s/^\s+|\s+$//g;
				if ($m_date > $soil_date_limit) {
				    my $val = $f[$precip_idx];
				    $val =~ s/^\s+|\s+$//g;
				    if ($val >= 0) {
					if ($type eq 'hourly') {
					    for my $mm (qw(00 10 20 30 40 50)) {
						$precip_by_10min{$m_date . $mm} = $val / 6;
					    }
					} else {
					    $precip_by_10min{$m_date} = $val;
					}
				    }
				}
			    }
			}
			last;
		    }
		}
	    }
	}
	my $sum_precip = 0;
	$sum_precip += $_ for values %precip_by_10min;
	if ($sum_precip > 0) {
	    my $adjustment = int($sum_precip * $precip_factor + 0.5);
	    my $old_bf10 = $this_res->{BF10};
	    $this_res->{BF10} += $adjustment;
	    if ($this_res->{BF10} > $precip_max) {
		$this_res->{BF10} = $precip_max;
	    }
	    if ($as eq 'text') {
		printf "  (adjusted by precip: %.1fmm * %.1f -> %d -> %d)\n", $sum_precip, $precip_factor, $adjustment, $this_res->{BF10};
	    }
	    $this_res->{precip_sum} = $sum_precip;
	    $this_res->{bf10_old} = $old_bf10;
	}
    }

    if ($as ne 'text') {
	$res->{$station} = $this_res;
    }
}

if ($as eq 'json') {
    print JSON::PP::encode_json($res), "\n";
} elsif ($as eq 'mapping') {
    my $bf10_mapping = join(',', map { $_->{station_id}.':'.$_->{BF10} } grep { defined $_->{BF10} } values %$res);
    print $bf10_mapping;
}

__END__
