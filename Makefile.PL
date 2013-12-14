#! /usr/bin/perl
# -*- perl -*-

use 5.005;

BEGIN {
    $^W = 0;
}

use strict;

use ExtUtils::MakeMaker;
use ExtUtils::Manifest;
use File::Basename;
use Getopt::Long;

BEGIN {
    if ($0 =~ m{make_.*bundle}) {
	chdir "..";
    }
}

use BBBikeVar;

my $action;
GetOptions('action=s' => \$action)
    or die "usage: $^X $0 [-action make_bundle|make_small_bundle|make_windist_bundle|make_cgi_bundle]";

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
use constant REQ_BBBIKE_CGI     => 2; # mandatory for a full cgi install
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
  [qw/YAML::XS	0	all	2	cgi,devel/,
   'optional für YAML-Dumps der BBBike-Route, für die Testsuite sowie fuer temp_blockings'],
  [qw/JSON::XS	0	all	2	base/,
   'optional für JSON-Dumps der BBBike-Route und diverse Serialisierungsaufgaben'],
  [qw/Kwalify	0	all	0	devel/,
   'optional für Validierung in der Testsuite'],

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
  [qw/Digest::MD5	0	all	2	cgi/,
   'für den File-Cache im CGI-Programm'],
  [qw/DB_File		0	all	2|4	base/,
   'Caching, Sessionhandling etc.'],
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
  [qw/Cairo	0	all	2	base/,
   'Erzeugung der Route als PDF-Dokument, alternativer Renderer'],
  [qw/Pango	0	all	2	base/,
   'Erzeugung der Route als PDF-Dokument, alternativer Renderer'],
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
  [qw/Date::Calc	0	all	0	devel/,
   'LogTracker plugin'],
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
  [qw/Geo::GDAL	0	all	0	base/,
   'Für das Parsen des ESRI-Projection-Formats'],
  [qw/Geo::Proj4	0	all	0	base/,
   'Für das Konvertieren von ESRI-Shapefiles'],
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
  [qw/Tk::ExecuteCommand	0	all	0	base/,
   'Bessere Fehlerberichte im temp_blockings-Editor'],
  [qw/Algorithm::Diff	0	all	0	base/,
   'Unterschiede im temp_blockings-Editor anzeigen'],
  [qw/Sort::Naturally	0	all	0	base/,
   'Für natürliches Sortieren von bbd-Dateien'],

  ## Not enabled anymore in non-advanced mode, superseded by
  ## Geo::Coder::Googlev3
  #  [qw/Geo::Coder::Google	0.06	all	0	plugin/,
  #   'Geocoding über Googlemaps (API v2)'], # alternative: Geo::Coder::GoogleMaps 0.03
  [qw/Geo::Coder::Googlev3	0	all	0	plugin/,
   'Geocoding über Googlemaps (API v3)'],
  [qw/Geo::Coder::Bing	0.10	all	0	plugin/,
   'Geocoding über Bing'],
  [qw/Geo::Cloudmade	0	all	0	plugin/,
   'Geocoding über Cloudmade'],
  [qw/Geo::Coder::OSM	0	all	0	plugin/,
   'Geocoding mit OpenStreetMap-Daten'],
  [qw/Flickr::API	0	all	0	plugin/,
   'Flickr-Bilder in BBBike anzeigen'],

  [qw/Image::Info	1.32	all	0	test/], # 1.32 needed, otherwise bbbikedraw.t may fail
  [qw/Test::More	0	all	0	test/],
  [qw/Test::Differences	0	all	0	test/],
  [qw/WWW::Mechanize	0	all	2	test/,
   'Für Testen des CGI-Interfaces'],
  [qw/WWW::Mechanize::FormFiller	0	all	2	test/,
   'Für Testen des CGI-Interfaces'],
  [qw/Devel::Leak	0	all	0	test/,
   'Für Memory-Leak-Tests'],
  [qw/Text::Table	0	all	0	devel/],
  [qw/Text::Unidecode	0	all	0|4	devel/,
   'Für das Neu-Erzeugen der .bbd-Dateien in data; Fallback für internationale Texte in PDFs'],
  [qw/Data::Compare	0	all	0	devel/,
   'Für das Neu-Erzeugen der .bbd-Dateien in data'],
  [qw/HTML::FormatText	0	all	0	devel/,
   'Für VMZTool'],
  [qw/Math::Round	0	all	0	devel/,
   'Für downloadosm -round'],

  # CGI 3.43 which comes with Debian has a couple of problems (self
  # urls have port, encoding problems with params...)
  (!eval { require CGI; $CGI::VERSION < 3.43 || $CGI::VERSION >= 3.46 } ?
   [qw/CGI		3.46	all	2	cgi/,
    'CGI-Handling'] : ()),

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

my $admin_makefile = "./Makefile_admin_PL";

