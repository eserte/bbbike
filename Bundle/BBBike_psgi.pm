# -*- perl -*-

package Bundle::BBBike_psgi;

$VERSION = '1.04'; # XXX need another solution here, not a hardcoded version

1;

__END__

=head1 NAME

Bundle::BBBike_psgi - A bundle to install psgi dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike_psgi'

=head1 CONTENTS


LWP::UserAgent	- f�r die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen f�r Daten-Updates �ber das Internet (ansonsten wird Http.pm verwendet)

LWP::Protocol::https	- F�r https-URLs (z.B. Download- oder Geocoder-URLs)

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung f�r das CGI-Programm

XML::Simple	- optional f�r XML-Dumps der BBBike-Route

YAML::XS	- optional f�r YAML-Dumps der BBBike-Route, f�r die Testsuite sowie fuer temp_blockings

JSON::XS	- optional f�r JSON-Dumps der BBBike-Route und diverse Serialisierungsaufgaben

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

Digest::MD5	- f�r den File-Cache im CGI-Programm

DB_File	- Caching, Sessionhandling etc.

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument

Cairo	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Pango	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Imager::QRCode	- F�r das Erzeugen von QRCodes

Class::Accessor	- f�r die ESRI-Module etc.

Template	- f�r BBBikeDraw::MapServer

Array::Heap	- macht A* noch etwas schneller

Palm::PalmDoc	- f�r das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung

XBase	- Erzeugen der Mapserver- oder anderer ESRI-Dateien

SVG	- additional optional BBBikeDraw backend for SVG graphics

Object::Iterate	- Notwendig f�r die bbd2-esri-Konvertierung

Archive::Zip	- Zum Zippen der BBBike-Daten in bbbike-data.cgi

Geo::SpaceManager 0.91	- Intelligentere Labelplatzierung, bei der PDF-Ausgabe verwendet

WWW::Mechanize	- F�r Testen des CGI-Interfaces

WWW::Mechanize::FormFiller	- F�r Testen des CGI-Interfaces

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

Module f�r eine PSGI/Plack-Installation.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
