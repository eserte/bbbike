#!/usr/local/bin/perl -w
# -*- perl -*-

#
# $Id: convert_berlinmap.pl,v 1.43 2007/08/02 21:55:32 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998,2003 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net/
#

# Hiermit können die Koeffizienten für die lineare Regression berechnet werden

package BBBike::Convert;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin",
	 "$FindBin::RealBin/../lib",
	);
use Cov;
use Getopt::Long;
use strict;

my @berlinmap_data = split(/\n/, <<'EOF');
# real (hafas)	berlinmap
-6454,1118	2336,11780	# Pfaueninselchaussee/Königstr.
-6808,1048	2190,11808	# Rathaus Wannsee
-5497,1305	2730,11711	# Am Kl. Wannsee/Am Gr. Wannsee
-5662,2566	2673,11213	# Jugenderholungsheim
29059,3327	16848,11195	# Müggelhort
29381,3873	16977,11029	# Müggelwerderweg
-8269,4225	1622,10525	# Kaserne Hottengrund
 2392,25125	6166,2147	# S Frohnau
 4704,10572	6963,8065	# Bleibtreustr.
 6986,865	7806,12012	# Weskammstr.
 12038,7861	9914,9157	# Herrfurthstr.
 16850,13474	11958,6967	# Herzbergstr./Siegfriedstr.
 20936,14844	13629,6470	# Adersleber Weg
 25976,2327	15551,11597	# Rübezahl
EOF

my @new_berlinmap_data = split(/\n/, <<'EOF');
# real (hafas)	new berlinmap
-6454,1118	2199,11147	# Pfaueninselchaussee/Königstr.
-6808,1048	2062,11171	# Rathaus Wannsee
#-5497,1305	2730,11711	# Am Kl. Wannsee/Am Gr. Wannsee
-5662,2566	2519,10610	# Jugenderholungsheim
29059,3327	15872,10597	# Müggelhort
29381,3873	16001,10427	# Müggelwerderweg
#-8269,4225	1622,10525	# Kaserne Hottengrund
 2392,25125	5816,2048	# S Frohnau
# 4704,10572	6963,8065	# Bleibtreustr.
# 6986,865	7806,12012	# Weskammstr.
# 12038,7861	9914,9157	# Herrfurthstr.
 16850,13474	11270,6594	# Herzbergstr./Siegfriedstr.
 20936,14844	12819,6176	# Adersleber Weg
# 25976,2327	15551,11597	# Rübezahl
EOF

my @newnew_berlinmap_data = split(/\n/, <<'EOF');
# real (hafas)	new berlinmap
8172,11679	8872,8103	# Kemperplatz
8075,12185	8833,7881	# Entlastungsstr./17. Juni
#-2230,16460	4459,5909	# Wasserstadt Spandau, vor der Brücke
-2984,17050	4119,5683	# Rauch/Streitstr.
8775,12457	9142,7772	# Dorotheen/Wilhelmstr.
677,9092	5610,9140	# Schmetterlingplatz (S-Bhf. Grunewald)
EOF

my @satmap_data  = split(/\n/, <<'EOF');
# berlinmap	satmap
581,12013	76,1489		# Glienicker Brücke
8796,8821	1085,1092	# Platz der Luftbrücke
8827,13169	1087,1632	# Knick Lichtenrade-West
8112,4014	999,500		# Mauer/Nordgraben
12996,6996	1595,866	# Springpfuhl/Allee der Kosmonauten
18216,11746	2237,1450	# Dämeritzsee/Spree
3957,3519	488,442		# Heiligensee/Brücke
EOF

my @satmap2_data = split(/\n/, <<'EOF');
# hafas	satmap
-10718,450	76,1489		# Glienicker Brücke
9222,8777	1085,1092	# Platz der Luftbrücke
#8827,13169	1087,1632	# Knick Lichtenrade-West
#8112,4014	999,500		# Mauer/Nordgraben
19412,13512	1595,866	# Springpfuhl/Allee der Kosmonauten
32475,2081	2237,1450	# Dämeritzsee/Spree
-2953,21595	488,442		# Heiligensee/Brücke
EOF

my @gismap_data_old = split(/\n/, <<'EOF');
# hafas		gismap (source = eplus)
9349,12344	6110,5052	# Unter den Linden/Friedrichstr.
9222,8777	6104,5219	# Platz der Luftbrücke
842,3060	5710,5487	# Clayallee/Berliner Str.
-10735,459	5169,5609	# Glienicker Brücke
1470,21205	5742,4638	# Karolinen/Heiligenseestr.
9249,23669	6108,4522	# Blankenfelde
18240,13521	6528,5000	# Rhin/Allee der Kosmonauten
25596,5983	6870,5353	# Fürstenwalder Damm/S-Freidrichshagen
10844,-1335	6180,5696	# Lichtenrader Damm/Barnetstr.
EOF

