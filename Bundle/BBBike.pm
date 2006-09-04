# -*- perl -*-

package Bundle::BBBike;

$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike - A bundle to install all dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike'

=head1 CONTENTS


Tk 800.000	- das absolute Muss!

Tk::FireButton	- "Firebutton"-Funktionalität für die Windrose

Tk::Pod 2.8	- Online-Hilfe

Tk::FontDialog	- zum Ändern des Zeichensatzes aus dem Programm heraus

Tk::JPEG

Tie::Watch

Tk::HistEntry

Tk::Stderr	- optionales Redirect von Fehlermeldungen in ein Tk-Fenster

Tk::DateEntry 1.38

Tk::Date

Tk::PNG	- Für Icons mit besserer Alpha-Unterstützung

Tk::NumEntry 2.06

LWP::UserAgent	- für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)

Image::Magick	- für Bildmanipulationen beim Radar-Bild der FU

Apache::Session::DB_File	- optionale Session-Verwaltung für das CGI-Programm, notwendig für wapbbbike

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung für das CGI-Programm

XML::SAX	- CPAN.pm kann XML::SAX nicht über XML::Simple automatisch installieren

XML::Simple	- optional für XML-Dumps der BBBike-Route

XML::Parser	- optional für UAProf parsing (alternative wäre XML::SAX::PurePerl)

XML::LibXML	- optional für das Parsen und Erzeugen von GPX-Dateien

XML::Twig	- alternativ für das Parsen und Erzeugen von GPX-Dateien, benötigt XML::Parser

YAML	- optional für YAML-Dumps der BBBike-Route sowie fuer temp_blockings

Mail::Mailer 1.53	- falls man aus bbbike heraus E-Mails mit der Routenbeschreibung verschicken will

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

String::Similarity	- optional für den temp_blockings-Editor und ungenaue Suche in der Perl/Tk-Applikation

Storable	- für das Caching beim CGI-Programm

MLDBM

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

Chart::ThreeD::Pie	- Tortendiagramme in der Statistik

List::Permutor	- Für das Problem des Handlungsreisenden

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument --- die neueste Version ist nur auf sourceforge erhältlich! (http://prdownloads.sourceforge.net/perl-pdf/perl-pdf-0.06.1b.tar.gz?download oder direkt: http://heanet.dl.sourceforge.net/sourceforge/perl-pdf/perl-pdf-0.06.1b.tar.gz)

Font::Metrics::Helvetica	- Für die Reparatur der Zeichenbreitentabellen in PDF::Create

BSD::Resource

Devel::Peek

Statistics::Descriptive

Math::MatrixReal

Class::Accessor	- für GPS::GpsmanData, die ESRI-Module etc.

Template	- für BBBikeDraw::MapServer

Inline::C	- für den schnelleren Suchalgorithmus, siehe ext/Strassen-Inline

Pod::Usage	- für das Ausgeben der 'Usage' in einigen Entwicklungs-Tools

Palm::PalmDoc	- für das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung

Astro::Sunrise	- Anzeige des Sonnenuntergangs/-aufgangs im Info-Fenster

WWW::Shorten	- Kürzen der langen Mapserver-Links im Info-Fenster

File::ReadBackwards	- LogTracker plugin, Edititeren

Date::Pcalc	- LogTracker plugin (mögliche Alternative ist Date::Calc)

XBase	- Erzeugen der Mapserver- oder anderer ESRI-Dateien, notwendig für radzeit.de

IPC::Run	- hilft bei der sicheren Ausführung von externen Kommandos (insbesondere für Win32)

Imager	- additional optional BBBikeDraw backend for PNG graphics

Image::ExifTool	- für geocode_images

SVG	- additional optional BBBikeDraw backend for SVG graphics

Object::Iterate	- Notwendig für die radzeit.de-Version (bbd2esri)

Object::Realize::Later	- Notwendig für Strassen::Lazy, selten benötigt

Archive::Zip	- Zum Zippen der BBBike-Daten in bbbike-data.cgi

Text::CSV_XS	- Für das Parsen des MapInfo-Formats

DBI	- Für XBase/MySQL, siehe unten

DBD::XBase	- Für das Parsen des ESRI-Shapefile-Formats

XBase	- Ebenfalls für das Parsen des ESRI-Shapefile-Formats

DBD::mysql	- Für den Zugriff auf die Hausnummerdatenbank

Tie::IxHash	- Damit Direktiven in Straßen-Daten geordnet bleiben

CDB_File	- Für die alternative A*-Optimierung in XS/C

DB_File::Lock	- Same DB_File operations, used in Strassen::Index

GPS::Garmin	- für GPS-Upload

Image::Info

Test::More

Test::Differences

Test::NoWarnings

WWW::Mechanize	- Für Testen des CGI-Interfaces

Devel::Leak	- Für Memory-Leak-Tests


=head1 DESCRIPTION

Dieses BE<uuml>ndel listet alle erforderlichen und empfohlenen Module
fE<uuml>r BBBike auf. Bis auf B<Tk> sind alle anderen Module optional.

This bundle lists all required and optional perl modules for BBBike.
Only B<Tk> is really required, all other modules are optional.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
