#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2022,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use 5.010; # //
use FindBin;
use lib "$FindBin::RealBin/..", $FindBin::RealBin;

use Getopt::Long;
use HTML::FormatText;
use JSON::XS qw(decode_json);
use List::Util qw(any first uniqstr);
use Term::ANSIColor qw(colored);
use Text::Wrap qw(wrap);
use Tie::IxHash;

use BBBikeUtil qw(bbbike_root is_in_path);
use BBBikeYAML qw(LoadFile);

my $variant = 'bvg2024';

my $use_pager = -t STDOUT && is_in_path('less');
my $highlight_days = 3;
my $mod_since;
GetOptions(
	   'pager!'           => \$use_pager,
	   'highlight-days=i' => \$highlight_days,
	   "variant=s" => sub {
	       if ($_[1] =~ m{^bvg(2021|2024)$}) {
		   $variant = $_[1];
	       } else {
		   die "Invalid variant '$_[1]', currently only bvg2021 and bvg2024 valid.\n";
	       }
	   },
	   'mod-since=s' => \$mod_since,
	   'last-check-file=s' => sub {
	       my $file = $_[1];
	       $mod_since = since_last_check($file);
	       $mod_since .= 'd';
	   },
	   'debug' => \my $debug,
	  )
    or die "usage: $0 [--no-pager] [--highlight-days days] [--mod-since <num>d | --last-check-file /path/to/file.org] [--debug]\n";

if ($variant eq 'bvg2024') {
    require "bvg_checker.pl"; # for get_primary_line_2024
}

if ($mod_since) {
    require Time::Moment;
    if ($variant ne 'bvg2024') {
	die "--mod-since only supported for --variant bvg2024.\n";
    }
    if ($mod_since =~ /^(\d+(?:\.\d+)?)d$/) {
	$mod_since = time - $1 * 86400; # ignore DST glitches
    } else {
	die "Only <num>d (days) allow for --mod-since.\n";
    }
}

my $sourceids_all     = LoadFile(bbbike_root . "/tmp/sourceid-all.yml");
my $sourceids_current = LoadFile(bbbike_root . "/tmp/sourceid-current.yml");

my $json_file = $variant eq 'bvg2024' ? '/tmp/bvg_checker_disruptions_2024.json' : '/tmp/bvg_checker_disruption_reports.json';

my $json = `cat $json_file`;
my $d = decode_json $json;