# additional coordinates from GPS
my @gismap_data = split(/\n/, <<'EOF');
# DMS		gismap (source = eplus)
N51 46 12.4	E12 00 00.5	1697,8987	# bei Köthen B185/B187a
N51 20 37.6	E11 59 18.1	1662,11216	# Merseburg, Ri. Kötzschen
N51 13 00.7	E11 58 08.2	1593,11875	# Weissenfels, Ri. Leuna
N51 50 12.4	E12 16 02.7     2559,8640	# Dessau, Ri. Vockerau

N53 18 17.5	E13 53 01.1	7576,903	# B198+Penkun
N53 18 49.1	E13 51 41.9	7504,865	# Prenzlau+B109+B198
N53 18 13.0	E14 02 32.4	8069,899	# Penkun-Prenzlau+Cramzow

N53 16 55.1	E13 47 11.8	7276,1031	# B109+Lychen
N53 06 31.4	E13 38 27.1	6843,1946	# Milmersdorf Kreuzung
N53 00 04.5	E13 35 46.1	6711,2510	# B109+Groß-Dölln
N52 47 49.8	E13 28 46.0	6370,3584	# B109+Kreuzbruch
N52 30 37.8	E13 23 23.7	6114,5087	# LEIPZIGER FRIEDRICH
N52 31 02.1	E13 23 20.4	6110,5052	# Unter den Linden/Friedrichstr.
N52 31 31.1	E13 25 13.1	6208,5008	# Otto-Braun+Moll
N52 24 21.0	E13 00 51.0	4928,5651	# Am Neuen Palais/Maulbeerallee
N52 30 19.1	E13 34 54.0	6726,5100	# Chemnitzer Str.+Alt-Kaulsdorf+Dorfstr.
N52 36 08.2	E13 25 50.9	6238,4605	# BLANKENFELDER BERLINER

#  9222,8777	6104,5219	# Platz der Luftbrücke
#  842,3060	5710,5487	# Clayallee/Berliner Str.
#  -10735,459	5169,5609	# Glienicker Brücke
#  1470,21205	5742,4638	# Karolinen/Heiligenseestr.
#  9249,23669	6108,4522	# Blankenfelde
#  18240,13521	6528,5000	# Rhin/Allee der Kosmonauten
#  25596,5983	6870,5353	# Fürstenwalder Damm/S-Freidrichshagen
#  10844,-1335	6180,5696	# Lichtenrader Damm/Barnetstr.
EOF

#XXX ist das hier gut?
my @polar_data_old = split(/\n/, <<'EOF');
# hafas		polar (DDD, WGS84)
1506,10212	13.2719993666667,52.4987965833333	# Deutschlandhalle
-4931,1287	13.1760352833333,52.419945	# Königs/Krone (Wannsee)
-6800,1050	13.1474697666667,52.4182015666667	# Rath. Wannsee
-7190,429	13.1419175833333,52.4127084	# Schäferstr./Friedenstr.
-7172,-1048	13.1403082666667,52.39962995	# Neue Kreisstr./Bäkestr.
-7030,-1256	13.1421697166667,52.3979455166667	# Bäkestr./Königsweg
#-7956,-9873	13.1278735333333,52.3185736	# Saarmund (nördl. Kreuzung)
#-8571,-15268	13.11760605,52.2709000166667	# Tremsdorf
#-2175,-13826	13.2104158333333,52.2834098333333	# Siethen
#668,-8693	13.2537871666667,52.3299890833333	# zwischen Ahrensdorf und Neubeeren
#10139,-8277	13.39447975,52.3316574166667	# Blankenfelde, Kreuzung Mahlow-Schulzendorf
#11831,-3648	13.4207332166667,52.3728829666667	# Kreuzung B96/nach Kleinziethen
#13374,-3280	13.4432262166667,52.37656295	# Kleinziethen, südl. Kreuzung
#13249,-1250	13.4424859333333,52.3945391166667	# Großziethen, nach Rudow
EOF

# mein Tracklog: 2002-01-14 bis 17
# XXX obsolete, better use gps_polar_convert_data.pl
# XXX ^^^^^^^^ is this comment really valid???
my @polar_data = split(/\n/, <<'EOF');
# hafas		polar/eTrex (DDD, WGS84)
14444,11752	13.46414,52.51064	# GRUENBERGER BOXHAGENER
13467,11787	13.44894,52.51144	# GUBENER KOPERNIKUS
14442,11101	13.46286,52.50517	# REVALER HELMERDINGER
13594,11489	13.45094,52.50856	# WARSCHAUER REVALER
9784,9519	13.39438,52.49131	# GNEISENAU ZOSSENER
9043,9745	13.38381,52.49339	# YORCK GROSSBEEREN
7941,9686	13.36750,52.49308	# BUELOW GOEBEN
6753,10446	13.34956,52.50033	# KLEIST EISENACHER
5938,10808	13.33764,52.50358	# TAUENTZIEN MARBURGER
4245,10435	13.31289,52.50058	# LEIBNIZ KURFUERSTENDAMM
4540,11041	13.31781,52.50614	# KANT SCHLUETER
6175,10968	13.34089,52.50539	# BUDAPESTER KURFUERSTENSTR
8172,11679	13.37164,52.51133	# KEMPERPLATZ
9046,11558	13.38447,52.51008	# LEIPZIGER WILHELM
10222,11724	13.40169,52.51147	# SPITTELMARKT
11328,12040	13.41761,52.51394	# BRUECKEN MAERKISCHES UFER
11773,11993	13.42419,52.51372	# LICHTENBERGER HOLZMARKT
12584,12233	13.43626,52.51546	# RUEDERSDORFER KOPPEN
EOF

