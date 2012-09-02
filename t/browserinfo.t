#!/usr/bin/perl -w
# -*- perl -*-

#
# Copyright (C) 2005,2012 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
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

BEGIN { plan tests => 20 }

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

{
    local $ENV{HTTP_USER_AGENT} = undef;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my $bi = BrowserInfo->new;
    is "@warnings", "", 'No warnings for empty user agent';
}

{
    local $ENV{HTTP_USER_AGENT} = "Mozilla/5.0 (iPad; CPU OS 5_1_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B206 Safari/7534.48.3";
    my $bi = BrowserInfo->new;
    is $bi->{user_agent_name}, 'Safari';
    is $bi->{user_agent_os}, 'iOS';
    # is $bi->{mobile_device}, 1 oder 0? # Was mache ich zur Zeit mit dem Wert? -> es wird z.B. auf m.bbbike.de geschaltet
    ok $bi->{can_table};
    ok $bi->{can_dhtml};
    ok $bi->{can_css};
    ok $bi->{can_javascript};
    ok !$bi->{text_browser};
    ok !$bi->{gecko_version}, "It's not a gecko, it's just like gecko";
    ok $bi->is_browser_version('Safari', 7000, 8000);
}

__END__