my %combinedRecords;
if ($variant eq 'bvg2024') {
    for my $dd (@$d) {
	next if $dd->{"messageType"} eq "ELEVATOR";
	if ($mod_since) {
	    next if !$dd->{modDate};
	    my $msg_epoch = Time::Moment->from_string($dd->{modDate})->epoch;
	    next if $msg_epoch < $mod_since;
	}
	my $from = $dd->{startDate};
	my $line = bvg_checker::get_primary_line_2024($dd);
	my $sourceid = "bvg2024:" . $line . "#" . $dd->{id};
	my $date_row = "$from - " . ($dd->{endDate} // "?");

	my $title_row;
	if (($dd->{stationOne}{name}//'') ne '') {
	    if ((($dd->{stationOne}{name}//'') eq ($dd->{stationTwo}{name}//'')) || (($dd->{stationTwo}{name}//'') eq '')) {
		$title_row = remove_boring_unicode($dd->{stationOne}{name});
	    } else {
		$title_row = remove_boring_unicode($dd->{stationOne}{name} . " - " . $dd->{stationTwo}{name})
	    }
	} else {
	    $title_row = remove_boring_unicode($dd->{content}[0]{headline});
	}

	my $text_without_line = remove_boring_unicode($dd->{content}[0]{content});
	if (!eval {
	    my $plain_text = HTML::FormatText->format_string($text_without_line, leftmargin => 0, rightmargin => 79);
	    if ($plain_text ne '') {
		$text_without_line = $plain_text;
	    }
	}) {
	    warn "WARNING: Parsing HTML for id $dd->{id} failed ($@)";
	    # fallback to unformatted content, just wrap it
	    $text_without_line = wrap("", "", $text_without_line);
	}

	my $key = "$date_row|$title_row|$text_without_line";
	push @{ $combinedRecords{$key} }, {
					   from              => $from,
					   sourceid          => $sourceid,
					   date_row          => $date_row,
					   title_row         => $title_row,
					   line              => $line,
					   text_without_line => $text_without_line,
					   mod_date          => $dd->{modDate},
					  }
    }
} else {
    my $qr = qr{(U-Bahn U?\d+|(?:Bus|Tram) [MXN]?\d+)};

    for my $dd (@$d) {
	next if $dd->{"notificationType"} eq "ELEVATOR";
	my $from = $dd->{startDate};
	my $sourceid = "bvg2021:" . lc($dd->{line}->{name}) . "#" . $dd->{uuid};
	my $date_row = "$from - " . ($dd->{endDate} // "?");
	my $title_row = remove_boring_unicode(join(" - ", grep { defined } $dd->{stationOne}{title}, $dd->{stationTwo}{title}));
	my $text_without_line = remove_boring_unicode($dd->{content});
	my $sev = $dd->{isSev} ? 'ja' : '';
	my $line;
	if ($text_without_line =~ m{^$qr}) {
	    $line = $1;
	    $text_without_line =~ s{^$qr:\s+}{};
	}
	$text_without_line =~ s{\s+$}{}sg;
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
    my $formatted_sourceids = ''; # already contains "\n" if non-empty
    for my $sourceid (map { $_->{sourceid} } @$record) {
	$formatted_sourceids .= ($sourceids_all->{$sourceid} ? colored($sourceid, (!$sourceids_current->{$sourceid} ? "yellow on_black" : "green on_black")) . " INUSE" : $sourceid) . "\n";
    }
    my $lines_combined;
    if ($variant eq 'bvg2024') {
	# no output of lines needed, it's already part of text_without_line (despite the variable name)
    } else {
	$lines_combined = combine($record, 'line');
    }
    my $sev_combined = combine($record, 'sev');
    my $text_without_line = $record->[0]->{text_without_line};

    my $text =
	$date_row . "\n" .
	($debug && $mod_since ? "modified $record->[0]->{mod_date}\n" : "") .
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
	       |   mehreren[ ]Demonstrationen
	       |   Demonstration(en)?
	       |   Aufzug(es)?
	       |   Kundgebung
	       |   Veranstaltung
	       |   Staatsbesuch(es|s)?
	       |   Sportveranstaltung
	       |   wegen[ ]zu[ ]hoher[ ]Verkehrsbelastung
	       |   erh�hte[ms][ ]Verkehrsaufkommen
	       |   wegen[ ]eines[ ]Wasserrohrbruches
	       |   betrieblichen[ ]Gr�nden
	       |   Bauarbeiten
	       |   Zusatzhalt
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

sub since_last_check {
    my $file = shift;
    require DateTime;
    require DateTime::Format::Strptime;
    require DateTime::Duration;
    require POSIX;

    my $found = 0; 
    my $now = DateTime->now(time_zone => "local");
    my $parser = DateTime::Format::Strptime->new(
        pattern => "%Y-%m-%d %H:%M",
        time_zone => "local"
    );

    open my $fh, $file or die $!;
    while(<$fh>) {
	if (/^\*+\s+TODO\s+BVG disruptions/) { $found = 1; }
	if ($found && /- State\s+"DONE"\s+from\s+"TODO"\s+\[(\d{4}-\d{2}-\d{2}\s+\w{2}\s+\d{2}:\d{2})\]/) {
	    my $date_str = $1;
	    $date_str =~ s/\s+\w{2}\s+/ /;  # Remove the weekday
	    my $date = $parser->parse_datetime($date_str);
	    my $duration = $now->subtract_datetime($date);
	    my $days = $duration->in_units("days") + $duration->in_units("hours") / 24 + $duration->in_units("minutes") / 1440;
	    return sprintf("%.1f", POSIX::ceil($days * 10) / 10);  # Round up to one decimal place
	}
    }
    if (!$found) {
	die "Cannot find last date of 'BVG disruptions' line in $file";
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