my @gis_data = split(/\n/, <<'EOF');
# hafas		gis (Gaus-Krüger)
-6808,1048	4578157,5809989	# Rathaus Wannsee (Chaussestr. 22)
-5497,1305	4579469,5810366	# Am Kl. Wannsee/Am Gr. Wannsee HNR 1
9225,8787	4594204,5817807	# Dudenstr. 2
11025,16450	4596004,5825499	# Bornholmer Str. 1
14487,16925	4599508,5825952	# Rennbahnstr. 2 XXX
22462,4462	4607622,5813391	# Müggelheimer Str. 52
EOF

# Die Hafas-Koordinaten habe ich direkt aus "strassen" und "plaetze" ausgelesen
# Die b1999-Koordinaten habe ich erzeugt, indem ich bbbike wie folgt
# eingestellt habe:
#   Ausgabe => canvas,
#   Koordinatensystem => Berlinmap-Karte 1999,
#   Karte => Berlinmap-Karte 1999
#
my @b1999_data = split(/\n/, <<'EOF');
# hafas		b1999
9349,12344	8386,6981	# UdLinden/Friedrichstr.
11170,13475	9092,6559	# Prenzlauer Tor
9443,15430	8449,5799	# Brunnenstr./Rügener Str.
9222,8787	8305,8341	# Duden/Mehringdamm
8724,8021	8109,8634	# Adolf-Scheidt-Platz
-3533,14046	3441,6220	# Altstädter Ring/Klosterstr./Seegefelder Str.
9401,10199	8389,7804	# Mehringdamm/Tempelhofer Ufer
EOF

# Die Hafas-Koordinaten habe ich direkt aus "strassen" und "plaetze" ausgelesen
# Die b2001-Koordinaten habe ich erzeugt, indem ich bbbike wie folgt
# eingestellt habe:
#   Zuerst in den Edit-Mode gehen, dann:
#   Ausgabe => canvas,
#   Koordinatensystem => Berlinmap-Karte 2001,
#   Karte => Berlinmap-Karte 2001
#
my @b2001_data = split(/\n/, <<'EOF');
# hafas		b2001
9349,12344	7678,6897	# UdLinden/Friedrichstr.
11170,13475	8380,6477	# Prenzlauer Tor
9443,15430	7736,5727	# Brunnenstr./Rügener Str.
9222,8787	7606,8246	# Duden/Mehringdamm
8724,8021	7409,8534	# Adolf-Scheidt-Platz/Manfr.-v-Richthofen-Str.
-3533,14046	2782,6157	# Altstädter Ring/Klosterstr./Seegefelder Str.
9401,10199	7684,7716	# Mehringdamm/Tempelhofer Ufer
EOF

my @b2002_data = split(/\n/, <<'EOF');
# hafas		b2002
9222,8787	8246,13285	# Duden/Mehringdamm
13919,10583	10149,12597	# Modersohn/Stralauer
13594,11489	10024,12230	# Revaler/Warschauer
9349,12344	8323,11856	# UdLinden/Friedrichstr.
11170,13475	9066,11411	# Prenzlauer Tor
8724,8021	8038,13588	# Adolf-Scheidt-Platz/Manfr.-v-Richthofen-Str.
-3533,14046	3143,11071	# Altstädter Ring/Klosterstr./Seegefelder Str.
EOF

my @p2002_data = split(/\n/, <<'EOF');
# hafas		p2002
-10568,-1895	6507,7440	# Karl-Liebknecht/Rudolf-Breitscheid
-17644,-7006	3620,9437	# Caputh/Fähre
-13858,-1433	5181,7220	# Zeppelin/Breite
-18984,-547	3133,6824	# Reiherberg/Weinmeister (Golm)
-13378,2961	5418,5464	# Amudsen/Nedlitzer (B2)
-10836,466	6415,6478	# Berliner/Schwanenallee
-7749,-2443	7635,7661	# Stein/Mendelssohn-Bartoldy
EOF

my @nbrb2004_data = split(/\n/, <<'EOF');
# polar (from my converted data)		nbrb2002
N53 33 04.5	E13 15 47.8	4059,4597	# Nbrb, Stargader Tor
N53 33 21.0	E13 16 02.3	4182,4332	# Nbrb, Demminer/Woldegker
N53 33 33.9	E13 13 34.4	3144,4302	# Nbrb, 104/Woggersiner Str
N53 33 19.5	E13 15 12.9	3847,4442	# Nbrb, Rostocker Str./Ring
N53 34 11.7	E13 16 47.3	4495,3786	# Nbrb, Ihlenfelder Knick
EOF

