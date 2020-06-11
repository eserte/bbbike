#!/usr/bin/env perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2018,2019,2020 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use warnings;
use FindBin;
use JSON::XS 'decode_json';
use LWP::UserAgent;
use File::Basename qw(basename);
use File::Glob qw(bsd_glob);
use File::Path qw(make_path);
use Getopt::Long;

## REPO BEGIN
## REPO NAME slurp /home/eserte/src/srezic-repository 
## REPO MD5 241415f78355f7708eabfdb66ffcf6a1
#
#=head2 slurp($file)
#
#=for category File
#
#Return content of the file I<$file>. Die if the file is not readable.
#
#An alternative implementation would be
#
#    sub slurp ($) { open my $fh, shift or die $!; local $/; <$fh> }
#
#but this probably won't work with very old perls.
#
#=cut

sub slurp ($) {
    my($file) = @_;
    my $fh;
    my $buf;
    open $fh, $file
	or die "Can't slurp file $file: $!";
    local $/ = undef;
    $buf = <$fh>;
    close $fh;
    $buf;
}
# REPO END

my $do_fetch;
my $do_confirm;
GetOptions(
	   "fetch" => \$do_fetch,
	   "confirm" => \$do_confirm,
	  )
    or die "usage?";

my $plannings_dir = "$ENV{HOME}/.cache/fixmyberlin-plannings";
make_path $plannings_dir if !-d $plannings_dir;

if ($do_fetch) {
    my $ua = LWP::UserAgent->new(keep_alive => 1);
    #$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable()); # XXX cannot use this, as it's written compressed to disk!
    #XXX needed? $ua->default_header('Accept' => 'application/json');
    my $next_url = 'https://api.fixmyberlin.de/api/projects';
    while ($next_url) {
	if ($do_confirm) {
	    warn "Fetch $next_url? <RETURN>\n"; <STDIN>;
	}
	my $store_file = "$plannings_dir/" . basename($next_url);
	warn "About to fetch $next_url to $store_file...\n";
	my $resp = $ua->get($next_url, ':content_file' => $store_file);
	if (!$resp->is_success) {
	    die "Fetching $next_url failed: " . $resp->status_line;
	}
	my $data = decode_json slurp $store_file;
	$next_url = $data->{next};
    }
}

my @results;
for my $file (bsd_glob("$plannings_dir/projects*")) {
    my $d = decode_json slurp $file;
    push @results, @{ $d->{results} };
}

binmode STDOUT, ':utf8';
print <<EOF;
#: encoding: utf-8
#: map: polar
#: line_color.X: #000080
#: 
EOF
for my $result (map { $_->[1] }
		sort { $b->[0] <=> $a->[0] }
		map {
		    my($id) = $_->{url} =~ m{/(\d+)$};
		    [$id, $_];
		} @results) {
    (my $desc = $result->{description}) =~ s{[\t\n\r]}{ }g;
    my @multi_coordinates;
    if (my $geometry = $result->{geometry}) {
	if      ($geometry->{type} eq 'Point') {
	    push @multi_coordinates, [$geometry->{coordinates}];
	} elsif ($geometry->{type} eq 'LineString') {
	    push @multi_coordinates, $geometry->{coordinates};
	} elsif ($geometry->{type} eq 'MultiLineString') {
	    push @multi_coordinates, @{ $geometry->{coordinates} };
	} else {
	    warn "No support for geometry type '$geometry->{type}' ($desc)\n";
	}
    }
    if (!@multi_coordinates) {
	warn "No coordinates found, fallback to center coordinate ($desc)\n";
	@multi_coordinates = $result->{center}->{coordinates};
    }
    my %seen_coord_string; # yes, duplicates seem to happen
    for my $single_coordinates (@multi_coordinates) {
	my $coord_string = join(" ", map { join(",", trim_accuracy(@$_)) } @$single_coordinates);
	if (!$seen_coord_string{$coord_string}++) {
	    my $url = $result->{url};
	    if ($coord_string eq '') {
		warn "No coordinates at all, create a comment ($desc)\n";
		print "# (coord missing) --- ";
	    }
	    print $result->{phase}, "¦", $desc, "¦", $url, "\tX ", $coord_string, "\n";
	}
    }
}

# Taken from Karte::Polar
sub trim_accuracy {
    my($x, $y) = @_;
    (0+sprintf("%.6f", $x), 0+sprintf("%.6f", $y));
}

__END__
