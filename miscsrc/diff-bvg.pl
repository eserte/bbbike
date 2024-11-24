#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;

use Encode qw(decode encode);
use File::Temp qw();
use Getopt::Long;
use JSON::XS qw(decode_json);
use IPC::Run qw(run);
use List::MoreUtils qw(uniq);
use YAML::XS qw(LoadFile);

my $json_file = "bvg_checker_disruptions_2024.json";

# note: use pseudo version delta -1 for uncommitted version
my $old_version = 1;
my $new_version;
my $debug;
#my $ignore_boring;
my @ignore;
my $use_wdiff;
GetOptions(
	   "old-version=i" => \$old_version,
	   "new-version=i" => \$new_version,
	   #"ignore-boring" => \$ignore_boring,
	   'ignore=s@'     => \@ignore,
	   'wdiff' => \$use_wdiff,
	   "debug" => \$debug,
	  )
    or die "usage: $0 [--debug] [--ignore key ...] [--old-version delta] [--new-version delta] [--wdiff]\n";

my $sourceids = load_sourceids();

if (!defined $new_version) {
    $new_version = $old_version - 1;
}

my @versions = split /\n/, qx(git log --pretty=%H -- $json_file);

my(%old_records, %new_records);
for my $def (
	     [$old_version, \%old_records],
	     [$new_version, \%new_records],
	    ) {
    my($delta_version, $ref) = @$def;
    my @cat_projects_cmd;
    if ($delta_version == -1) {
	@cat_projects_cmd = ('cat', $json_file);
    } elsif ($delta_version < -1) {
	die "version delta can only be -1, 0 or positive";
    } else {
	my $version = $versions[$delta_version];
	@cat_projects_cmd = (qw(git show), $version.':'.$json_file);
    }
    my @cmd = (\@cat_projects_cmd);
#	       '|', [qw(jq .[])],
#	       ($ignore_boring ? (
#				  '|', ['jq', 'del(.[].additionalHtmlContent)'],
#				  '|', ['jq', 'del(.[].coordinator)'],
#				  '|', ['jq', 'del(.[].holder)'],
#				  '|', ['jq', 'del(.[].imagesBefore)'],
#				  '|', ['jq', 'del(.[].imagesCurrent)'],
#				  '|', ['jq', 'del(.[].image)'],
#				  '|', ['jq', 'del(.[].kml)'],
#				 ) : ()),
#	       (map { ('|', ['jq', 'del(.[].'.$_.')']) } @ignore), # XXX only simple keys (e.g. "types") work here, but something like "types.metrics" does not
#	       '|', [qw(jq sort_by(.[].id))]
#	      );
    if ($debug) {
	my $debug_cmd = join(" ", map { ref $_ eq 'ARRAY' ? join(' ', @$_) : $_ } @cmd);
	warn "RUN: $debug_cmd...\n";
    }	
    run @cmd, '>', \my $json
	or die "Failed to run '@cat_projects_cmd' and process with jq";
    #$json = decode('UTF-8', $json);
    #XXX $json =~ s/\x{00AD}//g; # sanitize
    my $res = split_json($json);
    %$ref = %$res;
}

#binmode STDOUT, ':utf8';
binmode STDOUT, ':raw';

