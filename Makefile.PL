#! /usr/bin/perl
# -*- perl -*-
# $Id: Makefile.PL,v 1.153 2009/01/22 22:51:16 eserte Exp $

use 5.005;

BEGIN {
    $^W = 0;
}

use strict;

use ExtUtils::MakeMaker;
use ExtUtils::Manifest;
use File::Basename;
use Getopt::Long;

#use lib ".."; # falls als make_bundle gestartet

use BBBikeVar;

my $action;
GetOptions('action=s' => \$action)
    or die "usage: $^X $0 [-action make_bundle|make_small_bundle|make_windist_bundle|make_radzeit_bundle]";

my $author = 'Slaven Rezic (' . $BBBike::EMAIL . ')',
my $abstract = "BBBike - ein Routenplaner für Radfahrer in Berlin und Brandenburg";
my($version_major, $version_minor) = $BBBike::VERSION =~ /^(\d+)\.(\d+)/;

######################################################################
# Required modules
#

use constant REQTABLE_MODNAME => 0;
use constant REQTABLE_VERSION => 1;
use constant REQTABLE_OS      => 2;
use constant REQTABLE_REQ     => 3;
use constant REQTABLE_DESC    => 4;
use constant REQTABLE_LONGDESC=> 5;

use constant REQ_BBBIKE_TK      => 1; # mandatory for the Perl/Tk version
use constant REQ_BBBIKE_RADZEIT => 2; # mandatory for the web package on radzeit
use constant REQ_BBBIKE_WINDIST => 4; # for windows distribution (not yet!)
# ... 4, 8, 16 ...

