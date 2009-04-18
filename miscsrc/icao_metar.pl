#!/usr/bin/perl
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
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Geo::METAR;
use Getopt::Long;
use LWP::UserAgent;
use Strassen::Core;
use Time::Local qw(timegm);

my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=";

sub usage () {
    die <<EOF;
usage $0 [-sitecode ...] [-wettermeldung] [datadirectory | icaofile]
EOF
}

my $wanted_site_code;
my $wettermeldung_compatible;
GetOptions("sitecode=s" => \$wanted_site_code,
	   "wettermeldung!" => \$wettermeldung_compatible,
	  )
    or usage;

if ($wettermeldung_compatible && !$wanted_site_code) {
    die "Please specify also -sitecode if you use -wettermeldung!\n";
}

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
    next if ($site_code eq 'EDDI'); # Berlin-Tempelhof is closed, the data is outdated!
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

    if ($wettermeldung_compatible) {
	print format_wettermeldung($m);
    } else {
	print "$site_code: " . $m->dump . "\n";
    }
}

sub format_wettermeldung {
    my $m = shift;

    my @t = gmtime;
    $t[4]++;
    $t[5]+=1900;
    if ($m->DATE > $t[3]) {
	$t[4]--;
	if ($t[4] < 1) {
	    $t[4] = 12;
	    $t[5]--;
	}
    }
    $t[3] = $m->DATE;
    my($H,$M) = $m->TIME =~ m{^(\d+):(\d+)};
    $t[2] = $H;
    $t[1] = $M;
    $t[0] = 0;

    $t[4]--;
    $t[5]-=1900;
    my $time = timegm(@t);

    my @l = localtime $time;
    $l[4]++;
    $l[5]+=1900;

    join('|',
	 $l[3].".".$l[4].".".$l[5],
	 $l[2].".".$l[1],
	 $m->TEMP_C+0,
	 $m->ALT_HP+0,
	 $m->WIND_DIR_ABB,
	 sprintf("%.1f", $m->WIND_MS), # XXX is this max or avg?
	 "", # XXX humidity is missing, calculate from dew point?
	 "", # XXX wind avg?
	 "", # XXX precipitation HOURLY_PRECIP?
	 join(", ", @{$m->WEATHER}, @{$m->SKY}),
	);
}

__END__

=head1 TODO

Aufrufoptionen:

 * datadir/icaobbd: return data for all in file
 * datadir/icaobbd -near ...: return data for the nearest sitecode
 * datadir/icaobbd -sitecode ...: file not used!
 * -sitecode: return data fo this site

=cut