my $make_bundle;
my $type_bundle = 0;
if ($action) {
    if ($action eq 'make_bundle') {
	$make_bundle = "normal";
	$type_bundle = 0;
    } elsif ($action eq 'make_small_bundle') {
	$make_bundle = "small";
	$type_bundle = 0;
    } elsif ($action eq 'make_cgi_bundle') {
	$make_bundle = "cgi";
	$type_bundle = REQ_BBBIKE_CGI;
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
    exit make_cgi_bundle()     if $make_bundle eq 'cgi';
    exit make_windist_bundle() if $make_bundle eq 'windist';
    die "Should not happen: unhandled value <$make_bundle>";
}

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
	    if (($ENV{TRAVIS}||'') eq 'true') { # XXX actually, check for "batch environment where difficult modules cannot be installed easily"
		next if $_->[REQTABLE_MODNAME] =~ m{^(
							Image::Magick # needs exact matching imagemagick library version
						    |   Geo::GDAL     # dito
						    )$}x;
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

sub make_cgi_bundle {
    make_general_bundle(REQ_BBBIKE_CGI, "BBBike_cgi.pm");
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
					    REQ_BBBIKE_CGI,     "cgi",
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

.PHONY: ext
ext:
	cd ext && ${MAKE} ext PERL="${FULLPERL}"


'
}

sub MY::test {
    my $is_travis = ($ENV{TRAVIS}||'') eq 'true';
    my $out = "test ::\n";

    # XXX This is some kind of hack, travis skips the "make all" step (rightly, I should fix my deps!)
    if ($is_travis && -r "ext/Makefile") {
	$out .= <<'EOF';
	$(MAKE) ext PERL=$(FULLPERL)
EOF
    }

    if (-d "ESRI") {
	$out .= <<'EOF';
	cd ESRI && $(TEST_F) Makefile && $(MAKE) test $(PASTHRU)
EOF
    }
    if (-r "t/Makefile") {
	if ($is_travis) { # XXX actually, should check for no-cgi setup
	    $out .= <<'EOF';
	cd t && BBBIKE_TEST_FOR_LIVE=1 $(MAKE) test PERL=$(FULLPERL)
EOF
	} else {
	    $out .= <<'EOF';
	cd t && $(MAKE) test PERL=$(FULLPERL)
EOF
	}
    }
    if (-r "ext/Makefile") {
	$out .= <<'EOF'; # XXX "build" should not be here!
	cd ext && $(MAKE) build test PERL=$(FULLPERL)
EOF
    }
    if (0 && -r "projects/bbbike.de-hosteurope/Makefile") {
	$out .= <<'EOF';
	cd projects/bbbike.de-hosteurope && $(MAKE) deploy-local
EOF
    }
    if (0 && -r "projects/radlstadtplan_muenchen/Makefile.PL") {
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
    if (-f "/etc/debian-release" || -f "/etc/debian_version") {
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
REAL_BBBIKE_DEST_DIR?=	\$(BBBIKE_DEST_DIR)

do--symlink-bbbikeexe:
	[ -d \${INSTALL_PREFIX}/bin ] || mkdir -p \${INSTALL_PREFIX}/bin
EOF
    for my $f (@bbbikeexe) {
	$out .= <<EOF;
	-rm -f \${INSTALL_PREFIX}/bin/$f
	ln -s \${REAL_BBBIKE_DEST_DIR}/$f \${INSTALL_PREFIX}/bin/$f
EOF
    }

    $out .= <<'EOF';

install-to-usr-local:	do--install-to-usr-local do--symlink-bbbikeexe

do--install-to-usr-local:
	-rm -rf ${BBBIKE_DEST_DIR}
	cp -R . ${BBBIKE_DEST_DIR}
	find ${BBBIKE_DEST_DIR} | xargs chmod ugo+r
	find ${BBBIKE_DEST_DIR} -perm -u=x | xargs chmod go+x

install-using-eui:	distdir do--install-using-eui do--symlink-bbbikeexe

do--install-using-eui:
	-rm -rf ${BBBIKE_DEST_DIR}
	[ -d ${BBBIKE_DEST_DIR} ] || mkdir -p ${BBBIKE_DEST_DIR}
	$(PERL) -MExtUtils::Install -e 'install({ "$(DISTVNAME)" => "$(BBBIKE_DEST_DIR)" }, $(VERBINST), 0, 0, ["/debian/.*"], 1)'

install-freedesktop:
	[ -d ${INSTALL_PREFIX}/share/applications ] || mkdir -p ${INSTALL_PREFIX}/share/applications
	for size in 128x128 72x72 64x64 48x48 32x32 16x16 scalable; do \
	    [ -d ${INSTALL_PREFIX}/share/icons/hicolor/$$size/apps ] || mkdir -p ${INSTALL_PREFIX}/share/icons/hicolor/$$size/apps; \
	done
	perl -Ilib -MText::ScriptTemplate -e '$$t=Text::ScriptTemplate->new; $$t->setq(BBBIKE_ROOTDIR => "$(REAL_BBBIKE_DEST_DIR)"); print $$t->load("kde/bbbike.desktop.tst")->fill' > ${INSTALL_PREFIX}/share/applications/bbbike.desktop~
	mv ${INSTALL_PREFIX}/share/applications/bbbike.desktop~ ${INSTALL_PREFIX}/share/applications/bbbike.desktop
	install -m644 images/srtbike114.png   ${INSTALL_PREFIX}/share/icons/hicolor/128x128/apps/bbbike.png
	install -m644 images/srtbike72.png    ${INSTALL_PREFIX}/share/icons/hicolor/72x72/apps/bbbike.png
	install -m644 images/srtbike57.png    ${INSTALL_PREFIX}/share/icons/hicolor/64x64/apps/bbbike.png
	install -m644 images/srtbike48a.png   ${INSTALL_PREFIX}/share/icons/hicolor/48x48/apps/bbbike.png
	install -m644 images/srtbike32.xpm    ${INSTALL_PREFIX}/share/icons/hicolor/32x32/apps/bbbike.xpm
	install -m644 images/srtbike16.xpm    ${INSTALL_PREFIX}/share/icons/hicolor/16x16/apps/bbbike.xpm
	install -m644 images/srtbike_logo.svg ${INSTALL_PREFIX}/share/icons/hicolor/scalable/apps/bbbike.svg

EOF

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

