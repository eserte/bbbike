#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

BEGIN {
    if (!eval q{
	use JSON::XS;
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no JSON::XS, LWP::UserAgent and/or Test::More module(s)\n";
	exit;
    }
}

use BBBikeTest qw(check_cgi_testing $cgidir eq_or_diff);

check_cgi_testing;

plan 'no_plan';

my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent('BBBike-Test/1.0');
$ua->env_proxy;

my $cgiurl = "$cgidir/bbbike.cgi";
my $cgitesturl = "$cgidir/bbbike-test.cgi";

{
    my $data = do_config_api_call($cgiurl);
    is $data->{city}, 'Berlin_DE';
}

{
    my $data = do_config_api_call($cgitesturl);

    # following two are set dynamically in bbbike-test.cgi.config
    my $use_apache_session = delete $data->{use_apache_session};
    if ($use_apache_session) {
	my $apache_session_module = delete $data->{apache_session_module};
	like $apache_session_module, qr{^Apache::Session(|::Counted)$};
    }

    eq_or_diff $data,
	{
	 bbbikedraw_pdf_module	    => undef,
	 can_gif		    => JSON::XS::false,
	 can_gpsies_link	    => JSON::XS::false,
	 can_gpx		    => JSON::XS::false,
	 can_jpeg		    => JSON::XS::false,
	 can_kml		    => JSON::XS::false,
	 can_mapserver		    => JSON::XS::false,
	 can_palmdoc		    => JSON::XS::false,
	 can_pdf		    => JSON::XS::true,
	 can_svg		    => JSON::XS::false,
	 can_wbmp		    => JSON::XS::false,
	 city			    => 'Berlin_DE',
	 data_is_wgs84		    => JSON::XS::false,
	 detailmap_module	    => undef,
	 graphic_format		    => 'png',
	 osm_data		    => JSON::XS::false,
	 search_algorithm	    => undef,
	 show_start_ziel_url	    => JSON::XS::true,
	 show_weather		    => JSON::XS::true,
	 use_background_image	    => JSON::XS::true,
	 use_berlinmap		    => JSON::XS::true,
	 use_coord_link		    => JSON::XS::true,
	 use_exact_streetchooser    => JSON::XS::true,
	 use_fragezeichen	    => JSON::XS::true,
	 use_fragezeichen_routelist => JSON::XS::true,
	 use_select		    => JSON::XS::true,
	 use_utf8		    => JSON::XS::false,
	 with_cat_display	    => JSON::XS::false,
	 with_comments		    => JSON::XS::true
	};
}

sub do_config_api_call {
    my $cgiurl = shift;
    my $url = $cgiurl . "?api=config";
    my $resp = $ua->get($url);
    ok($resp->is_success, "config API call")
	or diag $resp->as_string;
    my $data = decode_json $resp->decoded_content(charset => 'none');
    $data;
}


__END__
