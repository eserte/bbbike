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
use Storable qw(dclone);
use YAML::XS qw(LoadFile Dump);

my $json_file = "bvg_checker_disruptions_2024.json";

# note: use pseudo version delta -1 for uncommitted version
my $old_version = 1;
my $new_version;
my $debug;
#my $ignore_boring;
my @ignore;
my $use_wdiff;
my $sort_by = 'date';
GetOptions(
	   "old-version=i" => \$old_version,
	   "new-version=i" => \$new_version,
	   #"ignore-boring" => \$ignore_boring,
	   'ignore=s@'     => \@ignore,
	   'wdiff' => \$use_wdiff,
	   'as-yaml' => \my $as_yaml,
	   "debug" => \$debug,
	   "sort-by=s" => \$sort_by,
	  )
    or die "usage: $0 [--debug] [--ignore key ...] [--old-version delta] [--new-version delta] [--wdiff] [--sort-by date|title]\n";

$sort_by =~ m{^(date|title)$}
    or die "usage: allowed --sort-by are 'date' (default) and 'title'\n";
my($sort_by_key1, $sort_by_key2) = ($sort_by eq 'title' ? qw(_title _date) : qw(_date _title));

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
    if ($debug) {
	my $debug_cmd = join(" ", map { ref $_ eq 'ARRAY' ? join(' ', @$_) : $_ } @cmd);
	warn "RUN: $debug_cmd...\n";
    }	
    run @cmd, '>', \my $json
	or die "Failed to run '@cat_projects_cmd'";

    $json = decode('UTF-8', $json);
    $json =~ s/[\x{2060}\x{200B}]//g; # sanitize
    $json = encode('UTF-8', $json);

    my $res = filter_and_split_json($json);
    %$ref = %$res;
}

binmode STDOUT, ':utf8';

my @all_ids;
{
    my %all_records = (%old_records, %new_records);
    @all_ids = sort {
	$all_records{$a}->{$sort_by_key1} cmp $all_records{$b}->{$sort_by_key1} ||
	$all_records{$a}->{$sort_by_key2} cmp $all_records{$b}->{$sort_by_key2} ||
	$a cmp $b
    } keys %all_records;
}
$| = 1;
my($stats_new, $stats_deleted, $stats_changed, $stats_changes_before_normalization) = (0, 0, 0, 0);
for my $id (@all_ids) {
    if (!$old_records{$id}) {
	print "="x70, "\n", "NEW RECORD $id\n";
	print_basic_info($new_records{$id}, mode => 'new');
	print_raw_serialized($new_records{$id});
	$stats_new++;
    } elsif (!$new_records{$id}) {
	print "="x70, "\n", "DELETED RECORD $id\n";
	print_basic_info($old_records{$id}, mode => 'deleted');
	print_raw_serialized($old_records{$id});
	$stats_deleted++;
    } else {
	my $old_serialized = $as_yaml ? Dump($old_records{$id}) : JSON::XS->new->pretty->canonical->utf8->encode($old_records{$id});
	my $new_serialized = $as_yaml ? Dump($new_records{$id}) : JSON::XS->new->pretty->canonical->utf8->encode($new_records{$id});
	if ($old_serialized ne $new_serialized) {
	    my($old_record_normalized, $new_record_normalized);
	    for my $def (
		[$old_records{$id}, \$old_record_normalized],
		[$new_records{$id}, \$new_record_normalized],
	    ) {
		my($from, $toref) = @$def;
		$$toref = dclone $from;
		for my $remove_field (qw(modDate)) {
		    delete $$toref->{$remove_field};
		}
	    }
	    if (JSON::XS->new->canonical->encode($old_record_normalized) ne JSON::XS->new->canonical->encode($new_record_normalized)) {
		print "="x70, "\n", "CHANGED RECORD $id\n";
		$stats_changed++;

		my $old = File::Temp->new(TMPDIR => 1, TEMPLATE => "bvg-old-XXXXXXXX");
		$old->print($old_serialized);
		$old->flush;

		my $new = File::Temp->new(TMPDIR => 1, TEMPLATE => "bvg-new-XXXXXXXX");
		$new->print($new_serialized);
		$new->flush;

		print_basic_info($new_records{$id}, mode => 'changed');
		my @cmd;
		if ($use_wdiff) {
		    @cmd = ('wdiff',
			    "--less-mode",
			    "$old", "$new");
		} else {
		    @cmd = ("diff", "-u", "$old", "$new");
		}
		run [@cmd], ">", \my $diff;
		binmode STDOUT, ':raw';
		print $diff;
		binmode STDOUT, ':utf8';
	    } else {
		$stats_changes_before_normalization++;
	    }
	}
    }
}

