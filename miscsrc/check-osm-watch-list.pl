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

my $osm_watch_list = "$FindBin::RealBin/../data/osm_watch_list";
my $bbbike_rootdir = "/home/e/eserte/src/bbbike"; # cannot use $FindBin::RealBin here, because of symlinking problems
my $berlin_osm_bz2 = "$bbbike_rootdir/misc/download/osm/berlin.osm.bz2";

my $show_unchanged;
GetOptions("show-unchanged" => \$show_unchanged)
    or die "usage?";

if (! -e $berlin_osm_bz2) {
    die "FATAL: $berlin_osm_bz2 is missing, please download!";
}
if (-M $berlin_osm_bz2 >= 7) {
    warn "WARN: $berlin_osm_bz2 is older than a week (" . sprintf ("%1.f", -M $berlin_osm_bz2) . " days), consider to update...\n";
} else {
    warn "INFO: Age of $berlin_osm_bz2: " . sprintf("%.1f", -M $berlin_osm_bz2) . " days\n";
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
    my $rx = '(' . join("|", map { qq{<$_->{type} id="$_->{id}"} } @osm_watch_list_data) . ')';
    my @grep_cml = ('bzegrep', '--', $rx, $berlin_osm_bz2);
    warn "INFO: Running '@grep_cml'...\n";
    open my $fh, '-|', @grep_cml
	or die "FATAL: $!";
    while(<$fh>) {
	chomp;
	if (my($type, $id) = $_ =~ m{<(way|node)\s+id="(\d+)"}) {
	    if (my($version) = $_ =~ m{version="(\d+)"}) {
		my $type_id = "$type/$id";
		if (my $record = $id_to_record{$type_id}) {
		    if ($record->{version} != $version) {
			warn "CHANGED: $type_id (version $record->{version} -> $version) ($record->{info})\n";
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
__END__
