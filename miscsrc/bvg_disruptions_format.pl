#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2022 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use JSON::XS qw(decode_json);
use YAML::XS qw(LoadFile);
use Term::ANSIColor qw(colored);

my $sourceids_all     = LoadFile("$ENV{HOME}/src/bbbike/tmp/sourceid-all.yml");
my $sourceids_current = LoadFile("$ENV{HOME}/src/bbbike/tmp/sourceid-current.yml");

my $json = `cat /tmp/bvg_checker_disruption_reports.json`;
my $d = decode_json $json;

my @records;
for my $dd (@{ $d->{data}->{allDisruptions}->{disruptions} }) {
    next if $dd->{"__typename"} eq "Elevator";
    my $from = "$dd->{gueltigVonDatum} $dd->{gueltigVonZeit}";
    my $sourceid = "bvg2021:" . lc($dd->{linie}) . "#" . $dd->{meldungsId};
    my $text =
	($sourceids_all->{$sourceid} ? colored($sourceid, (!$sourceids_current->{$sourceid} ? "yellow on_black" : "green on_black")) . " INUSE" : $sourceid) . "\n" .
	"$dd->{beginnAbschnittName} - $dd->{endeAbschnittName}\n" .
	"$from - " . ($dd->{gueltigBisDatum} // "?") . " " . ($dd->{gueltigBisZeit} // "") . "\n" .
	"$dd->{textIntAuswirkung}\n";
    $text .= "SEV: $dd->{sev}\n" if $dd->{sev} ne "";
    push @records, {from=>$from, text=>$text};
}

@records = sort { $a->{from} cmp $b->{from} } @records;

binmode STDOUT, ":utf8";
for my $record (@records) {
    print $record->{text};
    print "="x70, "\n";
}

__END__
