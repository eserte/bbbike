#!/usr/bin/perl
# -*- perl -*-

#
# Copyright (C) 2009,2012,2013,2016,2017,2018,2020,2024,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Fcntl 'SEEK_END';
use Geo::METAR;
use Getopt::Long;
use LWP::UserAgent;
use Time::Local qw(timegm);

#my $metar_url = "http://weather.noaa.gov/cgi-bin/mgetmetar.pl?cccc=";
my $metar_url_cb = sub { "http://tgftp.nws.noaa.gov/data/observations/metar/stations/$_[0].TXT" };

sub usage () {
    die <<EOF;
usage: $0 [-wettermeldung] datadirectory | icaofile
       $0 [-wettermeldung] -near lon,lat datadirectory | icaofile
       $0 [-wettermeldung] -sitecode EDDB
EOF
}

my $wanted_site_code;
my $wettermeldung_compatible;
my $near;
my $o;
my $retry_def;
my $use_fallback;
my $use_auto_fallback;
GetOptions("sitecode=s" => \$wanted_site_code,
	   "wettermeldung!" => \$wettermeldung_compatible,
	   "near=s" => \$near,
	   "o=s" => \$o,
	   "retry-def=s" => \$retry_def,
	   "fallback!" => \$use_fallback,
	   "auto-fallback!" => \$use_auto_fallback,
	  )
    or usage;

if ($use_fallback && $use_auto_fallback) {
    die "Cannot use both -fallback and -auto-fallback.\n";
}

my @retry_sleeps;
if ($retry_def) {
    @retry_sleeps = split /,/, $retry_def;
    die "--retry-def should contain only comma-separated positive integers\n"
	if grep { !/^[1-9]\d*$/ } @retry_sleeps;
}

my $ua = LWP::UserAgent->new;
$ua->default_header('Accept-Encoding' => scalar HTTP::Message::decodable());
$ua->timeout(30);

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

my $got_something = 0;

for my $site_def (@sites) {
    my($site_code, $r) = @{$site_def}{qw(sitecode record)};

    my $content;
    if (!$use_fallback) {
	$content = get_metar_standard($site_code);
    }
    if (!defined $content && ($use_fallback || $use_auto_fallback)) {
	$content = get_metar_mesonet_fallback($site_code);
    }
    next if !defined $content;

    #$content =~ s/\n//g;
    $content =~ m/(\Q$site_code\E\s\d+Z.*)/g;
    my $metar = $1;
    if (length $metar < 10) {
	warn "METAR for $site_code too short: '$metar'. Skipping...\n";
	next;
    }

    my $m = Geo::METAR->new;
    $m->metar($metar);

    $got_something++;

    if ($wettermeldung_compatible) {
	my $line = format_wettermeldung($m);
	if (!$wanted_site_code) {
	    $line .= "|$site_code";
	}
	$line .= "\n";

	if ($o) {
	    my $do_print = 1;
	    if (open my $ifh, $o) {
		if (-s $o > 4096) {
		    seek $ifh, -4096, SEEK_END;
		}
		local $/ = undef;
		my $buf = <$ifh>;
		if ($buf =~ m{.*\n(.+)}s) {
		    if ($1 eq $line) {
			$do_print = 0;
		    }
		} elsif ($buf eq $line) {
		    $do_print = 0;
		}
	    }
	    if ($do_print) {
		open my $ofh, ">>", $o
		    or die "Can't append to $o: $!";
		print $ofh $line;
		close $ofh
		    or die "Error closing $o: $!";
	    }
	} else {
	    print $line;
	}
    } else {
	print "$site_code: " . $m->dump . "\n";
    }
}

if (!$got_something && @retry_sleeps) {
    die "Did not get any data for " . join(", ", map { $_->{sitecode} } @sites) . "\n";
}

sub get_metar_standard {
    my($site_code) = @_;

    my $url = $metar_url_cb->($site_code);
    my @use_retry_sleeps = @retry_sleeps;
    my $resp;
    while (1) {
	$resp = $ua->get($url);
	last if $resp->is_success;
	if ($resp->code >= 500 && @use_retry_sleeps) {
	    my $sleep = shift @use_retry_sleeps;
	    warn "Fetching for $site_code failed with code " . $resp->code . ", but will retry in $sleep second(s)...\n";
	    sleep $sleep;
	} else {
	    last;
	}
    }
    if (!$resp->is_success) {
	warn "Fetching for $site_code (url $url) failed: " . $resp->status_line;
	return undef;
    }

    my $content = $resp->decoded_content;
    $content;
}

