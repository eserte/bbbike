# -*- perl -*-
# $Id: Makefile.PL,v 1.86 2003/07/06 20:20:36 eserte Exp eserte $

BEGIN {
    $^W = 0;
}

use ExtUtils::MakeMaker;
use ExtUtils::Manifest;
use File::Basename;

use lib ".."; # falls als make_bundle gestartet

use BBBikeVar;

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

# Table of prerequisites:
# Name, Version, OS, Req/CoReq, description token, long description
@req_table =
 ([qw/Tk		402.002	all	1	gui/,
   { de => 'das absolute Muss!',
     en => 'this one is really necessary!'
   }],
  #in dist: [qw/Tk::Getopt	0.40	all	0	gui/],
  #in dist: [qw/Tk::ContextHelp	0	unix	0	gui/],
  [qw/Tk::FireButton	0	all	0	gui/,
   '"Firebutton"-Funktionalität für die Windrose'],
  [qw/Tk::Pod		2.8	all	0	gui/,
   { de => 'Online-Hilfe', en => 'online help' }],
  [qw/Tk::FontDialog	0	all	0	gui/,
   'zum Ändern des Zeichensatzes aus dem Programm heraus'],
  [qw/Tk::JPEG		0	all	0	gui/],
#  [qw/X11::Protocol	0.04	unix	0	gui/], # not used anymore
  [qw/Tie::Watch	0	all	0	gui/],
  [qw/Tk::HistEntry	0	all	0	gui/],
  [qw/Tk::Stderr	0	all	0	gui/,
   'optionales Redirect von Fehlermeldungen in ein Tk-Fenster'],

  [qw/LWP::UserAgent	0	all	0	www/,
   'für die WWW-Verbindungen (Stadtplan und Wetterbericht)'],
  [qw/Image::Magick	0	all	0	www/,
   'für Bildmanipulationen beim Radar-Bild der FU'],

  [qw/Apache::Session::DB_File	0	all	0	cgi/,
   'optionale Session-Verwaltung für das CGI-Programm'],
  [qw/XML::SAX	0	all	0	cgi/,
   'CPAN.pm kann XML::SAX nicht über XML::Simple automatisch installieren'],
  [qw/XML::Simple	0	all	0	cgi/,
   'optional für XML-Dumps der BBBike-Route'],
  [qw/YAML	0	all	0	cgi/,
   'optional für YAML-Dumps der BBBike-Route'],

  [qw/Mail::Send	0	unix	0	mail/,
   'falls man aus bbbike heraus E-Mails mit der Routenbeschreibung verschicken will'],

  [qw/String::Approx	2.7	all	0	base/,
   'oder man verwendet agrep (mindestens Version 3.0)'],
  [qw/Storable		0	all	0	base/,
   'für das Caching beim CGI-Programm'],
  [qw/MLDBM		0	all	0	base/],
  [qw/GD		1.18	all	0	base/,
   'zum On-the-fly-Erzeugen von Grafiken beim CGI-Programm'],
  [qw/Chart::ThreeD::Pie	0	all	0	base/,
   'Tortendiagramme in der Statistik'],
  [qw/List::Permutor	0	all	0	base/,
   'Für das Problem des Handlungsreisenden'],
  [qw/PDF::Create	0.06	all	0	base/,
   'Erzeugung der Route als PDF-Dokument --- die neueste Version ist nur auf sourceforge erhältlich! (http://prdownloads.sourceforge.net/perl-pdf/perl-pdf-0.06.1b.tar.gz?download)'],
  #in dist: [qw/BikePower	0	all	0	base/],

  [qw/BSD::Resource	0	unix	0	base/], # really only BSD

  [qw/Win32::API	0	win	0	base/],
  [qw/Win32::Registry	0	win	0	base/],
  [qw/Win32::DDE::Client 0	win	0	base/],
  [qw/Win32::Shortcut	0	win	0	base/],

  [qw/Devel::Peek	0	all	0	devel/],
  [qw/Statistics::Descriptive	0	all	0	devel/],
  [qw/Math::MatrixReal	0	all	0	devel/],
  [qw/Class::Accessor	0	all	0	base/,
   'für GPS::GpsmanData, die ESRI-Module etc.'],
  [qw/Template	0	all	0	devel/,
   'für BBBikeDraw::MapServer'],
  [qw/Inline::C		0	all	0	base/,
   'für den schnelleren Suchalgorithmus, siehe ext/Strassen-Inline'],
  [qw/Pod::Usage	0	all	0	devel/,
   { de => 'für das Ausgeben der \'Usage\' in einigen Entwicklungs-Tools',
     en => 'for printing the usage in some development tools'
   }],
  [qw/Palm::PalmDoc	0	all	0	base/,
   'für das Erzeugen von palmdoc-Dateien mit der Routenbeschreibung'],
  [qw/Astro::Sunrise	0	all	0	base/,
   'Anzeige des Sonnenuntergangs/-aufgangs im Info-Fenster'],
  [qw/File::ReadBackwards 0	all	0	devel/,
   'LogTracker plugin'],
  [qw/Date::Calc	0	all	0	devel/,
   'LogTracker plugin'],
  [qw/XBase		0	all	0	devel/,
   'Erzeugen der Mapserver- oder anderer ESRI-Dateien'],
 );

