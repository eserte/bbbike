# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2007,2010,2011,2012,2014,2016,2017,2018,2019,2020,2021,2022,2023,2024,2025 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Link to OpenStreetMap, WikiMapia, Bing and other maps
# Description (de): Links zu OpenStreetMap, WikiMapia, Bing und anderen Karten
package MultiMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = 2.33;

use BBBikeUtil qw(bbbike_aux_dir module_exists deg2rad);

use vars qw(%images);

my $map_compare_use_bbbike_org = 1;
my $newest_berlin_aerial_year = '2024'; # used in MapCompare and Rapid
my $newest_berlin_aerial = 'berlin-historical-'.$newest_berlin_aerial_year;

$main::devel_host = $main::devel_host if 0; # cease -w

sub register {
    _create_images();
    my $lang = $Msg::lang || 'de';
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    # this order will be reflected in show_info
    if (0 && $is_berlin) {
	# XXX It seems that pharus abandoned all digital maps
	$main::info_plugins{__PACKAGE__ . "_DeinPlan_Web"} =
	    { name => "Pharus (dein-plan, Web)",
	      callback => sub { showmap_deinplan_web(@_) },
	      callback_3_std => sub { showmap_url_deinplan_web(@_) },
	      ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	    };
	$main::info_plugins{__PACKAGE__ . "_DeinPlan_Leaflet"} =
	    { name => "Pharus (dein-plan, Leaflet, 2016)",
	      callback => sub { showmap_deinplan_leaflet(@_) },
	      callback_3_std => sub { showmap_url_deinplan_leaflet(@_) },
	      ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	    };
    }
    $main::info_plugins{__PACKAGE__ . "_WikiMapia"} =
	{ name => "WikiMapia",
	  callback => sub { showmap_wikimapia(@_) },
	  callback_3_std => sub { showmap_url_wikimapia(@_) },
	  ($images{WikiMapia} ? (icon => $images{WikiMapia}) : ()),
	  order => 8000,
	};
    if ($is_berlin) {
	$main::info_plugins{__PACKAGE__ . '_HistoricMapsBerlin'} =
	    { name => 'Historic maps Berlin',
	      callback => sub { showmap_historic_maps_berlin(@_) },
	      callback_3_std => sub {showmap_url_historic_maps_berlin(@_) },
	      ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
	      order => 8950,
	    };
    }
    $main::info_plugins{__PACKAGE__ . '_OpenStreetMap'} =
	{ name => sub {
	      my %args = @_;
	      my $current_tag_filter = $args{current_tag_filter}||'';
	      if ($current_tag_filter eq 'pubtrans') {
		  'OpenRailwayMap';
	      } elsif ($current_tag_filter eq 'bicycle') {
		  'CyclOSM @ OSM';
	      } else {
		  'OpenStreetMap',
	      }
	  },
	  callback => sub {
	      my %args = @_;
	      my $current_tag_filter = $args{current_tag_filter}||'';
	      if ($current_tag_filter eq 'pubtrans') {
		  showmap_openrailwaymap(@_);
	      } elsif ($current_tag_filter eq 'bicycle') {
		  showmap_cyclosm_at_osm(@_);
	      } else {
		  showmap_openstreetmap(osmmarker => 0, @_);
	      }
	  },
	  callback_3 => sub { show_openstreetmap_menu(@_) },
	  allmaps_cb => sub {
	      (
	       "OpenStreetMap"    => showmap_url_openstreetmap(osmmarker => 0, @_),
	       "OpenStreetMap DE" => showmap_url_openstreetmap(variant => 'de', @_),
	       "OpenRailwayMap"   => showmap_url_openrailwaymap(@_),
	      )
	  },
	  ($images{OpenStreetMap} ? (icon => $images{OpenStreetMap}) : ()),
	  order => 'first',
	  tags => [qw(pubtrans bicycle osm)],
	};
    $main::info_plugins{__PACKAGE__ . "_MapCompare"} =
	{ name => "Map Compare (Google/OSM)",
	  callback => sub { showmap_mapcompare(@_) },
	  callback_3_std => sub { showmap_url_mapcompare(@_) },
	  ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
	};
    if ($map_compare_use_bbbike_org) {
	$main::info_plugins{__PACKAGE__ . "_MapCompare_Distinct_Map_Data"} =
	    { name => "Map Compare (distinct map data)",
	      callback => sub { showmap_mapcompare(@_, profile => "__distinct_map_data") },
	      callback_3_std => sub { showmap_url_mapcompare(@_, profile => "__distinct_map_data") },
	      ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
	    };
	$main::info_plugins{__PACKAGE__ . "_MapCompare_BBBike"} =
	    { name => "Map Compare (profile BBBike)",
	      callback => sub { showmap_mapcompare(@_, profile => "bbbike") },
	      callback_3_std => sub { showmap_url_mapcompare(@_, profile => "bbbike") },
	      ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
	    };
	if ($is_berlin) {
	    $main::info_plugins{__PACKAGE__ . "_MapCompare_Berlin_Satellite"} =
		{ name => "Map Compare (profile Berlin satellite)",
		  callback => sub { showmap_mapcompare(@_, profile => "berlin-satellite") },
		  callback_3 => sub { show_mapcompare_menu(@_) },
		  ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
		  tags => [qw(aerial)],
		};
	} else {
	    $main::info_plugins{__PACKAGE__ . "_MapCompare_Satellite"} =
		{ name => "Map Compare (profile satellite)",
		  callback => sub { showmap_mapcompare(@_, profile => "satellite") },
		  callback_3 => sub { show_mapcompare_menu(@_) },
		  ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
		  tags => [qw(aerial)],
		};
	}
	$main::info_plugins{__PACKAGE__ . "_MapCompare_Traffic"} =
	    { name => "Map Compare (profile traffic)",
	      callback => sub { showmap_mapcompare(@_, profile => "traffic") },
	      callback_3_std => sub { showmap_url_mapcompare(@_, profile => "traffic") },
	      ($images{_MapCompare} ? (icon => $images{_MapCompare}) : ()),
	      tags => [qw(traffic)],
	    };
    }
    if ($is_berlin) {
     	$main::info_plugins{__PACKAGE__ . "_BvgStadtplan"} =
     	    { name => "BVG-Stadtplan",
     	      callback => sub { showmap_bvgstadtplan(@_) },
     	      callback_3 => sub { show_bvgstadtplan_menu(@_) },
     	      ($images{BvgStadtplan} ? (icon => $images{BvgStadtplan}) : ()),
	      tags => [qw(pubtrans)],
     	    };
	$main::info_plugins{__PACKAGE__ . "_SBahnBerlin"} =
	    { name => "S-Bahn Berlin (Stadtplan)",
     	      callback => sub { showmap_sbahnberlin(@_) },
     	      callback_3_std => sub { showmap_url_sbahnberlin(@_) },
     	      ($main::sbahn_photo ? (icon => $main::sbahn_photo) : ()),
	      tags => [qw(pubtrans)],
     	    };
    }
    $main::info_plugins{__PACKAGE__ . "_BikeMapNet"} =
	{ name => "bikemap.net",
	  callback => sub { showmap_bikemapnet(@_) },
	  callback_3_std => sub { showmap_url_bikemapnet(@_) },
	  ($images{BikeMapNet} ? (icon => $images{BikeMapNet}) : ()),
	  tags => [qw(bicycle)],
	};
    $main::info_plugins{__PACKAGE__ . "_CriticalMaps"} =
	{ name => "Critical Maps",
	  callback => sub { showmap_criticalmaps(@_) },
	  callback_3_std => sub { showmap_url_criticalmaps(@_) },
	  ($images{CriticalMaps} ? (icon => $images{CriticalMaps}) : ()),
	  order => 8700,
	  tags => [qw(bicycle)],
	};
    $main::info_plugins{__PACKAGE__ . "_Geocaching"} =
	{ name => "geocaching.com",
	  callback => sub { showmap_geocaching(@_) },
	  callback_3_std => sub { showmap_url_geocaching(@_) },
	  ($images{Geocaching} ? (icon => $images{Geocaching}) : ()),
	  order => 8800,
	};
    $main::info_plugins{__PACKAGE__ . "_Bing"} =
	{ name => "bing",
	  callback => sub { showmap_bing_street(@_) },
	  callback_3 => sub { show_bing_menu(@_) },
	  ($images{Bing} ? (icon => $images{Bing}) : ()),
	  tags => [qw(traffic)],
	};
    $main::info_plugins{__PACKAGE__ . "_TomTom"} =
	{ name => "tomtom",
	  callback => sub { showmap_tomtom(@_) },
	  callback_3_std => sub { showmap_url_tomtom(@_) },
	  ($images{TomTom} ? (icon => $images{TomTom}) : ()),
	  tags => [qw(traffic)],
	};
    $main::info_plugins{__PACKAGE__ . "_Waze"} =
	{ name => "Waze",
	  callback => sub { showmap_waze(@_) },
	  callback_3_std => sub { showmap_url_waze(@_) },
	  ($images{Waze} ? (icon => $images{Waze}) : ()),
	  tags => [qw(traffic)],
	};
    if ($is_berlin) {
	$main::info_plugins{__PACKAGE__ . "_FIS_Broker"} =
	    { name => sub {
		  my %args = @_;
		  my $current_tag_filter = $args{current_tag_filter}||'';
		  if ($current_tag_filter eq 'bicycle') {
		      'FIS-Broker (Radverkehrsnetz)';
		  } else {
		      "FIS-Broker (1:5000)";
		  }
	      },
	      callback => sub {
		  my %args = @_;
		  my $current_tag_filter = $args{current_tag_filter}||'';
		  if ($current_tag_filter eq 'bicycle') {
		      showmap_fis_broker(mapId => 'k_radverkehrsnetz@senstadt', @_);
		  } else {
		      showmap_fis_broker(@_);
		  }
	      },
	      callback_3 => sub { show_fis_broker_menu(@_) },
	      ($images{FIS_Broker} ? (icon => $images{FIS_Broker}) : ()),
	      tags => [qw(bicycle)],
	    };
	$main::info_plugins{__PACKAGE__ . '_GeoPortalBerlin'} =
	    { name => sub {
		  my %args = @_;
		  my $current_tag_filter = $args{current_tag_filter}||'';
		  if ($current_tag_filter eq 'bicycle') {
		      'Geoportal Berlin (Radverkehrsanlagen)';
		  } elsif ($current_tag_filter eq 'pubtrans') {
		      'Geoportal Berlin (Bus und Tram)';
		  } else {
		      'Geoportal Berlin (1:5000)';
		  }
	      },
	      callback => sub {
		  my %args = @_;
		  my $current_tag_filter = $args{current_tag_filter}||'';
		  if ($current_tag_filter eq 'bicycle') {
		      showmap_gdi_berlin(layers => 'radverkehrsanlagen', @_);
		  } elsif ($current_tag_filter eq 'pubtrans') {
		      showmap_gdi_berlin(layers => 'oepnv', @_);
		  } else {
		      showmap_gdi_berlin(layers => 'k5_farbe', @_);
		  }
	      },
	      callback_3 => sub { show_gdi_berlin_menu(@_) },
	      ($images{Berlin} ? (icon => $images{Berlin}) : ()),
	      tags => [qw(bicycle pubtrans)],
	    };
	$main::info_plugins{__PACKAGE__ . '_VIZ'} =
	    { name => 'VIZ Berlin',
	      callback => sub { showmap_viz(@_) },
	      callback_3_std => sub { showmap_url_viz(@_) },
	      ($images{VIZ} ? (icon => $images{VIZ}) : ()),
	      tags => [qw(traffic)],
	    };
	$main::info_plugins{__PACKAGE__ . "_LGB"} =
	    { name => "LGB Brandenburg Topo DTK10 (via mc)",
	      callback => sub { showmap_mapcompare(@_, maps => 'lgb-topo-10') },
	      callback_3_std => sub { showmap_url_mapcompare(@_, maps => 'lgb-topo-10') },
	      ($images{BRB} ? (icon => $images{BRB}) : ()),
	    };
	$main::info_plugins{__PACKAGE__ . "_LSB"} =
	    { name => "LS Brandenburg Verkehrsstärke 2021",
	      callback => sub { showmap_bbviewer(@_, layers => 'verkehrsstaerke-2021') },
	      callback_3 => sub { show_bbviewer_menu(@_) },
	      ($images{BRB} ? (icon => $images{BRB}) : ()),
	      tags => [qw(traffic)],
	    };
	$main::info_plugins{__PACKAGE__ . "_RadverkehrsatlasBRB"} =
	    { name => "Radverkehrsatlas Brandenburg",
	      callback => sub { showmap_radverkehrsatlas(@_) },
	      callback_3_std => sub { showmap_url_radverkehrsatlas(@_) },
	      ($images{BRB} ? (icon => $images{BRB}) : ()),
	      tags => [qw(bicycle)],
	    };
    }
    $main::info_plugins{__PACKAGE__ . "_BKG"} =
	{ name => "BKG (TopPlusOpen)",
	  callback => sub { showmap_bkg(@_) },
	  callback_3_std => sub { showmap_url_bkg(@_) },
	  ($images{BKG} ? (icon => $images{BKG}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . '_Mapillary'} =
	{ name => 'Mapillary',
	  callback => sub { showmap_mapillary(@_) },
	  callback_3 => sub { show_mapillary_menu(@_) },
	  allmaps_cb => sub { showmap_url_mapillary(@_) },
	  ($images{Mapillary} ? (icon => $images{Mapillary}) : ()),
	  tags => [qw(streetview)],
	};
    $main::info_plugins{__PACKAGE__ . '_KartaView'} =
	{ name => 'KartaView',
	  callback => sub { showmap_kartaview(@_) },
	  callback_3_std => sub { showmap_url_kartaview(@_) },
	  ($images{KartaView} ? (icon => $images{KartaView}) : ()),
	  tags => [qw(streetview)],
	};
    $main::info_plugins{__PACKAGE__ . '_Mapilio'} =
	{ name => 'Mapilio',
	  callback => sub { showmap_mapilio(@_) },
	  callback_3_std => sub { showmap_url_mapilio(@_) },
	  ($images{Mapilio} ? (icon => $images{Mapilio}) : ()),
	  tags => [qw(streetview)],
        };
    $main::info_plugins{__PACKAGE__ . '_BerlinerLinien'} =
	{ name => 'berliner-linien.de (VBB)',
	  callback => sub { showmap_berlinerlinien(@_) },
	  callback_3_std => sub { showmap_url_berlinerlinien(@_) },
	  ($images{BerlinerLinien} ? (icon => $images{BerlinerLinien}) : ()),
	  tags => [qw(pubtrans)],
	};
    $main::info_plugins{__PACKAGE__ . '_F4map'} =
	{ name => 'F4map',
	  callback => sub { showmap_f4map(@_) },
	  callback_3_std => sub { showmap_url_f4map(@_) },
	  ($images{F4map} ? (icon => $images{F4map}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . '_SentinelHub'} =
	{ name => 'Sentinel Hub',
	  callback => sub { showmap_sentinelhub(@_) },
	  callback_3_std => sub { showmap_url_sentinelhub(@_) },
	  ($images{SentinelHub} ? (icon => $images{SentinelHub}) : ()),
	  tags => [qw(aerial)],
	};
    $main::info_plugins{__PACKAGE__ . '_travic'} =
	{ name => 'travic',
	  callback => sub { showmap_travic(@_) },
	  callback_3_std => sub { showmap_url_travic(@_) },
	  ($images{Travic} ? (icon => $images{Travic}) : ()),
	  tags => [qw(pubtrans)],
	};
    if ($is_berlin) {
	$main::info_plugins{__PACKAGE__ . '_HierBautBerlin'} =
	    { name => 'Hier Baut Berlin',
	      callback => sub { showmap_hierbautberlin(@_) },
	      callback_3_std => sub {showmap_url_hierbautberlin(@_) },
	      ($images{HierBautBerlin} ? (icon => $images{HierBautBerlin}) : ()),
	      order => 7500,
	      tags => [qw(construction)],
	    };
	$main::info_plugins{__PACKAGE__ . "_DAF"} =
	    { name => "Deutsches Architektur-Forum",
	      callback => sub { showmap_daf_berlin(@_) },
	      callback_3_std => sub { showmap_url_daf_berlin(@_) },
	      ($images{DAF} ? (icon => $images{DAF}) : ()),
	      order => 7501,
	      tags => [qw(construction)],
	    };
	$main::info_plugins{__PACKAGE__ . "_ArchitekturUrbanistik"} =
	    { name => "Berliner Architektur & Urbanistik",
	      callback => sub { showmap_architektur_urbanistik(@_) },
	      callback_3_std => sub { showmap_url_architektur_urbanistik(@_) },
	      # no icon (yet)
	      order => 7502,
	      tags => [qw(construction)],
	    };
    }
    $main::info_plugins{__PACKAGE__ . '_Windy'} =
	{ name => 'Windy',
	  callback => sub { showmap_windy(@_) },
	  callback_3_std => sub { showmap_url_windy(@_) },
	  ($images{Windy} ? (icon => $images{Windy}) : ()),
	  tags => [qw(met)],
	};
    $main::info_plugins{__PACKAGE__ . '_OvertureMaps'} =
	{ name => 'Overture Maps',
	  callback => sub { showmap_overture_maps(@_) },
	  callback_3_std => sub { showmap_url_overture_maps(@_) },
	  ($images{OvertureMaps} ? (icon => $images{OvertureMaps}) : ()),
        };
    if ($is_berlin && $main::devel_host) {
	$main::info_plugins{__PACKAGE__ . "_AllTrafficMaps"} =
	    { name => "All Traffic Maps",
	      callback => sub { show_all_traffic_maps(@_) },
	      order => 8999,
	    };
    }
    $main::info_plugins{__PACKAGE__ . '_AllMaps'} =
	{ name => 'All Maps',
	  callback => sub { show_links_to_all_maps(@_) },
	  order => 9000,
	};
}

sub unregister {
    my $deleted = 0;
    for my $info_plugin_name (keys %main::info_plugins) {
	if ($info_plugin_name =~ /^\Q@{[ __PACKAGE__ ]}/) {
	    delete $main::info_plugins{$info_plugin_name};
	    $deleted++;
	}
    }
    %images = ();
    main::status_message("Removed " . $deleted . " map link definition(s)", "info");
}

sub _create_images {
    if (!defined $images{WikiMapia}) {
	# Created with
	#     lwp-request http://wikimapia.org/favicon.ico | convert ico:- png:- | base64
	$images{WikiMapia} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQBAMAAADt3eJSAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAIVBMVEX////4qazxVVv84uPw
Rk3uKjH1jJD71NX98PHtHCT///9s7lfjAAAACXRSTlMAYL8fz+6BMA912afJAAAAAWJLR0QAiAUd
SAAAAAd0SU1FB+MDHgwmFHt8N80AAABiSURBVAjXY2BgEJrJAAYmMyEM5sgwAzCDZYpBGZghGdwE
kdJM0IQwZppDFc9kQ2LMnJkwEyw1c2bxTLDimZPYJoG1z9QwnQg2MJ3Z0wFsBXPqVAOwpTNnOoMM
EJo5U5GBAQAfoSGvI8kSrwAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAxOS0wMy0zMFQxMzozODoyMCsw
MTowMHS3C3cAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMTktMDMtMzBUMTM6Mzg6MjArMDE6MDAF6rPL
AAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{OpenStreetMap}) {
	# Created with
	#   lwp-request http://www.openstreetmap.org/assets/favicon-16x16-b5e4abe84fb615809252921d52099ede3236d1b7112ea86065a8e37e421c610b.png | base64
	$images{OpenStreetMap} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlz
AAAA3QAAAN0BcFOiBwAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAAddEVY
dFRpdGxlAE9wZW5TdHJlZXRNYXAgbG9nbyAyMDExsFqqrQAAABN0RVh0QXV0aG9yAEtlbiBWZXJt
ZXR0ZXA2QEoAAAA5dEVYdERlc2NyaXB0aW9uAFJlcGxhY2VtZW50IGxvZ28gZm9yIE9wZW5TdHJl
ZXRNYXAgRm91bmRhdGlvbrV+75QAAAAYdEVYdENyZWF0aW9uIFRpbWUAQXByaWwgMjAxMWGrJ9IA
AABJdEVYdFNvdXJjZQBodHRwOi8vd2lraS5vcGVuc3RyZWV0bWFwLm9yZy93aWtpL0ZpbGU6UHVi
bGljLWltYWdlcy1vc21fbG9nby5zdmd1KgF5AAAAUnRFWHRDb3B5cmlnaHQAQ0MgQXR0cmlidXRp
b24tU2hhcmVBbGlrZSBodHRwOi8vY3JlYXRpdmVjb21tb25zLm9yZy9saWNlbnNlcy9ieS1zYS8z
LjAvXoNavAAAAzJJREFUOI1900tvVGUcgPHnfc+ZczrXTqe0IhUyNtIK1jYKKSkQRBcu1BhXYmL8
ArrzG7jQlRvQYDS6IaGJVhZK0oUxxGgqTXqhLQKxUBMKrWWm7XRmzsy5zvt3ZWJY+Fs/20ctbX83
niAXEW7EiblczPZtiOF0I2i8v7H38Hmt5W5/rnRBW9aPOat0FlHnUnbqmeHiy6MASkTU3Pa3dzAM
04rpKpYwRlFp1fCjFnFNGOg9TgqL2CS0I4OttujtdSee6391VgNiDFdFBBMktOo1JAmxTAev4nLk
qTM8USyxr6+HQneWTFpT9zOs/VX5AEArpVTUkIprZdDFHLqjCI1P5LU50DNIJp3GWKDRZN0s0pWg
3AQrdfAtAC0i0l0ovOLYGVydJu3kqDR3WX3gUcwPYEkB4iKRX6TdztIODVZGkRjfGRs71a/hI43N
yY5ERHFAK2rQMC1yHCAMu2kGijCyaIYdqnXBMT0oBW7WtodGB4/Y17cOH9SmXnBSLh3PJ8512G8N
8GfTIwgj3IyHskO8djeCjeu2gTQ61dW+e/PmvD755LsPwzjZbLWbGIlQiU3a7mOwPM7P01fw/A6J
tMnkt8gXN0m7NuVcmcjTt0UEDVD5e3tJWRolEAYaE/ZQqzf4Y/ZXpqeukiSCIKQsix4psFndZce7
9ZmVz3drEen4Df9enMTsiUM6dpi+9A27y9+j3YBMocLtlVX2HiVsPwqZuTXP/QcruK7/4o0gqNoA
g08fPey4BbKOz9RXP7Dy+zrLusFr75xj9IU+7JLN5voctfouSUlzqDTIyszWOgsLiQbodKmzgsfk
+SvMXbtLkuxw9MSzjI7vJ7IP0WVshgbKFMsFbFeohPflwudfXhYRsRdqU91BJ05PfjrN8uwaju1z
+s0JXjoxgi7apmBXteftI53fob7nYaVsUlYq2FzcrAJYI2PDpaDdGrvz22p5b6+iTr0x0cr3ZpZ/
ubZ0/ouPL33SkXgj5ehcYiIdeP5Wfat5/afJmQ/ffv29tX9nYmRkJHfmuPP1zLKqGu1cdFV8b35+
PuY/lFI5EfF4jBIRlFJq6Nix3qwxanFxsfp49H/+AUEPkL9IoET7AAAAAElFTkSuQmCC
EOF
	}

    if (!defined $images{BvgStadtplan}) {
	# Fetched http://www.bvg.de/images/favicon.ico
	# and converted using
	#   convert -resize 16x16 favicon.ico bvg.gif
	#   mmencode -b bvg.gif
	$images{BvgStadtplan} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPYAAB8cByklBy4rByclCCklCSwoCi8sCTAtCjMuDD05CTw5DEE+C0ZADElC
DUxFDU5GDFFLDkVCEEtIEFVSEFlWEV1YEWRfD2JbEWBcE2JgEGZgFWlhEm5pFXZuF3lvFYV7
F4qEGY+HGZWKGJeLGpmPG5WRHZyUGqOaH6idHqegHKyjHbCnH7OpHrawH6SaIK+oIbCkILSr
IbmwIsS5IsW9I8i6IMi8I83GIs/DJNDCJNTIJtjMI9jIJNrPJdfMKdjNKNrRJuDTJ+TTJubW
JebYKuTdKu/iKPPiK/LlK/XjLfTlLPXmLP3rKvzrK//rK/7tKf/vKvrpLPvrLv/rLP7rLv/s
LP/wLgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAALAAAAAAQABAAAAe5gFOCToKFhoWEh4qHTomL
j5BTTY2FTZJNmJmSlJJTUpeYlY1PT1ZOmZmlnk5HPDpGSUJNS0RNRzY9UVNWKAYKFysORCwW
PhcGDThNViEMKgYuBTMfFyAMNzpImCMGFxBADiUaHxscNidAyyMEFQ1AHRcOMBgeKgEuVlYi
DDQELSkBDPjgQMFIhBL5SAyYoGCHDgASlMQwQMFADCtPgJwwgUPKEhg0rCyRIUKFEitTSuVL
SerUsieNAgEAOw==
EOF
    }

    if (!defined $images{BerlinerLinien}) {
	# Fetched from https://www.berliner-linien.de/pic/li.060c.png
	# and manually edited
	$images{BerlinerLinien} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAALvAAAC7wFAipWXAAAAB3RJTUUH6AMeDCwE9uM/4AAAAoRJREFUOMt1k09IVFEYxX/3vflT
NpY+NSKoXTsLhow2SQshJVsEgVCUG6m2biowjIKkwChoFS2sXStRK8pwUQYuahVU60RQp0ad14wz
OfPeu6fF2FihZ3Mv3HO/73z3noO2wMLCmk6cWFJ395Ky2fJWNFHbWUnh+irp2jVfEAhCDQ0V1ilW
oQ3/KeAAICic9wm8EvmOHNZa0mkLxACHdDokshHHR4/TPNJM31QfNUjVzkFjSaIiJSoKfgSSpCtX
ZjU8PCdJWlxdVPxxXDxCLSMtimz0lwIHikfWIAF5p0BlvgxAIlGPMfUALOQXcAOXuBPnqHcUx1Sv
xgAwUD+5i2hZJDLbiR9yCaaKgEEGJudecur1ab70fKGpronm7c0bI5QzGeUHB+VPTNQe5tfbivIt
OXXdvaoLw0NqfNqoqfm3tXN/fFz5W7dUzmZlVjo71fjmDQDfbt4kZQyOYGjnBx6kXoHg3vI5Ljqt
IMNqGLJ3cBCA3JkzxIxUU5O0ljrHwSCa8tsgVR2voBXszwIConK5xjdRBGuLiyreuCF/fLwm8cXc
pLwnLTp5/bbOPhxQ0VtV8f2GmXLPnqkwMKByJiMjVSVYWbKlLPP5eQ5PHGbm9DvG7h9k/z6XSwdc
Yt0JKl8j4l4MZ3cMB7PxC0J0jHUwszyDW3b53POZ1t2tjGkFEMmuFMWPRUiHxKIYfleOhufeRgEr
yyf/E4ENMEnDntSedR/8ZMcOF2gguTeJGyUggNTHOrBV//DH472TvfJGPHWOdcpaq9HRFYEEoaan
fYVBqMKxnAKvJP/y8iZhkhTaUHY9Tf39uVqY7txZ/Tdwm6bxP8zO/lJbW1bt7Vl9/762ZZx/A84s
RMCafb9MAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{Pharus}) {
	# This is the favicon of www.berliner-stadtplan.com, run through "base64"
	$images{Pharus} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAASFBMVEXEtrz8+vzMusQTkyWU
joz88mQA8gqknqS0qqykmpzM2uTMyrTsRjR0moyUknzMunzMyszUymzc5lzk1mx0tnzc7vT06lz/
//8oqzT8AAAAAWJLR0QXC9aYjwAAAAd0SU1FB+AMEQ0THxP6s+0AAACbSURBVBjTJY7bAsIgDEMT
2jDYHG6K/v+n2iIvTS+cBACLGegyI9ajWd0IVbOWfbNaKwmPYh3w6M32xsNSPRDFGuP2pEIactzL
YMdTqeOPRJRjpwYuLqNbrwK8lY4OsrMptjqdHqyCPc6GpDnnFagE8QNI91zQtMVGqetve61gTQ0r
2AxoRteXK7qEIMYqLD3vh+DwZiYcMR+R5AdYUAS1NmdRiQAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAx
Ni0xMi0xN1QxNDoxOToyMSswMTowMF/HH4gAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMTAtMTEtMDhU
MTE6NDQ6NTUrMDE6MDCRfW6PAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{BikeMapNet}) {
	# Created with
	#     lwp-request 'https://static.bikemap.net/favicons/favicon-16x16.png?v=M4oBa62yYG' | base64
	$images{BikeMapNet} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQBAMAAADt3eJSAAAABGdBTUEAALGPC/xhBQAAAAFzUkdC
AK7OHOkAAAAnUExURVW9/1a9/0xpcVe+/1e+/1e+/0u6/2nF/4LP/7rk/6zf/5rY/83s/9rJtuQA
AAAGdFJOU//UAFFVT7rGxFMAAABPelRYdFJhdyBwcm9maWxlIHR5cGUgaXB0YwAAeJzjyiwoSeZS
AAMjCy5jCxMjE0uTFAMTIESANMNkAyOzVCDL2NTIxMzEHMQHy4BIoEouACiVDuMqIm0fAAAACXBI
WXMAAAsTAAALEwEAmpwYAAAAcUlEQVQI12NQFmAAAsYgBgcGMGBmEGBgAwsBcTlbGjtYtGZ7+aoC
IJ2WuaNrWhoDA1v1qraKzu0JDOkzVi7YMauzjCGrYMfJqgr2ZUBG9/GsAiAjYwJXW8YEzjYGts4Z
CSDMwJDABsECELsYEZbCnAEA14gfbn28kNUAAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{CriticalMaps}) {
	# Downloaded
	# https://www.criticalmaps.net/assets/images/logo.svg and
	# edited with gimp
	$images{CriticalMaps} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH6AIVEzEPY0bAiAAAA0hJREFUOMttk29M1AUYxz/3uz/8
OI4/YhwEd4ecHAHSBLITpDId4patLIOcrVrKVtambcwXukULtrb+sDXnmltlb/Bdq6zQF43TZeUq
k3K5SGUuQOW4Ow64O7j7/bmnF8Ek1+fN8+b5bs/z7PlYuIMVMNUcpSydye4EHgY8gAn8AZwFvljq
VYAsgIX/cgh4tW6t0/vk1gJpqFZtixnJ/nApqZ8KzTni88YFh8NxSNO0H1eGlKX6Hooqjc0PpUIn
fCmJtogk20SmW0Rim8wDz90TfyC4RYAYsGMpY1ke5WC52/7ajkeKomUl9kxNpWpGRpPp/XtHY6Fv
wvOkDGqqVCNXtcef2KzagONOVakFhJJi22rg+pfHqnW5HZSrQ2tj3360JrV9s2+mpr7tFjjTL+3y
TMtkUCaGqxMyu0me6VilAYPLK+wL+HI0mQiKjAflk/57F7F6b6u5hbFKny9xcnDwBlgyR494ojK1
UeT6Brl6Zl0GCANegBP9B8p1GQ+KXGsWfwU3JyanDBHRuru7Z4DUwMD7t4DI1Pn1C3Jtg8iNBxPN
9U4BHlcAT2ujy4bLyvC5yTnPfU8XeCpKs319fYsjIyO2jo6O+bOhkK2lrV05PDCWwGmFMofL780B
8NsAy++jCbwXWGyqX+34e+xiwjA0tbOz02htbTV6enpcs/FYdj6pZ06fqVqVnTX0P3+JarPzRt7y
DT4ucXv0rVva/jIu368f3GOffbPvg5jcIdP31htxKLiZ+W29nD7uj69r3HbFmZsjwGMAeyxWVbY/
6p8In2/QtctNmYqy3GhqQdNM0xQRkXA4nHC7S6PpkQbz86P+eEP9mjAwA5Qo+XnWITHTV/bvkhJ3
rctmdzscAW9W/+nni4ai/Ptjz7/Qnex/RXfkFDuVp/aWFVW5Y/nAZ0BESaTMOeDYi0fGzbFfkwsU
WplLKmqlz5cCMoBeW9+o2KyKjVI7H74zqX19LjHlsFveXSkRwOGifGsq9GkgvrGpXJ+OxCPt7e1T
vb29ka+GvpvZt9OafPv1iiwwuiTa/7nEy8ClvDyXdHV1SSAQ0Ovq6szdu581AQM4BTSvDFjukipb
XGgvnpnTtwFtK3VWVcf36bQ2fLfO/wAJ33sTrfsaPgAAAABJRU5ErkJggg==
EOF
    }

    if (!defined $images{Geocaching}) {
	# Fetched logo:
	#   wget http://www.geocaching.com/images/nav/logo_sub.gif
	# Cropped whitespace and resized to 16px using gimp
	# Created base64:
	#   mmencode -b geocaching.gif
	$images{Geocaching} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAMZ9ADMxNjQxNDMyNTEzNzM0NTQ+OS4/RkM5NjVBOkQ7NkM/MitHTElFMUpG
MUtHMVNENyNcYl1KOCJfaVhSMFtXL1xXL11YLjlqRzpvSBGBjw6Hkw+HlRCHkw2Jl4JgOwqQ
nguQnDuGUAmToTuNUjyNUnx3KQOgrzyUVAGisoN7KQCktACktT2cVz2dV4qBKaJyPw2ouD6j
WT6kWqx5QD6vXT+yXrR+QJiSJT+2Xz+3X7eAQLmAQKGZJqiiI9aRQ9eRQ7WtIbiwIdqaTuqc
Re6eRcS7H/GfRsa+HfKgRvShR/ejR/mjR/qkR8vEHdDIHPqpU9bMHNjQG97VGt7WGuHXGsfG
x+jfGOziGPHoF/LoF7ze4dTV1brh5vbrFtnZ07jm6vjuFvnuFvrvFfnwFf7yFf/yFd7e3//z
Fd3f3dfm29vp3tjs39nw39zs79nx3/3kye7sz9vw8tnx89ry9P7u3f7u3v78zf/8zfL7+//9
3Pn7+v/89v/99////////////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQBCgB/ACwA
AAAAEAAQAAAHzYBYUl1HY1NleW44i4w4YC5BKTdUiGonNI04VzwUFT1niGgEBSGNZFklExZN
Z3lsMRckjWVWClRODU6JjDIji2VFDGFnUVC7ODkYCDU4ZUAOYmXSxzgsAi04d3BednfefHpu
4mtbaW5fWlVcX+x4e2/w8W8qIgAaKvhydEtJRv5IS1SgWAABnwp9S14cSPBAR0AVHEAYRLgj
QAQfSx7i6yDhQ5x9PzwQyahxRQYDA8zsG2KDpEZ8Jja02adkBhOSMHLqhDGnzpMnQn7+DAQA
Ow==
EOF
    }

    if ($map_compare_use_bbbike_org) {
	if (!defined $images{BBBikeGeofabrik} && eval { require Tk::PNG; 1 }) {
	    # Created from http://www.geofabrik.de/img/shortcut.png
	    # and srtbike_logo.svg with Gimp
	    $images{BBBikeGeofabrik} = $main::top->Photo
		(-format => 'png',
		 -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAA3XAAAN1wFCKJt4AAAAB3RJTUUH4wMeDAAyaq8xFAAAAwtJREFUOMtVkt1LZAUYxn/nnPl0
dDV3VltxR8i1KJasca1IpllIoVroIrUIYWmuwgK7EYuuov9AMBKCudkdSgNbWIW2SJbCbWU/mN1V
1jVTcZ2jO+p86HzPmfN24U7uPFfPCw8P7/O+jyIiwlMolkx+DC+zk87y0cttNNdVs5eA73/fx2VV
+ey9auy2I71aJmWfhe09tlNpDNPkr3WdZMpk6GKU7+5v8sdymlSGCijlDTbiBzyIxliKxhEFHBaN
QskkFnfwdyTHJ6dfpKPVhqrCac+RgaVMUoUi4a0dXmlq4NWmE1hUhcKTON1WF/3nLHz6wx7RVIEr
wyePDNKFIrc2o9zY2Kal7hjnnmtiauFfHiVS1DrtFEsmYt/n0u0VVJuTXEmrjDB+474ksnmKJZPe
M62YIlxbjfB22ykcVo2rSxvEszkURaFYgruPbORjbrqaa/nywypUT10NVk0FBXJGCYdVwxCThzsJ
nq12YbdqCGAK7Gc09PjhrClPIrz7QgtnGuu5thrh5uZjAmdforO5kccHGVQFFBTE1Li1ZqM678aR
N7jy1cnKN9aqgn5zjt2DNJfuLHG8ysHZU408jCZIZgtIroYHup39gywmJmNjYxSLxUMDXdfx+/24
LCqvP+Ng5Z9lfr63wsXbS/yysEo+doK9SAYQqpw2BJVkMkl3dzf5fB5ta2vrm5GRET7u68WpCL9d
vcexliY0FdRMPe+35bkcmqDX/w67OUjkDYJfnycWizE3N4e6uLhIT08PAMHQHS7zJpFdO6VcCV9D
guvX/+StzuN88YELTYFy8QcGBpidnT28QbnGgQvn+bazlRH/86z++hP1NQ6cTifZbBaAC6/V8vkb
DQBkMhlcLhcMDg5KKBSSp7G2tiZer1cMwxBd18Xr9UoqlarQDA0NSTAYFBKJhHR1dcnw8LBMT0/L
6OiotLe3y/z8/P/iyclJ6ejokPHxcZmYmJD+/n4JBAJimqYoIiKGYTA1NUU4HMbj8dDX14fb7a6o
7Pr6OjMzMySTSXw+Hz6fD4D/AElkl2avow92AAAAAElFTkSuQmCC
EOF
	    $images{_MapCompare} = $images{BBBikeGeofabrik};
	}
    } else {
	if (!defined $images{Geofabrik} && eval { require Tk::PNG; 1 }) {
	    # Fetched logo:
	    #   wget http://tools.geofabrik.de/img/geofabrik-tools.png
	    # Manually cut "G" logo out and resized to 16x16
	    # Create base64:
	    #   mmencode -b ...
	    $images{Geofabrik} = $main::top->Photo
		(-format => 'png',
		 -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAAZiS0dE
AP8A/wD/oL2nkwAAAAlwSFlzAAAE8AAABPABGA1izwAAAAd0SU1FB9kHGBMgGqjuhNYAAAAd
dEVYdENvbW1lbnQAQ3JlYXRlZCB3aXRoIFRoZSBHSU1Q72QlbgAAAhhJREFUOMuNkz1MFGEQ
hp+5Be5PTo9wiNFwYEKUChOWWJm4VmpnLDBRI7Gw0OJILFxbCrMFSGVrY0jMtRZ2boiFwWww
aqJQCGoUTxMh/Bw5jt0dC+90PbzoW803mXnnnflmoAGO60Xt+47rpRr9/wXH9a46rqeO6z38
G3kdsSaV+4Bbted5x/UuAtiWuYtEGqr2AR+Au0BBVX8GibwEzgBJ2zIX/1DguF6UdUxVA4FC
3DA0k4jTkUpomxEbBJZV9VGjYok49gJ3gOtDB3Mc7+lWQKpBqCvlijxeeM/Wjj8rIqO2Zc7X
SaRmnATGQ9UTvdmMXhjsl6dLy7wufafiByRaDMrVHQ1VRUSWgHvApG2ZiON6U8ANoDUIQ04f
yWs+m5HpuQV6su3k0kkqvs/bb6tsbldVRAQIgWfA5Ragt/4bCsQNQ4IwxA9DcukEhzsyZJNx
Pq1tsrldjQ6/C8jFbMs8B1wB3sREeLeypl17UgzszzKz+JkHc/MYEgNFa4mrwARwzLbM59Eh
HlLViVbDGDl7NE9/5z6+bmwRqnIgk2b6xQJf1suvROSabZmzv4bouB62ZdZJpoAxQ4TOdFK7
21NS8QMtbZRlvVIlVJ27fWp4qJ5sW+auRRoGSsC4qo7q74YXReQS0GZb5kyz3Y/aA47rfazd
QuC4XqExrlgs/vOYbtYInjQ7pmKxKLFmSmzLnARcYCTacwP0B/bXAvRRlokcAAAAAElFTkSu
QmCC
EOF
	    $images{_MapCompare} = $images{Geofabrik};
	}
    }

    if (!defined $images{Bing}) {
	$images{Bing} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAIQPAP+mFf+sJP+xMv+3Qf+8UP/Hbf/Ne//Tiv/Ymf/ep//jtv/pxf/u0//0
4v/58P//////////////////////////////////////////////////////////////////
/yH5BAEKABAALAAAAAAQABAAAAVaICCOZGme5UAMaLk8S0u+MRAQ6/kySPP8PwVhBmwccIXX
IzFSJgKlwg8hUkJNiYdDpHg0UIefyPAblgK+r4ihNZAIbAdLFED8HIuF78GYkwQGCnkLRzKG
hyMhADs=
EOF
    }

    if (!defined $images{TomTom}) {
	# Created with:
	#   wget 'https://www.tomtom.com/kenai/favicon.svg'
	#   convert -resize 16x16 favicon.svg favicon.png
	#   pngcrush -brute -reduce -rem allb -m 0 favicon.png favicon2.png
	#   base64 favicon2.png
	$images{TomTom} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAYBQTFRF
/////vv798fE7Xx36FlS6WFb8JWR++Lg/vb175CL4i4m3xkQ3hYN3hcO3xwT5UhB9sG/////8JeT
3x4V3xgP4Sgf5UdA5D423x4V3hcN4zkx+dLQ+t3c4zcv3hcO5EE69r+9/fDw/Ojn8JKO4CQc3hcN
63Js//z886uo3xwT4CAX9K+s/vn56mpk3hYN4zsz++bl8JWQ3hcO4i4m+tnX8JaS3xgP4S0l+djW
8qSg3xoR4CQb9r+9//7+7Hl03hYN4zYu++Hg+dPR4i0l3xgO6FhR+t3c//7+/vr69bSx4i8n3hYN
6WFb/vj4/vv77X553xkQ3xoR5Dw16mtm6F9Y4Skh3hcO4Soh9r67/Ovq621n3x4W3hUM3hQL3hQL
3hYN4i8m8qKf//z8/fPy86uo6WVf5UlC5k9I7Hp1+MvJ//39//39/e/v++bl/Ojn/vX0/////O3s
6m1n5k1G5kxF8Z6a8JSQ3hcO4jEp+dPR/Ovq5lBJ742J////98jG++TjbALhHwAAAHpJREFUGFdj
YgACRiZmFlY2dhCTgQmIOaBAACogyAUD0hABbgRQBwvwAMGD+/c4QQAsAGEwXAEZAxaAMBhsUVS4
uXuAdPLAzYCCzWCBTXBruaAOW84JBfOgAgxz2cFgGszpDAxsIDCBASHQzwIEDEgCDBgCbczMzRAW
ANziDx7V367aAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{Waze}) {
	# Created with:
	#   wget 'https://www.waze.com/livemap/assets/wazer-b704da66a0980396d93be87ea64c4e2b.svg'
	#   convert -resize 16x16 wazer-b704da66a0980396d93be87ea64c4e2b.svg png:- | base64
	$images{Waze} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAAAAAA6mKC9AAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QA/4ePzL8AAAAJcEhZ
cwAADdcAAA3XAUIom3gAAAAHdElNRQfnARQULy+HbGZ6AAABEklEQVQY0y3BTyhDcQAH8O97vzfl
1WPtwEEu/qwczZKji+IkFynpHXByINGkSHJxI+WwdnCh1pODJLUNBwdZnDis1bKVzMrzk83M3ntf
F5+PQgC/KetVeGp4qhNQCMjd/GioyX1J3JnDCsjK8rokSfJ+/JwgD+a/+S89kVNhJ2caUcp4wHMh
3Huk4snfA0SnJeqRDQylNeTbBTDWZ0Cb86HN1VDVAXR1+KAMuBCqinIDgIetMpz9U3y6wn872QoE
bqxc/M00ku8IWSTJ6lX0TNI2E4jNFimLDkmysrZZF8eFw4/VvZ9+AS+zjSVdoXOxmEVgoeXrMRU8
aYYGbSSeBVDasTFoACB5HdRXarWI3n1J8g/njYW7wvgGUAAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAy
My0wMS0yMFQyMDo0Nzo0NyswMTowMHwAIGoAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjMtMDEtMjBU
MjA6NDc6NDcrMDE6MDANXZjWAAAAGXRFWHRTb2Z0d2FyZQB3d3cuaW5rc2NhcGUub3Jnm+48GgAA
AABJRU5ErkJggg==
EOF
    }

    if (!defined $images{DAF}) {
	# Created with:
	#   convert http://www.deutsches-architektur-forum.de/forum/favicon.ico png:- | base64
	$images{DAF} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQAgMAAABinRfyAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAADFBMVEVNTU3////ajx9Rcagb
sWHEAAAAAWJLR0QB/wIt3gAAAAd0SU1FB+ECGRIMLMfSfQMAAAAYSURBVAjXY2BgkFrFgEaEAgHD
fyAgnQAA1G8wOeyCs3YAAAAldEVYdGRhdGU6Y3JlYXRlADIwMTctMDItMjVUMTk6MTI6NDQrMDE6
MDDSKYNAAAAAJXRFWHRkYXRlOm1vZGlmeQAyMDE3LTAyLTI1VDE5OjEyOjQ0KzAxOjAwo3Q7/AAA
AABJRU5ErkJggg==
EOF
    }

    if (!defined $images{FIS_Broker}) {
	# First try was
	#    convert http://fbinter.stadt-berlin.de/fb/images/favicon.ico png:- | base64
	# but the icon was too blurry and quite large, so I took
	# http://fbinter.stadt-berlin.de/fb/images/fisbroker_logo.jpg and hand-edited
	# with Gimp (crop + scale to 16x16 + indexed color mode with 16 colors)
	$images{FIS_Broker} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQBAMAAADt3eJSAAAAMFBMVEWPkh6QkSeXmDaZmTCYnB6e
oDunqFC0tme7u3vKzY3OzZzb2qzk4cLz89v18+P8/vv6G3U3AAAAAWJLR0QAiAUdSAAAAAlwSFlz
AAALEwAACxMBAJqcGAAAAAd0SU1FB+EGCxMzFc5bjNQAAACWSURBVAjXY/j//1Wx2dz//xn+/w4x
NlbuBzIWKCsbKXH8Z/ijagwEhvMZPjIwMAoIMvIz/N69a+aafe/vMUxgVOtevfcGB8Pp3TPCT5xS
1GDYzKB5vDrB2Jxhcc1inQZlZQ2G24VcW4WVjbUZPpgeFzVSNrJj+LPL0JiJ2Wg9yApjZWVxoF2/
lJWNjUGW/n+Zltb7/z8ADMI7t51Q4A0AAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{Mapillary}) {
	# Created with:
	#   lwp-request 'https://d1dk9tvuiy3v51.cloudfront.net/assets/icon/favicon-16x16.png' | base64
	$images{Mapillary} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAAFzUkdC
AK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAL1QTFRF
Nq9tNq9tNq9tNq9tNq9tNq9tNq9tNq9tNq9tNa9sNK5sNa5sTLh9YsGNM65rh8+o0+7fSLZ6Na9t
ObBvvuXQ////jtKtasST2vDkrN7D1u/hUbqBS7d83PHmqN3ARLV4tOHJdcibYsCN/v7+RbV4Mq5q
UrqBsODGVbuER7Z5jdKs1+/ituLKU7qCQrR2uuPNpty/NK5rULmAdsmcsuDHuuTNpdu+6PbuXr+K
pty+Xb+KseDG5PTraMORX7+Lt5+LqQAAAAh0Uk5THJ70G/3z8vzrOLjDAAAAAWJLR0QV5dj5owAA
AAlwSFlzAAAASAAAAEgARslrPgAAAJ5JREFUGNNdz2kTgiAQBmBQKcBCC63sslu7o8su+/8/Kw/A
mfbLss/MsvMCAA2sy4AmgFb+IrQUCwKUd7vRJKUgUDTmuC0pBbS553eoBsJ4txf0B1QCGTreaBxO
pkwCnbnzYLFcRTFVK+vNdrc/HE/6UyLOl+vtnjyEuoIpi5+JH3ENGeHX+5OKCjAWPP3aGaAqmsjm
mgynqg6B+Rf/B3qgDxqL68FkAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDE3LTAxLTA5VDE1OjA3OjUz
KzAwOjAwDs2y7AAAACV0RVh0ZGF0ZTptb2RpZnkAMjAxNy0wMS0wOVQxNTowNzo1MyswMDowMH+Q
ClAAAABGdEVYdHNvZnR3YXJlAEltYWdlTWFnaWNrIDYuNy44LTkgMjAxNC0wNS0xMiBRMTYgaHR0
cDovL3d3dy5pbWFnZW1hZ2ljay5vcmfchu0AAAAAGHRFWHRUaHVtYjo6RG9jdW1lbnQ6OlBhZ2Vz
ADGn/7svAAAAGHRFWHRUaHVtYjo6SW1hZ2U6OmhlaWdodAAxOTIPAHKFAAAAF3RFWHRUaHVtYjo6
SW1hZ2U6OldpZHRoADE5MtOsIQgAAAAZdEVYdFRodW1iOjpNaW1ldHlwZQBpbWFnZS9wbmc/slZO
AAAAF3RFWHRUaHVtYjo6TVRpbWUAMTQ4Mzk3NDQ3MwX4I+MAAAAPdEVYdFRodW1iOjpTaXplADBC
QpSiPuwAAABWdEVYdFRodW1iOjpVUkkAZmlsZTovLy9tbnRsb2cvZmF2aWNvbnMvMjAxNy0wMS0w
OS80MTk0MjEwMWEwYjc5MzVjMDhhN2VjMTE3ODdjODI0Yy5pY28ucG5nLsj4ngAAAABJRU5ErkJg
gg==
EOF
    }

    if (!defined $images{KartaView}) {
	# Created with:
	#    curl -k https://kartaview.org/favicon-16x16.png | base64
	# (certificate problems with lwp-request and curl without -k)
	$images{KartaView} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAAFzUkdC
AK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAALpQTFRF
DB0uCxwtCxwuFic3GCg4ChssFSY2CRssFCQ1o6mwrLK4Fyg4Lj1MjZWdw8fLLj1LESIymaGooqmv
NUNRz9LV////ztLVECEyEyQ0ECExpKux/f7+3uDi/v7+pKqxDyAxKDdG3uDjy8/SLz5My8/TJzdG
Lz1M5ujqsLW7DR4vsba8Gio6x8vP8fLzkpqhkpqiaHN99vf3gouU9/f49vb3gYmSg4yU+Pj59PX1
e4SNEiIzfYaPcXuFDx8w3kLWyQAAAAFiS0dEFeXY+aMAAAAJcEhZcwAACxMAAAsTAQCanBgAAACY
SURBVBjTjY7ZFoIwDEQbsLiCVYyK1hUFK6Dgvv7/b1ktaB+dh5zMnEzOJUQTwG83DDnMUmEpWBaU
K9VaXd3Qhu04dpO12uYnoG4Hpbpur68K3gCHnI9wPMkL0xnOfX+BfElVEIS4EmKNYaACiGJMNtsE
4yjnoGn2fpqltABkuz3i4ci+oMBO58vV08Dhdn88NS8TQQzyp17ulwtj5z0inQAAACV0RVh0ZGF0
ZTpjcmVhdGUAMjAyMC0xMC0yMVQxMTowMDo0MCswMDowMNd8ausAAAAldEVYdGRhdGU6bW9kaWZ5
ADIwMjAtMTAtMjFUMTE6MDA6NDArMDA6MDCmIdJXAAAARnRFWHRzb2Z0d2FyZQBJbWFnZU1hZ2lj
ayA2LjcuOC05IDIwMTQtMDUtMTIgUTE2IGh0dHA6Ly93d3cuaW1hZ2VtYWdpY2sub3Jn3IbtAAAA
ABh0RVh0VGh1bWI6OkRvY3VtZW50OjpQYWdlcwAxp/+7LwAAABh0RVh0VGh1bWI6OkltYWdlOjpo
ZWlnaHQAMTkyDwByhQAAABd0RVh0VGh1bWI6OkltYWdlOjpXaWR0aAAxOTLTrCEIAAAAGXRFWHRU
aHVtYjo6TWltZXR5cGUAaW1hZ2UvcG5nP7JWTgAAABd0RVh0VGh1bWI6Ok1UaW1lADE2MDMyNzgw
NDBt1/UOAAAAD3RFWHRUaHVtYjo6U2l6ZQAwQkKUoj7sAAAAVnRFWHRUaHVtYjo6VVJJAGZpbGU6
Ly8vbW50bG9nL2Zhdmljb25zLzIwMjAtMTAtMjEvYWM0YzUxNTIxZmI3OWVmOTljMjQ2NjliMTg3
NjE5NzUuaWNvLnBuZ/8pIS0AAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{Mapilio}) {
	# Created with:
	#   wget https://mapilio.com/mapilio_fav.png
	#   convert -resize 16x16 mapilio_fav.png mapilio_fav2.png
	#   pngcrush -brute -reduce -rem allb -m 0 mapilio_fav2.png mapilio_fav3.png
	#   base64 mapilio_fav3.png
	$images{Mapilio} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAkxQTFRF
AAAAAFXu////AFXx3un9AEzVAE7bAFDwAFf1AE/wAEnPAEbvAFHyB07Vscjz////////////////
////////AFbyAFLuM3Dgeab4ocH68vf+AErQAFTsAFPrIWzzocH6////AGP/AFDfAE3YV4/29vn/
////AFLoAE/e7PP+////AEvS////AFPo////AFby////AFbx////AFbx////AFbx2OT5AFbxAFbx
psT5QHzpAFb2AFbwAFHjkrf5HmjyABLsAE7cAE3ZAFTqg634EmDyAEnwAFbzAFTsAE3YbJ73Dl3y
AEvwAEfKAE7eAFbwAFbxAFbxAFbxAFDhAU3fAlHyAEHv4er6////4ev9krf5fqXs4+39QoL1AFXx
AFXxB1Latcvzkbb5AVXxAFbxAFbxAFPxAEvVEF3mydv7apz3AFPxAFbxAFTxMXb0AEvTAFPqDF7y
wdb8faj4AFTxAFbxAFPxQoL19fj+AE/dAFDhAlfxnr/6yNv8HGjyAFPxAFTxBVjxlbn5AFTtAE3Y
AFHoWJD2+fv//v7/r8r7P4D1Mnf0hK748/f+AFbxAFLlAE3ZEWDvudH7////8vb+7fP+/f7/AFbx
AFbwAE7cAE7gOnz04Ov9////AFbxAFbxAFTsAEzWAFLoWZH27fP++Pr+AFbxAFPoAEzVAFHlAlfy
Y5fz7fP8+/z/AE3XAFLmAFbwAFHlA07YY5Tt6/L9+fv/AFTsAE/cAE3ZAFPoAlXuV4rm4+z79fn/
AFDhAFXvAFbxAFbxAE3bRYDqi8GEXAAAAFd0Uk5TAAAAAAAAAAAAAAAABkWi4PfgokUGF47r644W
Fq3+/q0WBIz+/owEROnoQ6Cg3dv29fX13t6hoUXq6UQFkP7+jgUXrv7+rhcXjuvrjhcGRaLg9/fg
okUGAVTq4gAAALdJREFUGBkFwTErxAEAB9Dfy9F1Ft1gMRlkkJBk+OdOYWM7420Wy5XkM1zKYvIF
jMYz4cRgMVkuyWS4weAy6FLIexLjEPj4i4xUWZfQ5f3H6CS136SEW95Ms2aYVKCLWXUGSZXvsivm
NtFPpnxOoGN+G6/JDOj1LDTgKYvg8dlSEx6SAvd5sbwHrpMk2Tqzsg90kiQ7p1a1gIskuycUHADn
aR5jrOAQ0OZOynWOQJuboaSyAeDyK//KPCoKXDyvaAAAAABJRU5ErkJggg==
EOF
    }

    if (!defined $images{BKG}) {
	# Created with:
	#   lwp-request https://gdz.bkg.bund.de/skin/frontend/bkg/bkg_blau/favicon.ico | convert ico:- png:- | base64
	$images{BKG} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAwFBMVEX8/vz09vTc2tzMyszs
7uy0trTU0tT08vS8vrzEwsTc3ty8urz09vy01uys0uTc7vSkpqT8+vyUxuRsstScyuT0+vzM4vSE
vtzs8vzs6uyUxtzE4uzM5vRcqtTE3uy82ux8fnzs9vxMosyEutyUkpSkusTc6vSMwtysrqyEkpy0
vsTU6vREmsyEorRsbmx0ttRkZmSkzuSkoqSUwtx8utyk0uTU1tR0cnRccny02uxUUlSkrrScnpx0
dnR8enz///9niEdWAAAAAWJLR0Q/PmMwdQAAAAd0SU1FB+UCGwkWJrbBqMoAAAC/SURBVBjTTY/b
FoIgEEXHbloJBkpYGmpYWnYvu9f/f1agPchas1j7zH44A9B4RqvdaWC3ZwJYjaA/ADCHf7ARxo76
R3aFhLrYY2PuT0b1nk6DkMy4iGJSMUq8ZC4DDumiFvBynlEHUL6igWbfRRRYFq5jJeugKIATvNnu
qJJ1kERsPyusAxGSeoonII+Mn3bn7FIGvup2BbE0bnd5eRhIC7maxfM1fQBFnCl4k+vnK8pxJF2v
qtVJT/pkR4R1qR9PmhAJKXOvYQAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyMS0wMi0yN1QxMDoyMjoz
OCswMTowMIKPyhoAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjEtMDItMjdUMTA6MjI6MzgrMDE6MDDz
0nKmAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{SentinelHub}) {
	# Fetched https://apps.sentinel-hub.com/sentinel-playground/favicon.ico
	# Converted with:
	#   convert -resize 16x16 /tmp/favicon.ico png:- | base64
	$images{SentinelHub} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQEAYAAABPYyMiAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAABmJLR0T///////8JWPfcAAAA
B3RJTUUH5QQRDy0AvA6reQAABMRJREFUSMellWtMk2cYhu/3O7SF1gpU0RCgGwplg3lgoxRPiE7I
xMPYHM4TKk5GPKIgYY6ZzUzi5qIiGCl4gIDTTDAVjU6FaEwcIgY8H+LU0a6KTHGNIG2/73vf/dqf
GVaWXb/f3M+VO8+Tl2CAHH2nMcscCiicbMJm3qIK0kxgLTuD8Qp9IGGPaDJdiahvWqRj7hP48Npg
7rTQgGYqzQlPyWtd0H8uN1ABfpF4iiUC4gq1P7uToCEGrgD3M86TAo6hbfZ1Tsv3oakin08Xrdgc
so24yGqc9Z0r+Hpgm3wO5giAJiqBsGuruUd8OTOtL0IwjAgKduEnlEEG2EE2H6qWeknwXEF8p0po
V6XhqW+BfhuwFTbuMHsAvk+4w0SAM/IBLPnjYcRJZqJ1xkNMQjaeAGjHSRh+62N5dBAO7LHqNYZx
2CI7HNa7b4m7/4cAerhzrAmQy73LcDYkiyxGI66vOYMxmINnagFueCCxG6yFLYenYnlnyoNs/qTd
6Ai4XcQnJlb6vec/kk4SN5Sb9hZY5v8HgUNxtipLMBC5eeLdVwDYdvqMlC1uQiAxQozbAB48CICd
yIS29Tx7wbrx8oBa0IpHcET5SnCpTLj6xQw+RkhGW8YUsdnPiqGAld97xaIdgAAn8blsKXBj+snJ
OlWIwuLpFnyy6Clk9EJHhuMWTkHlrmVTaA1GlRSxFUoTDnfu1483pDNbYIdfsa6U7Xi7UtyvKYR+
rR45dCRchlIxTVOHtAEIyJK3Bp8Ccpl8EcY3yunPSg5ZF86Yic7FLACHWT7kM3V0sLIUY49NIhu4
IagD1Bd0e+hWs7/GphVYZ5hR5dS0s8rocXytWIyHkT/ycWI3Hrwu8NoVyLtlSjYByEEHAuhuqcEb
wSppN58iTCTt3hpui5jJCqscRMvNwLu9bSyGRZIKbRS/QGhit5c4yPtEZtmqTLFQlki+ZKBJymxW
zpVhAbahB834GoDlXxpQTkix4AA5zlsK3J/old0jyLy79e6MXj0xOUZ7SE8p13U5jo6iF8lMgDvH
17OoWauRjky4UpaQG9wuHAS4ZL6IVdiT+Hi+C9EdPwh3RB7eATTgie3LxbeAeoz/ECY8t0rz3MWk
qGSjck2aRvLmmehpZQ/yXzwKXjNIQ8cOKyGviBNHco1YCTNcmj9wCiICoSb7uCp8X+NK4Gav6c1w
+jW7bUW65a8LkP7Oo3zZXrPlNICr8KBPXEiCyHHsiDewNDYCfjd1IesiqxX9CiP2E4aO4nCEIBoK
ScUqFoChbRZFI8+FeWY9DhMd7I9D02OmnG89MIAl/JucfZ9dvpQKuDmXjU6QasP+jLknH/+lZFjW
iAhlWlgDkshGOD93QwMNRJKKC6hFoDeCFWAqPtgVKao0v7Lpj0OVZ9IT5KFfCHxwNLjRHl8FyHlS
KBbyD9ROPzvW7xxLCJeL66tc6MFzDAWYnW5ExNF4+bjswurMM6SFGPC8N+ijpKnTWkf3n+/7M5qD
Q4gChG2iiFvD7yGapMKeoMF4ZKMXwH040NX1Ha2megzZ/lJIEAbjS9+D+13Cf0Ktshc3AfmK9CZi
H8eqU8gEhGdf4mS+AYZNdawbQZCda6VqTzZOXPqdzxJK0YV7WOt7OAD8BdTV7r1onAbLAAAAJXRF
WHRkYXRlOmNyZWF0ZQAyMDIxLTA0LTE3VDE3OjQzOjU3KzAyOjAwFF/rKAAAACV0RVh0ZGF0ZTpt
b2RpZnkAMjAyMS0wNC0xN1QxNzo0Mzo1NyswMjowMGUCU5QAAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{HierBautBerlin}) {
	# Fetched https://hierbautberlin.de/images/hierbautberlin.png
	# Converted with:
	#   convert -resize 16x16 hierbautberlin.png png:- | base64
	$images{HierBautBerlin} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAAA0AAAAQCAMAAAD6fQULAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAABjFBMVEUAAAA8MAwEAwFzXRif
gyJKEgkAAAAfGAOCbCe7nkPGqEuojTpeTBUAAAAFBAEAAAATDgGcfyfqxlbRsU9dSxSNcR2XeR+9
mCnzyUmhhzeskSaKbxy2kia8oEYAAAAAAAAAAAAAAAANDQwgHA+vkzsAAAAAAAAAAAAAAADxylGE
ax3/PRgUERARERFpVBa2lCxYRxL2ORvLUDtwZGJbV1YODg0BAAAsIwghGwfzOx3zOhzsQSXrWUFx
JxsDAAAAAAAAAABEAABdUU9qYF8+NDMAAAAAAAAAAAAAAAAKCwsHCAgBAQEAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/1lP/1Ez+1lv/
0kT/zDP/zDP/zTX81VvzyUf/2l//11r/zz7/zDL/1VBXRRC6lSf3zEf/2mH/003/1FFPT09wcHEY
GBgQDQJZRxHBnCz701cFBQUUFBQoKCgmJiYAAAARDgMAAAAAAAD///8LB7SeAAAAYHRSTlMAAAAA
AAAAFIrt+ctXBAENH6T85FU1vsj4uBec+tYDLEBdwfzOCLD6+/6ICmr69edLT06HwOHPSRwibG9w
n/zREgWJ2NH3xw0DTn3NnAEHWOH6UyCh9vhIILx1lv6Q5X6cpwUhAAAAAWJLR0SD/LTP0gAAAAlw
SFlzAAAOxAAADsQBlSsOGwAAAAd0SU1FB+UMDBAYGmYksHsAAAC8SURBVAjXY2AAAUZ2Dk4ubh5e
IJOJj19AUCghMUlYBMhjFhUTl0hOSU1LlwTyWKSkZTIys7JzcmUZ5OQVFJWU8/ILCouKVRhU1dQ1
SkrLyisqqzS1GLR1dKtrauvq6xv09A0YDI2MTUzrG5vq683MLRgsraxtbO3qgcDegYGB1dHJ2cUV
xHNzZ2Bg8/D08gZx6n18Qc7y8w8AcQKDQJzgkFCwVFg4kBMRWQ8FUUBedAyMFwvkxcE49fEMDABP
JTqRI9bbGAAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyMS0xMi0xMlQxNzoyNDoxNCswMTowMDvDbNgA
AAAldEVYdGRhdGU6bW9kaWZ5ADIwMjEtMTItMTJUMTc6MjQ6MTQrMDE6MDBKntRkAAAAAElFTkSu
QmCC
EOF
    }

    if (!defined $images{BRB}) {
	# wget 'https://geoportal.brandenburg.de/typo3conf/ext/di_gpstyleguide/Resources/Public/Images/favicon.ico'
	# scaled using gimp to 16x16 using the technique described here: https://graphicdesign.stackexchange.com/a/92675/172122
	# called base64 on the exported png
	$images{BRB} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAACXBI
WXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gILFQMgq6aUzgAAAetJREFUOMudkz1oFFEUhb+dZTeJ
SSNpFAlCCiWdfwgWIqYQsbAKIgg2KeyChZWFhSB2EjvLkEIQQTtRkBgSSCMaEESEgBEFY7KYTbI/
M7Mz81lkRpZoIPjg8t7lvnvfeeeeWxKMgQAw38tAApTyM3nsXyugXCE2ZbOT0L57j8bQQbI8eU8r
Apv3J91St0yM1fTzsmFlwA5ol2U7TBDBBvhz6Z2riwuGI8fV2NbsK6Oui39bScEgBapAz9M5BpaW
qX5aJDx9huDcBcqnjmHOR9qFOiMgRjqVEqT5K/H5S7bm35qBKZjW6jZnXtrogtzJY4XfKr4gmID1
jW8mhw+Zgc3Ry26p7ZFhozwx2u6Y5sUE6eTVErAxcdPGi3mT3E+eP7Gu/pp+7PrUtLWpZ66N3zDJ
c1KQtIvh+thVv6jxlbE/5MXXxm0/euiPMHFFTda+2wHDAkEb/HprwhW1pdbUzdt33Ci4AFsBfnDD
WI0GB03zAhkY9AIHZt8zOPOanjikhwZpf5O+XH0p0JfB0YvXKa+tki3MER84QhXIANpd7CZgWN1n
Wi0b7eh7VPAy+cBQjYeGjcFSBu5FtubyzgiI5t8Q9A8QnDgJ7qq03a1+dtRW7aNRUNlGsJeZKVAm
hTJ799MbrvNfBYpprQC/AQyAoLWdM9PPAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{VIZ}) {
	# Got from: http://www.vmz-info.de/vmz-fuercho-5.1.1.1/images/liferay.ico
	# Converted with convert + mmencode -b
	$images{VIZ} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAAFz
UkdCAK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAA
AiJQTFRFL06DGj9/ETd5d4mqprXFhZ+9hJ69o7PEz9fdyNfmyNflx9Hb+vr6////G0CACjWB
ACt6bYOqp7nMh6fKhqbKo7XJ09vj0uPz0uPyzNjkEzh7ACp6AB9zZXylorXJgKLHf6DHnrHG
0Nnhz+Hyz+HxydbjfI6tcIara4GnqrXIxM3Wrr3Prb3Pw8zW3uLm2ODo2N7kp7bGprjNorbL
wsvV1drf0drk0Nrj193i/fz7/vz7//792+DlyNXgztvmxtDZh6C+iKbKgaLHrLvN0drj0uLz
0OHy0tzm/Pv72ODny9zt0uTzxNPhhp+9hqXKgKHHq7rN0NnizuDx0dvl2eDny93u0uT0xdPh
p7XGpLbKoLPIw8vW09zm0dzl2d/l/Pv6/f384OPnz9jg093kzdXbzdXa0dnh2t/l0dvk0tzl
197jx8/YoLHGprbKprTFxtPg0+P019/n0tvl0d3msL7PfZzCh6bKgp29xdPf1t/n09zl0eLz
0t3nsb/Pfp3DiafKhJ6+xtDYztnly9fj//38/v382N7j0Nvk1dzhxc7Xn7PIprnNpLTG3uPm
rr3Os7zMboGndImtfI6s+/v6y9fhzd/vzd/wz9ngobPHfp7EgKDFn7PLcYaqABxuACt5DzN3
z9vl0uP009zjprjLhqTJpbjOeYyuACh3CjaBFDt9+/v7yNLaxtXhxtXiztbbqbfHiKK/pbXH
hJSxFjd5H0SCLEyCxY87YQAAAAFiS0dEDfa0YfUAAAEJSURBVBjTY2BgZGJmYWVj5+Dk4ubh
5eVl4OMXEBQSFhEVE5eQBAtIScvIyskrKCopq6iCBdTUNTS1tHV09fT1DXiAgMHQyNjE1Mzc
wtLKytrG1s6ewcHRydnF1c3dA6jc08vbh8HXzz8g0C0oGCQQEhoWzhARGRVtERMbFx8fn5CY
lJzCkCqWphfv4RGfnpGZlZ2Tm8eQX6BcaMXL61EUpFxcUlpWzlAhrlJpCRSoUq6uqa2rb2Bo
bGo2aLG2bm1rD+7o7OruYQA5xsbTsze7r0S3f8LESQxA2yZPmTpt+oyZs2bPmTtvPlhggfjC
RYuXOC5dtnzFSpDAqtVr1q5b77Bh46bNW7YCAKJlS6V7R7bEAAAAJXRFWHRkYXRlOmNyZWF0
ZQAyMDEzLTAyLTE5VDIxOjQyOjUxKzAxOjAws5ftwQAAACV0RVh0ZGF0ZTptb2RpZnkAMjAx
Mi0wOC0xNFQxNjoyODo1MCswMjowMOv6tcMAAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{Berlin}) {
	# Created with:
	#   wget https://gdi.berlin.de/viewer/_shared/resources/img/favicon.ico
	#   convert -resize 16x16 favicon.ico png:- | base64
	$images{Berlin} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAACH1BMVEUBAQEODg4PDQ0PGRgR
JiMRJCERJCIRJCIRJCEQIB4PEhIODAwODw8PDw8NDQ0NDQ3d29zz/PvnsrnfaXnhdIPhd4Xhd4Xh
d4Xkjprs3N7v+fft6+vy8vLe3t4ODg7t6en////yf4nlAAHnBRfkAAPkAAHlAQnnABrsIT37xMz/
///u7u4ODg7s6OnwgpHhABLlEy/wfYzyipjtWm7kBiThABTmJTr88vTt7Ozt6erxgpDhAA3mFjL+
8fPtWW3jABfkBiP4wMjt6+vxgZDhAA3mFjL98fP//v7xfIziABHkByP4w8nt6+zxgZDhAA3mFTH8
5Of++fr5yM7oJT/iABPoLkX99/ju7e3xgZDiABDlCSflDSrlDivkBSHjABzmEi/6zNLu7u7lCSfl
DSrlDivlDCnjARzkAyDygpH////u7e3mFTH85Of+9vf96u3wbH7jABnjARr4wcnt6+vmFjL98fP9
6u3mFDDiABHxiJbt6erxgpD+8vP5w8rlCSfiABTyjpvt6ers6OnwgpHhABLlEy/wfYzxiJbweYnm
IDviABfjCiL50dft6+vt6enyf4nlAAHnBRfkAAPkAAHlAQTnABbqDCv5nanu7u7d29zz/Pvnsrnf
aXnhdIPhd4Xhd4Xhd4XjhpPqyc7v+fft7Ozy8vLe3t4ODg4PDQ0PGRgRJiMRJCERJCIRJCIRJCEQ
IR8PFhUODAwODg4PDw8NDQ1k3tIxAAAAAWJLR0Qgs2s9gAAAAAd0SU1FB+YIChICB+D0eaUAAAEA
SURBVBjTY2BgZGJmYWVj5+Dk4ubh5WNg4BcQFBIWERUTl5CUkpaR5WeQk1dQVFJWUVVT19DUUtCW
Y9DRVdDTNzA0MjYxNTNXsNBhkLNUsLK2sVVQsLN3cFRwkgMJOLu4urkreHh6eSv4gAV8/fwDAoOC
Q0LDFMLBAhGRUdExsXHxCQoKiVCBpOSU1LT0jEyFLKiW7JzcvPyCwiKFYqihJaUKCmXlFZUKVWCB
amubGgWF2rr6BoVGoMOaFJpbWtvaOzq7unsUeoEO61PonzBx0uQpU6dNV1CYIcfAP3PW7Dlz581f
sHDR4iVLl/EzMCxfsXLV6jVr163fsHHT5i0MABrnSmdAqo40AAAAJXRFWHRkYXRlOmNyZWF0ZQAy
MDIzLTAxLTIwVDIxOjAzOjUyKzAxOjAwhjYFLgAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyMi0wOC0x
MFQxODowMjowNyswMjowMHHB1SsAAAAASUVORK5CYII=
EOF
    }

    if (!defined $images{F4map}) {
	# Created with
	#   curl --silent https://www.f4map.com/cacheForever/f51c5661379bb5441e8e773abdf87d7a8a9932cd/images/f4_favicon.png | convert -resize 16 - png:- | base64  
	$images{F4map} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAOCAMAAAAR8Wy4AAAABGdBTUEAALGPC/xhBQAAACBjSFJN
AAB6JQAAgIMAAPn/AACA6QAAdTAAAOpgAAA6mAAAF2+SX8VGAAACQ1BMVEUAAAAgLTM/QUKgoaHR
fjcqLTBKS0sVFxmHh4caGxwqKyz/9ehFRUczSVGEV0QsJCEADHsADIMrLzHNspYoJSEkJyo0Nzw/
P0INHjEbJjHGk19MXWWyq6QAAAAAAAAUFRUvLy9HREJUU1MhIyV2dnaYmJeioaCsrKyusLFrg5hD
Ul//nxs2ODmLjIyssblFYnuWfmgAAABKS0ykpKRKc5ZuaWQAAABZWVqzs7NQg69bYmcUFRZxcXHE
xMRVZ3f///8lJid8fX1TcIm+rJk+QkRSe52Lh4JKSkpqf4lUh7N+how/RUeHo7IATJZOhbZoeYcA
AABWZW2Vt8oQP24OLU0GNmUJQHUqTG4MQHUISYkvVXdPVFgWFRV4kJ0RQ3NMUlg2AAAuLS1FRUhI
MB8PHy8iKTFASU5hdH0tRl5QWWPs28kAAABAOjS1sKqFk6d3iqFsgJlifZtblsvh4uONmq5VbYxH
YoMQOWUEMWFLicDZ3N/l6evh5efg4+WkvdM+cqMCLV45caWLpL8xZ52Brc+y1Omqyt9nm8ZRkswO
PGwgUoRTjsHHyMtrjLAHVqQAUaITWqFvqN203fyEsNFanNUoW44hUYFXmNCPoaltjKcBUKAAV6wA
V6sAS5QHV6VUlNCXweBinc9Ni8JPjcNanNaRt88bXZ0AVqsAV6wAUqIASpMCV6w3fL5bksJdod1L
iL41b6Vrl7oEU6MAV6sAWKwASI8AVKgYYqpPjMIcWJITXaQ1cKcAVaoAVKZ+pcAOWKD///+n8oR5
AAAAbnRSTlMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIIEh8vGQ9pnbLF1+SBACan+r0L
AknN4ycMdOn5USKh+YcBS8e5DJzgKyLD+GM/5f/5bgFt99dxp+TfsOO+GAue8VcGLDQIKy0dkdmF
BQMkD+P6vqoAAAABYktHRD8+YzB1AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5wsUEiIH
SUrU3gAAAOdJREFUCNdjYAABRiZmWTl5BUUlFjCXgZVNWUVVTV1DU0sbzGfn0NHVy8svKCzSNwDx
OQ2NjItLSsvKKypNTIF8LjNzi6rqmtq6+oZGSytuBh5rG9um5pbWtvaOzq5uO3sGB8ee3r7+CRMn
TZ4yddp0J2cGlxkzZ82eM3fe/AULFy1e4urG4O6xdNnyFStXrV6zdt36DZ5eDLzePhs3bd6y1Xfb
9h07d/n5M/AFBAbt3rM3OCQ0LDwiMiqagYE/Jnbf/rh4gYTEpOSUVEGgQ4TS0jMys4RFRMXEJSSl
QE6Vzs7JlWGAAgBbcEehwmrrtAAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyMy0xMS0yMFQxODozNDow
NyswMTowMHlDTeAAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjMtMTEtMjBUMTg6MzQ6MDcrMDE6MDAI
HvVcAAAAAElFTkSuQmCC
EOF
    }

    if (!defined $images{Travic}) {
	# Created with:
	#   wget https://travic.app/static/icon.png
	#   convert -resize 16x16 icon.png icon16.png
	#   pngcrush -brute -reduce -rem allb -m 0 icon16.png icon16_2.png
	#   base64 icon16_2.png 
	$images{Travic} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAAAAAA6mKC9AAAABGdBTUEAALGPC/xhBQAAAGBJREFU
GFdj8EADDEDsDgcQAa+oGCgIAgu4R91+9+bN69dv3nyY5QoX+Pb/7zuYAEhL5Nr/b/OioVpAhjov
/v862hVmKBC4Lvn/OgbEpamAW9myWUHIAh5uLq4QBkwAAQDfD2Si0ao6dwAAAABJRU5ErkJggg==
EOF
    }

    if (!defined $images{Windy}) {
	# Created with:
	#   wget https://www.windy.com/img/favicon.png
	#   convert -resize 16x16 favicon.png favicon2.png 
	#   pngcrush -brute -reduce -rem allb -m 0 favicon2.png favicon3.png
	#   base64 favicon3.png 
	$images{Windy} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAftQTFRF
AAAAowAApgAAogAAowAAowAApAAAogAAoQAAoQAAoAAAoAAAowAAoQAAoAAAowAAoQAAoAAAoAAA
oQAApQAAoQAAoAAAoAAAoQAAogAAoAAAoAAAoQAAoQAAoAAAoQAAoAAAowAAoQAAoAAApAAAogAA
oAAAoAAAoAAAoAAAnwAAoAAAnwAAnwAAoAAAoAAAoAAAoAAAqyEhrCYmoAEBrSkpqiEhoAAAogcH
3q2t5sHBqyYm6MfH3aenoQUFoAAAoAAAoAAAoAAAoAAAoQUF4LCw8uDgsjw88d/f4bS0oQYGoAAA
oAAAoQcHpBQUoQUFnwAA042N9urqtUJC79jY3aenoAICoAAAoAAAqygosDw8ogcHoAAAngAAxGZm
+fDwuElJ6svL256eoAAAoAAApRAQu1ZWtEFBoAAAnwAAtT099+3tvllZ4rW13qqqoAMDnwAAuEpK
xnNzry4unwAAoAAApxgY7dTUzH191JGR5Lu7oQYGry4uzIGBynp6pA0NoAAAoAAAoAAAoAAA0YmJ
5r+/xW5u7M/Psjc30YuL1ZiYvVVVnwAAnwAArCQk6cjI26am8d3d7tXV5cDA1ZeXpQ8PoAAAnwAA
szc33Kam4LKy4bS01ZSUqyMjnwAAnwAAoQYGoggIogYGoAQEnwAAoAAAoAAAoAAAoAAA2Z6u8AAA
ACd0Uk5TAAAAAAAAB0in4/v7F5DuGK/+/q8GkP//kEnt7abi+pD/F5DuB0j7mMOSigAAAKNJREFU
GBlFwU8KAXEYx+H3M15FxorNlD8rV7DhIk7hBhxB2bqGC7iFhVlgoSykNGRM89Uk/Z4HM+pUSkkf
GRFNSMCki/QS3oKEnyNFRhd6VN6y/EZBwoBgX3qtExOMDk4eE7RTx9oEO9wsJjBzKSaQXDOC7WxD
Ek3H/G2uJd0WjTk/67uyWl4WWTrxyuqUPx9EDMAXwPIivYRZfciZvp0lfWRfheZAKhmSgB8AAAAA
SUVORK5CYII=
EOF
    }

    if (!defined $images{OvertureMaps}) {
	# Created with:
	#   wget https://explore.overturemaps.org/aria/c118a0c-20.x-dist/favicon.png
	#   convert -resize 16x16 favicon.png favicon2.png 
	#   pngcrush -brute -reduce -rem allb -m 0 favicon2.png favicon3.png
	#   base64 favicon3.png
	$images{OvertureMaps} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAALGPC/xhBQAAAqZQTFRF
AAAAQFDLQFHMQFHMP1DLP1DLP1DMP1DLP1DNP1HMP1DMP1DMQFHMP0/IQVLMP1DLQFTMQEjNQE/L
PFjLFbLDO2zLOHHKD7y/MnvJE7XDKY7HGajFQk7JP1HLQFHLQFHMQFHMP1DMP1HMQFLMQFHMQFHM
QFHMQFHMQFHMQFHMP1DMP1DKP1DMQFHMQFHMQFDLQFHMQFHMP1DLP1DLP1DLP1HMP1DMP1HMQFHM
QFHMP1HMP1HLP1DMP1DMP1DMP1HMP1DLP1HMQFHMQFHMQFHMP1DMQFHMQFHLP1DLQFHMQFHMQFHM
QFHMQFHMQFHMP1HMP1HLQFHLQFDLQE/LPmLMQWLMQGPMQFrLQFHMQFHMP1HLP1DLQFHMQFHMP1LL
NmfKG6TEQGLMQWLMQWLMQF3LQFHMQFHMQFHLQFHMQFHMQFHMP1LLJJDHFLPDEbjBD72+QGLMQWLM
QGLMP2fLP1HMQFDLQFDMQFHMQFHMQFHMQU3MFbLEErXCEbnAD72+QGLMQGLMQGPLPWnLOHHKOGvK
QFHMQFDLQFDLQVDLM27JGKvEFbDEErbCELu/DsC9QGLMQGLMP2TLPGvLN3PKMnvJLoTIKovII5fG
H5/GHKTFGarFFLLDEbjBD72+DcG8QWPMQGPMPmbLOm7KNXbKMX7JLYbIKY7HJJbGIJ3GG6XFFq3E
FLTDELrADsC9DMS6QWPMQGPMPWnLOHHKNHnJMIHIK4jIJ5DHIpnGHqDFGqfFFq/EErfBD7y+DsG8
DMW6Om3LN3TKM3vJLoPIKovIJZPHIZrGHaLFGKvEFLLDErfBELy/DsC9+AD1MX/JLYbIKI7HJJXH
H5/FG6XFF6vEFLHEErbCMn/IJ5HHI5jGH57GHKTFGKrEQFHMQFHMQFHMQFHMQFHMQFHMrnEVlgAA
ANx0Uk5TAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAea7K7gC4DLGZ58tN6QAIWZjKH9rlc
hyxBWn/1+4ovVFsDZ5u/5PvxSBBhDHj4kzKN6Lp8Kl8LARVKkfSzEBCt6nBwD1mZZi+j6jtN5PSY
b3RBEEqZbyQmlnrJ9746DmCsV2KkiohhL0h8glssQXaOlT81jJ2Ng4dYGRhMfYJ8lKhTYq1xdpyL
hYaFgH2PkXWYSwo7fX1pfpqKgZeJaWeHi0EMRYZ7ZoZ/YmiLcjYJABFPh3dthWYqBgAaYWYlAzMo
dlwAAACRSURBVBjTY2RgYGCUZoSA+/+AHAYGZkYFIGerD5C49RskwKYGkl0bAiQuM/5gZOBk1AYy
l0WDNZ39ysjAw2gEMeGkBSPj8Y+MDAKMFoxwsP8dYwiM3VwHJDYzMibCBMq7IHQBlJ81HcqoZ0QD
/egC89EF1qMLiDKuROb6AP0isQXOdXkO8hwDg9QeMNfhKZANAMoQHMFDMdtyAAAAAElFTkSuQmCC
EOF
    }
}

######################################################################
# WikiMapia

sub showmap_url_wikimapia {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $mapscale_scale = $args{mapscale_scale};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://wikimapia.org/s/#lat=%s&lon=%s&z=%d&m=w",
	$py, $px, $scale;
}

sub showmap_wikimapia {
    my(%args) = @_;
    my $url = showmap_url_wikimapia(%args);
    start_browser($url);
}

######################################################################
# historic maps on mc.bbbike.org
# previously wmflabs (historic maps berlin)
# also available now on https://historicmaps.toolforge.org/berlin/index.html --- but not linkable by geopos

sub showmap_url_historic_maps_berlin {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $mapscale_scale = $args{mapscale_scale};

    my $scale = 17 - log(($mapscale_scale)/3000)/log(2);
    sprintf "https://mc.bbbike.org/mc/?lon=%s&lat=%s&zoom=%d&num=2&mt0=e-historicmaps-210&mt1=bbbike-bbbike&eo-match-id=e-historicmaps", $px, $py, $scale;
}

sub showmap_historic_maps_berlin {
    my(%args) = @_;
    my $url = showmap_url_historic_maps_berlin(%args);
    start_browser($url);
}

######################################################################
# OpenStreetMap

sub showmap_url_openstreetmap {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $with_marker = $args{osmmarker};
    my $layers_spec = '';
    my $variant = $args{variant} || '';
    my $editor = $args{editor} || '';
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 19 if $scale > 19;

    if ($editor eq 'id') {
	sprintf "https://www.openstreetmap.org/edit?editor=id#map=%d/%f/%f", $scale, $py, $px;
    } elsif ($editor) {
	main::status_message("Unsupported OSM editor '$editor'", "die");
    } else {
	if ($variant eq 'de') {
	    $with_marker = 0; # not implemented on openstreetmap.de
	    $layers_spec = '&layers=B00TT';
	} elsif (defined $args{layers}) {
	    $layers_spec = "&layers=$args{layers}";
	}
	my $mpfx = $with_marker ? 'm' : ''; # "marker prefix"
	my $base_url = (  $variant eq 'de' ? 'https://openstreetmap.de/karte/'
			  :                  'http://www.openstreetmap.org/index.html'
		       );

	sprintf "$base_url?%slat=%s&%slon=%s&zoom=%d%s",
	    $mpfx, $py, $mpfx, $px, $scale, $layers_spec;
    }
}

sub showmap_openstreetmap {
    my(%args) = @_;
    my $url = showmap_url_openstreetmap(%args);
    start_browser($url);
}

sub showmap_openstreetmap_de {
    my(%args) = @_;
    my $url = showmap_url_openstreetmap(%args, variant => 'de');
    start_browser($url);
}

sub showmap_mapycz {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    my $lang = $Msg::lang =~ m{^(en|de)$} ? $1 : 'de';
    my $url = sprintf "https://%s.mapy.cz/turisticka?x=%s&y=%s&z=%d", $lang, $px, $py, $scale;
    start_browser($url);
}

sub showmap_url_cyclosm_at_osm {
    showmap_url_openstreetmap(@_, layers => 'Y');
}

sub showmap_cyclosm_at_osm {
    my(%args) = @_;
    my $url = showmap_url_cyclosm_at_osm(%args);
    start_browser($url);
}

sub showmap_url_openrailwaymap {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    sprintf "https://www.openrailwaymap.org/?lat=%s&lon=%s&zoom=%s", $py, $px, $scale;
}

sub showmap_openrailwaymap {
    my(%args) = @_;
    my $url = showmap_url_openrailwaymap(%args);
    start_browser($url);
}

sub showmap_url_openaerialmap {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    "https://map.openaerialmap.org/#/$px,$py,$scale";
}

sub showmap_openaerialmap {
    my(%args) = @_;
    my $url = showmap_url_openaerialmap(%args);
    start_browser($url);
}

sub show_openstreetmap_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_OpenStreetMap_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'OpenStreetMap',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'OpenStreetMap.org ' . ($lang eq 'de' ? '(mit Marker)' : '(with marker)'),
	 -command => sub { showmap_openstreetmap(osmmarker => 1, %args) },
	);
    $link_menu->command
	(-label => 'Cyclosm',
	 -command => sub {
	     my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
	     $scale = 17 if $scale > 17;
	     my $px = $args{px};
	     my $py = $args{py};
	     my $url = sprintf "https://www.cyclosm.org/#map=%d/%s/%s/cyclosm", $scale, $py, $px;
	     start_browser($url);
	 });
    $link_menu->command
	(-label => 'Cyclemap ' . ($lang eq 'de' ? '(mit Marker)' : '(with marker)'),
	 -command => sub { showmap_openstreetmap(osmmarker => 1, layers => 'C', %args) },
	);
    $link_menu->command
	(-label => 'Cycling QA',
	 -command => sub {
	     my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
	     $scale = 17 if $scale > 17;
	     my $px = $args{px};
	     my $py = $args{py};
	     my $url = sprintf "https://cycling-qa.lorenz.lu/#%.2f/%s/%s", $scale, $py, $px;
	     start_browser($url);
	 });
    $link_menu->command
	(-label => 'mapy.cz',
	 -command => sub { showmap_mapycz(%args) },
        );
    $link_menu->separator;
    $link_menu->command
	(-label => 'OpenStreetMap.de',
	 -command => sub { showmap_openstreetmap_de(%args) },
	);
    $link_menu->command
	(-label => 'OpenRailwayMap',
	 -command => sub { showmap_openrailwaymap(%args) },
	 );
    $link_menu->command
	(-label => 'OpenAerialMap',
	 -command => sub { showmap_openaerialmap(%args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'iD Editor',
	 -command => sub { showmap_openstreetmap(editor => 'id', %args) },
	);
    $link_menu->command
	(-label => 'Latest changes',
	 -command => sub {
	     my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
	     $scale = 17 if $scale > 17;
	     my $px = $args{px};
	     my $py = $args{py};
	     my $url = sprintf "https://tyrasd.github.io/latest-changes/#%d/%s/%s", $scale, $py, $px;
	     start_browser($url);
	 });
    $link_menu->separator;
    $link_menu->command
	(-label => ".de-Link kopieren", # XXX lang!
	 -command => sub { _copy_link(showmap_url_openstreetmap(variant => 'de', %args)) },
	);
    $link_menu->command
	(-label => ".org-Link mit Marker kopieren", # XXX lang!
	 -command => sub { _copy_link(showmap_url_openstreetmap(osmmarker => 1, %args)) },
	);
    $link_menu->command
	(-label => ".org-Link ohne Marker kopieren", # XXX lang!
	 -command => sub { _copy_link(showmap_url_openstreetmap(osmmarker => 0, %args)) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

sub _copy_link {
    my $url = shift;
    $main::show_info_url = $url;
    $main::show_info_url = $main::show_info_url if 0; # cease warning
    $main::top->SelectionOwn;
    $main::top->SelectionHandle; # calling this mysteriously solves the closure problem elsewhere...
    $main::top->SelectionHandle(\&main::handle_show_info_url);
}

######################################################################
# Map Compare (Geofabrik resp. bbbike.org)

sub showmap_url_mapcompare {
    my(%args) = @_;

    my $profile = delete $args{profile};
    my $maps = delete $args{maps};
    $maps = [$maps] if $maps && ref $maps ne 'ARRAY';

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    if ($map_compare_use_bbbike_org) {
	$scale = 18 if $scale > 18;
    }
    my $common_qs;
    if ($profile && $profile eq '__distinct_map_data') {
	my @maps = (qw(bvg-stadtplan bbbike-bbbike mapnik esri), $newest_berlin_aerial, qw(google-map nokia-map lgb-webatlas waze-world));
	my $maps_qs = do { my $i = 0; join('&', map { "mt".($i++)."=".$_ } @maps) };
	$common_qs = 'num=10&' . $maps_qs;
    } elsif ($maps) {
	$common_qs = "num=" . scalar(@$maps);
	for my $map_i (0 .. $#$maps) {
	    my $map = $maps->[$map_i];
	    $common_qs .= "&mt$map_i=$map";
	}
    } else {
	my $map0 = $map_compare_use_bbbike_org ? 'google-hybrid' : 'googlehybrid';
	#my $map1 = 'tah';
	my $map1 = 'mapnik';
	#my $map1 = 'cyclemap';
	if ($profile) {
	    $common_qs = "profile=$profile";
	} else {
	    $common_qs = sprintf 'mt0=%s&mt1=%s', $map0, $map1;
	    if ($map_compare_use_bbbike_org) {
		$common_qs .= '&num=2';
	    }
	}
    }
    $common_qs .= sprintf '&lat=%s&lon=%s&zoom=%d', $py, $px, $scale;
    if ($map_compare_use_bbbike_org) {
	'http://mc.bbbike.org/mc/?' . $common_qs;
    } else {
	'http://tools.geofabrik.de/mc/?' . $common_qs;
    }
}

sub showmap_mapcompare { start_browser(showmap_url_mapcompare(@_)) }

sub show_mapcompare_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_MapCompare_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'Map Compare',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'Newest one only',
	 -command => sub {
	     showmap_mapcompare
		 (maps => [$newest_berlin_aerial],
		  %args,
		 )
	     },
	);
    $link_menu->command
	(-label => 'Newest eight only',
	 -command => sub {
	     # note: berlin-historical-2020 and lgb-satellite-color is
	     # the same imagery from 2020, but the lgb version covers
	     # whole of Brandenburg
	     showmap_mapcompare
		 (maps => [qw(
				 berlin-historical-2024
				 berlin-historical-2023
				 berlin-historical-2022
				 berlin-historical-2021
				 lgb-satellite-color
				 berlin-historical-2019
				 berlin-historical-2018
				 google-satellite
			    )],
		  %args,
		 )
	     },
	);
    $link_menu->command
	(-label => "Link kopieren",
	 -command => sub { _copy_link(showmap_url_mapcompare(%args)) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# BVG-Stadtplan (via mc.bbbike.org)

sub showmap_url_bvgstadtplan {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = int(17 - log(($args{mapscale_scale})/3000)/log(2) + 0.5);
    my $variant = $args{variant} || 'bvg-stadtplan';

    if ($variant eq 'bbbikeleaflet') {
        sprintf "http://localhost/bbbike/cgi/bbbikeleaflet.cgi?mlat=%s&mlon=%s&zoom=%d&bm=BVG", $py, $px, $scale;
    } else {
	sprintf "http://mc.bbbike.org/mc/?lon=%s&lat=%s&zoom=%d&num=1&mt0=%s", $px, $py, $scale, $variant;
    }
}

sub showmap_bvgstadtplan {
    my(%args) = @_;
    my $url = showmap_url_bvgstadtplan(%args);
    start_browser($url);
}

sub show_bvgstadtplan_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_BvgStadtplan_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'BVG',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'BVG (details)',
	 -command => sub { showmap_bvgstadtplan(%args, variant => 'bvg-stadtplan-10') },
	);
    if ($main::devel_host) {
	$link_menu->command
	    (-label => "BVG on bbbikeleaflet",
	     -command => sub { showmap_bvgstadtplan(%args, variant => 'bbbikeleaflet') },
	    );
    }
    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# S-Bahn Berlin (via mc.bbbike.org)

sub showmap_url_sbahnberlin {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = int(17 - log(($args{mapscale_scale})/3000)/log(2) + 0.5);
    sprintf "http://mc.bbbike.org/mc/?lon=%s&lat=%s&zoom=%d&num=1&mt0=sbahnberlin-standard", $px, $py, $scale;
}

sub showmap_sbahnberlin {
    my(%args) = @_;
    my $url = showmap_url_sbahnberlin(%args);
    start_browser($url);
}

######################################################################
# dein-plan, Pharus

sub showmap_url_deinplan_leaflet {
    my(%args) = @_;
    my $scale = int(17 - log(($args{mapscale_scale})/2863)/log(2) + 0.5);
    if ($scale > 16) { $scale = 16 }
    'http://m.deinplan.de/map.php#' . $scale . '/' . $args{py} . '/' . $args{px};
}

sub showmap_url_deinplan_web {
    my(%args) = @_;
    if (1) {
	require Karte::Deinplan;
	my($sx,$sy) = split /,/, $args{coords};
	$Karte::Deinplan::obj = $Karte::Deinplan::obj if 0; # cease -w
	my($x, $y) = map { int } $Karte::Deinplan::obj->standard2map($sx,$sy);
	#my $urlfmt = "http://www.dein-plan.de/?location=|berlin|%d|%d";
	my $urlfmt = "http://www.berliner-stadtplan.com/adresse/karte/berlin/pos/%d,%d.html";
	sprintf($urlfmt, $x, $y);
    } else {
	# The x_wgs/y_wgs styled links do not work anymore (since Summer 2014),
	# but would be preferred over the approximate pixel method above.
	require Karte::Polar;
	require URI::Escape;
	my($px, $py) = ($args{px}, $args{py});
	my $y_wgs = sprintf "%.2f", (Karte::Polar::ddd2dmm($py))[1];
	my $x_wgs = sprintf "%.2f", (Karte::Polar::ddd2dmm($px))[1];
	my $message = $args{street};
	if (!$message) {
	    $message = " "; # avoid empty message
	}
	$message =~ s{[/?]}{ }g;
	$message = URI::Escape::uri_escape($message);
	my $urlfmt = "http://www.berliner-stadtplan.com/topic/bln/str/message/%s/x_wgs/%s/y_wgs/%s/size/800x600/from/bbbike.html";
	sprintf($urlfmt, $message, $x_wgs, $y_wgs);
    }
}
    
sub showmap_deinplan_leaflet {
    my(%args) = @_;
    my $url = showmap_url_deinplan_leaflet(%args);
    start_browser($url);
}

sub showmap_deinplan_web {
    my(%args) = @_;
    my $url = showmap_url_deinplan_web(%args);
    start_browser($url);
}

######################################################################
# bikemap.de

sub showmap_url_bikemapnet {
    my(%args) = @_;

    my $lang = $Msg::lang || 'de';
    $lang = 'en' if $lang !~ m{^(de|en)$}; # what are the supported languages?

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    sprintf "https://www.bikemap.net/en/search/?zoom=%d&center=%s%%2C%s",
	$scale, $px, $py;

}

sub showmap_bikemapnet {
    my(%args) = @_;
    my $url = showmap_url_bikemapnet(%args);
    start_browser($url);
}

######################################################################
# CriticalMaps

sub showmap_url_criticalmaps {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    sprintf "https://www.criticalmaps.net/map#%d/%s/%s",
	$scale, $py, $px;
}

sub showmap_criticalmaps {
    my(%args) = @_;
    my $url = showmap_url_criticalmaps(%args);
    start_browser($url);
}

######################################################################
# Geocaching.com

sub showmap_url_geocaching {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
#    sprintf "http://www.geocaching.com/seek/gmnearest.aspx?lat=%s&lng=%s&zm=%d&mt=m",
#	$py, $px, $scale;
    sprintf "http://www.geocaching.com/map/default.aspx?lat=%s&lng=%s&zm=%d&mt=m&#?ll=%s,%s&z=%d",
	($py, $px, $scale) x 2;
}

sub showmap_geocaching {
    my(%args) = @_;
    my $url = showmap_url_geocaching(%args);
    start_browser($url);
}

######################################################################
# Bing

sub showmap_url_bing_birdseye {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.bing.com/maps/default.aspx?v=2&cp=%s~%s&style=o&lvl=%s&sp=Point.%s_%s____",
	$py, $px, $scale, $py, $px;
}

sub showmap_bing_birdseye {
    my(%args) = @_;
    my $url = showmap_url_bing_birdseye(%args);
    start_browser($url);
}

sub showmap_url_bing_street {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.bing.com/maps/?cp=%s~%s&lvl=%.1f&trfc=1",
	$py, $px, $scale;
}

sub showmap_bing_street {
    my(%args) = @_;
    my $url = showmap_url_bing_street(%args);
    start_browser($url);
}

sub show_bing_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_Bing_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'Bing',
			     -tearoff => 0);
    $link_menu->command
	(-label => "Bird's eye",
	 -command => sub { showmap_bing_birdseye(%args) },
	);
    $link_menu->command
	(-label => "Street-Link kopieren",
	 -command => sub { _copy_link(showmap_url_bing_street(%args)) },
	);
    $link_menu->command
	(-label => "Bird's eye-Link kopieren",
	 -command => sub { _copy_link(showmap_url_bing_birdseye(%args)) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# tomtom
sub showmap_url_tomtom {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://plan.tomtom.com/de/?p=%s,%s,%.2fz", $py, $px, $scale;
}

sub showmap_tomtom {
    my(%args) = @_;
    my $url = showmap_url_tomtom(%args);
    start_browser($url);
}

######################################################################
# Waze

sub showmap_url_waze {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    sprintf 'https://www.waze.com/en/live-map/directions?to=ll.%s%%2C%s', $py, $px;
}

sub showmap_waze {
    my(%args) = @_;
    my $url = showmap_url_waze(%args);
    start_browser($url);
}

######################################################################
# DAF (Deutsches Architektur-Forum)

sub showmap_url_daf_berlin {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.dafmap.de/d/berlin.html?center=%s+%s&zoom=%d", $py, $px, $scale;
}

sub showmap_daf_berlin {
    my(%args) = @_;
    my $url = showmap_url_daf_berlin(%args);
    start_browser($url);
}

######################################################################
# Architektur Urbanistik (via umap)

sub showmap_url_architektur_urbanistik {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://umap.openstreetmap.fr/de/map/berliner-architektur-und-urbanistik_945116#%d/%s/%s", $scale, $py, $px;
}

sub showmap_architektur_urbanistik {
    my(%args) = @_;
    my $url = showmap_url_architektur_urbanistik(%args);
    start_browser($url);
}

######################################################################
# FIS-Broker

sub showmap_url_fis_broker {
    my(%args) = @_;
    my $mapId = delete $args{mapId} || 'k5_farbe@senstadt';
    my($x0,$y0) = _wgs84_to_utm33U($args{py0}, $args{px0});
    my($x1,$y1) = _wgs84_to_utm33U($args{py1}, $args{px1});
    sprintf 'https://fbinter.stadt-berlin.de/fb/index.jsp?loginkey=zoomStart&mapId=%s&bbox=%d,%d,%d,%d', $mapId, $x0, $y0, $x1, $y1;
}

sub showmap_fis_broker {
    my(%args) = @_;
    my $url = showmap_url_fis_broker(%args);
    start_browser($url);
}

sub show_fis_broker_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_FisBroker_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'FIS-Broker',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'Fahrradwege (Stand 2017)',
	 -command => sub { showmap_fis_broker(mapId => 'k_radwege@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Radverkehrsanlagen (Stand 2013)',
	 -command => sub { showmap_fis_broker(mapId => 'wmsk_radverkehrsanlagen@senstadt', %args) },
	);
    $link_menu->command
	# früher (bis 2024): 'Übergeordnetes Fahrradroutennetz (Stand 2014)', 'k_fahrradroutennetz@senstadt'
	(-label => 'Radverkehrsnetz',
	 -command => sub { showmap_fis_broker(mapId => 'k_radverkehrsnetz@senstadt', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Verkehrsmengen 2019',
	 -command => sub { showmap_fis_broker(mapId => 'k_vmengen2019@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Verkehrsmengen 2014',
	 -command => sub { showmap_fis_broker(mapId => 'wmsk_07_01verkmeng2014@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Übergeordnetes Straßennetz',
	 -command => sub { showmap_fis_broker(mapId => 'verkehr_strnetz@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Straßenbefahrung 2014',
	 -command => sub { showmap_fis_broker(mapId => 'k_StraDa@senstadt', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'FNP',
	 -command => sub { showmap_fis_broker(mapId => 'fnp_ak@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Bebauungspläne',
	 -command => sub { showmap_fis_broker(mapId => 'bplan@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke (INSPIRE)',
	 -command => sub { showmap_fis_broker(mapId => 'CP_ALKIS@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke (ALKIS)',
	 -command => sub { showmap_fis_broker(mapId => 'wmsk_alkis@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke (ALKIS) (via strassenraumkarte)',
	 -command => sub { showmap_strassenraumkarte(%args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Grünanlagen',
	 -command => sub { showmap_fis_broker(mapId => 'gris_oeffgruen@senstadt', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Orthophotos 2024',
	 -command => sub { showmap_fis_broker(mapId => 'k_luftbild2024_true_rgbi@senstadt', %args) },
	);
    $link_menu->command
	(-label => 'Orthophotos 2023',
	 -command => sub { showmap_fis_broker(mapId => 'k_luftbild2023_true_rgbi@senstadt', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => ($lang eq 'de' ? "Link kopieren" : 'Copy link'),
	 -command => sub { _copy_link(showmap_url_fis_broker(%args)) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# gdi.berlin.de (z.B. Radverkehrsnetz Berlin)

sub showmap_url_gdi_berlin {
    my(%args) = @_;

    my $layerids = {
	k5_farbe           => 'hintergrund_k5_farbe',
	radverkehrsanlagen => 'hintergrund_k5_grau,radverkehrsanlagen:c_bussonderfahrstreifen,radverkehrsanlagen:b_radverkehrsanlagen,radverkehrsanlagen:a_verkehrszeichen',
        radverkehrsnetz    => 'hintergrund_k5_grau,radverkehrsnetz:untersuchungsbereiche,radverkehrsnetz:stadtgruen,radverkehrsnetz:radverkehrsnetz',
	fahrradstrassen    => 'hintergrund_k5_grau,fahrradstrassen:fahrradstrassen',
	dtvw2019           => 'hintergrund_k5_grau,verkehrsmengen_2019:dtvw2019lkw,verkehrsmengen_2019:dtvw2019kfz',
	dtv2019            => 'hintergrund_k5_grau,ua_verkehrsmengen_2019:verkehrsmengen_2019',
	dtv2014            => 'hintergrund_k5_grau,ua_verkehrsmengen_2014:verkehrsmengen_2014',
	ueberstrnetz       => 'hintergrund_k5_grau,strnetz:uebergeordnetes_strnetz',
	## der volle Layer-Satz wäre der folgende, ist aber zu lang in einem GET-Request:
	#strbefahrung2014   => 'hintergrund_k5_grau,strassenbefahrung:cm_fahrbahn,strassenbefahrung:cl_gehweg,strassenbefahrung:ck_parkflaeche,strassenbefahrung:cj_fussgaengerzone,strassenbefahrung:ci_oeffentlicher_platz,strassenbefahrung:ch_radweg,strassenbefahrung:cg_baustelle,strassenbefahrung:cf_trennstreifen,strassenbefahrung:ce_gruenflaeche,strassenbefahrung:cd_rampe,strassenbefahrung:cc_treppe,strassenbefahrung:cb_haltestellenwartebereich,strassenbefahrung:ca_haltebereich_bus,strassenbefahrung:bz_gleiskoerper_strab,strassenbefahrung:by_gehwegueberfahrt,strassenbefahrung:bx_fahrbahnschwelle,strassenbefahrung:bw_aufmerksamkeitsfeld,strassenbefahrung:bv_springbrunnen_zierbrunnen,strassenbefahrung:bu_recycling_container,strassenbefahrung:bu1_kleinbauten_sondernutzung,strassenbefahrung:bt_kabelschacht,strassenbefahrung:bs_induktionsschleife,strassenbefahrung:br_fahrgastunterstand,strassenbefahrung:bq_fahrradstaender,strassenbefahrung:bp_fahrbahnmarkierung_flaeche,strassenbefahrung:bo_denkmal,strassenbefahrung:bn_baumscheibe,strassenbefahrung:bm_zugangsbauwerk,strassenbefahrung:bl_strassenentwaesserungsrinne,strassenbefahrung:bk_strassenbegrenzung,strassenbefahrung:bj_sitzbank,strassenbefahrung:bi_schranke,strassenbefahrung:bh_mauer,strassenbefahrung:bg_leitplanke,strassenbefahrung:bf_gelaender,strassenbefahrung:be_fahrbahnmarkierunglinie,strassenbefahrung:bd_bordstein,strassenbefahrung:bc_aufmerksamkeitsstreifen,strassenbefahrung:bb_verkehrsschutzgitter,strassenbefahrung:ba_telefonzelle_telefonstele,strassenbefahrung:az_taxirufsaeule,strassenbefahrung:ay_streugutbehaelter,strassenbefahrung:ax_strassensinkkasten,strassenbefahrung:aw_spielgeraet,strassenbefahrung:av_poller,strassenbefahrung:au_parkscheinautomat,strassenbefahrung:at_mast_lsa,strassenbefahrung:as_mast,strassenbefahrung:ar_kanaldeckel,strassenbefahrung:ar1_kabelkasten,strassenbefahrung:aq_hydrant,strassenbefahrung:ap_handsteuergeraet_lsa,strassenbefahrung:ao_gebaeudeeingang,strassenbefahrung:an_fahrbahnmarkierung_piktogramm,strassenbefahrung:am_fahnenmast,strassenbefahrung:al_durchfahrtshoehe,strassenbefahrung:ak_briefkasten,strassenbefahrung:aj_anlegestelle,strassenbefahrung:ai_anforderungstaster_radverkehr,strassenbefahrung:ah_abfallbehaelter_muellbox,strassenbefahrung:ag_werbesaeule,strassenbefahrung:af_wasserpumpen_brunnen,strassenbefahrung:ae_viz_infotafel,strassenbefahrung:ad_uhr,strassenbefahrung:ac_trinkwasserbrunnen_wasserspender,strassenbefahrung:ab_touchpoint,strassenbefahrung:aa_verkehrszeichen',
	## auf straßenrelevante Dinge reduziert:
	strbefahrung2014   => 'hintergrund_k5_grau,strassenbefahrung:cm_fahrbahn,strassenbefahrung:cl_gehweg,strassenbefahrung:ck_parkflaeche,strassenbefahrung:cj_fussgaengerzone,strassenbefahrung:ci_oeffentlicher_platz,strassenbefahrung:ch_radweg,strassenbefahrung:cg_baustelle,strassenbefahrung:cf_trennstreifen,strassenbefahrung:ce_gruenflaeche,strassenbefahrung:cd_rampe,strassenbefahrung:cc_treppe,strassenbefahrung:ca_haltebereich_bus,strassenbefahrung:bz_gleiskoerper_strab,strassenbefahrung:bx_fahrbahnschwelle,strassenbefahrung:bw_aufmerksamkeitsfeld,strassenbefahrung:bs_induktionsschleife,strassenbefahrung:bq_fahrradstaender,strassenbefahrung:bp_fahrbahnmarkierung_flaeche,strassenbefahrung:bm_zugangsbauwerk,strassenbefahrung:bk_strassenbegrenzung,strassenbefahrung:bi_schranke,strassenbefahrung:be_fahrbahnmarkierunglinie,strassenbefahrung:bd_bordstein,strassenbefahrung:bc_aufmerksamkeitsstreifen,strassenbefahrung:bb_verkehrsschutzgitter,strassenbefahrung:at_mast_lsa,strassenbefahrung:ap_handsteuergeraet_lsa,strassenbefahrung:ai_anforderungstaster_radverkehr',
	## es existieren mehrere Layer: "gestoert" und "ungestoert", aber oberflächlich gesehen sehen sie gleich aus
	oepnv              => 'hintergrund_k5_grau,oepnv_ungestoert:d_tramlinien,oepnv_ungestoert:c_buslinien,oepnv_ungestoert:b_tramstopp,oepnv_ungestoert:a_busstopp',
	fnp2015            => 'hintergrund_k5_grau,fnp_2015:0,fnp_2015:1',
	fnpaktuell         => 'hintergrund_k5_grau,fnp_ak:0',
	bplaene            => 'hintergrund_k5_grau,bplan:2,bplan:3,bplan:6,bplan:7',
	fluralkis          => 'hintergrund_k5_farbe,alkis_flurstuecke:flurstuecke',
	flurinspire        => 'hintergrund_k5_farbe,cp_alkis:CP.CadastralZoning,cp_alkis:CP.CadastralParcel',
	gruenanlagen       => 'hintergrund_k5_grau,gruenanlagen:spielplaetze,gruenanlagen:gruenanlagen',
	ortho2024          => 'hintergrund_k5_grau,truedop_2024:truedop_2024',
	ortho2023          => 'hintergrund_k5_grau,truedop_2023:truedop_2023',
    }->{$args{layers}};
    if (!$layerids) {
	main::status_message('error', 'no layers found or invalid layers');
	return;
    }
    my $number_layerids = scalar split /,/, $layerids;
    my $visibility = join ',', ("true") x $number_layerids;
    my $transparency = join ',', ("0") x $number_layerids;

    my($x,$y) = _wgs84_to_utm33U($args{py}, $args{px});
    my $scale = sub {
	local $_ = $args{mapscale_scale};
	if    ($_ > 500_000*3/4) { 0 }
	elsif ($_ > 250_000*3/4) { 1 }
	elsif ($_ > 100_000*3/4) { 2 }
	elsif ($_ >  50_000*3/4) { 3 }
	elsif ($_ >  25_000*3/4) { 4 }
	elsif ($_ >  10_000*3/4) { 5 }
	elsif ($_ >   5_000*3/4) { 6 }
	elsif ($_ >   2_500*3/4) { 7 }
	elsif ($_ >   1_000*3/4) { 8 }
	else                     { 9 }
    }->();
    sprintf 'https://gdi.berlin.de/viewer/main/?Map/layerIds=%s&visibility=%s&transparency=%s&Map/center=[%s,%s]&Map/zoomLevel=%d', $layerids, $visibility, $transparency, $x, $y, $scale;
}

sub showmap_gdi_berlin {
    my(%args) = @_;
    my $url = showmap_url_gdi_berlin(%args);
    start_browser($url);
}

sub show_gdi_berlin_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_GeoPortalBerlin_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'Geoportal Berlin',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'Radverkehrsanlagen',
	 -command => sub { showmap_gdi_berlin(layers => 'radverkehrsanlagen', %args) },
        );
    $link_menu->command
	(-label => 'Radverkehrsnetz',
	 -command => sub { showmap_gdi_berlin(layers => 'radverkehrsnetz', %args) },
	);
    $link_menu->command
	(-label => 'Fahrradstraßen',
	 -command => sub { showmap_gdi_berlin(layers => 'fahrradstrassen', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Verkehrsmengen 2019 (DTVw)',
	 -command => sub { showmap_gdi_berlin(layers => 'dtvw2019', %args) },
	);
    $link_menu->command
	(-label => 'Verkehrsmengen 2019',
	 -command => sub { showmap_gdi_berlin(layers => 'dtv2019', %args) },
	);
    $link_menu->command
	(-label => 'Verkehrsmengen 2014',
	 -command => sub { showmap_gdi_berlin(layers => 'dtv2014', %args) },
	);
    $link_menu->command
	(-label => 'Übergeordnetes Straßennetz',
	 -command => sub { showmap_gdi_berlin(layers => 'ueberstrnetz', %args) },
	);
    $link_menu->command
	(-label => 'Straßenbefahrung 2014',
	 -command => sub { showmap_gdi_berlin(layers => 'strbefahrung2014', %args) },
	);
    $link_menu->command
	(-label => 'ÖPNV-Netz (Bus und Tram)',
	 -command => sub { showmap_gdi_berlin(layers => 'oepnv', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'FNP 2015',
	 -command => sub { showmap_gdi_berlin(layers => 'fnp2015', %args) },
	);
    $link_menu->command
	(-label => 'FNP (aktuelle Bearbeitung)',
	 -command => sub { showmap_gdi_berlin(layers => 'fnpaktuell', %args) },
	);
    $link_menu->command
	(-label => 'Bebauungspläne',
	 -command => sub { showmap_gdi_berlin(layers => 'bplaene', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke (INSPIRE)',
	 -command => sub { showmap_gdi_berlin(layers => 'flurinspire', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke (ALKIS)',
	 -command => sub { showmap_gdi_berlin(layers => 'fluralkis', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Grünanlagen',
	 -command => sub { showmap_gdi_berlin(layers => 'gruenanlagen', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Orthophotos 2024',
	 -command => sub { showmap_gdi_berlin(layers => 'ortho2024', %args) },
	);
    $link_menu->command
	(-label => 'Orthophotos 2023',
	 -command => sub { showmap_gdi_berlin(layers => 'ortho2023', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => ($lang eq 'de' ? "Link kopieren" : 'Copy link'),
	 -command => sub { _copy_link(showmap_url_gdi_berlin(layers => 'k5_farbe', %args)) },
     );

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# strassenraumkarte (using mapproxy.codefor.de)

sub showmap_url_strassenraumkarte {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://strassenraumkarte.osm-berlin.org/mapproxy_demo_map/?url=https://mapproxy.codefor.de/tiles/1.0.0/alkis_30/mercator/{z}/{x}/{y}.png#%s/%s/%s", $scale, $py, $px;
}

sub showmap_strassenraumkarte {
    my(%args) = @_;
    my $url = showmap_url_strassenraumkarte(%args);
    start_browser($url);
}

######################################################################
# Rapid Editor
sub showmap_url_rapid {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $dateFrom = $args{dateFrom};
    if ($dateFrom) {
	$dateFrom = _rel_to_abs_date($dateFrom);
    }
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    # All features documented in https://github.com/facebook/Rapid/blob/95f7965dc2a346b851280b6e72f11eaf2aadc5db/API.md?plain=1#L24
    # Actually the intent is to switch off the osm data layer, but there does not seem to exist an option for this.
    my $disable_features = 'points,traffic_roads,service_roads,paths,buildings,building_parts,indoor,landuse,boundaries,water,rail,pistes,aerialways,power,past_future,others';
    sprintf('https://rapideditor.org/edit#map=%.2f/%s/%s', $scale, $py, $px)
	. '&datasets=fbRoads,msBuildings&disable_features='.$disable_features
	. "&photo_dates=${dateFrom}_"
	. '&photo_overlay=mapillary'
	# don't specify background; Rapid chooses the newest/best aerial # . "&background=Berlin-$newest_berlin_aerial_year"
	;
}

sub showmap_rapid {
    my(%args) = @_;
    my $url = showmap_url_rapid(%args);
    start_browser($url);
}

######################################################################
# Mapillary

sub showmap_url_mapillary {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $dateFrom = $args{dateFrom};
    if ($dateFrom) {
	$dateFrom = _rel_to_abs_date($dateFrom);
    }
    my $panos = $args{panos};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf("https://www.mapillary.com/app/?lat=%s&lng=%s&z=%d", $py, $px, $scale)
	. ($dateFrom ? "&dateFrom=$dateFrom" : "")
	. ($panos    ? "&panos=true" : "");
}

sub showmap_mapillary {
    my(%args) = @_;
    my $url = showmap_url_mapillary(%args);
    start_browser($url);
}

sub show_mapillary_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_Mapillary_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'Mapillary',
			     -tearoff => 0);
    if ($args{last_checked} && $args{last_checked} =~ m{^(\d{4})-(\d{2})-(\d{2})}) {
	my($y,$m,$d) = ($1,$2,$3);
	require Time::Local;
	require POSIX;
	my $epoch = Time::Local::timelocal(0,0,0,$d,$m-1,$y); $epoch += 86400; # roughly next day, may be wrong in DST switches
	my $date_from = POSIX::strftime('%Y-%m-%d', localtime($epoch));
	$link_menu->command
	    (-label => "Fresh Mapillary (since $date_from)",
	     -command => sub { showmap_mapillary(dateFrom => $date_from, %args) },
	    );
    }
    $link_menu->command
	(-label => 'Fresh Mapillary (< 1 week)',
	 -command => sub { showmap_mapillary(dateFrom => '-1week', %args) },
	);
    $link_menu->command
	(-label => 'Fresh Mapillary (< 1 month)',
	 -command => sub { showmap_mapillary(dateFrom => '-1month', %args) },
	);
    $link_menu->command
	(-label => 'Fresh Mapillary (< 3 months)',
	 -command => sub { showmap_mapillary(dateFrom => '-3month', %args) },
	);
    $link_menu->command
	(-label => 'Fresh Mapillary (< 1 year)',
	 -command => sub { showmap_mapillary(dateFrom => '-1year', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => '360° imagery only',
	 -command => sub { showmap_mapillary(panos => 1, %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => 'Mapillary on Rapid (all)',
	 -command => sub { showmap_rapid(%args) },
	);
    $link_menu->command
	(-label => 'Mapillary on Rapid (< 1 month)',
	 -command => sub { showmap_rapid(dateFrom => '-1month', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => "Link kopieren",
	 -command => sub { _copy_link(showmap_url_mapillary(%args)) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# KartaView (former OpenStreetCam)

sub showmap_url_kartaview {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://kartaview.org/map/@%s,%s,%dz", $py, $px, $scale;
}

sub showmap_kartaview {
    my(%args) = @_;
    my $url = showmap_url_kartaview(%args);
    start_browser($url);
}

######################################################################
# Mapilio

sub showmap_url_mapilio {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf 'https://mapilio.com/app?lat=%s&lng=%s&zoom=%f', $py, $px, $scale;
}

sub showmap_mapilio {
    my(%args) = @_;
    my $url = showmap_url_mapilio(%args);
    start_browser($url);
}

######################################################################
# berliner-linien.de
sub showmap_url_berlinerlinien {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 25 - log(($args{mapscale_scale})/2100)/log(1.21); # XXX rough formula
    #sprintf "https://www.berliner-linien.de/BL/pages/netz.html?netz=VBB&zoom=%d&prio=400&X=%s&Y=%s", $scale, $px, $py;
    sprintf "https://www.berliner-linien.de/?netz=VBB&zoom=%d&prio=400&X=%s&Y=%s", $scale, $px, $py;
}

sub showmap_berlinerlinien {
    my(%args) = @_;
    my $url = showmap_url_berlinerlinien(%args);
    start_browser($url);
}

######################################################################
# BKG (Bundesamt für Kartographie und Geodäsie)

sub showmap_url_bkg {
    my(%args) = @_;
    my($x,$y) = _wgs84_to_utm_ze($args{py}, $args{px}, 32);
    my $scale = 14 - log(($args{mapscale_scale})/1111)/log(2); # XXX very rough, works for smaller mapscale_scale numbers
    $scale = 15 if $scale > 15;
    sprintf 'http://sg.geodatenzentrum.de/web_bkg_webmap/applications/bkgmaps/minimal.html?zoom=%.f&lat=%f&lon=%f', $scale, $y, $x;
}

sub showmap_bkg {
    my(%args) = @_;
    my $url = showmap_url_bkg(%args);
    start_browser($url);
}

######################################################################
# F4map
sub showmap_url_f4map {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 21 if $scale > 21;
    sprintf 'https://demo.f4map.com/#lat=%s&lon=%s&zoom=%d', $py, $px, $scale;
}

sub showmap_f4map {
    my(%args) = @_;
    my $url = showmap_url_f4map(%args);
    start_browser($url);
}

######################################################################
# Sentinel Hub
sub showmap_url_sentinelhub {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 16 if $scale > 16;
    ## Old URL, redirects now to browser.dataspace.copernicus.eu
    #sprintf 'https://apps.sentinel-hub.com/sentinel-playground/?source=S2&lat=%f&lng=%f&zoom=%d&preset=1-NATURAL-COLOR&layers=B01,B02,B03&maxcc=31&gain=1.0&gamma=1.0', $py, $px, $scale;
    sprintf 'https://browser.dataspace.copernicus.eu/?zoom=%d&lat=%f&lng=%f&themeId=DEFAULT-THEME', $scale, $py, $px;
}

sub showmap_sentinelhub {
    my(%args) = @_;
    my $url = showmap_url_sentinelhub(%args);
    start_browser($url);
}

######################################################################
# hierbautberlin.de
sub showmap_url_hierbautberlin {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://hierbautberlin.de/map?lat=%s&lng=%s&zoom=%.1f", $py, $px, $scale;
}

sub showmap_hierbautberlin {
    my(%args) = @_;
    my $url = showmap_url_hierbautberlin(%args);
    start_browser($url);
}

######################################################################
# VIZ Berlin

sub showmap_url_viz {
    my(%args) = @_;
    my($x,$y) = _wgs84_to_utm33U($args{py}, $args{px});
    my $scale = 11; # XXX hardcoded for now
    # note: when bookmarking then center has additional [...], but it works also without (and less problems regarding escaping or org-mode links)
    sprintf 'https://viz.berlin.de/site/_masterportal/berlin/index.html?Map/layerIds=basemap_raster_farbe,Verkehrslage,Baustellen_OCIT&visibility=true,true,true&transparency=40,0,0&Map/center=%d,%d&Map/zoomLevel=%d', $x, $y, $scale;
}

sub showmap_viz {
    my(%args) = @_;
    my $url = showmap_url_viz(%args);
    start_browser($url);
}

######################################################################
# bb-viewer (BrandenburgViewer, STRASSENNETZVIEWER)

sub showmap_url_bbviewer {
    my(%args) = @_;
    my $layers = delete $args{layers} || 'verkehrsstaerke';
    my $layerids = {
		    'verkehrsstaerke-2015' => '10021,2062,22,10,11,7,8,5,6',
		    'verkehrsstaerke-2021' => '10021,2062,10,7,5,11,8,6,33',
		    flurstuecke     => '291-bg,9001,9000,159,149',
		   }->{$layers};
    my $baseurl = {
		   'verkehrsstaerke-2015' => 'https://viewer.brandenburg.de/strassennetz/',
		   'verkehrsstaerke-2021' => 'https://viewer.brandenburg.de/strassennetz/',
		   flurstuecke     => 'https://bb-viewer.geobasis-bb.de/',
		  }->{$layers};
    die "Unhandled layers value '$layers'" if !$layerids || !$baseurl;

    my $number_layerids = scalar split /,/, $layerids;
    my $visibility = join ',', ("true") x $number_layerids;
    my $transparency = join ',', ("0") x $number_layerids;
    my $rooturl = "$baseurl?layerIDs=$layerids&visibility=$visibility&transparency=$transparency&";
    my($x,$y) = _wgs84_to_utm33U($args{py}, $args{px});
    my $scale = 7 - log(($args{mapscale_scale})/12000)/log(2);
    $scale = 15 if $scale > 15;
    sprintf "${rooturl}center=%d,%d&zoomlevel=%d", $x, $y, $scale;
}

sub showmap_bbviewer {
    my(%args) = @_;
    my $url = showmap_url_bbviewer(%args);
    start_browser($url);
}

sub show_bbviewer_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    my $w = $args{widget};
    my $menu_name = __PACKAGE__ . '_BBViewer_Menu';
    if (Tk::Exists($w->{$menu_name})) {
	$w->{$menu_name}->destroy;
    }
    my $link_menu = $w->Menu(-title => 'bb-viewer',
			     -tearoff => 0);
    $link_menu->command
	(-label => 'Verkehrsstärke 2015',
	 -command => sub { showmap_bbviewer(layers => 'verkehrsstaerke-2015', %args) },
	);
    $link_menu->command
	(-label => 'Flurstücke',
	 -command => sub { showmap_bbviewer(layers => 'flurstuecke', %args) },
	);
    $link_menu->separator;
    $link_menu->command
	(-label => ($lang eq 'de' ? "Link kopieren" : 'Copy link'),
	 -command => sub { _copy_link(showmap_url_bbviewer(%args, layers => 'verkehrsstaerke-2021')) },
	);

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

######################################################################
# Radverkehrsatlas

sub showmap_url_radverkehrsatlas {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://radverkehrsatlas.de/regionen/bb-kampagne?v=1&map=%.1f/%s/%s", $scale, $py, $px;
}

sub showmap_radverkehrsatlas {
    my(%args) = @_;
    my $url = showmap_url_radverkehrsatlas(%args);
    start_browser($url);
}

######################################################################
# travic

sub showmap_url_travic {
    my(%args) = @_;
    my($x, $y) = _wgs84_to_pseudo_mercator($args{px}, $args{py});
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://travic.app/?z=%d&x=%.1f&y=%.1f", $scale, $x, $y;
}

sub showmap_travic {
    my(%args) = @_;
    my $url = showmap_url_travic(%args);
    start_browser($url);
}

######################################################################
# windy

sub showmap_url_windy {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    my $lang = defined $Msg::lang && $Msg::lang =~ m{^(en|de)$} ? $Msg::lang : 'de'; # XXX allow more languages if supported by Windy
    sprintf "https://www.windy.com/%s/?radar,%f,%f,%d", $lang, $py, $px, $scale;
}

sub showmap_windy {
    my(%args) = @_;
    my $url = showmap_url_windy(%args);
    start_browser($url);
}

######################################################################
# Overture Maps

sub showmap_url_overture_maps {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 16 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://explore.overturemaps.org/#%.2f/%.5f/%.5f", $scale, $py, $px;
}

sub showmap_overture_maps {
    my(%args) = @_;
    my $url = showmap_url_overture_maps(%args);
    start_browser($url);
}

######################################################################

sub show_all_traffic_maps {
    my(%args) = @_;
    my $bbbike_aux_dir = bbbike_aux_dir();
    if (!$bbbike_aux_dir) {
	main::status_message("bbbike-aux directory is not available", "die");
    }
    my $all_traffic_maps_script = "$bbbike_aux_dir/misc/all-traffic-maps.pl";
    if (!-e $all_traffic_maps_script) {
	main::status_message("The script '$all_traffic_maps_script' does not exist", "die");
    }
    system "$all_traffic_maps_script --lon $args{px} --lat $args{py} &";
    main::status_message("all-traffic-maps.pl was started in the background, please be patient", "info");
}

######################################################################

sub show_links_to_all_maps {
    my(%args) = @_;
    my %all_maps = map {
	my $desc = $main::info_plugins{$_};
	if (!$desc || (exists $desc->{allmaps} && !$desc->{allmaps})) {
	    ();
	} elsif ($desc->{allmaps_cb}) {
	    my @ret = $desc->{allmaps_cb}->(%args);
	    if (@ret == 1) {
		($desc->{name} => $ret[0]);
	    } else {
		@ret;
	    }
	} elsif ($desc->{callback_3_std}) {
	    ($desc->{name} => $desc->{callback_3_std}->(%args));
	} else {
	    ();
	}
    } keys %main::info_plugins;
    my $tl_tag = 'MultiMap_AllMaps';
    my $t = main::redisplay_top($main::top, $tl_tag,
				-title => 'All Maps',
				-class => 'BbbbikePassive',
				);
    my $txt;
    if (defined $t) {
	$txt = $t->Scrolled('ROText', -scrollbars => 'osoe',
			    -wrap => 'none',
			    -width => 50, -height => 15)->pack(qw(-fill both -expand 1));
	$t->Advertise(Text => $txt);
    } else {
	$main::toplevel = $main::toplevel if 0; # cease -w
	$t = $main::toplevel{$tl_tag};
	$txt = $t->Subwidget('Text');
	$txt->delete('1.0', 'end');
    }
    for my $name (sort { lc($a) cmp lc($b) } keys %all_maps) {
	my $url = $all_maps{$name};
	$txt->insert('end', "$name\t$url\n");
    }
}

######################################################################

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

sub _wgs84_to_utm33U {
    my($y,$x) = @_;
    require Karte::UTM;
    my($utm_ze, $utm_zn, $utm_x, $utm_y) = Karte::UTM::DegreesToUTM($y, $x, "WGS 84");
    if ("$utm_ze$utm_zn" ne "33U") {
	warn "Unexpected UTM zone $utm_ze$utm_zn, expect wrong coordinate transformation...\n";
    }
    ($utm_x,$utm_y);
}

sub _wgs84_to_utm_ze {
    my($y,$x,$ze) = @_;
    require Karte::UTM;
    my($utm_ze, $utm_zn, $utm_x, $utm_y) = Karte::UTM::DegreesToUTM($y, $x, "WGS 84", ze => $ze);
    ($utm_x,$utm_y);
}

# target is EPSG:3857
sub _wgs84_to_pseudo_mercator {
    my($lon,$lat) = @_;

    # Earth's radius in meters (WGS84)
    my $R = 6378137;
    
    my $lambda_rad = deg2rad($lon);
    my $phi_rad = deg2rad($lat);

    my $x = $R * $lambda_rad;
    my $y = $R * log(Math::Trig::tan(Math::Trig::pi() / 4.0 + $phi_rad / 2.0));

    ($x, $y);
}

sub _rel_to_abs_date {
    my $date = shift;
    if ($date =~ m{^-(\d+)year$}) {
	require POSIX;
	$date = POSIX::strftime("%F", localtime(time - 86400*365*$1));
    } elsif ($date =~ m{^-(\d+)month$}) {
	require POSIX;
	$date = POSIX::strftime("%F", localtime(time - 86400*30*$1));
    } elsif ($date =~ m{^-(\d+)week$}) {
	require POSIX;
	$date = POSIX::strftime("%F", localtime(time - 86400*7*$1));
    }
    if ($date !~ m{^\d{4}-\d{2}-\d{2}$}) {
	die "dateFrom parameter must be an ISO 8601 day, not '$date'";
    }
    $date;
}

######################################################################

1;

__END__