# Table of prerequisites:
#
#    Modulname
#                       Version
#                               OS
#                                       Req/CoReq (ORed with "|")
#                                              description token (comma separated)
#    long description (may have de/en variants)
my @req_table =
 (($] < 5.006 ?
   [qw/warnings::compat 0 all 0 base/, 'So I can use warnings everywhere'] : ()
  ),
  [qw/Tk		800.000	all	1|4	gui/,
   { de => 'das absolute Muss!',
     en => 'this one is really necessary!'
   }], # für Tk 402 sollte man bbbike 2.xx verwenden
  #in dist: [qw/Tk::Getopt	0.40	all	0	gui/],
  #in dist: [qw/Tk::ContextHelp	0	unix	0	gui/],
  [qw/Tk::FireButton	0	all	0|4	gui/,
   '"Firebutton"-Funktionalität für die Windrose'],
  [qw/Tk::Pod		2.8	all	0|4	gui/,
   { de => 'Online-Hilfe', en => 'online help' }],
  [qw/Tk::FontDialog	0	all	0|4	gui/,
   'zum Ändern des Zeichensatzes aus dem Programm heraus'],
  [qw/Tk::JPEG		0	all	0|4	gui/], # note: already part of Tk 804
  [qw/Tie::Watch	0	all	0|4	gui/], # hmmm... this version does not really work with Tk-804.027_500 and is not needed at all for Tk804
  [qw/Tk::HistEntry	0	all	0|4	gui/],
  [qw/Tk::Stderr	0	all	0|4	gui/,
   'optionales Redirect von Fehlermeldungen in ein Tk-Fenster'], # probably only needed for developers
  [qw/Tk::DateEntry	1.38	all	0	gui/],
  [qw/Tk::Date		0	all	0|4	gui/],
  [qw/Tk::PNG		0	all	0|4	gui/, # note: already part of Tk 804
   'Für Icons mit besserer Alpha-Unterstützung'],
  [qw/Tk::NumEntry	2.06	all	0|4	gui/],
  [qw/X11::Protocol	0	unix	0	gui/,
   'Rotated text support'],

  [qw/LWP::UserAgent	0	all	2|4	www,gui/,
   'für die WWW-Verbindungen (z.B. Wetterbericht); in der Perl/Tk-GUI empfohlen für Daten-Updates über das Internet (ansonsten wird Http.pm verwendet)'],
  [qw/Image::Magick	0	all	0	www/,
   'für Bildmanipulationen beim Radar-Bild der FU'],

  [qw/Apache::Session::DB_File	0	all	2	cgi/,
   'optionale Session-Verwaltung für das CGI-Programm, notwendig für wapbbbike'],
  [qw/Apache::Session::Counted	0	all	2	cgi/,
   'optionale aber sehr zu empfehlende Session-Verwaltung für das CGI-Programm'],
  [qw/XML::SAX	0	all	0	cgi/,
   'CPAN.pm kann XML::SAX nicht über XML::Simple automatisch installieren'],
  [qw/XML::Simple	0	all	2	cgi/,
   'optional für XML-Dumps der BBBike-Route'],
  [qw/XML::LibXML	0	all	0	base/,
   'optional für das Parsen und Erzeugen von GPX-Dateien und für UAProf parsing'],
  [qw/XML::Parser	0	all	2	cgi/,
   'optional für UAProf parsing (bevorzugt wird allerdings XML::LibXML::SAX oder XML::SAX::PurePerl)'],
  [qw/XML::Twig	0	all	4	base/,
   'alternativ für das Parsen und Erzeugen von GPX-Dateien, benötigt XML::Parser'],
  [qw/YAML	0	all	2	cgi/,
   'optional für YAML-Dumps der BBBike-Route sowie fuer temp_blockings'],
  [qw/YAML::Syck	0	all	0	devel/,
   'optional für die Testsuite, könnte auch YAML.pm in Zukunft ersetzen'],
  [qw/JSON::XS	0	all	0	base/,
   'optional für diverse Serialisierungsaufgaben'],

  [qw/Mail::Mailer	1.53	unix	0	mail/,
   'falls man aus bbbike heraus E-Mails mit der Routenbeschreibung verschicken will'],
  [qw/MIME::Lite	0	unix	2	mail/,
   'Versenden von Benutzer-Kommentaren im Webinterface'],

  [qw/String::Approx	2.7	all	2|4	base/,
   'oder man verwendet agrep (mindestens Version 3.0)'],
  [qw/String::Similarity 0	all	0	base/,
   'optional für den temp_blockings-Editor und ungenaue Suche in der Perl/Tk-Applikation'],
  [qw/Storable		0	all	0|4	base/, # already part of perl 5.8 and newer
   'für das Caching beim CGI-Programm'],
  [qw/MLDBM		0	all	0|4	base/],
  [qw/GD		1.18	all	2	base/,
   'zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm'],
  [qw/Chart::ThreeD::Pie	0	all	0	base/,
   'Tortendiagramme in der Statistik'],
  [qw/Algorithm::Permute	0.08	all	0|4	base/,
   'Für das Problem des Handlungsreisenden (schnellerer Permutor)'],
  [qw/List::Permutor	0	all	0|4	base/,
   'Für das Problem des Handlungsreisenden (langsamerer Permutor)'],
  [qw/PDF::Create	0.06	all	2|4	base/,
   'Erzeugung der Route als PDF-Dokument'],
  [qw/Font::Metrics::Helvetica	0	all	0	base/,
   'Für die Reparatur der Zeichenbreitentabellen in PDF::Create'],
  #in dist: [qw/BikePower	0	all	0	base/],

  [qw/BSD::Resource	0	unix	0	base/], # really only BSD, and not used anyway in BBBike

  [qw/Win32::API	0	win	0|4	base/,
   'Für das Ermitteln der verfügbaren Desktop-Größe'],
  [qw/Win32::Registry	0	win	0|4	base/],
  [qw/Win32::DDE::Client 0	win	0	base/],
  [qw/Win32::Shortcut	0	win	0|4	base/],

  [qw/Devel::Peek	0	all	0	devel/],
  [qw/Statistics::Descriptive	0	all	0	devel/],
  [qw/Math::MatrixReal	0	all	0	devel/],
  [qw/Class::Accessor	0	all	2|4	base/,
   'für die ESRI-Module etc.'],
  [qw/Template	0	all	2	devel/,
   'für BBBikeDraw::MapServer'],
  [qw/Inline::C		0	all	0	base/,
   'für den schnelleren Suchalgorithmus, siehe ext/Strassen-Inline'],
  [qw/Pod::Usage	0	all	0	devel/,
   { de => 'für das Ausgeben der \'Usage\' in einigen Entwicklungs-Tools',
     en => 'for printing the usage in some development tools'
   }],
  [qw/Palm::PalmDoc	0	all	2	base/,
   'für das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung'],
  [qw/Astro::Sunrise	0.85	all	0	base/,
   'Anzeige des Sonnenuntergangs/-aufgangs im Info-Fenster'],
  [qw/WWW::Shorten	0	all	0	base/,
   'Kürzen der langen Mapserver-Links im Info-Fenster'],
  [qw/File::ReadBackwards 0	all	0	devel/,
   'LogTracker plugin, Edititeren'],
  [qw/Date::Pcalc	0	all	0	devel/,
   'LogTracker plugin (mögliche Alternative ist Date::Calc)'],
  [qw/XBase		0	all	2	devel/,
   'Erzeugen der Mapserver- oder anderer ESRI-Dateien'],
  [qw/IPC::Run		0	all	0|4	base/,
   'hilft bei der sicheren Ausführung von externen Kommandos (insbesondere für Win32)'],
  [qw/Imager	0	all	0	devel,gui/,
   'additional optional BBBikeDraw backend for PNG graphics'],
  [qw/Imager::Screenshot	0	all	0	devel,gui/,
   'better screenshot module'],
  [qw/Image::ExifTool	0	all	0	devel/,
   'für geocode_images'],
  [qw/SVG	0	all	2	cgi/,
   'additional optional BBBikeDraw backend for SVG graphics'],
  [qw/GD::SVG	0.31	all	0	devel/,
   'another SVG alternative, not used yet in production'],
  [qw/Object::Iterate	0	all	2|4	base/,
   'Notwendig für die bbd2-esri-Konvertierung'],
  [qw/Object::Realize::Later	0	all	0	base/,
   'Notwendig für Strassen::Lazy, selten benötigt'],
  [qw/Archive::Zip	0	all	2	cgi/,
   'Zum Zippen der BBBike-Daten in bbbike-data.cgi'],
  [qw/Text::CSV_XS	0	all	0	base/,
   'Für das Parsen des MapInfo-Formats'],
  [qw/DBI	0	all	0	base/,
   'Für XBase/MySQL, siehe unten'],
  [qw/DBD::XBase	0	all	0	base/,
   'Für das Parsen des ESRI-Shapefile-Formats'],
  [qw/XBase	0	all	0	base/,
   'Ebenfalls für das Parsen des ESRI-Shapefile-Formats'],
  [qw/DBD::mysql	0	all	0	base/,
   'Für den Zugriff auf die Hausnummerdatenbank'],
  [qw/Tie::IxHash	0	all	0|4	base/,
   'Damit Direktiven in Straßen-Daten geordnet bleiben'],
  [qw/CDB_File		0	all	0	base/,
   'Für die alternative A*-Optimierung in XS/C'],
  [qw/DB_File::Lock	0	all	0	base/,
   'Same DB_File operations, used in Strassen::Index'],
  # NOTE: perl-GPS is broken in ActivePerl 5.8.8, because
  # Win32::SerialPort is not specified as a dependency
  # in the ppm and also not available in ActivePerl at all
  [qw/GPS::Garmin	0	all	4	base/,
   'für GPS-Upload'],
  [qw/Geo::SpaceManager 0.91	all	2	base/,
   'Intelligentere Labelplatzierung, bei der PDF-Ausgabe verwendet'],
  [qw/Geo::Distance::XS	0	all	0	base/,
   'Berechnung von Entfernungen für polare Koordinaten, möglicherweise schneller als Math::Trig'],
  [qw/Geo::Distance	0.16	all	0	base/,
   'Prereq für Geo::Distance::XS'], # diese Version ohne Warnungen
  [qw/Geo::METAR        0       all     4       base/,
   'Wetterdaten im METAR-Format'],
  [qw/Tk::ExecuteCommand	0	all	1	base/,
   'Bessere Fehlerberichte im temp_blockings-Editor'],
  [qw/Algorithm::Diff	0	all	1	base/,
   'Unterschiede im temp_blockings-Editor anzeigen'],
  [qw/Sort::Naturally	0	all	0	base/,
   'Für natürliches Sortieren von bbd-Dateien'],

  [qw/Yahoo::Search	0	all	0	plugin/,
   'Suche in luise-berlin'],
  [qw/Geo::Coder::Google	0.06	all	0	plugin/,
   'Geocoding über Googlemaps'], # alternative: Geo::Coder::GoogleMaps 0.03
  [qw/Geo::Coder::Yahoo	0	all	0	plugin/,
   'Geocoding über Yahoo'],
  [qw/Geo::Coder::Bing	0	all	0	plugin/,
   'Geocoding über Bing'],
  [qw/Geo::Cloudmade	0	all	0	plugin/,
   'Geocoding über Cloudmade'],

  [qw/Image::Info	1.29	all	0	test/],
  [qw/Test::More	0	all	0	test/],
  [qw/Test::Differences	0	all	0	test/],
  [qw/WWW::Mechanize	0	all	2	test/,
   'Für Testen des CGI-Interfaces'],
  [qw/WWW::Mechanize::FormFiller	0	all	2	test/,
   'Für Testen des CGI-Interfaces'],
  [qw/Devel::Leak	0	all	0	test/,
   'Für Memory-Leak-Tests'],
  [qw/Text::Table	0	all	0	devel/],
  [qw/Text::Unidecode	0	all	0	devel/,
   'Für das Neu-Erzeugen der .bbd-Dateien in data'],
  [qw/Data::Compare	0	all	0	devel/,
   'Für das Neu-Erzeugen der .bbd-Dateien in data'],

  ## Maybe in future:
  # DBD::Pg - Strassen::Pg
  # Text::LevenshteinXS - PLZ::Levenshtein
  # Tk::Wizard - BBBikeImportWizard
 );