my @de2002_data = split(/\n/, <<'EOF');
# hafas		de2002
9222,8787	31340,13451	# Duden/Mehringdamm
-10724,492	30192,13987	# Glienicker Brücke
21954,5229	32097,13626	# Linden/Bahnhof Köpenick
-3339,14664	30591,13130	# Falkenseer Platz, Spandau
2461,25270	30904,12500	# Zeltinger Platz
EOF

# Koordinaten der Telefonbuch Berlin 1999/2000 CDROM
# Besser wäre es vielleicht, wenn die Umwandlung über die GIS-Daten
# der 1998/1999 CDROM gehen würden...
my @t99_data = split(/\n/, <<'EOF');
# hafas         telefonbuch 1999/2000 (DDD*10000)
-6808,1048	131489,524189	# Rathaus Wannsee (Chaussestr. 22)
-5497,1305	131683,524221	# Am Kl. Wannsee/Am Gr. Wannsee HNR 1
9225,8787	133869,524867	# Dudenstr. 2
11025,16450	134156,525555	# Bornholmer Str. 1
14487,16925	134674,525589	# Rennbahnstr. 2 XXX
22462,4462	135830,524445	# Müggelheimer Str. 52
EOF

# Koordinaten der Telefonbuch Berlin 2001/2002 CDROM
# Wahrscheinlich sind die Koordinaten die gleichen wie bei 1999/2000, aber
# hier habe ich genauer gemessen. Insbesondere habe ich versucht,
# die Kreuzungsmitte festzustellen.
# Aber die Genauigkeit ist trotzdem zweifelhaft. Beispiele:
# - Der Verlauf der Friedrichstr. sieht so aus, als ob die Straße
#   im Blockverlauf genau nach Norden ausgerichtet ist. Das stimmt nicht,
#   die Straße hat einen leichten Drall nach Westen.
# - Einige Hausnummern der Mussehlstr. befinden sich beim
#   St.-Josef-Krankenhaus!?
# Überhaupt kann man mit dem Wertebereich nur eine Genauigkeit im Bereich
# von 10m erreichen.
#
# Für die Berechnung der Kreuzungsmitte wurde folgender Einzeiler verwendet:
#
# perl -e '($x1,$y1)=split /,/,shift;($x2,$y2)=split /,/,shift;print int((($x2-$x1)/2)+$x1),",",int((($y2-$y1)/2)+$y1),"\n"' ... ...
#
my @t2001_data = split(/\n/, <<'EOF');
# hafas         telefonbuch 2001/2002 (DDD*10000)
9410,11803	133912,525134	# Mohrenstr.16/Friedrichstr.78
9918,13733	133992,525308	# Torstr.152/Ackerstr.171
8947,7601	133832,524757	# Thuyring 29/Manfred-v-Richthofen 158
10310,-2136	134008,523879	# Bahnhofstr.28/39 (Kreuzung mit Steinstr.)
24119,13491	136079,525261	# Ridbacher 110/111(Kreuzung mit Heinrich-Grüber)
-3206,14226	132059,525375	# Breite Str.13/Charlottenstr.7
EOF


# GDF-Koordinaten (Tele-Atlas-Datei Berlin_Mitte.gdf, siehe
# www.teleatlas.de)
# Hier erstmal nur Dummydaten von der T99-CDROM (mit 100 multipliziert)
#XXXXXXXXXXXXXXXXXXXXXXXX
my @gdf_data = split(/\n/, <<'EOF');
# hafas         gdf data (DDD*1000000)
9225,8787	13383797,52484993	# Dudenstr. 2
-6808,1048	13146102,52415949	# Rathaus Wannsee (Chaussestr. 22)
-5497,1305	13167193,52420430	# Am Kl. Wannsee/Am Gr. Wannsee HNR 1
11025,16450	13414321,52553892	# Bornholmer Str. 1
14487,16925	13466714,52557086	# Rennbahnstr. 2 XXX
22462,4462	13580680,52443206	# Müggelheimer Str. 52
EOF

if (0) {
    # @polar_data wird von @t2001_data erzeugt
    # XXX scheint schlechter zu sein!
    @polar_data = ();
    foreach (@t2001_data) {
	next if /^#/;
	    my($hafas, $t2001, @rest) = split(/\t/, $_);
	my($x1,$y1) = split(/,/, $t2001);
	my $polar = join(",", $x1/10000,$y1/10000);
	push @polar_data, join("\t", $hafas, $polar, @rest);
    }
}

# GPS-Koordinaten (von einem Gerät ?)
# von misc/20000510.tracks
my @gps_data_polar = split(/\n/, <<'EOF');
# hafas		gps (DMS)
4242,10443	N52 30.034010 E13 18.770964	# Leibnizstr => Kurfürstendamm
3757,13530	N52 31.755989 E13 18.386657	# Lise-Meitner => Gaussstr.
921,14386	N52 32.202415 E13 15.866454	# Siemensdamm/Rohrdamm
12493,5218	N52 27.132397 E13 26.003916	# Tempelhofer Weg => Gradestr
15952,2329	N52 25.534015 E13 29.004986	# Fritz-Erler => Neuköllner S
EOF