# EXE prerequisites ####################################################
# standard Unix: uname, who, tee, at, diff, zcat, ping
# BSD Unix:      leave
# extra:         enscript, gv, ghostview, gs, netpbm-utils, cjpeg, agrep,
#                netscape, socket
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

my(%prereq, @prereq);
{
    my(@res) = build_prereq($os);
    %prereq = %{$res[0]};
    @prereq = @{$res[1]};
}

# call before maniread!
exit make_bundle()       if $0 =~ /make_bundle/;
exit make_small_bundle() if $0 =~ /make_small_bundle/;
exit make_pi_osd('win')
    if $0 =~ /make_pi_osd/ && defined $ARGV[0] && $ARGV[0] eq 'win';
exit make_pi_osd()       if $0 =~ /make_pi_osd/;
exit make_small_pi_osd('win')
    if $0 =~ /make_small_pi_osd/ && defined $ARGV[0] && $ARGV[0] eq 'win';
exit make_small_pi_osd()      if $0 =~ /make_small_pi_osd/;

$fileref = ExtUtils::Manifest::maniread();
$exe_files = ['bbbike',
	      'bbbikeapplet',
	      'bbbikeclient',
	      'cgi/bbbike.cgi',
	      'cgi/runbbbikecgi',
	      'cgi/httpi',
	      'cgi/wapbbbike.cgi',
	      'cmdbbbike',
	      'smsbbbike',
	      'cbbbike'];
foreach (@$exe_files) { $exe_files{$_}++ }
while(my($k,$v) = each %$fileref) {
    next if $k =~ /\.bat$/;
    $pm{$k} = '$(INST_LIB)/'. $k unless $exe_files{$k};
}

return 1 if $ENV{PERL_FROM_EXTERNAL};

sub build_prereq {
    my $os = shift;
    my(%prereq, @prereq);
    foreach (@req_table) {
	my(%for_os) = map { ($_, 1) } split ",", $_->[REQTABLE_OS];
	if ($for_os{$os} || $for_os{"all"}) {
	    $prereq{$_->[REQTABLE_MODNAME]} = $_->[REQTABLE_VERSION];
	    push @prereq, $_;
	}
    }
    (\%prereq, \@prereq);
}

sub make_bundle {
    make_general_bundle(0, "BBBike.pm");
}

sub make_small_bundle {
    make_general_bundle(1, "BBBike_small.pm");
}

sub make_general_bundle {
    my $type = shift;
    my $file = shift;
    open(TMPL, "BBBike.pm.tmpl") or die "Can't open template: $!";
    open(BUNDLE, ">$file") or die "Can't write bundle $file: $!";
    while(<TMPL>) {
	print BUNDLE $_;
	if (/^=head1\s+CONTENTS/) {
	    print BUNDLE "\n";
	    foreach my $prereq (@prereq) {
		next if $prereq->[REQTABLE_REQ] < $type;
		print BUNDLE $prereq->[REQTABLE_MODNAME];
		if ($prereq->[REQTABLE_VERSION]) {
		    print BUNDLE " " . $prereq->[REQTABLE_VERSION];
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
		    print BUNDLE "\t- " . $msg;
		}
		print BUNDLE "\n\n";
	    }
	}
    }
    close BUNDLE;
    close TMPL;
    0;
}

