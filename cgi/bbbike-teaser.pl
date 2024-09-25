# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2003,2004,2005,2006,2008,2009,2010,2011,2012,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

use strict;
use vars qw($lang $bbbike_url $bbbike_images $bbbike_script $bbbike_html $can_mapserver $mapserver_init_url $is_beta $fake_time);

sub _teaser_beta_html (;$);
sub _teaser_new_html (;$);
sub _teaser_is_current ($);

my $today;
my $year;

######################################################################
#
# Teaser for bbbike.cgi
#
sub teaser {
    my %teasers_optional;
    my %teasers_mandatory;

    local $fake_time = $fake_time || time;
    {
	my @l = localtime($fake_time); $l[4]++; $l[5]+=1900;
	$year = $l[5];
	$today = sprintf "%04d%02d%02d", $l[5], $l[4], $l[3];
    }

    $teasers_optional{"de"}  = [
				'teaser_link',
				#'teaser_collecting_tracks',
			       ];
    $teasers_mandatory{"de"} = [
				teaser_maintenance(), # schaltet sich selbstst�ndig ab
				teaser_marathon(), # schaltet sich selbstst�ndig ab
				teaser_halbmarathon(), # schaltet sich selbstst�ndig ab
				teaser_velocity(), # schaltet sich selbstst�ndig ab
				teaser_sternfahrt_adfc(), # schaltet sich selbstst�ndig ab
				teaser_kreisfahrt_adfc(), # schaltet sich selbstst�ndig ab
				teaser_ios1(),
				# teaser_android0(), # XXX nicht mehr im Playstore?
				teaser_wp0(),
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				#teaser_other_cities(),
				teaser_other_cities_tagcloud(),
				teaser_beta(),
				#teaser_mapserver(),
				#teaser_fahrradstadt(),
				#teaser_twitter(),
			       ];
    $teasers_optional{"en"} = [],
    $teasers_mandatory{"en"} = [
				teaser_maintenance(), # schaltet sich selbstst�ndig ab
				teaser_marathon(), # schaltet sich selbstst�ndig ab
				teaser_halbmarathon(), # schaltet sich selbstst�ndig ab
				teaser_velocity(), # schaltet sich selbstst�ndig ab
				teaser_sternfahrt_adfc(), # schaltet sich selbstst�ndig ab
				teaser_kreisfahrt_adfc(), # schaltet sich selbstst�ndig ab
				teaser_ios1(),
				# teaser_android0(), # XXX nicht mehr im Playstore?
				teaser_wp0(),
				(0 ? teaser_perltk_newrelease() : teaser_perltk()),
				#teaser_other_cities(),
				teaser_other_cities_tagcloud(),
				#teaser_beta(), # XXX There's no beta version in English yet!
				#teaser_mapserver(),
				#teaser_twitter(),
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
    my $out_of_date = $today gt "20240602";
    if (!$out_of_date) {
	my $url = "https://berlin.adfc.de/artikel/adfc-sternfahrt-2024";
	<<EOF
<div class="teaser" style="font-size:larger;"><a href="$url"><b>Sternfahrt ${year}</b></a> am 2.�Juni�$year</div>
EOF
    } else {
	();
    }
}

sub teaser_kreisfahrt_adfc {
    my $out_of_date = $today lt "20240907" || $today gt "20240921";
    if (!$out_of_date) {
	my $adfc_url    = "https://touren-termine.adfc.de/radveranstaltung/134855-adfc-kreisfahrt-2024";
	my $kreisfahrt_img = "/BBBike/misc/kreisfahrt_anyyear/kreisfahrt_anyyear.png";
	<<EOF
<div class="teaser"><a style="text-decoration:none;" href="$adfc_url"><img src="$kreisfahrt_img" alt="ADFC-Kreisfahrt ${year}" border="0" style="position: relative; top: 3px;" /></a> am 21.�September�$year</div>
EOF
    } else {
	();
    }
}

sub teaser_marathon {
    my $out_of_date = $today lt "20240920" || $today gt "20240929";
    if (!$out_of_date) {
	my $marathon_map_url = 'https://www.bmw-berlin-marathon.com/dein-rennen/strecke/interaktive-karte/';
	my $skating_map_url  = 'https://skating.bmw-berlin-marathon.com/dein-rennen/strecke/interaktive-karte/';
	<<EOF
<div class="teaser" style="font-weight:bold">Am 28. und 29. September 2024 findet der Marathon statt.<br/>
Karten mit den Strecken &mdash; hier gibt es m&ouml;gliche Sperrungen:
<ul style="margin-top:1px; margin-bottom:1px; padding-left:20px;">
 <li><a href="$skating_map_url">Samstag</a></li>
 <li><a href="$marathon_map_url">Sonntag</a></li>
</ul>
</div>
EOF
    } else {
	();
    }
}

sub teaser_halbmarathon {
    my $out_of_date = $today gt "20220403";
    if (!$out_of_date) {
	my $halbmarathon_map_url = 'https://viz.berlin.de/2022/03/halbmarathon/';
	if ($lang eq 'en') {
	    <<EOF
<div class="teaser" style="font-weight:bold">BERLIN HALF MARATHON on 03 April 2022<br/>
<a href="$halbmarathon_map_url">Map with blockings</a></div>
EOF
	} else {
	    <<EOF
<div class="teaser" style="font-weight:bold">Am 3. April 2022 findet der Berliner Halbmarathon statt.<br/>
<a href="$halbmarathon_map_url">Karte mit den Sperrungen</a></div>
EOF
	}
    } else {
	();
    }
}

sub teaser_velocity {
    my $velocity_activation_day = "20240725";
    my $velocity_end_day = "20240804";
    my $out_of_date = ($today gt $velocity_end_day) || ($today lt $velocity_activation_day);
    if (!$out_of_date) {
	my $velocity_map_url = "https://velocity.berlin/event/strecken";
	my $date_spec = $today eq $velocity_end_day ? 'Heute' : "Am 03. & 04. August $year";
	<<EOF
<div class="teaser"><div style="font-weight:bold">$date_spec findet die VeloCity statt.<br/>
<a href="$velocity_map_url">Karte mit den Sperrungen</a></div> (Achtung, Sperrungen sind nicht in BBBike ber�cksichtigt!)</div>
EOF
    } else {
	();
    }
}

sub teaser_perltk_newrelease {
    if ($lang eq 'en') {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.en.html";
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac�OS�X and Windows.<br /><a href="@{[ CGI::escapeHTML($download_link) ]}" class="new" style="font-weight:bold;">NEW (March 2013): version 3.18 for Linux, Unix, Mac�OS�X, Windows</a></div>
EOF
} else {
	my $download_link = "$BBBike::BBBIKE_SF_WWW/downloads.de.html";
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($download_link) ]}">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. L�uft auf Linux, Un*x, Mac�OS�X und Windows.<br /><a class="new" href="@{[ CGI::escapeHTML($download_link) ]}" style="font-weight:bold;">NEU (M�rz 2013): Version 3.18 f�r Linux, Unix, Mac�OS�X, Windows</a></div>
EOF
    }
}