## XXX This is a optional requisite, but currently taken out
## because of http://rt.cpan.org/Ticket/Display.html?id=41521
## May be taken in again if ExtUtils::MakeMaker is patched (patch
## and ticket pending):
#  [qw/Test::NoWarnings	0	all	0	test/],

# EXE corequisites ####################################################
# standard Unix: uname, who, tee, at, diff, zcat, ping
# BSD Unix:      leave (very optional)
# extra:         enscript, gv, ghostview, gs, netpbm-utils, cjpeg, agrep,
#                netscape, socket, mapserver, pdftk
# local extra:   cdmount, dial
# palm utils:    install-datebook, pilot_makedoc, iSilo*, txt2pdbdoc,
#                pilot-xfer
# standard X11:  xwd
########################################################################

# build prereq for the current os
my $os; # XXX os2, msdos, mac et al. missing
if ($^O eq 'MSWin32') {
    $os = "win";
} else {
    $os = "unix";
}

my $admin_makefile = "./Makefile.admin.PL";

my $make_bundle;
my $type_bundle = 0;
if ($action) {
    if ($action eq 'make_bundle') {
	$make_bundle = "normal";
	$type_bundle = 0;
    } elsif ($action eq 'make_small_bundle') {
	$make_bundle = "small";
	$type_bundle = 0;
    } elsif ($action eq 'make_radzeit_bundle') {
	$make_bundle = "radzeit";
	$type_bundle = REQ_BBBIKE_RADZEIT;
    } elsif ($action eq 'make_windist_bundle') {
	$make_bundle = "windist";
	$type_bundle = REQ_BBBIKE_WINDIST;
    } else {
	die "Unhandled action '$action'";
    }
}

