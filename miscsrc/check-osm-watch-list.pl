#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2016,2018,2019,2022,2023 Slaven Rezic. All rights reserved.
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
		    ($locale_encoding =~ /utf-8/i || $] >= 5.029009 ? \*STDERR : ()), # disabled on non-utf-8 systems because of https://rt.perl.org/Ticket/Display.html?id=123489
		    # STDIN not needed here
		   ) {
	    binmode $fh, ":encoding($locale_encoding)";
	}
    }
}

our $VERSION = '0.06';

my $osm_watch_list = "$bbbike_rootdir/tmp/osm_watch_list";
my $osm_file = "$bbbike_rootdir/misc/download/osm/berlin.osm.bz2";
my $osm_api_url = 'https://api.openstreetmap.org/api/0.6';
my $osm_url = 'https://www.openstreetmap.org';
my $overpass_api_url = 'https://overpass-api.de/api/interpreter';

my $show_unchanged;
my $quiet;
my $show_diffs;
my $new_file;
my $with_notes = 1;
my $method = 'overpass';
my $diff_context = 0;
GetOptions(
	   "show-unchanged" => \$show_unchanged,
	   "diff!" => \$show_diffs,
	   "q|quiet" => \$quiet,
	   "osm-watch-list=s" => \$osm_watch_list,
	   "osm-file=s" => \$osm_file,
	   "new-file=s" => \$new_file,
	   'without-notes' => sub { $with_notes = 0 },
	   'method=s' => \$method,
	   'diff-context=i' => \$diff_context,
	  )
    or die "usage: $0 [-show-unchanged] [-q|-quiet] [-diff] [-diff-context lines] [-osm-watch-list ...] [-new-file ...] [-without-notes] [-method overpass|api|osm-file]\n";

if ($method !~ m{^(osm-file|api|overpass)$}) {
    die "Allowed methods are 'overpass', 'api' and 'osm-file', specified was '$method'";
}

my $ua;
if ($show_diffs || $method eq 'api' || $method eq 'overpass') {
    require XML::LibXML;
}
if ($show_diffs) {
    require Text::Diff;
}
if ($with_notes) {
    require JSON::XS;
}
if ($show_diffs || $with_notes || $method eq 'api' || $method eq 'overpass') {
    require LWP::UserAgent;
    $ua = LWP::UserAgent->new(keep_alive => 1);
    $ua->agent("check-osm-watch-list/$VERSION "); # + add lwp UA string
    $ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
}
if ($method eq 'api') { # caching not needed with overpass
    if (eval { require HTTP::Cache::Transparent; 1 }) {
	my $cache_dir = "$ENV{HOME}/.cache/check-osm-watch-list";
	require File::Path;
	File::Path::make_path($cache_dir);
	HTTP::Cache::Transparent::init({
	    BasePath => $cache_dir,
	    MaxAge   => 24,
	    NoUpdate => 86400,
	});
	# XXX probably need to implement a cleanup mechanism
    } else {
	warn "INFO: HTTP::Cache::Transparent not available, working without cache.\n";
    }
}

