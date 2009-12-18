#!/usr/bin/perl -w
# -*- perl -*-

#
# Copyright (C) 2005 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# $Id: browserinfo.t,v 1.5 2005/07/17 21:30:58 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ($FindBin::RealBin,
	 "$FindBin::RealBin/../lib",
	);
use BrowserInfo;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

BEGIN { plan tests => 10 }

#use vars qw($uaprofdir);
#$uaprofdir = "$FindBin::RealBin/../tmp/uaprof";
#mkdir $uaprofdir, 0755 if ! -d $uaprofdir;

{
    local $ENV{HTTP_USER_AGENT} = "Nokia6100/1.0";
    local $ENV{HTTP_PROFILE} = "http://nds.nokia.com/uaprof/N6100r100.xml";
    my $bi = BrowserInfo->new;
    my($w,$h) = @{ $bi->{display_size} };
    is($w, 122, "Nokia6100 width");
    is($h, 128, "Nokia6100 height");
    ok($bi->{can_table}, "Nokia6100 can tables");
}

{
    local $ENV{HTTP_USER_AGENT} = "Nokia6630/1.0";
    local $ENV{HTTP_X_WAP_PROFILE} = "http://nds.nokia.com/uaprof/N6630r100.xml";
    my $bi = BrowserInfo->new;
    my($w,$h) = @{ $bi->{display_size} };
    is($w, 164, "Nokia6630 width");
    is($h, 144, "Nokia6630 height");
    ok($bi->{can_table}, "Nokia6630 can tables");
}

{
    local $ENV{HTTP_USER_AGENT} = "SharpTQ-GX1/1.0";
    local $ENV{HTTP_PROFILE} = "http://sharp-mobile.com/UAprof/GX1.xml";
    my $bi = BrowserInfo->new;
    my($w,$h) = @{ $bi->{display_size} };
    is($w, 120-6, "Sharp width");
    is($h, 160, "Sharp height");
    ok($bi->{can_table}, "Sharp can tables");
}

{
    local $ENV{HTTP_USER_AGENT} = "UnknownDevice/1.0";
    local $ENV{HTTP_PROFILE} = "http://does.not-exist.example.com/UAprof/foo.xml";
    my $bi = BrowserInfo->new;
    is("@{ $bi->{display_size} }", "750 590", "Fallback for unknown device");
}
__END__