my(%prereq, @prereq);
{
    my(@res) = build_prereq($os, $type_bundle);
    %prereq = %{$res[0]};
    @prereq = @{$res[1]};
}

# Call before maniread:
# Various bundles:
if ($make_bundle) {
    exit make_bundle()         if $make_bundle eq 'normal';
    exit make_small_bundle()   if $make_bundle eq 'small';
    exit make_radzeit_bundle() if $make_bundle eq 'radzeit';
    exit make_windist_bundle() if $make_bundle eq 'windist';
    die "Should not happen: unhandled value <$make_bundle>";
}
# OSD descriptions (not really used):
exit make_pi_osd('win')
    if $0 =~ /make_pi_osd/ && defined $ARGV[0] && $ARGV[0] eq 'win';
exit make_pi_osd()       if $0 =~ /make_pi_osd/;
exit make_small_pi_osd('win')
    if $0 =~ /make_small_pi_osd/ && defined $ARGV[0] && $ARGV[0] eq 'win';
exit make_small_pi_osd()      if $0 =~ /make_small_pi_osd/;

my $fileref = ExtUtils::Manifest::maniread();
my $exe_files =
    ['bbbike',
     'bbbikeapplet',
     'bbbikeclient',
     'cgi/bbbike.cgi',
     'cgi/runbbbikecgi',
     'cgi/httpi',
     'cgi/wapbbbike.cgi',
     'cmdbbbike',
     'smsbbbike',
     'cbbbike',
    ];
