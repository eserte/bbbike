#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: temp_blockings_dates.t,v 1.5 2004/06/14 21:02:14 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);
require BBBikeEdit;
use Date::Calc qw(Mktime Today_and_Now);

BEGIN {
    if (!eval q{
	use Test::More qw(no_plan);
	1;
    }) {
	print "1..0 # skip: no Test module\n";
	exit;
    }
}

my @Today_and_Now = Today_and_Now;

for my $test_data
    (
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
    ) {
	my $btxt = shift @$test_data;
	my $errors = 0;
	my($start_date, $end_date, $prewarn_days, $rx_matched);
	eval {
	    ($start_date, $end_date, $prewarn_days, $rx_matched)
		= BBBikeEditUtil::parse_dates($btxt);
	    # Delta 1s for Today_and_Now tests
	    ok(abs($start_date - shift @$test_data) <= 1) or $errors++;
	    ok(abs($end_date   - shift @$test_data) <= 1) or $errors++;
	    is($prewarn_days, shift @$test_data) or $errors++;
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
