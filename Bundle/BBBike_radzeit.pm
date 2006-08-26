# -*- perl -*-

package Bundle::BBBike_radzeit;

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike - A bundle to install radzeit dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike_radzeit'

=head1 CONTENTS


LWP::UserAgent	- für die WWW-Verbindungen (z.B. Wetterbericht)

Apache::Session::DB_File	- optionale Session-Verwaltung für das CGI-Programm, notwendig für wapbbbike

Apache::Session::Counted	- optionale aber sehr zu empfehlende Session-Verwaltung für das CGI-Programm

XML::Simple	- optional für XML-Dumps der BBBike-Route

XML::Parser	- optional für UAProf parsing (alternative wäre XML::SAX::PurePerl)

YAML	- optional für YAML-Dumps der BBBike-Route sowie fuer temp_blockings

MIME::Lite	- Versenden von Benutzer-Kommentaren im Webinterface

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument --- die neueste Version ist nur auf sourceforge erhältlich! (http://prdownloads.sourceforge.net/perl-pdf/perl-pdf-0.06.1b.tar.gz?download oder direkt: http://heanet.dl.sourceforge.net/sourceforge/perl-pdf/perl-pdf-0.06.1b.tar.gz)

Class::Accessor	- für GPS::GpsmanData, die ESRI-Module etc.

Template	- für BBBikeDraw::MapServer

Palm::PalmDoc	- für das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung

XBase	- Erzeugen der Mapserver- oder anderer ESRI-Dateien, notwendig für radzeit.de

SVG	- additional optional BBBikeDraw backend for SVG graphics

Object::Iterate	- Notwendig für die radzeit.de-Version (bbd2esri)

Archive::Zip	- Zum Zippen der BBBike-Daten in bbbike-data.cgi

WWW::Mechanize	- Für Testen des CGI-Interfaces


=head1 DESCRIPTION

Module für die Installation auf radzeit.de.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
