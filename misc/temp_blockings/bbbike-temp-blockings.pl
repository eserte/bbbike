# temp-blocking
# undef old entries
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
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,6,0,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,9,23,59,0)),
       file  => "strassenfest-bluecherplatz.bbd",
       text  => "Straßenfest rund um den Blücherplatz vom 6.6. - 9.6.",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,7,0,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,8,22,0,0)),
       file  => "karneval-der-kulturen.bbd",
       text  => "Karneval der Kulturen am 8.6. (Hasenheide - Gneisenaustr. - Yorckstr.)",
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
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,23,5,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,29,5,0,0)),
       file  => "csd.bbd",
       text  => "CSD am 28.5.",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,6-1,27,6,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,6-1,29,23,59,59)),
       file  => "badstr.bbd",
       text  => "Badstraße zwischen Böttgerstraße und Pankstraße: in beiden Richtungen Veranstaltung, Straße gesperrt",
     },
     { from  => Time::Local::timelocal(reverse(2003-1900,7-1,3,6,0,0)),
       until => Time::Local::timelocal(reverse(2003-1900,7-1,7,23,59,59)),
       file  => "rheinstrassenfest.bbd",
       text  => "Rheinstraßenfest in der Rheinstraße zwischen Breslauer Platz  und Walter-Schreiber-Platz. Beide Richtungsfahrbahnen sind ab dem 05.07.2003, 06.00 Uhr bis zum 06.07.2003, 24.00 Uhr gesperrt.",
     },
     # XXX
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
     { from  => 1065060000, # 2003-10-02 04:00
       until => 1065391200, # 2003-10-06 00:00
       file  => 'karlmarx.bbd',
       text  => 'Karl-Marx-Straße, zwischen Flughafenstraße und Uthmannstraße gesperrt. Grund: Straßenfest. Dauer: 03.10.2003, 04.00 Uhr bis 05.10.2003, 24.00 Uhr ',
       type  => 'handicap',
     },
     { from  => 1065758400, # 2003-10-10 06:00
       until => 1065996000, # 2003-10-13 00:00
       file  => 'hermannstr.bbd',
       text  => 'Hermannstraße, zwischen Emserstraße und Thomasstraße gesperrt. Grund: Straßenfest. Dauer: 11.10.2003, 06.00 Uhr bis 12.10.2003, 24.00 Uhr',
       type  => 'handicap',
     },
     { from  => 1066924800, # 2003-10-23 18:00
       until => 1067295600, # 2003-10-28 00:00
       file  => 'schlichtallee.bbd',
       text  => 'Schlichtallee, zwischen Hauptstraße und Lückstraße, Vollsperrung vom 24.10.03, 18.00 Uhr bis 27.10.03, 04.00 Uhr wegen Ein-/Ausbau der Bahnbrücken. ',
       type  => 'gesperrt',
     },
     { from  => 1070341200, # 2003-12-02 06:00
       until => 1070924399, # 2003-12-08 23:59
       file  => 'rixdorfer_weihnachtsmarkt.bbd',
       text  => 'Rixdorfer Weihnachtsmarkt',
       type  => 'gesperrt',
     },
     { from  => 1069620183, # 2003-11-23 21:43
       until => 1072212183, # 2003-12-23 21:43
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
    );
