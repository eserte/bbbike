# -*- perl -*-

#
# $Id: bbbike-teaser.pl,v 1.19 2007/05/20 21:52:59 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005,2006 Slaven Rezic. All rights reserved.
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
    my %teasers_optional;
    my %teasers_mandatory;

    $teasers_optional{"de"}  = [
				'link',
				'wap',
				'routen',
				#'dobli',
			       ];
    $teasers_mandatory{"de"} = [
				#teaser_perltk_newrelease(),
				teaser_perltk(),
				teaser_beta(),
				teaser_mapserver(),
				#teaser_routen(),
				teaser_sternfahrt(),
				#teaser_dobli(),
				$ENV{SERVER_NAME} =~ /radzeit/i ? teaser_radzeit() : (),
			       ];
    $teasers_optional{"en"} = [],
    $teasers_mandatory{"en"} = [
				#teaser_perltk_newrelease(),
				teaser_perltk(),
				teaser_mapserver(),
				#teaser_routen(),
				teaser_sternfahrt(),
				#teaser_dobli(),
				$ENV{SERVER_NAME} =~ /radzeit/i ? teaser_radzeit() : (),
			       ];

    my $use_lang = $lang eq 'en' ? "en" : "de";
    my $teaser_optional = $teasers_optional{$use_lang}->[int(rand(@{$teasers_optional{$use_lang}}))];
    my $t;
    if ($teaser_optional) {
	my $sub = "teaser_" . $teaser_optional;
	$t = eval $sub . '()';
    }
    join("",
	 map {
	     '<div class="teaserbox">' . $_ . '</div>'
	 } (@{ $teasers_mandatory{$use_lang} },
	    defined $t ? $t : (),
	   )
	);
}

sub teaser_sternfahrt {
    my $year = (localtime)[5]+1900;
    my $url = "http://bbbike.radzeit.de/mapserver/brb/sternfahrt${year}_init.html";
    <<EOF
<div class="teaser"><a style="text-decoration:none;" href="$url"><img style="padding:3px 0px 3px 0px; border:0px;" src="$bbbike_images/stern${year}_titel.jpg" border="0"></a><br><a href="$url">Die Routen der Sternfahrt ${year}</a></div>
EOF
}

sub teaser_perltk_newrelease {
    if ($lang eq 'en') {
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.en.html">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac OS X and Windows.<br /><a class="new" href="@{[ CGI::escapeHTML($BBBike::LATEST_RELEASE_DISTDIR) ]}" style="font-weight:bold;">NEW: Version @{[ CGI::escapeHTML($BBBike::STABLE_VERSION) ]}</a></div>
EOF
} else {
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.en.html">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.<br /><a class="new" href="@{[ CGI::escapeHTML($BBBike::LATEST_RELEASE_DISTDIR) ]}" style="font-weight:bold;">NEU: Version @{[ CGI::escapeHTML($BBBike::STABLE_VERSION) ]}</a></div>
EOF
    }
}

sub teaser_perltk {
    if ($lang eq 'en') {
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.en.html">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac OS X and Windows.</div>
EOF
    } else {
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.de.html">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.</div>
EOF
    }
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
    if ($lang eq 'en') {
	<<EOF;
<div class="teaser">The BBBike map data visualized with <a href="@{[ CGI::escapeHTML($mapserver_url) ]}">Mapserver</a>.</div>
EOF
    } else {
	<<EOF;
<div class="teaser">Die BBBike-Kartendaten mit <a href="@{[ CGI::escapeHTML($mapserver_url) ]}">Mapserver</a> visualisiert.</div>
EOF
    }
}

sub teaser_dobli {
    <<EOF;
<div style="text-align:center; width:100%;"><a href="http://www.semlin.de/dobli"><img border="0" src="http://www.tagesspiegel.de/dobli/bilder/kampagne170.gif" alt="Dobli-Spiegel" /></a></div>
EOF
}

sub teaser_wap {
    <<EOF;
<div class="teaser">Experimentell - BBBike über WAP: <a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_WAP) ]}">@{[ CGI::escapeHTML($BBBike::BBBIKE_WAP) ]}</a></div>
EOF
}

sub teaser_radzeit {
    <<EOF;
<div class="teaser"><a href="http://www.radzeit.de"><!--img src="http://www.radzeit.de/uploads/images/1/thumb-RadZeit_Logo2.gif" width="100" height="21"--><b>Radzeit.de</b></a></div>
EOF
}

sub teaser_beta {
    if (!$is_beta) {
	<<EOF;
<div class="teaser">Was gibt es in der <a href="$bbbike_url?info=1#beta" style="font-weight:bold;">nächsten Version</a> von www.bbbike.de?</div>
EOF
    } else {
	();
    }
}

1;

__END__
