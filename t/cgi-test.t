#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no LWP::UserAgent and/or Test::More modules\n";
	exit;
    }
}

use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();
use Getopt::Long;

use BBBikeTest qw(get_std_opts like_long_data $cgidir);

sub bbbike_cgi_search ($$);

plan 'no_plan';

if (!GetOptions(get_std_opts("cgidir"),
	       )) {
    die "usage!";
}

{
    my $make = $^O =~ m{bsd}i ? "make" : "pmake";
    system("cd $FindBin::RealBin/data && $make");
}

my $testcgi = "$cgidir/bbbike-test.cgi";
my $ua = LWP::UserAgent->new;
$ua->agent("BBBike-Test/1.0");

{
    my $resp = bbbike_cgi_search +{startname=>'Dudenstr.',
				   startc=>'9229,8785',
				   zielname=>'Methfesselstr.',
				   zielc=>'8982,8781',
				  }, 'Search route with bbbike coords';
    my $content = $resp->decoded_content;
    like_long_data($content, qr{Route von.*Dudenstr.*Methfesselstr});
    like_long_data($content, qr{L.*nge.*0\.25\s+km});
}

{
    my $resp = bbbike_cgi_search +{startname=>'Dudenstr.',
				   startc_wgs84=>'13.385915,52.484976',
				   zielname=>'Methfesselstr.',
				   zielc_wgs84=>'13.382252,52.484989',
				  },'Search route with WGS84 coords';
    my $content = $resp->decoded_content;
    like_long_data($content, qr{Route von.*Dudenstr.*Methfesselstr});
    like_long_data($content, qr{L.*nge.*0\.25\s+km});
}

{
    my $resp = bbbike_cgi_search +{startc=>'10094,6428',
				   zielc=>'10176,6050',
				  },'BNP (Poller) in midst of route';
    my $content = $resp->decoded_content;
    like_long_data($content, qr{\(kein Zeitverlust\)});
}

sub bbbike_cgi_search ($$) {
    my($params, $testname) = @_;
    $params->{pref_seen} = 1;
    $params->{pref_speed} = 20 if !exists $params->{pref_speed};
    my $url = $testcgi . '?' . CGI->new($params)->query_string;
    my $resp = $ua->get($url);
    ok($resp->is_success, $testname);
    $resp;
}

__END__
