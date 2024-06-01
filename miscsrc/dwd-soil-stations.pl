#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2020,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Fetch the list of DWD stations reporting soil data (Bodenfeuchte),
# create a bbd file and store it to
#
#    ~/src/bbbike/tmp/dwd-soil-stations.bbd
#
# To fetch and open automatically in bbbike use
#
#    ~/src/bbbike-aux/misc/dwd-soil-stations.pl --open
# 

use lib "$ENV{HOME}/src/bbbike/lib";
use Doit;
use Doit::Log;
use Getopt::Long;

my $bbbike_root = "$ENV{HOME}/src/bbbike";
my $url = 'https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/recent/derived_germany_soil_daily_recent_stations_list.txt';
my $cache = "$bbbike_root/tmp/derived_germany_soil_daily_recent_stations_list.txt";
my $bbd = "$bbbike_root/tmp/dwd-soil-stations.bbd";
my $number_first;

my $doit = Doit->init;

GetOptions(
	   "open" => \my $do_open,
	   "number-first!" => \$number_first,
	  )
    or error "usage: $0 [--dry-run] [--number-first] [--open]\n";

$doit->add_component('lwp');
$doit->add_component('file');
if ($doit->lwp_mirror($url, $cache) || !-s $bbd) {
    $doit->file_atomic_write
	($bbd,
	 sub {
	     my($ofh) = @_;
	     open my $ifh, $cache
		 or die "Can't open $cache: $!";
	     chomp(my $header = <$ifh>);
	     my(@f) = split /\s*;/, $header;
	     error "Unexpected column 0 ($f[0])" if $f[0] ne 'Stationsindex';
	     error "Unexpected column 2 ($f[2])" if $f[2] ne 'Breite';
	     error "Unexpected column 3 ($f[3])" if $f[3] ne 'Länge';
	     error "Unexpected column 4 ($f[4])" if $f[4] ne 'Name';
	     print $ofh "#: map: polar\n";
	     print $ofh "#:\n";
	     while(<$ifh>) {
		 chomp; s/\r$//; s/^\s+//;
		 my(@f) = split /\s*;\s*/, $_;
		 my $name = $number_first ? "$f[0] - $f[4]" : "$f[4] - $f[0]";
		 print $ofh "$name\tX $f[3],$f[2]\n";
	     }
	 });
}
if ($do_open) {
    $doit->system("$bbbike_root/bbbikeclient", "-strlist", $bbd);
}

__END__