sub teaser_perltk {
    if ($lang eq 'en') {
    	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.en.html">Download</a> the offline version of BBBike (Perl/Tk) with interactive map. Runs on Linux, Un*x, Mac�OS�X and Windows.</div>
EOF
    } else {
	<<EOF;
<div class="teaser"><a href="@{[ CGI::escapeHTML($BBBike::BBBIKE_SF_WWW) ]}/downloads.de.html">Download</a> der Offline-Version von BBBike (Perl/Tk) mit interaktiver Karte. L�uft auf Linux, Un*x, Mac�OS�X und Windows.</div>
EOF
    }
}

sub teaser_none { "" }

sub teaser_collecting_tracks {
    $BBBike::EMAIL = $BBBike::EMAIL if 0; # cease -w
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
    my $teaser;
    { # purely textual
	if ($lang eq 'en') {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE @ Twitter</a></div>
EOF
	} else {
	    $teaser = <<EOF;
<div class="teaser"><a href="$twitter_url">BBBikeDE bei Twitter</a></div>
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
<div class="teaser">Was gibt es in der <a href="$bbbike_url?info=1#beta" style="font-weight:normal;">n�chsten Version</a> von www.bbbike.de?<br></div>
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
BBBike: Auszeichnung "<b>FahrradStadtBerlin 2007</b>" f�r Verdienste um die F�rderung des Radverkehrs<br/>
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
  <a href="$url" style="font-weight:bold;">BBBike \@ World</a><br/>BBBike f�r andere St�dte
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
<span class="teaser">BBBike f�r <a href="http://www.bbbike.org/">weitere</a> St�dte:</span>
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

sub teaser_maintenance {
    my $maintenance_end = 1727935200; # 2024-10-03 08:00:00
    if (time < $maintenance_end
	&& time > $maintenance_end-10*86400 # 10 Tage vorher
	&& $ENV{SERVER_NAME} =~ m{(bbbike\.de|bbbike\.hosteurope)$}
       ) {
	<<EOF;
<div class="teaser">
<b>Wartungsarbeiten</b><br>
Von 02. Oktober 2024 08:00 Uhr bis 03. Oktober 2024 08:00 Uhr wird $ENV{SERVER_NAME}
wegen Wartungsarbeiten f�r einige Stunden nicht verf�gbar sein.
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

sub teaser_wp0 {
    my $baseurl = "http://www.windowsphone.com/s?appid=6cc2f571-7c0e-414c-9e71-806162601d7a";
    my $new_until = "2014-11-22";
    if ($lang eq 'en') {
	my $url = $baseurl;
	<<EOF;
<div class="teaser">
  <a href="$url"><b>bbbike for Windows Phone</b></a> @{[ _teaser_new_html $new_until ]}
</div>
EOF
    } else {
	my $url = $baseurl;
	<<EOF;
<div class="teaser">
  <a href="$url"><b>bbbike f�r Windows Phone</b></a> @{[ _teaser_new_html $new_until ]}
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