my @all_ids = sort { $a cmp $b } uniq(keys(%old_records), keys(%new_records));
$| = 1;
my($stats_new, $stats_deleted, $stats_changed, $stats_changes_before_normalization) = (0, 0, 0, 0);
for my $id (@all_ids) {
    if (!$old_records{$id}) {
	print "="x70, "\n", "NEW RECORD $id\n";
	print_basic_info($new_records{$id}, mode => 'new');
	print "$new_records{$id}\n";
	$stats_new++;
    } elsif (!$new_records{$id}) {
	print "="x70, "\n", "DELETED RECORD $id\n";
	print_basic_info($old_records{$id}, mode => 'deleted');
	print "$old_records{$id}\n";
	$stats_deleted++;
    } elsif ($old_records{$id} ne $new_records{$id}) {
	# normalize first
	(my $old_record = $old_records{$id}) =~ s{https://}{http://}g;
	(my $new_record = $new_records{$id}) =~ s{https://}{http://}g;
	s{\\r}{}g for ($old_record, $new_record); # some "kml" record contain DOS newlines
	if ($old_record ne $new_record) {
	    print "="x70, "\n", "CHANGED RECORD $id\n";
	    $stats_changed++;

	    my $old = File::Temp->new(TMPDIR => 1, TEMPLATE => "bvg-old-XXXXXXXX");
	    binmode $old, ':utf8';
	    $old->print($old_record);
	    $old->flush;

	    my $new = File::Temp->new(TMPDIR => 1, TEMPLATE => "bvg-new-XXXXXXXX");
	    binmode $new, ':utf8';
	    $new->print($new_record);
	    $new->flush;

	    print_basic_info($new_record, mode => 'changed');
	    my @cmd;
	    if ($use_wdiff) {
		@cmd = ('wdiff',
			"--less-mode",
			"$old", "$new");
	    } else {
		@cmd = ("diff", "-u", "$old", "$new");
	    }
	    run [@cmd], ">", \my $diff;
	    $diff = decode('UTF-8', $diff);
	    print $diff;
	} else {
	    $stats_changes_before_normalization++;
	}
    }
}

print "="x70, "\n", "STATISTICS\n";
print "Records in last version: " . scalar(keys %old_records) . "\n";
print "Records in curr version: " . scalar(keys %new_records) . "\n";
print "New records    : $stats_new\n";
print "Deleted records: $stats_deleted\n";
print "Changed records: $stats_changed\n";

sub print_basic_info {
    my($json, %opts) = @_;
    my $mode = delete $opts{mode};
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    my $record = decode_json($json); 
    my($id) = $record->{id};
    print "id: " . $id . ($sourceids->{$id} ? " (INUSE)" : "") . "\n";

#    my($title) = $record =~ m{"title":\s*"(.*)"};
#    if ($title) {
#	print $title, "\n";
#    }
#    my $bbbike_data;
#    my($link) = $record =~ m{"link":\s*"(.*)"};
#    if ($link) {
#	print $link;
#	(my $link_without_scheme = $link) =~ s{^https?:}{};
#	$bbbike_data = $infravelo_urls->{$link_without_scheme};
#	if ($bbbike_data) {
#	    print " (INUSE)";
#	}
#	if ($bbbike_data && $check_deleted_if_in_use && $mode eq 'deleted') {
#	    my $resp = $ua->head($link);
#	    if ($resp->is_success) {
#		print " (WEBSITE_OK)";
#	    } else {
#		print " (WEBSITE_MISSING)";
#	    }
#	}
#	print "\n";
#    }
#    my($dateStart) = $record =~ m{"dateStart": "(.*)"};
#    my($dateEnd) = $record =~ m{"dateEnd": "(.*)"};
#    if ($dateStart || $dateEnd) {
#	my $period = ($dateStart//"...") . " - " . ($dateEnd//"...");
#	my $period_check = '';
#	if ($mode eq 'deleted') {
#	    $period_check = ' [?]'; # we have no fresh data
#	} else {
#	    my $bbbike_period = $bbbike_data->{period};
#	    if ($bbbike_period) {
#		$period_check = $period eq $bbbike_period ? ' [OK]' : ' [DIFF]';
#	    }
#	}
#	print $period . $period_check . "\n";
#    }
#    (my $link_rx = $link) =~ s{https?:}{https?:};
#    print qq{(bbbike-grep-with-args "by" "$link_rx")\n};
}

sub split_json {
    my $json = shift;
    my $data = decode_json($json);
    my %records;
    for my $element (@$data) {
	$records{$element->{id}} = JSON::XS->new->pretty->canonical->utf8->encode($element);
    }
    \%records;
}

sub load_sourceids {
    my $all_sourceids = LoadFile("$ENV{HOME}/src/bbbike/tmp/sourceid-all.yml");
    my %bvg_sourceids;
    while(my($id, undef) = each %$all_sourceids) {
	if ($id =~ m{^bvg2024:.*#(.*)}) {
	    $bvg_sourceids{$1} = 1;
	}
    }
    \%bvg_sourceids;
}

__END__
