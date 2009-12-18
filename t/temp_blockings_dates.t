#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: temp_blockings_dates.t,v 1.12 2007/09/20 21:04:23 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
require BBBikeEdit;

BEGIN {
    if (!eval q{
	use Test::More;
	use Date::Calc qw(Mktime Today_and_Now); # fallback to Date::PCalc?
	1;
    }) {
	print "1..0 # skip no Test::More and/or Date::Calc modules\n";
	exit;
    }
}

plan tests => 81;

my @Today_and_Now = Today_and_Now;
my $This_Year = $Today_and_Now[0];

for my $test_data
    ([<<EOF,
Kastanienallee (Prenzlauer Berg) in Richtung Danziger Str., ab Schwedter Str. Baustelle, Fahrtrichtung gesperrt bis 15.07. 
EOF
      Mktime(@Today_and_Now),
      Mktime($This_Year,7,15+1,0,0,0),
      0,
     ],

     [<<EOF,
Vom 26. Mai 2006 bis 16. Juli 2006 wird die Straße des 17. Juni zwischen Siegessäule und Brandenburger Tor komplett gesperrt. Grund sind die geplante WM-Fanmeile sowie mehrere Festveranstaltungen (u.a. Love Parade).
EOF
      Mktime(2006,5,26,0,0,0),
      Mktime(2006,7,16+1,0,0,0),
      undef,
     ],

     [<<EOF,
NEW	Johannisthaler Chaussee (Neukölln) in Höhe der Ernst-Keller-Brücke Baustelle, Straße vollständig gesperrt wegen Brückenneubau (bis Ende 2004) (10:01) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,12,31,23,59,59),
      0
     ],

     [<<EOF,
L 37; (Petershagen-Seelow); südl. Seelow Kno. Diedersdorf/    Friedersdorf    Bau OU B 1n/B167n    halbseitige Sperrung/Lichtsignalanl.    17.08.2004-unbekannt 
EOF
      Mktime(2004,8,17,0,0,0),
      undef,
     ],

     [<<EOF,
L 86; (Groß Kreutz-Ketzin); OD Deetz/Havel    Kanalarbeiten    halbseitige Sperrung/Lichtsignalanl.    09.06.2004-30.10.2004 
EOF
      Mktime(2004,6,9,0,0,0),
      Mktime(2004,10,30,23,59,59),
     ],

     [<<EOF,
L90 Johannisthaler Chaussee In beiden Richtungen zwischen Rudower Str. und Königsheideweg Brückenarbeiten, gesperrt eine Umleitung ist eingerichtet (bis 30.09.04.) (05:53) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,9,30,23,59,59),
      0
     ],

     [<<EOF,
Brunnenstr. (Mitte) in beiden Richtungen, zwischen Bernauer Str. und Anklamer Str. in Höhe Rheinsberger Str. Baustelle, Fahrbahn auf einen Fahrstreifen verengt (Bis Ende 09/2005) (08:34) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2005,9,30,23,59,59),
      0
     ],

     [<<EOF,
Blankenburger Weg - Blankenburger-Weg-Brücke (Pankow) in beiden Richtungen zwischen Pasewalker Str. und Bahnhofsstraße Baustelle, Straße vollständig gesperrt (bis 12/2004) (11:02) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,12,31,23,59,59),
      0
     ],

     [<<EOF,
Wilhelmstr. (Mitte) in beiden Richtungen zwischen Mohrenstr. und Leipziger Str. Baustelle, Fahrbahnverengung (bis Ende Juli 2005) (09:29) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2005,7,31,23,59,59),
      0
     ],

     [<<EOF,
Einbecker Str. (Lichtenberg) in Richtung Bhf Lichtenberg, zwischen Robert-Uhrig-Str. und Rosenfelder Str. Einbahnstraße in Richtung Bhf Lichtenberg (bis Ende 12/2004) (10:21) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,12,31,23,59,59),
      0
     ],

     [<<EOF,
Malchower Chaussee (Pankow) Richtung stadteinwärts zwischen Ortnitstr. und Nachtalbenweg Baustelle, veränderte Verkehrsführung. Für die Arbeiten im Abschnitt von Darßer str. bis Nachtalbenweg wird der Verkehr über Darßer Str. - Nachtalbenw. umgeleitet (bis Mitte 12.2004) (03:09) 
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,12,15,23,59,59),
      0
     ],

     [<<EOF,
Global City (05.09.03 - 07.09.03): Kurfürstendamm/Tauentzienstr. von Uhlandstr. bis Passauer Str. gesperrt
EOF
      Mktime(2003,9,5,0,0,0),
      Mktime(2003,9,8,0,0,0),
     ],

     [<<EOF,
Umfangreiche Bauarbeiten imBereich der AS Spandauer Damm
Sperrung der Einfahrt zur BAB in Richtung Süd sowie der Ausfahrt in Richtung Nord
Fahrstreifenverengung und -verschwenkungen auf dem Spandauer Damm
Umleitungen sind eingerichtet.
Dauer: voraussichtlich bis 27.07.2003
EOF
      Mktime(@Today_and_Now),
      Mktime(2003,7,28,0,0,0),
      0,
     ],

     [<<EOF,
Im Bereich Tauentzienstraße, Kurfürstendamm zwischen Nürnberger Straße
und Joachim-Friedrich-Straße, Droysenstraße, Kantstraße,
in beiden Richtungen Sportveranstaltung,Straße gesperrt.
Dauer: 09.08.2003, 14.00 Uhr bis 24.00 Uhr
EOF
      Mktime(2003,8,9,14,0,0),
      Mktime(2003,8,10,0,0,0),
     ],

     [<<EOF,
Kurfürstendamm zwischen Joachimstaler Straße und Fasanenstraße  in
Fahrtrichtung Westen gesperrt (Kranarbeiten).
Dauer: 27.07.2003 zwischen 05.30 Uhr und ca. 22.00 Uhr
EOF
      Mktime(2003,7,27,5,30,0),
      Mktime(2003,7,27,22,0,0),
     ],

     [<<EOF,
Straße des 17. Juni ist zwischen Entlastungstraße und Klopstockstraße gesperrt.
(X Race-Veranstaltung)
Dauer: 24.08.2003, von 14.00 Uhr bis 20.00 Uhr
EOF
      Mktime(2003,8,24,14,0,0),
      Mktime(2003,8,24,20,0,0),
     ],

     [<<EOF,
"Oberbaum Art-Brückenfest" am 10.08.2003
zwischen 07.00 Uhr bis 24.00 Uhr ist die Oberbaumbrücke für den
Fahrzeugverkehr gesperrt.
EOF
      Mktime(2003,8,10,7,0,0),
      Mktime(2003,8,11,0,0,0),
     ],

     [<<EOF,
zwischen Rummelsburger Straße und Schlichtallee
Bauarbeiten, gesperrt. Dauer: bis 31.08.2003.
EOF
      Mktime(@Today_and_Now),
      Mktime(2003,9,1,0,0,0),
      0
     ],

     [<<EOF,
Alfred-Kowalke-Straße
zwischen AmTierpark und Kurze Straße
veränderte Verkehrsführung im Baustellenbereich.
Dauer:28.04.2003, 07.00 Uhr bis 15.12.2003
EOF
      Mktime(2003,4,28,7,0,0),
      Mktime(2003,12,16,0,0,0),
     ],

     [<<EOF,
Alfred-Kowalke-Straße
Richtung Am Tierpark
wegen Straßenarbeiten als Einbahnstraße ausgewiesen.
Dauer: bis 31.12.2003
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,1,1,0,0,0),
      0
     ],

     [<<EOF,
Die Brückenstraße, Richtung Heinrich-Heine-Straße ist zwischen Märkisches Ufer und Köpenicker Straße wegen Bauarbeiten als Einbahnstraße eingerichtet. Die nördliche Einmündung Rungestraße/Brückenstraße wird gesperrt.Zufahrt zu den Grundstücken 6 - 11 und 28 - 30 ist nur über den Köllnischen Park möglich.
Dauer: 23.04.2003, 04.00 Uhr bis ca. 29.08.2004
EOF
      Mktime(2003,4,23,4,0,0),
      Mktime(2004,8,30,0,0,0),
     ],

     [<<EOF,
Grenzallee
Bauarbeiten  in beiden Richtungen zwischen Neuköllnische Allee und Karl-Marx-Straße
im Zusammenhang mit der Verkehrsführung der A113, AS Grenzallee/Bergiusstraße.
Fahrbahneinengungen durch Kanal- und Straßenbauarbeiten. Es kann zu erheblichen Verkehrsbehinderungen kommen.
Dauer: 10.03.2003 bis Juli 2003
EOF
      Mktime(2003,3,10,0,0,0),
      Mktime(2003,8,1,0,0,0),
     ],

     [<<EOF,
Britzer Damm    (Kreuzungsbereich Tempelhofer Weg / Fulhamer Allee)
Umbau der Straßenkreuzung ab 14.04.2003 bis 09.08.2003. Der Britzer Damm wird in beiden
Richtungen auf einen Fahrstreifen eingeschränkt, ein Linksabbiegen ist nicht möglich.
EOF
      Mktime(2003,4,14,0,0,0),
      Mktime(2003,8,10,0,0,0),
     ],

     [<<EOF,
Schwarzelfenweg
zwischen Ortnitstraße und Darßer Straße,
Gefahrenstelle, Straße gesperrt bis voraussichtlich Dezember 2003.
EOF
      Mktime(@Today_and_Now),
      Mktime(2004,1,1,0,0,0),
      0
     ],

     [<<EOF,
Heerstraße
zwischen Sandstraße und Gärtnereiring
in beiden Richtungen Straßenarbeiten,
Fahrbahn jeweils auf einen Fahrstreifen eingeengt
ab: 21.07.2003, 07.00 Uhr für ca. 4 Monate.
EOF
      Mktime(2003,7,21,7,0,0),
      Mktime(2003,11,21,7,0,0),
     ],

     [<<EOF,
Alt-Wittenau zwischen Eichborndamm und Triftstraße Bürgerfest, Straße gesperrt, Dauer: 19.06.2004, 10.00 Uhr bis 20.06.2004, 02.00 Uhr.
EOF
      Mktime(2004,06,19,10,00,00),
      Mktime(2004,06,20,02,00,00),
     ],

     [<<EOF,
Siegfriedstr. (Lichtenberg) Richtung Josef-Orlopp-Str., Höhe Fanninger Str. Baustelle, Fahrtrichtung gesperrt (bis 28.07.07 04 Uhr)
EOF
      Mktime(@Today_and_Now),
      Mktime(2007,07,28,04,00,00),
      0,
     ],

    ) {
	my($btxt, $start_date_expected, $end_date_expected, $prewarn_days_expected) = @$test_data;
	my $label = substr($btxt,0,20)."..."; $label =~ s{[\n\r]}{ }g;
	my $errors = 0;
	my($start_date, $end_date, $prewarn_days, $rx_matched);
	eval {
	    ($start_date, $end_date, $prewarn_days, $rx_matched)
		= BBBikeEditUtil::parse_dates($btxt);
	    # Delta 1s for Today_and_Now tests
	    ok(abs($start_date - $start_date_expected) <= 1, $label)
		or $errors++;
	    my $test_end_date = $end_date_expected;
	    if (!defined $test_end_date) {
		is($end_date, undef, "  no end date")
		    or $errors++;
	    } else {
		ok(abs($end_date   - $test_end_date) <= 1, "  end date")
		    or $errors++;
	    }
	    is($prewarn_days, $prewarn_days_expected, "  prewarn days")
		or $errors++;
	};
	if ($@) {
	    diag $@;
	    $errors++;
	}
	diag "$btxt\nParsed: " . scalar(localtime($start_date)) . " - " .
	    scalar(localtime($end_date)) . ", $prewarn_days prewarn days\n" .
	    "Regular expression match $rx_matched"
	    if $errors;
    }

__END__
