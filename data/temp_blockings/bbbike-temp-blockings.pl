# -*- bbbike -*-
# temp-blocking
# XXX undef old entries
# iso2epoch: date -j 2004MMDDhhmm +%s
#            date +%s
require Time::Local;
@temp_blocking =
    (
     { from  => Time::Local::timelocal(reverse(2003-1900,5-1,21,0,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,5-1,23,0,0,0)),
       file  => "richardplatz.bbd",
       text  => "Richardplatz - wegen eines Straßenfestes für den gesamten Fahrzeugverkehr gesperrt",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,5-1,26,0,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,2,0,0,0)),
       file  => "kirchentag-20030526.bbd",
       text  => "Gesperrte Straßen währen des Kirchentages vom 26.5. bis zum 1.6. (Straße des 17. Juni)",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,5-1,27,8,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,5-1,29,0,0,0)),
       file  => "kirchentag-20030528.bbd",
       text  => "Gesperrte Straßen am 28.5. zwischen 14 Und 24 Uhr während des Kirchentages (im Bereich Pariser Platz - Unter den Linden - Friedrichstr. - Gendarmenmarkt)",
       type  => "handicap",
     },
     { from  => 1115848800, # 2005-05-12 00:00
       until => 1116280616, # 2005-05-16 23:56
       text  => 'Straßenfest rund um den Blücherplatz',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9522,10017 9811,10055
userdel	2 9522,10017 9444,10000
userdel	2 9592,10174 9812,10211
userdel	2 9401,10199 9592,10174
userdel	2 9579,10122 9536,10064
userdel	2 9579,10122 9689,10124
userdel	2 9827,10120 9811,10055
userdel	2 9827,10120 9849,10202
userdel auto	3 9593,10238 9592,10174 9579,10122
userdel auto	3 10002,9948 9811,10055 9837,9856
userdel auto	3 10002,9948 9811,10055 9689,10124
userdel auto	3 9837,9856 9811,10055 10002,9948
userdel auto	3 9837,9856 9811,10055 9689,10124
userdel auto	3 9689,10124 9811,10055 10002,9948
userdel auto	3 9689,10124 9811,10055 9837,9856
userdel auto	3 9579,10122 9592,10174 9593,10238
EOF
     },
     { from  => 1149323010, # 2006-06-03 10:23
       until => 1149458399, # 2006-06-04 23:59
       text  => 'Karneval der Kulturen, 04.06.2006, 12.30 bis 21.30 Uhr',
       file  => "karneval-der-kulturen.bbd",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,19,6,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,22,22,0,0)),
       file  => "richardplatz.bbd",
       text  => "Richardplatz - wegen eines Straßenfestes für den gesamten Fahrzeugverkehr gesperrt. Dauer: 21.06.03, 06:00 Uhr bis 22.06.03, 22:00 Uhr",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,26,10,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,29,18,0,0)),
       file  => "wiesenfest.bbd",
       text  => "Finsterwalder Straße zwischen Engelroder Weg und Calauer Straße Vollsperrung aufgrund des Wiesenfestes. Dauer:28.06.2003, 10.00 Uhr bis 29.06.2003, 18.00 Uhr",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,20,4,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,22,23,59,59)),
       file  => "strassenfest-karl-marx-str.bbd",
       text  => "Karl-Marx-Straße zwischen Flughafenstraße und Werbellinstraße, Erkstraße zwischen Karl-Marx-Straße und Donaustraße: Straßenfest, Straßen gesperrt. Datum: 21.06.2003, 04.00 Uhr bis 22.06.2003, 24.00 Uhr",
     },
     { from  => Time::Local::timelocal(reverse(2005-1900,6-1,25,5,0,0)),
       until => Time::Local::timelocal(reverse(2005-1900,6-1,26,5,0,0)),
       file  => "csd.bbd",
       text  => "CSD am 25.6.",
     },
     { from  => 1119070200, # 2005-06-18 06:50
       until => 1119218400, # 2005-06-20 00:00
       text  => 'L71 Badstraße Berlin-Wedding - Berlin-Mitte in beiden Richtungen Zwischen Pankstraße und Böttgerstraße beidseitig Veranstaltung, Straße gesperrt bis 19.06.2005, 23:00 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8862,16208 8788,16264
userdel	2 8928,16158 8993,16100
userdel	2 8993,16100 9059,16038
userdel	2 9134,15953 9059,16038
EOF
     },
     { from  => Time::Local::timelocal(reverse(2005-1900,6-1,25,6,0,0)),
       until => Time::Local::timelocal(reverse(2005-1900,6-1,27,1,0,0)),
       file  => "rheinstrassenfest.bbd",
       text  => "Rheinstraßenfest in der Rheinstraße zwischen Breslauer Platz  und Walter-Schreiber-Platz. Dauer: 25.06.2005 06:00 Uhr bis 27.06.2005 01:00",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,8,6,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,12,23,59,59)),
       file  => "loveparade.bbd",
       text  => "Loveparade, Straßen gesperrt. Dauer: 11.07.2003, 20.00 Uhr bis 13.07.2003, 14.00 Uhr",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,7,6,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,12,20,00,00)),
       file  => "kranarbeiten.bbd",
       text  => "Charlottenstraße zwischen Kochstraße und Besselstraße Kranarbeiten, Straße gesperrt. Dauer: 08.07.2003, 06.00 Uhr bis 12.07.2003, 20.00 Uhr",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,10,20,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,14,4,00,00)),
       file  => "pankow-20030711.bbd",
       text  => "Berliner Straße zwischen Granitzstraße und Hadlichstraße sowie