my(%exe_files, %pm);
foreach (@$exe_files) { $exe_files{$_}++ }
while(my($k,$v) = each %$fileref) {
    next if $k =~ /\.bat$/;
    $pm{$k} = '$(INST_LIB)/'. $k unless $exe_files{$k};
}

return 1 if $ENV{PERL_FROM_EXTERNAL};

sub build_prereq {
    my($os, $type) = @_;
    my(%prereq, @prereq);
    foreach (@req_table) {
	$_->[REQTABLE_REQ] = eval $_->[REQTABLE_REQ]; # to resolve binary or: "|"
	my(%for_os) = map { ($_, 1) } split ",", $_->[REQTABLE_OS];
	if ($for_os{$os} || $for_os{"all"} || ($type == REQ_BBBIKE_WINDIST && $for_os{win})) {
	    if ($type != 0) {
		next if ($_->[REQTABLE_REQ] & $type) == 0;
	    }
	    $prereq{$_->[REQTABLE_MODNAME]} = $_->[REQTABLE_VERSION];
	    push @prereq, $_;
	}
    }
    (\%prereq, \@prereq);
}

sub make_bundle {
    die "This bundle action should not be called on a Windows system"
	if $^O eq 'MSWin32';
    make_general_bundle(0, "BBBike.pm");
}

sub make_small_bundle {
    make_general_bundle(REQ_BBBIKE_TK, "BBBike_small.pm");
}

sub make_radzeit_bundle {
    make_general_bundle(REQ_BBBIKE_RADZEIT, "BBBike_radzeit.pm");
}

sub make_windist_bundle {
    make_general_bundle(REQ_BBBIKE_WINDIST, "BBBike_windist.pm");
}

