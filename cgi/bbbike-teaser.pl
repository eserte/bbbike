# -*- perl -*-

#
# $Id: bbbike-teaser.pl,v 1.7 2004/08/19 22:06:07 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

######################################################################
#
# Teaser for bbbike.cgi
#
sub teaser {
    my @teasers_optional  = (
			     'link',
			     'wap',
			     'dobli',
			    );
    my @teasers_mandatory = (
			     #teaser_perltk_newrelease(),
			     teaser_perltk(),
			     teaser_mapserver(),
			     teaser_routen(),
			     #teaser_sternfahrt(),
			     #teaser_dobli(),
			    );
    my $sub = "teaser_" . $teasers_optional[int(rand(@teasers_optional))];
    my $t = eval $sub . '()';
    join("",
	 map {
	     '<div class="teaserbox">' . $_ . '</div>'
	 } (@teasers_mandatory,
	    defined $t ? $t : (),
	   )
	);
}

sub teaser_sternfahrt {
    my $year = (localtime)[5]+1900;
    my $url = "http://www.radzeit.de/mapserver/brb/sternfahrt${year}_init.html";
    <<EOF
<div class="teaser"><a style="text-decoration:none;" href="$url"><img style="padding:3px 0px 3px 0px; border:0px;" src="$bbbike_images/stern${year}_titel.jpg" border="0"></a><br><a href="$url">Die Routen der Sternfahrt ${year}</a></div>
EOF
}

sub teaser_perltk_newrelease {
    <<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}">Download</a> der Perl/Tk-Version von BBBike mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.<br /><a class="new" href="@{[ $BBBike::LATEST_RELEASE_DISTDIR ]}"><span style="font-weight:bold;">NEU: Version 3.13</a></span></div>
EOF
}

sub teaser_perltk {
    <<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}">Download</a> der Perl/Tk-Version von BBBike mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.</div>
EOF
}

sub teaser_none { "" }

sub teaser_routen {
    <<EOF;
<div class="teaser">Ich sammele GPS-Routen von Berlin und Brandenburg. Bitte per Mail an <a target="_top" href="mailto:@{[ CGI::escapeHTML($BBBike::EMAIL) ]}?subject=BBBike-GPS">Slaven Rezic</a> schicken.</div>
EOF
}

sub teaser_link {
    <<EOF;
<div class="teaser"><a href="$bbbike_url?info=1#link">Link auf BBBike setzen</a></div>
EOF
}

sub teaser_mapserver {
    my $mapserver_url;
    if ($can_mapserver) {
        $mapserver_url = "$bbbike_script?mapserver=1";
    } elsif (defined $mapserver_init_url) {
        $mapserver_url = $mapserver_init_url;
    }
    return undef if !$mapserver_url;
    <<EOF;
<div class="teaser">Die BBBike-Kartendaten mit <a href="@{[ CGI::escapeHTML($mapserver_url) ]}">Mapserver</a> visualisiert.</div>
EOF
}

sub teaser_dobli {
    <<EOF;
<div style="text-align:center; width:100%;"><a href="http://www.semlin.de/dobli"><img border="0" src="http://www.tagesspiegel.de/dobli/bilder/kampagne170.gif" alt="Dobli-Spiegel" /></a></div>
EOF
}

sub teaser_wap {
    <<EOF;
<div class="teaser">Experimentell - BBBike über WAP: <a href="@{[ $BBBike::BBBIKE_WAP ]}">@{[ $BBBike::BBBIKE_WAP ]}</a></div>
EOF
}

1;

__END__
