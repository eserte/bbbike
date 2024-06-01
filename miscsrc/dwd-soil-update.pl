#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use File::Path qw(make_path);
use Getopt::Long;

use lib "$FindBin::RealBin/..";

use BBBikeUtil qw(bbbike_root bbbike_aux_dir);

my $soil_dwd_dir;
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
GetOptions("q|quiet" => \$q)
    or die "usage: $0 [-q]\n";

my $pm = do {
    if (eval { require Parallel::ForkManager; 1 }) {
	Parallel::ForkManager->new(10);
    } else {
	undef;
    }
};

chdir "$soil_dwd_dir/recent" or die "Can't chdir to $soil_dwd_dir/recent: $!";
FETCH_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
    my $pid = $pm and $pm->start and next FETCH_LOOP;
    warn "INFO: update station $station ($stations{$station})...\n" unless $q;
    my @cmd = ('wget', '--quiet', '-N', "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/recent/derived_germany_soil_daily_recent_$station.txt.gz");
    system @cmd;
    if ($? != 0) { die "Command '@cmd' failed" }
    $pm and $pm->finish;
}
$pm and $pm->wait_all_children;

chdir "$soil_dwd_dir/historical" or die "Can't chdir to $soil_dwd_dir/historical: $!";
FETCH_HISTORICAL_LOOP: for my $station (sort {$a<=>$b} keys %stations) {
    print STDERR "INFO: check for historical data from station $station ($stations{$station})... " unless $q;
    my $historical_file = "derived_germany_soil_daily_historical_${station}.txt.gz";
    my $need_update;
    if (!-e $historical_file) {
	print STDERR " historical file does not exist -> need update\n";
	$need_update = 1;
    } else {
	my $last_historical_line = `gunzip -c $historical_file | tail -1`;
	my(undef, $historical_date) = split /;/, $last_historical_line;
	my $historical_year = substr($historical_date, 0, 4);
	my $recent_file = "$soil_dwd_dir/recent/derived_germany_soil_daily_recent_${station}.txt.gz";
	my $first_recent_line = `gunzip -c $recent_file | head -2 | tail -1`;
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
	my @cmd = ('curl', '--silent', '-O', "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/historical/derived_germany_soil_daily_historical_${station}.txt.gz");
	system @cmd;
	if ($? != 0) { die "Command '@cmd' failed" }
	$pm and $pm->finish;
    }
}
$pm and $pm->wait_all_children;

chdir "$soil_dwd_dir/recent" or die "Can't chdir to $soil_dwd_dir/recent: $!";
for my $station (sort {$a<=>$b} keys %stations) {
    chomp(my $last_line = `gunzip -c derived_germany_soil_daily_recent_${station}.txt.gz | tail -1`);
    my @f = split /;/, $last_line;
    printf "%-12s: %s %s\n", $stations{$station}||$station, $f[1], $f[11];
}

__END__
