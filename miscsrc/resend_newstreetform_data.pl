#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: resend_newstreetform_data.pl,v 1.1 2006/08/08 19:05:04 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;
use FindBin;
use LWP::UserAgent;
use Safe;
use Getopt::Long;
require "$FindBin::RealBin/../BBBikeVar.pm";

my $url = "http://www/~eserte/bbbike/cgi/mapserver_comment.cgi";

my $doit;
GetOptions("doit" => \$doit)
    or die "usage: $0 [-doit]";

if ($doit) {
    $BBBike::BBBIKE_DIRECT_WWW = $BBBike::BBBIKE_DIRECT_WWW if 0; # cease -w
    ($url = $BBBike::BBBIKE_DIRECT_WWW) =~ s{bbbike.cgi$}{mapserver_comment.cgi};
}

my $c = Safe->new;

my $res = parse_fh(\*STDIN);
my $env = $res->{env};
my $param = $res->{param};

$param->{__resent__} = scalar localtime;

my $ua = LWP::UserAgent->new;
my $resp = $ua->post($url, $param, %$env);

require Data::Dumper; print STDERR "Line " . __LINE__ . ", File: " . __FILE__ . "\n" . Data::Dumper->new([$resp],[qw()])->Indent(1)->Useqq(1)->Dump; # XXX

sub parse_fh {
    my $fh = shift;
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
