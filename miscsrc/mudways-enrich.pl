#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2022,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use 5.014; # //, s///r
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use File::Glob qw(bsd_glob);
use Getopt::Long;
use IO::Uncompress::Gunzip;
use Text::CSV_XS;

use Karte;
Karte::preload(qw(Polar Standard));
$Karte::Polar::obj = $Karte::Polar::obj if 0; # cease -w
use Strassen::Core;
use Strassen::Util;

# manually taken from dwd-soil-stations.bbd
my %stations = (
		400 => { name => 'Berlin-Buch',        pos => '13.50,52.63' },
		403 => { name => 'Berlin-Dahlem',      pos => '13.30,52.45' }, # FU
		420 => { name => 'Berlin-Marzahn',     pos => '13.56,52.55' },
		427 => { name => 'Berlin Brandenburg', pos => '13.53,52.38' }, # aka Schönefeld
		433 => { name => 'Berlin-Tempelhof',   pos => '13.40,52.47' },
	       );

while(my($station_nr, $station) = each %stations) {
    my($lon,$lat) = split /,/, $station->{pos};
    my($sx,$sy) = map { int } $Karte::Polar::obj->map2standard($lon, $lat);
    $station->{pos_bbbike} = "$sx,$sy";
}

my %station_to_date_to_bf10;
my $soil_dwd_dir;
my $data_dir = "$FindBin::RealBin/../data";
my($fix_station, $fix_station_name);

GetOptions(
    "soil-dwd-dir=s" => \$soil_dwd_dir,
    "fix-station=i" => \$fix_station,
)
    or die "$0 --soil-dwd-dir ... [--fix-station nr]\n";

$soil_dwd_dir or die "Please specify --soil-dwd-dir option!";

if ($fix_station) {
    $fix_station_name = $stations{$fix_station}->{name};
    if (!defined $fix_station_name) {
	warn "No information for station $fix_station available (continue anyway).\n";
	$fix_station_name = "station $fix_station";
    }
}

sub trim { $_[0] =~ s/^\s+//r }

my @station_nrs = $fix_station ? ($fix_station) : (sort keys %stations);

for my $station_nr (@station_nrs) {
    my $glob = "$soil_dwd_dir/*/*_${station_nr}.txt.gz";
    my @files = bsd_glob($glob); 
    if (!@files) {
	die "No files found for station $station_nr (tried glob '$glob')\n";
    }
    for my $f (@files) {
	my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1, sep_char => ';' });
	my $fh = IO::Uncompress::Gunzip->new($f)
	    or die "Can't gunzip $f: $!";
	my @cols = @{ $csv->getline($fh) };
	$csv->column_names(@cols);
	while(my $row = $csv->getline_hr($fh)) {
	    my $Datum = $row->{Datum} // die "No Datum?";
	    my $bf10 = trim($row->{BF10} // die "No BF10?");
	    $station_to_date_to_bf10{$station_nr}{$Datum} = $bf10;
	}
    }
}

my $srcbase = "mudways";
my $ofile = "/tmp/mudways_enriched.bbd";
open my $fh, "$data_dir/$srcbase" or die "Can't open $data_dir/$srcbase: $!";
open my $ofh, ">", "$ofile~" or die "Can't write to $ofile~: $!";
my $in_global_directives = 1;
my @current_local_directives;
my $source_file_printed = 0;
while(<$fh>) {
    if ($in_global_directives) {
	s{(#: title: Matschige Wege und Pfützen)}{"$1 (angereichert mit Bodenfeuchtewerten" . ($fix_station ? " aus $fix_station_name" : "") . ")"}e;
	if (/^#:\s+$/) {
	    if ($fix_station) {
		print $ofh "#: soil_moisture_station_name: $fix_station_name\n";
		print $ofh "#: soil_moisture_station_number: $fix_station\n";
	    }
	    $in_global_directives = 0;
	}
	print $ofh $_;
    } else {
	if (/^#:/) {
	    push @current_local_directives, $_;
	} elsif (/^#/) {
	    print $ofh $_;
	} else {
	    my $bbd_line = $_;
	    if (!$source_file_printed) {
		print $ofh "#: source_file: $srcbase\n";
		$source_file_printed = 1;
	    }
	    print $ofh "#: source_line: $.\n";
	    my $use_station_nr;
	    if (!$fix_station) {
		my $r = Strassen::parse($bbd_line);
		my @c = @{ $r->[Strassen::COORDS] };
		my $middle_point = $c[$#c/2];
		($use_station_nr,my($distance)) = get_best_station_nr($middle_point);
		my $station_name = $stations{$use_station_nr}->{name};
		print  $ofh "#: soil_moisture_station_name: $station_name\n";
		print  $ofh "#: soil_moisture_station_number: $use_station_nr\n";
		printf $ofh "#: soil_moisture_station_distance: %dm\n", $distance;
	    } else {
		$use_station_nr = $fix_station;
	    }
	    for my $local_directive (@current_local_directives) {
		$local_directive =~ s{^(?<pre>\#:\s+mud:\s+)(?<date>(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2}):)}{
		    my $d = $+{y}.$+{m}.$+{d};
		    my $bf = $station_to_date_to_bf10{$use_station_nr}{$d} // 'N/A';
		    $+{pre} . $+{date} . " BF10=" . sprintf("%-4s", "$bf:");
		}xe;
		print $ofh $local_directive;
	    }
	    @current_local_directives = ();
	    print $ofh $bbd_line;
	}
    }
}
close $ofh or die $!;
rename "$ofile~", $ofile or die $!;
chmod 0444, $ofile;

print STDERR "INFO: written $ofile\n";

sub get_best_station_nr {
    my($point) = @_;
    my $best_station_nr;
    my $best_distance;
    while(my($station_nr, $station) = each %stations) {
	my $distance = Strassen::Util::strecke_s($point, $station->{pos_bbbike});
	if (!defined $best_distance || $best_distance > $distance) {
	    $best_distance = $distance;
	    $best_station_nr = $station_nr;
	}
    }
    if (!defined $best_station_nr) {
	die "Should never happen: no best station found for point $point";
    }
    ($best_station_nr, $best_distance);
}

__END__
