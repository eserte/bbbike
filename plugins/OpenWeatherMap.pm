# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Show weather data from OpenWeatherMap
# Description (de): Wetterdaten vpn OpenWeatherMap anzeigen
package OpenWeatherMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
our $VERSION = '0.02';

use LWP::UserAgent ();
use JSON::XS qw(decode_json);

our %CURRENT_STATIONS;

sub register {
    my $pkg = __PACKAGE__;
    $BBBikePlugin::plugins{$pkg} = $pkg;
    add_button($pkg);
}

sub unregister {
    my $pkg = __PACKAGE__;
    return unless $BBBikePlugin::plugins{$pkg};
    BBBikePlugin::remove_from_global_plugins_menu($pkg."_menu");
    delete_owm_layer();
    delete $BBBikePlugin::plugins{$pkg};
}

sub add_button {
    my($pkg) = @_;
    BBBikePlugin::add_to_global_plugins_menu
	    (-menuitems => [
			    [Button => "OpenWeatherMap-Daten anzeigen",
			     -command => sub { refresh_owm_layer() },
			    ],
			    [Button => "XXX Raise", # XXX shouldn't be necessary if this was a proper BBBike layer
			     -command => sub { $main::c->raise('owm-data') },
			    ],
			    [Button => "OpenWeatherMap-Daten löschen",
			     -command => sub { delete_owm_layer() },
			    ],
			    [Button => 'Dieses Menü löschen',
			     -command => sub {
				 $main::top->after(100, sub {
						       unregister();
						   });
			     }
			    ]],
	     -title => 'OpenWeatherMap',
	     -advertisedname => $pkg."_menu",
	    );
}

sub refresh_owm_layer {
    eval {
	my($minx,$miny,$maxx,$maxy) = main::get_visible_map_bbox_polar();
	my $cx = ($maxx-$minx)/2 + $minx;
	my $cy = ($maxy-$miny)/2 + $miny;
	my $url = "http://api.openweathermap.org/data/2.5/station/find?lat=$cy&lon=$cx=cnt=10";
	my $ua = main::get_user_agent();
	my $resp = $ua->get($url);
	if (!$resp->is_success) {
	    die "Fetching $url failed with " . $resp->as_string;
	}
	my $d = decode_json($resp->decoded_content(charset => "none"));
	if (!@$d) {
	    die "Empty list was returned, probably no weather stations here";
	}
	delete_owm_layer();
	for my $entry (@$d) {
	    my $station = $entry->{station};
	    my $id = $station->{id};
	    if ($id) {
		$CURRENT_STATIONS{$id} = $entry;
	    }
	    my $last_data = $entry->{last};
	    my $text = '';
	    $text .= 'Date/time: ' . scalar(localtime $last_data->{dt}) . "\n";
	    $text .= 'Name: ' . $station->{name} . "\n";
	    $text .= 'Temperature: ' . sprintf("%.1f", $last_data->{main}->{temp} - 273.15) . "°C\n";
	    $text .= 'Wind: ' . $last_data->{wind}->{speed} . 'm/s, ' . $last_data->{wind}->{deg} . "°\n";
	    my($x,$y) = main::transpose($Karte::Polar::obj->map2standard($station->{coord}->{lon}, $station->{coord}->{lat})); # XXX other coord systems?
	    $main::c->createText($x,$y, -text => $text, -tags => ['owm-data', ($id ? "owm-data-$id" : ())]);
	}
    };
    if ($@) {
	main::status_message("Fehler: $@", "error");
    }
}

sub delete_owm_layer {
    %CURRENT_STATIONS = ();
    $main::c->delete('owm-data');
}

1;

__END__

=head1 TODO

* use "proper" BBBike layers (so raise-ing/lower-ing works fine)

* full data view, e.g. with tooltip or by clicking and opening a small dialog

* show wind velocity + directions as a graphical element

* is the cloudiness available? This would also be part of the graphical element

* does it work with a native wgs-84 map?

* Msg-ize

=cut
