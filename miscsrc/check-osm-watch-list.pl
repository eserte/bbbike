#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2016,2018 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use FindBin;
my $bbbike_rootdir; BEGIN { $bbbike_rootdir = "$FindBin::RealBin/.." }

use Getopt::Long;
use IPC::Run qw(run);

{
    # I don't understand "use open". Especially how it may be used to
    # set STDIN/OUT/ERR to locale encoding.
    require encoding;
    my $locale_encoding = encoding::_get_locale_encoding(); # yes, unfortunately using the private function
    if ($locale_encoding) {
	for my $fh (
		    \*STDOUT,
		    # \*STDERR, # disabled because of https://rt.perl.org/Ticket/Display.html?id=123489
		    # STDIN not needed here
		   ) {
	    binmode $fh, ":encoding($locale_encoding)";
	}
    }
}

our $VERSION = '0.03';

my $osm_watch_list = "$bbbike_rootdir/tmp/osm_watch_list";
my $osm_file = "$bbbike_rootdir/misc/download/osm/berlin.osm.bz2";

my $show_unchanged;
my $quiet;
my $show_diffs;
my $new_file;
my $with_notes = 1;
GetOptions(
	   "show-unchanged" => \$show_unchanged,
	   "diff!" => \$show_diffs,
	   "q|quiet" => \$quiet,
	   "osm-watch-list=s" => \$osm_watch_list,
	   "osm-file=s" => \$osm_file,
	   "new-file=s" => \$new_file,
	   'without-notes' => sub { $with_notes = 0 },
	  )
    or die "usage: $0 [-show-unchanged] [-q|-quiet] [-diff] [-osm-watch-list ...] [-new-file ...] [-without-notes]";

my $egrep_prog;
if ($osm_file =~ m{\.bz2$}) {
    $egrep_prog = 'bzegrep';
} elsif ($osm_file =~ m{\.gz$}) {
    $egrep_prog = 'zegrep';
} else {
    $egrep_prog = 'egrep';
}

my $ua;
if ($show_diffs) {
    require XML::LibXML;
    require Text::Diff;
}
if ($with_notes) {
    require JSON::XS;
}
if ($show_diffs || $with_notes) {
    require LWP::UserAgent;
    $ua = LWP::UserAgent->new;
    $ua->agent("check-osm-watch-list/$VERSION "); # + add lwp UA string
}

if (! -e $osm_file) {
    die "FATAL: $osm_file is missing, please download!";
}
if (-M $osm_file >= 7) {
    warn "WARN: $osm_file is older than a week (" . sprintf ("%1.f", -M $osm_file) . " days), consider to update...\n";
} else {
    if (!$quiet) {
	warn "INFO: Age of $osm_file: " . sprintf("%.1f", -M $osm_file) . " days\n";
    }
}

my @osm_watch_list_data;
my @notes_data;
my %id_to_record;
my @file_lines;
{
    open my $fh, $osm_watch_list
	or die "Can't open $osm_watch_list: $!";
    binmode $fh, ':encoding(utf-8)';
    while(<$fh>) {
	push @file_lines, $_;
	chomp;
	next if m{^\s*#};
	next if m{^\s*$};
	if (my($type, $rest) = $_ =~ m{^(way|node|relation|note)\s+(.*)}) {
	    if ($type eq 'note') {
		my($id, $comments_count) = split /\s+/, $rest;
		push @notes_data, { type => 'note', id => $id, comments_count => $comments_count };
	    } else {
		my($id, $version, $info);
		if (($id, $version, $info) = $rest =~ m{^id="(\d+)"\s+version="(\d+)"\s+(.*)$}) {
		    push @osm_watch_list_data, { type => $type, id => $id, version => $version, info => $info, line => $. };
		    $id_to_record{"$type/$id"} = $osm_watch_list_data[-1];
		} else {
		    warn "ERROR: Cannot parse string '$_'";
		}
	    }
	} else {
	    warn "ERROR: Cannot parse string '$_'";
	}
    }
}

if ($with_notes) {
    for my $note_data (@notes_data) {
	my $id = $note_data->{id};
	my $url = "https://www.openstreetmap.org/api/0.6/notes/$id.json";
	my $human_url = "https://www.openstreetmap.org/note/$id";
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    warn "ERROR: Cannot fetch $url: " . $resp->status_line;
	} else {
	    my $data = JSON::XS::decode_json($resp->decoded_content(charset => 'none'));
	    my $properties = $data->{properties};
	    if ($properties->{status} ne 'open') {
		warn "CHANGE: note $human_url: status is not 'open', but '$properties->{status}'\n";
	    } else {
		my $now_comments_count = @{ $properties->{comments} };
		if ($now_comments_count != $note_data->{comments_count}) {
		    warn "CHANGE: note $human_url: number of comments changed (now $now_comments_count, was " . scalar($note_data->{comments_count}) . ")\n";
		}
	    }
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
	    $by_type_rx{$type} = qq{<$type id="} . '(' . join("|", map { $_->{id} } @filtered_data) . ')' . qq{"};
	}
    }
    my $rx = '(' . join("|", values %by_type_rx) . ')';
    my @grep_cml = ($egrep_prog, '--', $rx, $osm_file);
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
			    print STDERR "*** URL: http://www.openstreetmap.org/browse/$type/$id\n";
			    show_diff($type, $id, $old_version, $new_version);
			}
			if ($new_file) {
			    $file_lines[$record->{line}-1] =~ s{version="$old_version"}{version="$new_version"};
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

my $deleted_count = 0;
while(my($k,$v) = each %id_to_record) {
    if (!$consumed{$k}) {
	warn "DELETED: could not find $k in osm data. Removed? Forgotten brb marker?\n";
	$deleted_count++;
	if ($show_diffs) {
	    my($type, $id, $old_version) = @{$v}{qw(type id version)};
	    show_diff($type, $id, $old_version, -1);
	}
    }
}

if ($changed_count || $deleted_count) {
    my @terms;
    if ($changed_count) {
	push @terms, "$changed_count changed entry/ies";
    }
    if ($deleted_count) {
	push @terms, "$deleted_count deleted entry/ies";
    }
    print STDERR "INFO: Found " . join(" and ", @terms) . ".\n";
    if ($new_file) {
	open my $fh, ">", $new_file
	    or die "ERROR: Can't write to $new_file: $!";
	print $fh @file_lines;
	close $fh
	    or die "ERROR: problem while writing to $new_file: $!";
	print STDERR "INFO: the new file was written to $new_file\n";
	print STDERR "INFO: try:         diff $new_file $osm_watch_list\n";
	print STDERR "INFO: and then:    cp $new_file $osm_watch_list\n";
	if ($deleted_count) {
	    print STDERR "WARN: the new file does not have the possibly deleted records removed!\n";
	}
    }
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
