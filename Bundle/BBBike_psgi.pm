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


LWP::UserAgent	- für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)

Apache::Session::DB_File	- optionale Session-Verwaltung für das CGI-Programm, notwendig für wapbbbike

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung für das CGI-Programm

XML::Simple	- optional für XML-Dumps der BBBike-Route

XML::Parser	- optional für UAProf parsing (bevorzugt wird allerdings XML::LibXML::SAX oder XML::SAX::PurePerl)

YAML::XS	- optional für YAML-Dumps der BBBike-Route, für die Testsuite sowie fuer temp_blockings

JSON::XS	- optional für JSON-Dumps der BBBike-Route und diverse Serialisierungsaufgaben

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

Digest::MD5	- für den File-Cache im CGI-Programm

DB_File	- Caching, Sessionhandling etc.

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument

Cairo	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Pango	- Erzeugung der Route als PDF-Dokument, alternativer Renderer

Class::Accessor	- für die ESRI-Module etc.

Template	- für BBBikeDraw::MapServer

Palm::PalmDoc	- für das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung

XBase	- Erzeugen der Mapserver- oder anderer ESRI-Dateien

SVG	- additional optional BBBikeDraw backend for SVG graphics

Object::Iterate	- Notwendig für die bbd2-esri-Konvertierung

Archive::Zip	- Zum Zippen der BBBike-Daten in bbbike-data.cgi

Geo::SpaceManager 0.91	- Intelligentere Labelplatzierung, bei der PDF-Ausgabe verwendet

WWW::Mechanize	- Für Testen des CGI-Interfaces

WWW::Mechanize::FormFiller	- Für Testen des CGI-Interfaces

Plack	- Basis für die PSGI-Anwendung

CGI::Emulate::PSGI	- Für die CGI-Emulation mit PSGI

CGI::Compile	- Für die CGI-Emulation mit PSGI

Plack::Middleware::Rewrite	- Für das Plack/PSGI-Routing benötigt

Starman	- Ein performanterer PSGI-Server als der Standard-Server bei Plack


=head1 DESCRIPTION

Module für eine PSGI/Plack-Installation.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
