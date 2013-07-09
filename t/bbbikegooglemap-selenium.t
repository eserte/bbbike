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
my $with_jscover;
GetOptions(
           "doit" => \$doit,
           "debug" => \$debug,
           "baseurl=s" => \$baseurl,
	   "with-jscover" => \$with_jscover,
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

if ($with_jscover) {
    $sel->open_ok("http://localhost:8080/jscoverage.html");
    $sel->type_ok('location', "http://localhost:8080/index.html");
    $sel->click_ok('openInWindowButton');
    $sel->wait_for_pop_up_ok('jscoverage_window', 10*1000);
    $sel->select_window_ok('jscoverage_window');
} else {
    $sel->open_ok("$cgidir/$baseurl", undef, "fetched bbbike+googlemap");
}

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
    poll(sub { $sel->is_alert_present }, 'Async call to geocoding');
    $sel->alert_like(qr{Adresse nicht gefunden});

    my $valid_address;

    # valid address
    $valid_address = 'Wallstraße 14';
    $sel->type_ok($geocode_text_locator, $valid_address);
    $sel->click_ok($geocode_button_locator);

    # another valid address - this should trigger removeOverlay() in setwptAndMark()
    $valid_address = 'Neue Grünstraße';
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

{
    # Workaround the canvas/click issues by calling the javascript
    # functions for setting start/goal directly

    $sel->get_eval('window.onClick(null, new window.GLatLng(52.5,13.5))'); # XXX v2 vs. v3 gmap api?
    $sel->get_eval('window.onClick(null, new window.GLatLng(52.5,13.4))');

    my $hin_street_rx = qr{Markgrafendamm};
    poll(sub { $sel->get_text('id=wpt') =~ $hin_street_rx }, 'Async call to route search');
    $sel->text_like('id=wpt', $hin_street_rx);

    $sel->click_ok('xpath=//*[@id="wpt"]//*[.="Rückweg"]');

    my $rueck_street_rx = qr{angekommen.*Sewan};
    poll(sub { $sel->get_text('id=wpt') =~ $rueck_street_rx }, 'Async call to route search');
    $sel->text_like('id=wpt', $rueck_street_rx);

    $sel->click_ok('xpath=//*[@id="wpt"]//*[.="gleiche Suche in BBBike"]');
    $sel->wait_for_page_to_load_ok(10*1000);
    $sel->text_like('xpath=/html/body', qr{Route von .* bis.*Sewanstr});
    $sel->go_back_ok;
    $sel->wait_for_page_to_load_ok(10*1000);
    # Note: by leaving the bbbikegooglemap page and getting back
    # everything's resetted, the route is not visible anymore.
}

{
    $sel->click_ok("id=mapmode_search");
    $sel->get_eval('window.onClick(null, new window.GLatLng(52.471557,13.384699))'); # Hoeppnerstr.
    $sel->get_eval('window.onClick(null, new window.GLatLng(52.471176,13.422007))'); # Kirchhofweg

    my $street_rx = qr{Tempelhof};
    poll(sub { $sel->get_text('id=wpt') =~ $street_rx }, 'Async call to route search');
    $sel->text_like('id=wpt', $street_rx);

    # We have a marker now because of the permanent temp-blocking via
    # Flughafen Tempelhof.

    ## XXX Unfortunately the marker cannot be clicked on programmatically?
    #$sel->click_ok('xpath=//*[@id="gmimap0"]'); # unfortunately this does not work ...
    ##XXX another workaround: $sel->get_eval('window.currentTempBlockingMarkers[0].click()'); # ... hence this workaround
    #my $temp_blockings_text_rx = qr{das Befahren ist nur tagsüber möglich};
    #poll(sub { $sel->get_text('xpath=/html/body') =~ $temp_blockings_text_rx }, 'Wait for info window opening');
    #$sel->text_like('xpath=/html/body', $temp_blockings_text_rx);
    #$sel->click_ok('xpath=//img[contains(@src, "iw_close.gif")]');
}

{
    $sel->click_ok('id=mapmode_addroute');
    $sel->get_eval('window.onClick(null, new window.GLatLng(52.471557,13.384699))');
    $sel->get_eval('window.onClick(null, new window.GLatLng(52.471176,13.422007))');
    $sel->click_ok('xpath=//*[.="Route löschen"]');
    $sel->click_ok('xpath=//*[.="Route wiederherstellen"]');
    $sel->click_ok('xpath=//*[.="Letzten Punkt löschen"]');
    $sel->click_ok('xpath=//*[.="Kommentar zu Route und Waypoints senden"]');
    $sel->type_ok('name=comment', 'TEST IGNORE (created by bbbikegooglemap-selenium.t)');
    $sel->type_ok('name=author', 'TEST IGNORE');
    $sel->click_ok('xpath=//*[.="Senden"]');
    my $thanks_rx = qr{Danke, der folgende Kommentar};
    poll(sub { $sel->get_text('id=answer') =~ $thanks_rx }, 'Sending comment mail');
    $sel->text_like('id=answer', $thanks_rx);
}

sub poll {
    my($exit_cond, $diag) = @_;
    my $timeout = 10;
    my $pause_ms = 500;
    my $loop = $timeout/($pause_ms/1000);
    for (1..$loop) {
	last if $exit_cond->();
	$sel->pause($pause_ms);
	if ($diag && $_ == 1) {
	    diag "$diag, wait max. $timeout s...";
	}
    }
}