# Hier erstmal nur Dummydaten für gps_data von den Polar-Daten (mit Sedezimal-Korrektur) erzeugen
#XXXXXXXXXXXXXXXXXXXXXXXX
my @gps_data;
if (1) {
    foreach (@polar_data) {
	next if /^\#/;
	my($hafas, $polar, @rest) = split(/\t/, $_);
	my($x1,$y1) = split(/,/, $polar);
#warn "($x1,$y1)";
	my($x,$xmin) = split(/\./, $x1);
	$xmin = substr($xmin, 0, 2) . "." . substr($xmin, 2);
#warn "$x $xmin";
	my($y,$ymin) = split(/\./, $y1);
	$ymin = substr($ymin, 0, 2) . "." . substr($ymin, 2);
	$polar = join(",", ($x*100)+$xmin/100*60, ($y*100)+$ymin/100*60);
    #warn $polar;
	push @gps_data, join("\t", $hafas, $polar, @rest);
    }
}

if (0) {
    # @polar_data aus 20000510.track erzeugen
    @polar_data = ();
    foreach (@gps_data_polar) {
	next if /^\#/;
	my($hafas, $polar, @rest) = split(/\t/, $_);
	my($lat_deg, $lat_min, $lon_deg, $lon_min) =
	    $polar =~ /^N(\d+)\s(\d+\.\d+)\sE(\d+)\s(\d+\.\d+)/;
	if (!defined $lat_deg || !defined $lon_min) {
	    die "Parse error in $_";
	}
	$polar = join(",",
		      $lon_deg + $lon_min/6000*100,
		      $lat_deg + $lat_min/6000*100);
    warn "$polar\n";
	push @polar_data, join("\t", $hafas, $polar, @rest);
    }
}


# Koordinaten der Radarkarte vom Meteorologischen Institut der FU
# Vergrößerte Karte (nur Brandenburg) (obsolet)
my @furadar_data = split(/\n/, <<'EOF');
# hafas         radar data
88867,-4205	436,277	# Frankfurt/Oder
49206,68859	364,120 # Angermünde
-30679,56900	203,134 # Neuruppin
76030,-70384	410,401	# Cottbus
-101605,65048	60,120	# Wittenberge
#1979,28091	263,190	# Invalidensiedlung Frohnau, Nordwestspitze
#-10735,459	233,261	# Glienicker Brücke
#33537,2687	337,263	# Dämeritzsee (Grenze Berlin/Erkner an der Spree)
EOF

# Koordinaten der Radarkarte vom Meteorologischen Institut der FU
# Karte von Norddeutschland (die beiden anderen sind veraltet)
my @furadar2_data = split(/\n/, <<'EOF');
# hafas         radar data
88867,-4205	338,273	# Frankfurt/Oder
49206,68859	303,194 # Angermünde
76030,-70384	324,334	# Cottbus
-40974,-60689	210,322	# Lutherstadt Wittenberg
-12919,-1132	234,264	# Potsdam (Fr.-Ebert-Str.)
EOF

# Koordinaten der Radarkarte vom Meteorologischen Institut der FU
# Karte von Brandenburg (obsolet)
my @furadar3_data = split(/\n/, <<'EOF');
# hafas         radar data
88867,-4205	419,265	# Frankfurt/Oder
49206,68859	349,107 # Angermünde
76030,-70384	395,388	# Cottbus
-40974,-60689	45,108	# Wittenberge
-12919,-1132	215,255	# Potsdam (Fr.-Ebert-Str.)
EOF

# Soldner-alt (Umweltatlas-Höhendaten, hm96.dat)
# In eckigen Klammern die Punktnummern
my @soldneralt_data = split(/\n/, <<'EOF');
# hafas         soldneralt data
9225,8025	83724.188,6794.195	# Tempelhofer/Parade [906842]
-8381,725	65936.938,-83.305	# vor dem Schäferberg [900066] Kreuzung
-8006,800	66247.125,-24.900	# nach dem Schäferberg [107080] Kreuzung
3912,17650	78655.250,16488.000     # AB-Kreuz Tegel [156724]
11824,8995	86378.750,7771.793	# Hermannplatz Süd [907921]
#ungenau abgelesen: -6454,1118	67506.438,221.695	# Königsstr/Pfaueninselchaussee [900293]
15762,9303	90218.438,7963.297	# Südspitze Stralau [133807]
#ungenau abgelesen: 28990,3468	103374.438,1839.800	# Müggelsee/Spree SO-Ecke [167493]
28991,3476	103367.438,1845.400	# Müggelsee/Spree SO-Ecke [172198]
27375,-1950	101637.438,-3536.500	# Südspitze an der Großen Krampe (östl. Punkt) [168308]
#ungenau abgelesen: 25550,4462	99873.688,2817.400	# Müggelsee/Spree SW-Ecke [126201]
25577,4557	99954.000,2993.299	# Müggelsee/Spree SW-Ecke [129692]
10215,16527	84890.063,15288.996     # Bornholmer/Malmöer Mitte [914047]
3159,11562	77727.875,10479.992	# Schloß/Kaiserdamm [910182]
-5814,10815	68768.375,9965.996	# Pots. Chaussee/Str. 270 [101805]
EOF

