#!/usr/bin/perl -w
# -*- mode: perl; coding: iso-8859-1; -*-

#
# Author: Slaven Rezic
#

# Test storing preferences into cookie.

use strict;
no utf8;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin",
	);
use BBBikeTest qw(set_user_agent $cgidir using_bbbike_test_cgi check_cgi_testing);

BEGIN {
    if (!eval q{
	use CGI '-oldstyle_urls';
	use File::Spec;
	use File::Temp;
	use HTTP::Cookies;
	use LWP::UserAgent;
	use Test::More;
	use WWW::Mechanize;
	1;
    }) {
	print "1..0 # skip no File::Temp, Test::More, LWP::UserAgent, and/or WWW::Mechanize modules\n";
	exit;
    }
}

check_cgi_testing;
using_bbbike_test_cgi;

plan tests => 10;

my $cookie_jar_file = File::Temp::tempnam(File::Spec->tmpdir, "bbbike_cookies_");
END { unlink $cookie_jar_file if defined $cookie_jar_file }

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->env_proxy;
set_user_agent($ua);
my $cookie_jar = HTTP::Cookies->new(file => $cookie_jar_file,
				    autosave => 1);
$cookie_jar->clear;
$ua->cookie_jar($cookie_jar);

my $bbbike_cgi = "$cgidir/bbbike-test.cgi";

my %pref = (speed	 => 20,
	    cat		 => "N1",
	    quality	 => "Q2",
	    ampel	 => "yes",
	    green	 => "GR1",
	    fragezeichen => "yes",
	   );

my %common_args = (startc    => '9229,8785',
		   startname => 'Dudenstr.',
		   zielname  => 'Metfesselstr.',
		   zielplz   => '10965',
		   zielc     => '8982,8781',
		   scope     => 'city',
		  );

{
    my $qs = CGI->new({ %common_args,
			(map {("pref_$_" => $pref{$_})} keys %pref),
			'pref_seen'=>1,
		      })->query_string;
    my $res = $ua->get("$bbbike_cgi?$qs");
    ok($res->is_success);

    my $found_cookies = 0;
    $cookie_jar->scan
	(sub {
	     my($version,$key,$val,$path,$domain,$port,$path_spec,$secure,$expires,$discard,$hash) = @_;
	     if ($key eq 'bbbike-dir') {
		 $found_cookies++;
	     } elsif ($key eq 'bbbike') {
		 $found_cookies++;
	     }
	 });
    is($found_cookies, 2, "Expect two cookies from bbbike.cgi calls");
}

{
    my $qs = CGI->new({ %common_args })->query_string;
    my $mech = WWW::Mechanize->new;
    set_user_agent($mech);
    $mech->cookie_jar($cookie_jar);
    my $res = $mech->get("$bbbike_cgi?$qs");
    ok($res->is_success);
    for my $q (qw(speed cat quality ampel green fragezeichen ferry)) {
	is($mech->current_form->value("pref_$q"), $pref{$q}, "Expected preference $q");
    }
}

__END__
