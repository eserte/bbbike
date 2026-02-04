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

use Scalar::Util qw(looks_like_number);

use BBBikeTest qw(check_cgi_testing $cgidir eq_or_diff get_cgi_config);

check_cgi_testing;

plan 'no_plan';

my $cgiurl = "$cgidir/bbbike.cgi";
my $cgitesturl = "$cgidir/bbbike-test.cgi";

my $version_rx = qr{^v?\d+\.};

{
    my $data = do_config_api_call($cgiurl);
    is $data->{city}, 'Berlin_DE';
}

{
    do_config_api_call($cgiurl, 1); # just do http response check
}

{
    my $data = do_config_api_call($cgitesturl);

    # following two are set dynamically in bbbike-test.cgi.config
    my $use_apache_session = delete $data->{use_apache_session};
    if ($use_apache_session) {
	my $apache_session_module = delete $data->{apache_session_module};
	like $apache_session_module, qr{^Apache::Session(|::Counted)$};
    }

    # following two are semi-dynamically; host name depends on $cgidir
    my $bbbike_html = delete $data->{bbbike_html};
    my $bbbike_images = delete $data->{bbbike_images};
    (my $expected_bbbike_root = $cgitesturl) =~ s{/cgi(-bin)?/bbbike-test\.cgi$}{};
    # Yes, $expected_bbbike_root is "http://$HOSTNAME" on setups with
    # use_cgi_bin_layout, which yields to "http://$HOSTNAME/html",
    # which does not exist. But that's the state of bbbike-test.cgi on
    # such systems.
    is $bbbike_html, "$expected_bbbike_root/html";
    is $bbbike_images, "$expected_bbbike_root/images";

    # and modules_info is dynamically determined from system's
    # installed modules
    my $modules_info = delete $data->{modules_info};
    my @diag;
    for my $mod (keys %$modules_info) {
	my $module_info = $modules_info->{$mod};
	if ($module_info->{warning}) {
	    push @diag, "NOTE: warning returned while retrieving info for '$mod': $module_info->{warning}";
	} elsif ($module_info->{installed} eq JSON::XS::false) {
	    push @diag, "NOTE: Module '$mod' not installed";
	} else {
	    like $module_info->{version} , $version_rx, "Version for '$mod' looks like a version";
	}
    }
    diag $_ for @diag;

    eq_or_diff $data,
	{
	 bbbikedraw_pdf_module	    => undef,
	 can_gif		    => JSON::XS::false,
	 can_gpx		    => JSON::XS::false,
	 can_jpeg		    => JSON::XS::false,
	 can_kml		    => JSON::XS::false,
	 can_mapserver		    => JSON::XS::false,
	 can_palmdoc		    => JSON::XS::false,
	 can_pdf		    => JSON::XS::true,
	 can_qrcode_link    	    => JSON::XS::false,
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
	 use_heap                   => undef,
	 use_select		    => JSON::XS::true,
	 use_utf8		    => JSON::XS::true,
	 use_winter_optimization    => JSON::XS::false,
	 winter_hardness            => undef,
	 winter_no_RW1              => JSON::XS::false,
	 with_cat_display	    => JSON::XS::false,
	 with_comments		    => JSON::XS::true
	};
}

{
    my $resp = get_cgi_config cgiurl => $cgiurl, optmod => 1;
    my $optmod = 'Apache::Session'; # a random optional module
    my $optmod_info = $resp->{modules_info}{$optmod};
    ok $optmod_info, "info for optional module $optmod";
    my $installed = $optmod_info->{installed};
    ok $installed eq JSON::XS::true || $installed eq JSON::XS::false, 'installed is a boolean';
    if ($installed) {
	ok looks_like_number($optmod_info->{version}), "$optmod has a version which looks like a number"
	    or diag explain $optmod_info;
    }
}

{
    require BBBikeCGI::API;
    my $test_mod = 'JSON::XS';
    my $res_factory = BBBikeCGI::API::_module_info($test_mod);
    my $res_mm      = BBBikeCGI::API::_module_info_via_module_metadata($test_mod);
    my $res_eumm    = BBBikeCGI::API::_module_info_via_eumm($test_mod);
    is_deeply $res_mm,   $res_factory, 'same result for _module_info and direct Module::Metadata call';
    is_deeply $res_eumm, $res_factory, 'same result for _module_info and direct EUMM call';
    ok $res_factory->{installed};
    is $res_factory->{installed}, JSON::XS::true;
    like $res_factory->{version}, $version_rx, 'looks like a version';
}

sub do_config_api_call {
    my($cgiurl, $with_resp_check) = @_;
    my $resp;
    my $data = get_cgi_config cgiurl => $cgiurl, ($with_resp_check ? (resp => \$resp) : ());
    ok $data, 'config API call returned data';
    if ($with_resp_check) {
	is $resp->content_type, 'application/json', 'expected Content-Type';
    }
    $data;
}

__END__