# Soldner-neu: ist eine einfache Umrechnung von Soldner-alt, deshalb keine
# Daten notwendig
my @soldnerneu_data = split(/\n/, <<'EOF');
EOF

# # http://germany.city-info.ch/germany.rcl?8434,9387,605,605,1
# @city_info_data = split(/\n/, <<'EOF');
# # hafas		city-info
# 8593,12243	8434,9387		# Berlin/Brandenburger Tor
# 1341,-782	8316,9163		# Teltow
# -12919,-1132	8082,9177		# Potsdam
# -46527,-498	7534,9194		# Brandenburg (Stadt)/Rathaus
# 88867,-4205	9727,9067		# Frankfurt/Oder, Oderbrücke
# 37066,48447	8874,9947		# Eberswalde
# 76030,-70384	9539,8040		# Cottbus
# EOF

# XXX added 20000 to y coordinate to reverse the meaning
# http://germany.city-info.ch/germany.rcl?8434,9387,605,605,1
my @city_info_data = split(/\n/, <<'EOF');
# hafas		city-info
8593,12243	8434,10613		# Berlin/Brandenburger Tor
1341,-782	8316,10837		# Teltow
-12919,-1132	8082,10823		# Potsdam
-46527,-498	7534,10806		# Brandenburg (Stadt)/Rathaus
88867,-4205	9727,10933		# Frankfurt/Oder, Oderbrücke
37066,48447	8874,10053		# Eberswalde
76030,-70384	9539,11960		# Cottbus
EOF

my @dein_plan_data = split(/\n/, <<'EOF');
# hafas		dein plan
8593,12243	5019,5585		# Brandenburger Tor
8983,8779	5128,6739		# Duden/Methfessel
3831,10348	3350,6192		# Adenauerpl
8790,16261	5120,4208		# Pank/Bad
16462,10697	7720,6155		# Weitling/Lück
EOF

my @maps =
         (
	  ['berlinmap',	\@berlinmap_data,        ''],
	  ['satmap',	\@satmap_data,           '?'], # XXX
	  ['satmap2',	\@satmap2_data,          's'],
	  ['newmap',	\@new_berlinmap_data,    'n'],
	  ['newnewmap',	\@newnew_berlinmap_data, 'nn'],
	  ['gismap',	\@gismap_data,           'e'],
	  ['polar',	\@polar_data,            'p'],
	  ['gis',       \@gis_data,              'g'],
	  ['b1999',     \@b1999_data,            'nnn'],
	  ['b2001',     \@b2001_data,            'n2001'],
	  ['b2002',     \@b2002_data,            'n2002'],
	  ['p2002',     \@p2002_data,            'p2002'],
	  ['nbrb2004',  \@nbrb2004_data,         'nbrb2004'],
	  ['de2002',    \@de2002_data,           'de2002'],
	  ['t99',       \@t99_data,              't99'],
	  ['t2001',     \@t2001_data,            't2001'],
	  ['gdf',       \@gdf_data,              'gdf'],
	  ['gps',       \@gps_data,              'gps'],
	  ['furadar',   \@furadar_data,          'fub'],
	  ['furadar2',  \@furadar2_data,         'fub2'],
	  ['furadar3',  \@furadar3_data,         'fub3'],
	  ['furadar3',  \@furadar3_data,         'fub3'],
	  ['soldneralt',\@soldneralt_data,       'sa'],
	  ['soldnerneu',\@soldnerneu_data,       'sn'],
	  ['cityinfo',  \@city_info_data,        'cityinfo'],
	  ['deinplan',  \@dein_plan_data,	 'deinplan'],
	 );

my @global_map_data;