sub make_general_bundle {
    my($type, $file, %args) = @_;

    chdir "Bundle" or die "Can't chdir into Bundle directory: $!";

    my $modules_string = "\n";
    foreach my $prereq (@prereq) {
	if ($type != 0) {
	    next if ($prereq->[REQTABLE_REQ] & $type) == 0;
	}
	$modules_string .= $prereq->[REQTABLE_MODNAME];
	if ($prereq->[REQTABLE_VERSION]) {
	    $modules_string .= " " . $prereq->[REQTABLE_VERSION];
	}
	if (defined $prereq->[REQTABLE_LONGDESC]) {
	    my $msg;
	    # XXX some day, allow building german OR english
	    # bundle files. For now, it's always german
	    if (UNIVERSAL::isa($prereq->[REQTABLE_LONGDESC], "HASH")) {
		$msg = $prereq->[REQTABLE_LONGDESC]->{'de'} ||
		       $prereq->[REQTABLE_LONGDESC]->{'en'};
	    } else {
		$msg = $prereq->[REQTABLE_LONGDESC];
	    }
	    $modules_string .= "\t- " . $msg;
	}
	$modules_string .= "\n\n";
    }

    require Template;
    my $t = Template->new({ DEBUG => 1 });
    my $out;
    (my $bundle_module = $file) =~ s/\.pm$//;
    $bundle_module = "Bundle::" . $bundle_module;
    $t->process("BBBike.tpl.pm", { type_num => $type,
				   type => {0,                  "full",
					    REQ_BBBIKE_TK,      "small",
					    REQ_BBBIKE_RADZEIT, "radzeit",
					    REQ_BBBIKE_WINDIST, "windist",
					   }->{$type},
				   file => $file,
				   bundle_module => $bundle_module,
				   modules_string => $modules_string,
				   \%args,
				 }, \$out) or die $t->error;
    open(BUNDLE, ">$file") or die "Can't write bundle $file: $!";
    binmode BUNDLE;
    print BUNDLE $out;
    close BUNDLE;
    0;
}

sub make_pi_osd {
    die "Not supported anymore (changes for new REQTABLE_REQ needed!)";
    my $os = shift || 'unix';
    make_general_pi_osd(0, "BBBike-$os.osd", $os);
}

sub make_small_pi_osd {
    die "Not supported anymore (changes for new REQTABLE_REQ needed!)";
    my $os = shift || 'unix';
    make_general_pi_osd(1, "BBBike_small-$os.osd", $os);
}

sub make_general_pi_osd {
    die "Not supported anymore (changes for new REQTABLE_REQ needed!)";
    my $type = shift;
    my $file = shift;
    my $os   = shift;

    my(%prereq, @prereq);
    {
	my(@res) = build_prereq($os, 0);
	%prereq = %{$res[0]};
	@prereq = @{$res[1]};
    }

    open(OSD, ">$file") or die "Can't write OSD $file: $!";
    (my $xml_abstract = $abstract) =~ s/ü/ue/g; # XXX
    print OSD <<EOF;
<SOFTPKG NAME="BBBike" VERSION="$version_major,$version_minor,0,0">
<TITLE>BBBike</TITLE>
<ABSTRACT>$xml_abstract</ABSTRACT>
<AUTHOR>$author</AUTHOR>
<LICENSE HREF="LICENSE" />
<IMPLEMENTATION>
 <CODEBASE HREF="http://prdownloads.sourceforge.net/bbbike/BBBike-$BBBike::STABLE_VERSION.tar.gz" />
 <INSTALL EXEC="perl">BBBike-$BBBike::STABLE_VERSION/install.pl</INSTALL>
</IMPLEMENTATION>
EOF
    foreach my $prereq (@prereq) {
	next if $prereq->[REQTABLE_REQ] < $type;
	(my $ppm_dist = $prereq->[REQTABLE_MODNAME]) =~ s/::/-/g;
	print OSD <<EOF;
<DEPENDENCY NAME="$prereq->[REQTABLE_MODNAME]">
 <CODEBASE TYPE="ppm" PACKAGE="$ppm_dist"/>
 <CODEBASE TYPE="cpan" PACKAGE="$prereq->[REQTABLE_MODNAME]"/>
</DEPENDENCY>
EOF
    }
    print OSD "</SOFTPKG>";
    close OSD;
    0;
}

