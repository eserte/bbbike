# -*- perl -*-

package Bundle::BBBike;

$VERSION = '1.04'; # XXX need another solution here, not a hardcoded version

1;

__END__

=head1 NAME

Bundle::BBBike - A bundle to install all dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike'

=head1 CONTENTS


Tk 800.000	- das absolute Muss!

Tk::FireButton	- "Firebutton"-Funktionalit�t f�r die Windrose

Tk::Pod 2.8	- Online-Hilfe

Tk::FontDialog	- zum �ndern des Zeichensatzes aus dem Programm heraus

Tk::JPEG

Tie::Watch

Tk::HistEntry

Tk::Stderr	- optionales Redirect von Fehlermeldungen in ein Tk-Fenster

Tk::DateEntry 1.38

Tk::Date

Tk::PNG	- F�r Icons mit besserer Alpha-Unterst�tzung

Tk::NumEntry 2.06

X11::Protocol	- Rotated text support

LWP::UserAgent	- f�r die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen f�r Daten-Updates �ber das Internet (ansonsten wird Http.pm verwendet)

Image::Magick	- f�r Bildmanipulationen beim Radar-Bild der FU

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung f�r das CGI-Programm

Apache::Session::DB_File	- optionale Session-Verwaltung f�r das CGI-Programm, falls Apache::Session::Counted nicht zur Verf�gung steht

XML::SAX	- CPAN.pm kann XML::SAX nicht �ber XML::Simple automatisch installieren

XML::Simple	- optional f�r XML-Dumps der BBBike-Route

XML::LibXML	- optional f�r das Parsen und Erzeugen von GPX- und KML-Dateien

XML::Twig	- alternativ f�r das Parsen und Erzeugen von GPX-Dateien, ben�tigt XML::Parser

YAML::XS	- optional f�r YAML-Dumps der BBBike-Route, f�r die Testsuite sowie fuer temp_blockings

JSON::XS	- optional f�r JSON-Dumps der BBBike-Route und diverse Serialisierungsaufgaben

Kwalify	- optional f�r Validierung in der Testsuite

Mail::Mailer 1.53	- falls man aus bbbike heraus E-Mails mit der Routenbeschreibung verschicken will

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

String::Similarity	- optional f�r den temp_blockings-Editor und ungenaue Suche in der Perl/Tk-Applikation

Storable	- f�r das Caching beim CGI-Programm

Digest::MD5	- f�r den File-Cache im CGI-Programm

DB_File	- Caching, Sessionhandling etc.

MLDBM

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

Chart::ThreeD::Pie	- Tortendiagramme in der Statistik

Algorithm::Permute 0.08	- F�r das Problem des Handlungsreisenden (schnellerer Permutor)

List::Permutor	- F�r das Problem des Handlungsreisenden (langsamerer Permutor)

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument

Cairo	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Pango	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Font::Metrics::Helvetica	- F�r die Reparatur der Zeichenbreitentabellen in PDF::Create

Imager::QRCode	- F�r das Erzeugen von QRCodes

autodie

IO::Zlib

BSD::Resource

Devel::Peek

Statistics::Descriptive

Math::MatrixReal

Class::Accessor	- f�r die ESRI-Module etc.

Template	- f�r BBBikeDraw::MapServer

Inline::C	- f�r den schnelleren Suchalgorithmus, siehe ext/Strassen-Inline

Array::Heap	- macht A* noch etwas schneller

Pod::Usage	- f�r das Ausgeben der 'Usage' in einigen Entwicklungs-Tools

Palm::PalmDoc	- f�r das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung

Astro::Sunrise 0.85	- Anzeige des Sonnenuntergangs/-aufgangs im Info-Fenster

WWW::Shorten	- K�rzen der langen Mapserver-Links im Info-Fenster

File::ReadBackwards	- LogTracker plugin, Edititeren

Date::Calc	- LogTracker plugin

XBase	- Erzeugen der Mapserver- oder anderer ESRI-Dateien

IPC::Run	- hilft bei der sicheren Ausf�hrung von externen Kommandos (insbesondere f�r Win32)

Imager	- additional optional BBBikeDraw backend for PNG graphics

Imager::Screenshot	- better screenshot module

Image::ExifTool	- f�r geocode_images und exif2gpsman

