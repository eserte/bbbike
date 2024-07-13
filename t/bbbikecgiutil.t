#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use CGI;

plan tests => 11;

use BBBikeCGI::Util;

{
    my $q = CGI->new({movemap => "S�d"});
    BBBikeCGI::Util::decode_possible_utf8_params($q, "not_used", "not_used");
    is($q->param("movemap"), "S�d");
}

SKIP: {
    skip("Encode not available", 1)
	if !eval { require Encode; 1 };
    my $sued_utf8 = Encode::encode("utf-8", "S�d");
    my $q = CGI->new({movemap => $sued_utf8});
    BBBikeCGI::Util::decode_possible_utf8_params($q, "not_used", "not_used");
    my $success = is($q->param("movemap"), "S�d");
    if (!$success && $Encode::VERSION lt "2.08") {
	diag "Failure expected with this Encode version ($Encode::VERSION)";
    }
}

{
    is(BBBikeCGI::Util::my_escapeHTML("ABC<>&DEF"), "ABC&#60;&#62;&#38;DEF", "Escaping classic ones");
    is(BBBikeCGI::Util::my_escapeHTML("�"), "&#228;", "Escaping latin1");
    is(BBBikeCGI::Util::my_escapeHTML("�\x{20ac}"), "&#228;&#8364;", "Escaping unicode > 255");
}

{
    local $ENV{HTTP_HOST} = "bbbike.de";
    my $q = CGI->new;
    # Since CGI 4.66 a trailing slash is added to the ->url call.
    # It's unclear if the new behavior is problematic, so for now
    # just accept both variants, with and without trailing slash.
    # See also https://github.com/leejo/CGI.pm/issues/267
    like(BBBikeCGI::Util::my_url($q), qr{^\Qhttp://bbbike.de\E/?$}, 'only Host header, no Request-Uri');
}

{
    local $ENV{HTTP_HOST} = "bbbike.de";
    local $ENV{REQUEST_URI} = "/cgi-bin/bbbike.cgi";
    my $q = CGI->new;
    is(BBBikeCGI::Util::my_url($q), "http://bbbike.de/cgi-bin/bbbike.cgi", 'with Request-Uri');
}

{
    local $ENV{HTTP_HOST} = "bbbike.de:80";
    local $ENV{REQUEST_URI} = "/cgi-bin/bbbike.cgi";
    my $q = CGI->new;
    is(BBBikeCGI::Util::my_url($q), "http://bbbike.de/cgi-bin/bbbike.cgi", 'default port 80');
}

{
    local $ENV{HTTP_HOST} = "bbbike.de:80";
    local $ENV{REQUEST_URI} = "/cgi-bin/bbbike.cgi";
    local $ENV{HTTP_X_FORWARDED_PROTO} = "https";
    my $q = CGI->new;
    is(BBBikeCGI::Util::my_url($q), "https://bbbike.de/cgi-bin/bbbike.cgi", 'https proxy');
}

{
    local $ENV{HTTP_HOST} = "bbbike.de:80";
    local $ENV{REQUEST_URI} = "/cgi-bin/bbbike.cgi";
    local $ENV{HTTP_X_FORWARDED_PROTO} = "http"; # seen in CloudFlare https setups
    {
	local $ENV{HTTP_CF_VISITOR} = '{"scheme":"https"}'; # seen in CloudFlare https setups (f.e. sf)
	my $q = CGI->new;
	is(BBBikeCGI::Util::my_url($q), "https://bbbike.de/cgi-bin/bbbike.cgi", 'https on CloudFlare (cf-visitor)');
    }
    {
	local $ENV{HTTP_CF_VISITOR} = '{"something": "else", "scheme": "https", "another_thing": true}'; # in case cf-visitor header contains more data
	my $q = CGI->new;
	is(BBBikeCGI::Util::my_url($q), "https://bbbike.de/cgi-bin/bbbike.cgi", 'https on CloudFlare (cf-visitor with more data)');
    }

}

__END__