WriteMakefile
  (
   'NAME'	  => 'BBBike',
   'VERSION_FROM' => 'BBBikeVar.pm',
   'dist'         => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => '.gz',
		      'POSTOP'=>'-$(CHMOD) 644 $(DISTVNAME).tar$(SUFFIX)'},
   'PM'           => \%pm,
   'PREREQ_PM'    => \%prereq,
   'EXE_FILES'    => $exe_files,

   'ABSTRACT'     => $abstract,
   'AUTHOR'       => $author,
   'LICENSE'	  => 'gpl',
   'NO_META'	  => 1,

   'INSTALLER'    =>
   { CONSOLE_PROGRAM        => "cbbbike",
     CLIENT_PROGRAM         => "bbbikeclient",
     USE_CLIENT_SERVER_MODE => 0,
     USE_AUTOSTART          => undef,
     HTML_DOCUMENTATION     => "bbbike.html",
     HOMEPAGE               => $BBBike::BBBIKE_WWW,
     MODULE_EXT             => ['BBBikeXS', ($^O eq 'MSWin32' ? () : ('VirtArray')), 'Strassen-Inline', 'VectorUtil-Inline'],
     # Not included in MODULE_EXT because of build problems (how to specify
     # the needed PERL5LIB env variable?):
     # 'Strassen-Inline2', 'StrassenNetz-CNetFile'
     EXTENSIONS             => ($0 eq '/usr/local/BBBike/install.pl' &&
				$^O =~ /((free|net|open)bsd|bsdi)$/ ? 0 : 1),
     DESKTOP_ICON           => 1,
     UNIX_ICON              => "images/srtbike.xpm",
     UNIX_MINI_ICON         => "images/srtbike_mini.xpm",
     WIN_ICON               => "images/srtbike.ico",
     WIN_WWW_ICON           => "images/srtbike_www.ico",
     WIN_EXTENSIONS         => [{'-extension' => '.bbr',
				 '-name'      => 'BBBike.Route',
				 '-desc'      => 'BBBike-Route',
				 '-mime'      => "application/x-bbbike-route",
				}],
   },
  );

sub MY::top_targets {
    'all ::
	@echo "Nothing to do --- please proceed with"
	@echo "    make install"
	@echo "or type"
	@echo "    $(PERL) ./bbbike"
	@echo "to start the program without installation"

ext:
	cd ext && ${MAKE} ext PERL="${FULLPERL}"


'
}

sub MY::test {
    my $out = "test ::\n";
    if (-d "ESRI") {
	$out .= <<'EOF';
	cd ESRI && $(TEST_F) Makefile && $(MAKE) test $(PASTHRU)
EOF
    }
    if (-r "t/Makefile") {
	$out .= <<'EOF';
	cd t && $(MAKE) test PERL=$(FULLPERL)
EOF
    }
    if (-r "ext/Makefile") {
	$out .= <<'EOF'; # XXX "build" should not be here!
	cd ext && $(MAKE) build test PERL=$(FULLPERL)
EOF
    }
    if (-r "projects/www.radzeit.de/Makefile") {
	$out .= <<'EOF';
	cd projects/www.radzeit.de && $(MAKE) deploy-local
EOF
    }
    if (-r "projects/radlstadtplan_muenchen/Makefile.PL") {
	$out .= <<'EOF';
	cd projects/radlstadtplan_muenchen && $(PERL) Makefile.PL && $(MAKE) test
EOF
    }
    $out .= "\n";
    $out;
}

