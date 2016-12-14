#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2016 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use Text::CSV_XS ();

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

while (my $row = $csv->getline($fh)) {
    my %row;
    @row{@keys} = @$row;
    print $row{'stop_name'}, "\t", "X", " ", $row{'stop_lon'}.','.$row{'stop_lat'}, "\n";
}
$csv->eof or $csv->error_diag ();
close $fh;

__END__
