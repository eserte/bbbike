[% #  -*- text -*- -%]
[% # use: tpage --eval_perl --define lang=DE < ... > README -%]
[% # use: tpage --eval_perl --define lang=EN < ... > README.english -%]
[% #  -%]
[% #  -%]
[% #  Necessary changes in this document: -%]
[% #  * BBBIKEWINVER if there's a new windows distribution -%]
[% #  * Tk version -%]
[% #  -%]
[% #  Warning: use no-fill in the next line! -%]
[% SET TESTPLATFORMS = "Linux (Debian wheezy, Debian squeeze, Debian etch, Ubuntu 12.04, CentOS, Suse 7.0 und 6.4, Red Hat 8.0), FreeBSD (Version 9.1, 9.0, 8.0, 6.1, 4.9, 4.6, 3.5), Windows (Windows 8, Windows 7, Vista, XP, 2000, NT 4.0, 98, 95), MacOSX (10.4, 10.5 ...), Solaris (Version 8 und 2.5)" -%]
[% PERL -%]
require BBBikeVar;
$stash->set('BBBIKEVAR_DISPLAY_DISTDIR', $BBBike::DISPLAY_DISTDIR);
$stash->set('BBBIKEVAR_DISTFILE_SOURCE', $BBBike::DISTFILE_SOURCE);
$stash->set('BBBIKEVAR_DISTFILE_WINDOWS', $BBBike::DISTFILE_WINDOWS);
$stash->set('BBBIKEVAR_UPDATE_DATA_CGI', $BBBike::BBBIKE_UPDATE_DATA_CGI);
$stash->set('BBBIKEVER', $BBBike::STABLE_VERSION);
$stash->set('BBBIKEWINVER', $BBBike::WINDOWS_VERSION);
$stash->set('BBBIKESFWWW', $BBBike::BBBIKE_SF_WWW);
$stash->set('MAIL', $BBBike::EMAIL);
$stash->set('CGIURL', $BBBike::BBBIKE_WWW);
$stash->set('DIRECTCGIURL', $BBBike::BBBIKE_DIRECT_WWW);
$stash->set('HTTPGIT', $BBBike::BBBIKE_GIT_HTTP);
$stash->set('GITREPO', $BBBike::BBBIKE_GIT_CLONE_URL);
$stash->set('HTTPCVS', $BBBike::BBBIKE_CVS_HTTP);
$stash->set('CVSREPO', $BBBike::BBBIKE_CVS_ANON_REPOSITORY);
$stash->set('HTTPSNAPSHOT', $BBBike::BBBIKE_UPDATE_DIST_CGI);
[% END -%]
[% #  -%]
[% #  .tpl source of README -%]
[% #  -%]
=head1 README

BBBike - 
[%- IF lang=="DE" -%]
ein Programm zum Suchen von Routen für Radfahrer in Berlin
[%- ELSE -%]
a route-finder for cyclists in Berlin and Brandenburg
[%- END -%]


=head1 
[%- IF lang=="DE" -%]
FERTIGE PAKETE
[%- ELSE -%]
PREBUILT PACKAGES
[%- END -%]



[%- IF lang=="DE" -%]
Wenn man sich die Arbeit erleichtern möchte, dann kann man ein
fertiges Paket auf L<[% BBBIKESFWWW %]/downloads.de.html> finden
(Windows, einige Linux-Distributionen, MacOSX, FreeBSD).

Die nächsten Installationsschritte werden nur für die
BBBike-Installation aus den Quellen benötigt.
[%- ELSE -%]
You can check on L<[% BBBIKESFWWW %]/downloads.en.html> for prebuilt BBBike
packages (Windows, einige Linux-Distributionen, MacOSX, FreeBSD).

The following installation steps are necessary only for installing
BBBike from source.
[%- END -%]


=head1 INSTALLATION


=head2 
[%- IF lang=="DE" -%]
Alle Systeme außer Windows
[%- ELSE -%]
All systems except Windows
[%- END -%]



=head3 
[%- IF lang=="DE" -%]
Download
[%- ELSE -%]
Download
[%- END -%]



[%- IF lang=="DE" -%]
Die aktuellste BBBike-Archivdatei findet man im Verzeichnis
L<[% BBBIKEVAR_DISPLAY_DISTDIR %]> . Die aktuelle Sourcedatei ist
L<[% BBBIKEVAR_DISTFILE_SOURCE %]> .
[%- ELSE -%]
You can find the newest source distribution file of BBBike in the directory
L<[% BBBIKEVAR_DISPLAY_DISTDIR %]> . The current source version is
L<[% BBBIKEVAR_DISTFILE_SOURCE %]> .
[%- END -%]


=head3 FreeBSD


[%- IF lang=="DE" -%]
Für FreeBSD existiert ein I<Port> für BBBike in der
Kategorie B<german>. Besitzer älterer FreeBSD-Versionen können den
I<Port> über L<http://www.freebsd.org/cgi/ports.cgi?query=bbbike&stype=all>
finden. Die Installation über das Ports-System erfolgt wie folgt:
[%- ELSE -%]
For FreeBSD there is a I<port> for BBBike in the
category B<german>. For older versions of FreeBSD, you can find the
I<port> at L<http://www.freebsd.org/cgi/ports.cgi?query=bbbike&stype=all>.
To install the application via the ports system type:
[%- END -%]


	cd /usr/ports/german/BBBike
	make all install


[%- IF lang=="DE" -%]
Ohne I<Port> kann BBBike wie bei L<anderen Unices|/Linux, Solaris, andere Unices> installiert werden.
[%- ELSE -%]
If you don't have the BBBike I<port>, you can install BBBike like L<in other
UNIX's|/Linux, Solaris, other UNIX operating systems>.
[%- END -%]


=head3 
[%- IF lang=="DE" -%]
Linux, Solaris, andere Unices
[%- ELSE -%]
Linux, Solaris, other UNIX operating systems
[%- END -%]



[%- IF lang=="DE" -%]
Perl muss installiert sein. Das ist oft, besonders bei Linux, der
Fall. Mit

	perl -v

kann überprüft werden, ob und welche Version von perl installiert ist.
Ansonsten kann man Perl unter L<http://www.perl.org/get.html> finden. Es wird
mindestens die Version 5.005 benötigt, alle neueren Perl-Versionen
(5.6.x, 5.8.x, 5.10.x, 5.12.x, 5.14.x, 5.16.x) funktionieren auch.

Danach kann BBBike ausgepackt werden:
[%- ELSE -%]
First, you have to install perl. Most operating systems have perl
already bundled. You can check with

	perl -v

whether and which version of perl is installed. Otherwise you can find
perl at L<http://www.perl.org/get.html>. You need at least version
5.005, but newer perl versions (5.6.x, 5.8.x, 5.10.x, 5.12.x, 5.14.x,
5.16.x) work, too.

Next step is to extract the BBBike distribution:
[%- END -%]



	zcat BBBike-[% BBBIKEVER %].tar.gz | tar xfv -


[%- IF lang=="DE" -%]
Falls perl/Tk (eine möglichst neue Version, z.B. 804.028 or 800.025) nicht
installiert ist: als Superuser folgendes eingeben:
[%- ELSE -%]
If perl/Tk (the recommended version is 804.028 or 800.025) is not installed:
type as super user:
[%- END -%]


        cd BBBike-[% BBBIKEVER %]
	perl -I`pwd` -MCPAN -e shell
	force install Bundle::BBBike_small
	quit


[%- IF lang=="DE" -%]
Damit wird Perl/Tk über das
Internet geladen, compiliert und installiert. "force" wird
benötigt, da einige Module erwartete Fehler in der Test-Suite erzeugen
und damit die Installation verhindern. Wenn weitere Probleme
auftreten (insbesondere mit der Internet-Verbindung), dann sollten
die Anweisungen in

	perldoc perlmodinstall

befolgt werden, um das Modul Tk manuell zu installieren.

Danach kann das Programm mit
[%- ELSE -%]
Perl/Tk will be fetched over the internet, get compiled
and installed. "force" is needed because some modules (especially Tk)
have expected test failures and therefore would not be installed. If
you have problems, especially with the internet 
connection, then you should follow the instructions in

	perldoc perlmodinstall

on how to install a perl module manually (in this case: the Tk
module).

After that, you can start the program with
[%- END -%]



	perl bbbike


[%- IF lang=="DE" -%]
gestartet werden.

Optional kann mit
[%- ELSE -%]

To compile some XS modules (this is optional and needs a C compiler)
and install the panel entry for KDE/GNOME, type:
[%- END -%]



	perl install.pl


[%- IF lang=="DE" -%]
oder
[%- ELSE -%]
or
[%- END -%]



	./install.sh


[%- IF lang=="DE" -%]
eine Compilierung von einigen XS-Modulen durchgeführt
werden sowie Einträge für KDE/GNOME erzeugt werden. Für das Compilieren
ist ein C-Compiler (z.B. gcc), der mittlerweile nicht bei allen
Linux-Versionen standardmäßig installiert wird, notwendig.
[%- END -%]

[%- IF lang=="DE" -%]


Statt dem oben erwähnten Bundle::BBBike_small kann auch Bundle::BBBike verwendet werden.
Damit werden wesentlich mehr Perl-Module installiert, die teilweise nur für
die Entwicklung verwendet werden, teilweise aber zusätzliche
BBBike-Features ermöglichen.

Wenn "perl install.pl" nicht verwendet wird, aber trotzdem die
XS-Module für bessere Performance installiert werden sollen, muss

	make ext

ausgeführt werden. Dazu ist das Perl-Modul L<Inline::C> notwendig.

[%- ELSE -%]


You can also use Bundle::BBBike instead of Bundle::BBBike_small. This
will install more Perl modules, some of them only useable for the
development, but some of them enabling more features of BBBike.

If you choose to not use "perl install.pl", but you want to compile
and install the XS modules for better performance, then you have to
execute

	make ext

This requires the perl module L<Inline::C>.

[%- END -%]

=head3 Mac OS X


[%- IF lang=="DE" -%]
Mac OS X enthält bereits 5.8.x. Um BBBike zum Laufen zu bringen
werden noch XDarwin und Perl/Tk benötigt. Eine Anleitung zum Aufsetzen
von Perl/Tk auf Mac OS X bekommt man in der comp.lang.perl.tk Newsgroup
(siehe L<http://groups.google.com>).

[%- ELSE -%]
Mac OS X comes already with perl 5.8.x. Now you just need XDarwin and Perl/Tk
to get BBBike running. For instructions how to setup Perl/Tk on Mac OS X
refer to the comp.lang.perl.tk newsgroup (see
L<http://groups.google.com>).

[%- END -%]


[%- IF lang=="DE" -%]
Folgende Anleitung habe ich von Wolfram Kroll erhalten:
[%- ELSE -%]
The following instructions are from Wolfram Kroll:
[%- END -%]



[%- IF lang=="DE" -%]
L<[% BBBIKEVAR_DISTFILE_SOURCE %]> und (von
L<http://www.cpan.org>) perl-5.8.4-stable.tar.gz, Tk-804.027.tar.gz
besorgt.
[%- ELSE -%]
Get L<[% BBBIKEVAR_DISTFILE_SOURCE %]> and (from
L<http://www.cpan.org>) perl-5.8.4-stable.tar.gz, Tk-804.027.tar.gz
[%- END -%]


=over

=item 1.

[%- IF lang=="DE" -%]
Perl auf dynamische Libs konfiguriert:
[%- ELSE -%]
Perl configured to use dynamic libraries:
[%- END -%]


 # sh Configure -des -Duseshrplib
 # make
 # make test
 # sudo make install


[%- IF lang=="DE" -%]
--> /usr/local/ ist der default (das orginale perl bleibt erhalten)
[%- ELSE -%]
--> /usr/local/ is the default (the original Perl is preserved)
[%- END -%]


=item 2.

[%- IF lang=="DE" -%]
Tk: das ist kein Aqua-Tk, sondern für X11, na meinetwegen...
[%- ELSE -%]
Tk: that is not a Aqua-Tk, but rather is for X11, but...
[%- END -%]


 # make


[%- IF lang=="DE" -%]
in einem X11-Fenster: # make test
[%- ELSE -%]
in an X11 window: # make test
[%- END -%]


 sudo make install

=item 3.

[%- IF lang=="DE" -%]
bbbike unter X11

läuft!
[%- ELSE -%]
bbbike under X11

runs!
[%- END -%]


=back


[%- IF lang=="DE" -%]
Um compilieren zu können, sind die Entwicklertools notwendig. Diese
werden "Xcode" genannt und befinden sich entweder auf einer
gleichnamigen CD (bei älteren Macs) oder im Applications-Ordner unter
C<Installers/Xcode Tools/Developer.mpkg> (bei neueren Macs).

Es wird auch eine X11- bzw. Darwin-Umgebung benötigt (X11SDK-Paket). 

Mac OS Classic wird nicht unterstützt.
[%- ELSE -%]
To compile bbbike under X11 the "Xcode" development tools are needed.
These can be found either on a CD-ROM of the same name (for older Macs)
or in the Applications folder under C<Installers/Xcode Tools/Developer.mpkg>
(for newer Macs).
 
An X11 environment or Darwin environment is also required (package X11SDK).

Mac OS Classic is not supported.
[%- END -%]



=head2 Windows 95/98/2000/NT/XP/Vista/7/8

=head3 
[%- IF lang=="DE" -%]
Normale Installation
[%- ELSE -%]
Normal installation
[%- END -%]



[%- IF lang=="DE" -%]

BBBike und Perl benötigen ca. 32 MB an Festplattenspeicher.

Einfach die Datei L<[% BBBIKEVAR_DISTFILE_WINDOWS %]> laden und starten.
Damit wird das Installationsprogramm gestartet.
[%- ELSE -%]
BBBike and Perl need approx. 32 MB hard disk space.

Download the file
L<[% BBBIKEVAR_DISTFILE_WINDOWS %]> and just start it for the installation
program.
[%- END -%]


=head3 Alternative Windows Installation (1)


[%- IF lang=="DE" -%]
Alternativ kann BBBike auch nur mit den Sourcen installiert werden.
Arbeitsschritte für Windows-95/98/2000/NT/XP-Benutzer:
[%- ELSE -%]
As an alternative, you can install BBBike just with the sources. Steps
for Windows 95/98/2000/NT/XP users:
[%- END -%]


=over 4

=item *


[%- IF lang=="DE" -%]
Aus dem WWW die perl-Distribution downloaden. Perl kann
von der ActiveState Webpage geladen werden:
[%- ELSE -%]
Download the perl distribution from the ActiveState webpage:
[%- END -%]


L<http://www.activestate.com/activeperl/downloads>


[%- IF lang=="DE" -%]
oder es kann alternativ Strawberry Perl verwendet werden:
[%- ELSE -%]
or alternatively use Strawberry Perl:
[%- END -%]


L<http://strawberryperl.com/>


[%- IF lang=="DE" -%]


Das Tk-Modul muss separat installiert werden. Das wird in der
Eingabeaufforderung mit den folgenden Kommandos getan:
[%- ELSE -%]


The Tk module needs to be installed using the following commands in
cmd.exe:
[%- END -%]


    perl -MCPAN -eshell
    force notest install Tk
    quit


=item *


[%- IF lang=="DE" -%]
L<BBBike-[% BBBIKEWINVER %].tar.gz|[% BBBIKEVAR_DISTFILE_WINDOWS %]>
downloaden und auspacken. Das
ausgepackte Verzeichnis kann an eine gewünschte Position verschoben werden.
[%- ELSE -%]
Download
L<BBBike-[% BBBIKEWINVER %].tar.gz|[% BBBIKEVAR_DISTFILE_WINDOWS %]>
and extract this file. The unpacked directory may be moved to another
position in the filesystem.
[%- END -%]


=item *


[%- IF lang=="DE" -%]
In der Eingabeaufforderung oder im Explorer zum Verzeichnis BBBike-[% BBBIKEWINVER %]
wechseln und


	install.pl

aufrufen. Das Installationsskript erstellt
Einträge für BBBike im Startmenü und erzeugt ein Icon auf dem Desktop.
[%- ELSE -%]
Open the explorer, change to the BBBike-[% BBBIKEVER %] directory and call


	install.pl.

The installation program creates entries in the start
menu and a desktop icon.
[%- END -%]


=back

=head3 Alternative Windows Installation (2)


[%- IF lang=="DE" -%]
Wenn Cygwin (L<http://www.cygwin.org/>) installiert ist, können aus einer
cygwin-Shell heraus die Anweisungen wie bei einer
L<UNIX-Installation|/Linux, Solaris, andere Unices>
befolgt werden.
[%- ELSE -%]
If you have Cygwin (L<http://www.cygwin.org/>) installed, you can start
a cygwin shell and follow the
L<UNIX instructions|/Linux, Solaris, other UNIX operating systems>.
[%- END -%]


=head3 Alternative Windows Installation (3)


[%- IF lang=="DE" -%]
Für sehr alte Systeme (Windows95, 98) kann als weitere Alternative eine ältere perl-Distribution, die bereits Tk
enthält, geladen werden:
[%- ELSE -%]
For very old systems (Windows95, 98) you can download an older distribution with Tk
included:
[%- END -%]


L<http://www.perl.com/CPAN/ports/win32/Standard/x86/perl5.00402-bindist04-bc.tar.gz>


[%- IF lang=="DE" -%]
Die geladene Datei muss mit WinZip oder gunzip+tar ausgepackt werden.
Im ausgepackten Verzeichnis befindet sich das Installationsprogramm
C<install.bat>. Das Programm in der Eingabeaufforderungen aufrufen und
die Anweisungen befolgen.

Mit dieser alten Version (5.004_02) von Perl benötigt man auch eine
relativ alte Version von BBBike (älter als 3.00).

[%- ELSE -%]
You have to extract this file with WinZip or gunzip+tar. In the
extracted directory, there will be the installation program
C<install.bat>. Call this program in the MSDOS prompt and follow the
instructions.

If you're using this old version of perl (5.004_02), you also need an
old version of BBBike, at least older than version 3.00.

[%- END -%]

=head3 Windows 3.1


[%- IF lang=="DE" -%]
Windows 3.1 wird nicht mehr unterstützt. Ältere Versionen von BBBike
(z.B. 2.x) haben noch eine Anleitung, wie man BBBike unter Windows 3.1
nutzen kann.
[%- ELSE -%]
Windows 3.1 is not supported anymore. Older BBBike versions (for
example 2.x) have instructions on how to use BBBike under Windows 3.1.
[%- END -%]



=head1 
[%- IF lang=="DE" -%]
AUSFÜHREN
[%- ELSE -%]
EXECUTION
[%- END -%]


=head2 
[%- IF lang=="DE" -%]
Perl/Tk-Version
[%- ELSE -%]
Perl/Tk version
[%- END -%]



[%- IF lang=="DE" -%]
Unter Unix wird BBBike ausgeführt, indem man ins bbbike-Verzeichnis
wechselt und 


	perl bbbike

eintippt. Wenn eine KDE/GNOME-Installation durchgeführt wurde, findet man
das Icon im 
Startmenü unter dem Punkt "Anwendungen". Bei Windows befindet sich das
BBBike-Icon ebenfalls im Startmenü.

Einige Versionen von BBBike wurden unter folgenden
Plattformen getestet: [% TESTPLATFORMS %]. Die
Entwicklungsarbeit wird auf einem FreeBSD-Rechner vorgenommen.
[%- ELSE -%]
To execute BBBike on Unix, change to the bbbike directory and type


	perl bbbike

in the shell. With a full KDE/GNOME installation, there is an icon in the
application menu item
of the start menu. On Windows, there is a start menu entry for
BBBike.

To switch the English language support, please set the LC_ALL,
LC_MESSAGES, or LANG environment variables to "en" or something
similar (for FreeBSD and Linux, this is "en_US.UTF-8"). For Unix,
this can be done with


	env LC_ALL=en_US.UTF-8 perl bbbike


Some versions of BBBike are tested with: [% TESTPLATFORMS %]. The
development machine runs with FreeBSD.
[%- END -%]


=head2 
[%- IF lang=="DE" -%]
WWW-Version
[%- ELSE -%]
WWW version
[%- END -%]



[%- IF lang=="DE" -%]
Im WWW existiert unter der Adresse
[%- ELSE -%]
There is a simple cgi version at
[%- END -%]


L<[% CGIURL %]>


[%- IF lang=="DE" -%]
eine einfache, stark text-orientierte, aber dennoch leistungsfähige Version von bbbike. Weitere
Informationen zu der CGI-Version gibt es unter
[%- ELSE -%]
More information for the CGI version at:
[%- END -%]


L<[% DIRECTCGIURL %]/info=1>


[% IF 0 %][%# Don't mention now, cbbbike fails currently -%]
=head2 
[%- IF lang=="DE" -%]
Nicht-GUI-Version
[%- ELSE -%]
Non GUI version
[%- END -%]



[%- IF lang=="DE" -%]
Mit C<cbbbike> und C<cmdbbbike> existieren einfache Kommandozeilen-Versionen des
Programms.
[%- ELSE -%]
C<cbbbike> and C<cmdbbbike> are simpler command line versions of the program.
[%- END -%]

[% END %]


=head1 
[%- IF lang=="DE" -%]
ENTWICKLUNG
[%- ELSE -%]
DEVELOPMENT
[%- END -%]


=head2 git


[%- IF lang=="DE" -%]
Der aktuelle Entwicklungsstand von BBBike kann mit git
verfolgt werden.

Dazu muss in der Kommandozeile folgendes eingegeben werden:

[%- ELSE -%]
The current BBBike development may be tracked via git.

To fetch the git repository type the following in the command line:

[%- END -%]


    git clone git://github.com/eserte/bbbike.git


[%- IF lang=="DE" -%]
Alle weiteren Male nur folgendes verwenden:
[%- ELSE -%]
to update the next time
[%- END -%]


    cd bbbike
    git pull


[%- IF lang=="DE" -%]
Das git-Repository wird fast täglich aktualisiert und enthält auch die aktuellen
Daten.


[%- ELSE -%]
The git repository is frequently updated and also contains the current
data.

[%- END -%]


[% IF 0 %][%# CVS wird nicht mehr aktualisiert -%]
=head2 CVS


[%- IF lang=="DE" -%]
Falls git nicht verwendet werden kann, gibt es noch immer die
Möglichkeit auf das alte CVS-Repository unter [% CVSREPO %] zuzugreifen.
Es ist allerdings nicht garantiert, dass Updates in der gleichen
Frequenz wie auf dem git-Repository passieren.
[%- ELSE -%]
If git cannot be used, then there's still the possibility to access
the old CVS repository ([% CVSREPO %]). Note that it's not guaranteed that
updates occur in the same frequency as for the git repository.
[%- END -%]
[% END %]

=head2

[%- IF lang=="DE" -%]
Programm-Aktualisierung
[%- ELSE -%]
Application update
[%- END -%]



[%- IF lang=="DE" -%]
Der aktuelle Programm -und Daten-Stand kann auch von der Adresse
L<[% HTTPSNAPSHOT %]> downgeloadet werden.
[%- ELSE -%]
It is also possible to download a current snapshot using the URL
L<[% HTTPSNAPSHOT %]>.
[%- END -%]


=head2

[%- IF lang=="DE" -%]
Daten-Aktualisierung
[%- ELSE -%]
Data update
[%- END -%]



[%- IF lang=="DE" -%]
Um nur die Daten zu aktualisieren, kann man sich die aktuellen Daten
als ZIP-Datei von L<[% BBBIKEVAR_UPDATE_DATA_CGI %]> holen. Die ZIP-Datei
muss im BBBike-Programmverzeichnis (bei Windows unter
C<C:\Programme\BBBike\bbbike>) ausgepackt werden.

Die Daten können auch aus der Perl/Tk-Applikation heraus aktualisiert
werden: per Menüpunkt Einstellungen > Daten-Update über das Internet.
[%- ELSE -%]
To update only the data part of BBBike, just download the current data
as a ZIP file from L<[% BBBIKEVAR_UPDATE_DATA_CGI %]>. The ZIP file has to be
extracted in the BBBike program directory (Windows: in
C<C:\Programme\BBBike\bbbike>).

The data may also be updated within the Perl/Tk application, using the
menu item Settings > Data update over internet.

[%- END -%]


=head1 
[%- IF lang=="DE" -%]
DOKUMENTATION
[%- ELSE -%]
DOCUMENTATION
[%- END -%]



[%- IF lang=="DE" -%]
Die L<Dokumentation|bbbike> liegt im POD-Format (plain old
documentation) in der 
Datei C<bbbike.pod>, sowie als HTML (C<bbbike.html>) vor. Die
POD-Datei kann entweder mit tkpod, perldoc oder aus bbbike (bei
installiertem B<Tk::Pod>) heraus gelesen werden.
[%- ELSE -%]
The L<documentation|bbbike> can be accessed in pod format (C<bbbike.pod>) or in
html format (C<bbbike.html>). You can read the pod version with tkpod,
perldoc or from bbbike (if B<Tk::Pod> is installed).
[%- END -%]



=head1 
[%- IF lang=="DE" -%]
LIZENZ
[%- ELSE -%]
LICENSE
[%- END -%]



[%- IF lang=="DE" -%]
Die wichtigsten Teilstücke der Anwendung (C<bbbike>, C<cgi/bbbike.cgi>,
C<Strassen.pm> und C<Strassen/Inline.pm>) und die Daten im
C<data>-Verzeichnis sind unter der
L<GPL|http://www.opensource.org/licenses/gpl-license.html>
veröffentlicht. Die restlichen Module können entweder unter der L<Artistic
License|http://www.opensource.org/licenses/artistic-license.html> oder
GPL veröffentlicht werden. Die genauen Lizenzbestimmungen stehen in den
Quelldateien selbst.

Einige Module und Dateien von anderen Autoren sind in dieser
Distribution enthalten: C<lib/your.pm> von Michael G Schwern,
C<lib/Text/ScriptTemplate.pm> von Taisuke Yamada, C<lib/enum.pm> von
Zenin, C<ext/Strassen-Inline/heap.[ch]> der Internet Software
Consortium, C<ext/BBBikeXS/sqrt.c> von Eyal Lebedinsky.

C<BBBike-[% BBBIKEWINVER %]-Windows.zip> enthält einen Teil der
C<Strawberry Perl>-Distribution, siehe
[%- ELSE -%]
The most important parts of the application (C<bbbike>, C<cgi/bbbike.cgi>,
C<Strassen.pm> and C<Strassen/Inline.pm>) and the data in the
subdirectory C<data> are released unter the
L<GPL|http://www.opensource.org/licenses/gpl-license.html>.
The other files can be redristibuted either under the L<Artistic
License|http://www.opensource.org/licenses/artistic-license.html> or
the GPL. Please refer to the source files.

Some module und files from other authors are included in this
distribution: C<lib/your.pm> by Michael G Schwern,
C<lib/Text/ScriptTemplate.pm> by Taisuke Yamada, C<lib/enum.pm> by
Zenin, C<ext/Strassen-Inline/heap.[ch]> by Internet Software
Consortium, C<ext/BBBikeXS/sqrt.c> by Eyal Lebedinsky.

C<BBBike-[% BBBIKEWINVER %]-Windows.zip> contains a partial
C<Strawberry Perl> distribution, see
[%- END -%]

L<http://strawberryperl.com/>

=head1 
[%- IF lang=="DE" -%]
AUTOR
[%- ELSE -%]
AUTHOR
[%- END -%]


Slaven Rezic, E-Mail: L<[% MAIL %]|mailto:[% MAIL %]>