if ($method eq 'osm-file') {
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
	my $url = "$osm_api_url/notes/$id.json";
	my $human_url = "$osm_url/note/$id";
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    warn "ERROR: Cannot fetch $url: " . $resp->dump;
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

my $changed_count = 0;
my $deleted_count = 0;
my %consumed;
my $handle_record = sub ($$$) {
    my($type, $id, $new_version) = @_;
    my $type_id = "$type/$id";
    if (my $record = $id_to_record{$type_id}) {
	my $old_version = $record->{version};
	if ($old_version != $new_version) {
	    warn "CHANGED: $type_id (version $old_version -> $new_version) ($record->{info})\n";
	    if ($show_diffs) {
		print STDERR "*** URL: $osm_url/browse/$type_id\n";
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
	warn "ERROR: Strange: '$type_id' is not in the watch list? Cannot find record in watch file?";
    }
};
if ($method eq 'osm-file') {
    my $egrep_prog;
    if ($osm_file =~ m{\.bz2$}) {
	$egrep_prog = 'bzegrep';
    } elsif ($osm_file =~ m{\.gz$}) {
	$egrep_prog = 'zegrep';
    } else {
	$egrep_prog = 'egrep';
    }

    my %by_type_rx;
    for my $type (qw(node way relation)) {
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
	if (my($type, $id) = $_ =~ m{<(way|node|relation)\s+id="(\d+)"}) {
	    if (my($new_version) = $_ =~ m{version="(\d+)"}) {
		$handle_record->($type, $id, $new_version);
	    } else {
		warn "ERROR: Cannot find version in string '$_'";
	    }
	} else {
	    warn "ERROR: Cannot parse string '$_'";
	}
    }
} elsif ($method eq 'api') {
    my $p = XML::LibXML->new;
    for my $type_id (sort keys %id_to_record) {
	my($type, $id) = split m{/}, $type_id;
	my $url = "$osm_api_url/$type/$id";
	my $resp = $ua->get($url);
	if ($resp->is_success) {
	    my $root = $p->parse_string($resp->decoded_content)->documentElement;
	    my $new_version = $root->findvalue('/osm/'.$type.'/@version');
	    $handle_record->($type, $id, $new_version);
	} elsif ($resp->code == 410) {
	    # 410 Gone handled later --- it's not consumed, so it's deleted
	} else {
	    die "ERROR: while fetching $url: " . $resp->dump;
	}
    }
} elsif ($method eq 'overpass') {
    my $p = XML::LibXML->new;
    my %type_to_ids;
    for my $type_id (sort keys %id_to_record) {
	my($type, $id) = split m{/}, $type_id;
	push @{ $type_to_ids{$type} }, $id;
    }
    my $feature_query_lines = join("", map {
	"  $_(id:" . join(",", @{ $type_to_ids{$_} }) . ");\n";
    } keys %type_to_ids);
    my $query = <<EOF;
[out:xml][timeout:60];
(
$feature_query_lines
);
out meta;
EOF
    my $resp = $ua->post($overpass_api_url, { data => $query });
    if ($resp->is_success) {
	my $root = $p->parse_string($resp->decoded_content)->documentElement;
	for my $node ($root->findnodes('/osm/node | /osm/way | /osm/relation')) {
	    my $type = $node->nodeName;
	    my $id = $node->findvalue('./@id');
	    my $new_version = $node->findvalue('./@version');
	    $handle_record->($type, $id, $new_version);
	}
    } else {
	die "ERROR: while fetching $overpass_api_url:\n" . $resp->dump(maxlength => 4) . "\n" . $resp->decoded_content;
    }

} else {
    die "FATAL ERROR: Unknown method '$method', should not happen";
}

while(my($k,$v) = each %id_to_record) {
    if (!$consumed{$k}) {
	warn "DELETED: could not find $k in osm data. Removed? If so, then look at $osm_url/browse/$k . Or forgotten brb marker?\n";
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

    my $url = "$osm_api_url/$type/$id/history";
    my $resp = $ua->get($url);
    if (!$resp->is_success) {
	warn "ERROR: while fetching <$url>: " . $resp->dump;
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
		my $diff = Text::Diff::diff(\$old_string, \$new_string, { CONTEXT => $diff_context });
		if ($diff_context == 0) {
		    $diff =~ s/^\@\@ .*\n//mg;
		}
		warn $diff, "\n";
		my($changeset) = $this_version->findvalue('./@changeset');
		if ($changeset) {
		    warn "Changeset URL: $osm_url/changeset/$changeset\n";
		    warn "OSMCha URL:    https://osmcha.org/changesets/$changeset/\n";
		    warn "achavi-URL:    https://overpass-api.de/achavi/?changeset=$changeset&relations=true\n";
		}
		warn "="x70, "\n";
	    }
	}
    }
}

__END__

=head1 NAME

check-osm-watch-list.pl - check if something happened in OpenStreetMap data

=head1 SYNOPSIS

Check Berlin data, using the "overpass" method, and showing diffs:

    ./check-osm-watch-list.pl -diff -method overpass

Check Brandenburg data:

    ./check-osm-watch-list.pl -diff -method overpass -osm-watch-list ../../tmp/osm_watch_list_brandenburg

=head1 DESCRIPTION

=head2 BASIC OPERATION

Check if OpenStreetMap features referenced with "osm_watch" directives
in BBBike data got new versions. If C<-diff> specified, then a diff
between the previously checked version and the current version for
every feature is shown.

The first diff line with the new version, looking like

    +<way id="1234567890" visible="true" version="42" changeset="9876543210" ...

may be selected and then updated to the new version using the emacs function

    M-x bbbike-update-osm-watch

(if F<miscsrc/bbbike.el> is loaded into emacs).

=head2 PREREQUISITES

Prerequisite is the existence of the files F<tmp/osm_watch_list> and
F<tmp/osm_watch_list_brandenburg>. These files may be generated using
the Makefile target C<osm-watch-lists> in the F<data> directory.

=head2 METHODS

There are currently three methods for fetching the OpenStreetMap data.

Using C<-method overpass> (default) one API call against the overpass-turbo API
is done to fetch all osm_watch features. This is currently the
preferred method.

Using C<-method api> an API call is done for every osm_watch feature.

Using C<-method osm-file> it's expected that a complete
C<.osm>, C<.osm.gz> C<.osm.bz2> with Berlin or Brandenburg data
exists. This path to this file should be specified with the
C<-osm-file> option. This script does not obtain the required osm
files; see L<osm_watch_tasks> for a script doing this.

The former two methods do not need the help of a download script, and
typically need less bandwidth (C<api> for 500 watches about 2 MB,
C<overpass> even less) than downloading complete osm files (Berlin,
for example, is gzip-compressed more than 120 MB at the time of
writing).

=head1 AUTHOR

Slaven Rezic

=head1 SEE ALSO

L<osm_watch_tasks>.

=cut
