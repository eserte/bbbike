# -*- perl -*-

#
# $Id: bbbike-teaser.pl,v 1.31 2009/04/04 11:12:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005,2006,2008,2009,2010 Slaven Rezic. All rights reserved.
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
				'teaser_link',
				'teaser_wap',
				'teaser_collecting_tracks',
				#'teaser_dobli',
			       ];
    $teasers_mandatory{"de"} = [
				teaser_other_cities(),
				teaser_sternfahrt_adfc(), # schaltet sich selbstständig ab
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				teaser_beta(),
				teaser_mapserver(),
				#teaser_fahrradstadt(),
				#teaser_collecting_tracks(),
				#teaser_sternfahrt(),
				#teaser_kreisfahrt(),
				#teaser_sternfahrt_changes(),
				#teaser_dobli(),
				_teaser_is_iphone() ? teaser_iphone() : (),
				teaser_twitter(),
			       ];
    $teasers_optional{"en"} = [],
    $teasers_mandatory{"en"} = [
				teaser_other_cities(),
				teaser_sternfahrt_adfc(), # schaltet sich selbstständig ab
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				#teaser_beta(), # XXX There's no beta version in English yet!
				teaser_mapserver(),
				#teaser_collecting_tracks(),
				#teaser_sternfahrt(),
				#teaser_kreisfahrt(),
				#teaser_sternfahrt_changes(),
				#teaser_dobli(),
				_teaser_is_iphone() ? teaser_iphone() : (),
				teaser_twitter(),
			       ];

    my $use_lang = $lang eq 'en' ? "en" : "de";
    my $teaser_optional = $teasers_optional{$use_lang}->[int(rand(@{$teasers_optional{$use_lang}}))];
    my $t;
    if ($teaser_optional) {
	my $sub = $teaser_optional;
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

sub teaser_sternfahrt_adfc {
    my $year = (localtime)[5]+1900;
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    my $out_of_date = $today gt "20100601";
    if (!$out_of_date) {
	my $url = "http://www.adfc-berlin.de/aktionenprojekte/sternfahrt/sternfahrt-$year.html";
	<<EOF
<div class="teaser" style="font-size:larger;"><a href="$url"><b>Sternfahrt ${year}</b></a> am 6.&nbsp;Juni&nbsp;$year</div>
EOF
    } else {
	();
    }
}

sub teaser_sternfahrt {
    my $year = (localtime)[5]+1900;
    my $url = "http://bbbike.de/mapserver/brb/sternfahrt${year}_init.html";
    <<EOF
<div class="teaser"><a style="text-decoration:none;" href="$url"><img style="padding:3px 0px 3px 0px; border:0px;" src="$bbbike_images/stern${year}_titel.jpg" border="0"></a><br><a href="$url">Die Routen der Sternfahrt ${year}</a></div>
EOF
}

sub teaser_sternfahrt_changes {
    my $year = (localtime)[5]+1900;
    if ($year == 2007) {
	my $url = "$mapserver_address_url?coords=-11971,57&&layer=bahn&layer=gewaesser&layer=faehren&layer=flaechen&layer=grenzen&layer=orte&layer=sternfahrt&layer=treffpunkte&msmap=sternfahrt$year";
	<<EOF
<div class="teaser"><b>Sternfahrt:</b><br> <a href="$url">Änderung der Routen im Bereich Potsdam</a><br>(betrifft die Routen Brandenburg, Werder und Rehbrücke)</div>
EOF
    }
}

sub teaser_kreisfahrt {
    my $year = (localtime)[5]+1900;
    my $radzeit_url    = "http://www.adfc-berlin.de/home/termine2/kreisfahrt";
    my $mapserver_url  = "/BBBike/misc/kreisfahrt_2007/kreisfahrt2007.html";
    my $googlemaps_url = "/BBBike/misc/kreisfahrt_2007/kreisfahrt2007_googlemaps.html";
    <<EOF
<div class="teaser"><a style="text-decoration:none;" href="$radzeit_url"><img style="padding:3px 0px 3px 0px; border:0px;" src="/BBBike/misc/kreisfahrt_2007/kreisfahrt2007_titel.png" border="0"></a><br>Die Route der Kreisfahrt ${year}:<br><a href="$googlemaps_url">Googlemaps</a> <a href="$mapserver_url">Mapserver</a></div>
EOF
}

sub teaser_perltk_newrelease {
    if ($lang eq 'en') {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.en.html";
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac OS X and Windows.<br /><a href="@{[ CGI::escapeHTML($download_link) ]}" class="new" style="font-weight:bold;">NEW: Version @{[ CGI::escapeHTML($BBBike::STABLE_VERSION) ]}</a></div>
EOF
} else {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.de.html";
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.<br /><a class="new" href="@{[ CGI::escapeHTML($download_link) ]}" style="font-weight:bold;">NEU: Version @{[ CGI::escapeHTML($BBBike::STABLE_VERSION) ]}</a></div>
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

sub teaser_collecting_tracks {
    <<EOF;
<div class="teaser">Ich sammele GPS-Tracks von Berlin und Brandenburg. Bitte per Mail an <a target="_top" href="mailto:@{[ CGI::escapeHTML($BBBike::EMAIL) ]}?subject=BBBike-GPS">Slaven Rezic</a> schicken.</div>
EOF
}

sub teaser_link {
    <<EOF;
<div class="teaser"><a href="$bbbike_url?info=1#link">Link auf BBBike setzen</a></div>
EOF
}

sub teaser_twitter {
    if (1) { # purely textual
	if ($lang eq 'en') {
	    <<'EOF';
<div class="teaser"><a href="http://twitter.com/BBBikeDE/">BBBikeDE @ Twitter</a>
</div>
EOF
	} else {
	    <<'EOF';
<div class="teaser">
<a href="http://twitter.com/BBBikeDE/">BBBikeDE bei Twitter</a>
</div>
EOF
	}
    } else { # graphical
	if ($lang eq 'en') {
	    <<EOF;
<div class="teaser">
<a href="http://twitter.com/BBBikeDE/"><img style="border:0px;" src="http://www.bbbike.org/images/tweetn.png" title="Follow BBBike on Twitter" alt=""></a>
</div>
EOF
	} else {
	    <<EOF;
<div class="teaser">
<a href="http://twitter.com/BBBikeDE/"><img style="border:0px;" src="http://www.bbbike.org/images/tweetn.png" title="Folge BBBike auf Twitter" alt=""></a>
</div>
EOF
	}
    }
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

sub teaser_beta {
    if (!$is_beta) {
	if ($lang eq 'en') {
	    return ();
	    # XXX There's no beta version in English yet!
	    <<EOF;
<div class="teaser">What's new in the <a href="$bbbike_url?info=1#beta" style="font-weight:normal;">next version</a> of www.bbbike.de?</div>
EOF
	} else {
	    <<EOF;
<div class="teaser">Was gibt es in der <a href="$bbbike_url?info=1#beta" style="font-weight:normal;">nächsten Version</a> von www.bbbike.de?<br><b>NEU</b>: wahlweise Benutzung von Fähren</div>
EOF
	}
    } else {
	();
    }
}

sub teaser_fahrradstadt {
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $out_of_date = $l[5]>=2009 || $l[4]>=5;
    if (!$out_of_date) {
	<<EOF;
<div class="teaser">
BBBike: Auszeichnung "<b>FahrradStadtBerlin 2007</b>" für Verdienste um die Förderung des Radverkehrs<br/>
<a href="http://www.stadtentwicklung.berlin.de/aktuell/pressebox/archiv_volltext.shtml?arch_0801/nachricht2936.html">Pressemitteilung</a><br/>
<img src="$bbbike_images/logo-fahrradstadt_75.png"><br/>
</div>
EOF
    } else {
	();
    }
}

sub teaser_other_cities {
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $is_new = $l[5]<2010 && $l[4]<5;
    my $url = "http://www.bbbike.org/";
    if ($lang eq 'en') {
	<<EOF;
<div class="teaser">
  <a href="$url" style="font-weight:bold;">BBBike \@ World</a><br/>BBBike for other cities
</div>
EOF
    } else {
	<<EOF;
<div class="teaser">
  <a href="$url" style="font-weight:bold;">BBBike \@ World</a><br/>BBBike für andere Städte
</div>
EOF
    }
}

sub teaser_iphone {
    my $url = "$bbbike_html/bbbike_tracks_iphone.html";
    if ($lang eq 'en') {
	<<EOF;
<div class="teaser">
  Tutorial: <a href="$url">Load BBBike tracks to iPhone</a> (sorry, German only)
</div>
EOF
    } else {
	<<EOF;
<div class="teaser">
  Anleitung: <a href="$url">BBBike-Tracks unterwegs auf das iPhone laden</a>
</div>
EOF
    }
}

sub _teaser_is_iphone { $ENV{HTTP_USER_AGENT} =~ m{\biPhone\b} }

1;

__END__
