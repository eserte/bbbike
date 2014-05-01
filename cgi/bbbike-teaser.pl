# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005,2006,2008,2009,2010,2011,2012,2013,2014 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@users.sourceforge.net
# WWW:  http://bbbike.sourceforge.net
#

sub _teaser_beta_html (;$);
sub _teaser_new_html (;$);
sub _teaser_is_current ($);

######################################################################
#
# Teaser for bbbike.cgi
#
sub teaser {
    my %teasers_optional;
    my %teasers_mandatory;

    $teasers_optional{"de"}  = [
				'teaser_link',
				#'teaser_collecting_tracks',
			       ];
    $teasers_mandatory{"de"} = [
				#teaser_maintenance(), # schaltet sich selbstständig ab
				teaser_marathon(), # schaltet sich selbstständig ab
				teaser_halbmarathon(), # schaltet sich selbstständig ab
				teaser_velothon(), # schaltet sich selbstständig ab
				teaser_sternfahrt_adfc(), # schaltet sich selbstständig ab
				teaser_kreisfahrt_adfc(), # schaltet sich selbstständig ab
				teaser_ios1(),
				teaser_android0(),
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				#teaser_other_cities(),
				teaser_other_cities_tagcloud(),
				teaser_beta(),
				#teaser_mapserver(),
				#teaser_fahrradstadt(),
				#_teaser_is_iphone() ? teaser_iphone() : (),
				teaser_twitter(),
			       ];
    $teasers_optional{"en"} = [],
    $teasers_mandatory{"en"} = [
				#teaser_maintenance(), # schaltet sich selbstständig ab
				teaser_marathon(), # schaltet sich selbstständig ab
				teaser_halbmarathon(), # schaltet sich selbstständig ab
				teaser_velothon(), # schaltet sich selbstständig ab
				teaser_sternfahrt_adfc(), # schaltet sich selbstständig ab
				teaser_kreisfahrt_adfc(), # schaltet sich selbstständig ab
				teaser_ios1(),
				teaser_android0(),
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				#teaser_other_cities(),
				teaser_other_cities_tagcloud(),
				#teaser_beta(), # XXX There's no beta version in English yet!
				#teaser_mapserver(),
				#_teaser_is_iphone() ? teaser_iphone() : (),
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
    my $out_of_date = $today gt "20140601";
    if (!$out_of_date) {
	my $url = "http://www.adfc-berlin.de/aktionenprojekte/sternfahrt/sternfahrt-2014.html";
	<<EOF
<div class="teaser" style="font-size:larger;"><a href="$url"><b>Sternfahrt ${year}</b></a> am 1. Juni $year</div>
EOF
    } else {
	();
    }
}

sub teaser_kreisfahrt_adfc {
    my $year = (localtime)[5]+1900;
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    my $out_of_date = $today lt "20130910" || $today gt "20130921";
    if (!$out_of_date) {
	my $adfc_url    = "http://www.adfc-berlin.de/aktionenprojekte/kreisfahrt/kreisfahrt-2013/1376-kreisfahrt-2013.html";
	my $kreisfahrt_img = "/BBBike/misc/kreisfahrt_anyyear/kreisfahrt_anyyear.png";
	<<EOF
<div class="teaser"><a style="text-decoration:none;" href="$adfc_url"><img src="$kreisfahrt_img" alt="ADFC-Kreisfahrt ${year}" border="0"" /></a> am 21. September $year</div>
EOF
    } else {
	();
    }
}

sub teaser_marathon {
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    my $out_of_date = $today gt "20130929";
    if (!$out_of_date) {
	my $marathon_map_url = 'http://www.bmw-berlin-marathon.com/event/streckensperrungen.html';
	<<EOF
<div class="teaser" style="font-weight:bold">Am 28. und 29. September findet der Marathon statt.<br/>
<a href="$marathon_map_url">Karte mit den Sperrungen</a></div>
EOF
    } else {
	();
    }
}

sub teaser_halbmarathon {
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    my $out_of_date = $today gt "20140330";
    if (!$out_of_date) {
	my $halbmarathon_map_url = 'http://www.berliner-halbmarathon.de/event/streckesperrungen.html';
	if ($lang eq 'en') {
	    <<EOF
<div class="teaser" style="font-weight:bold">BERLIN HALF MARATHON on 30 March 2014<br/>
<a href="$halbmarathon_map_url">Map with blockings</a></div>
EOF
	} else {
	    <<EOF
<div class="teaser" style="font-weight:bold">Am 30. März findet der Berliner Halbmarathon statt.<br/>
<a href="$halbmarathon_map_url">Karte mit den Sperrungen</a></div>
EOF
	}
    } else {
	();
    }
}

sub teaser_velothon {
    my @l = localtime; $l[4]++;$l[5]+=1900;
    my $today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    my $out_of_date = $today ge "20130610";
    if (!$out_of_date) {
	my $velothon_map_url = "http://files.upsolut.de/velothon/maps/sperr.php";
	my $date_spec = $today eq '20130609' ? 'Heute' : 'Am Sonntag, den 9. Juni 2013';
	<<EOF
<div class="teaser" style="font-weight:bold">$date_spec findet der Velothon statt.<br/>
<a href="$velothon_map_url">Karte mit den Sperrungen</a></div>
EOF
    } else {
	();
    }
}

sub teaser_perltk_newrelease {
    if ($lang eq 'en') {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.en.html";
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac OS X and Windows.<br /><a href="@{[ CGI::escapeHTML($download_link) ]}" class="new" style="font-weight:bold;">NEW (March 2013): version 3.18 for Linux, Unix, Mac OS X, Windows</a></div>
EOF
} else {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.de.html";
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.<br /><a class="new" href="@{[ CGI::escapeHTML($download_link) ]}" style="font-weight:bold;">NEU (März 2013): Version 3.18 für Linux, Unix, Mac OS X, Windows</a></div>
EOF
    }
}

sub teaser_perltk {
    if ($lang eq 'en') {
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.en.html">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac OS X and Windows.</div>
EOF
    } else {
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.de.html">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. Läuft auf Linux, Un*x, Mac OS X und Windows.</div>
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
    my $twitter_url = "http://twitter.com/BBBikeDE/";
    my $twitter_img = "$bbbike_images/logo_twitter_withbird_60_allblack.png";
    my $teaser;
    if (0) { # purely textual
	if ($lang eq 'en') {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE @ Twitter</a></div>
EOF
	} else {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE bei Twitter</a></div>
EOF
	}
    } else { # graphical
	if ($lang eq 'en') {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE @ <img border="0" src="$twitter_img" alt="Twitter"></a></div>
EOF
	} else {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE bei <img border="0" src="$twitter_img" alt="Twitter"></a></div>
EOF
	}
    }
    $teaser;
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
<div class="teaser">Was gibt es in der <a href="$bbbike_url?info=1#beta" style="font-weight:normal;">nächsten Version</a> von www.bbbike.de?<br></div>
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

sub teaser_other_cities_tagcloud {
    my $url = "http://www.bbbike.org/";
    my $lang = $lang eq 'en' ? 'en' : 'de';
    my $teaser = "";
    if ($lang eq 'en') {
	$teaser .= <<EOF;
<span class="teaser">BBBike for <a href="http://www.bbbike.org/">other</a> cities:</span>
EOF
    } else {
	$teaser .= <<EOF;
<span class="teaser">BBBike für <a href="http://www.bbbike.org/">weitere</a> Städte:</span>
EOF
    }
    $teaser .= <<"EOF";
<span class="htmltagcloud">
<span class="tagcloud4"><a href="http://www.bbbike.org/$lang/BrandenburgHavel/">Brandenburg (Havel)</a></span>
<span class="tagcloud5"><a href="http://www.bbbike.org/$lang/Cottbus/">Cottbus</a></span>
<span class="tagcloud6"><a href="http://www.bbbike.org/$lang/Dresden/">Dresden</a></span>
<span class="tagcloud5"><a href="http://www.bbbike.org/$lang/FrankfurtOder/">Frankfurt (Oder), M&auml;rkische Schweiz</a></span>
<span class="tagcloud6"><a href="http://www.bbbike.org/$lang/Leipzig/">Leipzig</a></span>
<span class="tagcloud4"><a href="http://www.bbbike.org/$lang/Oranienburg/">Oranienburg Uckermark</a></span>
<span class="tagcloud5"><a href="http://www.bbbike.org/$lang/Potsdam/">Potsdam-Mittelmark, Fl&auml;ming</a></span>
<span class="tagcloud4"><a href="http://www.bbbike.org/$lang/Usedom/">Usedom</a></span>
<span class="tagcloud3"><a href="http://www.bbbike.org/$lang/WarenMueritz/">Waren (M&uuml;ritz)</a></span>
<span class="tagcloud3"><a href="http://www.bbbike.org/$lang/Ruegen/">R&uuml;gen</a></span>
<a href="http://www.bbbike.org/">...</a>
</span>
EOF
    $teaser;
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

sub teaser_maintenance {
    my $maintenance_end = 1297843200; # Wed Feb 16 09:00:00 2011
    if (time < $maintenance_end
	&& time > $maintenance_end-10*86400
	&& $ENV{SERVER_NAME} =~ m{(bbbike\.de|bbbike\.hosteurope)$}
       ) {
	<<EOF;
<div class="teaser">
<b>Wartungsarbeiten</b><br>
Von 15.02.2011 23:00 Uhr bis 16.02.2011 09:00 wird $ENV{SERVER_NAME}
wegen Wartungsarbeiten kurzzeitig nicht verfügbar sein.
</div>
EOF
    } else {
	();
    }
}

sub teaser_android0 {
    my $url = "https://play.google.com/store/apps/details?id=org.selfip.leinad.android.bbbike";
    if ($lang eq 'en') {
	<<EOF;
<div class="teaser">
  <a href="$url"><b>BBBike for Android phones</b></a>
</div>
EOF
    } else {
	<<EOF;
<div class="teaser">
  <a href="$url"><b>BBBike auf Android</b></a>
</div>
EOF
    }
}

sub teaser_ios1 {
    my $baseurl = "https://itunes.apple.com/de/app/bbybike-made-in-berlin-for/id639384862?mt=8";
    my $new_until = "2013-07-01";
    if ($lang eq 'en') {
	my $url = "$baseurl&amp;l=en";
	<<EOF;
<div class="teaser">
  <a href="$url"><b>bbybike for iPhone</b></a> @{[ _teaser_new_html $new_until ]} &#x2014; using the BBBike routing engine
</div>
EOF
    } else {
	my $url = "$baseurl&amp;l=de";
	<<EOF;
<div class="teaser">
  <a href="$url"><b>bbybike auf iPhone</b></a> @{[ _teaser_new_html $new_until ]} &#x2014; verwendet die BBBike-Routensuche
</div>
EOF
    }
}

sub _teaser_beta_html (;$) {
    my $until = shift;
    return if !_teaser_is_current($until);
    q{<span style="font:xx-small sans-serif; border:1px solid red; padding:1px 2px 0px 2px; background-color:yellow; color:black;">BETA</span>};
}

sub _teaser_new_html (;$) {
    my $until = shift;
    return if !_teaser_is_current($until);
    q{<span style="font:xx-small sans-serif; border:1px solid red; padding:1px 2px 0px 2px; background-color:yellow; color:black;">NEW</span>};
}

sub _teaser_is_current ($) {
    my $until = shift; # until _including_
    if ($until) {
	my @l = localtime; $l[4]++; $l[5]+=1900;
	my $now = sprintf "%04d-%02d-%02d", @l[5,4,3];
	return $now le $until;
    } else {
	return 1;
    }
}

1;

__END__
