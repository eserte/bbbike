# -*- perl -*-

#
# $Id: bbbike-teaser.pl,v 1.4 2004/01/23 00:11:24 eserte Exp eserte $
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
			     'routen',
			     'link',
			    );
    my @teasers_mandatory = (
			     #teaser_perltk_newrelease(),
			     teaser_mapserver(),
			     teaser_dobli(),
			    );
    my $sub = "teaser_" . $teasers_optional[int(rand(@teasers_optional))];
    my $t = eval $sub . '()';
    join(blind_image(1,8),
	 map {
	     '<table width="100%" bgcolor="#ffdead"><tr><td>' . $_ . '</td></tr></table>'
	 } (@teasers_mandatory,
	    defined $t ? $t : (),
	   )
	);
}

sub teaser_sternfahrt {
    <<EOF
<a href="http://www.radzeit.de/mapserver/brb/sternfahrt2003_init.html"><img src="$bbbike_images/stern2003_titel.jpg" border="0"><br>Die Routen der Sternfahrt 2003</a>
EOF
}

sub teaser_perltk_newrelease {
    <<EOF;
<small><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}">Download</a> der Perl/Tk-Version von BBBike mit interaktiver Karte. Läuft auf Linux, Unix und Windows.</small><br><a class="new" href="@{[ $BBBike::LATEST_RELEASE_DISTDIR ]}">NEU: Version 3.13</a><br>
EOF
}

sub teaser_perltk {
    <<EOF;
<small><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}">Download</a> der Perl/Tk-Version von BBBike mit interaktiver Karte. Läuft auf Linux, Unix und Windows.</small><br>
EOF
}

sub teaser_none { "" }

sub teaser_routen {
    <<EOF;
<small>Ich sammele GPS-Routen von Berlin und Brandenburg. Bitte per Mail an <a target="_top" href="mailto:@{[ CGI::escapeHTML($BBBike::EMAIL) ]}?subject=BBBike-GPS">Slaven Rezic</a> schicken.</small>
EOF
}

sub teaser_link {
    <<EOF;
<small><a href="$bbbike_url?info=1#link">Link auf BBBike setzen</a></small>
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
<small>Die BBBike-Kartendaten mit <a href="@{[ CGI::escapeHTML($mapserver_url) ]}">Mapserver</a> visualisiert.</small>
EOF
}

sub teaser_dobli {
    <<EOF;
<div style="text-align:center; width:100%;"><a href="http://www.semlin.de/dobli"><img border="0" src="http://www.tagesspiegel.de/dobli/bilder/kampagne170.gif" alt="Dobli-Spiegel" /></a></div>
EOF
}

1;

__END__
