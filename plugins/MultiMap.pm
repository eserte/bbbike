# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2006,2007,2010,2011,2012,2014,2016,2017,2018 Slaven Rezic. All rights reserved.
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
$VERSION = 1.31;

use vars qw(%images);

my $map_compare_use_bbbike_org = 1;

sub register {
    _create_images();
    my $lang = $Msg::lang || 'de';
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    # this order will be reflected in show_info
    if ($is_berlin) {
	$main::info_plugins{__PACKAGE__ . "_DeinPlan_Leaflet"} =
	    { name => "Pharus (dein-plan, Leaflet)",
	      callback => sub { showmap_deinplan_leaflet(@_) },
	      callback_3_std => sub { showmap_url_deinplan_leaflet(@_) },
	      ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	    };
	$main::info_plugins{__PACKAGE__ . "_DeinPlan_Web"} =
	    { name => "Pharus (dein-plan, Web)",
	      callback => sub { showmap_deinplan_web(@_) },
	      callback_3_std => sub { showmap_url_deinplan_web(@_) },
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
    $main::info_plugins{__PACKAGE__ . '_OpenStreetMap'} =
	{ name => 'OpenStreetMap',
	  callback => sub { showmap_openstreetmap(osmmarker => 0, @_) },
	  callback_3 => sub { show_openstreetmap_menu(@_) },
	  ($images{OpenStreetMap} ? (icon => $images{OpenStreetMap}) : ()),
	  order => 'first',
	};
    $main::info_plugins{__PACKAGE__ . "_MapCompare"} =
	{ name => "Map Compare (Google/OSM)",
	  callback => sub { showmap_mapcompare(@_) },
	  callback_3_std => sub { showmap_url_mapcompare(@_) },
	  ($images{Geofabrik} ? (icon => $images{Geofabrik}) : ()),
	};
    if ($map_compare_use_bbbike_org) {
	$main::info_plugins{__PACKAGE__ . "_MapCompare_Distinct_Map_Data"} =
	    { name => "Map Compare (distinct map data)",
	      callback => sub { showmap_mapcompare(@_, profile => "__distinct_map_data") },
	      callback_3_std => sub { showmap_url_mapcompare(@_, profile => "__distinct_map_data") },
	      ($images{Geofabrik} ? (icon => $images{Geofabrik}) : ()),
	    };
	$main::info_plugins{__PACKAGE__ . "_MapCompare_BBBike"} =
	    { name => "Map Compare (profile BBBike)",
	      callback => sub { showmap_mapcompare(@_, profile => "bbbike") },
	      callback_3_std => sub { showmap_url_mapcompare(@_, profile => "bbbike") },
	      ($images{Geofabrik} ? (icon => $images{Geofabrik}) : ()),
	    };
    }
    if ($is_berlin) {
     	$main::info_plugins{__PACKAGE__ . "_BvgStadtplan"} =
     	    { name => "BVG-Stadtplan",
     	      callback => sub { showmap_bvgstadtplan(@_) },
     	      callback_3_std => sub { showmap_url_bvgstadtplan(@_) },
     	      ($images{BvgStadtplan} ? (icon => $images{BvgStadtplan}) : ()),
     	    };
    }
    $main::info_plugins{__PACKAGE__ . "_BikeMapNet"} =
	{ name => "bikemap.net",
	  callback => sub { showmap_bikemapnet(@_) },
	  callback_3_std => sub { showmap_url_bikemapnet(@_) },
	  ($images{BikeMapNet} ? (icon => $images{BikeMapNet}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_Geocaching"} =
	{ name => "geocaching.com",
	  callback => sub { showmap_geocaching(@_) },
	  callback_3_std => sub { showmap_url_geocaching(@_) },
	  ($images{Geocaching} ? (icon => $images{Geocaching}) : ()),
	  order => 8800,
	};
    $main::info_plugins{__PACKAGE__ . "_YahooDe"} =
	{ name => "yahoo.de",
	  callback => sub { showmap_yahoo_de(@_) },
	  callback_3_std => sub { showmap_url_yahoo_de(@_) },
	  ($images{YahooDe} ? (icon => $images{YahooDe}) : ()),
	  order => 8900,
	};
    $main::info_plugins{__PACKAGE__ . "_Bing_Birdseye"} =
	{ name => "bing (Bird's eye)",
	  callback => sub { showmap_bing_birdseye(@_) },
	  callback_3_std => sub { showmap_url_bing_birdseye(@_) },
	  ($images{Bing} ? (icon => $images{Bing}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_Bing_Street"} =
	{ name => "bing (Street)",
	  callback => sub { showmap_bing_street(@_) },
	  callback_3_std => sub { showmap_url_bing_street(@_) },
	  ($images{Bing} ? (icon => $images{Bing}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_DAF"} =
	{ name => "Deutsches Architektur-Forum",
	  callback => sub { showmap_daf(@_) },
	  callback_3_std => sub { showmap_url_daf(@_) },
	  ($images{DAF} ? (icon => $images{DAF}) : ()),
	};
    if ($is_berlin && module_exists('Geo::Proj4')) {
	$main::info_plugins{__PACKAGE__ . "_FIS_Broker_1_5000"} =
	    { name => "FIS-Broker (1:5000)",
	      callback => sub { showmap_fis_broker_1_5000(@_) },
	      callback_3_std => sub { showmap_url_fis_broker_1_5000(@_) },
	      ($images{FIS_Broker} ? (icon => $images{FIS_Broker}) : ()),
	    };
    }
## "NOT FOUND"
#    $main::info_plugins{__PACKAGE__ . 'Fahrrad_Stadtplan_Eu'} =
#	{ name => 'fahrrad-stadtplan.eu',
#	  callback => sub { showmap_fahrrad_stadtplan_eu(@_) },
#	  callback_3_std => sub { showmap_url_fahrrad_stadtplan_eu(@_) },
#	};
    $main::info_plugins{__PACKAGE__ . 'Mapillary'} =
	{ name => 'Mapillary',
	  callback => sub { showmap_mapillary(@_) },
	  callback_3 => sub { show_mapillary_menu(@_) },
	  ($images{Mapillary} ? (icon => $images{Mapillary}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . 'OpenStreetCam'} =
	{ name => 'OpenStreetCam',
	  callback => sub { showmap_openstreetcam(@_) },
	  callback_3_std => sub { showmap_url_openstreetcam(@_) },
	};
    $main::info_plugins{__PACKAGE__ . '_AllMaps'} =
	{ name => 'All Maps',
	  callback => sub { show_links_to_all_maps(@_) },
	  order => 9000,
	};
}

sub _create_images {
    if (!defined $images{WikiMapia}) {
	# Got from: http://wikimapia.org/favicon.ico
	# and used only 32 colors
	$images{WikiMapia} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPQbADV8MUqORHGxamChYHTNbEzWZz2aRUuRumWrqFio1Gu0zE2bznHRn3PL
zom7eJDEeZXRi5DNuKnXlLXXr6Xpro/O16rZz7XqztHrtcbcrdbv1P////n89+/z797tyJC4
pSH5BAAAAAAAIf8LTkVUU0NBUEUyLjADAQAAACwAAAAAEAAQAAAFsuAmbppEnASkceNoZto1
zQLEjpCk7ddl/RABhyWRYHaaX2VpeThIBA+F0lsqFBGjoWSkaqwNRoEgCRIw014j0Si4C4JM
4PwgUCzsiBguwADOBAx4CQthDAcDAxl/GA8WFQmRCwsHBwgCEwY5Jh8LkYSVCA8PAx59Ag4K
nqAFAYsTHE4SDh8JCgmIA04BHRscqBkWChUKHxAZDrw3vwEfFs4TDgADHUMtGQMBAAABA7C+
HCEAIfkEAAAAAAAsAAAAACAAIACEcqtsWZxZXdNuOddjWaKsVqfUbbPOS5vRcc6xbNWObrvJ
iLd1icp2kbmPltGMj860q9SRr9WvsOOatemwkOalkczUqtnUt+jPzO6yxt+10+3R////9/v3
6/Xr3ezRhLnLBf7gJo5bp02Sw6yMsDrSpHUcaY8myqQS5VCpn2Momd1IHE3kNcE0JxdLJCJt
ARzGo0nCgGE8YI3mQrZEI5BFN+KxcZJDCAbTAV86ZYu+oo84Fg4RHSRbO3MddR54eowVjnoP
DlcTgyIaPHMeYnd5Fo6fjhFcCw0ZNR1cDJkYF2JijHsGBp8RKAtXbRoUhh5OExSdjgqysw8U
FBkYDAAAGR0TEKoYJ1BkUZ6OsgoICAk+EhhpuBIQck4XwNbCFQoF2wkJAvIwEg0LC37SE79Q
Y57EBrrFkycvwQ5x0cBh6AGk1QV2CiK+EzCgIsEF5RYESDhHggBv6gy4+8AtwQCTFv4BYMyg
sYEhLvKORakgkhsFgRUrBgighmUAlwpbePMUsYDRbSXhCQgwgCcDny7nKINHwZHRAgeOckNA
oOvOAAAgRGi5YqGDBAiqfrjKVgGBAl0PdCVwRQJZVSluCmNrVO4Bv3LBhk3zc4cEcsceIBjG
969juV6v2NuYAgK5IfAQ8MX6l4BjuvfSaLSsAhwEAQAaEDDw9urnAzvpNhD9M4OGP3LELUjQ
ju1nrzsbTA4gyAMEAIYZ3EpAoLfIz195Dm+gCI6acg6EfzCwnRhcArdU2gMAVhCNDhkaIC+X
/oN7gHLthb5X3sMbER0iMFuZwYL7/9t9YE9GGv1k330ieFAwFjPCZRCBew9CmBF5YFH3BoL4
jbVTav81AGEEw9W3wYU1jMABeuoxoyJ5t4S3Ez5tjHjhDRwoKByF0W3YABsYynhECTYKJ6SQ
VNCA4YUhAAA7
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
	# Fetched http://www.bikemap.de/static/images/header/logo.de.gif
	# and converted using Gimp (cropped manually and scaled to 16px height)
	# mmencode the result
	$images{BikeMapNet} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAKAMZzAASbygWbyhOZxRGaxxSZxRKbxxOeyhGgzBagyhyfyR2fyR6lzx2n0Suj
yy6kzDWz2Da02Dm02Uev0kiw0kC02EC12D632je630O22T653EW52z694EG830W73Uy83Uq9
3la52VO83Fq72lO/3lu93E3D41q+3F2+3FjB31vA3l+/3VXF42LE4WbE4GnF4XDE32zG4W3H
4nPF33nG33TL5X3I4HnK43fP6IrO44DS6ovO5ILS6IzT6I3U6ZXR5ZfS5pbX6pXZ7Zra7J7e
8Kvb66zc66ff76ng77Tg7q3j8rXh77ji77jj8Lfl8rvm8r7p9Mfo88Tq9cro8szp88fs9tDr
9Mvt98/t9s/u99Du9tfv9tjv9tfw+Njw99nw99rw9tvx997y+eP0+eT2++f1+uX2++f3++34
++74/PL6/Pf8/fj8/vn9/vv9/vz+/vz+//3+/v3+//7/////////////////////////////
/////////////////////////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQBCgB/ACwA
AAAAEAAKAAAHjoBzc29lVGOCTyVDgoyCWCsXSYJsVhtmjY05N3JzcVEcQZhrV0dNGVlcPR87
HUZOanNhMSw0GhAWHkJpQA8jKBFdGDBuYikMLWhzTCE8FG0uFQFaYAsmKiSCJzZnB1BeAAhI
altzIi+CMiBzSmRLBjoJRFU1A+RzXwUzVUUKOHA/DgRIkNJoygQCDXzACQQAOw==
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

    if (!defined $images{YahooDe}) {
	# Fetched logo:
	#   wget http://l.yimg.com/a/i/ww/beta/y3.gif
	# Manually cropped the Y and resized to 16x16
	# Created base64:
	#   mmencode -b ...
	$images{YahooDe} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAKU2AM0DLcwELbgOMeYAL+MCMOkAL/IAMfgAMvkAMvAFMv0AM/8AM/gGNf8D
NeESO+YSOoVEU546T/4NPNkfRuoZQeUbRP0QP/0RPv4VQfcYRf4fR/wgSbhBV/8fTLlEXPEq
UP4lTv0nT7ZJX6JUZdI/XP4vWYlob4lqcadebsFZarVfbvw/ZPRFaY56f/pHav1KbJJ+g6OA
iJ+Ditl5ia6qq7Kwsf///////////////////////////////////////yH+FUNyZWF0ZWQg
d2l0aCBUaGUgR0lNUAAh+QQBCgA/ACwAAAAAEAAQAAAGXcCfcEgsGo/I5PDTaWIoE1VSRlos
ODThquTqumbDyuIwTHkYCEEERrQsEkMWAVI7ShaP3wZgUjYUGQEtSj8hCwYnhD8aCwOKiwsF
hC8gFwsIDgtJIiMonp4xj6JJQQA7
EOF
    }

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
}

######################################################################
# WikiMapia

sub showmap_url_wikimapia {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    for ($px, $py) {
	s{\.}{};
	$_ = substr($_, 0, 8); # XXX what about <10° and >100°?
	if (length($_) < 8) {
	    $_ .= " "x(8-length($_));
	}
    }

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://wikimapia.org/s/#y=%s&x=%s&z=%d&l=5&m=a",
	$py, $px, $scale;
}

sub showmap_wikimapia {
    my(%args) = @_;
    my $url = showmap_url_wikimapia(%args);
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
    my $variant = $args{variant};
    if ($variant eq 'de') {
	$with_marker = 0; # not implemented on openstreetmap.de
    } elsif ($variant eq 'sautter') {
	$with_marker = 0; # not implemented on sautter.com
	$layers_spec = '&layers=B000000FTFFFFTFF';
    } elsif (defined $args{layers}) {
	$layers_spec = "&layers=$args{layers}";
    }
    my $mpfx = $with_marker ? 'm' : ''; # "marker prefix"
    my $base_url = (  $variant eq 'de'      ? 'http://www.openstreetmap.de/karte.html'
		    : $variant eq 'sautter' ? 'http://sautter.com/map/'
		    :                         'http://www.openstreetmap.org/index.html'
		   );

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 17 if $scale > 17;
    sprintf "$base_url?%slat=%s&%slon=%s&zoom=%d%s",
	$mpfx, $py, $mpfx, $px, $scale, $layers_spec;
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

sub showmap_openstreetmap_sautter {
    my(%args) = @_;
    my $url = showmap_url_openstreetmap(%args, variant => 'sautter');
    start_browser($url);
}

sub show_openstreetmap_menu {
    my(%args) = @_;
    my $lang = $Msg::lang || 'de';
    use constant USE_SAUTTER_MAP => 1;
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
	(-label => 'Cyclemap ' . ($lang eq 'de' ? '(mit Marker)' : '(with marker)'),
	 -command => sub { showmap_openstreetmap(osmmarker => 1, layers => 'C', %args) },
	);
    $link_menu->command
	(-label => 'OpenStreetMap.de',
	 -command => sub { showmap_openstreetmap_de(%args) },
	);
    if (USE_SAUTTER_MAP) {
	$link_menu->command
	    (-label => 'Transparent Map Comparison',
	     -command => sub { showmap_openstreetmap(variant => 'sautter', %args) },
	    );
    }
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
    if (USE_SAUTTER_MAP) {
	$link_menu->command
	    (-label => "Transparent Map Comparison-Link kopieren", # XXX lang!
	     -command => sub { _copy_link(showmap_url_openstreetmap(variant => 'sautter', %args)) },
	    );
    }

    $w->{$menu_name} = $link_menu;
    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

sub _copy_link {
    my $url = shift;
    $main::show_info_url = $url;
    $main::top->SelectionOwn;
    $main::top->SelectionHandle; # calling this mysteriously solves the closure problem elsewhere...
    $main::top->SelectionHandle(\&main::handle_show_info_url);
}

######################################################################
# Map Compare (Geofabrik resp. bbbike.org)

sub showmap_url_mapcompare {
    my(%args) = @_;

    my $profile = delete $args{profile};

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    if ($map_compare_use_bbbike_org) {
	$scale = 18 if $scale > 18;
    }
    my $common_qs;
    if ($profile && $profile eq '__distinct_map_data') {
	$common_qs = 'num=10&mt0=bvg&mt1=bbbike-bbbike&mt2=mapnik&mt3=esri&mt4=falk-base&mt5=google-map&mt6=nokia-map&mt7=lgb-topo-10&mt8=pharus&mt9=tomtom-basic-main';
    } else{
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

######################################################################
# BVG-Stadtplan (via mc.bbbike.org)

sub showmap_url_bvgstadtplan {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = int(17 - log(($args{mapscale_scale})/3000)/log(2) + 0.5);
    sprintf "http://mc.bbbike.org/mc/?lon=%s&lat=%s&zoom=%d&num=1&mt0=bvg", $px, $py, $scale;
}

sub showmap_bvgstadtplan {
    my(%args) = @_;
    my $url = showmap_url_bvgstadtplan(%args);
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
    sprintf "https://www.bikemap.net/en/search/?zoom=%d&center=%s%2C%s",
	$scale, $py, $px;

}

sub showmap_bikemapnet {
    my(%args) = @_;
    my $url = showmap_url_bikemapnet(%args);
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
# Yahoo (de.routenplaner)

sub showmap_url_yahoo_de {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    $scale = 20 if $scale > 20;

    sprintf "http://de.maps.yahoo.com/#q1=++&lat=%s&lon=%s&zoom=%d&mvt=m&trf=0",
	$py, $px, $scale;
}

sub showmap_yahoo_de {
    my(%args) = @_;
    my $url = showmap_url_yahoo_de(%args);
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
    sprintf "http://www.bing.com/maps/?cp=%s~%s&lvl=%s",
	$py, $px, $scale;
}

sub showmap_bing_street {
    my(%args) = @_;
    my $url = showmap_url_bing_street(%args);
    start_browser($url);
}

######################################################################
# DAF (Deutsches Architektur-Forum)

sub showmap_url_daf {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.dafmap.de/d/berlin.html?center=%s+%s&zoom=%d", $py, $px, $scale;
}

sub showmap_daf {
    my(%args) = @_;
    my $url = showmap_url_daf(%args);
    start_browser($url);
}

######################################################################
# FIS-Broker

sub showmap_url_fis_broker_1_5000 {
    my(%args) = @_;
    require Geo::Proj4;
    my $proj4 = Geo::Proj4->new("+proj=utm +zone=33 +ellps=intl +units=m +no_defs") # see http://www.spatialreference.org/ref/epsg/2078/
	or die Geo::Proj4->error;
    my($x0,$y0) = $proj4->forward($args{py0}, $args{px0});
    my($x1,$y1) = $proj4->forward($args{py1}, $args{px1});
    sprintf 'http://fbinter.stadt-berlin.de/fb/index.jsp?loginkey=zoomStart&mapId=k5_farbe@senstadt&bbox=%d,%d,%d,%d', $x0, $y0, $x1, $y1;
}

sub showmap_fis_broker_1_5000 {
    my(%args) = @_;
    my $url = showmap_url_fis_broker_1_5000(%args);
    start_browser($url);
}

#######################################################################
## fahrrad-stadtplan.eu
#
#sub showmap_url_fahrrad_stadtplan_eu {
#    my(%args) = @_;
#    my $px = $args{px};
#    my $py = $args{py};
#    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
#    sprintf "http://www.fahrrad-stadtplan.eu/?lat=%s&lon=%s&zoom=%d", $py, $px, $scale;
#}
#
#sub showmap_fahrrad_stadtplan_eu {
#    my(%args) = @_;
#    my $url = showmap_url_fahrrad_stadtplan_eu(%args);
#    start_browser($url);
#}

######################################################################
# Mapillary

sub showmap_url_mapillary {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $dateFrom = $args{dateFrom};
    if ($dateFrom) {
	if ($dateFrom =~ m{^-(\d+)month$}) {
	    require POSIX;
	    $dateFrom = POSIX::strftime("%F", localtime(time - 86400*30));
	}
	if ($dateFrom !~ m{^\d{4}-\d{2}-\d{2}$}) {
	    die "dateFrom parameter must be an ISO 8601 day, not '$dateFrom'";
	}
    }
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf("https://www.mapillary.com/app/?lat=%s&lng=%s&z=%d", $py, $px, $scale)
	. ($dateFrom ? "&dateFrom=$dateFrom" : "");
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
    $link_menu->command
	(-label => 'Fresh Mapillary (< 1 month)',
	 -command => sub { showmap_mapillary(dateFrom => '-1month', %args) },
	);
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
# OpenStreetCam

sub showmap_url_openstreetcam {
    my(%args) = @_;
    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "https://www.openstreetcam.org/map/@%s,%s,%dz", $py, $px, $scale;
}

sub showmap_openstreetcam {
    my(%args) = @_;
    my $url = showmap_url_openstreetcam(%args);
    start_browser($url);
}

######################################################################

sub show_links_to_all_maps {
    my(%args) = @_;
    my %all_maps = map {
	my $desc = $main::info_plugins{$_};
	$desc && $desc->{callback_3_std} && (!exists $desc->{allmaps} || $desc->{allmaps}) ?
	    ($desc->{name} => $desc->{callback_3_std}->(%args)) : ();
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
    for my $name (sort keys %all_maps) {
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

# For sites which not work with mozilla/seamonkey - prefer firefox
sub start_browser_no_mozilla {
    my($url) = @_;
    require WWWBrowser;
    local @WWWBrowser::unix_browsers = @WWWBrowser::unix_browsers;
    @WWWBrowser::unix_browsers = grep { !m{^(seamonkey|mozilla|htmlview|_.*)$} } @WWWBrowser::unix_browsers;
    start_browser($url);
}

######################################################################
# Helper

# REPO BEGIN
# REPO NAME module_exists /home/eserte/src/srezic-repository 
# REPO MD5 1ea9ee163b35d379d89136c18389b022

# Return true if the module exists in @INC or if it is already loaded.

sub module_exists {
    my($filename) = @_;
    $filename =~ s{::}{/}g;
    $filename .= ".pm";
    return 1 if $INC{$filename};
    foreach my $prefix (@INC) {
	my $realfilename = "$prefix/$filename";
	if (-r $realfilename) {
	    return 1;
	}
    }
    return 0;
}
# REPO END

1;

__END__
