#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2016,2025 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use FindBin;
use Getopt::Long;
use Text::CSV_XS ();

GetOptions(
    "unique!"            => \my $unique,
    "add-dep-board-url!" => \my $add_dep_board_url, # add URL with departure board for selected station
)
    or die "usage: $0 [--[no]unique] [--[no]add-dep-board-url] /path/to/stops.txt\n";

my $infile = shift
    or die "Please provide path to stops.txt file as found in VBB-Fahrplandaten (try http://daten.berlin.de/datensaetze/vbb-fahrplandaten-dezember-2016-bis-august-2017 or so).\n";
open my $fh, $infile or die $!;
binmode $fh, ":utf8";
my $csv = Text::CSV_XS->new({ binary => 1})
    or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
my @keys = @{ $csv->getline($fh) };

binmode STDOUT, ':utf8';
print "#: encoding: utf8\n";
print "#: map: polar\n";
print "#:\n";

my %seen;
while (my $row = $csv->getline($fh)) {
    my %row;
    @row{@keys} = @$row;
    my $stop_name = $row{'stop_name'};
    if ($unique && $seen{$stop_name}++) {
	next;
    }
    if ($add_dep_board_url) {
	if ($row{'stop_id'} =~ m{^de:\d+:(\d+)}) {
	    my $url = sprintf "http://fahrinfo.vbb.de/bin/stboard.exe/dn?L=vs_newcms&input=%s&boardType=dep&maxJourneys=50&selectDate=today&productsFilter=111111101&start=yes&dirInput=&", $1;
	    print "#: url: $url\n";
	}
    }
    print $stop_name, "\t", "X", " ", $row{'stop_lon'}.','.$row{'stop_lat'}, "\n";
}
$csv->eof or $csv->error_diag ();
close $fh;

__END__