sub process {
local(@ARGV) = @_;
local $_;

my $map = 'berlinmap';
my $output = 'normal';
my $prefix = '';
my $data_from_file;
my $data_from_bbd_file;
my $data_from_any_file;
my $map_module;
my($reference_point_x, $reference_point_y);
my $reference_dist;
my $d;
my $reuse_map_data;
my $min_points = 4;

if (!GetOptions("map=s" => \$map,
		"bbbike!" => sub { $output = 'bbbike' },
		"bbdoutput!" => sub { $output = 'bbd' },
		"nooutput" => sub { $output = '' },
		"datafromfile=s" => \$data_from_file,
		"datafrombbd|datafrombbdfile=s" => \$data_from_bbd_file,
		"datafromany|datafromanyfile=s" => \$data_from_any_file,
		"mapmod=s" => \$map_module,
		"refpoint=s" => sub {
		    ($reference_point_x,$reference_point_y,$reference_dist)
			= split /,/, $_[1];
		    if (!defined $reference_point_x ||
			!defined $reference_point_y ||
			!defined $reference_dist) {
			die "-refpoint argument should be of form x,y,distance";
		    }
		},
		"minpoints=i" => \$min_points,
		"reusemapdata!" => \$reuse_map_data, # only for procedural interface
		"d|debug!" => \$d,
	       )) {
    die "Usage: $0 [-d|-debug] [-map mapname] [-refpoint x,y,dist] [-datafromfile file] [-datafrombbd file]
                  [-datafromany file] [-mapmod module] [-nooutput|-bbd|-bbbike]\n";
}

my $x1 = new Statistics::Descriptive::Full;
my $x2 = new Statistics::Descriptive::Full;

my $y1 = new Statistics::Descriptive::Full;
my $y2 = new Statistics::Descriptive::Full;

my @map_data_lines = ();
TRY: {
 if ($reuse_map_data && @global_map_data) {
     last TRY;
 } elsif ($data_from_file) {
     open(DATA, $data_from_file) or die "Can't open $data_from_file: $!";
     while(<DATA>) {
	 chomp;
	 push @map_data_lines, $_;
     }
     close DATA;
 } elsif ($data_from_bbd_file) {
     require Strassen::Core;
     my $s = Strassen->new($data_from_bbd_file);
     $s->init;
     while(1) {
	 my $r = $s->next;
	 last if !@{ $r->[Strassen::COORDS()] };
	 for (@{ $r->[Strassen::COORDS()] }) {
	     s/^:.*://; # remove additional point info
	 }
	 push @map_data_lines, join("\t",
				    @{ $r->[Strassen::COORDS()] }[0,1],
				    "# " . $r->[Strassen::NAME()]
				   );
     }
 } elsif ($data_from_any_file) {
     require Strassen::Core;
     open(DATA, $data_from_any_file)
	 or die "Can't open $data_from_any_file: $!";
     while(<DATA>) {
	 chomp;
	 if (/^\s*\#/) {
	     push @map_data_lines, $_;
	 } elsif (/\t.*\t/) { # rough check, theoretically it could be also separated by \s+
	     push @map_data_lines, $_;
	 } else {
	     my $r = Strassen::parse($_);
	     for (@{ $r->[Strassen::COORDS()] }) {
		 s/^:.*://; # remove additional point info
	     }
	     push @map_data_lines, join("\t",
					@{ $r->[Strassen::COORDS()] }[0,1],
					"# " . $r->[Strassen::NAME()]
				       );
	 }
     }
     close DATA;
 } elsif ($map_module) {
     require FindBin;
     push @INC, "$FindBin::RealBin/..", $FindBin::RealBin;
     eval 'require ' . $map_module;
     die $@ if $@;
     @map_data_lines = split /\n/, $map_module->create_conv_data();
 } else {
     foreach (@maps) {
	 if ($map eq $_->[0]) {
	     @map_data_lines = @{$_->[1]};
	     $prefix   =   $_->[2];
	     last TRY;
	 }
     }
     die "Unknown map. Known maps are: " . join(", ", map { $_->[0] } @maps) . "\n";
 }
}

my @map_data;
if (!$reuse_map_data || !@global_map_data) {
    @map_data = parse_data(@map_data_lines);
}

if ($reuse_map_data && !@global_map_data) {
    @global_map_data = @map_data;
}

my $map_data_ref;
if ($reuse_map_data && @global_map_data) {
    $map_data_ref = \@global_map_data;
} else {
    $map_data_ref = \@map_data;
}

require Strassen::Util;

my(@x1, @x2, @y1, @y2);
my(@linenr);
for (@$map_data_ref) {
    my($x1,$x2,$y1,$y2,$linenr) = @$_;
    if (defined $reference_dist) {
	next if Strassen::Util::strecke
	    ([$reference_point_x,$reference_point_y],
	     #[$x1,$y1], # XXX
	     [$x2,$y2], # XXX verhält sich besser, z.B. bei Schlund und Bergholz... aber warum?
	    ) > $reference_dist;
    }
    push @x1, $x1;
    push @x2, $x2;
    push @y1, $y1;
    push @y2, $y2;
    push @linenr, $linenr if $d;
}

if (@x1 < $min_points) {
    if ($output eq '') {
	return {Count => scalar @x1};
    } else {
	die "Too less data for conversion (" . scalar(@x1) . "), need $min_points";
    }
}

$x1->add_data(@x1);
$x2->add_data(@x2);

$y1->add_data(@y1);
$y2->add_data(@y2);

my($bbx0, $bbx1, $bbx2) = $x2->multiple_regression($x1, $y1);
my($bby0, $bby1, $bby2) = $y2->multiple_regression($x1, $y1);

if ($output eq 'bbbike') {
    print <<EOF;
       X0 => $bbx0,
       X1 => $bbx1,
       X2 => $bbx2,
       Y0 => $bby0,
       Y1 => $bby1,
       Y2 => $bby2,
EOF
} elsif ($output eq 'normal') {
    print "Mit multipler linearer Regression:\n";
    print "X: $bbx0+\$xx*$bbx1+\$yy*$bbx2\n";
    print "Y: $bby0+\$xx*$bby1+\$yy*$bby2\n";

} elsif ($output eq '') {
    return {X0 => $bbx0,
	    X1 => $bbx1,
	    X2 => $bbx2,
	    Y0 => $bby0,
	    Y1 => $bby1,
	    Y2 => $bby2,
	    Count => scalar @x1,
	   };
}

if ($output ne 'bbd' && $output ne '') {
    print "\n";
    printf
	"%11s,%11s    %11s,%11s    %11s,%11s\n",
	"real_x", "real_y", "calc_x", "calc_y", "epsilon_x", "epsilon_y";
    print "-" x 79, "\n";
}
my($sum_e2x, $sum_e2y, $sum_e2xy) = (0, 0, 0);
for my $i (0 .. $#x1) {
    my($realx, $realy) = ($x2[$i],$y2[$i]);
    my($calc2x, $calc2y) = ($bbx0+$x1[$i]*$bbx1+$y1[$i]*$bbx2,
			    $bby0+$x1[$i]*$bby1+$y1[$i]*$bby2);
    my($e2x, $e2y) = ($realx-$calc2x, $realy-$calc2y);
    if ($output eq 'bbd') {
	my $e2xy = my $color_val = sqrt(sqr($e2x)+sqr($e2y));
	$color_val = 255 if $color_val > 255;
	my $color = sprintf "#%02x0000", 255-$color_val;
	printf "%f\t$color %d,%d %d,%d\n",
	    $e2xy, $realx,$realy,$calc2x,$calc2y;
    } else {
	if ($d) {
	    printf "%4d ", $linenr[$i];
	}
	printf
	    "%12.3f,%12.3f    %12.3f,%12.3f    %10.3f,%10.3f\n",
	    $realx,$realy,$calc2x,$calc2y, $e2x, $e2y;
    }
    $sum_e2x += abs($e2x);
    $sum_e2y += abs($e2y);
    $sum_e2xy += sqrt(sqr($e2x)+sqr($e2y));
}

my $num = scalar @x1;
if ($output ne 'bbd') {
    print "\ndurchschnittliche Abweichungen:\n";
    printf
	"X: %12.3f, Y: %12.3f, XY: %12.3f\n",
	$sum_e2x/$num, $sum_e2y/$num, $sum_e2xy/$num;
}
}