DateTime::Format::ISO8601	- f�r exif2gpsman und temp_blockings_tasks

SVG	- additional optional BBBikeDraw backend for SVG graphics

GD::SVG 0.31	- another SVG alternative, not used yet in production

Object::Iterate	- Notwendig f�r die bbd2-esri-Konvertierung

Object::Realize::Later	- Notwendig f�r Strassen::Lazy, selten ben�tigt

Archive::Zip	- Zum Zippen der BBBike-Daten in bbbike-data.cgi

Text::CSV_XS	- F�r das Parsen des MapInfo-Formats

DBI	- F�r XBase, siehe unten

DBD::XBase	- F�r das Parsen des ESRI-Shapefile-Formats

XBase	- Ebenfalls f�r das Parsen des ESRI-Shapefile-Formats

Geo::LibProj::FFI	- F�r das Konvertieren von ESRI-Shapefiles

Tie::IxHash 1.23	- Damit Direktiven in Stra�en-Daten geordnet bleiben

CDB_File	- F�r die alternative A*-Optimierung in XS/C und Cache-Dateien (grid/lazy)

DB_File::Lock	- Same DB_File operations, used in Strassen::Index

GPS::Garmin	- f�r GPS-Upload

Geo::SpaceManager 0.91	- Intelligentere Labelplatzierung, bei der PDF-Ausgabe verwendet

Geo::Distance::XS	- Berechnung von Entfernungen f�r polare Koordinaten, m�glicherweise schneller als Math::Trig

Geo::Distance 0.16	- Prereq f�r Geo::Distance::XS

Geo::METAR	- Wetterdaten im METAR-Format

Tk::ExecuteCommand	- Bessere Fehlerberichte im temp_blockings-Editor

Algorithm::Diff	- Unterschiede im temp_blockings-Editor anzeigen

Sort::Naturally	- F�r nat�rliches Sortieren von bbd-Dateien

Geo::Coder::Bing 0.10	- Geocoding �ber Bing

Geo::Coder::OSM	- Geocoding mit OpenStreetMap-Daten

Flickr::API	- Flickr-Bilder in BBBike anzeigen

Image::Info 1.32

Test::More

Test::Differences

WWW::Mechanize	- F�r Testen des CGI-Interfaces

WWW::Mechanize::FormFiller	- F�r Testen des CGI-Interfaces

LWP::Protocol::https	- Zum Testen von https-URLs (z.B. Download-URLs)

Devel::Leak	- F�r Memory-Leak-Tests

Devel::Hide	- Zum Testen von optionalen Modulen

Text::Table

Text::Unidecode	- F�r das Neu-Erzeugen der .bbd-Dateien in data; Fallback f�r internationale Texte in PDFs

Data::Compare	- F�r das Neu-Erzeugen der .bbd-Dateien in data

HTML::FormatText	- F�r VMZTool

Math::Round	- F�r downloadosm -round

DateTime::Event::Easter	- F�r Feiertagsberechnungen in temp_blockings_tasks

CGI 3.46	- CGI-Handling, URL-Berechnungen

Module::Metadata	- Information zu installierten Modulen f�r API-Aufrufe

Plack	- Basis f�r die PSGI-Anwendung

CGI::Emulate::PSGI	- F�r die CGI-Emulation mit PSGI

CGI::Compile	- F�r die CGI-Emulation mit PSGI

Plack::Middleware::Rewrite	- F�r das Plack/PSGI-Routing ben�tigt

Starman	- Ein performanterer PSGI-Server als der Standard-Server bei Plack

HTTP::Date	- F�r If-Modified-Since-Handling in BBBikeDataDownloadCompat (mod_perl)

Tie::Handle::Offset	- F�r die schnelle Stra�en+Hausnummernsuche

Search::Dict 1.07	- F�r die schnelle Stra�en+Hausnummernsuche

Unicode::Collate 0.60	- F�r die schnelle Stra�en+Hausnummernsuche


=head1 DESCRIPTION

Dieses BE<uuml>ndel listet alle erforderlichen und empfohlenen Module
fE<uuml>r BBBike auf. Bis auf B<Tk> sind alle anderen Module optional.

This bundle lists all required and optional perl modules for BBBike.
Only B<Tk> is really required, all other modules are optional.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
