# Generated automatically by make_task.pl
use strict;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME => 'Task::BBBike::windist',
    VERSION_FROM => 'windist.pm',
    PREREQ_PM => {
	'Tk'                  => 800.000, # das absolute Muss!
	'Tk::FireButton'      => 0, # "Firebutton"-Funktionalität für die Windrose
	'Tk::Pod'             => 2.8, # Online-Hilfe
	'Tk::FontDialog'      => 0, # zum Ändern des Zeichensatzes aus dem Programm heraus
	'Tk::JPEG'            => 0,
	'Tie::Watch'          => 0,
	'Tk::HistEntry'       => 0,
	'Tk::Stderr'          => 0, # optionales Redirect von Fehlermeldungen in ein Tk-Fenster
	'Tk::Date'            => 0,
	'Tk::PNG'             => 0, # Für Icons mit besserer Alpha-Unterstützung
	'Tk::NumEntry'        => 2.06,
	'LWP::UserAgent'      => 0, # für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)
	'XML::Twig'           => 0, # alternativ für das Parsen und Erzeugen von GPX-Dateien, benötigt XML::Parser
	'String::Approx'      => 2.7, # oder man verwendet agrep (mindestens Version 3.0)
	'Storable'            => 0, # für das Caching beim CGI-Programm
	'DB_File'             => 0, # Caching, Sessionhandling etc.
	'MLDBM'               => 0,
	'List::Permutor'      => 0, # Für das Problem des Handlungsreisenden (langsamerer Permutor)
	'PDF::Create'         => 0.06, # Erzeugung der Route als PDF-Dokument
	'Win32::API'          => 0, # Für das Ermitteln der verfügbaren Desktop-Größe
	'Win32::Registry'     => 0,
	'Win32::Shortcut'     => 0,
	'Class::Accessor'     => 0, # für die ESRI-Module etc.
	'Array::Heap'         => 0, # macht A* noch etwas schneller
	'IPC::Run'            => 0, # hilft bei der sicheren Ausführung von externen Kommandos (insbesondere für Win32)
	'Object::Iterate'     => 0, # Notwendig für die bbd2-esri-Konvertierung
	'Tie::IxHash'         => 1.23, # Damit Direktiven in Straßen-Daten geordnet bleiben
	'CDB_File'            => 0, # Für die alternative A*-Optimierung in XS/C und Cache-Dateien (grid/lazy)
	'Geo::METAR'          => 0, # Wetterdaten im METAR-Format
	'Geo::Coder::Bing'    => 0.10, # Geocoding über Bing
	'Geo::Coder::OSM'     => 0, # Geocoding mit OpenStreetMap-Daten
	'Text::Unidecode'     => 0, # Für das Neu-Erzeugen der .bbd-Dateien in data; Fallback für internationale Texte in PDFs
	'CGI'                 => 3.46, # CGI-Handling, URL-Berechnungen
	'Tie::Handle::Offset' => 0, # Für die schnelle Straßen+Hausnummernsuche
	'Search::Dict'        => 1.07, # Für die schnelle Straßen+Hausnummernsuche
	'Unicode::Collate'    => 0.60, # Für die schnelle Straßen+Hausnummernsuche
    },
);
