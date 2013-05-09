# -*- perl -*-

#
# $Id: BBBikeGeoURLPlugin.pm,v 1.3 2007/03/31 20:08:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2006 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Description (en): GeoURL support (create tags and link to site)
# Description (de): GeoURL-Unterstützung (HTML-Tags erzeugen und auf die Site verlinken)
package BBBikeGeoURLPlugin;

use BBBikePlugin;
push @ISA, "BBBikePlugin";

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub register {
    my $pkg = __PACKAGE__;

    $main::info_plugins{$pkg} =
	{ name => "GeoURL",
	  callback => sub { geourl_tags(@_) },
	};
}

sub geourl_tags {
    my(%args) = @_;

    my $px = $args{px};
    my $py = $args{py};

    my $t = main::redisplay_top($main::top, __PACKAGE__, -title => "GeoURL");
    my $txt;
    my $b;
    if ($t) {
	$txt = $t->Scrolled("ROText", -width => 80, -height => 20)->pack(qw(-fill both -expand 1));
	$t->Advertise(Text => $txt);

	$b = $t->Button()->pack;
	$t->Advertise(Link => $b);
    } else {
	$t = $main::toplevel{ __PACKAGE__ . "" };
	$txt = $t->Subwidget("Text");
	$b = $t->Subwidget("Link");
    }

    my $geourl = <<EOF;
HTML:
<meta name="DC.title" content="TITEL DER HOMEPAGE, BITTE AUSFÜLLEN!!!">
<meta name="ICBM" content="$py, $px">
<meta name="geo.position" content="$py;$px">

XHTML:
<meta name="DC.title" content="TITEL DER HOMEPAGE, BITTE AUSFÜLLEN!!!" />
<meta name="ICBM" content="$py, $px" />
<meta name="geo.position" content="$py;$px" />

EOF

    $txt->delete("1.0", "end");
    $txt->insert("end", $geourl);

    $b->configure(-text => "Sites near $py/$px",
		  -command => sub {
		      start_browser("http://geourl.org/near?lat=$py&long=$px");
		  });
}

sub start_browser {
    my($url) = @_;
    main::status_message("Der WWW-Browser wird mit der URL $url gestartet.", "info");
    require WWWBrowser;
    WWWBrowser::start_browser($url);
}

1;

__END__
