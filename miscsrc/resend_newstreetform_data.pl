#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";
use LWP::UserAgent;
use Getopt::Long;
require "$FindBin::RealBin/../BBBikeVar.pm";

my $url = "http://localhost/bbbike/cgi/mapserver_comment.cgi";

my $doit;
my $format = 'yaml';
GetOptions(
    "doit-local" => sub { $doit = 'local' },
    "doit-live"  => sub { $doit = 'prod' },
    "format=s"   => \$format,
)
    or die "usage: $0 [-doit-local|-doit-live] [-format yaml|dd]\n";

if ($doit && $doit eq 'prod') {
    $BBBike::BBBIKE_DIRECT_WWW = $BBBike::BBBIKE_DIRECT_WWW if 0; # cease -w
    ($url = $BBBike::BBBIKE_DIRECT_WWW) =~ s{bbbike.cgi$}{mapserver_comment.cgi};
}

my $res = $format eq 'yaml' ? parse_fh_yaml(\*STDIN) : parse_fh_dd(\*STDIN);
my $env = $res->{env};
my $param = $res->{param};

$param->{encoding} = 'utf-8' if !defined $param->{encoding};
$param->{__resent__} = scalar localtime;

if ($doit) {
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->post($url, $param, %$env);
    require Data::Dumper; print STDERR Data::Dumper->new([$resp],[qw()])->Indent(1)->Useqq(1)->Dump;
} else {
    print STDERR "Would send to $url (or the production counterpart)\n";
    require Data::Dumper; print STDERR Data::Dumper->new([$param, $env],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump;
}

sub parse_fh_yaml {
    my $fh = shift;
    my $found_yaml_marker;
    while(<$fh>) {
	if (/^---$/) {
	    $found_yaml_marker = 1;
	    last;
	}
    }
    if (!$found_yaml_marker) {
	die "Cannot find YAML start marker (---)";
    }
    my $yaml = do { local $/; <$fh> };
    require BBBikeYAML;
    my $d = BBBikeYAML::Load($yaml);
    for my $k (keys %$d) {
	if (ref $d->{$k} eq 'HASH') {
	    while(my($k2,$v2) = each %{ $d->{$k} }) {
		$d->{$k.'.'.$k2} = $v2;
	    }
	    delete $d->{$k};
	}
    }
    +{ param => $d,
       env   => {}, # note: ENV is also in param. Do not use the dubious ENV-to-http-header hack
     };
}

sub parse_fh_dd {
    my $fh = shift;

    require Safe;
    my $c = Safe->new;

    my $param = {};
    my $env = {};
    while(<$fh>) {
	chomp;
	if (/^\$(\S+)\s*=\s*(\"?.*\"?);$/) {
	    my $key = $1;
	    my $val = $c->reval($2);
	    $param->{$key} = $val;
	} elsif (/^\s+\"(.*?)\" => (\"?.*\"?),?$/) {
	    my $key = $1;
	    my $val = $c->reval($2);
	    if ($key =~ /^HTTP_(.*)/) {
		(my $http_env = $1) =~ s{_}{-}g;
		$http_env = lc $http_env;
		next if $http_env =~ m{^(host)$}i;
		$env->{$http_env} = $val;
	    }
	}
    }

    +{ param => $param,
       env   => $env,
     };
}

__END__
