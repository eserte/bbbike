#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2020,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package bvg_checker;

use strict;
use warnings;
use FindBin;
my $bbbike_dir; BEGIN { $bbbike_dir = "$FindBin::RealBin/.." }
use lib $bbbike_dir, "$bbbike_dir/lib";

use File::Glob qw(bsd_glob);
use Getopt::Long;
use Term::ANSIColor qw(colored);
use Tie::IxHash;
use POSIX qw(strftime);

use Strassen::Core;

use constant BVG_SITE_IS_BROKEN => 0; # strftime("%Y-%m-%d", localtime) le '2025-02-10';

return 1 if caller;

my $variant = 'bvg2024';

GetOptions(
	   "list-only" => \my $list_only,
	   "log=s" => \my $log,
	   "debug!" => \my $debug,
	   "json-output-file=s" => \my $json_output_file,
	   "variant=s" => sub {
	       if ($_[1] =~ m{^bvg(2021|2024)$}) {
		   $variant = $_[1];
	       } else {
		   die "Invalid variant '$_[1]', currently only bvg2021 and bvg2024 valid.\n";
	       }
	   },
	   "ignore-broken-marker" => \my $ignore_broken_marker,
	  )
    or die "usage: $0 [--list-only] [--log logfile] [--debug]\n";

my $id_prefix = $variant;

my $logfh;
if ($log) {
    open $logfh, ">", "$log~"
	or die "Can't write to $log~: $!";
}

sub printerr ($;$) {
    my($msg, $color) = @_;
    if ($color) {
	print STDERR colored([$color], $msg);
    } else {
	print STDERR $msg;
    }
    if ($logfh) {
	print $logfh $msg;
    }
}

my @files = (
	     bsd_glob("$bbbike_dir/data/*-orig"),
	     "$bbbike_dir/tmp/bbbike-temp-blockings-optimized.bbd",
	    );
