# -*- perl -*-

#
# $Id: bbbike-teaser.pl,v 1.1 2003/05/24 22:38:29 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

######################################################################
#
# Teaser for bbbike.cgi
#
sub teaser {
    my @teasers = (#'none',
		   'routen', 'link', 'mapserver');
    my $sub = "teaser_" . $teasers[int(rand(@teasers))];
    my $t = eval $sub . '()';
    teaser_perltk() . ($t ne '' ? "<br>".blind_image(1,3)."<hr>".blind_image(1,3)."<br>$t" : "");
}

sub teaser_sternfahrt {
    <<EOF
<a href="http://www.radzeit.de/mapserver/brb/sternfahrt2003_init.html"><img src="$bbbike_images/stern2003_titel.jpg" border="0"><br>Die Routen der Sternfahrt 2003</a>
EOF
}

sub teaser_perltk {
    <<EOF;
<small><a href="@{[ $BBBike::BBBIKE_SF_WWW ]}">Download</a> der Perl/Tk-Version</small>
EOF
}

sub teaser_none { "" }

sub teaser_routen {
    <<EOF;
<small>Ich sammle GPS-Routen von Berlin und Brandenburg. Bitte per Mail an <a target="_top" href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike-GPS">Slaven Rezic</a> schicken.</small>
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
<small>Die BBBike-Kartendaten mit <a href="$mapserver_url">Mapserver</a> visualisiert.</small>
EOF
}

__END__
