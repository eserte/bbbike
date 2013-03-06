#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use Text::CSV_XS ();

my $infile = shift || "$FindBin::RealBin/../downloads/data-digested/5061c95925f17ae08661edb271b94747.content"; # this is http://datenfragen.de/openvbb/GTFS_VBB_Okt2012/stops.txt
open my $fh, $infile or die $!;
binmode $fh, ":utf8";
my $csv = Text::CSV_XS->new({ binary => 1})
    or die "Cannot use CSV: ".Text::CSV_XS->error_diag ();
chomp(my @keys = split /,/, scalar <$fh>);

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
