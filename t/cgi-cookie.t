#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-cookie.t,v 1.3 2009/02/01 13:19:39 eserte Exp $
# Author: Slaven Rezic
#

# Test storing preferences into cookie.

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin",
	);
use BBBikeTest qw(set_user_agent $cgiurl $cgidir);

BEGIN {
    if (!eval q{
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

BEGIN { plan tests => 10 }

my $cookie_jar_file = File::Temp::tempnam(File::Spec->tmpdir, "bbbike_cookies_");
END { unlink $cookie_jar_file if defined $cookie_jar_file }

my $ua = LWP::UserAgent->new;
set_user_agent($ua);
my $cookie_jar = HTTP::Cookies->new(file => $cookie_jar_file,
				    autosave => 1);
$cookie_jar->clear;
$ua->cookie_jar($cookie_jar);

my $bbbike_cgi = "$cgiurl/bbbike.cgi";

my $pref = {speed => 20,
	    cat => "N1",
	    quality => "Q2",
	    ampel => "yes",
	    green => "GR1",
	    fragezeichen => "yes",
	   };

{
    my $qs = 'startc=26615%2C14054&startname=Dahlwitzer+Str.%2FLemkestr.%2FHoppegartener+Str.+%28H%F6now%29&zielname=Hannoversche+Str.&zielplz=10115&zielc=9203%2C13463&scope=region&';
    $qs .= "pref_seen=1&pref_speed=$pref->{speed}&pref_cat=$pref->{cat}&pref_quality=$pref->{quality}&pref_ampel=$pref->{ampel}&pref_green=$pref->{green}&pref_fragezeichen=$pref->{fragezeichen}";
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
    my $qs = 'startc=26615%2C14054&startname=Dahlwitzer+Str.%2FLemkestr.%2FHoppegartener+Str.+%28H%F6now%29&via=&viahnr=&viacharimg.x=&viacharimg.y=&viamapimg.x=&viamapimg.y=&zielname=Hannoversche+Str.&zielplz=10115&zielhnr=&scope=region';
    my $mech = WWW::Mechanize->new;
    set_user_agent($mech);
    $mech->cookie_jar($cookie_jar);
    my $res = $mech->get("$bbbike_cgi?$qs");
    ok($res->is_success);
    for my $q (qw(speed cat quality ampel green fragezeichen ferry)) {
	is($mech->current_form->value("pref_$q"), $pref->{$q}, "Expected preference $q");
    }
}

__END__
