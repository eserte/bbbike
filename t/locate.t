#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: locate.t,v 1.2 2006/05/23 22:25:20 eserte Exp $
# Author: Slaven Rezic
#

use strict;

#use NotYetWritten;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 1;

pass("This is the test for the yet-to-written Strassen::Locate ? module");

my @tests = (
	     ["Boitzenburg" => "22642,95423"], # Stadt in Brandenburg (orte/orte2)
	     ["Berliner Str., Teltow" => "1453,-746"], # Straße/Stadt-Kombination
	     ["Teltow, Berliner Str." => "1453,-746"], # Stadt/Straße-Kombination
	     ["Berliner Str. (Teltow)" => "1453,-746"], # Straße/Stadt-Kombination
	     ["Berliner Str.    (Teltow)" => "1453,-746"], # Straße/Stadt-Kombination mit Spaces
	     ["Berliner Straße    (Teltow)" => "1453,-746"], # Straße/Stadt-Kombination
	     ["berliner straße    (teltow)" => "1453,-746"], # Straße/Stadt-Kombination, Kleinschreibung
	     ["Wandlitz" => "14822,37589"], # Stadt in Brandenburg (orte/orte2), ähnliche Straße in Berlin existiert
	     ["Königs Wusterhausen" => "..."], # Ort in Brandenburg
	     ["Berlin, Thaerstraße" => "..."], # Stadt/Straße-Kombination mit Berlin als Stadt
	     ["S-Bahnhof Bernau" => "..."], # S-Bahnhöfe im Umland
	     ["S Zeuthen" => "..."],
	     ["s- bahnhof buch" => "..."], # mit unnötigen Spaces
	     ["S -Bhf Erkner" => "..."],
	     ["S- Griebnitzsee" => "..."],
	     ["Potsdam Hbf" => "..."], # Potsdam Hbf Variationen
	     ["Potsdam Hauptbahnhof" => "..."],
	     ["S Potsdam HBF" => "..."],
	     ["s-bahnhof potsdam hbf" => "..."],
	     ["Kleinmachnow" => "..."], # Stadt in Brandenburg
	     ["Neurupin Stadt" => "..."], # Bahnhof in Brandenburg mit Rechtschreibfehler
	     ["Siegessäule" => "..."], # Sehenswürdigkeit
	     ["checkpoint charly" => "..."], # Sehenswürdigkeit mit Rechtschreibfehler
	     ["Hamburger Bahnhof" => "..."], # Sehenswürdigkeit, kein Bahnhof!
	     ["deutsches theater" => "..."], # Sehenswürdigkeit
	     ["Virchow-Klinikum" => "..."], # möglicherweise in den Sehenswürdigkeiten enthalten
	     ["gedächtniskirche" => "..."], # Sehenswürdigkeit, Kurzschreibweise
	     ["ICC" => "..."], # Sehenswürdigkeit
	     ["Charlottenburger Schloß" => "..."], # sollte das Schloß Charlottenburg als Ergebnis haben
	     ["Museumsinsel" => "..."], # Fläche/Sehenswürdigkeit?
	     ["Nikolaiviertel" => "..."], # dito
	     ["Spandau Altstadt" => "..."], # dito
	     ["zoolog garten" => "..."], # interessante Abkürzung
	     ["triglaw brücke" => "..."], # Brücke
	     ["gotzkowskibrücke" => "..."], # Brücke mit Rechtschreibfehler
	     ["berliner str. 76 13189 berlin" => "..."], # Straße+Hausnummer+PLZ+Ortsangabe
	     ["Ringstr. 44, 12105 Berlin" => "..."], # dito, mit Interpunktion
	     ["15732 Schulzendorf August-Bebel-Str. 18" => "..."], # andere Reihenfolge, nicht in Berlin
	     ["12359 onkel-bräsig-str." => "..."], # PLZ am Anfang
	     ["12359 berlin" => "..."], # PLZ und Stadt
	     ["10247 Weichselstraße" => "..."], # PLZ und Straße
	     ["Berlin Blankenburg" => "..."], # Ortsteil in Berlin
	     ["Oskar Helene Heim" => "..."], # gibt es als U-Bahnhof und Siedlung
	     ["U Zinnowitzer Straße" => "..."], # sollte den U-Bahnhof als Ergebnis haben
	     ["s südkreuz" => "..."], # neuer Name
	     ["s papestr" => "..."], # alter Name
	     ["bahnhof wannsee" => "..."], # ohne "S-", Regional-...
	     ["Ulmenallee 39 a" => "..."], # komplizierte Hausnummer mit Space
	     ["Reichenberger Str. 113 a" => "..."], # dito
	     ["königstr 36 b" => "..."], # und nochmal
	     ["Rummelsburger Straße 15 A" => "..."], # Großbuchstaben können auch vorkommen
	     ["Whulheide" => "..."], # Buchstabendreher, könnte den S-Bahnhof oder Park als Ergebnis haben
	     ["Mauerstraße Berlin-Mitte" => "..."], # Straße, Stadt, Ortsteil
	     ["spekteweg 52-berlin spandau" => "..."], # Straße, Hausnummer, Stadt, Ortsteil
	     ["priester" => "..."], # sollte priesterweg statt Priesterstege finden
	     ["albertstr, schoeneberg" => "..."], # Straße, Ortsteil
	     ["Fährweg, Woltersdorf" => "..."], # ebenso
	     ["schönefeld flughafen" => "..."], # Wortdreher
	     ["Müggelsee, kl. müggelsee" => "..."], # Hmmm...
	     ["zehlendorf süd" => "..."], # Ortsteil oder ehem. Bahnhof
	     ["lichterfelde" => "..."], # Ortsteil in Berlin
	     ["am langen see" => "..."], # gibt es als strasse, aber nicht in Berlin.coords.data
	     ["straße zur krampenburg" => "..."], # ebenso
	     ["Spinnerbrücke" => "..."], # populärer Name, dürfte in Alias oder so stehen...
	     ["indira-ghandi-allee" => "..."], # allee statt str. oder so
	     ["rudow, dörferblick" => "..."], # Park/Wald
	     ["Berlin Zob" => "..."], # Zentraler Omnibusbahnhof
	     ["12355 Berlin, Str. 181 Nr. 89" => "..."], # besonders kompliziert...
	     ["reichstr.105" => "..."], # warum wurde hier nichts gefunden? kein space?
	     ["neuer hönower weg" => "..."], # sollte existieren?
	     ["teerofendamm kleinmachnow" => "..."], # straße, stadt
	     ["großbeerenstr. potsdam" => "..."], # straße, stadt, sollte nicht die gleichnamnige Berliner Straße ausgeben
	     ["usedom" => "..."], # Hauptstadt von Usedom?
	     ["Av. Ch. de Gaulle 5" => "..."], # Abk. für Avenue
	     ["schloß cecilienhof" => "..."], # Sehenswürdigkeit im Umland. Neue vs. alte Rechtschreibung berücksichtigen
	     ["Schloss Diedersdorf" => "..."], # Sehenswürdigkeit im Umland.
	     ["glockebturmweg" => "..."], # zu viele Rechtschreibfehler? oder nicht in Berlin.coords.data? oder glockenturmstr. (wieder str./weg/allee etc. verwechselt!)
	     ["Entlastungsstraße" => ":.."], # ist die Straße nicht mehr in Berlin.coords.data oder so enthalten? oldname verwenden!
	     ["Fähre Caputt" => "..."], # ferry, Rechtschreibfehler
	     ["Warschauer STarße" => "..."], # er hat es tatsächlich geschafft...
	     ["hahn meitner" => "..."], # Institut
	     ["hmi" => "..."], # ebenso
	     ["Lilienthalsstr Ecke Südstern" => "..."], # Ecken werden nur mit ".../..." erkannt
	     ["Mahlower Str Ecke Fontanestr" => "..."],
	     ["s-bahnhof lichterfelde west" => "..."], # warum wurde dieser hier nicht erkannt? kein bindestrich?
	     ["Hackische Höfe" => "..."], # Sehenswürdigkeit mit Rechtschreibfehler
	     ["S-Bahnhof Hackischer Markt" =>" ..."], # S-Bhf. mit Rechtschreibfehler
	     ["Berlin-Tegel" => "..."], # ist hier der Ortsteil oder der Flughafen gemeint?
	     ["U-Bahn Tegel" => "..."], # Als Ergebnis kam hier S-Bhf Tegel...
	     ["Heinersdorf bei müncheberg" => "..."], # ich benutze selbst "bei"-Variationen in diesen Fällen. Vielleicht lieber die geografische Nähe verwenden, also alle Heinersdörfer in Bezug auf die Entfernung zu Müncheberg vergleichen.
	     ["Baggersee Biesdorf" => "..."], # wasserstadt
	     ["lankwitz kirche" => "..."], # populäre Bezeichnung, BVG-Haltestelle?
	     ["Berlin, Flughafen Schönefeld" => "..."], # ausschweifend...
	     ["tiergartentunnel" => "..."], # Alias in strassen_bab
	    );

__END__
