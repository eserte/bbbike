#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);
use Test::More 'no_plan';

use JSON::XS;

use BBBikeCGI::Config;

use BBBikeTest qw(eq_or_diff);

{
    my $config = BBBikeCGI::Config->load_config("$FindBin::RealBin/../cgi/bbbike-test.cgi.config", 'json');

    # following two are set dynamically in bbbike-test.cgi.config
    my $use_apache_session = delete $config->{use_apache_session};
    my $apache_session_module = delete $config->{apache_session_module};
    if ($use_apache_session) {
	like $apache_session_module, qr{^Apache::Session(|::Counted)$}, 'Apache::Session module used';
    }

    eq_or_diff $config,
	{
	 bbbike_html		    => '/bbbike/html',
	 bbbike_images		    => '/bbbike/images',
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
	 with_comments		    => JSON::XS::true,
	}, 'config in bbbike-test.cgi.config, for json';
}

{
    my $config_perl = BBBikeCGI::Config->load_config("$FindBin::RealBin/../cgi/bbbike-test.cgi.config", 'perl');
    is $config_perl->{bbbikedraw_pdf_module}, undef, 'undefined value';
    ok !$config_perl->{can_gif}, 'false value';
    ok $config_perl->{can_pdf}, 'true value';
    is $config_perl->{city}, 'Berlin_DE', 'string value';
}

for my $base ('bbbike.cgi.config', 'bbbike2.cgi.config') {
    my $file = "$FindBin::RealBin/../cgi/$base";
    if (-e $file) {
	my $config_perl = BBBikeCGI::Config->load_config($file, 'perl');
	isa_ok $config_perl, 'HASH';
	ok exists $config_perl->{city};
    }
}

__END__
