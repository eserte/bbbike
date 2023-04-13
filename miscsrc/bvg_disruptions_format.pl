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
use lib "$FindBin::RealBin/..";

use Getopt::Long;
use JSON::XS qw(decode_json);
use List::Util qw(any first uniqstr);
use YAML::XS qw(LoadFile);
use Term::ANSIColor qw(colored);
use Tie::IxHash;

use BBBikeUtil qw(bbbike_root is_in_path);

my $use_pager = -t STDOUT && is_in_path('less');
my $highlight_days = 3;
GetOptions(
	   'pager!'           => \$use_pager,
	   'highlight-days=i' => \$highlight_days,
	  )
    or die "usage: $0 [--no-pager] [--highlight-days days]\n";

my $sourceids_all     = LoadFile(bbbike_root . "/tmp/sourceid-all.yml");
my $sourceids_current = LoadFile(bbbike_root . "/tmp/sourceid-current.yml");

my $json = `cat /tmp/bvg_checker_disruption_reports.json`;
my $d = decode_json $json;

my $qr = qr{(U-Bahn U?\d+|(?:Bus|Tram) [MX]?\d+)};

my %combinedRecords;
if (0) { # until Apr 2023
    for my $dd (@{ $d->{data}->{allDisruptions} }) {
	next if $dd->{"__typename"} eq "Elevator";
	my $from = "$dd->{gueltigVonDatum} $dd->{gueltigVonZeit}";
	my $sourceid = "bvg2021:" . lc($dd->{linie}) . "#" . $dd->{meldungsId};
	my $date_row = "$from - " . ($dd->{gueltigBisDatum} // "?") . " " . ($dd->{gueltigBisZeit} // "");
	my $title_row = "$dd->{beginnAbschnittName} - $dd->{endeAbschnittName}";
	my $text_without_line = $dd->{textIntAuswirkung};
	my $line;
	if ($text_without_line =~ m{^$qr}) {
	    $line = $1;
	    $text_without_line =~ s{^$qr:\s+}{};
	}
	my $key = "$date_row|$title_row|$text_without_line";
	push @{ $combinedRecords{$key} }, {
					   from              => $from,
					   sourceid          => $sourceid,
					   date_row          => $date_row,
					   title_row         => $title_row,
					   line              => $line,
					   text_without_line => $text_without_line,
					   sev               => $dd->{sev},
					  }
    }
} else {
    for my $dd (@$d) {
	next if $dd->{"notificationType"} eq "ELEVATOR";
	my $from = $dd->{startDate};
	my $sourceid = "bvg2021:" . lc($dd->{line}->{name}) . "#" . $dd->{uuid};
	my $date_row = "$from - " . ($dd->{endDate} // "?");
	my $title_row = remove_boring_unicode(join(" - ", grep { defined } $dd->{stationOne}{title}, $dd->{stationTwo}{title}));
	my $text_without_line = remove_boring_unicode($dd->{content});
	my $sev = $dd->{isSev} ? 'mit SEV' : '';
	my $line;
	if ($text_without_line =~ m{^$qr}) {
	    $line = $1;
	    $text_without_line =~ s{^$qr:\s+}{};
	}
	my $key = "$date_row|$title_row|$text_without_line";
	push @{ $combinedRecords{$key} }, {
					   from              => $from,
					   sourceid          => $sourceid,
					   date_row          => $date_row,
					   title_row         => $title_row,
					   line              => $line,
					   text_without_line => $text_without_line,
					   sev               => $sev,
					  }
    }
}

my @records;
for my $record (values %combinedRecords) {
    my $from      = $record->[0]->{from};
    my $date_row  = $record->[0]->{date_row};
    my $title_row = $record->[0]->{title_row};
    my $formatted_sourceids = '';; # already contains "\n" if non-empty
    for my $sourceid (map { $_->{sourceid} } @$record) {
	$formatted_sourceids .= ($sourceids_all->{$sourceid} ? colored($sourceid, (!$sourceids_current->{$sourceid} ? "yellow on_black" : "green on_black")) . " INUSE" : $sourceid) . "\n";
    } 
    my $lines_combined = combine($record, 'line');
    my $sev_combined = combine($record, 'sev');
    my $text_without_line = $record->[0]->{text_without_line};

    my $text =
	$date_row . "\n" .
	$formatted_sourceids . 
	$title_row . "\n";
    $text .= $lines_combined . "\n" if defined $lines_combined;
    $text .=
	highlight_words($text_without_line) . "\n";
    $text .= "SEV: $sev_combined\n" if defined $sev_combined;

    push @records, {from=>$from, text=>$text};
}

@records = sort { $a->{from} cmp $b->{from} } @records;

my $outfh;
if ($use_pager) {
    require POSIX;
    my @next_days = map { POSIX::strftime('%F', localtime(time + 86400*$_)) } (0..$highlight_days-1); # XXX incorrect on DST switches!
    my $rx = '^(' . join('|', map { quotemeta } @next_days) . ')';
    my $qr = qr/$rx/;
    if (!any { $_->{from} =~ $qr } @records) {
	# none of next_days are available --- fallback to a previous date
	my $previous_date_record = first { ($_->{from} cmp $next_days[0]) <= 0 } reverse @records;
	if ($previous_date_record) {
	    $rx = '^' . quotemeta($previous_date_record->{from});
	} else {
	    undef $rx;
	}
    }
    my @pager_cmd = ('less', (defined $rx ? '+/'.$rx : ()));
    open $outfh, '|-', @pager_cmd
	or die "Failed to run '@pager_cmd': $!";
} else {
    $outfh = \*STDOUT;
}
$outfh->binmode(':utf8');
for my $record (@records) {
    $outfh->print($record->{text});
    $outfh->print("="x70, "\n");
}

sub highlight_words {
    my($text) = @_;
    return undef if !defined $text;
    $text =~ s{\b(
		   Verkehrsunfall(es|s)?
	       |   Verkehrsbehinderung
	       |   Feuerwehreinsatz(es)?
	       |   Polizeieinsatz(es)?
	       |   Demonstration
	       |   mehreren[ ]Demonstrationen
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

sub combine {
    my($arrref, $field) = @_;
    my $combined = join(', ', uniqstr map { $_->{$field} } grep { defined $_->{$field} && $_->{$field} ne '' } @$arrref);
    $combined = undef if !length $combined;
    $combined;
}

sub remove_boring_unicode {
    my $s = shift;
    $s =~ s/[\x{200b}\x{2060}]//g;
    $s;
}

__END__

=head1 NAME

bvg_disruptions_format.pl - format BVG StE<ouml>rungsmeldungen

=head1 SYNOPSIS

    ./miscsrc/bvg_checker.pl --debug
    ./miscsrc/bvg_disruptions_format.pl | less +/'^'$(date +%F)

=head1 DESCRIPTION

Format BVG disruption messages showing only relevant information
(from/until dates, description), combining same messages, sorted by
date, and also providing C<source_id> directives, possibly colored to
indicate usage in the bbbike data.

Requires a previous run of C<bvg_checker.pl --debug> to fetch the JSON
file with the BVG disruption messages.

Requires also generated F<sourceid*.yml> files, which may be created
using

   (cd data && make persistent-tmp)

=head1 SEE ALSO

L<bvg_checker.pl>.

=cut
