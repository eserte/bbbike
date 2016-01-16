# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2013,2015,2016 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Show weather data from OpenWeatherMap (experimental)
# Description (de): Wetterdaten vpn OpenWeatherMap anzeigen (experimentell)
package OpenWeatherMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
our $VERSION = '0.03';

use LWP::UserAgent ();
use JSON::XS qw(decode_json);
use POSIX qw(strftime);

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
	my $appid;
	my $appid_file = "$ENV{HOME}/.openweathermap_appid";
	if (open my $appid_fh, $appid_file) {
	    chomp($appid = <$appid_fh>);
	}
	my($minx,$miny,$maxx,$maxy) = main::get_visible_map_bbox_polar();
	my $cx = ($maxx-$minx)/2 + $minx;
	my $cy = ($maxy-$miny)/2 + $miny;
	my $url = "http://api.openweathermap.org/data/2.5/station/find?lat=$cy&lon=$cx&cnt=10";
	if (defined $appid) {
	    warn "INFO: using API key (appid): $appid\n";
	    $url .= "&APPID=$appid";
	} else {
	    warn "NOTE: no API key found, consider to apply for one and put it to $appid_file\n";
	}
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
	main::add_to_stack('owm-data', 'topmost');
	for my $entry (@$d) {
	    my $station = $entry->{station};
	    my $id = $station->{id};
	    if ($id) {
		$CURRENT_STATIONS{$id} = $entry;
	    }
	    my $last_data = $entry->{last};
	    my $text = '';
	    my $ago_secs = time - $last_data->{dt};
	    my $ago = ($ago_secs > 365*86400 ? '(more than one year ago)' :
		       $ago_secs > 31*86400  ? '(more than one month ago)' :
		       $ago_secs > 2*86400   ? '(' . int($ago_secs/86400) . ' days ago)' :
		       $ago_secs > 2*3600    ? '(' . int($ago_secs/3600) . ' hours ago)' :
		       $ago_secs > 2*60      ? '(' . int($ago_secs/60) . ' minutes ago)' : 'recent');
	    $text .= 'Date/time: ' . strftime("%Y-%m-%d %H:%M:%S", localtime($last_data->{dt})) . " $ago\n";
	    $text .= 'Name: ' . $station->{name} . "\n";
	    $text .= 'Temperature: ' . sprintf("%.1f", $last_data->{main}->{temp} - 273.15) . "°C\n";
	    $text .= 'Wind: ' . $last_data->{wind}->{speed} . 'm/s, ' . $last_data->{wind}->{deg} . "°\n";
	    my($x,$y) = main::transpose($Karte::Polar::obj->map2standard($station->{coord}->{lon}, $station->{coord}->{lat})); # XXX other coord systems?
	    #$main::c->createText($x,$y, -text => $text, -tags => ['owm-data', ($id ? "owm-data-$id" : ())]);
	    main::outline_text($main::c, $x, $y, -text => $text, -tags => ['owm-data', ($id ? "owm-data-$id" : ())]);
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

  -> now we have something better than before (initial stack order is topmost),
     but still not perfect

* full data view, e.g. with tooltip or by clicking and opening a small dialog

* show wind velocity + directions as a graphical element

* is the cloudiness available? This would also be part of the graphical element

* does it work with a native wgs-84 map?

* Msg-ize

* major reasons for being experimental.

  * I seldom use it

  * currently the available weather data is far from usable because too old
    (checked around Berlin, 2015-05-07)

=cut
