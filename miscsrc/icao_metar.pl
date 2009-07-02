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
use Time::Local qw(timegm);

my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=";

sub usage () {
    die <<EOF;
usage: $0 [-wettermeldung] datadirectory | icaofile
       $0 [-wettermeldung] -near lon,lat datadirectory | icaofile
       $0 [-wettermeldung] -sitecode EDDT
EOF
}

my $wanted_site_code;
my $wettermeldung_compatible;
my $near;
GetOptions("sitecode=s" => \$wanted_site_code,
	   "wettermeldung!" => \$wettermeldung_compatible,
	   "near=s" => \$near,
	  )
    or usage;

my $ua = LWP::UserAgent->new;

my @sites;
if ($wanted_site_code) {
    @sites = ({ sitecode => $wanted_site_code });
} else {
    require Strassen::Core;

    my $near_s;
    if ($near) {
	require Karte::Polar;
	require Karte::Standard;
	require Strassen::Util;

	my($lon,$lat) = split /,/, $near;
	if (!defined $lat) {
	    usage;
	}
	no warnings 'once';
	$near_s = join(",", $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($lon,$lat)));
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

    $s->init;
    while() {
	my $r = $s->next;
	last if !@{ $r->[Strassen::COORDS()] };
	my($site_code) = $r->[Strassen::NAME()] =~ m{^(\S+)};
	next if ($site_code eq 'EDDI'); # Berlin-Tempelhof is closed, the data is outdated!
	my $distance;
	if ($near_s) {
	    $distance = Strassen::Util::strecke_s($near_s, $r->[Strassen::COORDS()][0]);
	}
	push @sites, { sitecode => $site_code,
		       record => $r,
		       (defined $distance ? (distance => $distance) : ()),
		     };
    }

    if ($near_s) {
	@sites = (sort { $a->{distance} <=> $b->{distance} } @sites)[0];
    }
}

if (!@sites) {
    die "Could not find any site.\n";
}

for my $site_def (@sites) {
    my($site_code, $r) = @{$site_def}{qw(sitecode record)};

    my $url = $metar_url . $site_code;
    my $resp = $ua->get($url);
    if (!$resp) {
	warn "Fetching for $site_code failed: " . $resp->status_line;
	next;
    }

    my $content = $resp->content;
    $content =~ s/\n//g;
    $content =~ m/($site_code\s\d+Z.*?)</g;
    my $metar = $1;
    if (length $metar < 10) {
	warn "METAR for $site_code too short: '$metar'. Skipping...\n";
	next;
    }

    my $m = Geo::METAR->new;
    $m->metar($metar);

    if ($wettermeldung_compatible) {
	print format_wettermeldung($m);
	if (!$wanted_site_code) {
	    print "|$site_code";
	}
	print "\n";
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

    my $wind_max = '';
    if (defined $m->WIND_GUST_KTS && $m->WIND_GUST_KTS ne '') {
	$wind_max = sprintf "%.1f", kts_to_ms($m->WIND_GUST_KTS);
    } elsif (defined $m->WIND_GUST_MPH && $m->WIND_GUST_KTS ne '') {
	$wind_max = sprintf "%.1f", mph_to_ms($m->WIND_GUST_MPH);
    }

    my $wind_avg = '';
    if (defined $m->WIND_KTS && $m->WIND_KTS ne '') {
	$wind_avg = sprintf "%.1f", kts_to_ms($m->WIND_KTS);
    } elsif (defined $m->WIND_MPH && $m->WIND_MPH ne '') {
	$wind_avg = sprintf "%.1f", mph_to_ms($m->WIND_MPH);
    }

    join('|',
	 $l[3].".".$l[4].".".$l[5],
	 $l[2].".".$l[1],
	 $m->TEMP_C+0,
	 $m->ALT_HP+0,
	 $m->WIND_DIR_ABB,
	 $wind_max,
	 "", # XXX humidity is missing, calculate from dew point?
	 $wind_avg,
	 "", # XXX precipitation HOURLY_PRECIP?
	 join(", ", @{$m->WEATHER}, @{$m->SKY}),
	);
}

sub kts_to_ms { $_[0] / 1.852    / 3.6 }
sub mph_to_ms { $_[0] / 1.609344 / 3.6 }

__END__

=head1 TODO

Aufrufoptionen:

 * datadir/icaobbd: return data for all in file
 * datadir/icaobbd -near ...: return data for the nearest sitecode
 * datadir/icaobbd -sitecode ...: file not used!
 * -sitecode: return data fo this site

=cut