# Quadrat
sub sqr {
    $_[0] * $_[0];
}

sub parse_data {
    my @map_data_lines = @_;
    my @map_data;

    require Karte;
    require Karte::Polar;
    require Karte::Standard;

    my $linenr = 0;

    foreach (@map_data_lines) {
	$linenr++;
	next if /^\#/;
	next if /^\s*$/;
	if (/([+-]?[\d\.]+),([+-]?[\d\.]+)\s*([+-]?[\d\.]+),([+-]?[\d\.]+)/) {
	    push @map_data, [$3,$1,$4,$2,$linenr];
	    #XXX combine next three cases...
	} elsif (/([NS]\d+\s\d+\s[\d\.]+)\s+
		 ([EW]\d+\s\d+\s[\d\.]+)\s+
		 ([+-]?[\d\.]+),([+-]?[\d\.]+)/x) {
	    my($lat,$long,$x1,$y1) = ($1,$2,$3,$4);
	    my($x2,$y2) = $Karte::Polar::obj->map2standard
		(Karte::Polar::dms_string2ddd($long),
		 Karte::Polar::dms_string2ddd($lat));
	    push @map_data, [$x1,$x2,$y1,$y2,$linenr];
	} elsif (/([+-]?[\d\.]+),([+-]?[\d\.]+)\s+
		 ([NS]\d+\s\d+\s[\d\.]+)\s+
		 ([EW]\d+\s\d+\s[\d\.]+)/x) {
	    my($x1,$y1,$lat,$long) = ($1,$2,$3,$4);
	    my($x2,$y2) = $Karte::Polar::obj->map2standard
		(Karte::Polar::dms_string2ddd($long),
		 Karte::Polar::dms_string2ddd($lat));
	    push @map_data, [$x1,$x2,$y1,$y2,$linenr];
	} elsif (/([EW])\s+(\d+)°(\d+)\'([\d\.]+)\"\s+
		 ([NS])\s+(\d+)°(\d+)\'([\d\.]+)\"\s+
		 ([+-]?[\d\.]+),([+-]?[\d\.]+)/x) {
	    my $long = "$1$2 $3 $4";
	    my $lat  = "$5$6 $7 $8";
	    my($x1,$y1) = ($9, $10);
	    my($x2,$y2) = $Karte::Polar::obj->map2standard
		(Karte::Polar::dms_string2ddd($long),
		 Karte::Polar::dms_string2ddd($lat));
	    push @map_data, [$x1,$x2,$y1,$y2,$linenr];
	} else {
	    die "Can't parse $_";
	}
    }

    @map_data;
}

return 1 if caller;

process(@ARGV);

__END__

# Vorgehensweise:
# Karte::*-Modul kopieren
# neues Modul in Karte.pm eintragen
# evtl. y- oder x-Wert in sub coord anpassen
# Scrollregion entsprechend y/x-Wert anpassen
# fetch maps in der Einstellung Koordinatensystem neues Modul
# in dieser Datei Tabelle erstellen mit Hafas-Koordinaten (Standard)
#    gegen Koordinaten aus der Einstellung Koordinatensystem=neues Modul,
#    Aus/Eingabe=Standard
# mit
#    ./convert_berlinmap.pl -map <neuestoken> -bbbike
# aufrufen, X/Y-Werte in Karte::* eintragen