sub get_metar_mesonet_fallback {
    my($site_code) = @_;
    require URI;
    require URI::QueryParam;
    my $u = URI->new("https://mesonet.agron.iastate.edu/cgi-bin/request/asos.py");
    my @tomorrow  = gmtime(time+86400);
    my @yesterday = gmtime(time-86400);
    $u->query_param(station     => $site_code);
    $u->query_param(data        => 'metar');
    $u->query_param(year1       => $yesterday[5]+1900);
    $u->query_param(month1      => $yesterday[4]+1);
    $u->query_param(day1        => $yesterday[3]);
    $u->query_param(year2       => $tomorrow[5]+1900);
    $u->query_param(month2      => $tomorrow[4]+1);
    $u->query_param(day2        => $tomorrow[3]);
    $u->query_param(tz          => 'Etc/UTC');
    $u->query_param(format      => 'onlycomma');
    $u->query_param(latlon      => 'no');
    $u->query_param(direct      => 'no');
    $u->query_param(report_type => '2');
    my $url = $u->as_string;
    my $resp = $ua->get($url);
    if (!$resp->is_success) {
	warn "Fetching for $site_code (url $url) failed: " . $resp->status_line;
	return undef;
    }
    my $content = $resp->decoded_content;
    my($last_line) = $content =~ m{\n[^,]+,[^,]+,(.*)\Z}; # also strip two first columns of csv
    $last_line;
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

    my $pressure = $m->pressure || '';
    
    join('|',
	 $l[3].".".$l[4].".".$l[5],
	 $l[2].".".$l[1],
	 $m->TEMP_C+0,
	 $pressure,
	 $m->WIND_DIR_ABB,
	 $wind_max,
	 "", # XXX humidity is missing, calculate from dew point?
	 $wind_avg,
	 "", # XXX precipitation HOURLY_PRECIP?
	 join(", ", @{$m->WEATHER}, @{$m->SKY}),
	);
}

sub kts_to_ms { $_[0] * 1.852    / 3.6 }
sub mph_to_ms { $_[0] * 1.609344 / 3.6 }

__END__

=head1 NAME

icao_metar.pl - fetch and parse the most important weather data

=head1 SYNOPSIS

       icao_metar.pl [-wettermeldung] datadirectory | icaofile
       icao_metar.pl [-wettermeldung] -near lon,lat datadirectory | icaofile
       icao_metar.pl [-wettermeldung] -sitecode EDDB

=head1 DESCRIPTION

This program fetches weather information (expressed as METAR data) for
a given airport from NOAA, and prints this information.

When using the switch C<-wettermeldung>, then one pipe-separated line
with the following fields is printed:

=over

=item * date in the format DD.MM.YYYY (day and month may be single digit)

=item * time in the format HH.MM (hour may be single digit)

=item * temperature in degrees Celsius (integer or with floating point)

=item * pressure in hPa (integer or with floating point, optional, may be empty)

=item * wind direction (using abbrevs like "NW" or "S")

=item * max. wind speed in Beaufort (or m/s?)

=item * humidity (in percent, optional, may be empty)

=item * average wind speed in Beaufort (or m/s?)

=item * precipitation (in mm, optional, may be empty)

=item * weather condition (human readable text, may be English or German, optional)

=back

There are three possibilities to select the location:

=over

=item * specifying a bbd data directory containing an "icao" file or
directly an "icao" bbd file

In this case, all airports with an icao code are tried until the first
one has a result from the NOAA server.

=item * also specifying a data directory or icao file, but together
with a C<-near I<lon,lat>> option

In this case, the list of airports is sorted by distance to the
specified coordinate first.

=item * directly by specifying an icao code

For example "EDDB" for Flughafen Berlin-Brandenburg (BER).

=back

=head2 OPTIONS

Further options:

=over

=item C<-retry-def I<secs>,....>

A comma-separated list of positive integers, to force retries in case
of failure to fetch the URL. The numbers will be used as sleep times
between the retries. Only 5xx errors will cause a retry --- it is
expected that 4xx errors are permanent.

Additionally, if C<-retry-def> is specified and no site could be
fetched, then the script will die. Otherwise there will be no output,
but exit code will still be zero.

=item C<-fallback>

Use fallback URL (L<https://mesonet.agron.iastate.edu>).

=item C<-auto-fallback>

Use the fallback URL only if the regular URL fails. Cannot be used
together with C<-fallback>.

=back

=head1 AUTHOR

Slaven Rezic

=cut
