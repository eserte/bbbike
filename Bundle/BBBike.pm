# -*- perl -*-

package Bundle::BBBike;

$VERSION = sprintf("%d.%02d", q$Revision: 2.1 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike - A bundle to install all dependencies of BBBike

=head1 SYNOPSIS

 perl -MCPAN -e 'install Bundle::BBBike'

=head1 CONTENTS

Tk 402.002	- das absolute Muss!

Tk::FireButton

Tk::Pod 2.8	- Online-Hilfe

Tk::FontDialog

Tk::JPEG

Tie::Watch

Tk::HistEntry

LWP::UserAgent	- für die WWW-Verbindungen (Stadtplan und Wetterbericht)

Image::Magick	- für Bildmanipulationen beim Radar-Bild der FU

CGI::MiniSvr	- für das persistente CGI-Programm

FCGI

Apache::Session::DB_File	- optionale Session-Verwaltung für das CGI-Programm

Mail::Send	- falls man aus bbbike heraus E-Mails mit der Routenbeschreibung verschicken will

String::Approx 2.7	- oder man verwendet agrep (mindestens Version 3.0)

Storable	- für das Caching beim CGI-Programm

MLDBM

GD 1.18	- zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm

Chart::ThreeD::Pie	- Tortendiagramme in der Statistik

List::Permutor	- Für das Problem des Handlungsreisenden

PDF::Create 0.06	- Erzeugung der Route als PDF-Dokument --- die neueste Version ist nur auf sourceforge erhältlich! (http://prdownloads.sourceforge.net/perl-pdf/perl-pdf-0.06.1b.tar.gz?download)

BSD::Resource

Devel::Peek

Statistics::Descriptive

Math::MatrixReal

Class::Accessor	- für GPS::GpsmanData, die ESRI-Module etc.

Inline::C	- für den schnelleren Suchalgorithmus, siehe ext/Strassen-Inline

Pod::Usage	- für das Ausgeben der 'Usage' in einigen Entwicklungs-Tools



=head1 DESCRIPTION

Dieses BE<uuml>ndel listet alle erforderlichen und empfohlenen Module
fE<uuml>r BBBike auf. Bis auf B<Tk> sind alle anderen Module optional.

=head1 AUTHOR

Slaven Rezic <eserte@cs.tu-berlin.de>

=cut
