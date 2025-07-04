# Generated automatically by make_task.pl
use strict;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'Task::BBBike::windist',
    VERSION_FROM => 'windist.pm',
    PREREQ_PM => {
	'Tk'                   => 800.000, # das absolute Muss!
	'Tk::FireButton'       => 0, # "Firebutton"-Funktionalit�t f�r die Windrose
	'Tk::Pod'              => 2.8, # Online-Hilfe
	'Tk::FontDialog'       => 0, # zum �ndern des Zeichensatzes aus dem Programm heraus
	'Tk::JPEG'             => 0,
	'Tie::Watch'           => 0,
	'Tk::HistEntry'        => 0,
	'Tk::Stderr'           => 0, # optionales Redirect von Fehlermeldungen in ein Tk-Fenster
	'Tk::Date'             => 0,
	'Tk::PNG'              => 0, # F�r Icons mit besserer Alpha-Unterst�tzung
	'Tk::NumEntry'         => 2.06,
	'LWP::UserAgent'       => 0, # f�r die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen f�r Daten-Updates �ber das Internet (ansonsten wird Http.pm verwendet)
	'LWP::Protocol::https' => 0, # F�r https-URLs (z.B. Download- oder Geocoder-URLs)
	'XML::LibXML'          => 0, # optional f�r das Parsen und Erzeugen von GPX- und KML-Dateien
	'XML::Twig'            => 0, # alternativ f�r das Parsen und Erzeugen von GPX-Dateien, ben�tigt XML::Parser
	'String::Approx'       => 2.7, # oder man verwendet agrep (mindestens Version 3.0)
	'Storable'             => 0, # f�r das Caching beim CGI-Programm
	'DB_File'              => 0, # Caching, Sessionhandling etc.
	'MLDBM'                => 0,
	'List::Permutor'       => 0, # F�r das Problem des Handlungsreisenden (langsamerer Permutor)
	'PDF::Create'          => 1.43, # Erzeugung der Route als PDF-Dokument
	'Win32::API'           => 0, # F�r das Ermitteln der verf�gbaren Desktop-Gr��e
	'Win32::Registry'      => 0,
	'Win32::Shortcut'      => 0,
	'Class::Accessor'      => 0, # f�r die ESRI-Module etc.
	'Array::Heap'          => 0, # macht A* noch etwas schneller
	'IPC::Run'             => 0, # hilft bei der sicheren Ausf�hrung von externen Kommandos (insbesondere f�r Win32)
	'Object::Iterate'      => 0, # Notwendig f�r die bbd2-esri-Konvertierung
	'Tie::IxHash'          => 1.23, # Damit Direktiven in Stra�en-Daten geordnet bleiben
	'CDB_File'             => 0, # F�r die alternative A*-Optimierung in XS/C und Cache-Dateien (grid/lazy)
	'Geo::METAR'           => 0, # Wetterdaten im METAR-Format
	'Geo::Coder::OSM'      => 0, # Geocoding mit OpenStreetMap-Daten
	'Text::Unidecode'      => 0, # F�r das Neu-Erzeugen der .bbd-Dateien in data; Fallback f�r internationale Texte in PDFs
	'CGI'                  => 3.46, # CGI-Handling, URL-Berechnungen
	'Tie::Handle::Offset'  => 0, # F�r die schnelle Stra�en+Hausnummernsuche
	'Search::Dict'         => 1.07, # F�r die schnelle Stra�en+Hausnummernsuche
	'Unicode::Collate'     => 0.60, # F�r die schnelle Stra�en+Hausnummernsuche
    },
);