tie my %check_sourceids, 'Tie::IxHash';
tie my %check_inactive_sourceids, 'Tie::IxHash';
for my $file (@files) {
    my $s = Strassen->new_stream($file, UseLocalDirectives => 1);
    $s->read_stream
	(sub {
	     my($r, $dir) = @_;
	     for my $by (@{ $dir->{by} || [] }) {
		 if ($by =~ m{^(https?://www.bvg.de/de/Fahrinfo/Verkehrsmeldungen/\S+)}) {
		     my $url = $1;
		     printerr "WARNING: Found old by directive in $file for $r->[Strassen::NAME]: $url", "red on_black"; printerr "\n";
		 }
	     }
	     for my $sourceid (@{ $dir->{source_id} || [] }) {
		 if ($sourceid =~ m{^(\Q$id_prefix\E:\S+)}) {
		     $check_sourceids{$1} = $r->[Strassen::NAME];
		 }
	     }
	     for my $inactive_sourceid (@{ $dir->{'source_id[inactive]'} || [] }) {
		 if ($inactive_sourceid =~ m{^(\Q$id_prefix\E:\S+)}) {
		     $check_inactive_sourceids{$1} = $r->[Strassen::NAME];
		 }
	     }
	 }
	);
}

my $errors = 0;
if (%check_sourceids || %check_inactive_sourceids) {
    if ($list_only) {
	printerr join("\n", keys %check_sourceids) . "\n"; # ignore inactive ones here
    } else {
	my %links = find_active_sourceids();

	while(my($check_sourceid, $strname) = each %check_sourceids) {
	    printerr "$check_sourceid ($strname)... ";
	    if (!$links{$check_sourceid}) {
		printerr "note is not available anymore", "red on_black";
		$errors++;
	    } else {
		printerr "OK", "green on_black";
	    }
	    printerr "\n";
	}

	# diagnostics for inactive sourceids only if active again
	while(my($check_inactive_sourceid, $strname) = each %check_inactive_sourceids) {
	    if ($links{$check_inactive_sourceid}) {
		printerr "$check_inactive_sourceid ($strname)... note is again available -> please change source_id[inactive] to source_id", "red on_black";
		printerr "\n";
		$errors++;
	    }
	}
    }
}

if ($errors) {
    if (BVG_SITE_IS_BROKEN && !$ignore_broken_marker) {
	printerr "BVG site is currently likely to be broken, so don't fail the script run.", "yellow on_black";
	printerr "\n";
	exit 0;
    } else {
	if ($errors > 5) { # arbitrary number, or maybe work with percentages?
	    if ($ignore_broken_marker) {
		printerr "BVG site is known to be broken (BVG_SITE_IS_BROKEN is defined)", "red on_black";
		printerr "\n";
	    } else {
		printerr "Check if the BVG site is broken, and if so, define the BVG_SITE_IS_BROKEN constant in this script.", "red on_black";
		printerr "\n";
	    }
	}
	exit 1;
    }
} else {
    if (BVG_SITE_IS_BROKEN) {
	printerr "BVG site is marked as broken (see the BVG_SITE_IS_BROKEN constant in this script), but actually all sourceids were found. Consider to remove the breakage indication.", "red on_black";
	printerr "\n";
    }
}

# Only rename in the success case. So only bvg_checks.log~ stays around
# and might be inspected, while a failed run would also fail the next
# time and won't get unnoticed.
if ($logfh) {
    close $logfh
	or die $!;
    rename "$log~", $log
	or die "Error while renaming $log~ to $log: $!";
}

sub find_active_sourceids {
    if ($variant eq 'bvg2024') {
	find_active_sourceids_bvg2024();
    } else {
	# www.bvg.de is not reliable anymore (connection errors seen in March 2024), so do a retry once if Sub::Retry is available
	if (eval { require Sub::Retry; 1 }) {
	    Sub::Retry::retry(3, 10, sub {
				  my %res = eval { find_active_sourceids_bvg2023() };
				  if ($@) {
				      warn $@;
				      die $@;
				  }
				  %res;
			      });
	} else {
	    find_active_sourceids_bvg2023();
	}
    }
}

# Valid since May 2024
# Using new "bvg2024:" source_id prefix
sub find_active_sourceids_bvg2024 {
    #my $disruptions_query_url_pattern = sub { my %opts = @_; 'https://www.bvg.de/disruption-reports-service/disruptions?type=all&timeFrame=ALL&page=' . $opts{page} };
    my $disruptions_query_url_pattern = sub { my %opts = @_; 'https://www.bvg.de/disruption-reports-service/disruptions/v1/de?type=all&timeFrame=ALL&page=' . $opts{page} };
    require LWP::UserAgent;
    require JSON::XS;
    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar({});

    my $page = 1;
    my $max_pages;
    my @disruptions;
    while () {
	my $disruptions_query_url = $disruptions_query_url_pattern->(page => $page);
	my $resp = $ua->get($disruptions_query_url);
	die "Request to $disruptions_query_url failed:\n" . $resp->dump
	    if !$resp->is_success;
	my $json = $resp->decoded_content(charset => 'none');
	my $data = JSON::XS::decode_json($json);
	push @disruptions, @{ $data->{elements} };
	$max_pages = $data->{numPages};
	$page++;
	last if $page > $max_pages;
    }
    if ($debug || $json_output_file) {
	my $ofile = $json_output_file || '/tmp/bvg_checker_disruptions_2024.json';
	warn "INFO: write JSON to $ofile...\n";
	open my $ofh, '>', $ofile or die $!;
	print $ofh JSON::XS->new->pretty->canonical->utf8->encode(\@disruptions);
	close $ofh or die $!;
    }
    my %links;
    for my $disruption (@disruptions) {
	my $line = get_primary_line_2024($disruption);
	next if !defined $line;
	my $id = $disruption->{id};
	my $source_id = $line.'#'.$id;
	$links{"bvg2024:$source_id"} = 1;
    }
    if ($debug) {
	my $ofile = '/tmp/bvg_checker_disruption_ids_2024.json';
	my $jsoner = JSON::XS->new->pretty->canonical->utf8;
	warn "INFO: write active IDs to $ofile...\n";
	open my $ofh, '>', $ofile or die $!;
	print $ofh $jsoner->encode(\%links);
	close $ofh or die $!;
    }
    return %links;
}

# Valid since Apr 2023
# Still using "bvg2021:" source_id prefix
sub find_active_sourceids_bvg2023 {
    my $disruption_reports_query_url_pattern = sub { my %opts = @_; 'https://www.bvg.de/disruption-reports/notifications/all?showScheduled=true&page=' . $opts{page} };
    require LWP::UserAgent;
    require JSON::XS;

    my $ua = LWP::UserAgent->new;
    $ua->cookie_jar({});

    my $page = 1;
    my $max_pages;
    my @disruptions;
    while () {
	my $disruption_reports_query_url = $disruption_reports_query_url_pattern->(page => $page);
	my $resp = $ua->get($disruption_reports_query_url);
	die "Request to $disruption_reports_query_url failed:\n" . $resp->dump
	    if !$resp->is_success;
	my $json = $resp->decoded_content;
	my $data = JSON::XS::decode_json($json);
	push @disruptions, @{ $data->{elements} };
	$max_pages = $data->{numPages};
	$page++;
	last if $page > $max_pages;
    }
    if ($debug) {
	my $ofile = '/tmp/bvg_checker_disruption_reports.json';
	warn "INFO: write JSON to $ofile...\n";
	open my $ofh, '>', $ofile or die $!;
	print $ofh JSON::XS::encode_json(\@disruptions);
	close $ofh or die $!;
    }
    my %links;
    for my $disruption (@disruptions) {
	my $linie = $disruption->{line}->{name};
	my $meldungsId = $disruption->{uuid};
	my $source_id = lc($linie).'#'.$meldungsId;
	$links{"$id_prefix:$source_id"} = 1;
    }
    if ($debug) {
	my $ofile = '/tmp/bvg_checker_disruption_ids.json';
	my $jsoner = JSON::XS->new->pretty->canonical->utf8;
	warn "INFO: write active IDs to $ofile...\n";
	open my $ofh, '>', $ofile or die $!;
	print $ofh $jsoner->encode(\%links);
	close $ofh or die $!;
    }
    return %links;
}

# Valid since Oct 2022
# Still using "bvg2021:" source_id prefix
sub find_active_sourceids_bvg2022 {
    my $disruption_reports_query_url = 'https://www.bvg.de/disruption-reports/q';
    # query as issued on https://www.bvg.de/de/verbindungen/stoerungsmeldungen
    my $query = <<'EOF';
{"variables":{},"query":"{\n  allDisruptions {\n    meldungsId\n    linie\n    verkehrsmittel\n    __typename\n    ... on Elevator {\n      datum\n      gueltigVonDatum\n      gueltigVonZeit\n      gueltigBisDatum\n      gueltigBisZeit\n      bahnhof\n      bahnhofHafasId\n      meldungsTextDE\n      meldungsTextEN\n      __typename\n    }\n    ... on Traffic {\n      datum\n      gueltigVonDatum\n      gueltigVonZeit\n      gueltigBisDatum\n      gueltigBisZeit\n      richtungName\n      richtungHafasId\n      beginnAbschnittName\n      beginnAbschnittHafasId\n      endeAbschnittName\n      endeAbschnittHafasId\n      textIntUrsache\n      sev\n      textIntAuswirkung\n      umfahrung\n      textWAPSMSUrsache\n      textWAPSMSAuswirkung\n      prioritaet\n      __typename\n    }\n  }\n}\n"}
EOF

    require LWP::UserAgent;
    require JSON::XS;

    my $ua = LWP::UserAgent->new;
    my $resp = $ua->post($disruption_reports_query_url, Content_Type => 'application/json', Content => $query);
    die "Request to $disruption_reports_query_url failed:\n" . $resp->dump
	if !$resp->is_success;
    my $json = $resp->decoded_content;
    if ($debug) {
	my $ofile = '/tmp/bvg_checker_disruption_reports.json';
	warn "INFO: write JSON to $ofile...\n";
	open my $ofh, '>', $ofile or die $!;
	print $ofh $json;
	close $ofh or die $!;
    }
    my $data = JSON::XS::decode_json($json);
    my %links;
    for my $disruption (@{ $data->{data}->{allDisruptions} }) {
	my $linie = $disruption->{linie};
	my $meldungsId = $disruption->{meldungsId};
	my $source_id = lc($linie).'#'.$meldungsId;
	$links{"$id_prefix:$source_id"} = 1;
    }
    return %links;
}

# Valid from Oct 2021 - Oct 2022, using Firefox::Marionette
sub find_active_sourceids_bvg2021 {
    my $traffic_url = 'https://www.bvg.de/de/verbindungen/stoerungsmeldungen?type=traffic';
    require Firefox::Marionette;
    my $firefox = Firefox::Marionette->new->go($traffic_url);
    $firefox->await(sub { $firefox->loaded });
    my %links;
    {
	my(@old_links, @links);
	my $max_tries = 3;
	for my $try (1..$max_tries) {
	    @links = map {
		my $href = $_->attribute('href');
		if ($href && $href =~ m{/de/verbindungen/stoerungsmeldungen/(.*#.*)}) {
		    $1;
		} else {
		    ();
		}
	    } $firefox->find('//a');
	    if (!@links || (@old_links < @links)) {
		@old_links = @links;
		warn "INFO: sleep another second to make sure that the page is complete... ($try/$max_tries)\n" if $try > 1;
		sleep 1;
		next;
	    }
	}
	if (!@links) {
	    # likely a severe problem (connection problems, page not found, site changed...)
	    require File::Copy;
	    require POSIX;
	    my $pngtmp = $firefox->selfie;
	    my $out_file = "/tmp/bvg_checker_" . POSIX::strftime("%F_%T", localtime) . ".png";
	    File::Copy::cp("$pngtmp", $out_file)
		    or warn "Cannot create selfie: $!";
	    die "Cannot find any entries in $traffic_url. A selfie png of the browser window is located in $out_file\n";
	}
	%links = map {("$id_prefix:$_",1)} @links;
    }
    return %links;
}

sub get_primary_line_2024 {
    my $disruption = shift;

    # find suitable line, prefer busses
    my $first_line;
    for (@{ $disruption->{lines} }) {
	if ($_->{bus} && @{ $_->{bus} }) {
	    return $_->{bus}->[0]->{slug};
	}
	for my $type (sort keys %$_) {
	    if ($_->{$type} && @{ $_->{$type} }) {
		$first_line = $_->{$type}->[0]->{slug};
		last;
	    }
	}
    }
    if (defined $first_line) {
	return $first_line;
    } else {
	warn "WARNING: Cannot find line for id $disruption->{id} ($disruption->{messageType}).\n";
	return undef;
    }
}

__END__
