#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;

use Getopt::Long;
use Test::More;

use BBBikeTest qw($cgidir);

my $doit;
my $debug;
my $baseurl = 'bbbikegooglemap.cgi';
GetOptions(
           "doit" => \$doit,
           "debug" => \$debug,
           "baseurl=s" => \$baseurl,
          )
    or die "usage: $0 [-doit] [-debug] [-baseurl ...]";

if (!$doit) {
    plan skip_all => 'Tests are skipped without -doit switch';
    exit 0;
}

plan 'no_plan';

# Remember to start the Selenium server first, e.g.
# java -jar /usr/ports/distfiles/selenium-server-standalone-2.33.0.jar

require Test::WWW::Selenium;
my $sel = Test::WWW::Selenium->new(
                                   host => "localhost",
                                   port => 4444,
                                   browser => "*firefox",
                                   browser_url => "$cgidir/",
                                   default_names => 1,
                                   #error_callback => sub { die "error_callback NYI / args=@_" },
                                   auto_stop => !$debug,
                                  );

$sel->open_ok("$cgidir/$baseurl", undef, "fetched bbbike+googlemap");

{
    ## Geocoding checks
    my $geocode_text_locator = 'xpath=//*[@name="geocodeAddress"]';
    my $geocode_button_locator = "$geocode_text_locator/../..//button";

    # empty address
    $sel->click_ok($geocode_button_locator);
    $sel->is_alert_present_ok();
    $sel->alert_like(qr{Bitte Adresse angeben});

    # invalid address
    my $invalid_address = 'ThIsAddressDoesNotExistReallyNotNeeneenee...';
    $sel->type_ok($geocode_text_locator, $invalid_address);
    $sel->click_ok($geocode_button_locator);
    for (1..20) {
        last if $sel->is_alert_present;
        $sel->pause(500);
        diag "Async call to geocoding, wait max. 10s..." if $_ == 1;
    }
    $sel->alert_like(qr{Adresse nicht gefunden});

    # valid address
    my $valid_address = 'Wallstraße 14';
    $sel->type_ok($geocode_text_locator, $valid_address);
    $sel->click_ok($geocode_button_locator);
}

# Click on the three extra map buttons
$sel->click_ok('xpath=//*[.="Mapnik"]');
$sel->click_ok('xpath=//*[.="Mapnik"]/../following-sibling::div[1]/div');
$sel->click_ok('xpath=//*[.="Mapnik"]/../following-sibling::div[2]/div');

# Click on the three mapmodes, leaving the search mode active
$sel->click_ok("id=mapmode_browse");
$sel->click_ok("id=mapmode_addroute");
$sel->click_ok("id=mapmode_search");

## Does not work?
## Because of the inability of Selenium 1 to deal with Canvas?
## See http://www.theautomatedtester.co.uk/blog/2011/selenium-advanced-user-interactions.html
#my $mapw = $sel->get_element_width('id=map');
#my $maph = $sel->get_element_height('id=map');
#my $center = join(",", map { int $_/2 } $mapw, $maph);
#$sel->click_at_ok('id=map', $center);
##$sel->mouse_down_at_ok('id=map', $center);
##$sel->mouse_up_at_ok('id=map', $center);
#my $somewhere = join(",", map { int($_/2)+50 } $mapw, $maph);
#$sel->click_at_ok('id=map', $somewhere);
##$sel->mouse_down_at_ok('id=map', $somewhere);
##$sel->mouse_up_at_ok('id=map', $somewhere);
#sleep 60;
