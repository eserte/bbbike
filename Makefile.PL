# -*- perl -*-
# $Id: Makefile.PL,v 1.89 2003/11/16 22:59:19 eserte Exp eserte $

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
  [qw/IPC::Run		0	all	0	base/,
   'hilft bei der sicheren Ausführung von externen Kommandos (insbesondere für Win32)'],
  [qw/Imager	0	all	0	devel/,
   'additional optional BBBikeDraw backend for PNG graphics'],
  [qw/SVG	0	all	0	cgi/,
   'additional optional BBBikeDraw backend for SVG graphics'],

  [qw/Image::Info	0	all	0	test/],
  [qw/Test::More	0	all	0	test/],
 );

# EXE corequisites ####################################################
# standard Unix: uname, who, tee, at, diff, zcat, ping
# BSD Unix:      leave
# extra:         enscript, gv, ghostview, gs, netpbm-utils, cjpeg, agrep,
#                netscape, socket, mapserver
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
    if (-r "ext/Makefile") {
	$out .= <<'EOF';
	cd ext && $(MAKE) test
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
	    if (defined $ENV{USER} && $ENV{USER} eq 'eserte') {
		warn "Can't find $module_dist neither in $EXTMODCPANTOP nor in $EXTMODPERLTOP\n";
	    }
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
    $bbbike_makefile_admin;
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

