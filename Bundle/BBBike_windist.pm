# -*- perl -*-

package Bundle::BBBike_windist;

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike_windist - A bundle to install windows distribution dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install Bundle::BBBike_windist'

=head1 CONTENTS


Tk 800.000	- das absolute Muss!

Tk::FireButton	- "Firebutton"-Funktionalität für die Windrose

Tk::Pod 2.8	- Online-Hilfe

Tk::FontDialog	- zum Ändern des Zeichensatzes aus dem Programm heraus

Tk::JPEG

Tie::Watch

Tk::HistEntry

Tk::Stderr	- optionales Redirect von Fehlermeldungen in ein Tk-Fenster

Tk::Date

Tk::PNG	- Für Icons mit besserer Alpha-Unterstützung

Tk::NumEntry 2.06

LWP::UserAgent	- für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)

XML::Twig	- alternativ für das Parsen und Erzeugen von GPX-Dateien, benötigt XML::Parser

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

Storable	- für das Caching beim CGI-Programm

MLDBM

Algorithm::Permute 0.08	- Für das Problem des Handlungsreisenden (schnellerer Permutor)

List::Permutor	- Für das Problem des Handlungsreisenden (langsamerer Permutor)

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument

Win32::API	- Für das Ermitteln der verfügbaren Desktop-Größe

Win32::Registry

Win32::Shortcut

Class::Accessor	- für die ESRI-Module etc.

IPC::Run	- hilft bei der sicheren Ausführung von externen Kommandos (insbesondere für Win32)

Object::Iterate	- Notwendig für die bbd2-esri-Konvertierung

Tie::IxHash	- Damit Direktiven in Straßen-Daten geordnet bleiben

GPS::Garmin	- für GPS-Upload

Geo::METAR	- Wetterdaten im METAR-Format


=head1 DESCRIPTION

Module für die binäre Windows-Distribution.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
