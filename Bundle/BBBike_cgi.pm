# -*- perl -*-

package Bundle::BBBike_cgi;

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike_cgi - A bundle to install cgi dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike_cgi'

=head1 CONTENTS


LWP::UserAgent	- für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)

Apache::Session::DB_File	- optionale Session-Verwaltung für das CGI-Programm, notwendig für wapbbbike

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung für das CGI-Programm

XML::Simple	- optional für XML-Dumps der BBBike-Route

XML::Parser	- optional für UAProf parsing (bevorzugt wird allerdings XML::LibXML::SAX oder XML::SAX::PurePerl)

YAML	- optional für YAML-Dumps der BBBike-Route sowie fuer temp_blockings

JSON::XS	- optional für JSON-Dumps der BBBike-Route und diverse Serialisierungsaufgaben

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument

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


=head1 DESCRIPTION

Module für eine CGI-Installation.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
