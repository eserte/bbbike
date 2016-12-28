#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;

use Getopt::Long;
use URI ();
use URI::QueryParam ();
use Test::More;

use BBBikeTest qw($mapserverstaticurl selenium_diag);

my $doit;
my $debug;
my $root_url = "$mapserverstaticurl/brb/radroute.html";
# To test on bbbike-pps call with:
#
#    perl t/radrouten-selenium.t -doit -rooturl http://bbbike-pps/mapserver/brb/radroute.html
#
GetOptions(
           "doit" => \$doit,
           "debug" => \$debug,
	   "rooturl=s" => \$root_url,
          )
    or die "usage: $0 [-doit] [-debug] [-rooturl ...]";

if (!$doit) {
    plan skip_all => 'Tests are skipped without -doit switch';
    exit 0;
}

plan 'no_plan';

require Test::WWW::Selenium;
my $sel = eval {
    Test::WWW::Selenium->new(
			     host => "localhost",
			     port => 4444,
			     browser => "*firefox",
			     browser_url => "http://localhost",
			     default_names => 1,
			     #error_callback => sub { die "error_callback NYI / args=@_" },
			     auto_stop => !$debug,
			    );
};
if (!$sel || $@) {
    selenium_diag;
    fail $@;
    exit 1;
}

$sel->open_ok("$root_url", undef, "fetched radrouten page");

my $bu_xpath = '//*[contains(.,"Berlin - Usedom")]';
my $form_xpath = $bu_xpath . '/ancestor::form';
my $leaflet_button_xpath = $form_xpath . '//input[@type="submit" and contains(@value, "Leaflet")]';
my $mapserver_button_xpath = $form_xpath . '//input[@type="submit" and contains(@value, "Mapserver")]';
my $routelist_button_xpath = $form_xpath . '//input[@type="submit" and contains(@value, "Routenliste")]';

$sel->is_element_present_ok('xpath=' . $bu_xpath, 'found Berlin - Usedom route');
$sel->is_element_present_ok('xpath=' . $form_xpath, 'found associated form');

# leaflet
$sel->is_element_present_ok('xpath=' . $leaflet_button_xpath, 'found leaflet button');
$sel->click_ok('xpath=' . $leaflet_button_xpath);
$sel->wait_for_page_to_load_ok(10*1000);
{
    my $loc = $sel->get_location;
    like $loc, qr{/bbbikeleaflet\.cgi}, 'on leaflet map';
}
my $center = $sel->get_eval('window.map.getCenter()');
like $center, qr{^LatLng\(53\.\d+, 13\.\d+\)$}, 'center looks reasonable';
## XXX works only with Leaflet >= 0.5
#my $layer_count = $sel->get_eval('var layer_count = 0; window.map.eachLayer(function () { layer_count++ }); layer_count');
#is $layer_count, 1;
is $sel->get_eval('window.routeLayer'), '[object Object]', 'routeLayer set';

$sel->go_back;

# mapserver
$sel->is_element_present_ok('xpath=' . $mapserver_button_xpath, 'found mapserver button');
$sel->click_ok('xpath=' . $mapserver_button_xpath);
$sel->wait_for_page_to_load_ok(10*1000);
{
    my $loc = $sel->get_location;
    like $loc, qr{/mapserv.*layer=route}, 'on mapserver map, with route layer';
}
$sel->is_checked('xpath=//input[@type="checkbox" and @name="layer" and @value="route"]', 'route layer is checked');

$sel->go_back;

# bbbike
$sel->is_element_present_ok('xpath=' . $routelist_button_xpath, 'found routelist button');
$sel->click_ok('xpath=' . $routelist_button_xpath);
$sel->wait_for_page_to_load_ok(10*1000);
{
    my $loc = $sel->get_location;
    like $loc, qr{/bbbike\.cgi}, 'on bbbike';
}
$sel->is_text_present_ok('Berlin - Usedom');
$sel->is_text_present_ok('Schönhauser Allee');
$sel->is_text_present_ok('Bernau');
$sel->is_text_present_ok('Joachimsthal');
$sel->is_text_present_ok('Prenzlau');
$sel->is_text_present_ok('Ahlbeck');
