# -*- perl -*-

#
# $Id: AltBerlin.pm,v 1.2 2006/01/11 22:22:55 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package AltBerlin;

use BBBikePlugin;
push @ISA, 'BBBikePlugin';

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

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
10 1936
);

sub register {
    $main::info_plugins{__PACKAGE__ . ""} =
	{ name => "Alt-Berlin (1946)",
	  callback => sub { altberlin(@_, stadtplannr => 10) },
	  #callback_3_std => sub { altberlin_url(@_) },
	  callback_3 => sub { show_all_urls_menu(@_) },
	};
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
    WWWBrowser::start_browser($url);
}

1;

__END__

# To get the nr-year mapping:
#
# perl -nle '/nr=(\d+).*overlib.*([12]\d{3})/ && print "$1 $2"' the_html_page.html
