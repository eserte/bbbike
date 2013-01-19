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
use Getopt::Long;
use IPC::Run qw(run);

our $VERSION = '0.01';

my $osm_watch_list = "$FindBin::RealBin/../data/osm_watch_list";
my $bbbike_rootdir = "/home/e/eserte/src/bbbike"; # cannot use $FindBin::RealBin here, because of symlinking problems
my $berlin_osm_bz2 = "$bbbike_rootdir/misc/download/osm/berlin.osm.bz2";

my $show_unchanged;
my $quiet;
my $show_diffs;
GetOptions(
	   "show-unchanged" => \$show_unchanged,
	   "diff!" => \$show_diffs,
	   "q|quiet" => \$quiet,
	   "osm-watch-list=s" => \$osm_watch_list,
	  )
    or die "usage: $0 [-show-unchanged] [-q|-quiet] [-diff] [-osm-watch-list ...]";

my $ua;
if ($show_diffs) {
    require XML::LibXML;
    require Text::Diff;
    require LWP::UserAgent;
    $ua = LWP::UserAgent->new;
    $ua->agent("check-osm-watch-list/$VERSION "); # + add lwp UA string
}

if (! -e $berlin_osm_bz2) {
    die "FATAL: $berlin_osm_bz2 is missing, please download!";
}
if (-M $berlin_osm_bz2 >= 7) {
    warn "WARN: $berlin_osm_bz2 is older than a week (" . sprintf ("%1.f", -M $berlin_osm_bz2) . " days), consider to update...\n";
} else {
    if (!$quiet) {
	warn "INFO: Age of $berlin_osm_bz2: " . sprintf("%.1f", -M $berlin_osm_bz2) . " days\n";
    }
}

my @osm_watch_list_data;
my %id_to_record;
{
    open my $fh, $osm_watch_list or die $!;
    while(<$fh>) {
	chomp;
	my($type, $id, $version, $info);
	if (($type, $id, $version, $info) = $_ =~ m{^(way|node)\s+id="(\d+)"\s+version="(\d+)"\s+(.*)$}) {
	    push @osm_watch_list_data, { type => $type, id => $id, version => $version, info => $info };
	    $id_to_record{"$type/$id"} = $osm_watch_list_data[-1];
	} else {
	    warn "ERROR: Cannot parse string '$_'";
	}
    }
}

my %consumed;
my $changed_count = 0;
{
    my %by_type_rx;
    for my $type (qw(node way)) {
	my @filtered_data = grep { $_->{type} eq $type } @osm_watch_list_data;
	if (@filtered_data) {
	    $by_type_rx{$type} = qq{<$type id="} . '(' . join("|", map { $_->{id} } @osm_watch_list_data) . ')' . qq{"};
	}
    }
    my $rx = '(' . join("|", values %by_type_rx) . ')';
    my @grep_cml = ('bzegrep', '--', $rx, $berlin_osm_bz2);
    if (!$quiet) {
	warn "INFO: Running '@grep_cml'...\n";
    }
    open my $fh, '-|', @grep_cml
	or die "FATAL: $!";
    while(<$fh>) {
	chomp;
	if (my($type, $id) = $_ =~ m{<(way|node)\s+id="(\d+)"}) {
	    if (my($new_version) = $_ =~ m{version="(\d+)"}) {
		my $type_id = "$type/$id";
		if (my $record = $id_to_record{$type_id}) {
		    my $old_version = $record->{version};
		    if ($old_version != $new_version) {
			warn "CHANGED: $type_id (version $old_version -> $new_version) ($record->{info})\n";
			if ($show_diffs) {
			    show_diff($type, $id, $old_version, $new_version);
			}
			$changed_count++;
		    } else {
			if ($show_unchanged) {
			    warn "INFO: Found unchanged $type_id\n";
			}
		    }
		    $consumed{$type_id} = 1;
		} else {
		    warn "ERROR: Strange: '$type_id' is not in the watch list?";
		}
	    } else {
		warn "ERROR: Cannot find version in string '$_'";
	    }
	} else {
	    warn "ERROR: Cannot parse string '$_'";
	}
    }
}

while(my($k,$v) = each %id_to_record) {
    if (!$consumed{$k}) {
	warn "ERROR: could not find $k in osm data. Removed?\n";
    }
}

if ($changed_count) {
    warn "INFO: Found $changed_count changed entry/ies.\n";
    exit 2;
}

sub show_diff {
    my($type, $id, $old_version, $new_version) = @_;

    my $url = "http://www.openstreetmap.org/api/0.6/$type/$id/history";
    my $resp = $ua->get($url);
    if (!$resp->is_success) {
	warn "ERROR: while fetching <$url>: " . $resp->status_line;
    } else {
	my $p = XML::LibXML->new;
	my $root = $p->parse_string($resp->decoded_content)->documentElement;
	my($last_version) = $root->findnodes('/osm/'.$type.'[@version='.$old_version.']');
	if (!$last_version) {
	    warn "ERROR: strange, couldn't find old version $old_version in history\n" . $root->serialize(1);
	} else {
	    my $cond;
	    if ($new_version == -1) {
		$cond = '[position()=last()]';
	    } else {
		$cond = '[@version='.$new_version.']';
	    }
	    my($this_version) = $root->findnodes('/osm/'.$type.$cond);
	    if (!$this_version) {
		warn "ERROR: strange, couldn't find new version $new_version in history\n" . $root->serialize(1);
	    } else {
		my $old_string = $last_version->serialize(1);
		my $new_string = $this_version->serialize(1);
		my $diff = Text::Diff::diff(\$old_string, \$new_string);
		warn $diff, "\n", ("="x70), "\n";
	    }
	}
    }
}

__END__