sub MY::install {
    my $out = "";
    my @bbbikeexe = qw(bbbike cbbbike bbbikeclient cmdbbbike smsbbbike);
    $out .= <<'EOF';
install:
	@echo "*** No installation process yet."
	@echo ""
	@sleep 1

EOF
    my($INSTALL_PREFIX, $BBBIKE_DEST_DIR);
    if (-f "/etc/debian-release") {
	print STDERR "Choosing Debian layout (/usr/lib/BBBike, executable in /usr/bin)...\n";
	$INSTALL_PREFIX = "/usr";
	$BBBIKE_DEST_DIR = "/usr/lib/BBBike";
    } elsif ($^O =~ /^(freebsd|netbsd|openbdf|bsdi|bsd386)$/) {
	print STDERR "Choosing BSD layout (/usr/local/BBBike, executable in /usr/local/bin)...\n";
	$INSTALL_PREFIX = "/usr/local"; # but better would be ${PREFIX}, which is unfortunately overriden in this Makefile
	$BBBIKE_DEST_DIR = "${INSTALL_PREFIX}/BBBike";
    } elsif (-d "/opt") {
	print STDERR "Choosing /opt layout (/opt/BBBike, executable in /usr/bin)...\n";
	$INSTALL_PREFIX = "/usr";
	$BBBIKE_DEST_DIR = "/opt/BBBike";
    } elsif (-d "/usr/local") {
	print STDERR "Choosing /usr/local layout (/usr/local/BBBike, executable in /usr/bin)...\n";
	$INSTALL_PREFIX = "/usr";
	$BBBIKE_DEST_DIR = "/usr/local/BBBike";
    } elsif ($^O eq 'MSWin32') {
	warn <<EOF;
No installation support for MSWin32 yet. Please follow the instructions in
the README file or just start the application using

    perl bbbike

or just

    bbbike

EOF
	return;
    } else {
	print STDERR "Choosing /usr layout (/usr/BBBike, executable in /usr/bin)...\n";
	$INSTALL_PREFIX = "/usr";
	$BBBIKE_DEST_DIR = "/usr/BBBike";
    }
    $out .= <<EOF;
INSTALL_PREFIX?=	$INSTALL_PREFIX
BBBIKE_DEST_DIR?=	$BBBIKE_DEST_DIR

EOF
    $out .= <<'EOF';
install-to-usr-local:
	-rm -rf ${BBBIKE_DEST_DIR}
	cp -R . ${BBBIKE_DEST_DIR}
	find ${BBBIKE_DEST_DIR} | xargs chmod ugo+r
	find ${BBBIKE_DEST_DIR} -perm -u=x | xargs chmod go+x
EOF
    for my $f (@bbbikeexe) {
	$out .= <<EOF;
	-rm -f \${INSTALL_PREFIX}/bin/$f
	ln -s \${BBBIKE_DEST_DIR}/$f \${INSTALL_PREFIX}/bin/$f
EOF
    }
    return $out;

    # XXX disabled for now --- the installer does not work with newer
    # KDE or GNOME releases
    $out .= <<'EOF';
install:
	@echo "*** This will proceed an unusual installation process."
	@echo "*** The program and data will reside in this directory."
	@echo "*** The installer will fetch dependent modules and"
	@echo "*** try to make some GUI installation (currently for KDE, GNOME and Win32"
	@echo ""
	@sleep 1
	-$(PERL) -I`pwd` -MCPAN -e "install Bundle::BBBike"
	$(PERL) install.pl
#	@echo "Copy this directory to an appropriate destination (e.g. /usr/local/BBBike)"
#	@echo "and create a symbolic link to the executable"
#	@echo "(e.g. from /usr/local/bin/bbbike to /usr/local/BBBike/bbbike)"

EOF
    $out;
}

sub MY::dist_dir {
    <<'EOF'; 
distdir : distdir_main distdir_post

distdir_main:
	$(RM_RF) $(DISTVNAME)
	$(PERLRUN) "-MExtUtils::Manifest=manicopy,maniread" \
		-e "manicopy(maniread(),'$(DISTVNAME)', '$(DIST_CP)');"

distdir_post:
	find $(DISTVNAME) -type d -exec chmod ugo+rx {} \;
	find $(DISTVNAME) -type f -exec chmod ugo+r {} \;


EOF
}


sub MY::postamble {
    use vars qw($bbbike_makefile_admin);
    $bbbike_makefile_admin = "";
    if (-e $admin_makefile) {
	if (!do $admin_makefile) {
	    die "Can't load $admin_makefile: $@";
	}
    }
    $bbbike_makefile_admin;
}