print "="x70, "\n", "STATISTICS\n";
print "Records in last version: " . scalar(keys %old_records) . "\n";
print "Records in curr version: " . scalar(keys %new_records) . "\n";
print "New records:                   $stats_new\n";
print "Deleted records:               $stats_deleted\n";
print "Changed records:               $stats_changed\n";
print "Uninteresting changed records: $stats_changes_before_normalization\n";

sub print_basic_info {
    my($record, %opts) = @_;
    my $mode = delete $opts{mode};
    die "Unhandled arguments: " . join(" ", %opts) if %opts;

    if ($record->{_title}) {
	print $record->{_title}, "\n";
    }
    if ($record->{_date}) {
	print $record->{_date}, "\n";
    }

    my($id) = $record->{id};
    my $enddate;
    if ($record->{_date} =~ m{ - (\d{4}-\d{2}-\d{2})}) {
	$enddate = $1;
    }
    print "#: source_id: bvg2024:$id" . ($enddate ? " (bis $enddate)" : "") . ($sourceids->{$id} ? " (INUSE)" : "") . "\n";

}

sub filter_and_split_json {
    my $json = shift;
    my $data = decode_json($json);
    my %records;
    for my $element (@$data) {
	next if ($element->{"messageType"}||'') eq "ELEVATOR";

	inject_title($element);
	inject_date($element);

	delete $element->{$_} for qw(directionOne firstLineLineType hideTime messageCategory scheduled showOnStartpage);

	for my $content (@{ $element->{content} }) {
	    $content->{content} =~ s{<p>}{}g;
	    $content->{content} =~ s{</p>}{\n}g;
	}

	$records{$element->{id}} = $element;
    }
    \%records;
}

sub inject_title {
    my $record = shift;

    my($lines, $from, $to);

    {
	$lines = '';

	my %linetype_to_lines;
	for my $lines_element (@{$record->{lines}}) {
	    while(my($linetype, $_lines) = each %$lines_element) {
		for my $line (@$_lines) {
		    push @{ $linetype_to_lines{$linetype} }, $line->{name};
		}
	    }
	}
	my $need_sep;
	for my $linetype (sort keys %linetype_to_lines) {
	    if ($need_sep) {
		$lines .= ', ';
	    }
	    $lines .= ucfirst($linetype) . ' ';
	    $lines .= join(',', @{ $linetype_to_lines{$linetype} });
	    $need_sep = 1;
	}
    }

    $from = $record->{stationOne}{displayName} if $record->{stationOne};
    $to   = $record->{stationTwo}{displayName} if $record->{stationTwo};

    my $title = $lines . ($from || $to ? " " . join(" - ", ($from||()), ($to||())) : "");
    $record->{_title} = $title;
}

sub inject_date {
    my $record = shift;

    my $date = '';
    if ($record->{startDate}) {
	(my $startDate = $record->{startDate}) =~ s{\+\d+:\d+$}{};
	$startDate =~ s{T}{ };
	$date .= $startDate;
    } else {
	$date .= '...';
    }
    $date .= ' - ';
    if ($record->{endDate}) {
	(my $endDate = $record->{endDate}) =~ s{\+\d+:\d+$}{};
	$endDate =~ s{T}{ };
	$date .= $endDate;
    } else {
	$date .= '...';
    }

    $record->{_date} = $date;
}

sub print_raw_serialized {
    my $record = shift;
    binmode STDOUT, ':raw';
    if ($as_yaml) {
	print Dump($record);
    } else {
	print JSON::XS->new->pretty->canonical->utf8->encode($record);
    }
    binmode STDOUT, ':utf8';
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
