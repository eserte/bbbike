# -*- perl -*-

#
# $Id: AltBerlin.pm,v 1.5 2006/09/17 20:20:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): Link to maps from Alt-Berlin (alt-berlin.info)
# Description (de): Link zu Alt-Berliner Stadtplänen (alt-berlin.info)
package AltBerlin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use vars qw($icon);

use vars qw(%nr_to_year);
%nr_to_year = qw(
11 1738
13 1760
17 1789
18 1836
29 1869
8 1875
15 1893
12 1894
3 1895
25 1896
1 1897
5 1899
26 1906
2 1921
20 1926
21 1932
19 1938
14 1939
33 1943
4 1945
37 1945
10 1946
23 1954
50 1957
9 1960
22 1961
7 1989
);

sub register {
    my $is_berlin = $main::city_obj && $main::city_obj->cityname eq 'Berlin';
    if ($is_berlin) {
	_create_image();
	$main::info_plugins{__PACKAGE__ . ""} =
	    { name => "Alt-Berlin (1946)",
	      callback => sub { altberlin(@_, stadtplannr => 10) },
	      #callback_3_std => sub { altberlin_url(@_) },
	      callback_3 => sub { show_all_urls_menu(@_) },
	      icon => $icon,
	    };
    } else {
	main::status_message("Das AltBerlin-Plugin ist nur für Berlin verfübar.", "err")
		if !$main::booting;
    }
}

sub _create_image {
    if (!defined $icon) {
	# Got from: http://www.alt-berlin.info/bilder/lupe.ico
	$icon = $main::top->Photo
	    (-format => 'gif',
	     -data => <<EOF);
R0lGODlhEAAQAPf+AEVGSmRmaQAECQAFCgAECBIZHhAVGG97gWJmaHB9gXSAhHV+gURLTQYO
EAAZHgofIgcVFwUYGiYuL0dPUFdfYAALDCQvMBIvMSNNUAAlJgAiIwEtLAwYGDI8PDU/P2Fp
aV1kZH6IhwM1LwA4MAE+MgBCNA5NPW97eAcYEwBMNABWNQJWNgBPLgNgNgBlNQBkNBc2J3yu
lgRrNiB6TV+gfxRzQhh5Rh17SkmVbX+OhRYtHBswHyQ5IylBJ5q8llicTjRULzRTLpW4jX+V
ekVqOYKFgZa8iEZoOFZ+QkZmNoezcZa7hV+KSGCNRm+fUpS9e5O3fWaSSZPAdpi9f7fPqGmU
S5LEbZW9dZ3DgIW0XH+rWJvEeJbEaZ/IeZy/fJbDaIixX6nRf5/FeZy+epG6Y5zGa6DLb6nP
fJ/Fb57CcXySVbHRfJmyaa3Kc46kXqS8caG4cKe7drvUfLvRgaq9cMLXhLfIgqa2cq27dsHN
ibzHhZ6jc5+laLO5eL3Ci87TidDRjbi5h7m6icHCknh4ZJGOWM3KnMnHmuDal7ayh7SxiaOh
jqKddb64j7Goe6Obdp+bhs3CkKieep6Vc8Kzg9vMmtbAg6aadrGkfs/Bmo2GddC8kK2derio
g8u8m6STca+efMa4m/bZpeDGl9zCldO7j+vQoODHmaaUcrSigsm2kpSHb6ugjNK2h/3cpc6z
h8Wsgd7BkraeeOjLmuPGlt/ClN7Bk9m9kNC1isCnf+fKmt7ClM+1iv7fqu7Qn+nMnNm9kda7
j9O4jc2ziaOObdS6j8CogZ2Kaq2Ydd/EmMmxirWgfK6Zd5+MbbGce6WSc6GOcKWUeaSTeLyi
etO2iti7j7ifeuPEmOHEmNC1jc60jMyyi7iigJyKbqmWetvEoZ6FZLqfeeLCldCxif/bqenH
mti5j6mSctm9mOnNpsGrjNG5mO/Il9i0iMOmgp6Ha7OVc7SXeJZ/Za6Td8Woi/HDl5Z5X6OG
aqSHa6GIcOGddWddWOGRbn1PP////wAAACH5BAAAAAAALAAAAAAQABAAAAiYAP0JHEiwoEF/
CA4aPJJER4MPCql8QXbPHiE1PQgctMSvVDRp4MLhcSKhoI96+lwpUHeu2TI0AgqeCbUoRKtc
sYTB41OhYJgDRZL98oULlrs+HAoaKbct0TFivXSJmwPAoDJQgyQZo1WMEpcCBqXEUXXIkLNI
UPy9SAGh4BM9ggLBMSMwhg0RFBQapKFiAwi9BWtgAEyYcEAAOw==
EOF
    }
}

sub altberlin_url {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};
    my $nr = $args{stadtplannr};

    sprintf "http://www.alt-berlin.info/cgi/stp/lana.pl?nr=%s&gr=5&nord=%f&ost=%f", $nr, $py, $px;
}

sub altberlin {
    my(%args) = @_;
    my $url = altberlin_url(%args);
    start_browser($url);
}

sub show_all_urls_menu {
    my(%args) = @_;
    my $w = $args{widget};
    if (Tk::Exists($w->{"AltBerlinMenu"})) {
	$w->{"AltBerlinMenu"}->destroy;
    }
    my $link_menu = $w->Menu(-title => "Alt-Berliner Karten",
			     -tearoff => 0);
    for my $nr (sort { $nr_to_year{$a} <=> $nr_to_year{$b} } keys %nr_to_year) {
	$link_menu->command
	    (-label => "$nr_to_year{$nr} (Nr. $nr)",
	     -command => sub {
		 altberlin(stadtplannr => $nr, %args);
	     }
	    );
    }
    $w->{"AltBerlinMenu"} = $link_menu;

    my $e = $w->XEvent;
    $link_menu->Post($e->X, $e->Y);
    Tk->break;
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

1;

__END__

# To get the nr-year mapping:
#
# perl -nle '/nr=(\d+).*overlib.*([12]\d{3})/ && print "$1 $2"' the_html_page.html