sub make_pi_osd {
    my $os = shift || 'unix';
    make_general_pi_osd(0, "BBBike-$os.osd", $os);
}

sub make_small_pi_osd {
    my $os = shift || 'unix';
    make_general_pi_osd(1, "BBBike_small-$os.osd", $os);
}

sub make_general_pi_osd {
    my $type = shift;
    my $file = shift;
    my $os   = shift;

    my(%prereq, @prereq);
    {
	my(@res) = build_prereq($os);
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
 <CODEBASE HREF="http://prdownloads.sourceforge.net/bbbike/BBBike-$BBBike::VERSION.tar.gz" />
 <INSTALL EXEC="perl">BBBike-$BBBike::VERSION/install.pl</INSTALL>
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

######################################################################
# POD files
#
# grab a good pod2html XXX this is somewhat hacky
my $bbbike_html_rule;
$ENV{PATH} .= ":/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/scripts";
my $pod2html = is_in_path("mpod2html");
if (defined $pod2html) {
    $pod2html = "$^X -Mblib=/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/ $pod2html";
}
#XXX $pod2html = 'perl -Mblib=/usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43 /usr/local/src/CPAN/new.build/new.MarekPodHtml-0.43/blib/script/mpod2html -css html/bbbikepod.css';
my $htmlroot = "--htmlroot http://www.perldoc.com/cpan";

use constant POD_POD   => 0;
use constant POD_HTML  => 1;
use constant POD_TITLE => 2; # XXX do not put double quotes into title
#        podfile         htmlfile             title
my @pods = 
    ([qw(bbbike.pod      bbbike.html),        "Dokumentation für BBBike"],
     [qw(README          README.html),        "README für BBBike"],
     [qw(README.english  README.english.html),"README for BBBike"],
     [qw(bbd.pod         bbd.html),           "BBD file format"],
     );
my $all_pods = join " ", map { $_->[POD_POD] } @pods;
my $all_html = join " ", map { $_->[POD_HTML] } @pods;
if (defined $pod2html) {
    # XXX here no $htmlroot
    $bbbike_html_rule = <<EOF;
$all_html:	$all_pods
	$pod2html -tocname http://bbbike.sourceforge.net/index -notoc $all_pods
	\$(CLEAN_POD2HTML)
	chmod ugo+r $all_html podindex.html
EOF
} else {
    my $pod2html;
    if (-x "/usr/perl5.7.2/bin/pod2html") {
	# XXX --htmlroot with bugs: one level module names are not linked
	$pod2html = "/usr/perl5.7.2/bin/pod2html $htmlroot -css html/bbbikepod.css --header";
    } elsif (-x "/usr/perl5.6.0/bin/pod2html") {
	$pod2html = "/usr/perl5.6.0/bin/pod2html $htmlroot";
    } else {
	$pod2html = "pod2html";
    }
    $bbbike_html_rule = "";
    for my $poddef (@pods) {
	$bbbike_html_rule .= <<EOF
$poddef->[POD_HTML]: $poddef->[POD_POD]
	$pod2html --title "$poddef->[POD_TITLE]" $poddef->[POD_POD] > $poddef->[POD_HTML]
	\$(CLEAN_POD2HTML)

EOF
    }
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

   'INSTALLER'    =>
   { CONSOLE_PROGRAM        => "cbbbike",
     CLIENT_PROGRAM         => "bbbikeclient",
     USE_CLIENT_SERVER_MODE => 0,
     USE_AUTOSTART          => undef,
     HTML_DOCUMENTATION     => "bbbike.html",
     HOMEPAGE               => $BBBike::BBBIKE_WWW,
     MODULE_EXT             => ['BBBikeXS', ($^O eq 'MSWin32' ? () : ('VirtArray')), 'Strassen-Inline'],
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
	@echo "    $(PERL) bbbike"
	@echo "to start the program"

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
	cd t && $(MAKE) test
EOF
    }
    if (-r "projects/www.radzeit.de/Makefile") {
	$out .= <<'EOF';
	cd projects/www.radzeit.de && $(MAKE) deploy-local
EOF
    }
    $out .= "\n";
    $out;
}

sub MY::install {
    <<'EOF';
install:
	@echo "*** No installation process yet."
	@echo ""
	@sleep 1

EOF
    return;

    # XXX disabled for now --- the installer does not work with newer
    # KDE or GNOME releases
    <<'EOF';
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
}

sub MY::postamble {
    my(@bundled_perl_module_dists) =
	qw(Tk-ContextHelp Tk-Enscript Tk-Getopt Tk-Autoscroll Tk-PathEntry
	   Tk-CanvasFig BikePower savevars GD-Convert Tk-Splash
	   Http Msg
	   Tk-SREZIC Tk-CanvasBalloon Tk-CanvasUtil Tk-LogScale
	   Tk-ColorFlowChooser Tk-LayerEditor Tk-Placement
	   Tk-StippleLine Tk-WidgetDump Win32Util WWWBrowser
	  );
    my $EXTMODCPANTOP = "$ENV{HOME}/src/CPAN";
    my $EXTMODPERLTOP = "$ENV{HOME}/src/perl";
    my(@EXTMODCPAN, @EXTMODPERL);
    for my $module_dist (@bundled_perl_module_dists) {
	if (-e "$EXTMODCPANTOP/$module_dist") {
	    push @EXTMODCPAN, $module_dist;
	} elsif (-e "$EXTMODPERLTOP/$module_dist") {
	    push @EXTMODPERL, $module_dist;
	} else {
	    warn "Can't find $module_dist neither in $EXTMODCPANTOP nor in $EXTMODPERLTOP\n";
	}
    }
    my $EXTMODCPAN = join(" ", @EXTMODCPAN);
    my $EXTMODPERL = join(" ", @EXTMODPERL);

    $bbbike_makefile_admin = "";
    my $admin_makefile = "./Makefile.admin.PL";
    if (-e $admin_makefile) {
	if (!do $admin_makefile) {
	    die "Can't load $admin_makefile: $@";
	}
    }
    <<'EOF'

# DISTRIBUTIONS ##########################################################

TMPDIR?=	/tmp
BBBIKE_TMP=     $(TMPDIR)/$(DISTNAME)

EOF
.
    "DEVEL_ARCH=       \$(TMPDIR)/\$(DISTVNAME)-" .
                        sprintf("%04d%02d%02d",
                               sub { $_[5]+1900, $_[4]+1, $_[3] }->(localtime)
                              ) . "-devel.zip\n\n" .

    <<'EOF'
# bbbike.cgi #####################

CGI_ARCH=	$(TMPDIR)/bbbikecgi.zip
CGI2_ARCH_PROG= $(TMPDIR)/bbbikecgi_prog.zip
CGI2_ARCH_WEB=  $(TMPDIR)/bbbikecgi_web.zip

# CGI-Distribution: alle Dateien in einer Hierarchie
cgidist: cgidistdir
	$(RM_F) $(CGI_ARCH)
	cd $(BBBIKE_TMP); $(ZIP) $(ZIPFLAGS) $(CGI_ARCH) $(DISTNAME)

cgidistdir:   MANIFEST.bbbikecgi
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"

cgidistdir-berlin-potsdam:   MANIFEST.bbbikecgi
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e '$$files = maniread(q{MANIFEST.bbbikecgi}); \
		    for (keys %$$files) { \
		      if (m|^data/(.*)|) { $$data->{$$1}=""; delete $$files->{$$_} } \
		    } \
		    manicopy($$files,q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)}); \
		    chdir "data_berlin_and_potsdam" or die; \
		    manicopy($$data,q{$(BBBIKE_TMP)/$(DISTNAME)/data}, q{$(DIST_CP)}); \
'

# Alternative: Programme unter cgi-bin, Rest in ein BBBike-Verzeichnis
cgidist2:
	$(RM_F) $(CGI2_ARCH_PROG) $(CGI2_ARCH_WEB)
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi.prog}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"
	$(MV) $(BBBIKE_TMP)/$(DISTNAME)/cgi/* $(BBBIKE_TMP)
	cd $(BBBIKE_TMP); $(ZIP) $(ZIPFLAGS) $(CGI2_ARCH_PROG) .
	$(RM_RF) $(BBBIKE_TMP)
	$(MKPATH) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) \
		-MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(q{MANIFEST.bbbikecgi.web}),q{$(BBBIKE_TMP)/$(DISTNAME)}, q{$(DIST_CP)});"
	cd $(BBBIKE_TMP); $(ZIP) $(ZIPFLAGS) $(CGI2_ARCH_WEB) $(DISTNAME)

# In beiden MANIFEST-Dateien sind images enthalten, weil images sowohl vom
# Browser aus, als auch bei der PNG/GIF-Erstellung verwendet werden.
MANIFEST.bbbikecgi:	MANIFEST.bbbikecgi.prog MANIFEST.bbbikecgi.web
	echo "# DO NOT EDIT! Generated by Makefile" > MANIFEST.bbbikecgi
	cat MANIFEST.bbbikecgi.prog MANIFEST.bbbikecgi.web >> MANIFEST.bbbikecgi

cgidist-cs:	cgidistdir-berlin-potsdam
	cp -fp cgi/bbbike-cs.cgi.config $(BBBIKE_TMP)/$(DISTNAME)/cgi/bbbike.cgi.config

# cbbbike #####################

CBBBIKE_ARCH=      $(TMPDIR)/cbbbike.zip
CBBBIKE_DOS_ARCH=  $(TMPDIR)/cbbbike_dos.zip
RECODE=            recode

.PHONY: ChangeLog develdist makepatch cbbbikedist cbbbikedistdit
.PHONY: cbbbikedosdist cbbbikedosdistdir cgidist cgidistdir
.PHONY: ext distdir2

cbbbikedist: cbbbikedistdir
	$(RM_F) $(CBBBIKE_ARCH)
	cd $(TMPDIR); $(ZIP) $(ZIPFLAGS) $(CBBBIKE_ARCH) $(DISTNAME)

cbbbikedistdir:
	$(RM_RF) $(BBBIKE_TMP)
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -MExtUtils::Manifest=manicopy,maniread \
                -e "manicopy(maniread(\'MANIFEST.cbbbike\'),\'$(BBBIKE_TMP)\', \'$(DIST_CP)\');"

# cbbbikedosdist: wie cbbbikedist, nur wird noch zusätzlich mit recode
# nach cp850 (besser als cp437) konvertiert
cbbbikedosdist: cbbbikedosdistdir
	$(RM_F) $(CBBBIKE_DOS_ARCH)
	cd $(TMPDIR); $(ZIP) $(ZIPFLAGS) $(CBBBIKE_DOS_ARCH) $(DISTNAME)

cbbbikedosdistdir: cbbbikedistdir
	cd $(BBBIKE_TMP); chmod u+w *; $(RECODE) latin1:cp850 *.pm cbbbike; chmod 755 cbbbike
	cd $(BBBIKE_TMP)/data; chmod u+w *; $(RECODE) latin1:cp850 *

distdir2:
	umask 022 && $(MAKE) $(MAKEFLAGS) distdir
	# for testing with extension based systems like Windows
	cd $(DISTVNAME) && ln -s bbbike bbbike.pl
	-rm -f /tmp/$(DISTVNAME)
	ln -s `pwd`/$(DISTVNAME) /tmp/$(DISTVNAME)

develdist:
	rm -rf $(DEVEL_ARCH)
	cd ..; $(ZIP) $(ZIPFLAGS) $(DEVEL_ARCH) bbbike \
	    -x \*.tar.gz \
	    -x \*/old/\* \
	    -x \*/cache/\* \
	    -x \*/tmp/\* \
	    -x \*/vbbdata/\* \
	    -x \*/c/minibbbike \
	    -x \*/datagdf_berlin/\* \
	    -x \*/datagdf_brandenburg/\* \
	    -x \*/datagdf_mitte/\* \
	    -x \*/datagdf_*/\* \
	    -x \*/datagdf/\* \
	    -x \*/diplom/\* \
	    -x \*/CRASH/\* \
	    -x \*/distfiles/\* \
	    -x \*/i386-freebsd/\* \
            -x \*/i386-freebsd-64int/\* \
            -x \*/i386-freebsd-thread/\* \
	    -x \*/i586-linux/\* \
	    -x \*/blib \
	    -x \*/blib/\* \
	    -x \*/pm_to_blib \
 	    -x \*/.xvpics/\* \
	    -x \*/misc/adressen/\* \
	    -x \*/misc/Berlin_Mitte.gdf \
	    -x \*/palm/test/\* \
	    -x \*/palm/test2/\* \
	    -x \*/projects/\* \
	    -x \*/vbbbike/vbbbike \
	    -x \*.o \
	    -x \*.so \
	    -x \*.bs \
	    -x \*.old \
	    -x \*.core \
	    -x \*.out \
	    -x \*.grc \
	    -x \*.bin \
	    -x \*/#*# \
	    -x \*.gdbinit \
	    -x \*.bak \
	    -x \*~

win32sdist:
	./miscsrc/win32sdist

predist:
	cd data; ${MAKE}
	${MAKE} generatemods
	${MAKE} extmod
	${MAKE} linkextmod
	${MAKE} bbbikedoc
	${MAKE} distcheck
	${MAKE} distdir
	${MAKE} bundles
	@echo check bbbike in BBBike-$(VERSION) directory

# DOCUMENTATION ##########################################################

CLEAN_POD2HTML=$(RM_F) pod2html-*cache pod2htm?.?~~

STRPP=	strpp

README README.english:	README.spp BBBikeVar.pm
	${STRPP} --dir=. README.spp

EOF
. $bbbike_html_rule . <<'EOF'

clean_pod2html:

EOF
. "bbbikedoc:	README README.english $all_html\n" . <<'EOF'

# XXX this will fail if there is no symlink to the original libexec position
ChangeLog:
	rcs2log `find . -name "*,v" -a ! -path "./projects/*" -a ! -path "./misc/gps_data/*" -a ! -path "./Attic/*"` > ChangeLog

clean_cache:
	echo rm -rf cache/*

# PORTS, BINDISTS...####################################################

fbsdport:
	cd port/freebsd; env TMPDIR=$(TMPDIR) ./mkport.pl

fbsdport-distfiles-link:
	[ -d /usr/ports/distfiles ] && \
	[ -w /usr/ports/distfiles ] && \
	[ ! -e /usr/ports/distfiles/BBBike-$(VERSION).tar.gz ] && \
	ln -s ${.CURDIR}/distfiles/BBBike-$(VERSION).tar.gz /usr/ports/distfiles || \
	exit 0

fbsdportdiff: fbsdport
	-cd $(TMPDIR); diff --new-file -u /usr/ports/german/BBBike BBBike > $(TMPDIR)/bbbike-freebsdport.diff

WINBINDISTDIR=$(TMPDIR)/BBBike-$(VERSION)-Windows
# XXX use another bbbike.bat/setup.bat if activeperl-613 would be used...
WINPERLBIN=$(HOME)/src/binperl/sieperl-5.6.1
WINBINDIST=$(WINBINDISTDIR).zip

winbindist-pre:
	rm -rf $(WINBINDISTDIR)
	umask 022; mkdir $(WINBINDISTDIR)
	umask 022; cp -Rp $(WINPERLBIN) $(WINBINDISTDIR)
	mv $(WINBINDISTDIR)/`basename $(WINPERLBIN)` $(WINBINDISTDIR)/windows
	umask 022; if [ -r distfiles/BBBike-$(VERSION).tar.gz ] ; then \
	    cat distfiles/BBBike-$(VERSION).tar.gz | (cd $(WINBINDISTDIR); tar xfvz - ); \
	else \
	    cp -Rp BBBike-$(VERSION) $(WINBINDISTDIR); \
	fi
	mv $(WINBINDISTDIR)/BBBike-$(VERSION) $(WINBINDISTDIR)/bbbike
	umask 022; cp -p cdrom/windows/autorun.inf \
	      cdrom/windows/bbbike.bat \
	      cdrom/windows/setup.bat \
	      cdrom/windows/setup.pl \
	    $(WINBINDISTDIR)
# put this again to the distribution if it really works!
#	      cdrom/windows/setup.exe

winbindist: winbindist-pre
	cd $(WINBINDISTDIR)/..; umask 022; zip -r $(WINBINDIST) `basename $(WINBINDISTDIR)`
	chmod 644 $(WINBINDIST)

#XXX	[ -d /usr/ports/distfiles -a ! -l /usr/ports/distfiles/BBBike-$(VERSION)-Windows.zip ] && ln -s 

########################################################################

alldist: bbbikedoc dist dist_mv makepatch fbsdport fbsdport-distfiles-link \
	 winbindist ChangeLog

dist_mv:
	mv -i BBBike-$(VERSION).tar.gz distfiles

BACKUP_FILE=	/home5/bak/bbbike-devel.tar.gz

backup:
	-[ -f ${BACKUP_FILE} ] && mv -f ${BACKUP_FILE} ${BACKUP_FILE}~
	cd ..; tar -c -v -z -f ${BACKUP_FILE} --exclude "*.tar.gz" --exclude "*patch.gz" --exclude "*~" bbbike

# XXX Problem: binary files (xdelta? uuencode? nix?)
makepatch:
#	./miscsrc/mymakepatch.pl $(NAME)

rcslabel:
	$(PERL) -I$(PERL_ARCHLIB) -I$(PERL_LIB) -MExtUtils::Manifest=maniread \
		-e "@all = keys %{ maniread() };" \
		-e 'print("Executing $(RCS_LABEL) ...\n"); system("$(RCS_LABEL) @all");'

autoload:
	./miscsrc/make_autoload.pl -dd -f \
	    Strassen/Core.pm Strassen/Fast.pm Strassen/Kreuzungen.pm \
	    Strassen/MultiBezStr.pm Strassen/MultiStrassen.pm \
	    Strassen/Strasse.pm Strassen/StrassenNetz.pm Strassen/Util.pm

# Pfad zum mymake-Skript, das Makefile.PL's für ~/lib/perl erzeugt
# Da vieler meiner Skripte Test.pm verwenden, wird das nicht mit 5.004 gehen
EOF
		    . "MYEXTMODMAKE=	\$(HOME)/src/mymake -perl $^X\n"
		    . <<EOF
# normales Erzeugen mit: \$(FULLPERL) Makefile.PL
# "offizielle" Module
EXTMODCPANTOP=	$EXTMODCPANTOP
EXTMODCPAN=	$EXTMODCPAN
# "experimentelle" Module
EXTMODPERLTOP=	$EXTMODPERLTOP
EXTMODPERL=	$EXTMODPERL

EOF
		    . <<'EOF'

echoextmodcpantop:
	@echo $(EXTMODCPANTOP)

echoextmodcpan:
	@echo $(EXTMODCPAN)

echoextmodperltop:
	@echo $(EXTMODPERLTOP)

echoextmodperl:
	@echo $(EXTMODPERL)

# baut und installiert die externen Module wie BikePower etc.
# verwendet Xfvb oder Xnest
# XXX testen, ob man überhaupt einen X-Server hat
extmod:
#	Xvfb :121 & \
	Xnest -geometry 640x400 :121 & \
	_XVFB_PID=$$!; \
	DISPLAY=:121; \
	for i in $(EXTMODCPAN); do \
	    echo $$i; \
	    cd $(EXTMODCPANTOP)/$$i; \
		$(MYEXTMODMAKE) && \
		make && \
		BATCH=yes make test && \
		make install; \
	done; \
	for i in $(EXTMODPERL); do \
	    echo $$i; \
	    cd $(EXTMODPERLTOP)/$$i; \
		$(MYEXTMODMAKE) && \
		make && \
		BATCH=yes make test && \
		make install; \
	done; \
	echo Kill process $$_XVFB_PID; \
	kill -TERM $$_XVFB_PID
EOF
. <<EOF

linkextmod:
	$^X ./miscsrc/link_ext_mod.pl -v
EOF
. <<'EOF'

ext:
	cd ext; ${MAKE} ext

generatemods: Strassen/Generated.pm

bundles:
	if [ ! -h Bundle/make_bundle ] ; then \
	    ln -s ../Makefile.PL Bundle/make_bundle; \
	fi
	if [ ! -h Bundle/make_small_bundle ] ; then \
	    ln -s ../Makefile.PL Bundle/make_small_bundle; \
	fi
EOF
.
"	cd Bundle; $^X make_bundle; $^X make_small_bundle; \\
		   $^X make_pi_osd unix; $^X make_pi_osd win; \\
		   $^X make_small_pi_osd unix; $^X make_small_pi_osd win
" . <<'EOF'

Strassen/Generated.pm: Strassen/Generated_src.pm Strassen.pm
	-rm -f Strassen/Generated.pm
	echo "1;" > Strassen/Generated.pm
	cd Strassen && perl5.00503 Generated_src.pm
	perl5.00503 -c Strassen/Generated_src.pm
	chmod ugo+r,-w Strassen/Generated.pm

echoversion:
	@echo 1>&2 This rule is obsolete ... use BBBikeVar.pm
	@echo $(VERSION)

# find perl scripts and modules
FIND_PERL_SCRIPTS=-type f -a \( -name "*.pm" -o -name "*.pl" -o -name "*.cgi" -o -name "bbbike" -o -name "cbbbike" \)

# Create a crypted perl distribution. The generated scripts should be called
# using ~/private/src/decrypt/perl.
encrypt:
	cd $(TMPDIR) && tar xfvz ${.CURDIR}/distfiles/$(DISTVNAME).tar.gz
	cd $(HOME)/private/src/decrypt && find $(TMPDIR)/$(DISTVNAME) $(FIND_PERL_SCRIPTS)  -print -exec ./encrypt {} \;

# Create a mangled, comment-less, pod-less minimal version of the script
# and modules. Savings are minimal: about 10% space for the distribution,
# about 1s for startup and nearly no RAM benefits.
mangle:
	cd $(TMPDIR) && tar xfvz ${.CURDIR}/distfiles/$(DISTVNAME).tar.gz
	cd $(TMPDIR)/$(DISTVNAME) && \
	    find . $(FIND_PERL_SCRIPTS) -print \
		-exec mv {} {}~ \; \
		-exec perltidy -t -mangle -dac -dp {}~ -o {} \; \
		-exec rm -f {}~ \;

EOF
. $bbbike_makefile_admin
;
}

# REPO BEGIN
# REPO NAME is_in_path /home/e/eserte/src/repository 
# REPO MD5 1b42243230d92021e6c361e37c9771d1

=head2 is_in_path($prog)

=for category File

Return the pathname of $prog, if the program is in the PATH, or undef
otherwise.

DEPENDENCY: file_name_is_absolute

=cut

sub is_in_path {
    my($prog) = @_;
    return $prog if (file_name_is_absolute($prog) and -f $prog and -x $prog);
    require Config;
    my $sep = $Config::Config{'path_sep'} || ':';
    foreach (split(/$sep/o, $ENV{PATH})) {
	if ($^O eq 'MSWin32') {
	    return "$_\\$prog"
		if (-x "$_\\$prog.bat" ||
		    -x "$_\\$prog.com" ||
		    -x "$_\\$prog.exe");
	} else {
	    return "$_/$prog" if (-x "$_/$prog");
	}
    }
    undef;
}
# REPO END

# REPO BEGIN
# REPO NAME file_name_is_absolute /home/e/eserte/src/repository 
# REPO MD5 a77759517bc00f13c52bb91d861d07d0

=head2 file_name_is_absolute($file)

=for category File

Return true, if supplied file name is absolute. This is only necessary
for older perls where File::Spec is not part of the system.

=cut

sub file_name_is_absolute {
    my $file = shift;
    my $r;
    eval {
        require File::Spec;
        $r = File::Spec->file_name_is_absolute($file);
    };
    if ($@) {
	if ($^O eq 'MSWin32') {
	    $r = ($file =~ m;^([a-z]:(/|\\)|\\\\|//);i);
	} else {
	    $r = ($file =~ m|^/|);
	}
    }
    $r;
}
# REPO END