Florastraße zwischen Grunowstraße und Berliner Straße, Baustelle, Straße in beiden Richtungen gesperrt. Dauer: 11.07.2003, 20.00 Uhr bis 14.07.2003, 04.00 Uhr",
       type  => "handicap",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,19,8,00,00)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,20,20,00,00)),
       file  => "stauffenbergstr.bbd",
       text  => "Stauffenbergstr. und Umgebung wegen Veranstaltung gesperrt. Dauer: 20.07.2003, 08.00 Uhr bis 20.00 Uhr"
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,18,7,00,00)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,20,23,59,00)),
       file  => "oberbaumbruecke.bbd",
       text  => "Oberbaum-Brückenfest am 20.07.2003 zwischen 07.00 Uhr bis 24.00 Uhr für den Fahrzeugverkehr gesperrt."
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,8-1,8,7,00,00)),
       until => Time::Local::timelocal(reverse(2003-1900,8-1,10,23,59,00)),
       file  => "oberbaumbruecke.bbd",
       text  => "Oberbaum-Brückenfest am 10.08.2003 zwischen 07.00 Uhr bis 24.00 Uhr für den Fahrzeugverkehr gesperrt."
     },
     { from  => 1060257600, # 2003-08-07 14:00
       until => 1060466400, # 2003-08-10 00:00
       file  => '20030809.bbd',
       text  => 'Im Bereich Tauentzienstraße, Kurfürstendamm zwischen Nürnberger Straße und Joachim-Friedrich-Straße, Droysenstraße, Kantstraße, in beiden Richtungen Sportveranstaltung, Straße gesperrt. Dauer: 09.08.2003, 14.00 Uhr bis 24.00 Uhr'
     },
     { from  => 1061640000, # 2003-08-23 14:00
       until => 1061748000, # 2003-08-24 20:00
       file  => 'xrace.bbd',
       text  => 'Straße des 17. Juni ist zwischen Entlastungstraße und Klopstockstraße gesperrt. (X Race-Veranstaltung) Dauer: 24.08.2003, von 14.00 Uhr bis 20.00 Uhr'
     },
     { from  => 1059190200, # 2003-07-26 05:30
       until => 1059336000, # 2003-07-27 22:00
       file  => '20030727.bbd',
       text  => 'Kurfürstendamm zwischen Joachimstaler Straße und Fasanenstraße in Fahrtrichtung Westen gesperrt (Kranarbeiten). Dauer: 27.07.2003 zwischen 05.30 Uhr und ca. 22.00 Uhr',
       type  => "handicap",
     },
     { from  => 1061539200, # 2003-08-22 10:00
       until => 1061661600, # 2003-08-23 20:00
       file  => 'johnfosterdulles.bbd',
       text  => 'John-Foster-Dulles-Allee zwischen Spreeweg und Entlastungsstraße, Sportveranstaltung, Straße in beiden Richtungen gesperrt. Dauer: 23.08.2003, 10.00 Uhr bis 20.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1062136800, # 2003-08-29 08:00
       until => 1062280800, # 2003-08-31 00:00
       file  => 'maybachufer.bbd',
       text  => 'Maybachufer zwischen Kottbusser Tor und Hobrechtbrücke wegen Straßenfest für den Fahrzeugverkehr gesperrt. Dauer: 30.08.2003 zwischen 08.00 Uhr und 24.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,8-1,9,10,00,00)),
       until => Time::Local::timelocal(reverse(2003-1900,8-1,10,20,00,00)),
       file  => 'johnfosterdulles.bbd',
       text  => 'John-Foster-Dulles-Allee zwischen Spreeweg und Entlastungsstraße, Sportveranstaltung, Straße in beiden Richtungen gesperrt. Dauer: 10.08.2003, 10.00 Uhr bis 20.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1061496000, # 2003-08-21 22:00
       until => 1061676000, # 2003-08-24 00:00
       file  => 'hanfparade.bbd',
       text  => 'Sperrungen zur Hafparade am 23.8.2003',
       type  => 'gesperrt',
     },
     { from  => 1061625600, # 2003-08-23 10:00
       until => 1061730000, # 2003-08-24 15:00
       file  => 'kudamm_rad.bbd',
       text  => 'Kurfürstendamm (südl. Richtungsfahrbahn) zwischen Uhlandstraße und Leibnizstraße gesperrt. Grund: Radsportveranstaltung Dauer: 24.08.2003,10.00 Uhr bis 15.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1062136800, # 2003-08-29 08:00
       until => 1062280800, # 2003-08-31 00:00
       file  => 'kudamm_rad.bbd',
       text  => 'Kurfürstendamm (südl. Richtungsfahrbahn) zwischen Uhlandstraße und Leibnizstraße gesperrt. Grund: Radsportveranstaltung Dauer: 30.08.2003 zwischen 08.00 Uhr und 24.00 Uhr Uhr ',
       type  => 'gesperrt',
     },
     { from  => 1061503200, # 2003-08-22 00:00
       until => 1061762400, # 2003-08-25 00:00
       file  => 'muellerstr.bbd',
       text  => 'Straßenfest in der Müllerstraße bis 24.8.2003',
       type  => 'gesperrt',
     },
     { from  => 1061517600, # 2003-08-22 04:00
       until => 1061762400, # 2003-08-25 00:00
       file  => 'reichsstr.bbd',
       text  => 'Wegen eines Festes kann die Reichsstraße am Sonnabend ab 4 Uhr bis Sonntag (24 Uhr) vom Steubenplatz bis zum Theodor-Heuss-Platz nicht passiert werden',
       type  => 'gesperrt',
     },
     { from  => 1062829800, # 2003-09-06 08:30
       until => 1062943200, # 2003-09-07 16:00
       file  => '20030907.bbd',
       text  => 'Rixdorfer Straße, Alt-Mariendorf, Mariendorfer Damm, Ullsteinstraße wegen Rundkurs Sportveranstaltung gesperrt. Dauer: 07.09.2003 zwischen 08.30 Uhr und 16.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1062540000, # 2003-09-03 00:00
       until => 1062972000, # 2003-09-08 00:00
       file  => 'globalcity.bbd',
       text  => 'Global City (05.09.03 - 07.09.03): Kurfürstendamm/Tauentzienstr. von Uhlandstr. bis Passauer Str. gesperrt',
       type  => 'gesperrt',
     },
     { from  => 1062813600, # 2003-09-06 04:00
       until => 1064181600, # 2003-09-22 00:00
       file  => '20030907b.bbd',
       text  => 'Fürstenwalder Damm zwischen Bölschestraße und Hartlebenstraße Baustell stadtauswärts, Straße gesperrt, eine Umleitung ist eingerichtet, Dauer: 07.09.2003,04.00 Uhr bis 21.09.2003',
       type  => 'gesperrt',
     },
     { from  => 1063339200, # 2003-09-12 06:00
       until => 1063576800, # 2003-09-15 00:00
       file  => 'winzerfest.bbd',
       text  => 'Bahnhofstraße, zwischen Goltzstraße und Steinstraße Vollsperrung, vom 13.09.2003, 06.00 Uhr bis 14.09.2003, 24.00 Uhr ',
       type  => 'gesperrt',
     },
     { from  => 1096596000, # 2004-10-01 04:00
       until => 1096927200, # 2004-10-05 00:00
       file  => 'karlmarx.bbd',
       text  => 'Karl-Marx-Straße, zwischen Flughafenstraße und Uthmannstraße gesperrt. Grund: Straßenfest. Dauer: 02.10.2004 04:00 Uhr bis 04.10.2004',
       type  => 'handicap',
     },
     { from  => 1065758400, # 2003-10-10 06:00
       until => 1065996000, # 2003-10-13 00:00
       file  => 'hermannstr.bbd',
       text  => 'Hermannstraße, zwischen Emserstraße und Thomasstraße gesperrt. Grund: Straßenfest. Dauer: 11.10.2003, 06.00 Uhr bis 12.10.2003, 24.00 Uhr',
       type  => 'handicap',
     },
     { from  => 1135045277, # 2005-12-20 03:21
       until => 1135378800, # 2005-12-24 00:00
       text  => 'Schlichtallee zwischen Hauptstraße und Lückstraße beidseitig wegen Bauarbeiten gesperrt bis 23.12.05 ',
       type  => 'gesperrt',
       source_id => 'LMS_1134638526559',
       data  => <<EOF,
userdel	2 15751,10582 16032,10842
userdel	2 15751,10582 15629,10481
EOF
     },
     { from  => 1133420400, # 2005-12-01 08:00
       until => 1133737200, # 2005-12-05 00:00
       text  => 'Richardplatz Alt-Rixdorfer Weihnachtsmarkt, gesperrt. Dauer: 02.12.2005, 08:00 Uhr bis 04.12.2005, 24:00 Uhr. ',
       type  => 'gesperrt',
       file  => 'rixdorfer_weihnachtsmarkt.bbd',
     },
     { from  => 1102672800, # 2004-12-10 11:00
       until => 1102805999, # 2004-12-11 23:59
       file  => 'spandauer_weihnachtsmarkt.bbd',
       text  => 'Spandauer Weihnachtsmarkt',
       type  => 'gesperrt',
     },
     { from  => 1070600400, # 2003-12-05 06:00
       until => 1070838000, # 2003-12-08 00:00
       file  => 'sophienstr.bbd',
       text  => 'Sophienstraße zwischen Rosenthaler Straße und Große Hamburger Straße wegen 8. Umwelt - und Weihnachtsmarkt für den Fahrzeugverkehr gesperrt (keine Wendemöglichkeit für Lkw). Dauer : 6.12.2003 / 06.00 Uhr bis 7.12.2003 / 24.00 Uhr ',
       type  => 'gesperrt',
     },
     { from  => 1079046000, # 2004-03-12 00:00
       until => 1079319600, # 2004-03-15 04:00
       file  => 'sbhf_pankow.bbd',
       text  => 'Berliner Straße zwischen Florastraße und Granitzstraße in beiden Richtungen gesperrt (Höhe S-Bhf. Pankow). Grund: Brückenarbeiten. Eine Umleitung ist ausgeschildert. Dauer: 13.03.2004, 00:00 Uhr bis 15.03.2004, 04:00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1079236800, # 2004-03-14 05:00
       until => 1080514800, # 2004-03-29 01:00
       file  => 'langhansstr.bbd',
       text  => 'Die Langhansstraße ist zwischen Prenzlauer Promenade und Heinersdorfer Straße in beiden Richtungen gesperrt. Grund: Baumaßnahmen. Dauer:15.03.2004, 05:00 Uhr bis 28.03.2004, 17:00 Uhr. Eine Umleitung ist ausgeschildert.',
       type  => 'gesperrt',
     },
     { from  => 1079766000, # 2004-03-20 08:00
       until => 1079888400, # 2004-03-21 18:00
       file  => 'residenz_rad.bbd',
       text  => 'Residenzstraße zwischen Lindauer Allee und Emmentaler Straße, Emmentaler Straße zwischen Residenzstraße und Aroser Allee, Aroser Allee zwischen Emmentaler Straße und Lindauer Allee sowie Lindauer Allee zwischen Aroser Allee und Residenzstraße. Straßen gesperrt. Radrennen. Umleitung ist ausgeschildert. Dauer: 21.03.2004, 08.00 Uhr bis 18.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1117404000, # 2005-05-30 00:00
       until => 1117620000, # 2005-06-01 12:00
       text  => 'Budapester Str. wegen Staatsbesuch gesperrt',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6606,11222 6582,11202
userdel	2 6446,11147 6168,11042
userdel	2 6446,11147 6582,11202
EOF
     },
     { from  => 1081476000, # 2004-04-09 04:00
       until => 1081807200, # 2004-04-13 00:00
       file  => 'artists_boulevard.bbd',
       text  => 'Potsdamer Straße zwischen Schöneberger Ufer und Pohlstraße in beiden Richtungen gesperrt, Veranstaltung (Boulevard des Artistes). Dauer: 10.04.2004, 04:00 Uhr bis 12.04.2004, 24:00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1082869200, # 2004-04-25 07:00
       until => 1083362400, # 2004-05-01 00:00
       file  => 'lueckstr.bbd',
       text  => 'Lückstraße zwischen Giselastraße und Schlichtallee in Fahrtrichtung Schlichtallee Bauarbeiten, Straße gesperrt. Dauer: 26.04.2004, 07:00 Uhr bis voraussichtlich 30.04.2004 ',
       type  => 'handicap',
     },
     { from  => 1112991869, # 2005-04-08 22:24
       until => 1113170400, # 2005-04-11 00:00
       text  => 'Turmstr. (Mitte) in beiden Richtungen zwischen Gotzkowskystr. und Stromstr. Veranstaltung, Straße vollständig gesperrt (bis 10.04.2005 ca. 24 Uhr)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 6112,13327 6249,13322
userdel	q4 5705,13359 5857,13342
userdel	q4 5705,13359 5560,13382
userdel	q4 5956,13330 5857,13342
userdel	q4 5368,13406 5560,13382
userdel	q4 6112,13327 6011,13330 5956,13330
EOF
     },
     { from  => Time::Local::timelocal(reverse(2004-1900,4-1,30,12,0,0)),
       until => Time::Local::timelocal(reverse(2004-1900,5-1,2,6,0,0)),
       file  => "kreuzberg-20020501.bbd",
       text  => "mögliche Behinderungen zum 1. Mai in Kreuzberg",
     },
     { from  => 1083232800, # 2004-04-29 12:00
       until => 1083448800, # 2004-05-02 00:00
       file  => 'reinhardtstr.bbd',
       text  => 'Reinhardtstraße zwischen Friedrichstraße und Albrechtstraße in beiden Richtungen gesperrt, Veranstaltung. Dauer: 30.04.2004, 12:00 Uhr bis 01.05.2004, 24:00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1083294000, # 2004-04-30 05:00
       until => 1083448800, # 2004-05-02 00:00
       file  => 'spandauer.bbd',
       text  => 'Spandauer Straße, zwischen Karl-Liebknecht-Straße und Mühlendamm, in beiden Richtungen Straße gesperrt. Veranstaltung. Dauer: 01.05.2004, 05.00 Uhr bis 24.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1112241600, # 2005-03-31 06:00
       until => 1112562000, # 2005-04-03 23:00
       text  => 'Müllerstraße, Zwischen Kreuzung Seestraße und Kreuzung Leopoldplatz in beiden Richtungen Veranstaltung, Straße gesperrt, Dauer: 01.04.2005 06:00 Uhr bis 03.04.2005 23:00 Uhr (Müllerstraßenfest) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 7043,15793 7198,15656
userdel	2 7043,15793 6957,15869 6914,15908
userdel	2 7198,15656 7288,15579
userdel	2 6790,16018 6914,15908
EOF
     },
     { from  => 1083491594, # 2004-05-02 11:53
       until => 1083967200, # 2004-05-08 00:00
       file  => 'lueckstr.bbd',
       text  => 'Lückstraße Berlin-Friedrichsfelde Richtung Berlin-Friedrichshain; zwischen Rummelsburger Straße und Schlichtallee wegen Bauarbeiten gesperrt bis 7.05.2004. ',
       type  => 'handicap',
     },
     { from  => 1083708000, # 2004-05-05 00:00
       until => Time::Local::timelocal(reverse(2004-1900,5-1,19,23,59,59)),
       file  => 'karstaedt.bbd',
       text  => 'B 5; OD Karstädt, Bahnübergang; Gleisbauarbeiten; Vollsperrung; 06.05.2004-24.05.2004 ',
       type  => 'handicap',
     },
     { from  => 1083880800, # 2004-05-07 00:00
       until => 1084140000, # 2004-05-10 00:00
       file  => 'boelschefest.bbd',
       text  => 'Bölschestr. (Köpenick) in beiden Richtungen, zwischen Fürstenwalder Damm und Müggelseedamm Veranstaltung, Straßenfest (bis 09.05. 24 Uhr) 14. Bölschefest (11:39) ',
       type  => 'gesperrt',
     },
     { from  => 1083880800, # 2004-05-07 00:00
       until => 1084125600, # 2004-05-09 20:00
       file  => 'florastr.bbd',
       text  => 'Florastr. (Pankow) in beiden Richtungen zwischen Florapromenade und Heystr. Straßenfest, Straße vollständig gesperrt (bis 09.05.2004 20:00 Uhr) (16:47) ',
       type  => 'gesperrt',
     },
     { from  => 1084464000, # 2004-05-13 18:00
       until => 1084658400, # 2004-05-16 00:00
       file  => '20040514.bbd',
       text  => 'Ebertstraße, zwischen Behrenstraße und Dorotheenstraße, Straße des 17.Juni, zwischen Großen Stern und Entlastungsstraße sowie zwischen Entlastungsstraße und Platz des 18. März Veranstaltung. Straßen gesperrt. Dauer: 14.05.2004, 18.00 Uhr bis 15.04.2004, 24.00 Uhr ',
       type  => 'gesperrt',
     },
     { from  => 1116554400, # 2005-05-20 04:00
       until => 1116885600, # 2005-05-24 00:00
       text  => 'Hermannstraße, Straßenfest zwischen Flughafenstraße und Thomasstraße, Dauer: 21.05.2005 04:00 Uhr bis 23.05.2005',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 7043,15793 7198,15656
userdel	2 7043,15793 6957,15869 6914,15908
userdel	2 7198,15656 7288,15579
userdel	2 6790,16018 6914,15908
EOF
     },
     { from  => 1147522145, # 2006-05-13 14:09
       until => 1147651200, # 2006-05-15 02:00
       text  => 'Reichsstraße (Charlottenburg) in beiden Richtungen zwischen Theodor-Heuss-Platz und Steubenplatz Veranstaltung, Straße vollständig gesperrt (bis 15.05.2006 02:00 Uhr)',
       type  => 'gesperrt',
       source_id => 'IM_002775',
       file  => 'reichsstr.bbd',
     },
     { from  => 1084485600, # 2004-05-14 00:00
       until => 1084741200, # 2004-05-16 23:00
       file  => 'siegfriedstr.bbd',
       text  => 'Siegfriedstr. (Lichtenberg) in beiden Richtungen, zwischen Landsberger Allee und Herzbergstr. Veranstaltung, Straße vollständig gesperrt (bis 16.05. 23 Uhr) Siegfriedstraßenfest',
       type  => 'gesperrt',
     },
     { from  => 1085090400, # 2004-05-21 00:00
       until => 1085436000, # 2004-05-25 00:00
       file  => 'pillgram.bbd',
       text  => 'K 6733; Bahnübergang zw. Pillgram u. Jacobsdorf Gleisbauarbeiten Vollsperrung 22.05.2004-24.05.2004 ',
       type  => 'gesperrt',
     },
     { from  => 1085123951, # 2004-05-21 09:19
       until => 1085335200, # 2004-05-23 20:00
       file  => 'hauptstr_pankow.bbd',
       text  => 'Hauptstr. (Pankow) in beiden Richtungen zwischen Gravensteinstr. und Blankenfelder Str. Veranstaltung, Verkehrsbehinderung erwartet (bis 23.05.2004 20:00 Uhr)',
       type  => 'handicap',
     },
     { from  => 1085205600, # 2004-05-22 08:00
       until => 1085349600, # 2004-05-24 00:00
       file  => 'dorotheenstr.bbd',
       text  => 'Dorotheenstraße zwischen Eberetstraße und Wilhelmstraße sowie Ebertstraße zwischen Straße des 17.Juni und Dorotheenstraße Veranstaltung, gesperrt, Dauer: 23.05.2004, 08.00 Uhr bis 24.00 Uhr.',
       type  => 'gesperrt',
     },
     { from  => 1085124135, # 2004-05-21 09:22
       until => 1085342400, # 2004-05-23 22:00
       file  => 'marzahner_promenade.bbd',
       text  => 'Marzahner Promenade (Marzahn) in beiden Richtungen im Bereich des Freizeitforums Marzahn Veranstaltung, Straße vollständig gesperrt (bis 23.05.2004 22:00 Uhr) "Marzahner Frühling"',
       type  => 'handicap',
     },
     { from  => 1085124182, # 2004-05-21 09:23
       until => 1085428800, # 2004-05-24 22:00
       file  => 'scheidemannstr.bbd',
       text  => 'Scheidemannstr., Ebertstr. (Mitte) in beiden Richtungen im Bereich des Reichstagsgebäudes Veranstaltung, Straße vollständig gesperrt (bis 24.05.2004 22:00 Uhr)',
       type  => 'gesperrt',
     },
     { from  => 1085133600, # 2004-05-21 12:00
       until => 1085248800, # 2004-05-22 20:00
       file  => 'radrennen_hindenburgdamm.bbd',
       text  => 'Auguststraße zwischen Hindenburgdamm und Augustplatz Manteuffelstraße zwischen Augustplatz und Hindenburgdamm Hindenburgdamm (westliche Fahrbahn) zwischen Manteuffelstraße und Auguststraße Radrennen, Straße gesperrt, Dauer: 22.05.2004, 12.00 Uhr bis 20.00 Uhr. ',
       type  => 'gesperrt',
     },
     { from  => 1086919200, # 2004-06-11 04:00
       until => 1087163999, # 2004-06-13 23:59
       file  => 'karlmarx.bbd',
       text  => 'Karl-Marx-Straße zwischen Flughafenstraße und Uthmannstraße sowie Erkstraße zwischen Donaustraße und Karl-Marx-Straße: Straßenfest, Straßen gesperrt, Dauer: 12.06.2004, 04.00 Uhr bis 13.06,24.00 Uhr. ',
       type  => 'gesperrt',
     },
     { from  => 1086041261, # 2004-06-01 00:07
       until => Time::Local::timelocal(reverse(2004-1900,6-1,16,23,59,59)),
       file  => 'liesenstr.bbd',
       text  => 'Liesenstr. (Mitte) Richtung Süden zwischen Gartenstr. und Chausseestr. Baustelle, Fahrtrichtung gesperrt (bis 11.06.2004)',
       type  => 'handicap',
     },
     { from  => 1119520800, # 2005-06-23 12:00
       until => 1119736799, # 2005-06-25 23:59
       text  => 'Oberbaumbrückenfest, Dauer: 25.06.2005 12:00 Uhr bis 24:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13305,10789 13332,10832
userdel	2 13305,10789 13206,10651
userdel	2 13077,10747 13206,10651
userdel	2 13082,10634 13178,10623
userdel	2 13178,10623 13206,10651
EOF
     },
     { from  => 1150347600, # 2006-06-15 07:00
       until => 1150668000, # 2006-06-19 00:00
       text  => 'Bergmannstraßenfest, Bergmannstr. zwischen Mehringdamm und Zossener Str. gesperrt, 16.06.2006, 7.00 Uhr bis 18.06.2006, 24.00 Uhr ',
       type  => 'gesperrt',
       file  => 'bergmannstr.bbd',
     },
     { from  => 1087975800, # 2004-06-23 09:30
       until => 1088287200, # 2004-06-27 00:00
       file  => 'csd.bbd',
       text  => 'CSD am 26.06.2004 von 9.30 Uhr bis 24.00 Uhr',
       type  => 'gesperrt',
     },
     { from  => 1088892000, # 2004-07-04 00:00
       until => 1093903200, # 2004-08-31 00:00
       file  => 'herzfelde.bbd',
       text  => 'B 1; (Hauptstr.); OD Herzfelde Kanal- und Straßenbau Vollsperrung 05.07.2004-30.08.2004 ',
       type  => 'handicap',
     },
     { from  => 1086865200, # 2004-06-10 13:00
       until => 1086998400, # 2004-06-12 02:00
       file  => 'sowj_ehrenmal.bbd',
       text  => 'Die Straße des 17.Juni zwischen Entlastungsstraße und Ebertstraße (Start- und Zielbereich) ist von 11.06.2004,13:00 Uhr bis 12.06.2004, ca. 02:00 Uhr gesperrt (Sportveranstaltung).',
       type  => 'handicap',
     },
     { from  => 1087545600, # 2004-06-18 10:00
       until => 1087689600, # 2004-06-20 02:00
       file  => 'altwittenau.bbd',
       text  => 'Alt-Wittenau zwischen Eichborndamm und Triftstraße Bürgerfest, Straße gesperrt, Dauer: 19.06.2004, 10.00 Uhr bis 20.06.2004, 02.00 Uhr.',
       type  => 'handicap',
     },
     { from  => 1088114400, # 2004-06-25 00:00
       until => 1088352000, # 2004-06-27 18:00
       file  => 'wiesenfest.bbd',
       text  => 'Finsterwalder Straße zwischen Engelroder Weg und Calauer Straße Wiesenfest, Verkehrsbehinderung erwartet, Dauer: 26.06.2004, 10.00 UHr bis 27.06.2004, 18.00 Uhr.',
       type  => 'handicap',
     },
     { from  => 1087459757, # 2004-06-17 10:09
       until => 1089237600, # 2004-07-08 00:00
       file  => 'gleimstr.bbd',
       text  => 'Gleimstraße zwischen Schönhauser Allee und Ystarder Straße in beiden Richtungen gesperrt, Bauarbeiten. Dauer: bis voraussichtlich 07.07.2004',
       type  => 'handicap',
     },
     { from  => undef, # 
       until => 1150666200, # 2006-06-18 23:30
       text  => 'Badstr. (Wedding) in beiden Richtungen, zwischen Pankstr. und Behmstr. Veranstaltung, Straße vollständig gesperrt (bis 18.06.2006 23:30 Uhr) Seifenkistenrennen und Straßenfest in der Badstr.',
       type  => 'gesperrt',
       file  => 'badstr.bbd',
     },
     { from  => 1087462800, # 2004-06-17 11:00
       until => 1087765200, # 2004-06-20 23:00
       file  => 'motzstr.bbd',
       text  => 'NEW: Nollendorfplatz (Schöneberg) Bereich Nollendorfplatz Veranstaltung (bis 20.06. 23 Uhr), Aufbau ab 18.06. 11 Uhr; 12. Lesbisch-schwules Stadtfest',
       type  => 'gesperrt',
     },
     { from  => 1088807415, # 2004-07-03 00:30
       until => 1089147600, # 2004-07-06 23:00
       file  => 'gendarmenmarkt.bbd',
       text  => 'Gendarmenmarkt (Mitte) in allen Richtungen im Bereich Mohrenstr. Veranstaltung, Verkehrsbehinderung erwartet (bis 06.07.2004 23:00 Uhr) Classic Open Air am Gendarmenmarkt',
       type  => 'gesperrt',
     },
     { from  => 1088719200, # 2004-07-02 00:00
       until => 1089453600, # 2004-07-10 12:00
       file  => 'koenigsheideweg.bbd',
       text  => 'Königsheideweg (Treptow) Richtung Baumschulenstr. nach Sterndamm Baustelle, Fahrtrichtung gesperrt (bis Mitte 07.2004)',
       type  => 'handicap',
     },
     { from  => 1121462650, # 2005-07-15 23:24
       until => 1121637600, # 2005-07-18 00:00
       text  => 'Müllerstr. (Wedding) in beiden Richtungen zwischen Londoner Str. und Transvaalstr. Veranstaltung, Straße vollständig gesperrt (bis 17.07.2005 24 Uhr)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6032,16698 5791,16910
userdel	2 6032,16698 6110,16630
userdel	2 6110,16630 6329,16438
EOF
     },
     { from  => 1090533600, # 2004-07-23 00:00
       until => 1091224800, # 2004-07-31 00:00
       file  => 'goerlsdorf.bbd',
       text  => 'L 239; (B198 nö.Angermünde-Joachimsthal); Bahnübergang Görlsdorf Gleis- u. Straßenbau Vollsperrung 24.07.2004-30.07.2004 ',
       type  => 'gesperrt',
     },
     { from  => 1090913211, # 2004-07-27 09:26
       until => 1093736367, # bis Ende 08.2004
       file  => 'rathenower.bbd',
       text  => 'Berlin-Moabit, Kreuzung Rathenower Straße / Stephanstraße, Baustelle, Kreuzung vollständig gesperrt, Dauer: voraussichtlich bis Ende 08.2004',
       type  => 'handicap',
     },
     { from  => 1091055057, # 2004-07-29 00:50
       until => 1095112740, # 2004-09-13 23:59 removed
       file  => 'dietzgenstr.bbd',
       text  => 'Dietzgenstr. (Pankow) Richtung stadteinwärts zwischen Schillerstr. und Uhlandstr. Baustelle, Richtungsfahrbahn komplett gesperrt (bis 13.09.2004) ',
       type  => 'gesperrt',
     },
     { from  => 1092240000, # 2004-08-11 18:00
       until => 1092600000, # 2004-08-15 22:00
       file  => 'kudamm_tauentzien.bbd',
       text  => 'Zwischen Kreuzung Nürnberger Straße und Kreuzung Joachimstaler Straße in beiden Richtungen Veranstaltung (Global-City), gesperrt, Dauer: 12.08.2004 18:00 Uhr bis 15.08.2004 22:00 Uhr ',
       type  => 'gesperrt',
     },
     { from  => undef,
       until => 1092439940,
       text  => 'Hellersdorfer Straße (Hellersdorf) in beiden Richtungen zwischen Gülzower Straße und Heinrich-Grüber-Straße Straße vollständig gesperrt aufgrund eines Wasserrohrbruches.',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22998,12453 22956,12669
userdel	2 22998,12453 23090,12302
EOF
     },
     { from  => undef,
       until => 1092439940,
       data => <<EOF,
userdel	2 9475,18617 9301,18722
userdel	2 9590,18548 9896,18343
EOF
       text  => 'Heinrich-Mann-Straße Berlin-Reinickendorf Richtung Berlin-Pankow Zwischen Heinrich-Mann-Straße und Grabbeallee Störungen durch geplatzte Wasserleitung, Straße gesperrt',
       type  => 'gesperrt',
     },
     { from  => 1092520800, # 2004-08-15 00:00
       until => 1093298400, # 2004-08-24 00:00
       text  => 'OD Pritzwalk, zw. F.-Reuter-Str. und A.-Bartels-Weg; Brückenbauarbeiten; Vollsperrung: 16.08.2004-23.08.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -74489,80545 -74038,78181
EOF
     },
     { from  => undef, # 
       until => 1096151876, # removed (seen 2004-09-25)
       text  => 'Flottwellstr. (Tiergarten) in beiden Richtungen zwischen Lützowstraße und Am Karlsbad Verkehrsbehinderung durch Absenkung der Fahrbahn, Straße vollständig gesperrt',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 8199,10634 8281,10791
EOF
     },
     { from  => 1092520800, # 2004-08-15 00:00
       until => 1094940000, # 2004-09-12 00:00
       text  => 'B 96A; (Schönfließer Str.); OL Schildow; grundh. Straßenbau Vollsperrung; 16.08.2004-11.09.2004 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 8194,25966 8182,25608
EOF
     },
     { from  => 1092520800, # 2004-08-15 00:00
       until => 1093644000, # 2004-08-28 00:00
       text  => 'L 222; (Gransee-Großwoltersdorf); zw. Gransee und Abzw. Neulögow Deckenerneuerung; Vollsperrung; 16.08.2004-27.08.2004 ',
       type  => 'gesperrt',
      data  => <<EOF,
userdel	2 -8697,68965 -8826,68471
EOF
     },
     { from  => 1095285600, # 2004-09-16 00:00
       until => 1095717600, # 2004-09-21 00:00
       text  => 'L 88; (Beelitz-Lehnin); Bahnübergang zw. Beelitz u. AS Beelitz-Heilstätten Einbau Hilfsbrücke Vollsperrung 17.09.2004-20.09.2004 ',
       type  => 'gesperrt',
      data  => <<EOF,
userdel	2 -21642,-16531 -21341,-17172
EOF
     },
     { from  => 1095717600, # 2004-09-21 00:00
       until => 1096149600, # 2004-09-26 00:00
       text  => 'L 88; (Beelitz-Lehnin); Bahnübergang zw. Beelitz u. AS Beelitz-Heilstätten Einbau Hilfsbrücke Vollsperrung 22.09.2004-25.09.2004 ',
       type  => 'gesperrt',
      data  => <<EOF,
userdel	2 -21642,-16531 -21341,-17172
EOF
     },
     { from  => 1092866435, # 2004-08-19 00:00
       until => 1093989600, # 2004-09-01 00:00
       text  => 'B96A Berlin-Pankow, Schönholzer Straße - Mühlenstraße, Oranienburg Richtung Berlin-Mitte, Zwischen Kreuzung Grabbeallee und Kreuzung Breite Straße Baustelle, großer Zeitverlust, lange Staus bis 31.08.2004 , eine Umleitung ist eingerichtet (Sperrung nur zwischen Wollankstraße und Kreuzstraße)',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 9909,18333 10089,18180
EOF
     },
     { from  => 1093125600, # 2004-08-22 00:00
       until => 1093125600, # 2004-08-28 00:00 removed
       text  => 'L 792; (Groß Schulzendorf-Blankenfelde); OD Blankenfelde, Dorfstr. Straßenbauarbeiten Vollsperrung 23.08.2004-27.08.2004 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 10023,-8859 10115,-8276
EOF
     },
     { from  => 1099177200, # 2004-10-31 01:00
       until => 1099522800, # 2004-11-04 00:00
       text  => 'L 142; (Kyritzer Straße); Klempnitzbrücke in Wusterhausen Brückensanierung Vollsperrung 01.11.2004-03.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -54776,53333 -55124,53446
EOF
     },
     { from  => 1093384800, # 2004-08-25 00:00
       until => 1097272800, # 2004-10-09 00:00
       text  => 'L 30; (Tasdorfer Str.); OL Vogelsdorf, zw. Heinestr. u. Seestr. Kanalarbeiten Vollsperrung 26.08.2004-08.10.2004 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 35338,12538 35676,11706
EOF
     },
     { from  => 1093297474, # 2004-08-23 23:44
       until => 1093816800, # 2004-08-30 00:00
       text  => 'L 73; (B246-Fresdorf-Wildenbruch-B2); OD Wildenbruch, zw. Potsdamer Str. u. Dorfstr.; Straßenbauarbeiten; Vollsperrung; 23.08.2004-29.08.2004',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -12325,-13958 -12177,-13787
EOF
     },
     { from  => undef, # 
       until => 1093376850, # 2004-08-26 12:00 früher
       text  => 'Bachstraße: In beiden Richtungen Störungen durch Rohrbruch, gesperrt bis Do 12:00 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 6020,12492 5951,12353 5938,12281 5874,12165 5798,12021
userdel	q4 5771,11887 5787,11966 5798,12021
EOF
     },
     { from  => 1093125600, # 2004-08-22 00:00
       until => 1097618400, # 2004-10-13 00:00
       text  => 'L 435; (Grunow-Müllrose); OD Mixdorf, Hauptstr. grundhafter Ausbau Vollsperrung 23.08.2004-12.10.2004 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 79281,-22168 79255,-22467
EOF
     },
     { from  => 1093730400, # 2004-08-29 00:00
       until => 1094248800, # 2004-09-04 00:00
       text  => 'L 792; (Groß Schulzendorf-Blankenfelde); OD Blankenfelde, Dorfstr. Straßenbauarbeiten Vollsperrung 30.08.2004-03.09.2004 ',
       type  => 'handicap',
      data  => <<EOF,
userdel	q4 10023,-8859 10115,-8276
EOF
     },
     { from  => 1121292000, # 2005-07-14 00:00
       until => 1121637600, # 2005-07-18 00:00
       text  => 'B 103; (Havelberger Str.); OD Pritzwalk, Bahnübergang Gleissanierung Vollsperrung 15.07.2005-17.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -74489,80545 -74653,81289
EOF
     },
     { from  => 1093471200, # 2004-08-26 00:00
       until => 1093903200, # 2004-08-31 00:00
       text  => 'OL Finsterwalde Sängerfest Vollsperrung 27.08.2004-30.08.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 33240,-85187 33354,-85304
userdel	q4 33240,-85187 33060,-85292
userdel	q4 33481,-85428 33354,-85304
userdel	q4 33481,-85428 33488,-85803
userdel	q4 33103,-85731 33060,-85292
EOF
     },
     { from  => 1096840800, # 2004-10-04 00:00
       until => 1099520857, # XXX siehe unten
       text  => 'B 167; zw. Bad Freienw. u. Falkenberg, Höhe Papierfabrik Neubau von Durchlässen Vollsperrung 04.10.2004-unbekannt ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 49039,44131 48583,44366
EOF
     },
     { from  => 1093496400, # 2004-08-26 07:00
       until => 1093716000, # 2004-08-28 20:00
       text  => 'Die Naumannstraße ist zwischen Torgauer Straße und Tempelhofer Weg von 27.08.04, 07.00 Uhr bis 28.08.04, 20.00 Uhr gesperrt. Grund Bauarbeiten.',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 7716,8048 7717,7759
EOF
     },
     { from  => 1093730400, # 2004-08-29 00:00
       until => 1095397200, # 2004-09-17 07:00
       text  => 'Die Mohrenstraße ist von der Charlottenstraße in Richtung Friedrichstraße wegen Kranarbeiten vom 30.08.2004 bis 17.09.2004 montags bis freitags jeweils in der Zeit von 07:00 Uhr bis 17:00 Uhr als Einbahnstraße ausgewiesen.',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 9410,11803 9538,11818
EOF
     },
     { from  => 1093816800, # 2004-08-30 00:00
       until => 1098914400, # 2004-10-28 00:00
       text  => 'Oberwallstraße, Baustelle, Straße gesperrt zwischen Jägerstraße und Hausvogteiplatz, Dauer: 31.08.2004 bis 27.10.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9925,11947 9907,12055
EOF
     },
     { from  => 1093924800, # 2004-08-31 06:00
       until => 1098482400, # 2004-10-23 00:00
       text  => 'Gartenstraße zwischen Invalidenstraße und Bernauer Straße gesperrt, Baustelle, Einbahnstraße in südlicher Richtung wird eingerichtet, zudem wird die Ackerstraße zwischen Invalidenstraße und Bernauer Straße gesperrt. Dauer: 01.09.2004, 06.00 Uhr bis 22.10.2004',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 9383,13978 9224,14169
userdel	1 9400,14400 9439,14368 9628,14215 9737,14126 9810,14066
EOF
     },
     { from  => 1093928400, # 2004-08-31 07:00
       until => 1094234400, # 2004-09-03 20:00
       text  => 'Dauer: 01.09.2004 07:00 Uhr bis 03.09.2004 20:00 Uhr. Rudower Chaussee, gesperrt von Agastraße bis Großberliner Damm in Richtung Treptow',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 19732,3340 19581,3184 19501,3101
EOF
     },
     { from  => 1094083200, # 2004-09-02 02:00
       until => 1094428800, # 2004-09-06 02:00
       text  => 'Turmstraße zwischen Kreuzung Beusselstraße und Kreuzung Stromstraße sowie Thusneldaallee: Straße gesperrt (Turmstraßenfest), Dauer: 03.09.2004 02:00 Uhr bis 06.09.2004 02:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 5256,13420 5368,13406 5560,13382 5705,13359 5857,13342 5956,13330 6011,13330 6112,13327 6249,13322
userdel	2 5975,13256 5956,13330
EOF
     },
     { from  => 1094097600, # 2004-09-02 06:00
       until => 1094248799, # 2004-09-03 23:59
       text  => 'Erkstraße zwischen Kreuzung Karl-Marx-Straße und Kreuzung Sonnenallee Straße gesperrt (Spielfest), Dauer: 03.09.2004 06:00 Uhr bis 23:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12598,8390 12771,8439
userdel	2 12771,8439 12925,8494
EOF
     },
     { from  => undef, # 
       until => 1094407200, # 5.9.2004 20:00
       text  => 'Leibnizstraße (Charlottenburg) zwischen Bismarckstr. und Otto-Suhr-Allee in Richtung Kantstr. Baustelle, Fahrtrichtung gesperrt bis 5.9.2004, 20:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 4359,11979 4345,11710
EOF
     },
     { from  => 1094508000, # 2004-09-07 00:00
       until => 1094853600, # 2004-09-11 00:00
       text  => 'L 771; (Gröben-Saarmund); Autobahnbrücke südl. Saarmund Brückenabriss u. -neubau Vollsperrung 08.09.2004-10.09.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -8879,-12309 -8457,-11261
EOF
     },
     { from  => 1094176800, # 2004-09-03 04:00
       until => 1094418000, # 2004-09-05 23:00
       text  => 'Hermannstraßenfest zwischen Flughafenstraße und Thomasstraße, Straße gesperrt, Dauer: 04.09.2004 04:00 Uhr bis 05.09.2004 23:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12180,7387 12122,7553
userdel	2 11920,8252 11933,8198
userdel	2 11920,8252 11892,8372
userdel	2 12041,7788 12055,7751 12075,7696
userdel	2 11979,8014 11960,8090
userdel	2 11979,8014 11998,7948 12025,7852
userdel	2 11933,8198 11960,8090
userdel	2 12075,7696 12090,7651 12122,7553
EOF
     },
     { from  => 1094187600, # 2004-09-03 07:00
       until => 1094407200, # 2004-09-05 20:00
       text  => 'Platz des 4. Juli zwischen Goerzallee und Osteweg gesperrt, Sportveranstaltung. Dauer: 04.09.2004 und 05.09.2004 jeweils von 07:00 Uhr bis 20:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2632,1706 2843,1281
EOF
     },
     { from  => undef, # 
       until => 1094421599, # 2004-09-05 23:59
       text  => 'Alt-Rudow in beiden Richtungen, zwischen Krokusstr. und Neudecker Weg Veranstaltung, Straße vollständig gesperrt (bis 05.09. 24 Uhr), Rudower Meilenfest ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16596,1730 16838,1457
userdel	2 16960,1282 16838,1457
EOF
     },
     { from  => undef, # 
       until => 1097791200, # 2004-10-15 00:00
       text  => 'Lückstr. Richtung stadteinwärts zwischen Schlichtallee und Wönnichstr. Baustelle, Straße gesperrt (bis Mitte 10.2004) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 16655,10622 16585,10650 16460,10699 16316,10755 16153,10818 16032,10842
EOF
     },
     { from  => 1094627730, # 2004-09-08 09:15
       until => 1096668000, # 2004-10-02 00:00
       text  => 'Gleim-Tunnel: Baustelle, Straße vollständig gesperrt (bis 01.10.2004)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9917,15613 10122,15647
EOF
     },
     { from  => 1094421600, # 2004-09-06 00:00
       until => 1103151600, # 2004-12-16 00:00
       text  => 'K 7318; (Pinnow-L 24-Haßleben); OD Buchholz Kanal- und Straßenbau Vollsperrung 07.09.2004-15.12.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32334,89385 31796,89304
EOF
     },
     { from  => 1094940000, # 2004-09-12 00:00
       until => 1099781940, # 200411062359
       text  => 'L 961; (Rogäsen-LG Genthin); zw. Zitz und LG Karow Straßenbauarbeiten Vollsperrung 13.09.2004-06.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -62793,-10268 -63668,-10212
userdel	2 -63668,-10212 -64600,-9931
EOF
     },
     { from  => 1094800133, # 2004-09-10 09:08
       until => 1095026400, # 2004-09-13 00:00
       text  => 'Straße des 17. Juni - Ebertstr. (Mitte) in beiden Richtungen zwischen Platz des 18. März und Entlastungsstr. sowie zwischen Behrenstr. und Dorotheenstr. Veranstaltung, Straße gesperrt (bis 12.09.2004) Jesustag 2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8214,12205 8089,12186 8063,12182
userdel	2 8214,12205 8515,12242
userdel	2 8539,12286 8560,12326
userdel	2 8539,12286 8515,12242
userdel	2 8595,12066 8600,12165
userdel	2 8540,12420 8560,12326
userdel	2 8515,12242 8600,12165
EOF
     },
     { from  => 1094940000, # 2004-09-12 00:00
       until => 1097097435, # 2004-10-09 00:00, vorzeitig aufgehoben
       text  => 'B 102; zw. Krz. Kampehl und Bückwitz Straßenbauarbeiten Vollsperrung 13.09.2004-08.10.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -53139,50022 -54295,49682
EOF
     },
     { from  => 1095544800, # 2004-09-19 00:00
       until => 1104620400, # 2005-01-02 00:00
       text  => 'B 96a; (Bahnhofstr., Hauptstr.); OD Schildow Kanal- und Straßenbau Vollsperrung 20.09.2004-01.01.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8493,25378 8370,25539
userdel	q4 8370,25539 8182,25608
EOF
     },
     { from  => 1105830000, # 2005-01-16 00:00
       until => 1116363037, # aufgehoben XXX 2005-05-28 00:00
       text  => 'K 6413; (Wriezener Straße); OL Buckow, zw. Weinbergsweg u. Ringstr. Kanal- u. Straßenbau Vollsperrung 17.01.2005-27.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 55664,19342 55558,19957
EOF
     },
     { from  => 1096322400, # 2004-09-28 00:00
       until => 1097100000, # 2004-10-07 00:00
       text  => 'K 6422; (Petershagener Str.); OL Fredersdorf, Nr. 5 u. 6; SW-Hausanschluß; Vollsperrung; 29.09.2004-06.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34139,13113 34896,13562
EOF
     },
     { from  => 1095717600, # 2004-09-21 00:00
       until => 1101855600, # 2004-12-01 00:00
       text  => 'L 17; (Königshorst-Warsow); zw. Jahnberge und Warsow Straßenbauarbeiten Vollsperrung 22.09.2004-30.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -40025,34118 -41261,33257
userdel	2 -40025,34118 -39143,34187
userdel	2 -38293,34081 -39143,34187
EOF
     },
     { from  => 1095890400, # 2004-09-23 00:00
       until => 1117576800, # 2005-06-01 00:00
       text  => 'L 40; (Großbeeren-Güterfelde); zw. Großbeeren u. Neubeeren Neubau Bauwerk Vollsperrung 24.09.2004-31.05.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2443,-6309 2715,-6365
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1103929200, # 2004-12-25 00:00
       text  => 'K 6907; (B 2-AS Ferch); OD Neuseddin Straßenbauarbeiten Vollsperrung 04.10.2004-24.12.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -18080,-12637 -17374,-13449
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1097704800, # 2004-10-14 00:00
       text  => 'L 90; (Potsdamer Str.); OD Werder, zw. A.-Kärger Str. u. Grüner Weg Schachtsanierung Vollsperrung 04.10.2004-13.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -21137,-4034 -21003,-4494
userdel	q4 -21003,-4494 -20851,-4878
EOF
     },
     { from  => 1113170400, # 2005-04-11 00:00
       until => 1119650400, # 2005-06-25 00:00
       text  => 'B 167; zw. Bad Freienw. u. Falkenberg, Höhe Papierfabrik Neubau von Durchlässen Vollsperrung 12.04.2005-24.06.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 49039,44131 48583,44366
userdel	q4 49039,44131 49691,43812
EOF
     },
     { from  => 1096578452, # 2004-09-30 23:07
       until => 1096862400, # 2004-10-04 06:00
       text  => 'Str. des 17. Juni / Ebertstr. (Tiergarten) in beiden Richtungen zwischen Entlastungsstr. und Brandenburger Tor Veranstaltung, Straße vollständig gesperrt (Vorbereitung Tag der Deutschen Einheit) (bis 04.10.2004, 6 Uhr) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8063,12182 8089,12186 8214,12205
userdel	2 8214,12205 8515,12242
userdel	2 8539,12286 8515,12242
userdel	2 8600,12165 8515,12242
userdel	2 8515,12242 8610,12254
userdel	2 8539,12286 8560,12326 8540,12420 
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1112306400, # 2005-04-01 00:00
       text  => 'K 6904; (Gröben-Nudow); OD Fahlhorst, Dorfstr. Straßenbauarbeiten Vollsperrung 04.10.2004-31.03.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -5452,-11456 -5709,-10987
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1100905200, # 2004-11-20 00:00
       text  => 'L 743; (Motzener Str.); OL Bestensee, zw. Eichhornstr. u. Fasanenstr. SW-Leitung Vollsperrung 04.10.2004-19.11.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26650,-18150 26437,-18650 26343,-18775
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1097877600, # 2004-10-16 00:00
       text  => 'L 78; (Potsdamer Str.); OD Saarmund, Eisenbahnbrücke Brückensanierung Vollsperrung 04.10.2004-15.10.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -9626,-6603 -8492,-9628 -8331,-9887
EOF
     },
     { from  => 1096754400, # 2004-10-03 00:00
       until => 1098050400, # 2004-10-18 00:00
       text  => 'L 171; (Hohen Neuendorf-Hennigsdorf); zw. Stolpe und AS Stolpe Straßenbauarbeiten Vollsperrung 04.10.2004-17.10.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -25,27812 -250,27739
EOF
     },
     { from  => 1096927200, # 2004-10-05 00:00
       until => 1097877600, # 2004-10-16 00:00
       text  => 'K 6003; (Friedrichswalde-LG-L100 Gollin); OD Reiersdorf Deckenerneuerung Vollsperrung 06.10.2004-15.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 24200,72512 25875,71662
userdel	q4 28100,70162 26500,71425
userdel	q4 26500,71425 25875,71662
EOF
     },
     { from  => 1115503200, # 2005-05-08 00:00
       until => 1117576800, # 2005-06-01 00:00
       text  => 'L 34; (Philip-Müller-Straße); OL Strausberg, zw. Feuerwehr und Nordkreuzung Fahrbahninstandsetzung halbseitig gesperrt; Einbahnstraße 09.05.2005-31.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 43553,20466 43584,20871
userdel	q4 43553,20466 43110,19818
EOF
     },
     { from  => 1097177672, # 2004-10-07 21:34
       until => 1098050400, # 2004-10-18 00:00
       text  => 'Ruppiner Chaussee (Hennigsdorf) Kreuzung Hennigsdorfer Straße wegen Bauarbeiten gesperrt (bis 17.10.2004)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -1854,24385 -1591,24124 -1214,23742
userdel	q4 -1854,24385 -1896,24275 -1935,24187
userdel	q4 -1854,24385 -1912,24442
EOF
     },
     { from  => undef, # 
       until => 1097271072, # aufgehoben
       text  => 'Werner-Voß-Damm (Tempelhof) in beidenRichtungen zwischen Boelckestraße und Bäumerplan Verkehrsbehinderung durch geplatzte Wasserleitung, Straße ind beiden Richtungen gesperrt.',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8553,7795 8637,7871
userdel	q4 8553,7795 8512,7757
EOF
     },
     { from  => 1097359200, # 2004-10-10 00:00
       until => 1097877600, # 2004-10-16 00:00
       text  => 'L 30; (Schönower Chaussee); OD Bernau Baumfällungen Vollsperrung 11.10.2004-15.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 21637,30946 20794,30899
userdel	q4 21637,30946 21955,30976
EOF
     },
     { from  => 1097208000, # 2004-10-08 06:00
       until => 1097442000, # 2004-10-10 23:00
       text  => 'Hauptstraße, zwischen Kreuzung Dominicusstr. und Kreuzung Kaiser-Wilhelm-Platz Kürbisfest, Straße gesperrt, Dauer: 09.10.2004 06:00 Uhr bis 10.10.2004 23:00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 6687,8385 6765,8480 6912,8617 6990,8685 7009,8705 7105,8788 7201,8870 7275,8960
EOF
     },
     { from  => 1097618400, # 2004-10-13 00:00
       until => 1097964000, # 2004-10-17 00:00
       text  => 'L 33; (Berliner Str.); OL Altlandsberg Vollsp. Vollsperrung 14.10.2004-16.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32100,18012 31887,17453
EOF
     },
     { from  => 1138133685, # 2006-01-24 21:14
       until => 1142463599, # 2006-03-15 23:59
       text  => 'Naumannstraße in beiden Richtungen zwischen Torgauer Str. und Tempelhofer Weg Straße vollständig gesperrt, für Radfahrer u.U. passierbar (bis Mitte März 2006)',
       type  => 'handicap',
       source_id => 'IM_002432',
       data  => <<EOF,
userdel	q4 7717,7759 7716,8048
EOF
     },
     { from  => 1097964000, # 2004-10-17 00:00
       until => 1099000800, # 2004-10-29 00:00
       text  => 'L 171; (Hohen Neuendorf-Hennigsdorf); Bereich Anschlußstelle; Ausbau AS Stolpe; Vollsperrung; 18.10.2004-28.10.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 375,28109 524,28171 938,28349
EOF
     },
     { from  => 1137804913, # 2006-01-21 01:55
       until => 1153739499, # 2006-08-31 23:59 1157061599
       text  => 'Blankenburger Weg (Pankow) von Bahnhofstr. bis Pasewalker Str. Baustelle, Fahrtrichtung gesperrt (bis Ende 08.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_82',
       data  => <<EOF,
userdel	1 12442,20805 12030,20490
EOF
     },
     { from  => 1098309600, # 2004-10-21 00:00
       until => 1099427095, # 1101596400, 2004-11-28 00:00 => undef
       text  => 'B 109; (Templin-Zehdenick); Bahnübergang südwestl.Ortsausg.Hammelspring Gleisbauarbeiten Vollsperrung 22.10.2004-27.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 10170,73230 8656,71489
EOF
     },
     { from  => 1098568800, # 2004-10-24 00:00
       until => 1102719600, # 2004-12-11 00:00
       text  => 'L 16; (Siedl.Schönwalde-Pausin); Bahnübergang Gleisbauarbeiten Vollsperrung; Umleitung 25.10.2004-10.12.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -10559,23255 -10737,23418
EOF
     },
     { from  => 1098741600, # 2004-10-26 00:00
       until => 1112306400, # 2005-04-01 00:00
       text  => 'B 101; (Luckenwalder-, Berliner Str.); OD Trebbin Straßenbauarbeiten Vollsperrung 27.10.2004-31.03.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	q4 -1623,-21150 -1902,-21499
EOF
     },
     { from  => 1097964000, # 2004-10-17 00:00
       until => 1098828000, # 2004-10-27 00:00
       text  => 'L 43; (Dorfstraße in Kobbeln); südl. vom Kieselwitzer Weg Durchlaßbau Vollsperrung 18.10.2004-26.10.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 90062,-33160 90271,-33398
EOF
     },
     { from  => 1113170400, # 2005-04-11 00:00
       until => 1149026400, # 2006-05-31 00:00
       text  => 'L 302 Schöneicher Str. OL Schöneiche, Dorfaue und Rüdersdorfer Str. Kanal- und Straßenbau Vollsperrung 12.04.2005-30.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 31221,8312 30700,8462
EOF
     },
     { from  => 1098655200, # 2004-10-25 00:00
       until => 1103842800, # 2004-12-24 00:00
       text  => 'L 30; (Schönower Chaussee); OL Bernau,zw. Weinbergstraße und Edelweißstraße Straßen- u. Radwegebau Vollsperrung 26.10.2004-23.12.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 21637,30946 20794,30899
userdel	q4 21637,30946 21955,30976
EOF
     },
     { from  => 1098568800, # 2004-10-24 00:00
       until => 1101855600, # 2004-12-01 00:00
       text  => 'L 792; Trebbiner Str.-Glasower Damm: Straßenbau, Vollsperrung, 25.10.2004-30.11.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 11186,-5297 10994,-5361
EOF
     },
     { from  => 1098914007, # 2004-10-27 23:53
       until => 1101769140, # 200411292359
       text  => 'Gleimstr. (Mitte) in beiden Richtungen zwischen Gleimtunnel und Graunstr. Baustelle, Straße vollständig gesperrt (bis 29.11.2004)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9917,15613 10122,15647
EOF
     },
     { from  => 1098828000, # 2004-10-27 00:00
       until => 1103410800, # 2004-12-19 00:00
       text  => 'L 171; (Hohen Neuendorf-Hennigsdorf); Bereich Anschlußstelle Straßenbau Vollsperrung 28.10.2004-18.12.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -926,27132 -2118,26060
EOF
     },
     { from  => 1099177200, # 2004-10-31 01:00
       until => 1101078000, # 2004-11-22 00:00
       text  => 'L 200; (Breite Str.); OD Eberswalde, zw. BÜ und Neue Str. Straßenbauarbeiten, Vollsperrung 01.11.2004-21.11.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 38264,50086 38035,49183
userdel	q4 38264,50086 38845,51258
EOF
     },
     { from  => 1101942000, # 2004-12-03 06:00
       until => 1102287540, # 2004-12-05 23:59
       file  => 'rixdorfer_weihnachtsmarkt.bbd',
       text  => 'Rixdorfer Weihnachtsmarkt, 03.12.2004-05.12.2004',
       type  => 'gesperrt',
     },
     { from  => 1100038749, # 2004-11-09 23:19
       until => 1100559600, # 2004-11-16 00:00
       text  => 'Lennéstr. zwischen Bellvuestr. und Eberstr. Baustelle, Straße gesperrt Richtung Ebertstr. (bis 15.11.2004) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8489,11782 8436,11766 8326,11732
userdel	2 8326,11732 8223,11700
EOF
     },
     { from  => 1092520800, # 2004-08-15 00:00
       until => 1104620400, # 2005-01-02 00:00
       text  => 'L 21; (Mühlenbecker Str.); OL Schildow grundh. Straßenbau Vollsperrung 16.08.2004-01.01.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8231,26584 8194,25966
EOF
     },
     { from  => 1099177200, # 2004-10-31 01:00
       until => 1123884000, # 2005-08-13 00:00
       text  => 'L 401; (Lindenallee, Fontaneallee); OL Zeuthen, zw. Forstweg und Fährstr. grundhafter Straßenbau Vollsperrung 01.11.2004-12.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26581,-7087 26146,-6218
EOF
     },
     { from  => 1089496800, # 2004-07-11 00:00
       until => 1114898400, # 2005-05-01 00:00
       text  => 'K 6740; (L 38 östl. Berkenbrück-Steinhöfel); OL Demnitz Straßenbauarbeiten Vollsperrung 12.07.2004-30.04.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 64514,-1544 64439,-1243
EOF
     },
     { from  => 1097359200, # 2004-10-10 00:00
       until => 1125525600, # 2005-09-01 00:00
       text  => 'L 19; (Zechlinerhütte-Wesenberg (MVP)); zw. Abzw. Klein Zerlang u. LG (nö. Prebelowbrücke) Brückenneubau Vollsperrung 11.10.2004-31.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -26403,85177 -26316,84900
EOF
     },
     { from  => 1100991600, # 2004-11-21 00:00
       until => 1102719600, # 2004-12-11 00:00
       text  => 'L 166; (B 5-Friesack-Garz); zw. B 5 u. Friesack u. KG nördl. Zootzen Straßenbauarbeiten Vollsperrung 22.11.2004-10.12.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -45632,38429 -46170,36687
EOF
     },
     { from  => 1101078000, # 2004-11-22 00:00
       until => 1101596400, # 2004-11-28 00:00
       text  => 'L 201; (Nauener Chaussee); OD Falkensee, Bahnübergang am Finkenkrug Gleisbauarbeiten Vollsperrung 23.11.2004-27.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -13756,20176 -13875,20548 -13897,20621
EOF
     },
     { from  => 1100559600, # 2004-11-16 00:00
       until => 1103583600, # 2004-12-21 00:00
       text  => 'L 23; (Templin-Lychen); OD Lychen Straßenbau Vollsperrung 17.11.2004-20.12.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 3125,88753 2788,89447
EOF
     },
     { from  => 1116572111, # 2005-05-20 08:55
       until => 1116885600, # 2005-05-24 00:00
       text  => 'Volksradstr. (Friedrichsfelde) in beiden Richtungen Baustelle, Straße vollständig gesperrt (bis 23.05.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 17475,10442 17565,10782 17621,10994
userdel	q4 17475,10442 17427,10259
EOF
     },
     { from  => 1100991600, # 2004-11-21 00:00
       until => 1101855600, # 2004-12-01 00:00
       text  => 'L 236; (Alberichstr. in OL Börnicke); Alberichstr. zw. E.-Thälmann-Str. und Börnicker Chau Ausbau Straße, Radweg Vollsperrung 22.11.2004-30.11.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26136,29466 25361,29596
EOF
     },
     { from  => 1101507035, # 2004-11-26 23:10
       until => 1102980501, # passierbar für Radfahrer!
       text  => 'Ebertstr. Richtung Potsdamer Platz zwischen Behrensstr. und Hannah-Ahrendt-Str. Baustelle, Fahrtrichtung gesperrt (bis April 2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 8595,12066 8581,11896 8571,11846
EOF
     },
     { from  => 1101337200, # 2004-11-25 00:00
       until => 1102374000, # 2004-12-07 00:00
       text  => 'B 167; (Zerpenschleuse-Liebenwalde); zw. OA Liebenwalde und Abzw. Hammer Erneuerung Durchlass Vollsperrung 26.11.2004-06.12.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 11228,52175 9686,52037
EOF
     },
     { from  => 1085263200, # 2004-05-23 00:00
       until => 1103583600, # 2004-12-21 00:00
       text  => 'L 75; (Karl-Marx-Straße); OD Großziethen, von Dorfstraße bis Friedhofsweg Straßenbauarbeiten Vollsperrung 24.05.2004-20.12.2004 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 13225,-681 13090,205 13225,-681 13309,-1268
EOF
     },
     { from  => 1102654800, # 2004-12-10 06:00
       until => 1102892400, # 2004-12-13 00:00
       text  => 'Sophienstraße, zwischen Große Hamburger Straße und Rosenthaler Straße, für den Fahrzeugverkehr gesperrt (9. Umwelt- und Weihnachtsmarkt). Dauer: 11.12.2004 06:00 Uhr bis 12.12.2004 24:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9982,13411 10312,13231
EOF
     },
     { from  => 1102050000, # 2004-12-03 06:00
       until => 1102204800, # 2004-12-05 01:00
       text  => 'Bahnhofstr. zwischen Goltzstr. und Steinstraße Weihnachstsmarkt, in beiden Richtungen gesperrt. Dauer: 04.12.2004, 06:00 Uhr bis 05.12.2004, 01:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 10453,-2133 10747,-2129
EOF
     },
     { from  => 1101337200, # 2004-11-25 00:00
       until => 1101769200, # 2004-11-30 00:00
       text  => 'B 198; zw. Althüttendorf und Joachimsthal Einbau Deckschicht Vollsperrung 26.11.2004-29.11.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 34237,62950 34368,62531
EOF
     },
     { from  => 1101337200, # 2004-11-25 00:00
       until => 1103065200, # 2004-12-15 00:00
       text  => 'L 912; (Päwesin-Gortz); Brücke über Seeverbindung bei Päwesin Brückenneubau Vollsperrung 26.11.2004-14.12.2004 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -37026,11176 -36669,10926 -36435,10883
EOF
     },
     { from  => 1102981307, # 2004-12-14 00:41
       until => 1103324400, # 2004-12-18 00:00
       text  => 'Emmentaler Str. (Reinickendorf) Richtung Westen zwischen Residenzstr. und Gamsbartweg Baustelle, Straße Richtung Westen gesperrt, Einbahnstraßenregelung Richtung Osten (bis 17.12.2004)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	q4; 7693,18481 7350,18262
EOF
     },
     { from  => 1101934006, # 2004-12-01 21:46
       until => 1114976619, # aufgehoben XXX 1117576800 2005-06-01 00:00
       text  => 'Akeleiweg, Tiefbauarbeiten, Straße von Eisenhutweg in Richtung Stubenrauchstraße gesperrt, Dauer: bis 31.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 17894,2783 17631,3200 17603,3240 17388,3576
EOF
     },
     { from  => 1102538190, # 2004-12-08 21:36
       until => 1103929200, # 2004-12-25 00:00
       text  => 'Düsseldorfer Str. in beiden Richtungen zwischen Brandenburgische Str. und Konstanzer Str. Baustelle, Straße vollständig gesperrt (bis 24.12.2004)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 4151,10026 3906,10035
EOF
     },
     { from  => undef, # 
       until => 1122058621, # nicht mehr XXX
       text  => 'Johannisthaler Chaussee Zwischen Rudower Straße und Königsheideweg beidseitig Brückenarbeiten, gesperrt ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15573,4122 15594,4152 15618,4189
userdel	2 15669,4266 15640,4222 15618,4189
EOF
     },
     { from  => 1102712612, # 2004-12-10 22:03
       until => 1102910400, # 2004-12-13 05:00
       text  => 'Schulze-Boysen-Str. (Lichtenberg) in beiden Richtungen zwischen Wiesenweg und Pfarrstr. Kranarbeiten, Straße vollständig gesperrt (bis 13.12.2004 ca. 5:00 Uhr)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15452,11330 15480,11392
EOF
     },
     { from  => 1105225200, # 2005-01-09 00:00
       until => 1122406057, # 1122760800 2005-07-31 00:00
       text  => 'K 6938; (Görzke-Hohenlobbese); zw. OL Görzke und Abzw. Reppinichen, Brücke Brücken- und Straßenbau Vollsperrung 10.01.2005-30.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -59599,-27568 -59265,-27286
EOF
     },
     { from  => 1102980646, # 2004-12-14 00:30
       until => 1104015600, # 2004-12-26 00:00
       text  => 'Weihnachtsmarkt am Opernpalais, bis 25.12.2004',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9890,12161 9875,12254 9853,12402
userdel	2 9801,12245 9782,12393
EOF
     },
     { from  => undef, #
       until => 1135551600, # 2005-12-26 00:00
       text  => 'Weihnachtsmarkt am Schloßplatz, bis 25.12.2005',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 10170,12261 10083,12442
EOF
     },
     { from  => 1136837576, # 2006-01-09 21:12
       until => 1137016800, # 2006-01-11 23:00
       text  => 'Fähre (Ketzin) außer Betrieb bis 11.01.2006 23:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -17728,-6975 -17643,-7028
EOF
     },
     { from  => 1104409481, # 2004-12-30 13:24
       until => 1104573600, # 2005-01-01 11:00
       text  => 'Str. des 17. Juni: Großer Stern - Brandenburger Tor (Mitte) in allen Richtungen sowie angrenzende Nebenstraßen Veranstaltung, Straße vollständig gesperrt (bis 01.01.2005 ca. 11:00 Uhr)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8214,12205 8089,12186 8063,12182
userdel	q4 8214,12205 8515,12242
userdel	q4 6653,12067 6642,12010
userdel	q4 6685,11954 6744,11936
userdel	q4 8610,12254 8515,12242
userdel	q4 7816,12150 8063,12182
userdel	q4 7816,12150 7383,12095
userdel	q4 6744,11936 6809,11979
userdel	q4 8851,12123 8737,12098
userdel	q4 6809,11979 6828,12031
userdel	q4 8539,12286 8560,12326
userdel	q4 8539,12286 8515,12242
userdel	q4 6828,12031 7383,12095
userdel	q4 6828,12031 6799,12083
userdel	q4 8775,12457 8540,12420
userdel	q4 8737,12098 8595,12066
userdel	q4 6642,12010 5901,11902
userdel	q4 6642,12010 6685,11954
userdel	q4 8595,12066 8600,12165
userdel	q4 8540,12420 8560,12326
userdel	q4 8515,12242 8600,12165
userdel	q4 6725,12113 6690,12104 6653,12067
userdel	q4 6799,12083 6754,12108 6725,12113
EOF
     },
     { from  => 1105311600, # 2005-01-10 00:00
       until => 1105830000, # 2005-01-16 00:00
       text  => 'K 6304; (Priorter Chaussee); OD Priort, Bahnübergang Gleisbauarbeiten Vollsperrung 11.01.2005-15.01.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -19149,11495 -19058,11636
EOF
     },
     { from  => 1106434800, # 2005-01-23 00:00
       until => 1106780400, # 2005-01-27 00:00
       text  => 'L 62; (Elsterwerda-Hohenleipisch); Bahnübergang bei Dreska Gleisbauarbeiten Vollsperrung 24.01.2005-26.01.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22508,-102744 22382,-102254
EOF
     },
     { from  => 1112047200, # 2005-03-29 00:00
       until => 1112824800, # 2005-04-07 00:00
       text  => 'L 86; zw. Schmergow und Ketzin Straßenbau Vollsperrung 30.03.2005-06.04.2005',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -27793,4863 -27127,5270
EOF
     },
     { from  => 1119996000, # 2005-06-29 00:00
       until => 1122415200, # 2005-07-27 00:00
       text  => 'K 6161; (Ernst-Thälmann-Str.); OD Schulzendorf, Kanal- und Straßenbau Vollsperrung 30.06.2005-30.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25185,-3955 23463,-4466
EOF
     },
     { from  => 1107475200, # 2005-02-04 01:00
       until => 1107741600, # 2005-02-07 03:00
       text  => 'Berliner Straße, Zwischen Kreuzung Granitzstraße und Florastr. in beiden Richtungen Brückenarbeiten, gesperrt, Dauer: 05.02.2005 01:00 Uhr bis 07.02.2005 03:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 10846,17992 10859,17854
EOF
     },
     { from  => 1075827600, # 2004-02-03 18:00
       until => 1107748800, # 2005-02-07 05:00
       text  => 'Blockdammweg in Richtung Köpenicker Chaussee ab Hönower Wiesenweg gesperrt (Arbeiten an Gasleitung). Dauer: 04.02.2004 18:00 Uhr bis 07.02.2005 05:00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 17375,8847 17072,8714
EOF
     },
     { from  => 1107730800, # 2005-02-07 00:00
       until => 1108681200, # 2005-02-18 00:00
       text  => 'K 6148; (Brand-Halbe); Bahnübergang in OL Teurow Arbeiten an Signaltechnik Vollsperrung 08.02.2005-17.02.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 32937,-34794 32747,-34772
EOF
     },
     { from  => 1108854000, # 2005-02-20 00:00
       until => 1109199600, # 2005-02-24 00:00
       text  => 'L 62; (Elsterwerda-Hohenleipisch); Bahnübergang bei Dreska Gleisbauarbeiten Vollsperrung 21.02.2005-23.02.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22508,-102744 22382,-102254
EOF
     },
     { from  => 1108249200, # 2005-02-13 00:00
       until => 1110145553, # XXX not anymore, was 1114898400 2005-05-01 00:00
       text  => 'Im Zeitraum vom 14.02.2005 bis 30.04.2005 besteht für die L 73 zwischen Langerwisch und Wildenbruch Vollsperrung auf Grund von Bauarbeiten. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -12156,-13509 -12221,-13124
userdel	2 -12156,-13509 -12177,-13787
userdel	2 -12372,-12676 -12221,-13124
userdel	2 -12372,-12676 -12443,-12223 -12459,-12120
userdel	2 -12337,-10735 -12433,-11898 -12459,-12120
EOF
     },
     { from  => 1108684644, # 2005-02-18 00:57
       until => 1122847199, # 2005-07-31 23:59
       text  => 'Fürstenwalder Damm zwischen Bölschestr. und Stillerzeile Baustelle, Straße stadteinwärts gesperrt (bis Ende 07.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q3; 25579,5980 25121,5799
EOF
     },
     { from  => 1108681200, # 2005-02-18 00:00
       until => 1109372400, # 2005-02-26 00:00
       text  => 'L 791; (Luckenwalder Str.); Bahnübergang in Zossen, Havarie, Vollsperrung, 19.02.2005-25.02.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13557,-21831 13014,-22300
userdel	2 13557,-21831 13988,-21217
EOF
     },
     { from  => 1109280022, # 2005-02-24 22:20
       until => 1109631600, # 2005-03-01 00:00
       text  => 'Späthstraße (Treptow) In beiden Richtungen zwischen A113 und Königsheideweg Störungen durch geplatzte Wasserleitung, Straße gesperrt (bis 28.02.2005) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 14687,5215 14994,5193
userdel	2 14994,5193 15174,5463
userdel	2 15174,5463 15382,5687
EOF
     },
     { from  => 1113429600, # 2005-04-14 00:00
       until => 1113775200, # 2005-04-18 00:00
       text  => 'L 24; (AS Pfingstberg-Gerswalde); Bereich AS Pfingstberg, Brücke A 11 Brückenabruch Vollsperrung 15.04.2005-17.04.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 41292,81052 41593,80703
EOF
     },
     { from  => 1109545200, # 2005-02-28 00:00
       until => 1128117600, # 2005-10-01 00:00
       text  => 'B 179; (Berliner Str.); OL Königs Wusterhausen, zw. Schloßplatz u. Funkerberg Kanalarbeiten halbseitig gesperrt (XXX welche Richtung?); Einbahnstraße 01.03.2005-30.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 25859,-11559 25640,-11357
EOF
     },
     { from  => 1109365909, # 2005-02-25 22:11
       until => 1125525599, # 2005-08-31 23:59
       text  => 'Hussitenstr. (Mitte) in Richtung Bernauer Str. zwischen Bernauer Str. und Usedomer Str. Baustelle, Fahrtrichtung gesperrt (bis Ende 08.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 9112,14771 9300,14615 9378,14553 9472,14478
EOF
     },
     { from  => 1109628414, # 2005-02-28 23:06
       until => 1135591662, # was 1136069999 2005-12-31 23:59
       text  => 'Ringstr. (Steglitz) Richtung Finkensteinallee zwischen Drakestr. und Finckensteinallee Baustelle, Fahrtrichtung gesperrt (bis 12.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 3507,3635 3375,3544 3184,3413 3050,3316 2701,3064 2639,2989 2638,2843
EOF
     },
     { from  => 1110917391, # 2005-03-15 21:09
       until => 1111100400, # 2005-03-18 00:00
       text  => 'Augsburger Str. (Charlottenburg) in beiden Richtungen zwischen Joachimstaler Str. und Rankestr. Baustelle, Straße vollständig gesperrt (Kranarbeiten) (bis 17.03.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 5636,10626 5479,10719
EOF
     },
     { from  => 1110063600, # 2005-03-06 00:00
       until => 1122674400, # 2005-07-30 00:00
       text  => 'K 6738; (L 36 nördl. Steinhöfel-Müncheberg); OD Tempelberg Straßenausbau Vollsperrung 07.03.2005-29.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 62529,5578 62084,5754
userdel	q4 61809,5952 62084,5754
EOF
     },
     { from  => 1111960800, # 2005-03-28 00:00
       until => 1125525600, # 2005-09-01 00:00
       text  => 'K 6907; (B 1 Neuseddin-Ferch); OD Neuseddin, Kunersdorfer Str. Straßenbauarbeiten Vollsperrung 29.03.2005-31.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -16605,-14239 -17374,-13449
userdel	q4 -18080,-12637 -17374,-13449
EOF
     },
     { from  => 1111437775, # 2005-03-21 21:42
       until => 1111705200, # 2005-03-25 00:00
       text  => 'Sterndamm (Treptow) in Richtung Rudow zwischen Königsheideweg und Winckelmannstr. Baustelle, Fahrtrichtung gesperrt, eine Umleitung ist eingerichtet (bis 24.03.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 17518,4644 17428,4503
EOF
     },
     { from  => 1110235074, # 2005-03-07 23:37
       until => 1110317384, # XXX from 2005-12-09 marked as removed, check!
       text  => 'Unter den Linden (Mitte) Richtung Westen zwischen Schadowstr. und Wilhelmstr. Baustelle, Straße vollständig gesperrt',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 9028,12307 8804,12280
EOF
     },
     { from  => 1127503882, # 2005-09-23 21:31
       until => 1127772000, # 2005-09-27 00:00
       text  => 'Dahlwitzer Landstr. - Bölschestr. (Köpenick) in beiden Richtungen an der Bahnbrücke Bölschestr. Baustelle, Straße vollständig gesperrt (Brücken- und Straßenarbeiten) (bis 26.09.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25585,6050 25579,5980
EOF
     },
     { from  => 1110668400, # 2005-03-13 00:00
       until => 1111186800, # 2005-03-19 00:00
       text  => 'L 29; (Oderberg-Hohenfinow); OD Oderberg Baumfällarb. Dammsicherung Vollsperrung 14.03.2005-18.03.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 52671,51846 51496,51542
EOF
     },
     { from  => 1110679200, # 2005-03-13 03:00
       until => 1116194400, # 2005-05-16 00:00
       text  => 'Wassersportallee - Regattastraße, Zwischen Kreuzung Adlergestell und Kreuzung Wassersportallee in beiden Richtungen gesperrt, Baustelle, Dauer: 14.03.2005 03:00 Uhr bis 15.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 22449,1281 22217,1108
userdel	q4 22449,1281 22663,1441
userdel	q4 22217,1108 22162,1067
EOF
     },
     { from  => 1110862800, # 2005-03-15 06:00
       until => 1111013999, # 2005-03-16 23:59
       text  => 'Kantstraße Richtung Spandau: Zwischen Kreuzung Hardenbergstraße und Kreuzung Joachimstaler Straße gesperrt, Dauer: 16.03.2005 06:00 Uhr bis 16:00 Uhr (Filmarbeiten) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 5652,11004 5613,10963 5505,10971
EOF
     },
     { from  => 1110700800, # 2005-03-13 09:00
       until => 1111168800, # 2005-03-18 19:00
       text  => 'Die Stadthausstraße ist zwischen Türschmidtstraße und Archibaldweg gesperrt. Grund Bauarbeiten. Dauer: 14.03.05, 09.00 Uhr bis 18.03.05, 19.00 Uhr. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15657,10846 15628,10915
EOF
     },
     { from  => 1112479200, # 2005-04-03 00:00
       until => 1113602400, # 2005-04-16 00:00
       text  => 'B 246; (Gerichtsstr.); OL Zossen, zw. Friedhofsweg u. Luchweg Straßenbauarbeiten Vollsperrung 04.04.2005-15.04.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 15178,-20983 15072,-21175
EOF
     },
     { from  => 1110841200, # 2005-03-15 00:00
       until => 1117576800, # 2005-06-01 00:00
       text  => 'K 6501; (Bahnhofstr.); OD Schildow, zw. Hauptstr. u. F.-Schmidt-Str. grundhafter Straßenbau Vollsperrung 16.03.2005-31.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8066,25646 8182,25608
EOF
     },
     { from  => 1149623367, # 2006-06-06 21:49
       until => 1154383199, # 2006-07-31 23:59
       text  => 'Nennhauser Damm (Spandau) stadteinwärts zwischen Heerstr. und Döberitzer Weg Baustelle, Fahrtrichtung gesperrt (bis Ende 07.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002500',
       data  => <<EOF,
userdel	1 -8671,13312 -8643,13383 -8358,13340 -8011,13351
EOF
     },
     { from  => 1111524913, # 2005-03-22 21:55
       until => 1120168800, # 2005-07-01 00:00
       text  => 'Pistoriusstr. (Weissensee) Richtung Berliner Allee zwischen Mirbachplatz und Parkstr. Baustelle, Fahrtrichtung gesperrt (bis 30.06.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 13386,16408 13652,16297 13797,16237
EOF
     },
     { from  => 1111960800, # 2005-03-28 00:00
       until => 1119477600, # 2005-06-23 00:00
       text  => 'B 2; (Bernau-Biesenthal); B 2, OD Rüdnitz grundh. Ausbau, Bau Kreisverk. Vollsperrung 29.03.2005-22.06.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25095,35601 24915,35340
EOF
     },
     { from  => 1111960800, # 2005-03-28 00:00
       until => 1120428000, # 2005-07-04 00:00
       text  => 'L 23; (Joachimsthal-Templin); OD Joachimsthal Neubau Durchlass Vollsperrung 29.03.2005-03.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32966,64019 33080,63939 33254,63446
EOF
     },
     { from  => 1111532400, # 2005-03-23 00:00
       until => 1114898400, # 2005-05-01 00:00
       text  => 'L 291; (Oderberger Str.); OD Eberswalde, Einm. Breite Str. Straßenbauarbeiten Vollsperrung 24.03.2005-30.04.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 38035,49183 37900,48350 37875,48253
EOF
     },
     { from  => 1111960800, # 2005-03-28 00:00
       until => 1115157600, # 2005-05-04 00:00
       text  => 'L 23; (Templin-Lychen); OD Lychen, Kreuzungsber. Straßenbau Vollsperrung 29.03.2005-03.05.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	q4 3125,88753 2788,89447
EOF
     },
     { from  => 1113084000, # 2005-04-10 00:00
       until => 1113602400, # 2005-04-16 00:00
       text  => 'L 622; (Rückersdorf-Doberlug Kirchhain); südl. Doberlug-Kirchhain, Höhe Hammerteich Baumfällarbeiten Vollsperrung 11.04.2005-15.04.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22495,-89358 22558,-89699
EOF
     },
     { from  => 1112072400, # 2005-03-29 07:00
       until => 1112810400, # 2005-04-06 20:00
       text  => 'die Fähre Ketzin ist vom 30.03.05 07.00 Uhr bis 06.04.2005 20.00 Uhr aufgrund Bauarbeiten gesperrt',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -26784,5756 -26840,5684
EOF
     },
     { from  => 1112339478, # 2005-04-01 09:11
       until => 1112562000, # 2005-04-03 23:00
       text  => 'Wilhelmstraße, Straße gesperrt bis 03.04.2005 23:00 Uhr (Frühlingsfest zwischen Pichelsdorfer Straße und Adamstraße). ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3887,13057 -3791,13357
userdel	2 -3887,13057 -3937,12971 -3974,12914 -4028,12831
userdel	2 -4028,12831 -4081,12765 -4150,12689
EOF
     },
     { from  => 1111960800, # 2005-03-28 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'B 2; (Leipziger Str.); OD Treuenbrietzen, zw. Krz.Leipz.-/Belziger Str. u. Hinter d.Mauer Straßenbau, KVK Vollsperrung 29.03.2005-30.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -25472,-35585 -24967,-35112
EOF
     },
     { from  => 1113256800, # 2005-04-12 00:00
       until => 1113602400, # 2005-04-16 00:00
       text  => 'L 23; (Britz-Joachimsthal); Bereich AS Chorin Brückenbauarbeiten Vollsperrung 13.04.2005-15.04.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 35962,59463 35405,59832
EOF
     },
     { from  => undef, # 
       until => 1133819018, # not anymore
       text  => 'L 711; (Krausnick-AS Stakow); zw. Krausnick u. Bahnhof Brand Einschränkung Tragfähigkeit Vollsperrung, Dauer unbekannt ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 35178,-41015 37450,-41050 37950,-41275 38512,-41000 40398,-40989
EOF
     },
     { from  => 1113256800, # 2005-04-12 00:00
       until => 1113688800, # 2005-04-17 00:00
       text  => 'L 30; (Bernauer Str.); OL Altlandsberg zw. Strausberger Str. u. Buchholzer Str. Kanalarbeiten Vollsperrung 13.04.2005-16.04.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32665,17841 32985,17127 33589,15778
EOF
     },
     { from  => 1113084000, # 2005-04-10 00:00
       until => 1114812000, # 2005-04-30 00:00
       text  => 'L 59; (Bormannstr.); OL Bad Liebenwerda Kanalneubau Vollsperrung 11.04.2005-29.04.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 12571,-99519 12788,-100207
EOF
     },
     { from  => 1113336339, # 2005-04-12 22:05
       until => 1117490400, # 2005-05-31 00:00
       text  => 'Zimmermannstr. (Marzahn) Richtung Osten zwischen Köpenicker Str. und Lindenstr. Baustelle, Fahrtrichtung gesperrt (bis 30.05.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 21093,9179 21206,9130 21351,9066
EOF
     },
     { from  => 1123452000, # 2005-08-08 00:00
       until => 1130623200, # 2005-10-30 00:00
       text  => 'B 101; (Berliner Str.); OD Trebbin, zw. Bahnhofstr. u. Luckenwalder Str., Straßenbauarbeiten, Vollsperrung, 09.08.2005-29.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -1902,-21499 -1623,-21150
EOF
     },
     { from  => 1113688800, # 2005-04-17 00:00
       until => 1119045600, # 2005-06-18 00:00
       text  => 'L 141; (B 5-Neustadt); zw. B 5 und Dreetz Deckenerneuerung Vollsperrung 18.04.2005-17.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -50303,42160 -50198,42376
userdel	2 -50303,42160 -50496,42007
EOF
     },
     { from  => 1113775200, # 2005-04-18 00:00
       until => 1130536800, # 2005-10-29 00:00
       text  => 'L 14; (Großderschau- Bahnhof Zernitz); Brücke über die Neue Jägelitz bei Zernitz Brückensanierung Vollsperrung 19.04.2005-28.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -63163,51264 -63375,50856
EOF
     },
     { from  => 1112652000, # 2005-04-05 00:00
       until => 1122242400, # 2005-07-25 00:00
       text  => 'B 273; (Potsdamer Str.); OD Potsdam, OT Bornim, zw. Florastr. u. Rückertstr. Kanalarbeiten halbseitig gesperrt; Einbahnstraße 06.04.2005-24.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -16640,1304 -15557,809 -15527,795
userdel	q4 -16640,1304 -16894,1485
EOF
     },
     { from  => 1113775200, # 2005-04-18 00:00
       until => 1120168800, # 2005-07-01 00:00
       text  => 'L 691; (Dübrichen-Wehrhain-B 87); Kreuzung zw. Dübrichen u. Frankenhain Knotenausbau Vollsperrung 19.04.2005-30.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 11561,-75017 12171,-75229
EOF
     },
     { from  => 1113869983, # 2005-04-19 02:19
       until => 1114812000, # 2005-04-30 00:00
       text  => 'Kastanienallee (Prenzlauer Berg) Richtung stadtauswärts zwischen Schwedter Str. und Oderberger Str. Baustelle, Fahrtrichtung gesperrt (bis 29.04.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 10534,14460 10723,14772
EOF
     },
     { from  => 1113714000, # 2005-04-17 07:00
       until => 1114034400, # 2005-04-21 00:00
       text  => 'Kronenstraße (Mitte) in beiden Richtungen, zwischen Charlottenstraße und Markgrafenstraße Kranarbeiten, Straße gesperrt, Dauer: 18.04.2005, 07.00 Uhr bis 20.04.2005',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 9569,11631 9701,11649
EOF
     },
     { from  => 1113870146, # 2005-04-19 02:22
       until => 1114553274, # XXX ich konnte aus der S-Bahn heraus nichts erkennen 2005-12-31 23:59
       text  => 'Rosa-Luxemburg-Str. (Mitte) Richtung stadtauswärts, zwischen Memhardstr. und Torstr. Baustelle, Straße vollständig gesperrt (bis Ende 2005) Umleitung über Karl-Liebknecht-Straße - Torstraße',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 10755,13152 10846,13362 10790,13565 10777,13614 10746,13673
EOF
     },
     { from  => 1112220000, # 2005-03-31 00:00
       until => 1115244000, # 2005-05-05 00:00
       text  => 'B 101; (Luckenwalder-, Berliner Str.); OD Trebbin, Knoten Beelitzer Str. Straßenbauarbeiten Vollsperrung 01.04.2005-04.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -1902,-21499 -1969,-21492
EOF
     },
     { from  => 1114468172, # 2005-04-26 00:29
       until => 1136069999, # 2005-12-31 23:59
       text  => 'Berliner Allee Richtung stadtauwärts, zwischen Langhanstr. und Lindenallee Baustelle, Fahrtrichtung gesperrt (bis Ende 2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 13540,15928 13751,16009 14014,16106 14067,16127 14371,16252
EOF
     },
     { from  => 1138319749, # 2006-01-27 00:55
       until => 1146434399, # 2006-04-30 23:59
       text  => 'Vulkanstr. (Lichtenberg) von Landsberger Allee bis Herzbergstr. Baustelle, Fahrtrichtung gesperrt (bis Ende 04.2006)',
       type  => 'handicap',
       source_id => 'INKO_77420',
       data  => <<EOF,
userdel	q4; 15838,14319 15897,13942 15892,13534
EOF
     },
     { from  => 1114466400, # 2005-04-26 00:00
       until => 1143756000, # 2006-03-31 00:00
       text  => 'B 001 Potsdamer Str. OD Groß Kreutz Kanal- und Straßenbau; Vollsperrung 27.04.2005-30.03.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4	-28793,-1618 -31991,-1024
EOF
     },
     { from  => 1115503200, # 2005-05-08 00:00
       until => 1116021600, # 2005-05-14 00:00
       text  => 'L 30; (Tiergartenstr.); OT Neue Mühle, Schleuse Straßenbauarbeiten Vollsperrung 09.05.2005-13.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	2 27543,-11912 27657,-11741
EOF
     },
     { from  => 1122760800, # 2005-07-31 00:00
       until => 1124056800, # 2005-08-15 00:00
       text  => 'B 179; (Cottbuser-/ Fichtestr.); OL Königs Wusterhausen, Bahnübergang Fichtestr. Umbau Bahnübergang Vollsp * 01.08.2005-14.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26313,-13049 26028,-12312
EOF
     },
     { from  => 1114725600, # 2005-04-29 00:00
       until => 1114984800, # 2005-05-02 00:00
       text  => 'B 198; (Schwedter Str.); OD Prenzlau, Kno. Uckermarkkaserne Ausbau Knotenpunkt Vollsperrung 30.04.2005-01.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 40682,100854 40507,100965
EOF
     },
     { from  => 1114725600, # 2005-04-29 00:00
       until => 1114984800, # 2005-05-02 00:00
       text  => 'L 90; (Eisenbahnstr.); OD Werder, zw. B1 Berliner Str. u. Phöbener Str. 126. Baumblütenfest Vollsperrung 30.04.2005-01.05.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -21137,-4034 -21112,-3787
EOF
     },
     { from  => 1114898400, # 2005-05-01 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'L 76; (Mahlower Str.); OL Teltow, zw. Ruhlsdorfer u. A.-Saefkow-Str. Kanal- und Straßenbau Vollsperrung 02.05.2005-30.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 1453,-746 1550,-761 1709,-953
userdel	q4 1916,-1090 1709,-953
EOF
     },
     { from  => 1115589537, # 2005-05-08 23:58
       until => 1126821599, # 2005-09-15 23:59
       text  => 'Danziger Str. (Prenzlauer Berg) Richtung Osten zwischen Schönhauser Allee und Knaackstr. Baustelle Fahrtrichtung gesperrt, Umleitung: Schönhauser Allee - Sredzkistr. - Knaackstr. (bis Mitte 09.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 10889,15045 11056,15009
EOF
     },
     { from  => 1115535600, # 2005-05-08 09:00
       until => 1118354400, # 2005-06-10 00:00
       text  => 'Rosenfelder Straße Richtung Frankfurter Allee zwischen Skandinavische Straße und Frankfurter Allee Baustelle, Straße gesperrt, Dauer: 09.05.2005, 09.00 Uhr bis 09.06.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 17363,11972 17249,11802
EOF
     },
     { from  => 1116280800, # 2005-05-17 00:00
       until => 1152396000, # 2006-07-09 00:00
       text  => 'B 115 Forster Str. OD Döbern grundhafter Straßenausbau Vollsperrung 18.05.2005-08.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 93524,-86350 93217,-85769
EOF
     },
     { from  => 1116280800, # 2005-05-17 00:00
       until => 1117663200, # 2005-06-02 00:00
       text  => 'K 6425; Zw. Neuenhagen und Altlandsberg Abriss Brücke ü. BAB Vollsperrung 18.05.2005-01.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 30768,15431 29743,14143
EOF
     },
     { from  => 1116367200, # 2005-05-18 00:00
       until => 1116885600, # 2005-05-24 00:00
       text  => 'L 30; (Friedrichstraße); OL Erkner, zw. Fürstenwalder Str. u. Beuststr. 13.Heimatfest Erkner Vollsperrung 19.05.2005-23.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34443,1951 34250,2546
EOF
     },
     { from  => 1117317600, # 2005-05-29 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'L 86; (Lehniner Str.); OD Damsdorf Kanal- und Straßenbau Vollsperrung 30.05.2005-30.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -32682,-7140 -32645,-6220
EOF
     },
     { from  => 1117576800, # 2005-06-01 00:00
       until => 1118959200, # 2005-06-17 00:00
       text  => 'K 6422; (Schöneicher Allee); Brücke A 10 zw. B 1 und Fredersdorf Brückenabbruch Vollsperrung 02.06.2005-16.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 33128,11823 32535,11591
EOF
     },
     { from  => 1116194400, # 2005-05-16 00:00
       until => Time::Local::timelocal(reverse(2005-1900,8-1,31,23,59,59)),
       text  => 'L 15; (Fürstenberg-Rheinsberg); OD Menz Kanal-,Straßen- u. Brückenbau Vollsperrung 17.05.2005-08.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -15062,76937 -14623,77426
EOF
     },
     { from  => 1116194400, # 2005-05-16 00:00
       until => Time::Local::timelocal(reverse(2005-1900,8-1,31,23,59,59)),
       text  => 'L 222; (Gransee-Menz); OD Menz Kanal-,Straßen- u. Brückenbau Vollsperrung 17.05.2005-08.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -15062,76937 -14862,76637
EOF
     },
     { from  => 1116885600, # 2005-05-24 00:00
       until => 1117490400, # 2005-05-31 00:00
       text  => 'L 35; (Eisenbahnstr.); OL Fürstenwalde, zw. Wassergasse und Frankfurter Str. Frühlingsfest Vollsperrung 25.05.2005-30.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 55393,-4240 55562,-4726
EOF
     },
     { from  => 1117080000, # 2005-05-26 06:00
       until => 1117490400, # 2005-05-31 00:00
       text  => 'Luxemburger Straße - Föhrer Straße, Zwischen Kreuzung Leopoldplatz und Kreuzung Amrumer Straße Veranstaltung, Straße gesperrt, Dauer: 27.05.2005 06:00 Uhr bis 30.05.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 7162,15436 7020,15314
userdel	q4 7162,15436 7288,15579
userdel	q4 6647,15094 6737,15133
userdel	q4 6737,15133 6846,15202 7020,15314
EOF
     },
     { from  => 1117231200, # 2005-05-28 00:00
       until => 1117490400, # 2005-05-31 00:00
       text  => 'K 6910; (Geltower Chausse); Bahnübergang im OT Caputh Gleisbauarbeiten Vollsperrung 29.05.2005-30.05.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -17811,-6820 -17811,-6691
EOF
     },
     { from  => 1117404000, # 2005-05-30 00:00
       until => 1117749600, # 2005-06-03 00:00
       text  => 'L 29; (Biesenthal-Wandlitz); Bahnübergang bei Wandlitz Gleisbauarbeiten Vollsperrung 31.05.2005-02.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15403,40364 14713,40426
EOF
     },
     { from  => 1117317600, # 2005-05-29 00:00
       until => 1126821600, # 2005-09-16 00:00
       text  => 'K 7330; (L 23 nördl. Templin-Gandenitz); OD Gandenitz Kanal- und Straßenbau Vollsperrung 30.05.2005-15.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 11401,84932 11423,85183
EOF
     },
     { from  => 1118091230, # 2005-06-06 22:53
       until => 1136069999, # 2005-12-31 23:59
       text  => 'Bouchéstraße (Treptow) in beiden Richtungen zwischen Kiefholzstraße und Am Treptower Park Fahrbahnerneuerung, Straße vollständig gesperrt (bis Ende 2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13867,9864 13601,9572
EOF
     },
     { from  => 1119391200, # 2005-06-22 00:00
       until => 1123365600, # 2005-08-07 00:00
       text  => 'B 246; zw. Christinendorf und Trebbin Anbind. neue Brücke Vollsperrung 23.06.2005-06.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 1691,-21721 1271,-21606
EOF
     },
     { from  => 1119736800, # 2005-06-26 00:00
       until => 1130709600, # 2005-10-30 23:00
       text  => 'K 6152; (Gussower Str.); OD Gräbendorf, ab B246 bis OA Kanal- und Straßenbau Vollsperrung 27.06.2005-30.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 31863,-18000 32922,-16523
EOF
     },
     { from  => 1119477600, # 2005-06-23 00:00
       until => 1120168800, # 2005-07-01 00:00
       text  => 'K 7234; (Goethestr.); Bahnübergang in Dabendorf Gleisbauarbeiten Vollsperrung 24.06.2005-30.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13048,-18384 13282,-18250
userdel	2 14153,-17829 13282,-18250
EOF
     },
     { from  => 1118527200, # 2005-06-12 00:00
       until => 1135378800, # 2005-12-24 00:00
       text  => 'L 216; (Gollin-Templin); OD Vietmannsdorf, Brücke über Mühlengraben Brückenneubau Vollsperrung 13.06.2005-23.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 17636,72217 17653,71852
EOF
     },
     { from  => 1118959200, # 2005-06-17 00:00
       until => 1119132000, # 2005-06-19 00:00
       text  => 'L 23; (Mühlenstr.); OD Templin, zw. Heinestr. und M.-Luther-Str. 16. Stadtfest Vollsperrung 18.06.2005-18.06.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 15448,79614 15840,79375
EOF
     },
     { from  => 1118527200, # 2005-06-12 00:00
       until => 1119650399, # 2005-06-24 23:59
       text  => 'Zimmerstraße Richtung Charlottenstraße zwischen Friedrichstraße und Charlottenstraße Kranarbeiten, gesperrt bis 24.06.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 9473,11316 9603,11328
EOF
     },
     { from  => 1119240000, # 2005-06-20 06:00
       until => 1119412800, # 2005-06-22 06:00
       text  => '"Bridge Partie", Modersohnbrücke von 21.06.2005, 06.00 Uhr bis 22.06.2005, 06:00 Uhr gesperrt ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 14026,10869 14043,10928 14081,11057 14102,11133 14139,11269
EOF
     },
     { from  => 1118949539, # 2005-06-16 21:18
       until => 1120068000, # 2005-06-29 20:00
       text  => 'Französische Str. ab Markgrafenstr., Werderscher Markt, Breite Str. gesperrt. Dauer: bis 29.06.2005, 20:00 Uhr. (Beachvolleyball) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9636,12126 9756,12139 9812,12145
userdel	2 10084,12228 9959,12180
userdel	2 9812,12145 9890,12161
userdel	2 9890,12161 9959,12180
userdel	2 10170,12261 10109,12238
userdel	2 10170,12261 10267,12305
EOF
     },
     { from  => 1118988173, # 2005-06-17 08:02
       until => 1119218400, # 2005-06-20 00:00
       text  => '300 Jahre Charlottenburg, 17.06.2005 bis 19.06.2005',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 3076,12192 3061,12300 3050,12394 3038,12482
userdel	2 3076,12192 3091,12071
userdel	2 3038,12482 2788,12447 2647,12427
userdel	2 3038,12482 3191,12502 3280,12512
userdel	2 3103,11968 3091,12071
userdel auto	3 3365,12231 3232,12210 3076,12192 2902,12165 2898,12197
userdel auto	3 2898,12197 2902,12165 3076,12192 3232,12210 3365,12231
EOF
     },
     { from  => 1120180333, # undef XXX 2005-07-07 00:00
       until => 1120180333, # undef XXX 2005-07-10 00:00
       text  => 'L 30; (Woltersdorfer Landstr.); OD Erkner Grundhafter Straßenbau Vollsperrung 08.07.2005-09.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34271,3184 34486,4276
EOF
     },
     { from  => 1118872800, # 2005-06-16 00:00
       until => 1119132000, # 2005-06-19 00:00
       text  => 'L 77; (Saarmund-Güterfelde); OD Philippsthal, zw. Kreisel u. OE Dreharbeiten Vollsperrung 17.06.2005-18.06.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -6319,-7823 -6659,-8210
EOF
     },
     { from  => 1118993118, # 2005-06-17 09:25
       until => 1119240000, # 2005-06-20 06:00
       text  => '"Köpenicker Sommer", im Bereich Altstadt Straßen gesperrt bis 20.06.2005, 06:00 Uhr (Schloßplatz, Grünstraße, Rosenstraße, Alt-Köpenick, Schüßlerplatz, Jägerstraße, Luisenhain, Schloßinsel) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22138,4661 22111,4562
userdel	2 22138,4661 22196,4847
userdel	2 22111,4562 22162,4546
userdel	2 22111,4562 22093,4499
userdel	2 22147,4831 22043,4562
userdel	2 22383,4703 22312,4593
userdel	2 22312,4593 22162,4546
userdel	2 22043,4562 22071,4501
EOF
     },
     { from  => 1119391200, # 2005-06-22 00:00
       until => 1123452000, # 2005-08-08 00:00
       text  => 'B 168; (Lieberose-Friedland); zw. Lieberose und Abzw. Mochlitz Straßenbauarbeiten Vollsperrung 23.06.2005-07.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 73201,-43677 72887,-44704
EOF
     },
     { from  => 1119132000, # 2005-06-19 00:00
       until => 1132959600, # 2005-11-26 00:00
       text  => 'L 53; (Seestr.); OL Großräschen, zw. B96 u. Ahornstr. Straßenbauarbeiten Vollsperrung 20.06.2005-25.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 53810,-90698 53805,-90240
userdel	q4 53252,-90440 53805,-90240
EOF
     },
     { from  => 1123365600, # 2005-08-07 00:00
       until => 1128376800, # 2005-10-04 00:00
       text  => 'L 17; (LG Berlin-Hennigsdorf); zw. Kreisverkehr und Hennigsdorf Straßenbau Vollsperrung 08.08.2005-03.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	2 -2800,25478 -2446,25386
EOF
     },
     { from  => 1119736800, # 2005-06-26 00:00
       until => 1121117530, # 1121119200 2005-07-12 00:00
       text  => 'L 26; (Löcknitz MVP-LG-Brüssow); zw. LG und Kno. Wollschow Deckeneinbau Vollsperrung 27.06.2005-11.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 61780,112606 61784,112969
EOF
     },
     { from  => 1119697095, # 2005-06-25 12:58
       until => 1136069999, # 2005-12-31 23:59
       text  => 'Dorotheenstr. Richtung Osten zwischen Wilhelmstr. und Schadowstr. sowie Schadowstr. Richtung Unter den Linden gesperrt (bis Ende 2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 8775,12457 8907,12472 9008,12485
userdel	q4; 9008,12485 9018,12400 9028,12307
EOF
     },
     { from  => 1119909600, # 2005-06-28 00:00
       until => 1125698400, # 2005-09-03 00:00
       text  => 'L 793; (Schönhagen-Ludwigsfelde); zw. Abzw. Gröben und Siethen Straßenbauarbeiten Vollsperrung 29.06.2005-02.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -2542,-13926 -3801,-14252
EOF
     },
     { from  => 1119909600, # 2005-06-28 00:00
       until => 1125698400, # 2005-09-03 00:00
       text  => 'L 793; (Schönhagen-Ludwigsfelde); zw. OD Jütchendorf und Abzw. Gröben Straßenbauarbeiten Vollsperrung 29.06.2005-02.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3694,-14508 -4077,-14595
userdel	2 -4504,-14978 -4077,-14595
EOF
     },
     { from  => 1120085920, # 2005-06-30 00:58
       until => 1120413600, # 2005-07-03 20:00
       text  => 'Straße des 17. Juni in beiden Richtungen zwischen Großer Stern und Entlastungsstr. Veranstaltung, Straße vollständig gesperrt (bis 03.07.2005 ca. 20 Uhr)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6828,12031 7383,12095
userdel	2 7383,12095 7816,12150
userdel	2 7816,12150 8063,12182
userdel auto	3 7663,11946 7460,12054 7383,12095 7039,12314
userdel auto	3 7039,12314 7383,12095 7460,12054 7663,11946
EOF
     },
     { from  => undef, # 
       until => 1148937435, # XXX zuletzt gesehen: 2006-03-19, laut http://archiv.tagesspiegel.de/archiv/29.05.2006/2555791.asp vorbei?
       text  => 'Rosa-Luxemburg-Str. Richtung Schönhauser Tor wegen Bauarbeiten gesperrt',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 10755,13152 10846,13362 10790,13565 10777,13614 10746,13673
EOF
     },
     { from  => 1114293600, # 2005-04-24 00:00
       until => 1125957600, # 2005-09-06 00:00
       text  => 'L 70; (Karl-Fiedler-Str.); OD Sperenberg, zw. Goethestr. u. Am Niederfließ Kompletter Straßenausbau Vollsperrung 25.04.2005-05.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
	q4 8576,-29378 8721,-29879
EOF
     },
     { from  => 1120088649, # 2005-06-30 01:44
       until => 1126796400, # 2005-09-15 17:00
       text  => 'Holzendorffstraße zwischen Rönnestraße und Gervinusstraße Brückenarbeiten, Straße gesperrt. Dauer: bis 15.09.2005, 17.00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 3049,10719 3093,10594
EOF
     },
     { from  => 1121378400, # 2005-07-15 00:00
       until => 1121637600, # 2005-07-18 00:00
       text  => 'Einfahrt in die Kastanienallee wegen Bauarbeiten gesperrt, 16.07.2005-17.07.2005',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 10889,15045 10723,14772
EOF
     },
     { from  => 1121732314, # 2005-07-19 02:18
       until => 1123452000, # 2005-08-08 00:00
       text  => 'Pappelallee (Prenzlauer Berg) in beiden Richtungen zwischen Raumerstr. und Schönhauser Allee Baustelle, Straße vollständig gesperrt (bis 07.08.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 11119,15385 10889,15045
EOF
     },
     { from  => 1120341600, # 2005-07-03 00:00
       until => 1123538400, # 2005-08-09 00:00
       text  => 'B 109; (Prenzlauer Str.); OD Basdorf, Kno. Dimitroff-/Waldheimstr. Straßen-,Geh- u.Radwegbau Vollsperrung 04.07.2005-08.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 12193,34683 12551,32765
EOF
     },
     { from  => 1122415200, # 2005-07-27 00:00
       until => 1123020000, # 2005-08-03 00:00
       text  => 'B 158; (Freienwalder Chaussee); OD Blumberg, zw. Kietz u. Elisenauer Ch. Deckenerneuerung Vollsperrung 28.07.2005-02.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 24735,22556 24951,22681
EOF
     },
     { from  => 1130018400, # 2005-10-23 00:00
       until => 1130277600, # 2005-10-26 00:00
       text  => 'L 23; OD Spreenhagen, Brücke über Oder-Spree-Kanal Sanierung Brücke Vollsperrung 24.10.2005-25.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 42349,-5620 42486,-5743 42769,-6313
EOF
     },
     { from  => 1120946400, # 2005-07-10 00:00
       until => 1123970400, # 2005-08-14 00:00
       text  => 'L 74; (Kastanienallee); OL Teupitz, Durchlass Ersatzneubau Vollsperrung 11.07.2005-13.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25240,-29746 25412,-29762
userdel	q4 25412,-29762 25541,-29875
EOF
     },
     { from  => 1151745684, # 2006-07-01 11:21
       until => 1151877600, # 2006-07-03 00:00
       text  => 'Pichelsdorfer Straße, zwischen Kreuzung Wilhelmstraße und Kreuzung Weißenburger Str. gesperrt bis 02.07.2006 (Sommerfest Wilhelmstadt) ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3650,12929 -3669,13015 -3764,13270 -3791,13357
userdel	2 -3650,12929 -3641,12861 -3629,12781
EOF
     },
     { from  => 1121032800, # 2005-07-11 00:00
       until => 1123106400, # 2005-08-04 00:00
       text  => 'B 96; OD Rangsdorf, Kno. Kienitzer Str. Straßenverbreiterung Vollsperrung 12.07.2005-03.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
	q4 14123,-11199 14327,-11767
EOF
     },
     { from  => 1120341600, # 2005-07-03 00:00
       until => 1128117600, # 2005-10-01 00:00
       text  => 'K 6301; (Bötzow-Wansdorf-Pausin); OD Wansdorf Kanal- und Straßenbau Vollsperrung 04.07.2005-30.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -11509,25591 -11337,25571
EOF
     },
     { from  => 1121117010, # 2005-07-11 23:23
       until => 1128117600, # 2005-10-01 00:00
       text  => 'Behrenstr. (Mitte) Richtung Gendarmenmarkt zwischen Glinkastr. und Charlottenstr. Baustelle, Fahrtrichtung gesperrt (bis 30.09.2005)',
       type  => 'handicap',
       source_id => 'IM_002045',
       data  => <<EOF,
userdel	q4; 9164,12172 9365,12196 9492,12214
EOF
     },
     { from  => 1121551200, # 2005-07-17 00:00
       until => 1122674400, # 2005-07-30 00:00
       text  => 'L 235; (Gielsdorf-Werneuchen); OD Wegendorf, Schulstr. Ersatzneubau Durchlass Vollsperrung 18.07.2005-29.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34492,22176 34321,22151
userdel	q4 34125,22128 34321,22151
EOF
     },
     { from  => 1122588000, # 2005-07-29 00:00
       until => 1122760800, # 2005-07-31 00:00
       text  => 'B 168; zw. Abzw. Mochlitz und LG in Ri. Friedland Straßenbauarbeiten Vollsperrung 30.07.2005-30.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 72781,-41234 71792,-39389
EOF
     },
     { from  => 1122501600, # 2005-07-28 00:00
       until => 1123365600, # 2005-08-07 00:00
       text  => 'B 87; zw. Hohenwalde und Müllrose Munitionsbergung Vollsperrung 29.07.2005-06.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 81786,-12568 81278,-13886
EOF
     },
     { from  => 1121896800, # 2005-07-21 00:00
       until => 1122588000, # 2005-07-29 00:00
       text  => 'K 7234; (Goethestr.); BÜ in Dabendorf, zw.Kastanienallee u. Brandenburger Str. Gleisbauarbeiten Vollsperrung 22.07.2005-28.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13048,-18384 13282,-18250
userdel	2 14153,-17829 13282,-18250
EOF
     },
     { from  => 1121205600, # 2005-07-13 00:00
       until => 1121464800, # 2005-07-16 00:00
       text  => 'L 382; (Gronenfelder Weg); zw. FFO, Birnbaumsmühle und Booßener Kreisel Gefahrenabwehr Vollsperrung 14.07.2005-15.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 85161,-3425 84653,-3159
EOF
     },
     { from  => 1121724000, # 2005-07-19 00:00
       until => 1128204000, # 2005-10-02 00:00
       text  => 'B 96; (Clara-Zetkin-Str.); OD Birkenwerder, zw. Weimarerstr. u. E.-Mühsam-Str. grundh. Straßenausbau Vollsperrung 20.07.2005-01.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 1772,31266 2257,31124
EOF
     },
     { from  => 1121724000, # 2005-07-19 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'K 7207; (KG südl. Rinow-Weißen); Brücke bei Rinow Brückenbauarbeiten Vollsperrung 20.07.2005-30.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2362,-64075 3737,-64262
EOF
     },
     { from  => 1121801694, # 2005-07-19 21:34
       until => 1123884000, # 2005-08-13 00:00
       text  => 'Hönower Str. (Mahlsdorf) in Richtung Alt-Mahlsdorf zwischen Wilhelmsmühlenweg und Alt-Mahlsdorf Baustelle, Fahrtrichtung gesperrt (bis 12.08.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 24623,11684 24591,11625 24603,11450 24658,11293
EOF
     },
     { from  => 1121724000, # 2005-07-19 00:00
       until => 1122156000, # 2005-07-24 00:00
       text  => 'B 112; (Kupferhammerstr.); Bahnübergang in OL Guben Gleisinstandhaltungsarb. Vollsperrung 20.07.2005-23.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 99825,-46697 99765,-46542 99702,-46376
EOF
     },
     { from  => 1152309600, # 2006-07-08 00:00
       until => 1152482400, # 2006-07-10 00:00
       text  => 'B 112 OL Guben, Bahnübergang OL Guben, Bahnübergang zw. OT Gr. Breesen u. Bresinchen Arbeiten Deutsche Bahn Vollsperrung 09.07.2006-09.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 99277,-43921 99228,-44346
EOF
     },
     { from  => 1121892756, # 2005-07-20 22:52
       until => 1123279200, # 2005-08-06 00:00
       text  => 'Rudower Str. (Treptow) Richtung stadteinwärts zwischen Köpenicker Str. und Wegedornstr. Baustelle, Fahrtrichtung gesperrt, Einbahnstraße in Richtung Köpenicker Str. (bis 05.08.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 19771,1793 19455,1870 19188,1980 18881,2062
EOF
     },
     { from  => 1122415200, # 2005-07-27 00:00
       until => 1123365600, # 2005-08-07 00:00
       text  => 'B 1; (Küstriner Str.); OD Seelow Deckenerneuerung Vollsperrung 28.07.2005-06.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 76771,15413 77393,15654
EOF
     },
     { from  => 1123884000, # 2005-08-13 00:00
       until => 1124229600, # 2005-08-17 00:00
       text  => 'B 169; (Elsterwerdaer Str.); Bahnübergang zw. B101 und OE Prösen Reparaturarbeiten Vollsperrung 14.08.2005-16.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 19076,-108365 19683,-108408
EOF
     },
     { from  => 1122058524, # 2005-07-22 20:55
       until => 1122238800, # 2005-07-24 23:00
       text  => 'Eisenacher Str. (Schöneberg) in beiden Richtungen, zwischen Grunwaldstr. und Hauptstr. Veranstaltung, Straße vollständig gesperrt (bis 24.07.2005 23:00 Uhr)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6735,9103 6769,8996
userdel	2 6735,9103 6711,9225
userdel	2 7009,8705 6860,8878
userdel	2 6769,8996 6860,8878
EOF
     },
     { from  => 1122156000, # 2005-07-24 00:00
       until => 1122588000, # 2005-07-29 00:00
       text  => 'L 15; (Rosa-Luxemburg-Str.); OD Wittstock Straßenbauarbeiten Vollsperrung 25.07.2005-28.07.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -53868,82504 -53648,82294
EOF
     },
     { from  => 1122242400, # 2005-07-25 00:00
       until => 1122674400, # 2005-07-30 00:00
       text  => 'K 6509; (Liebenberg-B 96 Teschendorf); zw. Grüneberg und B 96 grundh. Straßenbau Vollsperrung 26.07.2005-29.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -6201,51305 -5813,51200
userdel	2 -5813,51200 -3395,51242
EOF
     },
     { from  => 1123106400, # 2005-08-04 00:00
       until => 1123452000, # 2005-08-08 00:00
       text  => 'B 169; von OD Kahla bis OE Elsterwerda Deckschichteinbau Vollsperrung 05.08.2005-07.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 23758,-103850 22424,-103934
EOF
     },
     { from  => 1122501600, # 2005-07-28 00:00
       until => 1122847200, # 2005-08-01 00:00
       text  => 'B 169; zw. Plessa und Kahla Deckschichteinbau Vollsperrung 29.07.2005-31.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 24971,-104007 26625,-104401
EOF
     },
     { from  => 1122501600, # 2005-07-28 00:00
       until => 1122674400, # 2005-07-30 00:00
       text  => 'L 338; (Neuenhagener Chaussee); Zuf. Flora-Gelände bei Schöneiche Umbau Knotenpunkt Vollsperrung 29.07.2005-29.07.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 30455,10061 30500,10571
EOF
     },
     { from  => 1125180000, # 2005-08-28 00:00
       until => 1125439200, # 2005-08-31 00:00
       text  => 'B 112; (OU Neuzelle-OU Guben); Ber. Steinsdorf Vorwerk Bau Oder-Lausitz-Trasse Vollsperrung 29.08.2005-30.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 98777,-43381 98337,-41604
EOF
     },
     { from  => 1123103274, # 2005-08-03 23:07
       until => 1125525600, # 2005-09-01 00:00
       text  => 'B96, Ortsdurchfahrt Altlüdersdorf gesperrt bis 31.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -5146,69565 -5209,70040
userdel	q4 -5209,70040 -4978,71109
EOF
     },
     { from  => 1122933600, # 2005-08-02 00:00
       until => 1128117600, # 2005-10-01 00:00
       text  => 'K 6718; von OL Schernsdorf u. Kupferhammer in 3 Abschn. Straßenbauarbeiten Vollsperrung 03.08.2005-30.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 83059,-23016 81501,-23378
EOF
     },
     { from  => 1123365600, # 2005-08-07 00:00
       until => 1134774000, # 2005-12-17 00:00
       text  => 'K 6917; (B246 Borkheide-Kanin); OD Borkwalde Straßenbauarbeiten Vollsperrung 08.08.2005-16.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -26809,-18383 -27757,-17707
EOF
     },
     { from  => 1124748000, # 2005-08-23 00:00
       until => 1126389600, # 2005-09-11 00:00
       text  => 'L 793; (Alfred-Kühne-Str.); OD Ludwigsfelde, am OA in Ri. A 10 Einbau Anschlussgleis Vollsperrung 24.08.2005-10.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2996,-10338 1764,-12480
EOF
     },
     { from  => 1149119975, # 2006-06-01 01:59
       until => 1159653599, # 2006-09-30 23:59
       text  => 'Swinemünder Brücke: Baustelle Straße für Autos vollständig gesperrt, Radfahrer und Fußgänger können passieren (bis Ende 09.2006) ',
       type  => 'handicap',
       source_id => 'IM_002360',
       data  => <<EOF,
userdel	q2 9494,15998 9583,15851
EOF
     },
     { from  => 1124137069, # 2005-08-15 22:17
       until => 1126303200, # 2005-09-10 00:00
       text  => 'Lauenburger Str. (Steglitz) in beiden Richtungen zwischen Lothar-Bucher-Str. und Lauenburger Platz Baustelle, Straße vollständig gesperrt (bis 09.09.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6030,6165 6024,6080
EOF
     },
     { from  => 1123970400, # 2005-08-14 00:00
       until => 1128117600, # 2005-10-01 00:00
       text  => 'B 179; (Spreewaldstr.); OD Zeesen, Kno. Karl-Liebknecht-Str. Straßenausbau Vollsperrung 15.08.2005-30.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26583,-15677 26612,-15094
EOF
     },
     { from  => 1122760800, # 2005-07-31 00:00
       until => 1124307438, # vorzeitig beendet 1125525600 2005-09-01 00:00
       text  => 'B 96; (Gransee-Fürstenberg); zw. Gransee und Altlüdersdorf grundh. Ausbau Vollsperrung 01.08.2005-31.08.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -5575,69050 -5703,68140
EOF
     },
     { from  => 1128290400, # 2005-10-03 00:00
       until => 1129413600, # 2005-10-16 00:00
       text  => 'L 171; (Hohen Neuendorf-Hennigsdorf); zw. Kreisverkehr bei Hennigsd. und AS Stolpe Straßenbau Vollsperrung 04.10.2005-15.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -2446,25386 -2118,26060
EOF
     },
     { from  => 1124486293, # 2005-08-19 23:18
       until => 1124679600, # 2005-08-22 05:00
       text  => 'Kurfürstendamm / Tauentzienstr. in beiden Richtungen zwischen Passauer Str. und Uhlandstr. Veranstaltung, Straße vollständig gesperrt, einschließlich der Seitenstraßen (bis 22.08.2005 05:00 Uhr)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 5229,10716 5351,10760
userdel	2 5229,10716 5076,10658
userdel	2 5657,10868 5484,10810
userdel	2 5657,10868 5725,10892
userdel	2 5725,10892 5797,10881
userdel	2 5942,10803 6040,10751
userdel	2 5942,10803 5797,10881
userdel	2 6040,10751 6137,10689
userdel	2 5484,10810 5351,10760
userdel auto	3 5831,10978 5797,10881 5681,10696
userdel auto	3 5247,10992 5242,10918 5229,10716 5207,10399
userdel auto	3 5207,10399 5229,10716 5242,10918 5247,10992
userdel auto	3 5479,10719 5484,10810 5505,10971
userdel auto	3 5877,10486 6040,10751 6135,10982
userdel auto	3 5505,10971 5484,10810 5479,10719
userdel auto	3 5681,10696 5797,10881 5831,10978
userdel auto	3 6135,10982 6040,10751 5877,10486
EOF
     },
     { from  => 1124575200, # 2005-08-21 00:00
       until => 1146261599, # 28.04.2006, was: 1139094000 2006-02-05 00:00
       text  => 'B 101; (Herzberg-Jüterbog); Brücke über Kremnitzbach u. über Rad-u.Gehweg bei Bernsdorf Brückenbau Vollsperrung 22.08.2005-28.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -1307,-73252 -1245,-72696
EOF
     },
     { from  => 1124486820, # 2005-08-19 23:27
       until => 1125698400, # 2005-09-03 00:00
       text  => 'Luckauer Str. (Kreuzberg) in beiden Richtungen zwischen Oranienstr. und Waldemarstr. Baustelle, Straße vollständig gesperrt (bis02.09.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 11145,11042 11105,10945
userdel	2 11105,10945 11039,10820
EOF
     },
     { from  => 1124742735, # 2005-08-22 22:32
       until => 1127512800, # 2005-09-24 00:00
       text  => 'Buschallee (Weißensee) in Richtung Berliner Allee zwischen Elsastr. und Hansastr. Baustelle, Fahrtrichtung gesperrt (bis 23.09.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 15918,16383 15871,16399 15432,16500
EOF
     },
     { from  => 1124575200, # 2005-08-21 00:00
       until => 1125871200, # 2005-09-05 00:00
       text  => 'K 7237; (L 40 Klein Kienitz-Rangsdorf); zw. Südringcenter Rangsdorf u. Klein Kienitz Straßenbauarbeiten Vollsperrung 22.08.2005-04.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26583,-15677 26612,-15094
userdel	2 14327,-11767 15962,-10958
EOF
     },
     { from  => 1125612000, # 2005-09-02 00:00
       until => 1125784800, # 2005-09-04 00:00
       text  => 'B 167; (Frankfurter Str.); OD Seelow, zw. Breite Str. u. Berliner Str. Stadtfest Vollsperrung 03.09.2005-03.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 76771,15413 77081,14637
EOF
     },
     { from  => 1125698400, # 2005-09-03 00:00
       until => 1126044000, # 2005-09-07 00:00
       text  => 'K 6422; (Eggersdorfer Str.); OL Petershagen, unbeschrankter Bahnübergang Instandsetzungsarb. Vollsperrung 04.09.2005-06.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 35900,13643 36716,13979
EOF
     },
     { from  => 1124920800, # 2005-08-25 00:00
       until => 1125093600, # 2005-08-27 00:00
       text  => 'K 6907; zw. Ferch und L 90 Glindow Dreharbeiten Vollsperrung 26.08.2005-26.08.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -22803,-9880 -23295,-9711
EOF
     },
     { from  => 1125350749, # 2005-08-29 23:25
       until => 1129413600, # 2005-10-16 00:00
       text  => 'Glienicker Straße zwischen Grünauer Straße und Nipkowstraße Richtung Adlergestell wegen Bauarbeiten gesperrt bis 15.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 21823,4210 21690,4057 21498,3837 21442,3774 21316,3662 21227,3549 21198,3522 21136,3482 20967,3343 20818,3182
EOF
     },
     { from  => 1125351382, # 2005-08-29 23:36
       until => 1125698400, # 2005-09-03 00:00
       text  => 'Fähre Cauth K 6910 Straße der Einheit bis 02.09.2005 außer Betrieb ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -17728,-6975 -17643,-7028
EOF
     },
     { from  => 1125460800, # 2005-08-31 06:00
       until => 1125864000, # 2005-09-04 22:00
       text  => 'Weitlingstraße zwischen Sophienstraße und Frankfurter Allee in beiden Richtungen gesperrt, Veranstaltung, Dauer: 01.09.2005. 06.00 Uhr bis 04.09.2005, 22.00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 16653,11251 16723,11470 16786,11668
userdel	q4 16958,11778 16821,11743
userdel	q4 16821,11743 16786,11668
EOF
     },
     { from  => 1139555958, # 2006-02-10 08:19
       until => 1191189600, # 2007-10-01 00:00
       text  => 'Florastr. (Pankow) Berliner Str. in Richtung Mühlenstr. Baustelle, Fahrtrichtung gesperrt (bis September 2007)',
       type  => 'handicap',
       source_id => 'IM_002176',
       data  => <<EOF,
userdel	q4; 10459,17754 10722,17940 10846,17992
EOF
     },
     { from  => 1127508095, # 2005-09-23 22:41
       until => 1136069999, # 2005-12-31 23:59
       text  => 'Wegedornstraße (Adlershof) Richtung Rudow, zwischen Rudower Chaussee und Ernst-Ruska-Ufer Baustelle, Fahrtrichtung gesperrt (bis Ende 2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 18929,2454 18925,2700
EOF
     },
     { from  => 1125957600, # 2005-09-06 00:00
       until => 1131750000, # 2005-11-12 00:00
       text  => 'B 102; zw. Kampehl und B 5, Bückwitz Bau Kreisverkehrsplatz Vollsperrung 07.09.2005-11.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -53139,50022 -54295,49682
EOF
     },
     { from  => 1126648800, # 2005-09-14 00:00
       until => 1134601627, # aufgehoben, was 1204326000 2008-03-01 00:00
       text  => 'B 103; (Kyritzer Chaussee); OD Pritzwalk, zw. Fritz-Reuter-Str. u. Havelberger Str. Bau OU B189n halbseitig gesperrt; Einbahnstraße 15.09.2005-29.02.2008 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -74489,80545 -74038,78181
EOF
     },
     { from  => 1127772000, # 2005-09-27 00:00
       until => 1128031200, # 2005-09-30 00:00
       text  => 'B 112; (Beeskower Str.); OD Eisenhüttenstadt Asphaltarbeiten halbseitig gesperrt; Einbahnstraße 28.09.2005-29.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 94350,-26678 94796,-26727
EOF
     },
     { from  => 1128290400, # 2005-10-03 00:00
       until => 1129413600, # 2005-10-16 00:00
       text  => 'B 112; (Guben-Eisenhüttenstadt); OD Neuzelle Deckenerneurung Vollsperrung 04.10.2005-15.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 96492,-34347 95945,-34062
EOF
     },
     { from  => 1132873200, # 2005-11-25 00:00
       until => 1135292400, # 2005-12-23 00:00
       text  => 'B 166 Zichow-Gramzow OD Gramzow Kanal- und Straßenbau Vollsperrung 26.11.2005-22.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 50109,89725 49930,89857
EOF
     },
     { from  => 1126994400, # 2005-09-18 00:00
       until => 1130191200, # 2005-10-25 00:00
       text  => 'B 179; (Karl-Liebknecht-Str.); OD Zeesen, zw. Spreewaldstr. u. Weidendamm Straßenausbau Vollsperrung 19.09.2005-24.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26473,-14543 26612,-15094
EOF
     },
     { from  => 1126994400, # 2005-09-18 00:00
       until => 1128722400, # 2005-10-08 00:00
       text  => 'B 188; westl. Rathenow, zw. Kreisel u. Abzw. Großwudicke Straßenanbindung B188n Vollsperrung 19.09.2005-07.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -67681,19301 -67871,19214
EOF
     },
     { from  => 1126648800, # 2005-09-14 00:00
       until => 1142463600, # 2006-03-16 00:00
       text  => 'B 198 Günterberg-Gramzow bei Schmiedeberg, Brücke über Mühlengraben Brückenersatzneubau Vollsperrung 15.09.2005-15.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 46677,82770 47081,83093
userdel	2 47081,83093 47137,83456
EOF
     },
     { from  => 1128808800, # 2005-10-09 00:00
       until => 1130623200, # 2005-10-30 00:00
       text  => 'B 198; zw. Prenzlau und Bietikow grundh.Straßenbau Vollsperrung 10.10.2005-29.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 42775,98487 43126,98186
EOF
     },
     { from  => 1122156000, # 2005-07-24 00:00
       until => 1127599200, # 2005-09-25 00:00
       text  => 'B 273; (Potsdamer Str.); OD Bornim, zw. Amundsenstr. u. Lindstedter Weg Kanalarbeiten halbseitig gesperrt; Einbahnstraße 25.07.2005-24.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -15527,795 -15557,809 -16640,1304
EOF
     },
     { from  => 1126994400, # 2005-09-18 00:00
       until => 1128204000, # 2005-10-02 00:00
       text  => 'B 87; OD Mittweide Straßenbauarbeiten Vollsperrung 19.09.2005-01.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 60430,-38587 62112,-36752
EOF
     },
     { from  => 1130364000, # 2005-10-27 00:00
       until => 1130886000, # 2005-11-02 00:00
       text  => 'B 96; (Neuhof-Wünsdorf); Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung 28.10.2005-01.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
EOF
     },
     { from  => 1126389600, # 2005-09-11 00:00
       until => 1136070000, # 2006-01-01 00:00
       text  => 'K 6424; (Dahlwitzer Landstr.-Münchehofe-B 1); OD Münchehofe Straßenausbau Vollsperrung 12.09.2005-31.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 28605,9637 26851,9005
EOF
     },
     { from  => 1127772000, # 2005-09-27 00:00
       until => 1128031200, # 2005-09-30 00:00
       text  => 'K 7226; zw. Neuhof und Sperenberg Straßenbauarbeiten Vollsperrung 28.09.2005-29.09.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12690,-30392 14671,-30092
EOF
     },
     { from  => 1125525600, # 2005-09-01 00:00
       until => 1130799600, # 2005-11-01 00:00
       text  => 'L 19; (Zechlinerhütte-Wesenberg (MVP)); zw. Abzw. Klein Zerlang u. LG (nö. Prebelowbrücke) Ersatzneubau Brücke Prebelow Vollsperrung 02.09.2005-31.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -26403,85177 -26316,84900
EOF
     },
     { from  => 1126562400, # 2005-09-13 00:00
       until => 1128117600, # 2005-10-01 00:00
       text  => 'L 201; (Nauener Chaussee); OD Falkensee, zw. F.-Ludwig-Jahn-Str. u. Innstr. Straßenbauarbeiten halbseitig gesperrt; Einbahnstraße 14.09.2005-30.09.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -12601,19517 -12074,19052
EOF
     },
     { from  => 1126994400, # 2005-09-18 00:00
       until => 1134687600, # 2005-12-16 00:00
       text  => 'L 22; (Oranienburger Str.); OD Gransee grundh. Straßenbau Vollsperrung 19.09.2005-15.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -7696,66033 -7851,66418
userdel	q4 -7873,66589 -7851,66418
EOF
     },
     { from  => 1128290400, # 2005-10-03 00:00
       until => 1129932000, # 2005-10-22 00:00
       text  => 'L 39; (Kolberg-Friedersdorf); OD Blossin, Haupstr. Straßenbauarbeiten Vollsperrung 04.10.2005-21.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 37885,-16100 37888,-15635
EOF
     },
     { from  => 1129068000, # 2005-10-12 00:00
       until => 1129240800, # 2005-10-14 00:00
       text  => 'L 513; (Ringchaussee); Krz. Burg Kolonie/ Naundorf Deckenerneuerung Vollsperrung 13.10.2005-13.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 59792,-61720 60404,-61710
EOF
     },
     { from  => 1129240800, # 2005-10-14 00:00
       until => 1129413600, # 2005-10-16 00:00
       text  => 'L 541; (Suschow-Burg Kolonie); Krz. Burg Kolonie/ Naundorf Deckenerneuerung Vollsperrung 15.10.2005-15.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 59792,-61720 60404,-61710
EOF
     },
     { from  => 1125871200, # 2005-09-05 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'L 75; (Karl-Marx-Str.); OD Großziethen Straßenbauarbeiten Vollsperrung 06.09.2005-30.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 13225,-681 13090,205 12984,1011
EOF
     },
     { from  => 1128290400, # 2005-10-03 00:00
       until => 1132095600, # 2005-11-16 00:00
       text  => 'B 112; zw. Abzw. Ziltendorf und Abzw. Pohlitz Deckenerneurung Vollsperrung 04.10.2005-15.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 93494,-21221 93192,-21578
EOF
     },
     { from  => 1127772000, # 2005-09-27 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'L 382; (Birnbaumsmühle); OD Frankfurt (O), Bereich unter den Brücken DB grundh. Straßenbau Vollsperrung 28.09.2005-30.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 85403,-4497 85666,-3989
EOF
     },
     { from  => 1128117600, # 2005-10-01 00:00
       until => 1128398400, # 2005-10-04 06:00
       text  => 'Ebertstraße, Pariser Platz: Veranstaltung, Straße gesperrt bis Di 06:00 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8581,11896 8595,12066
userdel	2 8581,11896 8571,11846
userdel	2 8595,12066 8600,12165
userdel	2 8539,12286 8515,12242
userdel	2 8539,12286 8560,12326
userdel	2 8540,12420 8560,12326
userdel	2 8600,12165 8515,12242
userdel	2 8515,12242 8610,12254
EOF
     },
     { from  => 1128808800, # 2005-10-09 00:00
       until => 1131404400, # 2005-11-08 00:00
       text  => 'B 87; (Beeskow-Lübben); zw. Abzw. Wittmannsdorf und Abzw. Dollgen Straßenbauarbeiten Vollsperrung 10.10.2005-07.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 58111,-41188 60430,-38587
EOF
     },
     { from  => 1128290400, # 2005-10-03 00:00
       until => 1128981600, # 2005-10-11 00:00
       text  => 'B 87; (Beeskow-Lübben); zw. Trebatsch und Abzw. Wittmannsdorf Straßenbauarbeiten Vollsperrung 04.10.2005-10.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 62112,-36752 60430,-38587
EOF
     },
     { from  => 1128808800, # 2005-10-09 00:00
       until => 1131836400, # 2005-11-13 00:00
       text  => 'B 198; OD Prenzlau, Dr.-Wilhelm-Külz-Str. grundh. Straßenbau Vollsperrung 10.10.2005-12.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 39715,101866 39574,101863 39322,101924
EOF
     },
     { from  => 1128376800, # 2005-10-04 00:00
       until => 1128722400, # 2005-10-08 00:00
       text  => 'B 273; zw. Kremmen und Schwante Straßenbauarbeiten Vollsperrung 05.10.2005-07.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -14038,37008 -12791,36632
EOF
     },
     { from  => 1128549600, # 2005-10-06 00:00
       until => 1128895200, # 2005-10-10 00:00
       text  => 'B 87; zw. Schlieben und Kolochau Deckeneinbau Vollsperrung 07.10.2005-09.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 7711,-74770 8300,-74790
EOF
     },
     { from  => 1120341600, # 2005-07-03 00:00
       until => 1130018400, # 2005-10-23 00:00
       text  => 'K 6301; (Bötzow-Wansdorf-Pausin); OD Wansdorf Kanal- und Straßenbau Vollsperrung 04.07.2005-22.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -11337,25571 -11509,25591
EOF
     },
     { from  => 1126562400, # 2005-09-13 00:00
       until => 1130709600, # 2005-10-30 23:00
       text  => 'L 201; (Nauener Chaussee); OD Falkensee, zw. F.-Ludwig-Jahn-Str. u. Innstr. Straßenbauarbeiten halbseitig gesperrt; Einbahnstraße 14.09.2005-30.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -12601,19517 -12074,19052
EOF
     },
     { from  => 1128549600, # 2005-10-06 00:00
       until => 1128808800, # 2005-10-09 00:00
       text  => 'L 96; (B 1 Neubensdorf-Rathenow); zw. Milow und Bützer Straßenbauarbeiten Vollsperrung 07.10.2005-08.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -64341,12416 -64162,11951
EOF
     },
     { from  => 1128808800, # 2005-10-09 00:00
       until => 1129500000, # 2005-10-17 00:00
       text  => 'B 2; (Bernau-Biesenthal); B 2, OD Rüdnitz, Kreisverkehr grundh. Ausbau, Bau Kreisverk. Vollsperrung 10.10.2005-16.10.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25095,35601 24915,35340
EOF
     },
     { from  => 1128988800, # 2005-10-11 02:00
       until => 1129298400, # 2005-10-14 16:00
       text  => 'Drakestraße zwischen Hans-Sachs-Straße und Knesebeckstraße in beiden Richtungen Brückenabriss, Straße gesperrt, Dauer: 12.10.2005 02:00 Uhr bis 14.10.2005 16:00 Uhr',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 3259,4002 3128,4190
EOF
     },
     { from  => 1128808800, # 2005-10-09 00:00
       until => 1134774000, # 2005-12-17 00:00
       text  => 'K 7228; (Zossener Allee); OL Sperenberg Straßenbau Vollsperrung 10.10.2005-16.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8576,-29378 8725,-26812
EOF
     },
     { from  => 1128754834, # 2005-10-08 09:00 (by polizeifax und Tagesspiegel)
       until => 1130104800, # 2005-10-24 00:00
       text  => 'Ehrlichstr. (Lichtenberg) zwischen Wildensteiner Str. und Treskowallee Baustelle, gesperrt (bis 23.10.2005)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 18147,8583 18225,8532 18467,8375 18615,8269 18683,8232
EOF
     },
     { from  => undef, # 
       until => 1128891600, # 2005-10-09 23:00
       text  => 'Hermannstraße zwischen Flughafenstraße und Thomasstraße Veranstaltung, Straße gesperrt bis So 23:00 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12090,7651 12075,7696
userdel	2 12090,7651 12122,7553
userdel	2 12180,7387 12122,7553
userdel	2 11920,8252 11933,8198
userdel	2 11920,8252 11892,8372
userdel	2 12041,7788 12055,7751
userdel	2 12041,7788 12025,7852
userdel	2 11998,7948 12025,7852
userdel	2 11998,7948 11979,8014
userdel	2 11979,8014 11960,8090
userdel	2 11933,8198 11960,8090
userdel	2 12055,7751 12075,7696
EOF
     },
     { from  => 1128985496, # 2005-10-11 01:04
       until => 1130104800, # 2005-10-24 00:00
       text  => 'Josef-Orlopp-Str. (Lichtenberg) in Richtung Storkower Str. zwischen Siegfriedstr. und Vulkanstr. Fahrbahnerneuerung, Fahrtrichtung gesperrt (bis 23.10.2005)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 16863,13138 15912,13153
EOF
     },
     { from  => 1128899379, # 2005-10-10 01:09 (by Tagesspiegel)
       until => 1131667773, # 2005-11-11 01:09
       text  => 'Prenzlauer Berg: Richtung Prenzlauer Allee gesperrt (Kopfsteinpflaster wird durch Asphalt ersetzt)',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 11723,13630 11538,13683 11257,13647
EOF
     },
     { from  => undef, # 
       until => 1129413599, # 2005-10-15 23:59
       text  => 'Mahlsdorfer Str. (Köpenick) Richtung Köpenick, zwischen Hultischiner Damm und Genovevastr. Baustelle, Fahrtrichtung gesperrt (bis 15.10.)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 23799,7877 23774,7803 23701,7772 23190,7484 23066,7355
EOF
     },
     { from  => 1129327200, # 2005-10-15 00:00
       until => 1129759200, # 2005-10-20 00:00
       text  => 'L 15; (B109-Boitzenburg); zw. Abzw. Klein Sperrenwalde u. OL Gollmitz, Prenzlauer Str. Straßenbauarbeiten Vollsperrung 16.10.2005-19.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 31882,98397 30743,99403
EOF
     },
     { from  => 1128981600, # 2005-10-11 00:00
       until => 1129413600, # 2005-10-16 00:00
       text  => 'L 165; (Manker-Garz); bei Garz, Bereich Brücke über Temnitz Asphaltsanierung Vollsperrung 12.10.2005-15.10.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -43343,47590 -42999,47684
EOF
     },
     { from  => 1129413600, # 2005-10-16 00:00
       until => 1131145200, # 2005-11-05 00:00
       text  => 'L 70; (Sperenberg-Trebbin); zw. Abzw.Chrisinend. u. Abzw.Kl.Schulzend.Ber.Brücke B101n Straßen- und Brückenbau Vollsperrung 17.10.2005-04.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 1740,-23380 1079,-23181
EOF
     },
     { from  => 1128967200, # 2005-10-10 20:00
       until => 1143227474, # 1143756000 2006-03-31 00:00
       text  => 'Rosenthaler Straße zwischen Hackescher Markt und Neue Schönhauser Straße Baustelle, als Einbahnstraße eingerichtet in Richtung Rosenthaler Platz, Dauer: 11.10.2005, 20.00 Uhr bis 30.03.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 10305,13211 10264,13097
EOF
     },
     { from  => 1119996000, # 2005-06-29 00:00
       until => 1133391600, # 2005-12-01 00:00
       text  => 'L 401; (Lindenallee); OD Zeuthen, zw. OE und An der Eisenbahn grundhafter Straßenbau Vollsperrung 30.06.2005-30.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26790,-7918 26700,-7334 26581,-7087
EOF
     },
     { from  => undef, # 
       until => 1293836399, # 2010-12-31 23:59
       text  => 'Universitätsstr., Richtung Dorotheenstr. gesperrt (bis 2010) ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 9603,12372 9574,12578
EOF
     },
     { from  => undef, # 
       until => 1293836399, # 2010-12-31 23:59
       text  => 'Universitätsstr., Richtung Dorotheenstr. gesperrt (bis 2010)',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 9562,12679 9574,12578
EOF
     },
     { from  => 1129413600, # 2005-10-16 00:00
       until => 1132959600, # 2005-11-26 00:00
       text  => 'B 109; (Zehdenick-Templin); zw. Hammelspring und Hindenburg Straßen-, Durchlass- u.Radweg. Vollsperrung 17.10.2005-25.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12311,76014 11771,74993
EOF
     },
     { from  => 1129705762, # 2005-10-19 09:09
       until => 1130191200, # 2005-10-25 00:00
       text  => 'Zeltinger Str. Richtung Oranienburger Chaussee zwischen Zernsdorfer Weg und Zeltinger Platz Straßenarbeiten, Fahrtrichtung gesperrt (bis 24.10.2005)',
       type  => 'gesperrt',
       source_id => 'IM_002297',
       data  => <<EOF,
userdel	1 2461,25270 2657,25486 2721,25576
EOF
     },
     { from  => 1129879314, # 2005-10-21 09:21
       until => 1130623200, # 2005-10-30 00:00
       text  => 'Scheidemannstr. Richtung Ebertstr. von Entlastungsstr. bis Ebertstr. Veranstaltung, Fahrtrichtung gesperrt (bis 29.10.2005)',
       type  => 'handicap',
       source_id => 'IM_002305',
       data  => <<EOF,
userdel	q4 8119,12414 8374,12416
userdel	q4 8400,12417 8540,12420
userdel	q4 8400,12417 8374,12416
EOF
     },
     { from  => 1129878000, # 2005-10-21 09:00
       until => 1129996800, # 2005-10-22 18:00
       text  => 'Stadtgebiet Potsdam: auf Grund einer Bombenentschärfung sind folgende Strassen innerhalb folgender Begrenzung gesperrt: Am Kanal -- Kurfürstenstr. -- Berliner Strasse -- Friedrich-Ebert-Str., Dauer: 22.10.2005 09:00 Uhr bis 18:00 Uhr, ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -12306,-496 -12262,-612
userdel	2 -12523,-839 -12575,-1031
userdel	2 -12523,-839 -12190,-775
userdel	2 -12523,-839 -12685,-870
userdel	2 -12063,-784 -12148,-934
userdel	2 -12148,-934 -12231,-1078
userdel	2 -12148,-934 -12100,-962
userdel	2 -11910,-945 -12100,-962
userdel	2 -12296,-1190 -12231,-1078
userdel	2 -12296,-1190 -12362,-1122 -12488,-999
userdel	2 -12488,-999 -12553,-1025
userdel	2 -12262,-612 -12190,-775
userdel	2 -12262,-612 -12545,-698
userdel	2 -12575,-1031 -12768,-1069
userdel	2 -12575,-1031 -12553,-1025
userdel	2 -12553,-1025 -12552,-1233 -12549,-1277
userdel	2 -12078,-1068 -12070,-1153
userdel	2 -12078,-1068 -12020,-1062
userdel	2 -12078,-1068 -12231,-1078
userdel	2 -12078,-1068 -12100,-962
userdel	2 -12768,-1069 -12784,-956
userdel	2 -12571,-581 -12545,-698
userdel	2 -12190,-775 -12148,-784
userdel	2 -12784,-956 -12797,-893
userdel	2 -12545,-698 -12712,-734
userdel	2 -12685,-870 -12797,-893
userdel	2 -12712,-734 -12884,-769
userdel	2 -12730,-627 -12712,-734
userdel	2 -12797,-893 -12895,-913
userdel	2 -12718,-1327 -12755,-1131 -12768,-1069
EOF
     },
     { from  => 1130277600, # 2005-10-26 00:00
       until => 1130972400, # 2005-11-03 00:00
       text  => 'B 112; (Karl-Marx-Str.); OD Eisenhüttenstadt Deckenerneuerung Vollsperrung 27.10.2005-02.11.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 94863,-27943 94983,-28457
EOF
     },
     { from  => 1130277600, # 2005-10-26 00:00
       until => 1130972400, # 2005-11-03 00:00
       text  => 'B 112; zw. Lawitz und Eisenhüttenstadt Deckenerneuerung Vollsperrung 27.10.2005-02.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 95829,-31753 95494,-29935
EOF
     },
     { from  => 1130536800, # 2005-10-29 00:00
       until => 1130972400, # 2005-11-03 00:00
       text  => 'B 246; (Bauptstr.); Bahnübergang in OL Bestensee Gleisbauarbeiten Vollsperrung 30.10.2005-02.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26639,-17861 26752,-17872
userdel	2 26832,-17882 26752,-17872
EOF
     },
     { from  => 1130277600, # 2005-10-26 00:00
       until => 1134774000, # 2005-12-17 00:00
       text  => 'L 15; (B109 südl. Prenzlau-Boitzenburg); OD Gollmitz Leitungsverlegung Vollsperrung 27.10.2005-16.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 30743,99403 30504,99595
EOF
     },
     { from  => 1130450400, # 2005-10-28 00:00
       until => 1130972400, # 2005-11-03 00:00
       text  => 'L 402; (Forstweg); Bahnübergang in OL Zeuthen Gleisbauarbeiten Vollsperrung 29.10.2005-02.11.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26001,-6257 26146,-6218
EOF
     },
     { from  => 1130715720, # 2005-10-31 00:42
       until => 1132354800, # 2005-11-19 00:00
       text  => 'Naumannstraße zwischen Torgauer Str. und Kolonnenstraße in Richtung Kolonnenstraße wegen Bauarbeiten gesperrt bis 18.11.2005 ',
       type  => 'handicap',
       source_id => 'LMS_1129024102795',
       data  => <<EOF,
userdel	q4; 7713,8600 7709,8770
userdel	q4; 7716,8048 7716,8356 7712,8560
EOF
     },
     { from  => 1130792769, # 2005-10-31 22:06
       until => 1131231600, # 2005-11-06 00:00
       text  => 'Brückensperrung zwischen Seehausen und Potzlow Die Brücke ist ab dem 5.9.2005 bis zum 5.11.2005 auch für Radfahrer nicht passierbar ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 40230,90006 40938,90213
EOF
     },
     { from  => 1130831377, # 2005-11-01 08:49
       until => 1132354800, # 2005-11-19 00:00
       text  => 'Eldenaer Str. zwischen Thaerstr. und Proskauer Str. Baustelle, wegen Bauarbeiten gesperrt. Dauer: bis 18.11.2005',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 14363,12749 14336,12758
userdel	q4 13960,12866 14096,12827
userdel	q4 13960,12866 13844,12900
userdel	q4 14096,12827 14336,12758
EOF
     },
     { from  => 1131050267, # 2005-11-03 21:37
       until => 1132095599, # 2005-11-15 23:59
       text  => 'Romain-Rolland-Straße (Weissensee) zwischen Straße 16 und Berliner Straße Straßenarbeiten, gesperrt (bis Mitte November 2005) ',
       type  => 'handicap',
       source_id => 'IM_002329',
       data  => <<EOF,
userdel	q4 13300,17726 13031,17775 12928,17801 12856,17825
userdel	q4 12856,17825 12746,17981
EOF
     },
     { from  => undef, # 
       until => 1144438894, # Time::Local::timelocal(reverse(2006,7-1,31,0,0,0)) 2006-07-31 00:00
       text  => 'Köthener Brücke in beiden Richtungen Baustelle, Straße vollständig gesperrt (bis Mitte 2006)',
       type  => 'gesperrt',
       source_id => 'INKO_81917',
       data  => <<EOF,
userdel	2 8443,10777 8430,10710
EOF
     },
     { from  => 1131534000, # 2005-11-09 12:00
       until => 1131793200, # 2005-11-12 12:00
       text  => 'Behrenstraße, zwischen Kreuzung Ebertstraße und Kreuzung Glinkastraße in beiden Richtungen Veranstaltung, Straße gesperrt, Dauer: 10.11.2005 12:00 Uhr bis 12.11.2005 12:00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8851,12123 9059,12155
userdel	q4 8851,12123 8737,12098
userdel	q4 8595,12066 8737,12098
userdel	q4 9164,12172 9059,12155
EOF
     },
     { from  => undef, # 
       until => 1149803999, # 2006-06-08 23:59
       text  => 'Siemensstr. (Treptow-Köpenick) in Richtung Nalepastr. zwischen Edisonstr. Einbahnstraße in Richtung Nalepastr. (bis 08.06.) (17:00) ',
       type  => 'gesperrt',
       source_id => 'IM_002866',
       data  => <<EOF,
userdel	q4; 17766,6616 17962,6674
EOF
     },
     { from  => 1132097451, # 2005-11-16 00:30
       until => 1142397192, # 1146434400 2006-05-01 00:00
       text  => 'Stahnsdorf, Lindenstraße, Baustelle bis 30.04.2006, Der Verkehr wird an der Baustelle durch eine Lichtzeichenanlage halbseitig vorbeigeführt. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 -1668,-1709 -1752,-1823 -1921,-1931 -2049,-2165
EOF
     },
     { from  => 1132411558, # 2005-11-19 15:45
       until => 1136069999, # 2005-12-31 23:59
       text  => 'Weihnachtsmarkt an der Gedächtniskirche, bis 2005-12-31',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 5831,10978 5797,10881
userdel	q4 5657,10868 5652,11004
userdel	q4; 5652,11004 5716,10978 5831,10978
EOF
     },
     { from  => 1132606608, # 2005-11-21 21:56
       until => 1143842399, # 2006-03-31 23:59
       text  => 'Pistoriusstr. (Pankow) Richtung Weißensee, zwischen Hamburger Platz und Roelckestr. Baustelle, Fahrtrichtung gesperrt (bis 03/2006)',
       type  => 'gesperrt',
       source_id => 'INKO_77722',
       data  => <<EOF,
userdel	1 12708,16699 12874,16631 13131,16525
EOF
     },
     { from  => 1138319651, # 2006-01-27 00:54
       until => 1149199199, # 2006-06-01 23:59
       text  => 'Siemensstr. (Treptow) Richtung Edisonstr. zwischen Wilhelminenhofstr. und Edisonstr. Baustelle, Fahrtrichtung gesperrt (bis Anfang 06.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002441',
       data  => <<EOF,
userdel	1 17614,6571 17766,6616 17962,6674
EOF
     },
     { from  => 1130799600, # 2005-11-01 00:00
       until => 1134601200, # 2005-12-15 00:00
       text  => 'B 2 (Angermünde-OU Pinnow) OD Dobberzin grundh. Straßenbau Vollsperrung 02.11.2005-14.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 52316,69186 52711,69501
userdel	q4 52316,69186 50891,68557
EOF
     },
     { from  => 1136502000, # 2006-01-06 00:00
       until => 1136847600, # 2006-01-10 00:00
       text  => 'B 96 Neuhof-Wünsdorf Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung; Umleitung 07.01.2006-09.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1134082800, # 2005-12-09 00:00
       until => 1134428400, # 2005-12-13 00:00
       text  => 'B 96 Neuhof-Wünsdorf Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung; Umleitung 10.12.2005-12.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1136847600, # 2006-01-10 00:00
       until => 1137020400, # 2006-01-12 00:00
       text  => 'B 96 Neuhof-Wünsdorf Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung; Umleitung 11.01.2006-11.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1135033200, # 2005-12-20 00:00
       until => 1135292400, # 2005-12-23 00:00
       text  => 'B 96 Neuhof-Wünsdorf Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung; Umleitung 21.12.2005-22.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1078095600, # 2004-03-01 00:00
       until => 1136070000, # 2006-01-01 00:00
       text  => 'B 167 (Herzberg-Neuruppin) OL Alt Ruppin, Rhinbrücke Brückenneubau Vollsperrung 02.03.2004-31.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -28866,59954 -28692,59635 -28477,59467
EOF
     },
     { from  => 1067986800, # 2003-11-05 00:00
       until => 1149026400, # 2006-05-31 00:00
       text  => 'B 169 OU Senftenberg Bau Ortsumfahrung Vollsperrung 06.11.2003-30.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 54357,-96691 54884,-96292
userdel	q4 55158,-95910 54884,-96292
EOF
     },
     { from  => 1129413600, # 2005-10-16 00:00
       until => 1135983600, # 2005-12-31 00:00
       text  => 'B 198 Greiffenberger Str. OD Kerkow grundhafter Straßenbau Vollsperrung * 17.10.2005-30.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 48929,70947 49007,71214
EOF
     },
     { from  => 1127599200, # 2005-09-25 00:00
       until => 1135378800, # 2005-12-24 00:00
       text  => 'K 6419 zw. Rehfelde, R.-Luxemburg-Str. u. OE Strausberg Straßen-,Geh- u. Radwegbau Vollsperrung 26.09.2005-23.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 42578,15750 42300,15756
EOF
     },
     { from  => 1131490800, # 2005-11-09 00:00
       until => 1135378800, # 2005-12-24 00:00
       text  => 'K 6753 von OL Braunsdorf bis OL Markgrafpieske grundhafter Ausbau Vollsp. 10.11.2005-23.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 47692,-6364 47806,-6168
userdel	2 47692,-6364 47514,-6402
userdel	2 48136,-5051 48131,-4175
userdel	2 48136,-5051 47885,-5561
userdel	2 47885,-5561 47908,-5802
userdel	2 47514,-6402 47354,-6584
userdel	2 47806,-6168 47908,-5802
EOF
     },
     { from  => 1135983600, # 2005-12-31 00:00
       until => 1143842400, # 2006-04-01 00:00
       text  => 'K 6950 Gohlitzstr. OL Lehnin, zw. Belziger Str. u. Lindenstr. Straßenbau; Herst.Umleit.stre. Vollsperrung 11.10.2005-31.03.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -34655,-11263 -34337,-11047
userdel	q4 -34232,-10832 -34337,-11047
EOF
     },
     { from  => 1131836400, # 2005-11-13 00:00
       until => 1135378800, # 2005-12-24 00:00
       text  => 'K 7220 Luckenwalde-Liebätz zw. Ruhlsdorf und Liebätz Straßen- und Radwegbau Vollsperrung 14.11.2005-23.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -4686,-30955 -4311,-30322
userdel	2 -3607,-29164 -3733,-29501
userdel	2 -4031,-30164 -3733,-29501
userdel	2 -4031,-30164 -4311,-30322
EOF
     },
     { from  => 1133218800, # 2005-11-29 00:00
       until => 1135292400, # 2005-12-23 00:00
       text  => 'L 15 Fürstenberg-Menz OD Fürstenberg, Rheinsberger Str. grundhafter Straßenbau Vollsperrung; Umleitung 30.11.2005-22.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -8787,85721 -8886,85737
userdel	q4 -8886,85737 -9850,84800
EOF
     },
     { from  => 1133650800, # 2005-12-04 00:00
       until => 1133996400, # 2005-12-08 00:00
       text  => 'L 16 Bahnübergang bei Siedlung Schönwalde Gleisbauarbeiten Vollsperrung 05.12.2005-07.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -10559,23255 -10737,23418
EOF
     },
     { from  => 1134082800, # 2005-12-09 00:00
       until => 1134342000, # 2005-12-12 00:00
       text  => 'L 16 Bahnübergang bei Siedlung Schönwalde Gleisbauarbeiten Vollsperrung 10.12.2005-11.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -10559,23255 -10737,23418
EOF
     },
     { from  => 1130713200, # 2005-10-31 00:00
       until => 1134687600, # 2005-12-16 00:00
       text  => 'L 23 Töpferstr. OD Joachimsthal, Kno. Angermünder Str. Ausbau Kreisverkehrsplatz Vollsperrung 01.11.2005-15.12.2005 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 33080,63939 33254,63446
EOF
     },
     { from  => 1133823600, # 2005-12-06 00:00
       until => 1134082800, # 2005-12-09 00:00
       text  => 'L 74 Chausseestr. Eisenbahnbrücke in der OD Wünsdorf Brückenbauarbeiten Vollsperrung; Umleitung 07.12.2005-08.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15229,-27157
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1134169200, # 2005-12-10 00:00
       until => 1134601200, # 2005-12-15 00:00
       text  => 'L 201 Nauener Chaussee Bahnübegang bei Falkensee Gleisbauarbeiten Vollsperrung 11.12.2005-14.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -13897,20621 -13875,20548 -13756,20176
EOF
     },
     { from  => 1133996400, # 2005-12-08 00:00
       until => 1134255600, # 2005-12-11 00:00
       text  => 'L 201 Nauener Chaussee Bahnübergang bei Falkensee Gleisbauarbeiten Vollsperrung 09.12.2005-10.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -13897,20621 -13875,20548 -13756,20176
EOF
     },
     { from  => 1131231600, # 2005-11-06 00:00
       until => 1157061600, # 2006-09-01 00:00
       text  => 'L 202 Wustermark-Brieselang Brücke über Havelkanal bei Zeestow Brückenneubau Vollsperrung 07.11.2005-31.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -19908,17940 -18793,18169
EOF
     },
     { from  => 1134104400, # 2005-12-09 06:00
       until => 1134345600, # 2005-12-12 01:00
       text  => 'Bahnhofstraße zwischen Goltzstraße und Steinstraße, Weihnachtsmarkt, Straße gesperrt. Dauer: 10.12.2005 06:00 Uhr bis 12.12.2005 01:00 Uhr. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 10945,-2124 10747,-2129
userdel	2 10310,-2136 10453,-2133
userdel	2 10453,-2133 10747,-2129
EOF
     },
     { from  => 1134255600, # 2005-12-11 00:00
       until => 1137776400, # 2006-01-20 18:00
       text  => 'Tietzenweg zwischen Margaretenstraße und Unter den Eichen, Baustelle, Straße gesperrt. Dauer: 12.12.2005 bis 20.01.2006,18.00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 3490,4449 3425,4541
EOF
     },
     { from  => 1134428400, # 2005-12-13 00:00
       until => 1134774000, # 2005-12-17 00:00
       text  => 'B 167 Eisenbahn- u. Heegermühler Str. OD Eberswalde, Eisenbahnbrücke Ersatzneubau Brücke Vollsperrung; Umleitung 14.12.2005-16.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 36913,48088 36403,48168
EOF
     },
     { from  => 1136242800, # 2006-01-03 00:00
       until => 1136588400, # 2006-01-07 00:00
       text  => 'L 074 Chausseestr. Eisenbahnbrücke in der OD Wünsdorf Brückenbauarbeiten Vollsperrung; Umleitung 04.01.2006-06.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1138143600, # 2006-01-25 00:00
       until => 1138402800, # 2006-01-28 00:00
       text  => 'L 074 Chausseestr. Eisenbahnbrücke in der OD Wünsdorf Brückenbauarbeiten Vollsperrung 26.01.2006-27.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1130799600, # 2005-11-01 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'B 122 Schloßstr. OD Rheinsberg, zw. Königstr. und Lange Str. Kanalarbeiten halbseitige Sperrung; 02.11.2005-30.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -25679,76561 -25764,76324
EOF
     },
     { from  => 1134702000, # 2005-12-16 04:00
       until => 1135105200, # 2005-12-20 20:00
       text  => 'Säntisstraße zwischen Daimlerstraße und Nahmitzer Damm Bahnübergang gesperrt bzw. halbseitig gesperrt, Dauer: 17.12.05 04:00 Uhr bis 20.12.05 20:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9024,906 9241,1073
EOF
     },
     { from  => 1136070000, # 2006-01-01 00:00
       until => 1138057200, # 2006-01-24 00:00
       text  => 'B 179 Cottbuser-/ Fichtestr. OL Königs Wusterhausen, Bahnübergang Fichtestr. Umbau Bahnübergang Vollsperrung 02.01.2006-23.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26313,-13049 26028,-12312
EOF
     },
     { from  => 1134860400, # 2005-12-18 00:00
       until => 1135206000, # 2005-12-22 00:00
       text  => 'L 030 Karl-Marx-Str. OD Niederlehme, Autobahnbrücke A 10 Brückenneubau Vollsperrung; Umleitung 19.12.2005-21.12.2005 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 27535,-10033 27485,-10246
EOF
     },
     { from  => 1137088800, # 2006-01-12 19:00
       until => 1137301200, # 2006-01-15 06:00
       text  => 'Bellevuestraße, Presseball, Straße in beide Richtungen gesperrt, Dauer: 13.01.2006 19:00 Uhr bis 15.01.2006 06:00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 8462,11538 8209,11671 8202,11691
EOF
     },
     { from  => 1137548634, # 2006-01-18 02:43
       until => 1148759509, # 1149112799 2006-05-31 23:59
       text  => 'Voßstr. (Mitte) in Richtung Wilhelmstr. zwischen Ebertstr. und Gertrud-Kolmar-Str. Baustelle, Fahrtrichtung gesperrt (bis Ende 05.2006)',
       type  => 'handicap',
       source_id => 'IM_002419',
       data  => <<EOF,
userdel	q4; 8553,11638 8837,11676
EOF
     },
     { from  => 1137279600, # 2006-01-15 00:00
       until => 1142636400, # 2006-03-18 00:00
       text  => 'L 088 Bahnhofstr. OD Lehnin, Höhe Marktplatz Umgestaltung Marktplatz Vollsperrung 16.01.2006-17.03.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -34063,-10552 -34488,-10578
EOF
     },
     { from  => undef, # 
       until => 1152221087, # XXX undef
       text  => 'Pistoriusstr. (Weißensee) in Richtung Mirbachplatz zwischen Berliner Allee und Parkstr. Baustelle, Fahrtrichtung gesperrt',
       type  => 'handicap',
       source_id => 'IM_002437',
       data  => <<EOF,
userdel	q4; 14067,16127 13797,16237
EOF
     },
     { from  => 1138319443, # 2006-01-27 00:50
       until => 1141167599, # 2006-02-28 23:59
       text  => 'Rosa-Luxemburg-Str. (Mitte) in Richtung Memhardtstr. zwischen Karl-Liebknecht-Str. und Memhardtstr. Baustelle, Fahrtrichtung gesperrt, eine Umleitung ist eingerichtet (bis Ende Februar 2006)',
       type  => 'handicap',
       source_id => 'INKO_75621',
       data  => <<EOF,
userdel	q4; 10706,13043 10755,13152
EOF
     },
     { from  => 1138402800, # 2006-01-28 00:00
       until => 1138575600, # 2006-01-30 00:00
       text  => 'B 096 a Brücke über DB AG zw. Glasower Str. u. Waßmannsdorfer Ch. Brückenneubau Vollsperrung * 29.01.2006-29.01.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
	2 13289,-4660 13655,-4831
EOF
     },
     { from  => 1141340400, # 2006-03-03 00:00
       until => 1141599600, # 2006-03-06 00:00
       text  => 'B 096 Neuhof-Wünsdorf Bahnübergang in OL Neuhof Gleisbauarbeiten Vollsperrung; Umleitung 04.03.2006-05.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1144015200, # 2006-04-03 00:00
       until => 1150668000, # 2006-06-19 00:00
       text  => 'B 112 Guben-Frankfurt (O) Kreuz. L 45/B 112/K6702 in Steinsdorf Bau der Kreuzung Vollsperrung 04.04.2006-18.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	2 91858,-18170 90698,-16886
EOF
     },
     { from  => undef, # 
       until => 1139428054, # XXX
       text  => 'Elsenstr. (Kaulsdorf) in beiden Richtungen zwischen Kressenweg und Hornungsweg Wasser auf der Fahrbahn, Straße vollständig gesperrt ',
       type  => 'gesperrt',
       source_id => 'LMS_1138607956237',
       data  => <<EOF,
userdel	2 23571,10990 24389,10836
EOF
     },
     { from  => 1150092737, # 2006-06-12 08:12
       until => 1150737175, # 1167605999 2006-12-31 23:59, jetzt nur noch "Engstellensignalisierung"
       text  => 'Schlichtallee (Rummelsburg) in Richtung Nord, auf der südlichen Bahnbrücke Baustelle; Fahrtrichtung gesperrt (bis Ende 12/2006) ',
       type  => 'handicap',
       source_id => 'IM_002885',
       data  => <<EOF,
userdel	q4; 15629,10481 15751,10582 16032,10842
EOF
     },
     { from  => undef, # 
       until => 1139470769, # XXX
       text  => 'Berlin-Lübars: Am Freibad in beiden Richtungen Wasser auf der Fahrbahn, gesperrt',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 5727,23485 5297,23633
EOF
     },
     { from  => undef, # 
       until => 1140727101, # XXX
       text  => 'Tempelhofer Weg (Tempelhof) von Gottlieb-Dunkel-Str. bis Hattenheimer Str. Baustelle, Fahrtrichtung gesperrt',
       type  => 'handicap',
       source_id => 'IM_002431',
       data  => <<EOF,
userdel	q4; 11456,6103 11590,6026
EOF
     },
     { from  => 1140303600, # 2006-02-19 00:00
       until => 1164927600, # 2006-12-01 00:00
       text  => 'B 096 Gransee-Fürstenberg Brücke über Wentowkanal bei Dannenwalde Brückenabriß- u. -neubau Vollsperrung 20.02.2006-30.11.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -5962,74421 -6037,73865
EOF
     },
     { from  => 1140994800, # 2006-02-27 00:00
       until => 1141426800, # 2006-03-04 00:00
       text  => 'B 122 Alt Ruppin-Dierberg Bahnübergang bei Dierberg Gleisbauarbeiten Vollsperrrung 28.02.2006-03.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -22567,67134 -21150,67860
userdel	2 -21150,67860 -20726,68037
EOF
     },
     { from  => 1139871600, # 2006-02-14 00:00
       until => 1141426800, # 2006-03-04 00:00
       text  => 'B 179 Berliner Str. OL Königs Wusterhausen, zw. Schloßplatz u. Gartenweg Havarie SW-Schacht Vollsperrung 15.02.2006-03.03.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 25859,-11559 25640,-11357
EOF
     },
     { from  => undef, # 
       until => 1140120150, # XXX
       text  => 'Säntisstraße zwischen Daimlerstraße und Albanstraße Störung am Bahnübergang, Straße gesperrt ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8957,852 9024,906
userdel	2 9241,1073 9024,906
EOF
     },
     { from  => 1140303600, # 2006-02-19 00:00
       until => 1153807245, # 2006-08-05 00:00 1154728800
       text  => 'B 246 Trebbin-Beelitz OD Löwendorf, zw. Ahrensdorfer Str. u. Schillerstr. Straßen- und Kanalbau Vollsperrung 20.02.2006-04.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -2643,-21212 -2815,-20920
EOF
     },
     { from  => 1140509431, # 2006-02-21 09:10
       until => 1140560993, # expired ... 2006-03-11 00:00
       text  => 'Peschkestraße zwischen Rheinstraße und Holsteinische Straße wegen Tiefbauarbeiten bis voraussichtlich 10.03.06 gesperrt. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 5532,6525 5424,6584
EOF
     },
     { from  => 1140908400, # 2006-02-26 00:00
       until => 1156716000, # 2006-08-28 00:00
       text  => 'L 029 Eberswalder Chaussee OD Oderberg, von Berliner Str. in Ri. Eberswalde Beseit. Tragfähigkeitsschäden Vollsperrung 27.02.2006-27.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 52671,51846 51496,51542
EOF
     },
     { from  => 1141499777, # 1141426800 2006-03-04 00:00
       until => 1141499852, # 1142031600 2006-03-11 00:00
       text  => 'L 401 Richard-Sorge-Str./ Bergstr. OL Wildau, Bahnübergang Bergstr. Gleisbauarbeiten Einmünd. gesp. 05.03.2006-10.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26381,-9962 25700,-9502
EOF
     },
     { from  => 1141254000, # 2006-03-02 00:00
       until => 1141686000, # 2006-03-07 00:00
       text  => 'L 090 Phöbener Str. Bahnübergang in OL Werder Gleisbauarbeiten Vollsperrung; Umleitung 03.03.2006-06.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -22206,-1693 -22042,-2060
EOF
     },
     { from  => 1142118000, # 2006-03-12 00:00
       until => 1144965600, # 2006-04-14 00:00
       text  => 'B 101 Trebbiner Str. OL Luckenwalde, zw. Beelitzer Str. u. Potsdamer Str. Anschluß Gewerbehof Vollsperrung; Umleitung 13.03.2006-13.04.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -4299,-35198 -4204,-35072
EOF
     },
     { from  => 1142809200, # 2006-03-20 00:00
       until => 1144187940, # 2006-04-04 23:59
       text  => 'L 070 Sperenberg-Trebbin zw. Abzw.Chrisinend. u. Abzw.Kl.Schulzend.Ber.Brücke B101n Brückenbau Vollsperrung 21.03.2006-04.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 1740,-23380 1079,-23181
EOF
     },
     { from  => 1141561135, # 2006-03-05 13:18
       until => 1193871599, # 2007-10-31 23:59
       text  => 'Die Kaulsdorfer Brücke ist ab Montag 06.03.2006, 6.00 Uhr bis voraussichtlich Herbst 2007 gesperrt.',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22691,12044 22668,12080
userdel	2 22668,12080 22701,12115
EOF
     },
     { from  => 1141765672, # 2006-03-07 22:07
       until => 1150408799, # 2006-06-15 23:59
       text  => 'Niedstr. (Friedenau) in beiden Richtungen zwischen Lauterstr. und Handjerystr. Baustelle Straße vollständig gesperrt (bis Mitte 06.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002505',
       data  => <<EOF,
userdel	2 5810,7337 5653,7333
EOF
     },
     { from  => 1141765814, # 2006-03-07 22:10
       until => 1150408799, # 2006-06-15 23:59
       text  => 'Niedstr. (Friedenau) von Handjerystr. bis Friedrich-Wilhelmplatz Einbahnstr. (bis Mitte 06.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002505',
       data  => <<EOF,
userdel	1 5364,7330 5653,7333
EOF
     },
     { from  => 1142118000, # 2006-03-12 00:00
       until => 1142632779, # 1157061600 2006-09-01 00:00
       text  => 'L 745 Motzen-B246 Gallun zw. OA Motzen und OE Gallun Straßenbauarbeiten Vollsperrung 13.03.2006-31.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22476,-19219 22338,-19081
userdel	2 22476,-19219 22599,-19785
userdel	2 22324,-18950 22338,-19081
userdel	2 23356,-20982 22599,-19785
EOF
     },
     { from  => 1142424201, # 2006-03-15 13:03
       until => 1159653599, # 2006-09-30 23:59
       text  => 'Wiesbadener Str. (Wilmersdorf) in Richtung Bundesallee zwischen Geisenheimer und Südwestkorso Baustelle, Fahrtrichtung gesperrt. Ebenso gesperrt: Geisenheimer Str. Richtung Wiesbadener Str. (bis Ende 09.2006)',
       type  => 'handicap',
       source_id => 'IM_002513',
       data  => <<EOF,
userdel	q4; 4391,7258 4618,7231 4743,7212
userdel	q4; 4534,7015 4462,7137 4391,7258
EOF
     },
     { from  => 1143068400, # 2006-03-23 00:00
       until => 1149120177, # 1151704800 2006-07-01 00:00
       text  => 'K 7219 Zülichendorf-Dobbrikow OD Nettgendorf, zw. OE und Klinkenmühler Str. Kanal- und Straßenbau Vollsperrung 24.03.2006-30.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -12904,-28790 -12925,-29046
userdel	q4 -12904,-28790 -12713,-28704
EOF
     },
     { from  => 1146002400, # 2006-04-26 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'B 087 Beeskow-Lübben OD Ranzig Straßenbauarbeiten Vollsperrung 27.04.2006-12.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 64853,-30986 65386,-29479
EOF
     },
     { from  => undef, # 
       until => 1148166908, # XXX nur noch Fahrstreifeneinschränkung...
       text  => 'Bötzowstr. (Prenzlauer Berg) in beiden Richtungen, zwischen Danziger Str. und Hufelandstr. Baustelle, Straße vollständig gesperrt',
       type  => 'handicap',
       source_id => 'IM_002530',
       data  => <<EOF,
userdel	q4 12438,14054 12499,14136
userdel	q4 12438,14054 12380,13975
userdel	q4 12578,14237 12630,14306
userdel	q4 12578,14237 12499,14136
EOF
     },
     { from  => 1142632575, # 2006-03-17 22:56
       until => 1142895600, # 2006-03-21 00:00
       text  => 'Charlottenstr. (Mitte) in Richtung Unter den Linden zwischen Mittelstr. und Unter den Linden Baustelle, Straße vollständig gesperrt (bis 20.03.2006)',
       type  => 'handicap',
       source_id => 'IM_002531',
       data  => <<EOF,
userdel	q4; 9465,12460 9476,12359
EOF
     },
     { from  => 1143410400, # 2006-03-27 00:00
       until => 1143842400, # 2006-04-01 00:00
       text  => 'B 122 Alt Ruppin-Dierberg Bahnübergang bei Dierberg Gleisbauarbeiten Vollsperrrung 28.03.2006-31.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -28116,60092 -27347,60616
EOF
     },
     { from  => 1146434400, # 2006-05-01 00:00
       until => 1146607200, # 2006-05-03 00:00
       text  => 'L 074 Chausseestraße OL Wünsdorf, Bahnbrücke Brückenbauarbeiten Vollsperrung 02.05.2006-02.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15229,-27157
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1143583200, # 2006-03-29 00:00
       until => 1143756000, # 2006-03-31 00:00
       text  => 'L 074 Chausseestraße OL Wünsdorf, Bahnbrücke Brückenbauarbeiten Vollsperrung 30.03.2006-30.03.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15229,-27157
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1143154477, # 2006-03-23 23:54
       until => 1143227432, # 1155679200 2006-08-16 00:00
       text  => 'Fürstenwalder Damm in beiden Richtungen zwischen Dahlwitzer Landstraße und Müggelseedamm (West) beidseitig Baustelle, gesperrt bis 15.08.2006',
       type  => 'handicap',
       source_id => 'LMS_1142967727545',
       data  => <<EOF,
userdel	q4 25039,5766 23950,5342
userdel	q4 25039,5766 25121,5799
userdel	q4 25579,5980 25121,5799
EOF
     },
     { from  => 1146520800, # 2006-05-02 00:00
       until => 1146693600, # 2006-05-04 00:00
       text  => 'B 096 OD Neuhof BÜ Neuhof Gleisbau Vollsperrung 03.05.2006-03.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1146693600, # 2006-05-04 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'B 096 OD Neuhof BÜ Neuhof Gleisbau Vollsperrung 05.05.2006-12.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1144262992, # 1144965600 2006-04-14 00:00
       until => 1144263001, # Cancelled 1145138400 2006-04-16 00:00
       text  => 'B 096 OD Neuhof BÜ Neuhof Gleisbau Vollsperrung 15.04.2006-15.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1142895600, # 2006-03-21 00:00
       until => 1149112800, # 2006-06-01 00:00
       text  => 'B 198 OD Kerkow Greiffenbg.Str. Kerkow Neubau Straße Vollsperrung 22.03.2006-31.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 48929,70947 49007,71214
EOF
     },
     { from  => 1143575024, # 2006-03-28 21:43
       until => 1143820800, # 2006-03-31 18:00
       text  => 'Hirtenstr. Arbeiten an Wasserleitungen, Straße in beiden Richtungen gesperrt. (zwischen Rosa-Luxemburg-Str. und Kleine Alexanderstr.) bis 31.03.06, 18:00 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 10846,13362 10923,13317
EOF
     },
     { from  => undef, # 
       until => 1144438933, # XXX
       text  => 'Zoppoter Str. (Wilmersdorf) in beiden Richtungen zwischen Heiligendammer Str. und Breitestr. Tiefbauarbeiten, Straße vollständig gesperrt',
       type  => 'handicap',
       source_id => 'IM_002552',
       data  => <<EOF,
userdel	q4 3349,7361 3314,7269
EOF
     },
     { from  => 1143928800, # 2006-04-02 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'B 087 OL Ranzig Deckenerneuerung Vollsperrung 03.04.2006-12.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 63609,-34428 64853,-30986
EOF
     },
     { from  => 1143324000, # 2006-03-25 23:00
       until => 1144263353, # 1152914400 2006-07-15 00:00
       text  => 'L 019 Kremmen, Schloßdamm, Ruppiner Str. Kremmen Neubau Fahrbahn Vollsperrung 27.03.2006-14.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -15302,43177 -15278,42709
userdel	2 -14998,42541 -15278,42709
EOF
     },
     { from  => 1143928800, # 2006-04-02 00:00
       until => 1157148000, # 2006-09-02 00:00
       text  => 'B 198 Dr. Wilhelm Külz Str. Straßenbau Vollsperrung 03.04.2006-01.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 39322,101924 39574,101863
userdel	q4 39715,101866 39574,101863
EOF
     },
     { from  => 1142377200, # 2006-03-15 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'B 198 bei Schmiedeberg Neubau Brücke Vollsperrung 16.03.2006-30.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 46677,82770 47081,83093
EOF
     },
     { from  => 1133046000, # 2005-11-27 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'K 6422 Ernst-Thälmann-Str. OL Fredersdorf, Kno.. Bollensdorfer Allee u. Kno. Fließstr. Errichtung Lichtsignalanlage Vollsperrung 28.11.2005-30.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34139,13113 33644,12458
EOF
     },
     { from  => 1143410400, # 2006-03-27 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'L 220 OD Joachimsthal Bau Kreisverkehr Vollsperrung 28.03.2006-30.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 33787,63026 33254,63446
EOF
     },
     { from  => 1144792800, # 2006-04-12 00:00
       until => 1147298400, # 2006-05-11 00:00
       text  => 'L 745 Motzen- Gallun zw. OA Motzen und OE Gallun Straßenbau Vollsperrung 13.04.2006-10.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22476,-19219 22338,-19081
userdel	2 22476,-19219 22599,-19785
EOF
     },
     { from  => 1144015200, # 2006-04-03 00:00
       until => 1148162400, # 2006-05-21 00:00
       text  => 'B 112 Steinsdorf, Einmündung L45/B112 Herstellung Anbindung L45 Vollsperrung 04.04.2006-20.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 98052,-40791 98091,-41089
EOF
     },
     { from  => 1144176662, # 2006-04-04 20:51
       until => 1144263062, # 2006-04-05 20:51
       text  => ' ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 16407,-29400 16379,-29446
userdel	2 16336,-29511 16379,-29446
EOF
     },
     { from  => 1144015200, # 2006-04-03 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'K 6419 zw. Rehfelde, R.-Luxemburg-Str. u. OE Strausberg Straßen-,Geh- u. Radwegbau Vollsperrung 04.04.2006-30.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 42996,14793 42578,15750
userdel	2 42578,15750 42300,15756
userdel	2 41681,15915 42300,15756
EOF
     },
     { from  => 1143324000, # 2006-03-25 23:00
       until => 1152914400, # 2006-07-15 00:00
       text  => 'L 019 Schloßdamm, Ruppiner Str. OD Kremmen grundhafter Straßenbau Vollsperrung 27.03.2006-14.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -15961,38892 -16173,38465
EOF
     },
     { from  => 1153737956, # 2006-07-24 12:45
       until => 1155679199, # 2006-08-15 23:59
       text  => 'L05 Karl-Marx-Str. (Großziethen) in beiden Richtungen zwischen Nibelungenstraße und Erlenweg Baustelle, Straße vollständig gesperrt, eine Umleitung ist eingerichtet (bis Mitte 08.2006)',
       type  => 'handicap',
       source_id => 'IM_002624',
       data  => <<EOF,
userdel	q4 13225,-681 13090,205 12984,1011
EOF
     },
     { from  => 1143928800, # 2006-04-02 00:00
       until => 1155938400, # 2006-08-19 00:00
       text  => 'L 077 Lindenstr. OD Stahnsdorf, zw. Streuobsthang u. Ruhlsdorfer Str. Geh- und Radwegbau halbseitig gesperrt; Einbahnstraße 03.04.2006-18.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 -2049,-2165 -1921,-1931 -1752,-1823
EOF
     },
     { from  => 1144706400, # 2006-04-11 00:00
       until => 1145829600, # 2006-04-24 00:00
       text  => 'L 079 Ludwigsfelde-Ahrensdorf zw. Ludwigsfelde und Ahrensdorf Straßenbauarbeiten Vollsperrung 12.04.2006-23.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -2086,-9891 -1245,-9999
EOF
     },
     { from  => 1145570400, # 2006-04-21 00:00
       until => 1145916000, # 2006-04-25 00:00
       text  => 'B 001 zw. Abzw. Hennickendorf und Tasdorf Deckeneinbau Vollsperrung 22.04.2006-24.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 36874,10046 37154,10022
userdel	2 37154,10022 37670,9871
EOF
     },
     { from  => 1144274400, # 2006-04-06 00:00
       until => 1144620000, # 2006-04-10 00:00
       text  => 'B 112 Ziltendorf-Brieskow Finkenheerd OD Wiesenau Straßenbauarbeiten Vollsperrung; Umleitung 07.04.2006-09.04.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 91858,-18170 90698,-16886
EOF
     },
     { from  => 1145743200, # 2006-04-23 00:00
       until => 1146261600, # 2006-04-29 00:00
       text  => 'L 216 Gollin-Templin OD Vietmannsdorf, Brücke über Mühlengraben Einbau Decke Vollsperrung 24.04.2006-28.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 17636,72217 17653,71852
EOF
     },
     { from  => 1144438665, # 2006-04-07 21:37
       until => 1146434400, # 2006-05-01 00:00
       text  => 'Brücke über den Nordgraben (Reinickendorf) in beiden Richtungen, in Höhe Schorfheidestr. Baustelle, Straße vollständig gesperrt (bis 30.04.06)',
       type  => 'gesperrt',
       source_id => 'INKO_82299',
       data  => <<EOF,
userdel	2 6281,20369 6289,20468
EOF
     },
     { from  => 1144438729, # 2006-04-07 21:38
       until => 1144706400, # 2006-04-11 00:00
       text  => 'Charlottenstr. (Mitte) in beiden Richtungen, in Höhe Mittelstr. Baustelle, Straße vollständig gesperrt (bis 10.04.06)',
       type  => 'gesperrt',
       source_id => 'IM_002607',
       data  => <<EOF,
userdel	2 9454,12558 9465,12460
userdel	2 9476,12359 9465,12460
EOF
     },
     { from  => 1144438828, # 2006-04-07 21:40
       until => 1151704800, # 2006-07-01 00:00
       text  => 'Roelckestr. (Weissensee) in beiden Richtungen zwischen Charlottenburger Str. und Pistoriusstr. Baustelle, Straße bis 30.06.2006 vollständig gesperrt',
       type  => 'gesperrt',
       source_id => 'IM_002598',
       data  => <<EOF,
userdel	2 13131,16525 13045,16368
EOF
     },
     { from  => 1144339200, # 2006-04-06 18:00
       until => 1148745600, # 2006-05-27 18:00
       text  => 'Herzbergstraße, zwischen Siegfriedstraße und Vulkanstraße gesperrt, die Gegenrichtung ist als Einbahnstraße ausgeschildert, Straße am Wasserwerk, zwischen Herzbergstraße und Landsberger Allee gesperrt, Baustelle. Dauer: 07.04.2006 , 18:00 Uhr bis 27.05.2006, 18:00 Uhr. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 16866,13532 15892,13534
EOF
     },
     { from  => 1144483509, # 2006-04-08 10:05
       until => 1144706400, # 2006-04-11 00:00
       text  => 'Möllendorffstr. (Lichtenberg) in Richtung Süden, zwischen Am Containerbahnhof und Frankfurter Allee Baustelle, Straße vollständig gesperrt, Radweg womöglich noch nutzbar (bis 10.04.06)',
       type  => 'handicap',
       source_id => 'IM_002605',
       data  => <<EOF,
userdel	q4; 15392,12135 15349,12073
EOF
     },
     { from  => undef, # 
       until => 1144619999, # 2006-04-09 23:59
       text  => 'Scharnweberstr. (Reinickendorf) in beiden Richtungen zwischen Eichborndamm und Hechelstr. Veranstaltung, Straße vollständig gesperrt (Straßenfest)',
       type  => 'handicap',
       source_id => 'IM_002611',
       data  => <<EOF,
userdel	q4 4386,17760 4581,17689
userdel	q4 4386,17760 4324,17782
userdel	q4 4581,17689 4695,17648
userdel	q4 4324,17782 4086,17873 4013,17901
EOF
     },
     { from  => 1144706400, # 2006-04-11 00:00
       until => 1147298400, # 2006-05-11 00:00
       text  => 'B 096 Hauptstr. OD Baruth Einbau Spundwände Vollsperrung 12.04.2006-10.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 18307,-38801 18042,-39923
EOF
     },
     { from  => 1144792800, # 2006-04-12 00:00
       until => 1144965600, # 2006-04-14 00:00
       text  => 'B 320 Birkenhainichener Str. zw. OL Groß Leine und Birkenhainichen Deckenerneuerung Vollsperrung 13.04.2006-13.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 55628,-43569 56193,-44322
userdel	2 56193,-44322 56510,-44474
EOF
     },
     { from  => 1145224800, # 2006-04-17 00:00
       until => 1145743200, # 2006-04-23 00:00
       text  => 'K 7220 Potsdamer Str. OL Luckenwalde, zw. Buchtstr. u. Feldstr. Abbrucharbeiten Vollsperrung 18.04.2006-22.04.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -4173,-34910 -4129,-34535
EOF
     },
     { from  => 1145743200, # 2006-04-23 00:00
       until => 1146175200, # 2006-04-28 00:00
       text  => 'L 030 Tiergartenstr. OL Königs Wusterhausen, Schleusenbrücke Brückenreparatur Vollsperrung 24.04.2006-27.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 27543,-11912 27657,-11741
EOF
     },
     { from  => 1144959197, # 2006-04-13 22:13
       until => 1147557600, # 2006-05-14 00:00
       text  => 'Jüterborger Str. (Kreuzberg) in Richtung Golßener Str., zwischen Friesenstr. und Heimstr. Baustelle, Fahrtrichtung gesperrt (bis 13.05.06)',
       type  => 'handicap',
       source_id => 'IM_002632',
       data  => <<EOF,
userdel	q4; 9799,8962 9958,8966
EOF
     },
     { from  => 1145649600, # 2006-04-21 22:00
       until => 1145844000, # 2006-04-24 04:00
       text  => '21.04.2006, 22.00 Uhr bis 24.04.2006, 4.00 Uhr Vollsperrung der Ottomar-Geschke-Straße ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 21182,4336 21174,4250
userdel	2 21100,4192 21174,4250
EOF
     },
     { from  => 1151002800, # 2006-06-22 21:00
       until => 1151168400, # 2006-06-24 19:00
       text  => '23.06.2006, 21.00 Uhr bis 24.06.2006, 19.00 Uhr Vollsperrung der Ottomar-Geschke-Straße ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 21182,4336 21174,4250
userdel	2 21100,4192 21174,4250
EOF
     },
     { from  => 1145209261, # 2006-04-16 19:41
       until => 1145311200, # 2006-04-18 00:00
       text  => 'Adamstr. (Spandau) in beiden Richtungen zwischen Wilhelmstr. und Pichelsdorfer Str. Veranstaltung, Straße vollständig gesperrt (bis 17.04.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002648',
       data  => <<EOF,
userdel	2 -4167,12554 -4223,12631
userdel	2 -4167,12554 -4069,12558
userdel	2 -3621,12575 -3738,12572
userdel	2 -3738,12572 -3876,12567
userdel	2 -3876,12567 -4069,12558
EOF
     },
     { from  => 1145397600, # 2006-04-19 00:00
       until => 1149112800, # 2006-06-01 00:00
       text  => 'L 010 Havelberger Str. OD Bad Wilsnack, vom OE bis An der Trift Kanal- und Straßenbau Vollsperrung 20.04.2006-31.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -89647,59213 -89549,58784
EOF
     },
     { from  => 1145224800, # 2006-04-17 00:00
       until => 1147557600, # 2006-05-14 00:00
       text  => 'L 080 Brandenburger Str. OL Luckenwalde, Kreuz. Dessauer Str. Kanalarbeiten Vollsperrung 18.04.2006-13.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -5036,-34940 -4888,-34952
EOF
     },
     { from  => 1145392820, # 2006-04-18 22:40
       until => 1146348000, # 2006-04-30 00:00
       text  => 'Kreuzstr. (Pankow) in beiden Richtungen, zwischen Grabbeallee und Wollankstr. Baustelle, Straße vollständig gesperrt (bis 29.04.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002650',
       data  => <<EOF,
userdel	2 9902,18180 9909,18333
userdel	2 9902,18180 9832,17925
EOF
     },
     { from  => 1145311200, # 2006-04-18 00:00
       until => 1155679200, # 2006-08-16 00:00
       text  => 'L 034 Philipp-Müller-Str./ Wriezener Str. OD Strausberg, Nordkreuzung Kreiselneubau Vollsperrung 19.04.2006-15.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 43553,20466 43584,20871
userdel	q4 43584,20871 43498,21028
userdel	q4 43584,20871 43209,20665
userdel	q4 43584,20871 44596,21287
EOF
     },
     { from  => 1145336400, # 2006-04-18 07:00
       until => 1145642400, # 2006-04-21 20:00
       text  => 'Karlsruher Straße zwischen Kurfürstendamm und Heilbronner Straße, Baustelle, Straße gesperrt. Dauer: 19.04.2006 bis 21.04.2006 jeweils zwischen 07.00 Uhr und 20.00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2965,10522 2938,10071
EOF
     },
     { from  => 1145343600, # 2006-04-18 09:00
       until => 1145451600, # 2006-04-19 15:00
       text  => 'Invalidenstraße, Prenzlauer Berg Richtung Tiergarten Zwischen Kreuzung Gartenstraße und Kreuzung Chausseestraße Baustelle, gesperrt, Dauer: 19.04.2006 09:00 Uhr bis 15:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9383,13978 9203,13953
userdel	2 9151,13941 9203,13953
userdel	2 9151,13941 9076,13915
userdel	2 9076,13915 8935,13844
EOF
     },
     { from  => 1145430358, # 2006-04-19 09:05
       until => 1146866400, # 2006-05-06 00:00
       text  => 'Prenzlauer Promenade (Prenzlauer Berg) im Kreuzungsbereich Ostseestr. und Wisbyer Str Baustelle, in Richtung stadteinwärts Straße gesperrt (Radfahrer können möglicherweise den Gehweg benutzen) (bis 05.05.06)',
       type  => 'handicap',
       source_id => 'IM_002644',
       data  => <<EOF,
userdel	q4; 12097,16263 12091,16209
EOF
     },
     { from  => 1145562106, # 2006-04-20 21:41
       until => 1150495200, # 2006-06-17 00:00
       text  => 'Ruschstr. (Lichtenberg) in Richtung Süd, in Höhe Normannenstr. Einbahnstraße in Richtung Nord, Einfahrt in Normannenstr. gesperrt (bis 16.06.06)',
       type  => 'handicap',
       source_id => 'IM_002668',
       data  => <<EOF,
userdel	q4; 15904,12340 15863,11992
EOF
     },
     { from  => 1146175200, # 2006-04-28 00:00
       until => 1146348000, # 2006-04-30 00:00
       text  => 'L 090 Eisenbahnstr OL Werder Festumzug 127. Baumblütenfest Vollsperrung 29.04.2006-29.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -21220,-3831 -21284,-3767
userdel	2 -21284,-3767 -21266,-3604
EOF
     },
     { from  => 1145916000, # 2006-04-25 00:00
       until => 1146175200, # 2006-04-28 00:00
       text  => 'K 6216 Zinsdorf-Beutersitz Brücke über Schwarze Elster bei Neumühl Arbeiten an Wehranlage, Vollsperrung 26.04.2006-27.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8987,-92875 9450,-92307
EOF
     },
     { from  => 1146251142, # XXX 2006-05-01 00:00
       until => 1146251563, # XXX 2006-07-29 00:00
       text  => 'B 168 Fürstenwalde-Müncheberg zw. Beerfelde und Schönfelde Straßenbauarbeiten Vollsperrung 02.05.2006-28.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 54428,4464 54602,4910
userdel	2 54602,4910 54157,5895
EOF
     },
     { from  => 1147298400, # 2006-05-11 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'L 074 Chausseestraße OL Wünsdorf, Bahnbrücke Brückenbauarbeiten Vollsperrung 12.05.2006-12.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15682,-26971 15229,-27157
userdel	2 15682,-26971 15960,-26906
EOF
     },
     { from  => 1145916000, # 2006-04-25 00:00
       until => 1146175200, # 2006-04-28 00:00
       text  => 'K 6216 Zinsdorf-Beutersitz Brücke über Schwarze Elster bei Neumühl Arbeiten an Wehranlage Vollsperrung * 26.04.2006-27.04.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8987,-92875 9450,-92307
EOF
     },
     { from  => 1146088800, # 2006-04-27 00:00
       until => 1146348000, # 2006-04-30 00:00
       text  => 'Seifenkisten auf dem Mehringdamm, 28.4.2006-29.4.2006',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 9248,9350 9235,9111 9235,9051 9227,8890 9222,8787
EOF
     },
     { from  => 1146701340, # 2006-05-04 02:09
       until => 1150916294, # 2006-09-25 15:00 1159189200 (moved)
       text  => 'Schulzendorfer Straße zwischen Ruppiner Chaussee und Blisenkrautstr. in beiden Richtungen Baustelle, gesperrt bis 25.09.2006 15:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -862,22946 -596,23009
userdel	2 -862,22946 -1254,22853
EOF
     },
     { from  => 1146701434, # 2006-05-04 02:10
       until => 1146834000, # 2006-05-05 15:00
       text  => 'Holtzendorffstr. zwischen Rönnestr. und Gervinusstr. in beiden Richtungen Brückenarbeiten gesperrt bis 05.05.06, 15:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 3093,10594 3049,10719
EOF
     },
     { from  => 1146768809, # 2006-05-04 20:53
       until => 1167606000, # 2007-01-01 00:00
       text  => 'Weinmeisterstr. (Mitte) in Richtung Alexanderplatz Baustelle, Straße vollständig gesperrt, Einbahnstraßenreglung in Richtung Rosenthaler Str. (bis 31.12.06)',
       type  => 'gesperrt',
       source_id => 'IM_002733',
       data  => <<EOF,
userdel	1 10331,13397 10528,13243
EOF
     },
     { from  => 1147557600, # 2006-05-14 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'L 037 Petersdorfer Str. OD Petershagen Kanal- und Straßenbauarbeiten Vollsperrung 15.05.2006-30.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 74092,475 74246,584
EOF
     },
     { from  => undef, # 
       until => 1147121258, # XXX
       text  => 'Mühlenstr. (Pankow) in Richtung Norden zwischen Florastr und Dolomitenstr. Einbahnstraße in Richtung Süden',
       type  => 'gesperrt',
       source_id => 'IM_002743',
       data  => <<EOF,
userdel	1 10596,17554 10510,17649 10459,17754
EOF
     },
     { from  => undef, # 
       until => 1147067585, # XXX
       text  => 'Reichstagufer (Mitte) zwischen Neustädter Kirchstr. und Friedrichsstr. Gefahr durch Uferunterspühlung, Straße gesperrt.',
       type  => 'gesperrt',
       source_id => 'LMS_1146113785841',
       data  => <<EOF,
userdel	2 9091,12681 9209,12795
userdel	2 9283,12856 9209,12795
EOF
     },
     { from  => 1146693600, # 2006-05-04 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'B 158 zw. OL Seefeld, Löhmer Ch. und Bahnübergang Gleis- u. Straßenbauarbeiten Vollsperrung 05.05.2006-12.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26936,23104 27283,23503
userdel	2 28323,24341 27608,23776
userdel	2 27283,23503 27608,23776
EOF
     },
     { from  => 1146866400, # 2006-05-06 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'L 401 R.-Sorge-/ Bergstr. Bahnübergang Bergstraße Gleisbauarbeiten Zufahrt gesperrt 07.05.2006-12.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26381,-9962 25700,-9502
EOF
     },
     { from  => 1146897090, # 2006-05-06 08:31
       until => 1147086000, # 2006-05-08 13:00
       text  => 'Wilhelmstraße Richtung Pichelsdorf zwischen Einmündung Pichelsdorfer Straße und Einmündung Gatower Straße Baustelle, gesperrt bis 08.05.2006 13:00 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 -3791,13357 -3887,13057 -3937,12971 -3974,12914 -4028,12831 -4081,12765 -4150,12689 -4223,12631 -4300,12571 -4335,12465
EOF
     },
     { from  => 1146801600, # 2006-05-05 06:00
       until => 1147039140, # 2006-05-07 23:59
       text  => ' Sonnenallee Zwischen Kreuzung Wildenbruchstraße und Pannierstraße in beiden Richtungen gesperrt, Veranstaltung, Dauer: 06.05.2006 06:00 Uhr bis 07.05.2006 23:59 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12438,8859 12320,8927
userdel	2 12438,8859 12483,8834
userdel	2 12925,8494 12772,8612
userdel	2 12483,8834 12630,8722
userdel	2 12742,8635 12630,8722
userdel	2 12242,8972 12320,8927
EOF
     },
     { from  => undef, # 
       until => 1148166862, # XXX tritt nirgendwo mehr auf
       text  => 'Riemenschneiderweg zwischen Vorarlberger Damm und Grazer Platz, Baustelle, in beiden Richtungen gesperrt.',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6802,6816 6773,7116
EOF
     },
     { from  => 1147816800, # 2006-05-17 00:00
       until => 1148335200, # 2006-05-23 00:00
       text  => 'L 030 Friedrichstr. OL Erkner, zw. fürstenwalder Str. u. Beuststr. 14. Heimatfest Vollsperrung 18.05.2006-22.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 34443,1951 34250,2546
EOF
     },
     { from  => 1147212000, # 2006-05-10 00:00
       until => 1147471200, # 2006-05-13 00:00
       text  => 'K 6503 KG Lubowsee-L211 nördl. Summt Kreuzung Zühlslake Vorber. Kreiselneubau Vollsperrung 11.05.2006-12.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 7435,34963 7070,34665
EOF
     },
     { from  => 1147384800, # 2006-05-12 00:00
       until => 1147557600, # 2006-05-14 00:00
       text  => 'L 015 Fürstenberger Str. OL Lychen, ab Vogelsangstr. bis Am Markt Einbau Deckschicht Vollsperrung 13.05.2006-13.05.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 2788,89447 2179,89513
EOF
     },
     { from  => 1147522037, # 2006-05-13 14:07
       until => 1148940000, # 2006-05-30 00:00
       text  => 'Buschallee (Weißensee) in Richtung Berliner Allee, zwischen Hansastr. und Berliner Allee Baustelle Straße vollständig gesperrt (bis 29.05.06)',
       type  => 'gesperrt',
       source_id => 'IM_002776',
       data  => <<EOF,
userdel	1 15388,16502 15121,16503 14621,16563
EOF
     },
     { from  => 1147721063, # 2006-05-15 21:24
       until => undef, # was 2006-05-17 00:00, but continuing
       text  => 'Linienstr. (Mitte) in Richtung Tucholskystr., ab Oranienburger Str. Straßenarbeiten, Einbahnstraße',
       type  => 'handicap',
       source_id => 'IM_002765',
       data  => <<EOF,
userdel	q4; 9607,13507 9281,13374
EOF
     },
     { from  => 1147989600, # 2006-05-19 00:00
       until => 1148248800, # 2006-05-22 00:00
       text  => 'L 079 Ludwigsfelde-Ahrensdorf zw. Ludwigsfelde und Ahrensdorf Straßenbauarbeiten Vollsperrung 20.05.2006-21.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -2086,-9891 -1245,-9999 -862,-9933
EOF
     },
     { from  => 1147845153, # 2006-05-17 07:52
       until => 1147888800, # 2006-05-17 20:00
       text  => 'Anklamer Str. (Mitte) in beiden Richtungen, zwischen Ackerstraße und Strelitzer Straße Veranstaltung, Straße vollständig gesperrt (bis 17.5.2006, 20.00 Uhr)',
       type  => 'gesperrt',
       source_id => 'IM_002793',
       data  => <<EOF,
userdel	2 9628,14215 9801,14288
EOF
     },
     { from  => 1147838400, # 2006-05-17 06:00
       until => 1148205600, # 2006-05-21 12:00
       text  => 'Straße am Nordbahnhof zwischen Invalidenstraße und Zinnowitzer Veranstaltung, Straße gesperrt. Dauer: 18.05.2006, 06:00 Uhr bis 21.05.2006 12:00 Uhr. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 9076,13915 9006,14005
EOF
     },
     { from  => 1148162400, # 2006-05-21 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'L 011 Perleberger Chaussee zw. Weisen, Walhausstr. u. Wittenberge, Kyritzer Str. Straßenausbau Vollsperrung 22.05.2006-30.09.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -102390,65175 -102434,66177
EOF
     },
     { from  => 1131836400, # 2005-11-13 00:00
       until => 1151012746, # 2006-07-01 00:00 1151704800
       text  => 'L 372 Gubener Str. südl. Eisenhüttenstadt, Kreuzung Schrabisch Mühle Bau Kreisverkehr Vollsperrung 14.11.2005-30.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 95351,-29486 95494,-29935 95829,-31753
EOF
     },
     { from  => 1147989600, # 2006-05-19 00:00
       until => 1148162400, # 2006-05-21 00:00
       text  => 'B 246 Trebbin-Beelitz OD Löwendorf, zw. Ahrensdorfer Str. u. Schillerstr. Deckeneinbau Vollsperrung 20.05.2006-20.05.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -2643,-21212 -2815,-20920
EOF
     },
     { from  => 1148113240, # 2006-05-20 10:20
       until => 1148248800, # 2006-05-22 00:00
       text  => 'Herrmannstr. (Neukölln) in beiden Richtungen zwischen Werbellinstr. und Thomasstr. Veranstaltung, Straße vollständig gesperrt (bis 21.05.2006 24 Uhr)',
       type  => 'gesperrt',
       source_id => 'IM_002798',
       data  => <<EOF,
userdel	2 11979,8014 11998,7948 12025,7852 12041,7788 12055,7751 12075,7696 12090,7651 12122,7553 12180,7387
EOF
     },
     { from  => 1148565600, # 2006-05-25 16:00
       until => 1153087200, # 2006-07-17 00:00
       text  => 'Vom 26.05.2006, 16:00 Uhr bis 16.07.2006 wird die Straße des 17. Juni zwischen Siegessäule und Brandenburger Tor komplett gesperrt. Grund sind die geplante WM-Fanmeile sowie mehrere Festveranstaltungen (u.a. Love Parade).',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8515,12242 8214,12205 8089,12186
userdel	2 8063,12182 7816,12150 7383,12095 6828,12031
userdel auto	3 7460,12054 7383,12095 7039,12314
userdel auto	3 7039,12314 7383,12095 7460,12054
userdel	3 8119,12414 8063,12182 8034,12093
userdel	3 8034,12093 8063,12182 8119,12414
EOF
     },
     { from  => 1148623200, # 2006-05-26 08:00
       until => 1148767200, # 2006-05-28 00:00
       text  => 'Mögliche Behinderungen wegen eines Flugspektakels am Flughafen Tempelhof, 27.5. von 8 bis 24 Uhr ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 10213,8665 9801,8683 9571,8706 9395,8726 9364,8640 9321,8607 9224,8584
userdel	q4 9395,8726 9303,8781 9222,8787 9221,8732 9224,8584 9223,8409 9224,8254 9229,8029 9227,7797 9231,7657 9236,7324 9234,7287 9235,7146
userdel auto	3 9227,8890 9222,8787 9050,8783
userdel auto	3 9050,8783 9222,8787 9227,8890
EOF
     },
     { from  => 1148767200, # 2006-05-28 00:00
       until => 1150754400, # 2006-06-20 00:00
       text  => 'B 179 Spreewaldstr. OD Zeesen, Einmünd. zur K.-Liebknecht-Str. Umbau Knotenpunkt Vollsperrung 29.05.2006-19.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26758,-15727 26699,-15709 26583,-15677
EOF
     },
     { from  => 1148853600, # 2006-05-29 00:00
       until => 1154383200, # 2006-08-01 00:00
       text  => 'L 074 Märkisch Buchholz-Halbe-Teupitz OD Märkisch Buchholz, Schützenst. Straßenbau Vollsperrung 30.05.2006-31.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 35518,-32837 35641,-32578
EOF
     },
     { from  => 1148759377, # 2006-05-27 21:49
       until => 1153087200, # 2006-07-17 00:00
       text  => 'Heinrich-von-Gagern-Str. (Tiergarten) in beiden Richtungen Veranstaltung, Straße vollständig gesperrt (im Zuge der Fußball-WM) (bis 16.07.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002823',
       data  => <<EOF,
userdel	2 8119,12414 8122,12600
EOF
     },
     { from  => 1148937489, # 2006-05-29 23:18
       until => 1149372000, # 2006-06-04 00:00
       text  => 'Jannowitzbrücke (Mitte) in beiden Richtungen vollständig gesperrt (bis 03.06.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002820',
       data  => <<EOF,
userdel	2 11347,12181 11328,12040
EOF
     },
     { from  => 1149058136, # 2006-05-31 08:48
       until => 1149285600, # 2006-06-03 00:00
       text  => 'Ebertstr. (Mitte) in beiden Richtungen zwischen Lenéstr. und Behrenstr. Veranstaltung, Straße vollständig gesperrt (bis 02.06.06. 6 Uhr)',
       type  => 'handicap',
       source_id => 'IM_002840',
       data  => <<EOF,
userdel	q4 8595,12066 8581,11896 8571,11846
EOF
     },
     { from  => 1149230977, # 2006-06-02 08:49
       until => 1149544800, # 2006-06-06 00:00
       text  => 'Blücherstr., Zossnerstr., Waterlooufer rund um den Blücherplatz Veranstaltung, Straßen vollständig gesperrt (bis 05.06.06)',
       type  => 'gesperrt',
       source_id => 'IM_002848',
       data  => <<EOF,
userdel	2 9522,10017 9444,10000
userdel	2 9811,10055 9522,10017 9536,10064 9579,10122 9592,10174 9812,10211 9851,10219
userdel	2 9401,10199 9592,10174
userdel	2 9579,10122 9689,10124
userdel	2 9811,10055 9827,10120 9849,10202 9851,10219
EOF
     },
     { from  => 1149229271, # 2006-06-02 08:21
       until => 1151704800, # 2006-07-01 00:00
       text  => 'Hindenburgdamm (Steglitz) in beiden Richtungen, in Höhe Wolfensteindamm Baustelle, Straße vollständig gesperrt (bis 30.06.06)',
       type  => 'gesperrt',
       source_id => 'IM_002804',
       data  => <<EOF,
userdel	2 4517,4853 4515,4966
EOF
     },
     { from  => 1149458400, # 2006-06-05 00:00
       until => 1152914400, # 2006-07-15 00:00
       text  => 'B 167 Neustädter Str. OD Neuruppin, zw. Damaschkeweg u. Zufahrt Lidl Straßen-u.Kanalbau,Mittelinsel Vollsperrung 06.06.2006-14.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -32062,56731 -33038,55844
EOF
     },
     { from  => 1149631200, # 2006-06-07 00:00
       until => 1150063200, # 2006-06-12 00:00
       text  => 'B 246 Fünfeichen-Grunow OL Bremsdorf, Str. der Jugend Einbau Deckschicht Vollsperrung 08.06.2006-11.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 84903,-28417 83882,-28424
EOF
     },
     { from  => 1149544800, # 2006-06-06 00:00
       until => 1164927600, # 2006-12-01 00:00
       text  => 'L 338 Rahnsdorfer Str. OD Schöneiche, Brücke über Jägergraben Brückenneubau Vollsperrung 07.06.2006-30.11.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 30221,7373 30118,8128
EOF
     },
     { from  => 1150581600, # 2006-06-18 00:00
       until => 1155333600, # 2006-08-12 00:00
       text  => 'L 074 Chausseestraße OL Wünsdorf, zw. Cottbusser/Berliner Str. u. Seestr. Kanalverlegung Vollsperrung 19.06.2006-11.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 15960,-26906 15682,-26971 15229,-27157
EOF
     },
     { from  => 1149623437, # 2006-06-06 21:50
       until => 1151100000, # 2006-06-24 00:00
       text  => 'Londoner Str. (Wedding) Richtung Holländerstr. zwischen Müllerstr. und Holländerstr. Baustelle, Fahrtrichtung gesperrt (bis 23.06.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_83663',
       data  => <<EOF,
userdel	2 5791,16910 6042,17189 6118,17327 6154,17438
EOF
     },
     { from  => 1149976800, # 2006-06-11 00:00
       until => 1151186400, # 2006-06-25 00:00
       text  => 'B 156 OL Spremberg, Muskauer Straße OL Spremberg, Muskauer Str., Bahnübergang Sanierung BÜ u. Tiefbau Vollsperrung 12.06.2006-24.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 80783,-91972 80236,-92007
EOF
     },
     { from  => 1146898800, # 2006-05-06 09:00
       until => 1152913500, # 2006-07-14 23:45
       text  => 'Reinhardtstraße - Otto-von-Bismarck-Allee: zwischen Kreuzung Kapelleufer und Kreuzung Willy-Brandt-Straße in beiden Richtungen Veranstaltung, gesperrt, Dauer: 07.05.2006 09:00 Uhr bis 14.07.2006 23:45 Uhr ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8124,12742 8218,12742 8275,12742 8308,12742 8417,12846 8503,12895
EOF
     },
     { from  => 1149703449, # 2006-06-07 20:04
       until => 1152914400, # 2006-07-15 00:00
       text  => 'Regierungsviertel: im Zuge der Fußball-WM mehrere Straßen gesperrt (bis 14.07.2006)',
       type  => 'gesperrt',
       source_id => 'IM_002870',
       data  => <<EOF,
userdel	2 8168,12848 8209,12816 8218,12742 8218,12601
userdel	2 8775,12457 8540,12420 8400,12417 8374,12416 8119,12414
userdel	2 8032,12817 8124,12840
userdel	2 8307,12601 8308,12742
userdel	2 8032,12817 8017,12826
EOF
     },
     { from  => 1149703543, # 2006-06-07 20:05
       until => 1152914400, # 2006-07-15 00:00
       text  => 'John-Foster-Dulles-Allee (Tiergarten) in beiden Richtungen zwischen Yitzhak-Rabin-Str. und Spreeweg Straße vollständig gesperrt, Veranstaltung (im Zuge der WM 2006 bis 14.07.06)',
       type  => 'gesperrt',
       source_id => 'IM_002839',
       data  => <<EOF,
userdel	2 8119,12414 8017,12359 7875,12363 7437,12368 7215,12295 7039,12314
EOF
     },
     { from  => 1149976800, # 2006-06-11 00:00
       until => 1151100000, # 2006-06-24 00:00
       text  => 'B 101 OL Luckenwalde, Zinnaer Straße OL Luckenwalde, Zinnaer Str. zw. Mühlenweg u. Am Nuth: Vollsperrung 12.06.2006-23.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -4630,-36012 -4603,-35730
EOF
     },
     { from  => 1150581600, # 2006-06-18 00:00
       until => 1151791200, # 2006-07-02 00:00
       text  => 'L 099 Barnewitz - Marzahne zw. Abzw. Gortz (L911) in OL Barnewitz u. L98 in OL Marzahne Straßenbau Vollsperrung 19.06.2006-01.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -46651,12935 -45980,13284
EOF
     },
     { from  => 1152568800, # 2006-07-11 00:00
       until => 1164927600, # 2006-12-01 00:00
       text  => 'L 601 Leipziger Str. OD Finsterwalde, Kno. Hain-/ Schützenstr. Kanalarbeiten Vollsperrung 12.07.2006-30.11.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32963,-85912 32865,-86269 32870,-86323 32478,-86374
EOF
     },
     { from  => 1149544800, # 2006-06-06 00:00
       until => 1152482399, # 2006-07-09 23:59
       text  => 'Fan-Fest der FIFA im Tiergarten, 7. Juni 2006 - 9. Juli 2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8021,11636 8006,11766 8172,11679
userdel	2 7816,12150 7875,12363
userdel	2 7504,11504 7382,11588 7163,11738 7287,11763 7535,11677 7591,11639 7669,11586 7706,11612 7742,11639 7852,11721 8006,11766
userdel	2 7669,11586 7711,11558
userdel	2 8022,12016 8006,11766 7811,11868 7663,11946 7570,11855 7223,11897 7073,11798 7163,11738 6980,11583 6809,11570
userdel	2 7039,12314 7383,12095
userdel	2 7073,11798 6778,11742
userdel	2 8374,12416 8539,12286
userdel	2 7382,11588 7354,11513
userdel	2 6809,11979 7073,11798
userdel	2 8223,11700 8220,11844 8215,12156 8214,12205
userdel	2 8119,12414 8063,12182
userdel	2 8063,12182 8034,12093 8006,12074 7999,12049 8022,12016
userdel	2 8540,12420 8560,12326 8539,12286 8515,12242 8600,12165 8595,12066
userdel	2 8595,12066 8581,11896 8571,11846
EOF
     },
     { from  => undef, # 
       until => 1149833870, # XXX undef
       text  => 'Veitstr. (Tegel) in beiden Richtungen zwischen Medebacher Weg und Treskowstr. Wasserrohrbruch, Baustelle, Straße vollständig gesperrt (Dauer: mehrere Tage)',
       type  => 'gesperrt',
       source_id => 'IM_002880',
       data  => <<EOF,
userdel	2 2064,19874 1886,19835
EOF
     },
     { from  => 1149834073, # 2006-06-09 08:21
       until => 1150063200, # 2006-06-12 00:00
       text  => 'Müllerstr. (Wedding) in beiden Richtungen zwischen Seestr. und Leopoldplatz Veranstaltung, Straße vollständig gesperrt (bis 11.06.06)',
       type  => 'gesperrt',
       source_id => 'IM_002867',
       data  => <<EOF,
userdel	2 6790,16018 6914,15908 6957,15869 7043,15793 7198,15656 7288,15579
EOF
     },
     { from  => 1150581600, # 2006-06-18 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'K 6162 OL Waltersdorf, Siedlung Kienberg, Bau der BAB 113n, Vollsperrung 19.06.2006-30.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 20575,-3680 20265,-3849
EOF
     },
     { from  => 1150395890, # 2006-06-15 20:24
       until => 1150754400, # 2006-06-20 00:00
       text  => 'Altstadt Köpenick: Köpenicker Sommer, Verkehrsbehinderung erwartet (bis 19.06.2006)',
       type  => 'handicap',
       source_id => 'IM_002922',
       data  => <<EOF,
userdel	q4 22439,4838 22445,4758 22381,4752 22377,4836 22196,4847 22138,4661 22111,4562 22162,4546 22312,4593 22358,4521
userdel	q4 22111,4562 22093,4499
userdel	q4 22445,4758 22449,4712 22383,4703 22312,4593 22263,4671 22243,4710 22234,4789
userdel	q4 22147,4831 22043,4562 22071,4501
userdel	q4 22381,4752 22383,4703
EOF
     },
     { from  => 1151532000, # 2006-06-29 00:00
       until => 1152050400, # 2006-07-05 00:00
       text  => 'B 246 OL Bestensee, Hauptstraße OL Bestensee, Hauptstraße, Bahnübergang Bauarbeiten am Gleiskörper Vollsperrung 30.06.2006-04.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26639,-17861 26752,-17872 26832,-17882
EOF
     },
     { from  => 1150840800, # 2006-06-21 00:00
       until => 1160949600, # 2006-10-16 00:00
       text  => 'K 6828 L 164 Altfriesack-Wuthenow OT Seehof, Dorfstr. Kanalarbeiten Vollsperrung 22.06.2006-15.10.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -28368,51517 -28736,52387
EOF
     },
     { from  => 1151618400, # 2006-06-30 00:00
       until => 1151877600, # 2006-07-03 00:00
       text  => 'K 7221 Woltersdorf-Liebätz Einmündung zur K7220 (Ruhldorf-Liebätz) Straßen- u. Radwegebau Vollsperrung 01.07.2006-02.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3584,-29888 -3733,-29501
EOF
     },
     { from  => 1151609302, # 2006-06-29 21:28
       until => 1157061600, # 2006-09-01 00:00
       text  => 'Bis 31.08.2006 Vollsperrung der L 862 zwischen Falkenrehde und Ketzin. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -22215,9500 -22510,9372 -23467,9217 -23807,9279 -24319,9296 -24594,9168 -25265,9000 -25456,8850 -25658,8777 -26243,8485 -26774,7951 -27468,7711
EOF
     },
     { from  => 1150916248, # 2006-06-21 20:57
       until => 1159653599, # 2006-09-30 23:59
       text  => 'Schulzendorfer Str. (Reinickendorf) in beiden Richtungen zwischen Damkitzstr. und Ruppiner Chaussee Baustelle, Straße vollständig gesperrt (bis Ende 09.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_82301_COPY_1',
       data  => <<EOF,
userdel	2 -862,22946 -596,23009
EOF
     },
     { from  => 1149976800, # 2006-06-11 00:00
       until => 1151618400, # 2006-06-30 00:00
       text  => 'B 156 Muskauer Straße Bahnübergang in der OL Spremberg Sanierung BÜ u. Tiefbau Vollsperrung 12.06.2006-29.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 80783,-91972 80236,-92007
EOF
     },
     { from  => 1150840800, # 2006-06-21 00:00
       until => 1151013600, # 2006-06-23 00:00
       text  => 'B 158 bei Schiffmühle, Brücke über Alte Oder Rückbauarb., Herstell. M.insel Vollsperrung * 22.06.2006-22.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 53350,45087 53293,45400
EOF
     },
     { from  => 1152050400, # 2006-07-05 00:00
       until => 1156024800, # 2006-08-20 00:00
       text  => 'K 6503 B273-Zühlsdorf-L211 (Summt-Lehnitz) Kreuzung. Summter Chaussee bei Zühlslake Neubau Kreisverkehr Vollsperrung 06.07.2006-19.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 7346,32257 7435,34963 8115,35387
userdel	q4 7070,34665 7435,34963 7443,36175
EOF
     },
     { from  => 1149026400, # 2006-05-31 00:00
       until => 1157061600, # 2006-09-01 00:00
       text  => 'L 010 Havelberger Str. OD Bad Wilsnack, vom OE bis An der Trift Kanal- und Straßenbau Vollsperrung 01.06.2006-31.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -89549,58784 -89647,59213
EOF
     },
     { from  => 1150754400, # 2006-06-20 00:00
       until => 1157061600, # 2006-09-01 00:00
       text  => 'L 011 Große Str. OD Bad Wilsnack, Einmünd. zur Havelberger Str. Kanal- und Straßenbau Vollsperrung 21.06.2006-31.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -89647,59213 -89606,59341
EOF
     },
     { from  => 1151013248, # 2006-06-22 23:54
       until => 1188597599, # 2007-08-31 23:59
       text  => 'Askanierring (Spandau) in Richtung Hohenzollernring, zwischen Eckschanze und Fehrbelliner Tor Baustelle, Fahrtrichtung gesperrt (bis Ende 08/2007)',
       type  => 'gesperrt',
       source_id => 'INKO_82715',
       data  => <<EOF,
userdel	1 -3972,15639 -3985,15770 -3735,16205 -3631,16224
EOF
     },
     { from  => 1150840800, # 2006-06-21 00:00
       until => 1151704800, # 2006-07-01 00:00
       text  => 'L 211 Lehnitzer Str. OD Oanienburg, zw. Lindenring u. Dr.-H.-Byk-Str. Munitionssuche u.-bergung halbseitig gesperrt; Einbahnstraße 22.06.2006-30.06.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -954,38397 -591,37970
EOF
     },
     { from  => 1151042079, # 2006-06-23 07:54
       until => 1151272800, # 2006-06-26 00:00
       text  => 'Turmstr. zwischen Stromstr. und Waldstr. Veranstaltung, Straße vollständig gesperrt (bis 25.06.06, 24:00 Uhr)',
       type  => 'gesperrt',
       source_id => 'IM_002950',
       data  => <<EOF,
userdel	2 6249,13322 6112,13327 6011,13330 5956,13330 5857,13342 5705,13359 5560,13382 5368,13406
EOF
     },
     { from  => 1151099435, # 2006-06-23 23:50
       until => 1151290800, # 2006-06-26 05:00
       text  => 'Dörpfeldstr., Ottomar-Geschke-Str. (Treptow) in beiden Richtungen,zwischen Waldstr. und Oberspreestr. Baustelle, Straße vollständig gesperrt (bis 26.06.06, 05.00 Uhr)',
       type  => 'gesperrt',
       source_id => 'INKO_64281_COPY_1',
       data  => <<EOF,
userdel	2 20692,3951 21100,4192 21174,4250 21182,4336 21332,4655
EOF
     },
     { from  => 1151101431, # 2006-06-24 00:23
       until => 1155679199, # 2006-08-15 23:59
       text  => 'Corinthstr. - Markgrafendamm: wegen einer Baustelle kann nur der Gehweg genutzt werden (bis Mitte 08.2006)',
       type  => 'handicap',
       source_id => 'INKO_77040_COPY_1',
       data  => <<EOF,
userdel	q4 14439,10496 14608,10409
EOF
     },
     { from  => 1150754400, # 2006-06-20 00:00
       until => 1151359200, # 2006-06-27 00:00
       text  => 'B 002 Eberswalder Str. Bahnübergang in OL Melchow Umbau Bahnübergang Vollsperrung 21.06.2006-26.06.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 30143,41500 29468,41438
EOF
     },
     { from  => 1152050400, # 2006-07-05 00:00
       until => 1156024800, # 2006-08-20 00:00
       text  => 'L 235 Gielsdorf-Werneuchen Schulstr. in der OL Wegendorf Straßen- u. Durchlassbau Vollsperrung; 06.07.2006-19.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 34492,22176 34321,22151 34125,22128
EOF
     },
     { from  => 1151791200, # 2006-07-02 00:00
       until => 1151964000, # 2006-07-04 00:00
       text  => 'B 183 Dresdner Str. OL Bad Liebenwerda, zw. Querspange u. Hainsche Str. Untersuchung Lubwartturm Vollsperrung 03.07.2006-03.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 12194,-98944 12593,-99029
EOF
     },
     { from  => 1152050400, # 2006-07-05 00:00
       until => 1152655200, # 2006-07-12 00:00
       text  => 'L 711 Buckow-Wahlsdorf zw. Wahlsdorf und Liepe Deckenerneuerung Vollsperrung 06.07.2006-11.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 8810,-50414 6695,-50057
EOF
     },
     { from  => 1153432800, # 2006-07-21 00:00
       until => 1153692000, # 2006-07-24 00:00
       text  => 'L 060 Marktplatz (Zentrum) OL Uebigau, zw. Elsterstr. u. Kreuzstr. Altstadtfest Vollsperrung 22.07.2006-23.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 5798,-90075 5358,-90502
EOF
     },
     { from  => 1151877600, # 2006-07-03 00:00
       until => 1152050400, # 2006-07-05 00:00
       text  => 'L 220 B167 Finowfurt-Joachimsthal zw. Eichhorst und Elsenau Baumfällungen Vollsperrung 04.07.2006-04.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 29884,58862 30384,59443
EOF
     },
     { from  => 1151618400, # 2006-06-30 00:00
       until => 1151877600, # 2006-07-03 00:00
       text  => 'K 7220 Luckenwalde-Liebätz zw. Ruhlsdorf und Liebätz Deckeneinbau Vollsperrung 01.07.2006-02.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3607,-29164 -3733,-29501
EOF
     },
     { from  => 1152050400, # 2006-07-05 00:00
       until => 1156024800, # 2006-08-20 00:00
       text  => 'L 079 Ludwigsfelde-Potsdam Höhe Ahrensdorf bis Kreisverk. Nudow Straßenbauarbeiten Vollsperrung 06.07.2006-19.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -3618,-9791 -4050,-9464 -4422,-9151 -4649,-8996
EOF
     },
     { from  => 1151917200, # 2006-07-03 11:00
       until => 1152061200, # 2006-07-05 03:00
       text  => 'Der große Stern wird zu den Halbfinalspielen am 4.7.2006 von 11.00 Uhr bis zum 5.7.2006 03.00 Uhr gesperrt. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6653,12067 6642,12010 6685,11954 6744,11936 6809,11979 6828,12031 6799,12083 6754,12108 6725,12113 6690,12104
EOF
     },
     { from  => 1152234000, # 2006-07-07 03:00
       until => 1152504000, # 2006-07-10 06:00
       text  => 'Der große Stern wird zu den Finalspielen am 8.7.2006 von 03.00 Uhr bis zum 10.7.2006 06.00 Uhr gesperrt. ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 6653,12067 6642,12010 6685,11954 6744,11936 6809,11979 6828,12031 6799,12083 6754,12108 6725,12113 6690,12104
userdel	2 6540,11754 6685,11954
userdel	2 6825,11486 6809,11570 6778,11742 6744,11936
userdel	2 6653,12067 6178,12387
userdel	2 5901,11902 6642,12010
userdel	2 7039,12314 6799,12083
EOF
     },
     { from  => 1151965861, # 2006-07-04 00:31
       until => 1153346400, # 2006-07-20 00:00
       text  => 'Bäkestr. (Steglitz) in beiden Richtungen, zwischen Ostpreußendamm und Hindenburgdamm Baustelle, Straße vollständig gesperrt (bis 19.07.06)',
       type  => 'gesperrt',
       source_id => 'IM_003018',
       data  => <<EOF,
userdel	2 4409,3173 4582,3076 4643,3046 4825,2958
EOF
     },
     { from  => 1152396000, # 2006-07-09 00:00
       until => 1153740281, # 2006-08-20 00:00 1156024800
       text  => 'L 362 Bergmannstr. OD Müncheberg, zw. Seelower Str. u. Marienfeld Instandsetzung Durchlass Vollsperrung 10.07.2006-19.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 61069,13387 61181,12075
EOF
     },
     { from  => 1152221102, # 2006-07-06 23:25
       until => 1156975200, # 2006-08-31 00:00
       text  => 'Pistoriusstr. (Pankow) in Richtung Berliner Allee, zwischen Roelckstr. und Mirbachplatz Baustelle, Straße vollständig gesperrt (bis 30.08.06)',
       type  => 'handicap',
       source_id => 'INKO_77721_COPY_1',
       data  => <<EOF,
userdel	q4; 13131,16525 13386,16408
EOF
     },
     { from  => 1153000800, # 2006-07-16 00:00
       until => 1167606000, # 2007-01-01 00:00
       text  => 'K 6413 Berliner Str. OL Buckow, zw. Hauptstr. und OA grundhafter Straßenbau Vollsperrung 17.07.2006-31.12.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 55988,18385 55623,17923 55217,17672
EOF
     },
     { from  => 1152568800, # 2006-07-11 00:00
       until => 1152914400, # 2006-07-15 00:00
       text  => 'K 6413 Berliner Str. OL Buckow, zw. Nr. 60 und Waldweg grundhafter Straßenbau Vollsperrung; Umleitung 12.07.2006-14.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 55988,18385 55623,17923 55217,17672
EOF
     },
     { from  => 1152568800, # 2006-07-11 00:00
       until => 1156975200, # 2006-08-31 00:00
       text  => 'L 029 Bahnhofstr. Bahnübergang in Biesenthal Umbau Bahnübergang Vollsperrung 12.07.2006-30.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 28993,38709 28262,39100 26237,40190
EOF
     },
     { from  => 1152223200, # 2006-07-07 00:00
       until => 1152655200, # 2006-07-12 00:00
       text  => 'L 171 Karl-Marx-Str. OD Hohen Neuendorf, Kno.K.-Tucholsky-Str. Straßensanierung halbseitig gesperrt; Einbahnstraße 08.07.2006-11.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 1379,29410 1611,29359
EOF
     },
     { from  => 1152828000, # 2006-07-14 00:00
       until => 1153000800, # 2006-07-16 00:00
       text  => 'B 102 Große Milower Str. OD Rathenow, zw. Eigendorfstr. u. Grünauer Weg Neub. B188n, Mont. Stahlträger Vollsperrung 15.07.2006-15.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -62333,20390 -62269,19881 -62153,19281
EOF
     },
     { from  => 1152396000, # 2006-07-09 00:00
       until => 1160949600, # 2006-10-16 00:00
       text  => 'L 019 Ruppiner Chaussee OD Kremmen grundhafter Straßenbau Vollsperrung 10.07.2006-15.10.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -15770,39361 -15556,39597 -15170,39685 -14871,40028
EOF
     },
     { from  => 1152396000, # 2006-07-09 00:00
       until => 1153000800, # 2006-07-16 00:00
       text  => 'L 099 zw. Abzw. Gortz (L911) in OL Barnewitz u. Marzahne Straßenbau Vollsperrung 10.07.2006-15.07.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -48510,11216 -48001,11540 -47603,12203 -47031,12527 -46651,12935 -45980,13284 -45617,13395 -44599,14084 -44292,14733 -44020,15116 -43321,16508
EOF
     },
     { from  => 1152396000, # 2006-07-09 00:00
       until => 1155938400, # 2006-08-19 00:00
       text  => 'L 743 Motzener Str. OD Bestensee, Durchlass Ersatzneubau Durchlass Vollsperrung 10.07.2006-18.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 26639,-17861 26650,-18150 26437,-18650 26343,-18775 25475,-19231
EOF
     },
     { from  => 1152312770, # 2006-07-08 00:52
       until => 1162335600, # 2006-11-01 00:00
       text  => 'Neue Bahnhofstr. Richtung Süden ab Oderstr. gesperrt, voraussichtlich bis Oktober 2006',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 15091,11596 15043,11511 15008,11436 14912,11252
EOF
     },
     { from  => 1152228595, # 2006-07-07 01:29
       until => 1167606000, # 2007-01-01 00:00
       text  => 'Luisenhain ist gesperrt, Umgestaltung bis 2007',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 22196,4847 22147,4831 22043,4562 22071,4501
EOF
     },
     { from  => 1152363677, # 2006-07-08 15:01
       until => 1158357599, # 2006-09-15 23:59
       text  => 'Simon-Dach-Str.: Bauarbeiten an der Wühlischstr., Einbahnstraße, bis 2006-09-15 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	1 13890,11411 13954,11647
EOF
     },
     { from  => 1152363870, # 2006-07-08 15:04
       until => 1167605999, # 2006-12-31 23:59
       text  => 'Neubau der Treptower Straße in Neukölln, Sperrung zwischen Kiefholzstraße und Heidelberger Straße (Anliegerverkehr ist frei) (bis Ende 2006) ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 13857,8601 13982,8764 14015,8798 14140,8977
EOF
     },
     { from  => 1153955394, # 2006-07-27 01:09
       until => 1154124000, # 2006-07-29 00:00
       text  => 'Buschallee (Weißensee) in Richtung Hansastr., zwischen Berliner Allee und Hansastr. Baustelle, Straße vollständig gesperrt (bis 28.07.06)',
       type  => 'gesperrt',
       source_id => 'INKO_84063',
       data  => <<EOF,
userdel	1 14621,16563 15121,16503 15388,16502
EOF
     },
     { from  => 1152566231, # 2006-07-10 23:17
       until => 1153860384, # 2006-07-31 23:59 1154383199
       text  => 'Wilhelminenhofstr. (Treptow) Richtung Rathenaustr. zwischen Edisonstr. und Schillerpromenade Baustelle, Fahrtrichtung gesperrt (bis Ende 07.2006)',
       type  => 'handicap',
       source_id => 'INKO_84075',
       data  => <<EOF,
userdel	q4; 18175,6376 18445,6287 18853,6009
EOF
     },
     { from  => 1154642400, # 2006-08-04 00:00
       until => 1154901600, # 2006-08-07 00:00
       text  => 'L 023 Storkow-Grünheide Brücke über die Müggelspree bei Neuhartmannsdorf Asphaltarbeiten Vollsperrung 05.08.2006-06.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 40333,-4484 40503,-4571 40652,-4743
EOF
     },
     { from  => 1153738184, # 2006-07-24 12:49
       until => 1159653599, # 2006-09-30 23:59
       text  => 'Bergstr. (Steglitz) Richtung Bismarckstr. zwischen Menckenstr. und Körnerstr. Baustelle, Fahrtrichtung gesperrt, eine Umleitung ist eingerichtet (bis Ende 09.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_84234_COPY_14',
       data  => <<EOF,
userdel	1 5481,5721 5601,5732
EOF
     },
     { from  => 1153738269, # 2006-07-24 12:51
       until => 1156197600, # 2006-08-22 00:00
       text  => 'Gartenstr. (Wedding) in Richtung Invalidenstr., zwischen Bernauer Str. und Invalidenstr. Baustelle, Straße vollständig gesperrt (bis 21.08.06)',
       type  => 'gesperrt',
       source_id => 'INKO_83906_COPY_1',
       data  => <<EOF,
userdel	1 9224,14169 9383,13978
EOF
     },
     { from  => 1153739381, # 2006-07-24 13:09
       until => 1157061599, # 2006-08-31 23:59
       text  => 'Lützowplatz (Mitte) in beiden Richtunen zwischen Einemstr. und Lützowufer Baustelle, Straße vollständig gesperrt (bis Ende 08.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_84233_COPY_14',
       data  => <<EOF,
userdel	2 7002,11034 7010,11002 6918,10854
EOF
     },
     { from  => 1153739453, # 2006-07-24 13:10
       until => 1154383199, # 2006-07-31 23:59
       text  => 'Rosestr., Germanenstr. (Treptow) An der Kreuzung Baustelle, Rosestraße vollständig gesperrt, Germaenstr. teilweise gesperrt (bis Ende 07.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_84204',
       data  => <<EOF,
userdel	2 21350,852 21202,727 21164,697 21089,639
EOF
     },
     { from  => 1153346400, # 2006-07-20 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'B 096 Gransee-Fürstenberg OD Dannenwalde grundhafter Straßenbau Vollsperrung 21.07.2006-30.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -5962,74421 -5737,74650
EOF
     },
     { from  => 1153000800, # 2006-07-16 00:00
       until => 1155333600, # 2006-08-12 00:00
       text  => 'B 167 Eisenbahnstr./ Wilhelmstr. OL Eberswalde, Wilhelmbrücke Fahrbahnsanierung 17.07.2006-11.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 37875,48253 37532,48149
EOF
     },
     { from  => 1153000800, # 2006-07-16 00:00
       until => 1164927600, # 2006-12-01 00:00
       text  => 'K 6425 Rudolf-Breitscheid-Allee OD Neuenhagen, zw. Am Friedhof u. Krz. Hönower Chaussee Straßen- uned Gehwegbau halbseitig gesperrt; Einbahnstraße 17.07.2006-30.11.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 29743,14143 29093,13456
EOF
     },
     { from  => 1152482400, # 2006-07-10 00:00
       until => 1160172000, # 2006-10-07 00:00
       text  => 'L 098 Marzahne-Rathenow Brandenburger Str. in OL Mützlitz Kanal- und Straßenbau Vollsperrung 11.07.2006-06.10.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -50268,15901 -50493,15837 -50578,15920
EOF
     },
     { from  => 1153173600, # 2006-07-18 00:00
       until => 1154296800, # 2006-07-31 00:00
       text  => 'L 362 Müncheberg-Wulkow OD Obersdorf Kanal- u. Straßenbau Vollsperrung 19.07.2006-30.07.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 62444,15991 62380,16226 62104,16631
EOF
     },
     { from  => 1156370400, # 2006-08-24 00:00
       until => 1156802400, # 2006-08-29 00:00
       text  => 'L 601 Berliner Str. OL Finsterwalde Sängerfest Vollsperrung 25.08.2006-28.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 33060,-85292 33103,-85731
EOF
     },
     { from  => 1153805975, # 2006-07-25 07:39
       until => 1162335599, # 2006-10-31 23:59
       text  => 'Quitzowstr. (Tiergarten) Richtung Putlitzstr. zwischen Rathenower Str. und Havelberger Str. Baustelle, Fahrtrichtung gesperrt (bis Ende 10.2006)',
       type  => 'handicap',
       source_id => 'INKO_82304',
       data  => <<EOF,
userdel	q4; 6670,14302 6482,14264
EOF
     },
     { from  => 1153860291, # 2006-07-25 22:44
       until => 1157061599, # 2006-08-31 23:59
       text  => 'Ringstr. (Lichterfelde) Richtung Carstennstr. zwischen Lotzestr. und Finckensteinallee Baustelle, Fahrtrichtung gesperrt (bis Ende 08.2006)',
       type  => 'gesperrt',
       source_id => 'IM_003129',
       data  => <<EOF,
userdel	1 2639,2989 2638,2843
EOF
     },
     { from  => 1153860349, # 2006-07-25 22:45
       until => 1159653600, # 2006-10-01 00:00
       text  => 'Ruschestr. (Lichtenberg) in Richtung Frankfurter Allee, zwischen Normannenstr. und Frankfurter Allee Baustelle, Straße vollständig gesperrt (bis 30.09.06)',
       type  => 'gesperrt',
       source_id => 'IM_003134',
       data  => <<EOF,
userdel	1 15904,12340 15863,11992
EOF
     },
     { from  => 1154210400, # 2006-07-30 00:00
       until => 1155333600, # 2006-08-12 00:00
       text  => 'L 015 B109 südl. Prenzlau-Boitzenburg OD Gollmitz Einbau Deckschicht Vollsperrung 31.07.2006-11.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 30743,99403 30504,99595
EOF
     },
     { from  => 1154038125, # 2006-07-28 00:08
       until => 1167605999, # 2006-12-31 23:59
       text  => 'Josef-Orlopp-Str. (Lichtenberg) Richtung Vulkanstr. zwischen Siegfriedstr. und Vulkanstr. Baustelle, Fahrtrichtung gesperrt (bis Ende 2006)',
       type  => 'gesperrt',
       source_id => 'INKO_81874_COPY_4',
       data  => <<EOF,
userdel	1 16863,13138 15912,13153
EOF
     },
     { from  => 1154210400, # 2006-07-30 00:00
       until => 1157234400, # 2006-09-03 00:00
       text  => 'L 035 Eisenbahnstr.-August-Bebel-Str. Brücke über die Spree in Fürstenwalde Deckenerneuerung halbseitig gesperrt; Einbahnstraße 31.07.2006-02.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4; 55549,-4992 55562,-4726
EOF
     },
     { from  => 1154642400, # 2006-08-04 00:00
       until => 1156629600, # 2006-08-27 00:00
       text  => 'L 063 Berliner Str. OL Lauchhammer, Höhe Bahnübergang Neugestaltung SGÜ Vollsperrung 05.08.2006-26.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 35482,-103562 35379,-103141 35072,-102150
EOF
     },
     { from  => 1154296800, # 2006-07-31 00:00
       until => 1157839200, # 2006-09-10 00:00
       text  => 'L 074 Kehrigk-Märkisch Buchholz OD Märkisch Buchholz, Friedrichstr. Straßenbau Vollsperrung 01.08.2006-09.09.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 36004,-32198 35916,-32601
EOF
     },
     { from  => 1154165181, # 2006-07-29 11:26
       until => 1154296800, # 2006-07-31 00:00
       text  => 'Rheinstr. (Schöneberg) in beiden Richtungen zwischen Saarstr. und Walter-Schreiber-Platz Veranstaltung, Straße vollständig gesperrt (bis 30.07.2006 nachts) ',
       type  => 'gesperrt',
       source_id => 'IM_003088',
       data  => <<EOF,
userdel	2 5370,6500 5424,6584 5533,6753 5654,6941
EOF
     },
     { from  => 1154203576, # 2006-07-29 22:06
       until => 1183240800, # 2007-07-01 00:00
       text  => 'Karl-Liebknecht-Str. (Mitte) in Richtung Spandauer Str., zwischen Memhardstr.. und Dircksenstr. Baustelle, Straße vollständig gesperrt. Ebenfalls Einbahnstraßen: Teile der Memhardstr. und Dircksenstr. (bis Juni 2007) ',
       type  => 'gesperrt',
       source_id => 'IM_003157',
       data  => <<EOF,
userdel	1 10920,13139 10781,13002
userdel	1 10755,13152 10920,13139
userdel	1 10781,13002 10706,13043
EOF
     },
     { from  => 1152568800, # 2006-07-11 00:00
       until => 1156024800, # 2006-08-20 00:00
       text  => ' L 601 Leipziger Str. OD Finsterwalde, Kno. Hain-/ Schützenstr. Kanalarbeiten Vollsperrung 12.07.2006-19.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 32963,-85912 32865,-86269 32870,-86323 32478,-86374
EOF
     },
     { from  => 1154556000, # 2006-08-03 00:00
       until => 1154815200, # 2006-08-06 00:00
       text  => 'B 107 zw. Tüchen und Mesendorf Vollsperrung 04.08.2006-05.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -79120,73107 -78454,74544
EOF
     },
     { from  => 1152396000, # 2006-07-09 00:00
       until => 1167606000, # 2007-01-01 00:00
       text  => 'K 6308 KG nördl. Bagow-L 91 westl.Nauen zw. OL Klein Behnitz und Groß Behnitz Straßenbauarbeiten Vollsperrung 10.07.2006-31.12.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -37075,16831 -37025,17462 -36787,18125
EOF
     },
     { from  => 1155420000, # 2006-08-13 00:00
       until => 1155938400, # 2006-08-19 00:00
       text  => 'L 059 Bormannstr. OL Bad Liebenwerda, zw. F.-Engels-Str. u. Stangengärtenstr. Kanalarbeiten Vollsperrung 14.08.2006-18.08.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 12571,-99519 12383,-99327 12173,-99115
EOF
     },
     { from  => 1154785716, # 2006-08-05 15:48
       until => 1159739999, # 2006-10-01 23:59
       text  => 'Grunerstr. (Mitte) stadtauswärts neben Tunnel Alexanderplatz Baustelle, Fahrtrichtung gesperrt (bis Anfang 10.2006)',
       type  => 'gesperrt',
       source_id => 'IM_003144',
       data  => <<EOF,
userdel	1 11323,12484 11209,12430 11092,12375 11056,12461 10954,12635
userdel	1 10954,12635 11057,12715 11134,12793
EOF
     },
     { from  => 1154786970, # 2006-08-05 16:09
       until => 1154988000, # 2006-08-08 00:00
       text  => 'Rixdorfer Str. (Treptow) in beiden Richtungen zwischen Südostallee und Schnellerstr. Baustelle, Straße vollständig gesperrt (bis 07.08.2006 5 Uhr)',
       type  => 'handicap',
       source_id => 'INKO_84352',
       data  => <<EOF,
userdel	q4 16861,5935 17156,6235 17239,6182 17290,6228
EOF
     },
     { from  => 1154876732, # 2006-08-06 17:05
       until => 1157061599, # 2006-08-31 23:59
       text  => 'Invalidenstr. in Richtung Tiergartentunnel, zwischen Ackerstr. und Bergstr. Baustelle, Fahrtrichtung gesperrt (bis Ende 08.2006)',
       type  => 'gesperrt',
       source_id => 'INKO_70880',
       data  => <<EOF,
userdel	1 9810,14066 9663,14036
EOF
     },
     { from  => 1154815200, # 2006-08-06 00:00
       until => 1164927600, # 2006-12-01 00:00
       text  => 'B 109 B167-Zehdenick OD Falkenthal grundhafter Straßenbau Vollsperrung 07.08.2006-30.11.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 2775,56089 2034,55227
EOF
     },
     { from  => 1155420000, # 2006-08-13 00:00
       until => 1170284400, # 2007-02-01 00:00
       text  => 'B 167 Friedrich-Engels-Str. OD Alt Ruppin, zw. Rhinbrücke u. Brückenstr. Straßenbauarbeiten Vollsperrung 14.08.2006-31.01.2007 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -28866,59954 -28692,59635
EOF
     },
     { from  => 1156975200, # 2006-08-31 00:00
       until => 1157320800, # 2006-09-04 00:00
       text  => 'B 167 Frankfurter Str. OL Seelow, zw. breite Str. u. Küstriner Str. Stadtfest Vollsperrung 01.09.2006-03.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 76771,15413 77081,14637
EOF
     },
     { from  => 1155765600, # 2006-08-17 00:00
       until => 1156197600, # 2006-08-22 00:00
       text  => 'B 005 Abzw. Groß Gottschow-OU Perleberg Bahnübergang bei Perleberg Gleissanierung Vollsperrung 18.08.2006-21.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -94722,72190 -94274,71791 -93406,71227
EOF
     },
     { from  => 1156111200, # 2006-08-21 00:00
       until => 1156370400, # 2006-08-24 00:00
       text  => 'B 005 Abzw. Groß Gottschow-OU Perleberg Bahnübergang bei Perleberg Gleissanierung Vollsperrung 22.08.2006-23.08.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -94722,72190 -94274,71791 -93406,71227
EOF
     },
     { from  => 1155664127, # 2006-08-15 19:48
       until => 1159653599, # 2006-09-30 23:59
       text  => 'Grünbergallee (Treptow) in beiden Richtungen zwischen Am Seegraben und Rosenweg Baustelle, Verkehr wird wechselseitig vorbeigeführt (bis Ende 09.2006)',
       type  => 'handicap',
       source_id => 'IM_003258',
       data  => <<EOF,
userdel	q4 20161,-651 20315,-653 20386,-555
EOF
     },
     { from  => undef, # 
       until => undef, # XXX
       text  => 'Havemannstr. (Marzahn) in beiden Richtungen zwischen Märkische Allee und Borkheider Str. Baustelle, Straße vollständig gesperrt',
       type  => 'handicap',
       source_id => 'IM_003255',
       data  => <<EOF,
userdel	q4 21218,18536 21451,18415 21524,18376 21679,18296 21836,18214
EOF
     },
     { from  => 1155664247, # 2006-08-15 19:50
       until => 1155938400, # 2006-08-19 00:00
       text  => 'Schönerlinder Str. (Buchholz) stadteinwärts zwischen Triftstr. und Bucher Str. Baustelle, Fahrtrichtung gesperrt, eine Umleitung ist eingerichtet (bis 18.08.2006)',
       type  => 'gesperrt',
       source_id => 'IM_003250',
       data  => <<EOF,
userdel	1 12067,23241 12129,23117 12178,23034
EOF
     },
     { from  => 1155592800, # 2006-08-15 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'B 005 Berliner Str. OD Petershagen, zw. Betonstr. und Ortsausgang Kanal- und Straßenbauarbeiten Vollsperrung 16.08.2006-30.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 73775,831 74246,584
EOF
     },
     { from  => 1155506400, # 2006-08-14 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'K 6411 Neulewin- L 33 Wriezen OL Neulewin, zw. KAP-Straße und Dorfstr. Straßenbau Vollsperrung 15.08.2006-30.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 69208,37364 69249,37090
EOF
     },
     { from  => 1155420000, # 2006-08-13 00:00
       until => 1167606000, # 2007-01-01 00:00
       text  => 'K 6418 Garzau-Hohenstein zw. Garzau und Gladowshöhe Straßenbau Vollsperrung 14.08.2006-31.12.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 46389,15079 46564,15609 46717,15970 46852,16883
EOF
     },
     { from  => 1155506400, # 2006-08-14 00:00
       until => 1158098400, # 2006-09-13 00:00
       text  => 'K 7239 Diedersdorf-Birkholz OD Diedersdorf, Kno. Birkholzer Str./ Chausseestr. Bau Kreisverkehrsplatz Vollsperrung 15.08.2006-12.09.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 7547,-5739 7399,-7001
EOF
     },
     { from  => 1156024800, # 2006-08-20 00:00
       until => 1159653600, # 2006-10-01 00:00
       text  => 'L 038 zw. Briesen und Petersdorf grundhafter Straßenbau Vollsperrung 21.08.2006-30.09.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 70549,-5215 71331,-5118 73292,-4598 74238,-3970 74606,-3837
EOF
     },
     { from  => 1155420000, # 2006-08-13 00:00
       until => 1180648800, # 2007-06-01 00:00
       text  => 'L 141 Neustadt-Bahnhof Zernitz Dossebrücke in der OL Neustadt Brückenneubau Vollsperrung 14.08.2006-31.05.2007 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -56556,49662 -56487,49318 -56325,49162
EOF
     },
     { from  => 1155756590, # 2006-08-16 21:29
       until => 1162335599, # 2006-10-31 23:59
       text  => 'Rixdorfer Str. (Treptow-Köpenick) in Richtung Südostallee zwischen Schnellerstr. und Südostallee Baustelle, Straße vollständig gesperrt (bis Ende Oktober 2006)',
       type  => 'gesperrt',
       source_id => 'IM_003268',
       data  => <<EOF,
userdel	1 17290,6228 17239,6182 17156,6235 16861,5935
EOF
     },
     { from  => 1155836502, # 2006-08-17 19:41
       until => 1156129200, # 2006-08-21 05:00
       text  => 'Kurfürstendamm/ Tauentzienstr. (Charlottenburg) in beiden Richtungen zwischen Uhlandstr. und Passauer Str. Straßenfest (Global City), Straße gesperrt (bis 21.08.2006, 5:00 Uhr) (18:00) ',
       type  => 'gesperrt',
       source_id => 'IM_003267',
       data  => <<EOF,
userdel	2 6137,10689 6040,10751 5942,10803 5797,10881 5725,10892 5657,10868 5484,10810 5351,10760 5229,10716 5076,10658
EOF
     },
     { from  => 1156888800, # 2006-08-30 00:00
       until => 1157148000, # 2006-09-02 00:00
       text  => 'L 401 Königs Wusterhausen-Wildau OL Königs Wusterhausen, Höhe Neue Ziegelei Deckeneinbau Vollsperrung 31.08.2006-01.09.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 26437,-10393 26407,-10986
EOF
     },
     { from  => 1156024800, # 2006-08-20 00:00
       until => 1161986400, # 2006-10-28 00:00
       text  => 'B 096 Strelitzer Str. OD Gransee, vom KVK in Ri Altlüdersdorf grundhafter Straßenbau Vollsperrung 21.08.2006-27.10.2006 ',
       type  => 'handicap',
       data  => <<EOF,
userdel	q4 -6382,67186 -7071,66471
EOF
     },
     { from  => 1156024800, # 2006-08-20 00:00
       until => 1160258400, # 2006-10-08 00:00
       text  => 'L 017 Königshorst-Warsow zw. Lobeofsund und KG bei Wiesenaue Straßenbauarbeiten Vollsperrung 21.08.2006-07.10.2006 ',
       type  => 'gesperrt',
       data  => <<EOF,
userdel	2 -36125,34218 -34868,34062
EOF
     },
    );
