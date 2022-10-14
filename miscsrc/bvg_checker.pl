#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2020,2021,2022 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
my $bbbike_dir; BEGIN { $bbbike_dir = "$FindBin::RealBin/.." }
use lib $bbbike_dir, "$bbbike_dir/lib";

use File::Glob qw(bsd_glob);
use Getopt::Long;
use Term::ANSIColor qw(colored);
use Tie::IxHash;

use Strassen::Core;

my $id_prefix = 'bvg2021';

GetOptions(
	   "list-only" => \my $list_only,
	   "log=s" => \my $log,
	   "debug!" => \my $debug,
	  )
    or die "usage: $0 [--list-only] [--log logfile] [--debug]\n";

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
	 }
	);
}

my $errors = 0;
if (%check_sourceids) {
    if ($list_only) {
	printerr join("\n", keys %check_sourceids) . "\n";
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
    }
}

if ($errors) {
    exit 1;
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
    find_active_sourceids_bvg2022();
}

# Valid since Oct 2022
# Still using "bvg2021:" source_id prefix
sub find_active_sourceids_bvg2022 {
    my $disruption_reports_query_url = 'https://www.bvg.de/disruption-reports/q';
    # query as issued on https://www.bvg.de/de/verbindungen/stoerungsmeldungen
    my $query = <<'EOF';
{"variables":{},"query":"{\n  allDisruptions {\n    disruptions {\n      meldungsId\n      linie\n      verkehrsmittel\n      __typename\n      ... on Elevator {\n        datum\n        gueltigVonDatum\n        gueltigVonZeit\n        gueltigBisDatum\n        gueltigBisZeit\n        bahnhof\n        bahnhofHafasId\n        meldungsTextDE\n        meldungsTextEN\n        __typename\n      }\n      ... on Traffic {\n        datum\n        gueltigVonDatum\n        gueltigVonZeit\n        gueltigBisDatum\n        gueltigBisZeit\n        richtungName\n        richtungHafasId\n        beginnAbschnittName\n        beginnAbschnittHafasId\n        endeAbschnittName\n        endeAbschnittHafasId\n        textIntUrsache\n        sev\n        textIntAuswirkung\n        umfahrung\n        textWAPSMSUrsache\n        textWAPSMSAuswirkung\n        prioritaet\n        __typename\n      }\n    }\n    __typename\n  }\n}\n"}
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
    for my $disruption (@{ $data->{data}->{allDisruptions}->{disruptions} }) {
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

__END__
