#!/usr/bin/perl -w
# -*- perl -*-

#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Geo::METAR;
use Getopt::Long;
use LWP::UserAgent;
use Strassen::Core;

my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=";

sub usage () {
    die <<EOF;
usage $0 [-sitecode ...] [datadirectory | icaofile]
EOF
}

my $wanted_site_code;
GetOptions("sitecode=s" => \$wanted_site_code)
    or usage;

my $data_dir_or_file = shift;
usage if (!defined $data_dir_or_file);

my $file;
if (-d $data_dir_or_file) {
    $file = $data_dir_or_file . '/icao';
} else {
    $file = $data_dir_or_file;
}

my $s = Strassen->new($file);
my $ua = LWP::UserAgent->new;

my @sites;

$s->init;
while() {
    my $r = $s->next;
    last if !@{ $r->[Strassen::COORDS] };
    my($site_code) = $r->[Strassen::NAME] =~ m{^(\S+)};
    next if (defined $wanted_site_code && $wanted_site_code ne $site_code);
    push @sites, { sitecode => $site_code, record => $r };
}

if ($wanted_site_code && !@sites) {
    die "Could not find '$wanted_site_code' in '$file'.\n";
}

for my $site_def (@sites) {
    my($site_code, $r) = @{$site_def}{qw(sitecode record)};

    my $url = $metar_url . $site_code;
    my $resp = $ua->get($url);
    if (!$resp) {
	warn "Fetching for $r->[Strassen::NAME] failed: " . $resp->status_line;
	next;
    }

    my $content = $resp->content;
    $content =~ s/\n//g;
    $content =~ m/($site_code\s\d+Z.*?)</g;
    my $metar = $1;
    if (length $metar < 10) {
	warn "METAR for $r->[Strassen::NAME] too short: '$metar'. Skipping...\n";
	next;
    }

    my $m = Geo::METAR->new;
    $m->metar($metar);
    warn "$site_code: " . $m->TEMP_C
}
