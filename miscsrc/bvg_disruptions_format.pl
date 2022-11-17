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
use FindBin;
use lib "$FindBin::RealBin/..";

use JSON::XS qw(decode_json);
use YAML::XS qw(LoadFile);
use Term::ANSIColor qw(colored);

use BBBikeUtil qw(bbbike_root);

my $sourceids_all     = LoadFile(bbbike_root . "/tmp/sourceid-all.yml");
my $sourceids_current = LoadFile(bbbike_root . "/tmp/sourceid-current.yml");

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
	highlight_words($dd->{textIntAuswirkung}) . "\n";
    $text .= "SEV: $dd->{sev}\n" if $dd->{sev} ne "";
    push @records, {from=>$from, text=>$text};
}

@records = sort { $a->{from} cmp $b->{from} } @records;

binmode STDOUT, ":utf8";
for my $record (@records) {
    print $record->{text};
    print "="x70, "\n";
}

sub highlight_words {
    my($text) = @_;
    return undef if !defined $text;
    $text =~ s{\b(
		   Verkehrsunfall(es|s)?
	       |   Feuerwehreinsatz(es)?
	       |   Polizeieinsatz(es)?
	       |   Demonstration
	       |   Kundgebung
	       |   Veranstaltung
	       |   Sportveranstaltung
	       )\b}{wrap_friendly_coloring(['bold'], $1)}eigx;
    $text;
}

sub wrap_friendly_coloring {
    my($color, $text) = @_;
    my @token = split /\s+/, $text;
    if (@token > 1) {
	my $last_token = pop @token;
	join("", map { colored($color, "$_ ") } @token) . colored($color, $last_token);
    } else {
	colored($color, $token[0]);
    }
}

__END__

=head1 NAME

bvg_disruptions_format.pl - format BVG StE<ouml>rungsmeldungen

=head1 SYNOPSIS

    ./miscsrc/bvg_checker.pl --debug
    ./miscsrc/bvg_disruptions_format.pl | less +/'^'$(date +%F)

=head1 DESCRIPTION

Format BVG disruption messages showing only relevant information
(from/until dates, description), sorted by date, and also providing
C<source_id> directives, possibly colored to indicate usage in the
bbbike data.

Requires a previous run of C<bvg_checker.pl --debug> to fetch the JSON
file with the BVG disruption messages.

Requires also generated F<sourceid*.yml> files, which may be created
using

   (cd data && make persistent-tmp)

=head1 SEE ALSO

L<bvg_checker.pl>.

=cut
