#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2022,2023 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;

use File::Glob qw(bsd_glob);
use Getopt::Long;
use IO::Uncompress::Gunzip;
use Text::CSV_XS;

my %date_to_bf10;
my $station = '403'; # hardcode to Dahlem for now
my $station_name = 'Berlin-Dahlem'; # -"-
my $soil_dwd_dir;
my $data_dir = "$FindBin::RealBin/../data";

GetOptions(
    "soil-dwd-dir=s" => \$soil_dwd_dir
)
    or die "$0 --soil-dwd-dir ...\n";

$soil_dwd_dir or die "Please specify --soil-dwd-dir option!";

sub trim { $_[0] =~ s/^\s+//r }

for my $f (bsd_glob("$soil_dwd_dir/*/*_$station.txt.gz")) {
    my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1, sep_char => ';' });
    my $fh = IO::Uncompress::Gunzip->new($f)
	or die "Can't gunzip $f: $!";
    my @cols = @{ $csv->getline($fh) };
    $csv->column_names(@cols);
    while(my $row = $csv->getline_hr($fh)) {
	my $Datum = $row->{Datum} // die "No Datum?";
	my $bf10 = trim($row->{BF10} // die "No BF10?");
	$date_to_bf10{$Datum} = $bf10;
    }
}

my $ofile = "/tmp/mudways_enriched.bbd";
open my $fh, "$data_dir/mudways" or die $!;
open my $ofh, ">", "$ofile~" or die $!;
my $in_global_directives = 1;
while(<$fh>) {
    if ($in_global_directives) {
	if (/^#:\s+$/) {
	    # XXX In future different station might be used, depending on distance from point.
	    print $ofh "#: soil_moisture_station_name: $station_name\n";
	    print $ofh "#: soil_moisture_station_number: $station\n";
	    $in_global_directives = 0;
	}
    }
    s{(#: title: Matschige Wege und Pfützen)}{$1 (angereichert mit Bodenfeuchtewerten aus Dahlem)};
    s{^(?<pre>\#:\s+mud:\s+)(?<date>(?<y>\d{4})-(?<m>\d{2})-(?<d>\d{2}):)}{
	my $d = $+{y}.$+{m}.$+{d};
	my $bf = $date_to_bf10{$d} // 'N/A';
	$+{pre} . $+{date} . " BF10=" . sprintf("%-4s", "$bf:");
    }xe;
    print $ofh $_;
}
close $ofh or die $!;
rename "$ofile~", $ofile or die $!;
chmod 0444, $ofile;

print STDERR "INFO: written $ofile\n";

__END__
