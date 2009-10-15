# -*- perl -*-

#
# $Id: MultiMap.pm,v 1.19 2008/07/11 21:40:53 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006,2007 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Link to GoYellow, WikiMapia, MultiMap and other maps
# Description (de): Links zu GoYellow, WikiMapia, MultiMap und anderen Karten
package MultiMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.19 $ =~ /(\d+)\.(\d+)/);

use vars qw(%images);

sub register {
    _create_images();
    # this order will be reflected in show_info
    $main::info_plugins{__PACKAGE__ . "_DeinPlan"} =
	{ name => "Pharus (dein-plan)",
	  callback => sub { showmap_deinplan(@_) },
	  callback_3_std => sub { showmap_url_deinplan(@_) },
	  ($images{Pharus} ? (icon => $images{Pharus}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_GoYellow"} =
	{ name => "GoYellow",
	  callback => sub { showmap_goyellow(@_) },
	  callback_3_std => sub { showmap_url_goyellow(@_) },
	  ($images{GoYellow} ? (icon => $images{GoYellow}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_WikiMapia"} =
	{ name => "WikiMapia",
	  callback => sub { showmap_wikimapia(@_) },
	  callback_3_std => sub { showmap_url_wikimapia(@_) },
	  ($images{WikiMapia} ? (icon => $images{WikiMapia}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_ClickRoute"} =
	{ name => "ClickRoute",
	  callback => sub { showmap_clickroute(@_) },
	  callback_3_std => sub { showmap_url_clickroute(@_) },
	  ($images{ClickRoute} ? (icon => $images{ClickRoute}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_OpenStreetMap"} =
	{ name => "OpenStreetMap",
	  callback => sub { showmap_openstreetmap(@_) },
	  callback_3_std => sub { showmap_url_openstreetmap(@_) },
	  ($images{OpenStreetMap} ? (icon => $images{OpenStreetMap}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_MapCompare"} =
	{ name => "Map Compare (Google/OSM)",
	  callback => sub { showmap_mapcompare(@_) },
	  callback_3_std => sub { showmap_url_mapcompare(@_) },
	  ($images{Geofabrik} ? (icon => $images{Geofabrik}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_MultiMap"} =
	{ name => "MultiMap",
	  callback => sub { showmap(@_) },
	  callback_3_std => sub { showmap_url(@_) },
	  ($images{MultiMap} ? (icon => $images{MultiMap}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_BvgStadtplan"} =
	{ name => "BVG-Stadtplan",
	  callback => sub { showmap_bvgstadtplan(@_) },
	  callback_3_std => sub { showmap_url_bvgstadtplan(@_) },
	  ($images{BvgStadtplan} ? (icon => $images{BvgStadtplan}) : ()),
	};
## Does not work anymore: URL gets redirected to http://intl.local.live.com/ page.
#     $main::info_plugins{__PACKAGE__ . "_LiveCom"} =
# 	{ name => "maps.live.com",
# 	  callback => sub { showmap_livecom(@_) },
# 	  callback_3_std => sub { showmap_url_livecom(@_) },
# 	  ($images{LiveCom} ? (icon => $images{LiveCom}) : ()),
# 	};
    $main::info_plugins{__PACKAGE__ . "_BikeMapDe"} =
	{ name => "bikemap.de",
	  callback => sub { showmap_bikemapde(@_) },
	  callback_3_std => sub { showmap_url_bikemapde(@_) },
	  ($images{BikeMapDe} ? (icon => $images{BikeMapDe}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_BerlinerStadtplan24"} =
	{ name => "www.berliner-stadtplan24.com",
	  callback => sub { showmap_berliner_stadtplan24(@_) },
	  callback_3_std => sub { showmap_url_berliner_stadtplan24(@_) },
	  ($images{BerlinerStadtplan24} ? (icon => $images{BerlinerStadtplan24}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_Geocaching"} =
	{ name => "geocaching.com",
	  callback => sub { showmap_geocaching(@_) },
	  callback_3_std => sub { showmap_url_geocaching(@_) },
	  ($images{Geocaching} ? (icon => $images{Geocaching}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_Panoramio"} =
	{ name => "panoramio.com",
	  callback => sub { showmap_panoramio(@_) },
	  callback_3_std => sub { showmap_url_panoramio(@_) },
	  ($images{Panoramio} ? (icon => $images{Panoramio}) : ()),
	};
    $main::info_plugins{__PACKAGE__ . "_YahooDe"} =
	{ name => "yahoo.de",
	  callback => sub { showmap_yahoo_de(@_) },
	  callback_3_std => sub { showmap_url_yahoo_de(@_) },
	  ($images{YahooDe} ? (icon => $images{YahooDe}) : ()),
	};
}

sub _create_images {
    if (!defined $images{GoYellow}) {
	# Got from: http://www.goyellow.de/favicon.ico
	$images{GoYellow} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPYAAAAASgAAWgAEWgAMUgAIWgAMWggMUggMWggQUggQWggUWhAUUhAUWhAY
WhAcWhgcWgAQYwgQYxAcYxgcYxggWhggYxggcxgocyEkUiEgWikoUikoWiksWjEsUjEwUjk0
Ujk4UiEkYyEoYyksYykwazE0azk8a0I8QkI4SkI8a2tZOUpBQkpBSlJFQlJJQlJNWkJBY1pR
Y1pVY1JRe1pVc1pZc2NVQmtdWmthUmtha2Nhc3Ntc3ttc3txYzE4hFJZjFphjHtxhHN1lGNp
pYxtKYxxKZR1KbV5AIx5UoR5c5R9a62GGLWKGLWOGL2OGL2SGL2WKYyCe7WWQqWSY6WWa62a
a6WSc7Wie9aWAMaeKd6mCN6qCOeuAOeqCO+yAPe6AMaue86yc9a+e966c+fLc+fPe+/Pe+/T
e/fXc/fXe/fbc/fbe//Xc/rUeP/Xe//bc//fe4yOrbWutda+hN7HhN7TpffXhP/7nPfnrf/n
rc7P3ufjzv//1v//58zMzAAAACH5BAEAAH4ALAAAAAAQABAAAAfVgG6Cg4SFR3ltiG1ZKigg
LkZbX5OHiHlICBUTDhQUHU+UljgSP0IzIZ0UGaCVUgBAe3x4URINCQ0dW4dtDBR1fXpyQRAD
GLdGh1AAPXdxQz4RD1RpVRQrh0UGY3MWF0kyU2ApcDkYh0QObFYBAmdKZCIAbzvmeUsJYWgL
L2sxahs37JA4cUiLAhhpyojhkeCKGTo1CiDL84VIghE0ShAoUEGHiQIanBz6wqVFgo0NHigg
cOCByJFfuqhIlYpDkyMiKU7ywsTGBw8sioh8mQeL0aNIkwYCADs=
EOF
    }

    if (!defined $images{MultiMap}) {
	# Got from: http://www.multimap.com/favicon.ico
	# and scaled to 16x16
	$images{MultiMap} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAMIDAAAAAAAAgP8AAP///////////////////yH5BAEAAAQALAAAAAAQABAA
AAMtOLrc/jDKQFWFNOchuh9VGHACZ4rg2JklWq1lO6LwOd9Srj+A0zO/3yC4KzoSADs=
EOF
    }

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

    # XXX no image for clickroute.de yet

    if (!defined $images{OpenStreetMap}) {
	# Fetched http://www.openstreetmap.org/images/mag_map.svg
	# and converted using
	#   convert -geometry 16x16 mag_map.svg mag_map_16x16.gif
	#   mmencode -b /tmp/mag_map_16x16.gif
	$images{OpenStreetMap} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPcAACs/GzIzMDM1Mjw/OEk+MDZRJThSIj9eJzxDNEdCNEBJOkRkK0lkM01q
Ok9tOE1vOVFmPlR6NzdMQDpXRTJLVT5ZakhJRkpTQE5XQ1RfR19aRlBRT0xcWl1RVlVZUEtt
R1ZvRl1hS1lkTVxlTlltSFxpTVhxQll5Ql18RFt7SltoUVxqUW1lUWFvVWJuVWNxV2RyWWZz
XmZ2XG10XnxyWENfdVhxbG17YG5+Y2R4anF3Ymd/dmKBWXmeV3SQW3eNY3aDa3mGa3qJa3uN
aXmIbnuObn6HdH6Odn+Sco2EZouHc4aOdIOUdYufd4OVeoyceZ+XdYajbI3HXafeeJGMi5eZ
iJOjhZCmhJ+hg5qkjZmpiJ+vjZunkJ6pkbKziqWimKOpnKSqnaSrn6ampqysrKezpbGxsbq7
t7q8uMaqhcqpkM28kM+9ktK8kOOoiOO4jqDBgbPbjq3Cla/Blq3DnbjEnbXLnbvMnbjRnrfP
obzPorPDqcjBl8HNndbCldTFmObEl+LNn9XKptfOqMrUoM/Uo8DZo8HZpsfap8PUq8HZqcPc
rdTXpdDYp9jQqtDdqsHbsMLbssbfsd7esObQoOnTo+ferMPjoMjgrMzkr9Hhrczyp87xq8ni
s83lsMvltM/osc7otNPmsdDptNDptd/pst7stdjqvdf0td7wudz2vd75v+Xir+TmsePntOHs
tuLwuc7OztLS0tTU09fX19bxwNvywtr2xN36wd/7weH7wevq6+zs7O/v8PHw8f38/QAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAAIf4yIENyZWF0ZWQgd2l0aCBJbmtz
Y2FwZSAoaHR0cDovL3d3dy5pbmtzY2FwZS5vcmcvKSAALAAAAAAQABAAAAj+AHnR6vWr4C9e
smTtikVmjJmERrp8OYOmjJUoQTwIsLAhwABeXUz5sTMnzhQ4LjIoWEFixIVfYERVckVqkxQG
GW7gOOGjyZNfZ/K0YhUKVQ8DDyCAePDiCJNfaOb8eXTIkAkACwoUWNBAxo1fYhhZwoUJT4qs
FCZEQOFChi8upSi9ynSJB4IPNSqkQDGEyKwtuGABIsTpCocdOWwU+YHkiCwtngqt6aNpjgoM
IlS0uAGECK8stlK1SaOmChARCETICNLiBUxJumDpodLBoogEGlSEIACVTq1bkfYoWeIEio4Z
LGgkgTrnkydFi/hUqdNmkR4veDKB9aRLFaJGgmwcZQp0ShcmUqt8dcGlSxejN24GJRpUSpcn
VboCAgA7
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

    # XXX missing: LiveCom image

    if (!defined $images{Pharus}) {
	# Fetched http://www.pharus-plan.de/px/head_kopf.jpg
	# and converted using Gimp (cropped manually and scaled to 16px width)
	# mmencode the result
	$images{Pharus} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhDQAQAOfOADg4NDs7OEFBPUVEQlBHPVJKSU1OSFZOSmBRRl5RTGBUTVpYTFNcTWFa
NGhYQRmMAxiNAhqMAhqMAx+ICxuMARuMAx6KBxuNARuNAh+LAhiPABqOAHNbHxqOARqOAhuO
ABuOAR2NARuOAiCLBx+MBk9oR3RdKiOMDWheT3ReL11iW2RgWGVeYGpdWieNEVBtUlhqTimO
FWphVyaREH9iH1NwT35jJ25iWC2SFy+RGXVkW35qLnRmX2huW3RqXzuTI21sbXlqYXlrXD2W
J3duY29xbn5uY2GDVWeAW3R3amp/X3d2c4R0XYRzZ29+akSfMIJ0bnt3c3x2d2yCaoJ5X0ef
OIF3dHGBbYR6X4V4aYd2cEyfOnl+cYZ4bnaAcUqiNIJ7bop4aoN7bU6gOXt9fIh6bH99dox6
aGSSVol+Y32AfY16cl+YT2KWU4t/ZlCmQmyTZVWmQVqjTm2XW3+IfH6LdYiEhVunRFumS3eS
a16lSmyaX1+lTXWVZ3eTb2KjU4SKfnaVapSGa5aFa5OEeWmiWoyKg2WlXmmnWYGVenKhZG6l
W3idb3ifaXaga4uRhJCPiJGRj5WPj5KRj5GTiZGUhJSUkoCldJ+SjaiSd5iWkpqalZebmKeZ
gK+Xdp6alrCce6mekaCin7KggqOko6SnqKamqK+mnqSvobGpqaysp8Gtj664qMaxkLW2r8q0
icG5m7i5vbe8sM63j8u7kcHBuL/Aw8XBusHEwMHDx9fBn9fDn8XHvcLJw9bGqMnJxszLxc3M
xNzPr+nLosjVy9LS0dfVydXY0NnZ2drb2Nzf2d7f3+Lg4OXi4///////////////////////
////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////
/////////////////////////////////yH+FUNyZWF0ZWQgd2l0aCBUaGUgR0lNUAAh+QQB
CgD/ACwAAAAADQAQAAAI7QAzfBDhIg4bNG345IBw4QIGCkMU1TH0SVKSRmMqgJDwgxEvYK7I
qKklK8+XCCQWsQomypYpS0VIHbuE44kfZZyW9SKGClckZI/w/AHUrFQxSpAqxcr1S5UjOHaY
NeBgw8QOGilSbUqkJEoyIlSwCHLDxIExTVymALlFyJcnXaBWnTk1iQ6SJaHWDBo269UuBFqk
OJljpkyTNK0yjerkI4iVQHd6ZAmDAhYtYWBu6FhQKMYRAC26EBCjgAeUAjCqPHhTw8AKGUKM
HAjAANEIDxbklBDAAlOCAS8OzaCwIcSELXuuqPDSR8+JDhoCAgA7
EOF
    }

    if (!defined $images{BikeMapDe}) {
	# Fetched http://www.bikemap.de/static/images/header/logo.de.gif
	# and converted using Gimp (cropped manually and scaled to 16px height)
	# mmencode the result
	$images{BikeMapDe} = $main::top->Photo
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

    if (!defined $images{BerlinerStadtplan24}) {
	$images{BerlinerStadtplan24} = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPUAAFxYWFxcWFxYXFxcXGBcWGBcXGBgYGRkZGhkaHBscHR0dHx4eHx8eIB8
eIB8gIiEhIiIiIyMjJCMjJCQkJiUmJycnKCcnKiopKyorKyssLy8vMDAwMTExMjIyMzIzMzM
zNDQ0NTU1NjU0NjY2Nzc3ODg4OTk5Ojo6PDw8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAAIf4V
Q3JlYXRlZCB3aXRoIFRoZSBHSU1QACwAAAAAEAAQAAAGgECUcEgsGo9IVGnJ5EwaE5KQCToM
BNdBNmICeToWLRZLKBQGDop2EGCLAoQ4AWDIXAaFeGAPjwMCChsfeGtaZnltCRooGAwLCmZi
AwSJiw54AmZYVwRaiigQApkFmVmUA4onIRUQCghXh6eBSiMgHRKwmZ0DDxtTTMDBJUnExUJB
ADs=
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

    if (!defined $images{Panoramio} && eval { require Tk::PNG; 1 }) {
	# Fetched logo:
	#   wget http://www.panoramio.com/favicon.v1.ico
	# Converted:
	#   convert 'favicon.v1.ico[0]' favicon.png
	# Created base64:
	#   mmencode -b favicon.png
	$images{Panoramio} = $main::top->Photo
	    (-format => 'png',
	     -data => <<EOF);
iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABmJLR0QA/wD/AP+gvaeTAAAA
CXBIWXMAAABIAAAASABGyWs+AAAACXZwQWcAAAAQAAAAEABcxq3DAAAC7klEQVQ4y22Tf2jU
dRjHX5/P93s3d+M2GLrF3Ji3mbVK591Wa0ambM4CaXptERH1jwUVhP2RKExhiEQkqJM0xPK/
EdXl0tb+8ERF8tfa5Z2sWOfG5m21I/Viv9zte9/v0x+D4bW9/3p4ePN+Ht7P81YsgSM/RSUc
HWUwOQGAr8jL5mdW8sl2v/o/N6vxRc9taeu8SWo6vZQu3lwX+1trs4QWio++uiId3bfRStEU
KCdYv5qq0kIUEBn6h3D0Lt29Q9iOsLOxilMfbFZZkwkel/y3Tsnpy4NyN5WW8Yk5uTdlyemL
f8qZ3hEZ/Tct31wblsJ3vhaCx+WzMxEB0ABtnTfRSnH03U00rS/Fm2OQv8zA41YcPvsbLg3e
HINNT5fw5fsNmIbmwHd9AOiO7pikptM0+ctpWFeGx2WQ59bkujQ9kRFiI/exLJs8t8bj1rxQ
9RjNdZVMzVocDPWJeSE2CsDLNav4NT6OS4PjONiOcPD7CAACGFqxzNTMZYSWDasJXY1zPprA
vDM+f6pq3wrio/c5eu4W/YkHWe4fPhelwONm41MlmFpRVVaIVoqh5MS8BwCGgmB9Jb2ftxDa
vRW/b/mCwJU//qax/Swv7esiHEss9EXA9BV76U88YGAsxRMlBWilCdZVMD2b4e2OCzy/ppjd
2/0A2I6gtSI2fA9HhIrifHTjulIAuq4PMmcL6YxgO4LbnF9uX2sNO+p8ND/n45WaVdQ/WcLP
fcMANKwtRe/aVq0KPG56IsNc7h9jxnKYthy01gQqVrCluoyMIzy0HGbmbG7Ek4R+iZPrNtn/
eq3SAO1vPIvjCB+euMil/r+YStsIil2vrmfGEiZmbSbTNlcHkuw8FsayHfbs8Ge/8nsnLsnJ
879jaEVzXSVbA+UEKoswlGJgLEXX9UFC1+6QsR3efPFxOj/eohaF6dCPt6T9214mH1pLhikv
x2TvawHaWmoXh+lRfPpDRMLRBEPJSQTBV5RPw9qVtLXWLuL/B6D3MZolV9/dAAAAAElFTkSu
QmCC
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
}

######################################################################
# MultiMap

sub showmap_url {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = $args{mapscale_scale};
    my @allowed_scales = (5000, 10000, 25000, 50000, 100000, 200000,
			  500_000, 1_000_000, 2_000_000, 4_000_000,
			  10_000_000, 20_000_000, 40_000_000);
 TRY: {
	for my $i (0 .. $#allowed_scales-1) {
	    if ($scale < ($allowed_scales[$i]+$allowed_scales[$i+1])/2) {
		$scale = $allowed_scales[$i];
		last TRY;
	    }
	}
	$scale = $allowed_scales[0];
    }
	
    sprintf "http://www.multimap.com/map/browse.cgi?scale=%d&lon=%f&lat=%f", $scale, $px, $py;
}

sub showmap {
    my(%args) = @_;
    my $url = showmap_url(%args);
    start_browser($url);
}

######################################################################
# GoYellow

sub showmap_url_goyellow {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.goyellow.de/map?lat=%f&lon=%f&z=%d&mt=1",
	$py, $px, $scale;
}

sub showmap_goyellow {
    my(%args) = @_;
    my $url = showmap_url_goyellow(%args);
    start_browser($url);
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
# ClickRoute

sub showmap_url_clickroute {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://clickroute.de/?center_lat=%s&center_lng=%s&zoom=%d&maptype=hybrid",
	$py, $px, $scale;
}

sub showmap_clickroute {
    my(%args) = @_;
    my $url = showmap_url_clickroute(%args);
    start_browser($url);
}

######################################################################
# OpenStreetMap

sub showmap_url_openstreetmap {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.openstreetmap.org/index.html?lat=%s&lon=%s&zoom=%d",
	$py, $px, $scale;
}

sub showmap_openstreetmap {
    my(%args) = @_;
    my $url = showmap_url_openstreetmap(%args);
    start_browser($url);
}

######################################################################
# Map Compare (Geofabrik)

sub showmap_url_mapcompare {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    my $map0 = 'googlehybrid';
    #my $map1 = 'tah';
    #my $map1 = 'mapnik';
    my $map1 = 'cyclemap';
    sprintf 'http://tools.geofabrik.de/mc/?mt0=%s&mt1=%s&lat=%s&lon=%s&zoom=%d',
	$map0, $map1, $py, $px, $scale;
}

sub showmap_mapcompare { start_browser(showmap_url_mapcompare(@_)) }

######################################################################
# BVG-Stadtplan

sub showmap_url_bvgstadtplan {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    sprintf "http://www.fahrinfo-berlin.de/Stadtplan/index?language=d&client=fahrinfo&mode=show&zoom=3&ld=0.1&seqnr=1&location=,,WGS84,%s,%s&label=", $px, $py
}

sub showmap_bvgstadtplan {
    my(%args) = @_;
    my $url = showmap_url_bvgstadtplan(%args);
    start_browser($url);
}

######################################################################
# maps.live.com
# Seems to not work on seamonkey, but linux-firefox is OK

sub showmap_url_livecom {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    if ($scale > 13) {
	$scale = 13; # schlechte Auflösung in Berlin und Umgebung
    }
    sprintf "http://maps.live.com/default.aspx?v=2&cp=%f~%f&style=h&lvl=%d&tilt=-90&dir=0&alt=-1000&encType=1",
	$py, $px, $scale;
}

sub showmap_livecom {
    my(%args) = @_;
    my $url = showmap_url_livecom(%args);
    start_browser_no_mozilla($url);
}

######################################################################
# dein-plan, Pharus

sub showmap_url_deinplan {
    my(%args) = @_;
    if (0) {
	require Karte::Deinplan;
	my($sx,$sy) = split /,/, $args{coords};
	my($x, $y) = map { int } $Karte::Deinplan::obj->standard2map($sx,$sy);
	my $urlfmt = "http://www.dein-plan.de/?location=|berlin|%d|%d";
	sprintf($urlfmt, $x, $y);
    } else {
	# The old-styled links still work. Prefer this over the
	# approximate pixel method above.
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
    
sub showmap_deinplan {
    my(%args) = @_;
    my $url = showmap_url_deinplan(%args);
    start_browser($url);
}

######################################################################
# bikemap.de

sub showmap_url_bikemapde {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    if ($scale > 13) {
	$scale = 13; # zu wenig Details (=Routen) bei niedrigeren Stufen
    }
    sprintf "http://www.bikemap.de/#lt=%s&ln=%s&z=%d&t=0",
	$py, $px, $scale;
}

sub showmap_bikemapde {
    my(%args) = @_;
    my $url = showmap_url_bikemapde(%args);
    start_browser($url);
}

######################################################################
# Berliner-Stadtplan24.com, does not work in seamonkey, but works in
# firefox

sub showmap_url_berliner_stadtplan24 {
    my(%args) = @_;

    #my $y_wgs = sprintf "%.2f", (Karte::Polar::ddd2dmm($py))[1];
    #my $x_wgs = sprintf "%.2f", (Karte::Polar::ddd2dmm($px))[1];
    (my $y_wgs = $args{py}) =~ s{\.}{,};
    (my $x_wgs = $args{px}) =~ s{\.}{,};
    my $zoom = "100";
    my $mapscale_scale = $args{mapscale_scale};
    if ($mapscale_scale) {
	if ($mapscale_scale < 13000) {
	    $zoom = 100;
	} elsif ($mapscale_scale < 18000) {
	    $zoom = 75;
	} elsif ($mapscale_scale < 26000) {
	    $zoom = 50;
	} else {
	    $zoom = 27;
	}
    }
    ## Does not work anymore?
    #my $url = "http://www.berliner-stadtplan.com/?y_wgs=${y_wgs}%27&x_wgs=${x_wgs}%27&zoom=$zoom&size=500x400&sub.x=15&sub.y=7";
    ## But this works. Be nice and tell the Pharus guys where this request came from:
    #my $url = "http://www.berliner-stadtplan24.com/topic/bln/str/x_wgs/${x_wgs}/y_wgs/${y_wgs}/from/bbbike.html";
    ## Since 2007-08-01 everything changed. Now it is:
    ## http://www.berliner-stadtplan24.com/berlin/gps_x/13,4439/gps_y/52,514.html
    my $url = "http://www.berliner-stadtplan24.com/berlin/gps_x/${x_wgs}/gps_y/${y_wgs}.html";
    $url;
}

sub showmap_berliner_stadtplan24 {
    my(%args) = @_;
    my $url = showmap_url_berliner_stadtplan24(%args);
    start_browser($url);
}

######################################################################
# Geocaching.com

sub showmap_url_geocaching {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = 17 - log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.geocaching.com/seek/gmnearest.aspx?lat=%s&lng=%s&zm=%d&mt=m",
	$py, $px, $scale;
}

sub showmap_geocaching {
    my(%args) = @_;
    my $url = showmap_url_geocaching(%args);
    start_browser($url);
}

######################################################################
# panoramio

sub showmap_url_panoramio {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $scale = log(($args{mapscale_scale})/3000)/log(2);
    sprintf "http://www.panoramio.com/map/#lt=%s&ln=%s&z=%d&k=2",
	$py, $px, $scale
}

sub showmap_panoramio {
    my(%args) = @_;
    my $url = showmap_url_panoramio(%args);
    start_browser($url);
}

######################################################################
# Yahoo (de.routenplaner)

sub showmap_url_yahoo_de {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $scale = $args{mapscale_scale};
    my @allowed_scales = (undef, 4500, 15000, 50000, 125000);
 TRY: {
	for my $i (1 .. $#allowed_scales) {
	    if ($scale < ($allowed_scales[$i]+$allowed_scales[$i+1])/2) {
		$scale = $i;
		last TRY;
	    }
	}
	$scale = $#allowed_scales;
    }

    sprintf "http://de.routenplaner.yahoo.com/maps_result?ds=n&name=Hallo&desc=&lat=%s&lon=%s&zoomin=yes&mag=%d",
	$py, $px, $scale;
}

sub showmap_yahoo_de {
    my(%args) = @_;
    my $url = showmap_url_yahoo_de(%args);
    start_browser($url);
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

1;

__END__
