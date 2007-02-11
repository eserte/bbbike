# -*- perl -*-

#
# $Id: MultiMap.pm,v 1.6 2007/02/11 21:50:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Link to GoYellow, WikiMapia and MultiMap
# Description (de): Links zu GoYellow, WikiMapia und MultiMap
package MultiMap;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use vars qw(%images);

sub register {
    _create_images();
    $main::info_plugins{__PACKAGE__ . "_MultiMap"} =
	{ name => "MultiMap",
	  callback => sub { showmap(@_) },
	  callback_3_std => sub { showmap_url(@_) },
	  ($images{MultiMap} ? (icon => $images{MultiMap}) : ()),
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

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    WWWBrowser::start_browser($url);
}

1;

__END__
