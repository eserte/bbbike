#!/usr/bin/env perl
# -*- perl -*-

#
# $Id: bbbike.cgi,v 6.24 2003/05/30 07:56:59 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 1998-2003 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

=head1 NAME

bbbike.cgi - CGI interface to bbbike

=cut

use vars qw(@extra_libs);
use FindBin;
BEGIN {
    if ($ENV{SERVER_NAME} =~ /(radzeit\.de|radzeit.herceg.de)$/) {
	# Make it easy to switch between versions:
	if ($FindBin::Script =~ /bbbike2/) {
	    @extra_libs =
		("$FindBin::RealBin/../BBBike2",
		 "$FindBin::RealBin/../BBBike2/lib",
		);
	} else {
	    @extra_libs =
		("$FindBin::RealBin/../BBBike",
		 "$FindBin::RealBin/../BBBike/lib",
		);
	}
    } else {
	# Achtung: evtl. ist auch ~/lib/ für GD.pm notwendig (z.B. CS)
	@extra_libs =
	    (#"/home/e/eserte/src/bbbike",
	     "$FindBin::RealBin/..", # falls normal installiert
	     "$FindBin::RealBin/../lib",
	     "$FindBin::RealBin/../BBBike", # falls in .../cgi-bin/... installiert
	     "$FindBin::RealBin/../BBBike/lib",
	     "$FindBin::RealBin/BBBike", # weitere Alternative
	     "$FindBin::RealBin/BBBike/lib",
	     "$FindBin::RealBin",
	     "/home/e/eserte/lib/perl", # only for TU Berlin
	    );
    }
}
use lib (@extra_libs);

use Strassen; # XXX => Core etc.?
#use Strassen::Lazy; # XXX mal sehen...
use BBBikeCalc;
use BBBikeVar;
use BBBikeUtil qw(is_in_path min max);
use CGI qw(-no_xhtml);
use CGI::Carp; # Nur zum Debuggen verwenden --- manche Web-Server machen bei den kleinsten Kleinigkeiten Probleme damit: qw(fatalsToBrowser);
use BrowserInfo 1.31;
use strict;
use vars qw($VERSION $VERBOSE $WAP_URL
	    $debug $tmp_dir $mapdir_fs $mapdir_url
	    $bbbike_root $bbbike_images $bbbike_url $bbbike_html
	    $max_proc $use_miniserver $auto_switch_slow  $use_fcgi
	    $modperl_lowmem $use_imagemap $create_imagemap $q %persistent
	    $str $lstr $lstr2 $multistr $orte $orte2 $multiorte
	    $ampeln $qualitaet_s_net $handicap_s_net
	    $strcat_net $radwege_strcat_net $routen_net $comments_net
	    $green_net
	    $inaccess_str $crossings $kr $plz $net $multi_bez_str
	    $overview_map
	    $use_umland $use_umland_jwd $use_special_destinations
	    $check_map_time $use_cgi_bin_layout
	    $show_weather $show_start_ziel_url @weather_cmdline
	    $bp_obj $bi $use_select
	    $graphic_format $use_mysql_db $use_exact_streetchooser
	    $cannot_gif_png $cannot_jpeg $cannot_pdf $cannot_svg $can_gif
	    $can_wbmp $can_palmdoc $can_mapserver $mapserver_address_url
	    $mapserver_init_url $no_berlinmap $max_plz_streets $with_comments
	    $use_coord_link
	    @weak_cache @no_cache %proc
	    $bbbike_script $bbbike_script_cgi $cgi $port
	    $search_algorithm $use_background_image
	    $use_apache_session $cookiename
	    @temp_blocking
	   );

#open(STDERR, ">>/tmp/bbbike.log");

# versucht, die C/XS-Version von make_net zu laden
eval q{local $SIG{'__DIE__'};
       # XXX warum gibt das hier Fehler auf stderr aus?
       # (nur bei 5.6.0?)
       use BBBikeXS;
   };

=head1 Configuration section

Please change the configuration variables in the file bbbike.cgi.config
(replace bbbike.cgi with the basename of the CGI script).

=head2 Filesystem and URLs

=over

=item $mapdir_url

URL for directory where the imagemaps are created. The directory should
be writable for the owner of the httpd process.

=cut

$mapdir_url = '/~eserte/bbbike-tmp';

=item $mapdir_fs

The C<$mapdir_url> path in filesystem space.

=cut

$mapdir_fs  = '/home/e/eserte/www/bbbike-tmp';

=item $tmp_dir

Temporary directory for cache files, weather data files etc. Default:
the environment variables TMPDIR or TEMP or the C</tmp> directory. A
good platform-independent default is

    do { require File::Spec; File::Spec->tmpdir }

=cut

$tmp_dir = $ENV{TMPDIR} || $ENV{TEMP} || "/tmp";

=item $use_cgi_bin_layout

Set to true, if you are using a cgi-bin styled layout, that is, cgi-bin
and htdocs are in seperate directories. Default: false.

=cut

$use_cgi_bin_layout = 0;

=back

=head2 External programs

=over

=item $ENV{PATH}

Some WWW servers set the PATH environment variable empty. Set this to
a sane value (e.g. /bin:/usr/bin) for some required external programs.

=cut

$ENV{PATH} = '' if !defined $ENV{PATH};
$ENV{PATH} = "/usr/bin:$ENV{PATH}"; # for Sys::Hostname

=item $Strassen::OLD_AGREP, $PLZ::OLD_AGREP

Set the C<$Strassen::OLD_AGREP> and C<$PLZ::OLD_AGREP> to a true value to
not use C<agrep> (instead C<String::Approx> will be used for approximate
matches). Please note that C<agrep> in versions less than 3.0 does not handle
umlauts correctly.

=cut

$Strassen::OLD_AGREP = 1;
$PLZ::OLD_AGREP      = 1;
$PLZ::OLD_AGREP      = $PLZ::OLD_AGREP; # peacify -w

=back

=head2 Web Server

=over

=item $use_miniserver

Set to a true value, if C<CGI::MiniSvr> should be used. Default: false.

=cut

$use_miniserver = 0;

=item $max_proc

The maximal count of concurrent miniserver processes. Default: 2.

=cut

$max_proc = 2;

=item $auto_switch_slow

Set to true, if the slower CGI interface should be used if there are
two many miniserver processes. Default: true.

=cut

$auto_switch_slow = 1;

=item $modperl_lowmem

In the case of using the script in a  modperl environment: set this to
true, if global variables should be deleted after the end of a request.
This may help if there are memory leaks. Default: false.

=cut

$modperl_lowmem = 0;

=back

=head2 Imagemaps, graphic creation

=over

=item $use_imagemap

Set to true, if the detail maps should use an imagemap. This feature
seems to be supported only on Netscape running on FreeBSD or Linux.
On other systems there may be fatal errors if this is set to true.
Default: false.

=cut

$use_imagemap = 0;

=item $create_imagemap

If set to true, then imagemaps for C<$use_imagemap> will be created.
Default: true.

=cut

$create_imagemap = 1;

=item $check_map_time

Control the checking of the up-to-dateness of imagemaps.

=over

=item 0: no check

=item 1: check against the "strassen" datafile

=item 2: check against the "strassen" datafile and the CGI script itself

=back

=cut

$check_map_time = 0;

=item $graphic_format

Set the preferred graphic format: C<png> or C<gif>. If using C<GD
1.20> or newer, this *must* be set to png, otherwise the creation of
graphics will not work! If neither gif nor png can be produced, set
the the variable to an empty string. Default: png.

=cut

$graphic_format = 'png';

=item $cannot_jpeg

If for some reasons JPEG cannot be produced (because GD is not able
to), set this variable to a true value. Default: true.

=cut

$cannot_jpeg = 1;

=item $cannot_pdf

If PDF::Create is not installed, set this variable to a true value. Default:
false.

=cut

$cannot_pdf  = 0;

=item $cannot_svg

If C<SVG.pm> is not installed, set this variable to a true value. Default:
true.

=cut

$cannot_svg  = 1;

=item $can_gif

Set this to a true value if you can produce gif images. Default: false.

=cut

$can_gif = 0;

=item $can_wbmp

Set this to a true value if you can produce wbmp images. Default: false.

=cut

$can_wbmp = 0;

=item $can_palmdoc

Set this to a true value if you can produce palmdoc documents with the
Palm::PalmDoc module (possible viewer: CSpotRun). Default: false.

=cut

$can_palmdoc = 0;

=item $can_mapserver

Set this to a true value if mapserver can be used. Default: false. See
below for special mapserver variables.

=cut

$can_mapserver = 0;

=back

=head2 Mapserver

=over

=item $mapserver_dir

Directory containing map and template html files.

=item $mapserver_prog_relurl

Relative URL to the mapserver cgi program.

=item $mapserver_prog_url

Absolute URL to the mapserver cgi program.

=item $mapserver_init_url

Absolute URL to the page which starts the mapserver program.

=cut

$mapserver_init_url = $BBBike::BBBIKE_MAPSERVER_INIT;

=item $mapserver_address_url

Absolute URL to the mapserver address cgi program.

=cut

$mapserver_address_url = $BBBike::BBBIKE_MAPSERVER_ADDRESS_URL;

=item $bbd2esri_prog

Path to the bbd2esri program.

=back

=head2 Appearance

=over

=item $show_start_ziel_url

Create links for start/goal URLs. Default: true.

=cut

$show_start_ziel_url = 1;

=item $show_weather

Show and fetch the current weather information. Default: true.

=cut

$show_weather = 1;

=item @weather_cmdline

The command line for the weather information fetching program.

=cut

@weather_cmdline = ("$FindBin::RealBin/" . ($use_cgi_bin_layout
					    ? "BBBike" : "..") .
		    "/lib/wettermeldung2", qw(-dahlem1));

=item $use_select

Use E<lt>SELECTE<gt> instead of E<lt>INPUT TYPE=RADIOE<gt>, if possible.
Default: true.

=cut

$use_select = 1;

=item $no_berlinmap

If no detailmap links should be shown (because GD is not installed at all),
then set this to true. Default: false.

=cut

$no_berlinmap = 0;

=item $use_background_image

Show the nice background image. Default: true.

=cut

$use_background_image = 1;

=item $with_comments

Include column for comments in route list. Only activated if browser
is able to display tables.

=cut

$with_comments = 1;

=item $use_coord_link

Use an own exact coordinate link (i.e. to Mapserver) instead of a
"Stadtplan" link. Default: true:

=cut

$use_coord_link = 1;

=back

=head2 Data

=over

=item $use_umland

Experimental: search in the region. Default: false.

=cut

$use_umland = 0;

=item $use_umland_jwd

Even more experimental: search in the wide region. Default: false.

=cut

$use_umland_jwd = 0;

=item $use_special_destinations

Set to a true value if special destinations like bikeshops, bankomats etc.
may be used.

=cut

$use_special_destinations = 0;

=back

=head2 Misc

=over

=item $search_algorithm

Default search algorithm is (pure perl) A*, but may be set to C<C-A*> or
other.

=cut

$search_algorithm = undef;

=item $use_mysql_db

Should the MySQL database (TelbuchDBApprox) be used if a house number
is given? Default: false.

=cut

$use_mysql_db = 0;

=item $use_exact_streetchooser

Exact chooser for near coordinates ... somewhat slower, but more
exact. Default: false.

=cut

$use_exact_streetchooser = 0;

=item $VERBOSE

Set this to true for debugging purposes.

=cut

$VERBOSE = 0;

=item @temp_blocking

Array with temporary blocking elements. Each element is a hash with the
following keys set:

=over

=item from

unix time of start of temporary blocking or undef.

=item until

unix time of end of temporary blocking or undef.

=item file

bbd file for temporary blocking data or undef.

=item text

Explanation text for temporary blockings.

=back

=back

=cut

####################################################################

unshift(@Strassen::datadirs,
	"$FindBin::RealBin/../data",
	"$FindBin::RealBin/../BBBike/data",
       );

eval { local $SIG{'__DIE__'};
       #warn "$0.config";
       do "$0.config" };

eval { local $SIG{'__DIE__'};
       my $teaser_file = "$FindBin::RealBin/bbbike-teaser.pl";
       if (defined $BBBikeCGI::teaser_file_modtime &&
	   (stat($teaser_file))[9] > $BBBikeCGI::teaser_file_modtime) {
	   delete $INC{$teaser_file};
       }
       require $teaser_file;
       $BBBikeCGI::teaser_file_modtime = (stat($teaser_file))[9];
}; warn $@ if $@;

if ($VERBOSE) {
    $StrassenNetz::VERBOSE    = $VERBOSE;
    $Strassen::VERBOSE        = $VERBOSE;
    $Kreuzungen::VERBOSE      = $VERBOSE;
}

if ($use_miniserver) {
    eval q{
	local $SIG{'__DIE__'};
	#local $^W = 0; # XXX noch notwendig?
	require CGI::Base;
	require CGI::Request;
	require CGI::MiniSvr;

	package CGI::MiniSvr::BBBike;
	@CGI::MiniSvr::BBBike::ISA = qw(CGI::MiniSvr);
	# validate_peer ist eher störend ...
	# Probleme lokal beim Apache 1.3.4
	# (wahrscheinlich ein Konfigurationsproblem)
	sub validate_peer { return 1 }
    };

    warn __LINE__ .  ": Warnung: $@<br>\n" if $@;
}

if ($0 =~ /\.fcgi$/) {
    require FCGI;
    $use_fcgi = 1;
    exit if FCGI::accept() < 0;
}

# beim ersten Mal *darf* kein HTTP-Response-Header übermittelt werden,
# danach *muss* es geschehen
use vars qw($first_time);
$first_time = 1;

{
# header() patchen
package CGI::BBBike;
@CGI::BBBike::ISA = qw(CGI);
sub new {
    my($class, @args) = @_;
    my $caller_pkg = caller();
    my $code = "";
    if ($] >= 5.006) {
	$code .= "no warnings 'redefine';\n";
    }
    $code .= '
sub header
 {
    if (!$ ' . $caller_pkg . '::first_time && $ ' . $caller_pkg . '::use_miniserver) {
	print "HTTP/1.0 200 OK\n";
    }
    $ ' . $caller_pkg . '::first_time = 0;
    shift->SUPER::header(@_);
}
';
    #warn $code;
    eval $code;
    $class->SUPER::new(@args);
}

# damit ich weiterhin mit $q->... arbeiten kann
package CGI::Request::BBBike;
use vars qw(@ISA);
@ISA = qw(CGI::Request CGI::BBBike);

} # jetzt beginnt wieder package main

$VERSION = sprintf("%d.%02d", q$Revision: 6.24 $ =~ /(\d+)\.(\d+)/);

my $font = 'sans-serif,helvetica,verdana,arial'; # also set in bbbike.css
my $delim = '!'; # wegen Mac nicht ¦ verwenden!

# XXX del:
#  my $std_css = <<EOF;
#  body,td,th,p,input { font-family:$font; }
#  tt,pre { font-family:fixed,courier;}
#  EOF
@weak_cache = ('-expires' => '+1d',
               # XXX ein bißchen soll Netscape3 auch cachen können:
	       #'-pragma' => 'no-cache',
	       '-cache-control' => 'private',
              );
@no_cache = ('-expires' => 'now',
             '-pragma' => 'no-cache',
	     '-cache-control' => 'no-cache',
            );

if (defined %Apache::) {
    # workaround for "use lib" problem with Apache::Registry
    'lib'->import(@extra_libs);
}

# Konstanten für die Imagemaps
# Die nächsten beiden Variablen müssen auch in bbbike_start.js geändert werden.
my $xgridwidth = 20; # 20 * 10 = 200: Breite und Höhe von berlin_small.gif
my $ygridwidth = 20;
my $xgridnr = 10;
my $ygridnr = 10;
# Diese Werte (bis auf $ym) werden mit small_berlinmap.pl ausgegeben.
my $xm = 228.58;
my $ym = $xm;
my $x0 = -10849;
my $y0 = 34867;
## schön groß, aber passt nicht auf Seite
#my $detailwidth  = 600; # muß quadratisch sein!
#my $detailheight = 600;
my $detailwidth  = 500; # muß quadratisch sein!
my $detailheight = 500;
my $nice_berlinmap = 0;
my $nice_abcmap    = 0;

my $start_bgcolor = '';
my $via_bgcolor   = '';
my $ziel_bgcolor  = '';
if (!$use_background_image) {
    $start_bgcolor = '#f0f8ff';
    $via_bgcolor   = '#ecf4ff';
    $ziel_bgcolor  = '#e8f0ff';
}

my @pref_keys = qw/speed cat quality ampel green/;

$q = new CGI::BBBike;
$str = new Strassen "strassen" unless defined $str;
#$str = new Strassen::Lazy "strassen" unless defined $str;
$cookiename = "bbbike";
if (!defined $inaccess_str) {
    my $i_s;
    eval { $i_s = new Strassen "inaccessible_strassen" };
    if ($i_s) {
	$inaccess_str = $i_s->get_hashref;
    }
}
if ($use_umland) {

    # Strassen
    # XXX there should also be a lazy version of Multistrassen
    my @s = $str;
    $lstr  = new Strassen "landstrassen"  unless defined $lstr;
    push @s, $lstr;
    if ($use_umland_jwd) {
	$lstr2 = new Strassen "landstrassen2" unless defined $lstr2;
	push @s, $lstr2;
    }
    $multistr = new MultiStrassen @s unless defined $multistr;

    # Orte
    my @o;
    $orte = new Strassen "orte" unless defined $orte;
    push @o, $orte;
    if ($use_umland_jwd) {
	$orte2 = new Strassen "orte2" unless defined $orte2;
	push @o, $orte2;
    }
    $multiorte = new MultiStrassen @o unless defined $multiorte;

} else {
    $multistr = $str;
}

# Maximale Anzahl der angezeigten Straßen, wenn eine Auswahl im PLZ-Gebiet
# gezeigt wird.
$max_plz_streets = 25;

# die originale URL (für den Kaltstart)
$bbbike_url = $q->url;
# $mapdir_url absolut machen
$mapdir_url = "http://" . $q->server_name . $mapdir_url;
# Root-Verzeichnis und Bilder-Verzeichnis von bbbike
($bbbike_root = $bbbike_url) =~ s|[^/]*/[^/]*$|| if !defined $bbbike_root;
$bbbike_root =~ s|/$||; # letzten Slash abschneiden
if (!defined $bbbike_images) {
    $bbbike_images = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	"images";
}
if (!defined $bbbike_html) {
    $bbbike_html   = "$bbbike_root/" . ($use_cgi_bin_layout ? "BBBike/" : "") .
	"html";
}

my($fontstr, $fontend);
my $smallform = 0;

if (!-d $mapdir_fs) {
    # unter der Voraussetzung, dass das Parent-Verzeichnis schon existiert
    mkdir $mapdir_fs, 0755;
}

$bbbike_script = $q->url;
$bbbike_script_cgi = $bbbike_script;
if ($use_fcgi) { # die normale CGI-Skript-Version (ohne FCGI)
    $bbbike_script_cgi =~ s/\.fcgi\b/.cgi/;
}

# den MiniSvr starten
if ($use_miniserver) {
    my $proc_slot = limit_processes();
    CGI::Base::LogFile("$tmp_dir/bbbike.log");
    chmod 0600, "$tmp_dir/bbbike.log";
    $cgi = new CGI::MiniSvr::BBBike;
    $port = $cgi->port;
    $bbbike_script_cgi = $bbbike_script
      = "http://$ENV{SERVER_NAME}$port$ENV{SCRIPT_NAME}";
    user_agent_info();
    choose_form();
    $cgi->done(0);
    $cgi->spawn and exit 0;
#    $cgi->sigpipe_catch;#XXX needed? minisvr is unstable...
    # Prozessnummer korrigieren
    set_process($proc_slot);
    CGI::Request::Interface($cgi);
}

# Request-Loop
while (1) {
    if ($use_miniserver) {
	$q = new CGI::Request::BBBike or $cgi->exit;
	$q->delete("~SequenceNumber ");    # stört nur...
    } elsif ($use_fcgi) {
	# XXX workaround mit QUERY_STRING
	# scheint aber zu funktionieren
	$q = new CGI $ENV{QUERY_STRING};
    }

    if ($q->path_info ne "") {
	my $q2 = CGI->new(substr($q->path_info, 1));
	foreach my $k ($q2->param) {
	    $q->param($k, $q2->param($k));
	}
    }

    # Bei Verwendung von FCGI oder Apache muß die User-Info immer
    # neu festgestellt werden
    user_agent_info() unless $use_miniserver;

    if ($bi->{'wap_browser'}) {
        exec("./wapbbbike.cgi", @ARGV);
	warn "exec failed, try redirect...";
	print $q->redirect($WAP_URL || $BBBike::BBBIKE_WAP);
	exit(0);
    }

    undef $bp_obj unless $use_miniserver;
    init_bikepower($q) if !($use_miniserver && defined $bp_obj);

    # Wettermeldungen so früh wie möglich versuchen zu holen
    if ($show_weather || $bp_obj) {
	start_weather_proc();
    }

    $q->delete('Dummy');
    $smallform = $q->param('smallform') || $bi->{'mobile_device'};

    foreach my $type (qw(start via ziel)) {
	if (defined $q->param($type . "charimg.x") and
	    $q->param($type . "charimg.x") ne ""   and
	    defined $q->param($type . "charimg.y") and
	    $q->param($type . "charimg.y") ne "") {
	    my($x, $y) = (int(($q->param($type . "charimg.x")-2)/30),
			  int(($q->param($type . "charimg.y")-2)/30));
	    my $ch = $x + $y*9 + ord("A");
	    $ch = ($ch > ord("Z") ? 'Z' : ($ch < ord("A") ? 'A' : chr($ch)));
	    $q->param($type . "char", $ch);
	    $q->delete($type . "charimg.x");
	    $q->delete($type . "charimg.y");
	}
    }

    if (defined $q->param('movemap')) {
	my $move = $q->param('movemap');
	my($x, $y) = ($q->param('detailmapx'),
		      $q->param('detailmapy'));
	if    ($move =~ /^nord/i) { $y-- }
	elsif ($move =~ /^süd/i)  { $y++ }
	if    ($move =~ /west$/i) { $x-- }
	elsif ($move =~ /ost$/i)  { $x++ }
	$q->delete('detailmapx');
	$q->delete('detailmapy');
	$q->delete('movemap');
	draw_map('-x' => $x,
		 '-y' => $y);
	goto LOOP_CONT;
    }

    foreach my $type (qw(start via ziel)) {
	if (defined $q->param($type . "mapimg.x") and
	    $q->param($type . "mapimg.x") ne ""   and
	    defined $q->param($type . "mapimg.y") and
	    $q->param($type . "mapimg.y") ne "") {
	    my($x, $y) = (int($q->param($type . 'mapimg.x')/$xgridwidth),
			  int($q->param($type . 'mapimg.y')/$ygridwidth));
	    $q->param('type', $type);
	    $q->delete($type . "mapimg.x");
	    $q->delete($type . "mapimg.y");
	    draw_map('-x' => $x,
		     '-y' => $y);
	    goto LOOP_CONT;
	}
    }

    if (defined $q->param('detailmapx') and
	defined $q->param('detailmapy') and
	defined $q->param('detailmap.x') and
	defined $q->param('detailmap.y')
       ) {
	my $c = detailmap_to_coord($q->param('detailmapx'),
				   $q->param('detailmapy'),
				   $q->param('detailmap.x'),
				   $q->param('detailmap.y'));
	if (defined $c) {
	    $q->param($q->param('type') . 'c', $c);
	}
	$q->delete('detailmapx');
	$q->delete('detailmapy');
	$q->delete('detailmap.x');
	$q->delete('detailmap.y');
	$q->delete('type');
    }

    # Ziel für stadtplandienst-kompatible Koordinaten setzen
    my $set_zielc = sub {
	my $ll = shift;
	require Karte;
	Karte::preload("Standard", "Polar");
	# Ob die alte ...x...-Syntax noch unterstützt wird, ist fraglich...
	my($long,$lat) = $ll =~ /^[\+\ ]/
			  ? $ll =~ /^[\+\-\ ]([0-9.]+)[\+\-\ ]([0-9.]+)/
			  : split(/x/, $ll)
			 ;
	if (defined $long && defined $lat) {
	    local $^W;
	    my($x, $y) = $Karte::Polar::obj->map2standard($lat, $long);
	    new_kreuzungen(); # XXX needed in munich, here too?
	    $q->param("zielc", get_nearest_crossing_coords($x,$y));
	}
    };

    # schwache stadtplandienst-Kompatibilität
    # Note: ";" und "&" werden von CGI.pm gleichberechtigt behandelt
    if (defined $q->param('STR')) {
	$q->param('ziel', $q->param('STR'));
    }
    if (defined $q->param('PLZ')) {
	$q->param('zielplz', $q->param('PLZ'));
    }
    if (defined $q->param('LL')) {
	$set_zielc->($q->param('LL'));
    }

    if (defined $q->param('begin')) {
	$q->delete('begin');
	choose_form();
    } elsif (defined $q->param('info') || $q->path_info eq '/_info') {
	$q->delete('info');
	show_info();
    } elsif (defined $q->param('uploadpage') ||
	     defined $q->param('gps')) {
	$q->delete('uploadpage');
	$q->delete('gps');
	upload_button();
    } elsif (defined $q->param('all')) {
	$q->delete('all');
	choose_all_form();
    } elsif (defined $q->param('bikepower')) {
	$q->delete('bikepower');
	call_bikepower();
    } elsif (defined $q->param('nahbereich')) {
	nahbereich();
    } elsif (defined $q->param('mapserver')) {
	start_mapserver();
    } elsif (defined $q->param('routefile') and
	     $q->param('routefile') ne "") {
	draw_route_from_fh($q->param('routefile'));
    } elsif (defined $q->param('coords') || defined $q->param('coordssession')) {
	draw_route(-cache => []);
    } elsif (defined $q->param('create_all_maps')) {
	# XXX Der Apache 1.3.9/FreeBSD 3.3 lässt den Prozess nach
	# ungefähr fünf Karten mit "Profiling timer expired" sterben.
	# Mit thttpd gibt es zwar auch mysteriöse kills, aber es geht im
	# Großen und Ganzen.
	print $q->header(-type => 'text/plain',
			 @no_cache,
			 etag(),
			);
	$| = 1;
	$check_map_time = 1;
	for my $x (0 .. 9) {
	    for my $y (0 .. 9) {
		print "x=$x y=$y ...\n";
		draw_map('-x' => $x,
			 '-y' => $y,
			 '-quiet'    => 1,
			 '-logging'  => 1,
			 '-strlabel' => 1,
			 '-force'    => 0,
			);
	    }
	}
	exit(0);
    } elsif (defined $q->param('startchar')) {
	choose_ch_form($q->param('startchar'), 'start');
    } elsif (defined $q->param('viachar')) {
	choose_ch_form($q->param('viachar'), 'via');
    } elsif (defined $q->param('zielchar')) {
	choose_ch_form($q->param('zielchar'), 'ziel');
    } elsif (defined $q->param('startc') and
	     defined $q->param('zielc')) {
	if (!$q->param('pref_seen')) {
	    # zuerst die Einstellungen für die Suche eingeben lassen
	    get_kreuzung();
	} else {
	    # und erst dann suchen
	    search_coord();
	}
    } elsif (((defined $q->param('startname') and $q->param('startname') ne '')
	      or
	      (defined $q->param('startc') and $q->param('startc') ne ''))
	     and
	     ((defined $q->param('zielname')  and $q->param('zielname')  ne '')
	      or
	      (defined $q->param('zielc') and $q->param('zielc') ne ''))
	     and
	     via_not_needed()
	    ) {
	get_kreuzung();
    } elsif (defined $q->param('browser')) {
	show_user_agent_info();
    } else {
	choose_form();
    }

  LOOP_CONT:
    if ($use_miniserver) {
	$cgi->done(0);
    } elsif ($use_fcgi) {
	FCGI::flush();
	exit 1 if FCGI::accept() < 0;
    } else {
	last;
    }
}

if ($modperl_lowmem) {
    # Nutzen für den Speicherverbrauch ist eher begrenzt...
    undef $q;
    undef $str;
    undef $lstr;
    undef $lstr2;
    undef $multistr;
    undef $orte;
    undef $orte2;
    undef $multiorte;
    undef $plz;
    undef $net;
    undef $multi_bez_str;
}


sub abc_link {
    my($type, %args) = @_;

    if ($bi->{'mobile_device'}) {
	# we don't need any extras
    } elsif ($bi->{'text_browser'}) {
	for my $ch ('A' .. 'Z') {
	    print "<input type=submit name="
	      . $type . "char value=" . $ch . ">";
	}
	print "<br>\n";
    } elsif ($nice_abcmap) {
	print "<input type=hidden name=\"" . $type . "charimg.x\" value=\"\">";
	print "<input type=hidden name=\"" . $type . "charimg.y\" value=\"\">";
	print "<div id=" . $type . "charbelow style=\"position:relative; visibility:hidden\">";
	print "<img src=\"$bbbike_images/abc.gif\" border=0 width=270 height=94 alt=\"\">";
	print "</div>";
	print "<div id=" . $type . "charabove style=\"position:absolute; visibility:hidden\">";
	print "<img src=\"$bbbike_images/abc_hi.gif\" border=0 width=270 height=94 alt=\"\">";
	print "</div>";
	print <<EOF;
<script type="text/javascript"><!--
function ${type}char_init() { return any_init("${type}char"); }
function ${type}char_highlight(Evt) { return any_highlight("${type}char", Evt); }
function ${type}char_byebye(Evt) { return any_byebye("${type}char", Evt); }
function ${type}char_detail(Evt) { return any_detail("${type}char", Evt); }

// --></script>

EOF

    } else {
	print "<input type=image name=" . $type
	  . "charimg src=\"$bbbike_images/abc.gif\" class=\"charmap\" alt=\"A..Z\">";
    }
}

sub choose_form () {
    my $startname = $q->param('startname') || '';
    my $start2    = $q->param('start2')    || '';
    my $start     = $q->param('start')     || '';
    my $startplz  = $q->param('startplz')  || '';
    my $starthnr  = $q->param('starthnr')  || '';

    my $vianame   = $q->param('vianame')   || '';
    my $via2      = $q->param('via2')      || '';
    my $via       = $q->param('via')       || '';
    my $viaplz    = $q->param('viaplz')    || '';
    my $viahnr    = $q->param('viahnr')    || '';

    my $zielname  = $q->param('zielname')  || '';
    my $ziel2     = $q->param('ziel2')     || '';
    my $ziel      = $q->param('ziel')      || '';
    my $zielplz   = $q->param('zielplz')   || '';
    my $zielhnr   = $q->param('zielhnr')   || '';

    my $nl = sub {
	if ($bi->{'can_table'}) {
	    print "<tr><td>&nbsp;</td></tr>\n";
	} else {
	    print "<p>\n";
	}
    };
    my $tbl_center = sub {
	my $text = shift;
	my $align = shift || "center";
	if ($bi->{'can_table'}) {
	    print "<tr><td colspan=4 align=$align>$text</td></tr>\n";
	} else {
	    print "<center>$text</center>\n";
	}
    };

    # Namen und Koordinaten der Start...orte
    my($startort, $viaort, $zielort,
       $startortc, $viaortc, $zielortc);

    # Leerzeichen am Anfang und Ende löschen
    # überflüssige Leerzeichen in der Mitte löschen
    $start =~ s/^\s+//; $start =~ s/\s+$//; $start =~ s/\s{2,}/ /g;
    $via   =~ s/^\s+//; $via   =~ s/\s+$//; $via   =~ s/\s{2,}/ /g;
    $ziel  =~ s/^\s+//; $ziel  =~ s/\s+$//; $ziel  =~ s/\s{2,}/ /g;

    foreach ([\$startname, \$start2, \$startort, \$startortc, 'start'],
	     [\$vianame,   \$via2,   \$viaort,   \$viaortc,   'via'],
	     [\$zielname,  \$ziel2,  \$zielort,  \$zielortc,  'ziel'],
	) {
	my  (  $nameref,    $tworef,  $ortref,    $ortcref,   $type) = @$_;
	# Überprüfen, ob eine in PLZ vorhandene Straße auch in
	# Strassen vorhanden ist und ggfs. $....name setzen
	if ($$nameref eq '' && $$tworef ne '') {
	    my(@s) = split(/$delim/o, $$tworef);
	    if ($s[1] eq '#ort') {
		my($ortname, $xy) = ($s[0], $s[2]);
		$$ortref  = $ortname;
		$$ortcref = $xy;
	    } else {
		my($strasse, $bezirk, $plz) = @s;
		warn "Wähle $type-Straße für $strasse/$bezirk\n" if $debug;
		my $pos = $str->choose_street($strasse, $bezirk);
		if (defined $pos) {
		    $$nameref = $str->get($pos)->[0];
		    $q->param($type . 'plz', $plz);
		}
	    }
	}
    }

    # Es ist alles vorhanden, keine Notwendigkeit für ein Formular.
  TRY: {
	if (((defined $startname && $startname ne '') ||
	     (defined $startort  && $startort ne '')) &&
	    ((defined $zielname  && $zielname ne '') ||
	     (defined $zielort   && $zielort ne ''))) {
	    last TRY if (((defined $via2 && $via2 ne '') ||
			  (defined $via  && $via  ne '' && $via ne 'NO')) &&
			 ((!defined $vianame || $vianame eq '') &&
			  (!defined $viaort  || $viaort eq '')));

	    foreach ([\$startort, \$startortc, \$startname, 'start'],
		     [\$viaort,   \$viaortc,   \$vianame,   'via'],
		     [\$zielort,  \$zielortc,  \$zielname,  'ziel']) {
		my $ortref  = $_->[0];
		my $ortcref = $_->[1];
		my $nameref = $_->[2];
		my $type    = $_->[3];
		if ((!defined $$ortref || $$ortref ne '') and
		    defined $$ortcref) {
		    new_kreuzungen(); # XXX needed in munich, here too?
		    my($best) = get_nearest_crossing_coords(split(/,/, $$ortcref));
		    $q->param($type . 'isort', 1);
		    $q->param($type . 'c', $best);
		    $q->param($type . 'name', $$ortref);
		    $$nameref = $$ortref;
		}
	    }

	    if (0 && # XXX preferences-seite!
		$q->param("startc") and $q->param("zielc") and
		((!defined $vianame || $vianame eq '') ||
		 ($q->param("viac")))) {
		search_coord();
	    } else {
		warn "Wähle Kreuzung für $startname und $zielname\n"
		    if $debug;
		get_kreuzung($startname, $vianame, $zielname);
	    }
	    return;
	}
    }

    # Activate only for tested platforms
    if ($bi->{'can_dhtml'} && !$bi->{'dhtml_buggy'} &&
	$bi->{'can_javascript'} && !$bi->{'text_browser'}) {
	if (($bi->is_browser_version("Mozilla", 4.5, 4.9999) &&
	     $bi->{'user_agent_os'} =~ /(freebsd|linux|windows|winnt)/i) ||
	    (defined $bi->{'gecko_version'} &&
	     ($bi->{'gecko_version'} >= 20020000 ||
	      $bi->{'gecko_version'} == 0))
	   ) {
	    $nice_berlinmap = $nice_abcmap = 1;
	}
	if ($bi->is_browser_version("MSIE", 5.0, 5.4999)) {
	    $nice_berlinmap = $nice_abcmap = 1;
	}
    }

    my(@start_matches, @via_matches, @ziel_matches);
 MATCH_STREET:
    foreach ([\$startname,\$start,\$start2,\@start_matches,'start',\$startplz],
	     [\$vianame,  \$via,  \$via2,  \@via_matches,  'via',  \$viaplz],
	     [\$zielname, \$ziel, \$ziel2, \@ziel_matches, 'ziel', \$zielplz],
	    ) {
	my  (  $nameref,  $oneref,$tworef, $matchref,      $type,  $zipref)=@$_;

	# Darstellung eines Vias nicht erwünscht
	next if ($type eq 'via' and $$oneref eq 'NO');

	# Überprüfen, ob eine Straße in PLZ vorhanden ist.
	if ($$nameref eq '' && $$oneref ne '') {
	    if (!$plz) {
		require PLZ;
		PLZ->VERSION(1.26);
		$plz = new PLZ;
		if (!$plz) {
		    # Notbehelf. PLZ sollte möglichst installiert sein.
		    my @res = $str->agrep($$oneref);
		    if (@res) {
			$$nameref = $res[0];
		    }
		    next;
		}
	    }

	    warn "Suche $$oneref in der PLZ-DB.\n" if $debug;

	    # check for given crossings
	    my $crossing_street;
	    if ($$oneref =~ m|/|) {
		# XXX is it OK to change the referred value?
		($$oneref, $crossing_street) = split /\s*\/\s*/, $$oneref, 2;
	    }
	    my @extra;
	    if ($$zipref ne '') {
		push @extra, Citypart => $$zipref;
	    }
	    next if $$oneref =~ /^\s*$/;
	    my($retref, $matcherr) =
		$plz->look_loop(PLZ::split_street($$oneref),
				@extra,
				Max => $max_plz_streets,
				MultiZIP => 1, # introduced because of Hauptstr./Friedenau vs. Hauptstr./Schöneberg problem
				MultiCitypart => 1, # works good with the new combine method
				Agrep => 'default');
	    @$matchref = grep { defined $_->[PLZ::LOOK_COORD()] && $_->[PLZ::LOOK_COORD()] ne "" } @$retref;
	    # XXX needs more checks, but seems to work good
	    @$matchref = map { $plz->combined_elem_to_string_form($_) } $plz->combine(@$matchref);

	    if (@$matchref == 0) {
		# Nichts gefunden. In der Plätze-Datei nachschauen.
		if (my $platz = new Strassen "plaetze") {
		    warn "Suche $$oneref in der Plätze-Datei.\n" if $debug;
		    my @res = $platz->agrep($$oneref);
		    if (@res) {
			my $ret = $platz->get_by_name($res[0]);
			if ($ret) {
			    $$nameref = $res[0];
			    $q->param($type . 'c', $ret->[1][0]);
			}
		    }
#XXX		    next;
		}
		if (!defined $$nameref) {
#XXX Überprüfen ...
		    # Noch immer ohne Erfolg. In der Strassen-Datei
		    # nachschauen, weil einige Straßen nicht in der PLZ-Datei
		    # stehen.
		    warn "Suche $$oneref in der Straßen-Datei.\n" if $debug;
		    my @res = $str->agrep($$oneref);
		    if (@res) {
			my $ret = $str->get_by_name($res[0]);
			if ($ret) {
			    $$nameref = $res[0];
			    $q->param($type . 'c', $ret->[1][0]);
			}
		    }
		}
		next;
	    }

	    # If this is a crossing, then get the exact point, but don't fail
	    if (defined $crossing_street) {
		# first: get all matching Strasse objects (first part)
		my $rx = "^" . join("|", map { quotemeta($_->[&PLZ::LOOK_NAME]) } @$matchref);
		my @matches = grep {
		    $_->[Strassen::NAME] =~ /$rx/i
		} $str->get_all;
		if (@matches) {
		    all_crossings();
		    # now search for crossings
		    foreach my $r (@matches) {
			foreach my $c (@{$r->[Strassen::COORDS]}) {
			    if (exists $crossings->{$c}) {
				# is this the right crossing?
				foreach my $test_crossing_street (@{$crossings->{$c}}) {
				    if ($test_crossing_street =~ /^\Q$crossing_street\E/i) {
					$$nameref = join("/", @{$crossings->{$c}});
					$q->param($type . 'c', $c);
					next MATCH_STREET;
				    }
				}
			    }
			}
		    }
		}
	    }

	    # Überprüfen, ob es sich bei den gefundenen Straßen um die
	    # gleiche Straße, die durch mehrere Bezirke verläuft, handelt,
	    # oder ob es mehrere Straßen in mehreren Bezirken sind, die nur
	    # den gleichen Namen haben.
	    if (@$matchref > 1) {
	      TRY: {
		    my $first = $matchref->[0][0];
		    for(my $i = 1; $i <= $#$matchref; $i++) {
			if ($first ne $matchref->[$i][0]) {
			    last TRY;
			}
		    }
		    # alle Straßennamen sind gleich
		    if (!$multi_bez_str) {
			$multi_bez_str = new MultiBezStr;
		    }
		    if ($multi_bez_str) {
			my %bezirk;
			foreach ($multi_bez_str->bezirke($first)) {
			    $bezirk{$_}++;
			}
			foreach (@$matchref) {
			    last TRY if !exists $bezirk{$_->[1]};
			}
			splice @$matchref, 1;
		    }
		}
	    }

	    if ($multiorte) {
		my @orte = $multiorte->agrep($$oneref, Agrep => $matcherr);
		if (@orte) {
		    use constant MATCHREF_ISORT_INDEX => 4;
		    push @$matchref, map { [$_, undef, undef, undef, 1] } @orte;
		}
	    }

	    if (@$matchref == 1) {
		my($strasse, $bezirk) = ($matchref->[0][0],
					 $matchref->[0][1]);
		warn "Wähle $type-Straße für $strasse/$bezirk.\n"
		  if $debug;
		my $pos = $str->choose_street($strasse, $bezirk);
		if (defined $pos) {
		    $$nameref = $str->get($pos)->[0];
		    $q->param($type . 'plz', $matchref->[0][2]);
		} else {
		    $$tworef = join($delim, @{ $matchref->[0] });
		}
	    }
	}
    }

    # Es ist alles vorhanden, keine Notwendigkeit für ein Formular.
  TRY: {
	if ($startname ne '' && $zielname ne '') {
	    last TRY if (((defined $via2 && $via2 ne '') ||
			  (defined $via  && $via  ne '')) &&
			 (!defined $vianame || $vianame eq ''));
	    warn "Wähle Kreuzung für $startname und $zielname\n"
	      if $debug;
	    get_kreuzung($startname, $vianame, $zielname);
	    return;
	}
    }

    my %header_args = @weak_cache;
    $header_args{-expires} = ($use_miniserver ? 'now' : '+1d');
    print $q->header(%header_args, etag());
    my @extra_headers;
    if ($bi->{'text_browser'} && !$bi->{'mobile_device'}) {
	push @extra_headers, -up => $BBBike::HOMEPAGE;
    }
    if ($nice_berlinmap || $nice_abcmap) {
	push @extra_headers, -onLoad => "init_hi(); window.onResize = init_hi;",
	     -script => {-src => $bbbike_html . "/bbbike_start.js",
			},
    }
    header(@extra_headers, -from => "chooseform");

    if ($start eq ''  && $ziel eq '' &&
	$start2 eq '' && $ziel2 eq '' &&
	$startname eq '' && $zielname eq '' &&
	!$smallform) {
	# use "make count-streets" in ../data
 	print <<EOF;
<table>
<tr>
<td valign="top">@{[ blind_image(420,1) ]}<br>Dieses Programm sucht (Fahrrad-)Routen in Berlin. Es sind ca. 2800 von 10000 Berliner Stra&szlig;en erfasst (alle Hauptstra&szlig;en und wichtige
Nebenstra&szlig;en). Bei nicht erfassten Straßen wird automatisch die
nächste bekannte verwendet.<br>
<i>Neu</i>: In der Datenbank sind jetzt auch ca. 120 Potsdamer Stra&szlig;en.</td>
<td valign="top" @{[ $start_bgcolor ? "bgcolor=$start_bgcolor" : "" ]}>@{[ defined &teaser ? teaser() : "" ]}</td>
</tr>
</table>
<p>
EOF
        if ($bi->{'text_browser'}) {
            print q{<a name="navig"></a><a href="#start">Start-</a>};
            unless ($via eq 'NO') {
		print q{, <a href="#via">Via- (optional)</a> };
	    }
	    print <<EOF;
und <a href="#ziel">Zielstra&szlig;e</a>
der Route ausw&auml;hlen und dann <a href="#weiter">weiter</a>:<p>
EOF
        } else {
	    if ($nice_berlinmap) {
		print "<noscript>Die Aktivierung von Javascript und CSS ist empfehlenswert, aber nicht notwendig.<p></noscript>\n";
	    }
            print "&nbsp;Start- und Zielstra&szlig;e der Route ausw&auml;hlen";
	    unless ($via eq 'NO') { print " (Via ist optional)" }
	    print ": <p>\n";
        }
    }

    print "<form action=\"$bbbike_script\" name=BBBikeForm>\n";

    print "<table id=inputtable>\n" if ($bi->{'can_table'});

    foreach
      ([\$startname, \$start, \$start2, \$startort, \@start_matches, 'start',
	$start_bgcolor],
       [\$vianame,   \$via,   \$via2,   \$viaort,   \@via_matches,   'via',
	$via_bgcolor],
       [\$zielname,  \$ziel,  \$ziel2,  \$zielort,  \@ziel_matches,  'ziel',
	$ziel_bgcolor]) {
	my($nameref,  $oneref, $tworef,  $ortref,    $matchref,       $type,
	   $bgcolor) = @$_;
	my $bgcolor_s = $bgcolor ne '' ? "bgcolor=$bgcolor" : '';
	my $coord     = $q->param($type . "c");
	my $has_init_map_js;

	# Darstellung eines Vias nicht erwünscht
	if ($type eq 'via' and $$oneref eq 'NO') {
	    print "<input type=hidden name=via value=NO>";
	    next;
	}

	my $printtype = ucfirst($type);
	my $imagetype = "$bbbike_images/" . $type . ".gif";
	my $tryempty  = 0;
	my $no_td     = 0;

	if ($bi->{'can_table'}) {
	    print "<tr id=${type}tr $bgcolor_s><td align=center valign=middle width=40><a name=\"$type\"><img src=\"$imagetype\" border=0 alt=\"$printtype\"></a></td>";
	    my $color = {'start' => '#e0e0e0',
			 'via'   => '#c0c0c0',
			 'ziel'  => '#a0a0a0',
			}->{$type};
#XXX not yet:	    print "<td bgcolor=\"$color\">" . blind_image(1,1) . "</td>";
	} else {
	    print "<a name=\"$type\"><b>$printtype</b></a>: ";
	}
	if ((defined $$nameref and $$nameref ne '') ||
	    (defined $coord and $coord ne '')) {
	    print "<td valign=middle colspan=2>$fontstr" if $bi->{'can_table'};
	    if (defined $coord) {
		print "<input type=hidden name=" . $type . "c value=\""
		  . $coord . "\">\n";
	    }
	    if ($q->param($type . "isort")) {
		print "<input type=hidden name=" . $type . "isort value=1>\n";
	    }
	    if (defined $coord and (!defined $$nameref or $$nameref eq '')) {
		print crossing_text($coord);
	    } else {
		print "$$nameref\n";
	    }
	    print "<input type=hidden name=" . $type
	      . "name value=\"$$nameref\">\n";
	    if (defined $q->param($type . "plz")) {
		print "<input type=hidden name=${type}plz value=\""
		  . $q->param($type . "plz") . "\">\n";
	    }
	    if (defined $q->param($type . "hnr")) {
		print "<input type=hidden name=${type}hnr value=\""
		    . $q->param($type."hnr") . "\">\n";
	    }

	    print "$fontend</td>\n" if $bi->{'can_table'};
	} elsif (defined $$ortref and $$ortref ne '') {
	    print "<td valign=middle>$fontstr" if $bi->{'can_table'};
	    print "$$ortref\n";
	    print "<input type=hidden name=" . $type . "2 value=\""
		  . $$tworef . "\">\n";
	    print "</td>" if $bi->{'can_table'};
	    print "<input type=hidden name=" . $type . "isort value=1>\n";
	} elsif ($$oneref ne '' && @$matchref == 0) {
	    print "<td align=center>$fontstr" if $bi->{'can_table'};
	    print "<b>$$oneref</b> ist nicht bekannt.<br>\n";
	    $no_td = 1;
	    $tryempty = 1;
	} elsif ($$tworef ne '') {
	    my($strasse, $bezirk, $plz, $xy) = split(/$delim/o, $$tworef);
	    print "<td>$fontstr" if $bi->{'can_table'};
	    if (defined $xy) {
		new_kreuzungen();
		my $cr = crossing_text($xy);
		print "$cr";
		my($best) = get_nearest_crossing_coords(split(/,/, $xy));
		print "<input type=hidden name=" . $type .
		    "c value=\"$best\">";
		print "<input type=hidden name=" . $type .
		    "name value=\"$cr\">";
	    } else {
		choose_street_html($strasse,
				   $plz,
				   $type);
	    }
	    print "$fontend</td>" if $bi->{'can_table'};
	} elsif (@$matchref == 1) {
# XXX wann kommt man hierher?
	    print "<td>$fontstr" if $bi->{'can_table'};
	    choose_street_html($matchref->[0][0],
			       $matchref->[0][2],
			       $type);
	    print "$fontend</td>" if $bi->{'can_table'};
	} elsif (@$matchref > 1) {
	    print "<td>${fontstr}" if $bi->{'can_table'};
	    print "Genaue <b>" . $printtype .
	      "stra&szlig;e</b> ausw&auml;hlen:<br>\n";
	    my $s;
	    my $checked = 0;
	    foreach $s (@$matchref) {
		my $strasse2val;
		my $is_ort = $s->[MATCHREF_ISORT_INDEX];
		print "<input type=radio name=" . $type . "2";
		if ($is_ort && $multiorte) {
		    my($ret) = $multiorte->get_by_name($s->[0]);
		    my $xy;
		    if ($ret) {
			$xy = $ret->[1][0];
		    }
		    $strasse2val = join($delim, $s->[0], "#ort", $xy);
		    $s->[0] =~ s/\|/ /; # Zusatzbezeichnung von Orten
		} else {
		    $strasse2val = join($delim, @$s); # 0..3
		}
		print " value=\"$strasse2val\"";
		if (!$checked) {
		    print " checked";
		    $checked++;
		}
		print "> $s->[0]";
		if (defined $s->[1] && defined $s->[2]) {
		    print " (<font size=-1>$s->[1]" . ($s->[2] ne "" ? ", $s->[2]" : "") . "</font>)";
		}
		print "<br>\n";
	    }

	    if (defined $q->param($type . "hnr")) {
		print "<input type=hidden name=${type}hnr value=\""
		    . $q->param($type."hnr") . "\">\n";
	    }

	    if ($bi->{'can_table'}) {
		print "$fontend</td><td>";

		# show choices in the overview map, too
		if ($nice_berlinmap) {
		    print "<div id=${type}mapbelow style=\"position:relative;visibility:hidden;\">";
		    print "<img src=\"$bbbike_images/berlin_small.gif\" border=0 width=200 height=200 alt=\"\">";
		    print "</div>";

		    my $js = "";
		    my $match_nr = 0;

		    foreach $s (@$matchref) {
			$match_nr++;
			next if $s->[MATCHREF_ISORT_INDEX];
			my $xy = $s->[PLZ::LOOK_COORD()];
			next if !defined $xy;
			my($tx,$ty) = map { int $_ } overview_map()->{Transpose}->(split /,/, $xy);
			$tx -= 4; $ty -= 4; # center reddot.gif
			my $divid = $type . "match" . $match_nr;
			print "<div id=$divid style=\"position:absolute;visibility:show;background-color:#ff6060;\">";
			print "<a href=\"#\" onclick=\"document.BBBikeForm.${type}2[" . ($match_nr-1) . "].checked = true; return false;\"><img src=\"$bbbike_images/reddot.gif\" border=0 width=8 height=8 alt=\"$s->[0] ($s->[1])\"></a>";
			print "</div>";
			$js .= "pos_rel(\"$divid\", \"${type}mapbelow\", $tx, $ty);\nvis(\"$divid\", \"show\");\n";
		    }

		    print <<EOF;
<script type="text/javascript"><!--
function $ {type}map_init() { vis("${type}mapbelow", "show"); $js }
// --></script>
EOF
                    $has_init_map_js++;


		} else {
		    print "&nbsp;";
		}
		print "</td>";
	    }
	} else {
	    $tryempty = 1;
	}

	if ($tryempty) {
	    if (!$no_td) {
		# align=center was a mistake
		print "<td align=left>" if $bi->{'can_table'};
	    }
	    print "<input type=text name=$type>";
	    if ($use_mysql_db) {
		print "&nbsp;<input type=text name=${type}hnr size=4>";
	    }
	    print "<br>";
	    if (!$smallform) {
		abc_link($type, -nice => 1);

		if ($use_special_destinations) {
		    if ($type eq 'via') {
			print "<br>";
			print qq{<select $bi->{hfill} name="${type}special">
<option value="">oder ...
<option value="viabikeshop">Fahrradladen auf der Strecke
<option value="viabankomat">Geldautomat auf der Strecke
<option value="">Straße
</select>
};
		    } elsif ($type eq 'ziel') {
			print "<br>";
			print qq{<select $bi->{hfill} name="${type}special">
<option value="">oder ...
<option value="nextbikeshop">nächster Fahrradladen
<option value="nextbankomat">nächster Geldautomat
<option value="">Straße
</select>
};
		    }
		}

		print "</td><td>" if $bi->{'can_table'};
		if ($nice_berlinmap && !$no_berlinmap) {
		    print "<input type=hidden name=\"" . $type . "mapimg.x\" value=\"\">";
		    print "<input type=hidden name=\"" . $type . "mapimg.y\" value=\"\">";
		    print "<div id=" . $type . "mapbelow style=\"position:relative;visibility:hidden;\">";
		    print "<img src=\"$bbbike_images/berlin_small.gif\" border=0 width=200 height=200 alt=\"\">";
		    print "</div>";
		    print "<div id=" . $type . "mapabove style=\"position:absolute;visibility:hidden;\">";
		    print "<img src=\"$bbbike_images/berlin_small_hi.gif\" border=0 width=200 height=200 alt=\"\">";
		    print "</div>";
		    print <<EOF;
<script type="text/javascript"><!--
function $ {type}map_init() { return any_init("${type}map"); }
function $ {type}map_highlight(Evt) { return any_highlight("${type}map", Evt); }
function $ {type}map_byebye(Evt) { return any_byebye("${type}map", Evt); }
function $ {type}map_detail(Evt) { return any_detail("${type}map", Evt); }
// --></script>
EOF
		} elsif (!$bi->{'text_browser'} && !$no_berlinmap) {
		    print "<input type=image name=" . $type
		      . "mapimg src=\"$bbbike_images/berlin_small.gif\" class=\"citymap\" alt=\"\">";
		}
		print "</td>" if $bi->{'can_table'};
	    }
	} elsif ($nice_berlinmap) {
	    if (!$has_init_map_js) {
		print "<script type=\"text/javascript\"><!--
function " . $type . "map_init() {}
//--></script>\n";
	    }
            print "<script type=\"text/javascript\"><!--
function " . $type . "char_init() {}
//--></script>\n";
        }
	if ($bi->{'can_table'}) {
	    print "<td width=40>&nbsp;</td></tr>\n";
	} else {
	    print "<p>\n";
	}
    }
    $nl->();

    hidden_smallform();

    {
	my $button_str = "";
	if (($start2 ne "" || $startname ne "" ||
	     $via2 ne "" || $vianame ne "" ||
	     $ziel2 ne "" || $zielname ne "") &&
	    $bi->{'can_javascript'}) {
	    $button_str .= "<input type=button value=\"&lt;&lt; Zurück\" onclick=\"history.back(1);\">&nbsp;&nbsp;";
	}
	$button_str .= "<a name=\"weiter\"><input type=submit value=\"Weiter &gt;&gt;\"></a>";
	$tbl_center->($button_str);
    }

    print "</table>\n" if $bi->{'can_table'};

    print "<hr>";

    if (!$smallform) {
	print window_open("$bbbike_script?all=1", "BBBikeAll",
			  "dependent,height=500,resizable," .
			  "screenX=500,screenY=30,scrollbars,width=250")
	    . "Liste aller bekannten Stra&szlig;en</a> (ca. 75 kB)";
	print "<hr>";
    }

    print footer_as_string();
    print "</form>\n";

    print $q->end_html;
}

sub choose_ch_form {
    my($search_char, $search_type) = @_;
    my $use_javascript = ($bi->{'can_javascript'} &&
			  !$bi->{'javascript_incomplete'});

    use locale;
    eval {
	local $SIG{'__DIE__'};
	require POSIX;
	foreach my $locale (qw(de de_DE de_DE.ISO8859-1 de_DE.ISO_8859-1)) {
	    # Aha. Bei &POSIX::LC_ALL gibt es eine Warnung, ohne & und mit ()
	    # funktioniert es reibungslos.
	    last if POSIX::setlocale( POSIX::LC_ALL(), $locale);
	}
    };
    print $q->header(@weak_cache, etag());
    header();
    print "<b>" . ucfirst($search_type) . "</b>";
    print " (Anfangsbuchstabe <b>$search_char</b>)<br>\n";
    my $next_char =
      (ord($search_char) < ord('Z') ? chr(ord($search_char)+1) : undef);
    my $prev_char =
      (ord($search_char) > ord('A') ? chr(ord($search_char)-1) : undef);
    print "<form action=\"$bbbike_script\" name=Charform>\n";
    if (!$use_javascript) {
	print "<input type=submit value=\"Weiter &gt;&gt;\"><br>";
    }
    foreach ($q->param) {
	unless ($_ eq 'startchar' || $_ eq 'viachar' || $_ eq 'zielchar' ||
		$_ eq $search_type) {
	    # Lynx-Bug (oder Feature?): hidden-Variable werden nicht von
	    # der nachfolgenden Radio-Liste überschrieben
	    next if ($_ =~ /^$search_type/);
	    print "<input type=hidden name=$_ value=\""
	      . $q->param($_) . "\">\n";
	}
    }

    my $regex_char = "^" . ($search_char eq 'A'
			    ? '[AÄ]'
			    : ($search_char eq 'O'
			       ? '[OÖ]'
			       : ($search_char eq 'U'
				  ? '[UÜ]'
				  : $search_char)));
    my @strlist;
    $str->init;
    eval q{ # eval wegen /o
	while(1) {
	    my $ret = $str->next;
	    last if !@{$ret->[1]};
	    my $name = $ret->[0];
	    push(@strlist, $name) if $name =~ /$regex_char/oi;
	}
    };
    @strlist = sort @strlist;

    print
      "<input type=radio name=" . $search_type . "name value=\"\"" ,
      ($use_javascript ? " onclick=\"document.Charform.submit()\"" : ""),
      "> ",
      ($use_javascript ? "(Zurück zum Eingabeformular)" : "(nicht gesetzt)"),
      "<br>\n";

    my $last_name;
    for(my $i = 0; $i <= $#strlist; $i++) {
	my $name = $strlist[$i];
	if (defined $last_name and $name eq $last_name) {
	    next;
	} else {
	    $last_name = $name;
	}
	print
	  "<input type=radio name=" . $search_type . "name value=\"$name\"",
	  ($use_javascript ? " onclick=\"document.Charform.submit()\"" : ""),
	  "> ",
	  $name,
	  "<br>\n";
    }

    print "<br>";
    if (!$use_javascript) {
	print "<input type=submit value=\"Weiter &gt;&gt;\"><br><br>\n";
    }
    print "andere " . ucfirst($search_type) . "stra&szlig;e:<br>\n";
    abc_link($search_type);
    footer();
    print "</form>\n";
    print $q->end_html;
}

sub get_kreuzung {
    my($start_str, $via_str, $ziel_str) = @_;
    if (!defined $start_str) {
	$start_str = $q->param('startname');
    }
    if (!defined $via_str) {
	$via_str = $q->param('vianame');
    }
    if ($via_str =~ /^\s*$/) {
	undef $via_str;
    }
    if (!defined $ziel_str) {
	$ziel_str  = $q->param('zielname');
    }
    my $start_plz = $q->param('startplz');
    my $via_plz   = $q->param('viaplz');
    my $ziel_plz  = $q->param('zielplz');

    my $start_c   = $q->param('startc');
    my $via_c     = $q->param('viac');
    my $ziel_c    = $q->param('zielc');

    my %is_ort;
    foreach (qw(start via ziel)) {
	$is_ort{$_} = $q->param($_ . 'isort');
    }

    my($start, $via, $ziel);
    my(@start_coords, @via_coords, @ziel_coords);

    if ($use_mysql_db) {
	my $tdb;
	foreach my $type (qw(start via ziel)) {
	    my($str_normed, $citypart);
	    my $hnr = $q->param($type."hnr");
	    if (defined $q->param($type."2") && $q->param($type."2") !~ /^\s*$/) {
		($str_normed, $citypart) = split $delim, $q->param($type."2");
	    } else {
		$str_normed = eval "\$".$type.'_str'; die $@ if $@;
	    }
	    next if (!defined $str_normed || $str_normed =~ /^\s*$/);

	    if (defined $hnr && $hnr =~ /\d/) {
		if (!$tdb) {
		    require TelbuchDBApprox;
		    $tdb = TelbuchDBApprox->new
			or die;
		}
		if (defined $q->param($type."2")) {
		    ($str_normed, $citypart) = split $delim, $q->param($type."2");
		} else {
		    $str_normed = eval "\$".$type.'_str'; die $@ if $@;
		}
		my(@res) = $tdb->search("$str_normed $hnr", undef, $citypart,
					-maxtry => TelbuchDBApprox::TRY_NO_CITYPART());
		if (@res == 1) {
		    eval "\$".$type."_c = \"$res[0]->{Coord}\""; die $@ if $@;
		}
	    }
	}
    }

    $str->init;
    # Abbruch kann hier nicht früher erfolgen, da Straßen unterbrochen
    # sein können
    while(1) {
	my $ret = $str->next;
	last if !@{$ret->[1]};
	my $name = $ret->[0];
	if (defined $start_str && $start_str eq $name and !defined $start_c) {
	    $start   = $str->pos;
	    push @start_coords, @{$ret->[1]};
	}
	if (defined $via_str && $via_str eq $name and !defined $via_c) {
	    $via     = $str->pos;
	    push @via_coords, @{$ret->[1]};
	}
	if (defined $ziel_str && $ziel_str  eq $name and !defined $ziel_c) {
	    $ziel   = $str->pos;
	    push @ziel_coords, @{$ret->[1]};
	}
    }

    if (!defined $start and !defined $start_c) {
	confess "Fehler: Start $start kann nicht zugeordnet werden.<br>\n";
    }
    if (!defined $ziel  and !defined $ziel_c) {
	confess "Fehler: Ziel $ziel kann nicht zugeordnet werden.<br>\n";
    }

    if (@start_coords == 1 and @ziel_coords == 1 and
	(@via_coords == 1 or !defined $via)) {
	# nur eine Kreuzung für alle Punkte vorhanden
	# => gleich zur Suche springen bzw. nur die Preferences anzeigen
	$q->param('startc', $start_coords[0]);
	$q->param('startname', $start_str);
	$q->param('zielc',  $ziel_coords[0]);
	$q->param('zielname', $ziel_str);
	if (defined $via) {
	    $q->param('viac',  $via_coords[0]);
	    $q->param('vianame', $via_str);
	}
	## Das hier muss man wieder herein nehmen, wenn man nicht die
	## Preferences braucht:
	# search_coord();
	# exit(0);
    }

    print $q->header(@weak_cache, etag());
    header();

    if (!$start_c || !$ziel_c || (@via_coords && !$via_c)) {
	print "Genaue Kreuzung angeben:<p>\n";
    }

    all_crossings();

    print "<form action=\"$bbbike_script\">";


    print "<table>\n" if ($bi->{'can_table'});

    foreach ([$start_str, \@start_coords, $start_plz, $start_c, 'start',
	      $start_bgcolor],
	     [$via_str,   \@via_coords,   $via_plz,   $via_c,   'via',
	      $via_bgcolor],
	     [$ziel_str,  \@ziel_coords,  $ziel_plz,  $ziel_c,  'ziel',
	      $ziel_bgcolor],
	    ) {
	my($strname,      $coords_ref,    $plz,       $c,       $type,
	   $bgcolor) = @$_;
	my $bgcolor_s = $bgcolor ne '' ? "bgcolor=$bgcolor" : '';
	my @coords = @$coords_ref;
	next if !@coords and !$c; # kann bei nicht definiertem Via vorkommen
	my $printtype = ucfirst($type);

	print "<tr $bgcolor_s><td>"
	    if ($bi->{'can_table'});
	print "<b>$printtype</b>: ";
	print "</td><td>"
	    if ($bi->{'can_table'});

	if (@coords == 1) {
	    $c = $coords[0];
	}
	if (defined $c) {
	    print "<input type=hidden name=" . $type . "c value=\"$c\">";
	}
	if (defined $c and (not defined $strname or $strname eq '')) {
	    print crossing_text($c) . "<br>\n";
	} else {
	    if (defined $plz and $plz eq '') {
		print $strname;
	    } else {
		if (defined $c && $use_coord_link) {
		    print coord_link($strname, $c);
		} else {
		    print stadtplan_link($strname, $plz, $is_ort{$type});
		}
	    }
	}
	if (defined $q->param($type."hnr") && $q->param($type."hnr") ne "") {
	    print " " . $q->param($type . "hnr");
	}
	# Parameter durchschleifen...
	if (defined $strname) {
	    print "<input type=hidden name=" . $type .
	      "name value=\"$strname\">";
	}
	if (defined $q->param($type . "plz")) {
	    print "<input type=hidden name=" . $type . "plz value=\"" .
	      $q->param($type . "plz") . "\">\n";
	}
	if (defined $q->param($type."hnr") && $q->param($type."hnr") ne "") {
	    print "<input type=hidden name=" . $type . "hnr value=\"" .
	      $q->param($type . "hnr") . "\">\n";
	}
	if ($is_ort{$type}) {
	    print "<input type=hidden name=" . $type . "isort value=1>\n";
	}
	if (!defined $c) {
	    my $i = 0;
	    my %used;
	    my $ecke_printed = 0;
	    foreach (@coords) {
		# inaccessible point
		next if ($inaccess_str && $inaccess_str->{$_});
		unless ($ecke_printed) {
		    if ($use_select) {
			print " Ecke ";
			if ($bi->{'can_table'}) {
			    print "</td><td>";
			}
			print "<select $bi->{hfill} name=" . $type . "c>";
		    } else {
			print " Ecke ...<br>\n";
		    }
		    $ecke_printed++;
		}
		if ($used{$_}) {
		    next;
		} else {
		    $used{$_}++;
		}
		if (exists $crossings->{$_}) {
		    if ($use_select) {
			print "<option value=\"$_\">";
		    } else {
			print
			  "<input type=radio name=" . $type . "c ",
			  "value=\"$_\"";
			if ($i++ == 0) {
			    print " checked";
			}
			print "> ";
		    }
		    my @kreuzung;
		    foreach (@{$crossings->{$_}}) {
			if ($_ ne $strname) {
			    push(@kreuzung, $_);
			}
		    }
		    if (@kreuzung == 0) {
			print "..."; # XXX bessere Loesung?
		    } else {
			print join("/", @kreuzung);
		    }
		    print "<br>" unless $use_select;
		    print "\n";
		}
	    }
	    print "</select>" if $use_select && $ecke_printed;

#XXX
#  	    my $img_url = crossing_map($type, \@coords);
#  	    if ($img_url) {
#  		print "<img src=\"$img_url\">";
#  	    }
	}
	if ($bi->{'can_table'}) {
	    print "</td></tr>\n";
	} else {
	    print "" . ($type ne 'ziel' ? '<hr>' : '<br><br>') . "\n";
	}
    }

    print "</table>\n" if ($bi->{'can_table'});

    hidden_smallform();


    print <<EOF;
<hr><p><b>Einstellungen</b>:</p>
EOF
    settings_html();
    print "<hr>\n";

    suche_button();
## Nahbereich ist nur verwirrend...
#      # probably tkweb - work around form submit bug
#      if ($q->user_agent !~ m|libwww-perl|) {
#  	print " <font size=\"-1\"><input type=submit name=nahbereich value=\"Nahbereich\"></font>\n";
#      }
    footer();
    print "</form>";
    print $q->end_html;
}

#XXX hmmm... muss gründlicher überlegt werden.
#  sub crossing_map {
#      my($type, $coordsref) = @_;
#      return if !-d $mapdir_fs || !-w $mapdir_fs;
#      return if $^O eq 'MSWin32'; # no fork XXX
#      my $draw;
#      eval {
#  	local $SIG{'__DIE__'};
#  	require BBBikeDraw;
#  	BBBikeDraw->VERSION(2.26);
#  	$draw = new BBBikeDraw
#  	    Geometry => "100x100",
#  	    Draw => ['title', 'wasser', 'flaechen', 'ubahn', 'sbahn', 'str'],
#  	;
#  	die $@ if !$draw;
#      };
#      return if ($@);
#      my $basefile = "_crossing_".$$."_".$type.".".$draw->suffix;
#      if (fork == 0) {
#  	# XXX $$ is not enough for modperl!!!
#  	$draw->{Coords} = $coordsref;
#  	eval { $draw->pre_draw }; return if $@;
#  	$draw->draw_map;
#  	$draw->draw_route;
#  	open(IMG, ">$mapdir_fs/$basefile")
#  	    or die "Can't write to $mapdir_fs/$basefile: $!";
#  	binmode IMG;
#  	$draw->flush(Fh => \*IMG);
#  	close IMG;
#  	exit 0;
#      } else {
#  	return "$mapdir_url/$basefile";
#      }
#  }

sub settings_html {
    # Einstellungen ########################################
    my %c = $q->cookie(-name => $cookiename);

    foreach my $key (@pref_keys) {
	$c{"pref_$key"} = $q->param("pref_$key")
	    if defined $q->param("pref_$key");
    }

    my(%strcat)    = ("" => 0, "N1" => 1, "N2" => 2, "H1" => 3, "H2" => 4);
    my(%strqual)   = ("" => 0, "Q0" => 1, "Q2" => 2);
    my(%strrouten) = ("" => 0, "RR" => 1);

    my $default_speed   = (defined $c{"pref_speed"}   ? $c{"pref_speed"}+0 : 20);
    my $default_cat     = (defined $c{"pref_cat"}     ? $c{"pref_cat"}     : "");
    my $default_quality = (defined $c{"pref_quality"} ? $c{"pref_quality"} : "");
    my $default_ampel   = (defined $c{"pref_ampel"} && $c{"pref_ampel"} eq 'yes' ? 1 : 0);
    my $default_routen  = (defined $c{"pref_routen"}  ? $c{"pref_routen"}  : "");
    my $default_green   = (defined $c{"pref_green"} && $c{"pref_green"} eq 'yes' ? 1 : 0);

    my $cat_checked = sub { my $val = shift;
			    'value="' . $val . '" ' .
			    ($default_cat eq $val ? "selected" : "")
			};
    my $qual_checked = sub { my $val = shift;
			     'value="' . $val . '" ' .
			     ($default_quality eq $val ? "selected" : "")
			 };
    my $routen_checked = sub { my $val = shift;
			       'value="' . $val . '" ' .
			       ($default_routen eq $val ? "selected" : "")
			 };

    if ($bi->{'can_javascript'}) {
	print <<EOF;
<script type="text/javascript"><!--
function reset_form() {
    var frm = document.forms.settings;
    if (!frm) {
	frm = document.forms[0];
    }
    with (frm) {
	elements["pref_speed"].value = $default_speed;
	elements["pref_cat"].options[@{[defined $strcat{$default_cat} ? $strcat{$default_cat} : 0]}].selected = true;
	elements["pref_quality"].options[@{[defined $strqual{$default_quality} ? $strqual{$default_quality}: 0]}].selected = true;
//	elements["pref_routen"].options[@{[defined $strrouten{$default_routen} ? $strrouten{$default_routen} : 0]}].selected = true;
	elements["pref_ampel"].checked = @{[ $default_ampel?"true":"false" ]};
	elements["pref_green"].checked = @{[ $default_green?"true":"false" ]};
    }
    return false;
}
//--></script>
EOF
    }
    print <<EOF;
<input type=hidden name="pref_seen" value=1>
<table>
<tr><td>Bevorzugte Geschwindigkeit:</td><td><input type=text maxlength=4 size=2 name="pref_speed" value="$default_speed"> km/h</td></tr>
<tr><td>Bevorzugter Straßentyp:</td><td><select $bi->{hfill} name="pref_cat">
<option @{[ $cat_checked->("") ]}>egal
<option @{[ $cat_checked->("N1") ]}>Nebenstraßen bevorzugen
<option @{[ $cat_checked->("N2") ]}>nur Nebenstraßen benutzen
<option @{[ $cat_checked->("H1") ]}>Hauptstraßen bevorzugen
<option @{[ $cat_checked->("H2") ]}>nur Hauptstraßen benutzen
<option @{[ $cat_checked->("N_RW") ]}>Hauptstraßen ohne Radwege meiden
</select></td></tr>
<tr><td>Bevorzugter Straßenbelag:</td><td><select $bi->{hfill} name="pref_quality">
<option @{[ $qual_checked->("") ]}>egal
<option @{[ $qual_checked->("Q0") ]}>nur sehr gute Beläge bevorzugen (rennradtauglich)
<option @{[ $qual_checked->("Q2") ]}>Kopfsteinpflaster vermeiden
</select></td></tr>
<!--
<tr><td>Ausgeschilderte Fahrradrouten bevorzugen:</td><td><select $bi->{hfill} name="pref_routen">
<option @{[ $routen_checked->("") ]}>egal
<option @{[ $routen_checked->("RR") ]}>ja
</select></td></tr>
-->
<!--XXX implement <tr><td>Radwege:</td><td><select $bi->{hfill} name="pref_rw">
<option value="">egal
<option value="R0">nur Radwege verwenden
<option value="R1">Hauptstraßen mit Radweg bevorzugen
<option value="R2">benutzungspflichtige Radwege vermeiden
</select></td></tr>-->
<tr><td>Ampeln vermeiden:</td><td><input type=checkbox name="pref_ampel" value=yes @{[ $default_ampel?"checked":"" ]}></td>
<tr><td>Grüne Wege bevorzugen:</td><td><input type=checkbox name="pref_green" value=yes @{[ $default_green?"checked":"" ]}></td>
EOF
    if ($bi->{'can_javascript'}) {
	print <<EOF
<td><input type=button value="Reset" onclick="return reset_form();"></td>
EOF
    }
print <<EOF;
</tr>
</table>
EOF
}

sub suche_button {
    if ($bi->{'can_javascript'}) {
	print "<input type=button value=\"&lt;&lt; Zurück\" onclick=\"history.back(1);\">&nbsp;&nbsp;";
    }
    print "<input type=submit value=\"Route zeigen &gt;&gt;\">\n";
}

sub hidden_smallform {
    # Hier die Query-Variable statt der Perl-Variablen benutzen...
    if ($q->param('smallform')) {
	print "<input type=hidden name=smallform value=\"" .
	  $q->param('smallform') . "\">\n";
    }
}

sub via_not_needed {
    my($via, $via2, $vianame) = @_;
    $via     = $q->param('via')     if !defined $via;
    $via2    = $q->param('via2')    if !defined $via2;
    $vianame = $q->param('vianame') if !defined $vianame;

    !(((defined $via2 && $via2 ne '') ||
       (defined $via  && $via  ne '' && $via ne 'NO')) &&
      (!defined $vianame || $vianame eq ''));
}

sub make_netz {
    my $lite = shift;
    if (!$net) {
	$net = new StrassenNetz $multistr;
	# XXX überprüfen, ob sich der Cache lohnt...
	# evtl. mit IPC::Shareable arbeiten (Server etc.)
	$net->make_net(UseCache => 1);
	if (!$lite) {
	    $net->make_sperre('gesperrt',
			      Type => ['einbahn', 'sperre',
				       #'tragen',
				       'wegfuehrung']);
	}
    }
    $net;
}

sub search_coord {
    my $startcoord  = $q->param('startc');
    my $viacoord    = $q->param('viac');
    my $zielcoord   = $q->param('zielc');
    my $startname   = name_from_cgi($q, 'start');
    my $vianame     = name_from_cgi($q, 'via');
    my $zielname    = name_from_cgi($q, 'ziel');
    my $starthnr    = $q->param('starthnr');
    my $viahnr      = $q->param('viahnr');
    my $zielhnr     = $q->param('zielhnr');
    my $alternative = $q->param('alternative');
    my $custom      = $q->param('custom');
    my $output_as   = $q->param('output_as');
    my $printmode   = defined $output_as && $output_as eq 'print';

    my $printwidth  = 400;
    my $fontstr     = ($printmode
		       ? "<font face=\"$font\" size=\"-2\">"
		       : $fontstr);

    make_netz();

    ($startcoord, $viacoord, $zielcoord)
      = fix_coords($startcoord, $viacoord, $zielcoord);

    if ($inaccess_str) {
	if (exists $inaccess_str->{$startcoord} ||
	    (defined $viacoord && exists $inaccess_str->{$viacoord}) ||
	    exists $inaccess_str->{$zielcoord}) {
	    print $q->header;
	    print "Die angegebenen Punkte <$startcoord>, <$viacoord>, <$zielcoord> können nicht erreicht werden.<br>\n";
	    print "<a href=\"$bbbike_url\">Zurück zu BBBike</a><br>";
	    exit(0);
	}
    }

    my $via_array = (defined $viacoord && $viacoord ne ''
		     ? [$viacoord]
		     : []);

    my %extra_args;
    if (@$via_array) {
	$extra_args{Via} = $via_array;
	# siehe Kommentar in search: Via und All beißen sich
    } else {
	$extra_args{All} = 1;
    }

    # Tragen vermeiden
    $extra_args{Tragen} = 1;
    my $velocity_kmh = $q->param("pref_speed") || 20;
    $extra_args{Velocity} = $velocity_kmh/3.6; # convert to m/s
    # XXX Anzahl der Tragestellen zählen...

    # Ampeloptimierung
    if (defined $q->param('pref_ampel') && $q->param('pref_ampel') eq 'yes') {
	if (new_trafficlights()) {
	    $extra_args{Ampeln} = {Net     => $ampeln,
				   Penalty => 100};
	}
    }

    # Haupt/Freizeitrouten-Optimierung
    if (defined $q->param('pref_routen') && $q->param('pref_routen') ne '') { # 'RR'
	if (!$routen_net) {
	    $routen_net =
		new StrassenNetz(Strassen->new("radrouten"));
	    $routen_net->make_net;
	}
	$extra_args{UserDefPenaltySub} = sub {
	    my($p, $next_node, $last_node) = @_;
	    if (!$routen_net->{Net}{$last_node}{$next_node}) {
		$p *= 2; # XXX differenzieren?
	    }
	    $p;
	};
    }

    # Optimierung der grünen Wege
    if (defined $q->param('pref_green') && $q->param('pref_green') ne '') {
	if (!$green_net) {
	    $green_net = new StrassenNetz(Strassen->new("green"));
	    $green_net->make_net_cat;
	}
	my $penalty = { "green0" => 3,
			"green1" => 2,
			"green2" => 1,
		      };
	$extra_args{Green} =
	    {Net => $green_net,
	     Penalty => $penalty,
	    };
    }

    # Handicap-Optimierung ... zurzeit nur Fußgängerzonenoptimierung automatisch
    if (1) {
	if (!$handicap_s_net) {
	    $handicap_s_net =
		new StrassenNetz(Strassen->new("handicap_s"));
	    $handicap_s_net->make_net_cat;
	}
	my $penalty;
	$penalty = { "q4" => $velocity_kmh/5, # hardcoded für Fußgängerzonen
		   };
	for my $q (0 .. 3) {
	    $penalty->{"q$q"} = 1;
	}
	$extra_args{Handicap} =
	    {Net => $handicap_s_net,
	     Penalty => $penalty,
	    };

    }

    # Qualitätsoptimierung
    if (defined $q->param('pref_quality') && $q->param('pref_quality') ne '') {
	# XXX landstraßen?
	if (!$qualitaet_s_net) {
	    $qualitaet_s_net =
		new StrassenNetz(Strassen->new("qualitaet_s"));
	    $qualitaet_s_net->make_net_cat;
	}
	my $penalty;
	if ($q->param('pref_quality') eq 'Q2') {
	    $penalty = { "Q0" => 1,
			 "Q1" => 1.2,
			 "Q2" => 1.6,
			 "Q3" => 2 };
	} else {
	    $penalty = { "Q0" => 1,
			 "Q1" => 1,
			 "Q2" => 1.5,
			 "Q3" => 1.8 };
	}
	$extra_args{Qualitaet} =
	    {Net => $qualitaet_s_net,
	     Penalty => $penalty,
	    };

    }

    # Kategorieoptimierung
    if (defined $q->param('pref_cat') && $q->param('pref_cat') ne '') {
	my $penalty;
	if ($q->param('pref_cat') eq 'N_RW') {
	    if (!$radwege_strcat_net) {
		$radwege_strcat_net = new StrassenNetz $multistr;
		$radwege_strcat_net->make_net_cyclepath(Strassen->new("radwege_exact"), 'N_RW', UseCache => 0); # UseCache => 1 for munich
	    }
	    $penalty = { "H"    => 4,
			 "H_RW" => 1,
			 "N"    => 1,
			 "N_RW" => 1 };
	    $extra_args{RadwegeStrcat} =
		{Net => $radwege_strcat_net,
		 Penalty => $penalty,
		};
	} else {
	    if (!$strcat_net) {
		$strcat_net = new StrassenNetz $multistr;
		$strcat_net->make_net_cat(-usecache => 0); # 1 for munich
	    }
	    if ($q->param('pref_cat') eq 'N2') {
		$penalty = { "HH" => 4,
			     "H"  => 4,
			     "N"  => 1,
			     "NN" => 1 };
	    } elsif ($q->param('pref_cat') eq 'N1') {
		$penalty = { "HH" => 1.5,
			     "H"  => 1.5,
			     "N"  => 1,
			     "NN" => 1 };
	    } elsif ($q->param('pref_cat') eq 'H1') {
		$penalty = { "HH" => 1,
			     "H"  => 1,
			     "N"  => 1.5,
			     "NN" => 1.5 };
	    } elsif ($q->param('pref_cat') eq 'H2') {
		$penalty = { "HH" => 1,
			     "H"  => 1,
			     "N"  => 4,
			     "NN" => 4 };
	    }
	    $extra_args{Strcat} =
		{Net => $strcat_net,
		 Penalty => $penalty,
		};
	}
    }

    if (defined $search_algorithm) {
	$extra_args{Algorithm} = $search_algorithm;
    }

    my(%custom_s, $custom_net, %current_temp_blocking);
    {
	my $t = time;
	for my $temp_blocking (@temp_blocking) {
	    if ($t >= $temp_blocking->{from} &&
		$t <= $temp_blocking->{until}) {
		my $type = $temp_blocking->{type} || 'gesperrt';
		push @{ $current_temp_blocking{$type} }, $temp_blocking;
	    }
	}
	if (keys %current_temp_blocking) {
	    push @Strassen::datadirs,
		"$FindBin::RealBin/../BBBike/misc/temp_blockings",
		"$FindBin::RealBin/../misc/temp_blockings"
		;
	}
	while(my($type, $list) = each %current_temp_blocking) {
	    if (@$list) {
		eval {
		    $custom_s{$type} = MultiStrassen->new
			(map { $_->{file} } @$list);
		};
		warn $@ if $@;
	    }
	    if ($custom && $custom eq 'temp-blocking') {
		if ($type eq 'gesperrt' && $custom_s{$type}) {
		    $net->load_user_deletions
			($custom_s{$type},
			 -merge => 1,
			);
		} elsif ($type eq 'handicap' && $custom_s{$type}) {
		    if (!$handicap_s_net) {
			warn "No net for handicap defined, ignoring temp_blocking=handicap";
		    } else {
			$handicap_s_net->merge_net_cat($custom_s{$type});
		    }
		}
	    }
	}
	if (keys %custom_s) {
	    eval {
		my $custom_multi = MultiStrassen->new(values %custom_s);
		$custom_net = StrassenNetz->new($custom_multi);
		$custom_net->make_net;
	    };
	    warn $@ if @;
	}
    }

    my(@r) = $net->search($startcoord, $zielcoord,
			  AsObj => 1,
			  %extra_args);

    if (defined $output_as && $output_as eq 'palmdoc') {
	require BBBikePalm;
	print $q->header("application/x-palm-database");
	print BBBikePalm::route2palm(-net => $net, -route => $r[0],
				     -startname => $startname,
				     -zielname => $zielname);
	return;
    }

    if (defined $output_as && $output_as eq 'mapserver') {
	$q->param('coords', join("!", map { "$_->[0],$_->[1]" }
				 @{ $r[0]->path }));
	$q->param("imagetype", "mapserver");
	draw_route();
	return;
    }

    my(@weather_res);
    if ($show_weather || $bp_obj) {
	@weather_res = gather_weather_proc();
    }

    my $sess = tie_session(undef);

    my $r;
    my @out_route;
    my %speed_map;
    my %power_map;
    my @strnames;
    my @path;
 CALC_ROUTE_TEXT: {
	last CALC_ROUTE_TEXT if (!@r);

	if (defined $alternative &&
	    $alternative >= 0 && $alternative <= $#r) {
	    $r = $r[$alternative];
	} else {
	    $r = $r[0];
	}

	last CALC_ROUTE_TEXT if (!$r->path_list);

	my(@power) = (50, 100, 200);
	my @bikepwr_time = (0, 0, 0);
	use vars qw($wind_dir $wind_v %wind_dir $wind); # XXX oben definieren
	if ($bp_obj && @weather_res && exists $wind_dir{lc($weather_res[4])}) {
	    analyze_wind_dir($weather_res[4]);
	    $wind = 1;
	    $wind_v = $weather_res[7];
	    my(@path) = $r->path_list;
	    for(my $i = 0; $i < $#path; $i++) {
		my($x1, $y1) = @{$path[$i]};
		my($x2, $y2) = @{$path[$i+1]};
		my($deltax, $deltay) = ($x1-$x2, $y1-$y2);
		my $etappe = sqrt(sqr($deltax) + sqr($deltay));
		next if $etappe == 0;
# XXX feststellen, warum hier ein Minus stehen muß...
		my $hw = -head_wind($deltax, $deltay);
		# XXX Doppelung mit bbbike-Code vermeiden
		my $wind; # Berechnung des Gegenwindes
		if ($hw >= 2) {
		    $wind = -$wind_v;
		} elsif ($hw > 0) { # unsicher beim Crosswind
		    $wind = -$wind_v*0.7;
		} elsif ($hw > -2) {
		    $wind = $wind_v*0.7;
		} else {
		    $wind = $wind_v;
		}
		for my $i (0 .. 2) {
		    # XXX Höhenberechnung nicht vergessen
		    # XXX Doppelung mit bbbike-Code vermeiden
		    my $bikepwr_time_etappe =
		      ( $etappe / bikepwr_get_v($wind, $power[$i]));
		    $bikepwr_time[$i] += $bikepwr_time_etappe;
		}
	    }
	}

	@strnames = $net->route_to_name($r->path);

	my @speeds = qw(10 15 20 25);
	if ($q->param('pref_speed')) {
	    if (!grep { $_ == $q->param('pref_speed') } @speeds) {
		push @speeds, $q->param('pref_speed');
		@speeds = sort { $a <=> $b } @speeds;
		if ($q->param('pref_speed') > 17) {
		    shift @speeds;
		} else {
		    pop @speeds;
		}
	    }
	}

	foreach my $speed (@speeds) {
	    my $def = {};
	    $def->{Pref} = ($q->param('pref_speed') && $speed == $q->param('pref_speed'));
	    my $time;
	    if ($handicap_s_net) {
		my %handicap_s_speed = ("q4" => 5); # hardcoded für Fußgängerzonen
		$time = 0;
		my @realcoords = @{ $r[0]->path };
		for(my $ii=0; $ii<$#realcoords; $ii++) {
		    my $s = Strassen::Util::strecke($realcoords[$ii],$realcoords[$ii+1]);
		    my @etappe_speeds = $speed;
#		    if ($qualitaet_s_net && (my $cat = $qualitaet_s_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
#		    push @etappe_speeds, $qualitaet_s_speed{$cat}
#			if defined $qualitaet_s_speed{$cat};
#		}
		    if ($handicap_s_net && (my $cat = $handicap_s_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
			push @etappe_speeds, $handicap_s_speed{$cat}
			    if defined $handicap_s_speed{$cat};
		    }
		    $time += ($s/1000)/min(@etappe_speeds);
		}
	    } else {
		$time = $r->len/1000/$speed;
	    }
	    $def->{Time} = $time;
	    $speed_map{$speed} = $def;
	}

	if ($bp_obj and $bikepwr_time[0]) {
	    for my $i (0 .. $#power) {
		$power_map{$power[$i]} = {Time => $bikepwr_time[$i]};
	    }
	}

	if (!defined $r->trafficlights && new_trafficlights()) {
	    $r->add_trafficlights($ampeln);
	}

	if ($with_comments) {
	    if (!$comments_net) {
		my @s;
		my @comment_files = qw(comments qualitaet_s);
		if ($custom && $custom eq 'temp-blocking' &&
		    $custom_s{"handicap"}) {
		    push @s, $custom_s{"handicap"};
		} else {
		    push @comment_files, "handicap_s";
		}
		for my $s (@comment_files) {
		    eval {
			push @s, Strassen->new($s);
		    };
		    warn "$s: $@" if $@;
		}
		if (@s) {
		    $comments_net = StrassenNetz->new(MultiStrassen->new(@s));
		    $comments_net->make_net_cat(-net2name => 1, -multiple => 1);
		}
	    }
	    @path = $r->path_list;
	}

	my($next_entf, $ges_entf_s, $next_winkel, $next_richtung, $next_route_inx);
	($next_entf, $ges_entf_s, $next_winkel, $next_richtung, $next_route_inx)
	    = (0, "", undef, "");

	my $ges_entf = 0;
	for(my $i = 0; $i <= $#strnames; $i++) {
	    my $strname;
	    my $etappe_comment = '';
	    my $entf_s;
	    my $raw_direction;
	    my($entf, $winkel, $richtung, $route_inx)
		= ($next_entf, $next_winkel, $next_richtung, $next_route_inx);
	    ($strname, $next_entf, $next_winkel, $next_richtung, $next_route_inx)
		= @{$strnames[$i]};
	    if ($i > 0) {
		if (!$winkel) { $winkel = 0 }
		$winkel = int($winkel/10)*10;
		if ($winkel < 30) {
		    $richtung = "";
		    $raw_direction = "";
		} else {
		    $raw_direction =
			($winkel <= 45 ? 'h' : '') .
			    ($richtung eq 'l' ? 'l' : 'r');
		    $richtung =
			($winkel <= 45 ? 'halb' : '') .
			    ($richtung eq 'l' ? 'links ' : 'rechts ') .
				"($winkel°) " . Strasse::de_artikel($strname);
		}
		$ges_entf += $entf;
		$ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
		$entf_s = sprintf "nach %.2f km", $entf/1000;
	    } elsif ($#{ $r->path } > 1) {
		# XXX main:: ist haesslich
		$raw_direction =
		    uc(#main::opposite_direction #XXX why???
		       (main::line_to_canvas_direction
			(@{ $r->path->[0] },
			 @{ $r->path->[1] })));
		$richtung = "nach " . $raw_direction;
	    }

	    if ($with_comments && $comments_net) {
		my @comments;
		my %seen_comments_in_this_etappe;
		for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		    my @etappe_comments = $comments_net->get_point_comment(\@path, $i, undef);
		    foreach my $etappe_comment (@etappe_comments) {
			$etappe_comment =~ s/^.+?:\s+//; # strip street
			if (!exists $seen_comments_in_this_etappe{$etappe_comment}) {
			    push @comments, $etappe_comment;
			    $seen_comments_in_this_etappe{$etappe_comment}++;
			}
		    }
		}
		$etappe_comment = join("; ", @comments) if @comments;
	    }

	    push @out_route, {
			      Dist => $entf,
			      DistString => $entf_s,
			      TotalDist => $ges_entf,
			      TotalDistString => $ges_entf_s,
			      Direction => $raw_direction,
			      DirectionString => $richtung,
			      Angle => $winkel,
			      Strname => $strname,
			      ($with_comments && $comments_net ?
			       (Comment => $etappe_comment) : ()
			      ),
			      Coord => join(",", @{$r->path->[$route_inx->[0]]}),
			     };
	}
	$ges_entf += $next_entf;
	$ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
	my $entf_s = sprintf "nach %.2f km", $next_entf/1000;
	push @out_route, {
			  Dist => $next_entf,
			  DistString => $entf_s,
			  TotalDist => $ges_entf,
			  TotalDistString => $ges_entf_s,
			  DirectionString => "angekommen!",
			  Strname => $zielname,
			  Coord => join(",", @{$r->path->[-1]}),
			 };
    }

    if ($output_as eq 'perldump') {
	require Data::Dumper;
	print $q->header(-type => "text/plain",
			 @no_cache,
			 etag(),
			);
	print Data::Dumper->new
	    ([{
	       Route => \@out_route,
	       Len   => $r->len, # in meters
	       Trafficlights => $r->trafficlights,
	       Speed => \%speed_map,
	       Power => \%power_map,
	       ($sess ? (Session => $sess->{_session_id}) : ()),
	       Path => [ map { join ",", @$_ } @{ $r->path }],
	      }
	     ], ['route'])->Dump;
	return;
    }

    %persistent = $q->cookie(-name => $cookiename);
    foreach my $key (@pref_keys) {
	$persistent{"pref_$key"} = $q->param("pref_$key");
    }
    my $cookie = $q->cookie
	(-name => $cookiename,
	 -value => { %persistent },
	 -expires => '+1y',
	);

    print $q->header(@weak_cache,
		     -cookie => $cookie,
		     etag());
    my %header_args;
##XXX die Idee hierbei war: table.background ist bei Netscape der Hintergrund
## ohne cellspacing, während es beim IE mit cellspacing ist. Also für
## jedes td bgcolor setzen. Oder besser mit Stylesheets arbeiten. Nur wie,
## wenn man nicht für jedes td die Klasse setzen will?
#     if ($can_css) {
# 	$header_args{'-style'} = <<EOF;
# <!--
# $std_css
# td { background:#ffcc66; }
# -->
# EOF
#     }
    $header_args{-printmode} = 1 if $printmode;
    header(%header_args);

    if (!@out_route) {
	print "Keine Route gefunden.\n";
    } else {
	if ($custom_net && !$printmode) {
	    my(@path) = $r->path_list;
	    for(my $i = 0; $i < $#path; $i++) {
		my($x1, $y1) = @{$path[$i]};
		my($x2, $y2) = @{$path[$i+1]};
		if ($custom_net->{Net}{"$x1,$y1"}{"$x2,$y2"}) {
		    if (!$custom) {
			my $hidden = "";
			foreach my $key ($q->param) {
			    $hidden .= $q->hidden(-name => $key,
						  -default => [$q->param($key)]);
			}
			$hidden .= $q->hidden(-name => 'custom',
					      -default => 'temp-blocking');
			print <<EOF;
<center><form name="Ausweichroute" action="@{[ $q->self_url ]}">
@{[ join("<br>\n", map { $_->{text} } map { @$_ } values %current_temp_blocking) ]}
$hidden
<br><input type=submit value="Ausweichroute suchen"><hr>
</form></center><p>
EOF
                    }
		    last;
		}
	    }
	}
	if ($custom) {
	    print "<center>Mögliche Ausweichroute</center>\n";
	}

	print "<center>" unless $printmode;
	print "<table bgcolor=\"#ffcc66\"";
	if ($printmode) {
	    print " width=$printwidth";
	}
	print "><tr><td>${fontstr}Route von <b>" .
	    ($use_coord_link
	     ? coord_link($startname, $startcoord)
	     : stadtplan_link($startname,
			      $q->param('startplz')||"",
			      $q->param('startisort')?1:0,
			      (defined $starthnr && $starthnr ne '' ? $starthnr : undef),
			     )
	    )
		. "</b> ";
	if (defined $vianame && $vianame ne '') {
	    print "&uuml;ber <b>" .
		($use_coord_link
		 ? coord_link($vianame, $viacoord)
		 : stadtplan_link($vianame,
				  $q->param('viaplz')||"",
				  $q->param('viaisort')?1:0,
				  (defined $viahnr && $viahnr ne '' ? $viahnr : undef),
				 )
		)
		    . "</b> ";
	}
	print "bis <b>" .
	    ($use_coord_link
	     ? coord_link($zielname, $zielcoord)
	     : stadtplan_link($zielname,
			      $q->param('zielplz')||"",
			      $q->param('zielisort')?1:0,
			      (defined $zielhnr && $zielhnr ne '' ? $zielhnr : undef),
			     )
	    )
		. "</b>$fontend</td></tr></table><br>\n";
	print "<table";
	if ($printmode) {
	    print " width=$printwidth";
	}
	print ">\n";
	printf "<tr><td>${fontstr}L&auml;nge:$fontend</td><td>${fontstr}%.2f km$fontend</td>\n", $r->len/1000;
	print
	  "<tr><td>${fontstr}Fahrzeit:$fontend</td>";

	{
	    my $i = 0;
	    for my $speed (sort { $a <=> $b } keys %speed_map) {
		my $def = $speed_map{$speed};
		my $bold = $def->{Pref};
		my $time = $def->{Time};
		print "<td>$fontstr" . make_time($time)
		    . "h (" . ($bold ? "<b>" : "") . "bei $speed km/h" . ($bold ? "</b>" : "") . ")";
		print "," if $speed != 25;
		print "$fontend</td>";
		if ($i == 1) {
		    print "</tr><tr><td></td>";
		}
		$i++;
	    }
	}
	print "<tr>\n";
	print "$fontend</td></tr>";
	if (%power_map) {
	    print "<tr><td></td>";
	    my $is_first = 1;
	    for my $power (sort { $a <=> $b } keys %power_map) {
		if (!$is_first) {
		    print ",";
		} else {
		    $is_first = 0;
		}
		print "<td>", $fontstr,  make_time($power_map{$power}->{Time}/3600) . "h (bei $power W)", $fontend, "</td>"
	    }
	    print "</tr>\n";
	}
	print "</table>\n";
	if (defined $r->trafficlights) {
	    my $nr = $r->trafficlights;
	    print $nr . " Ampel" . ($nr == 1 ? "" : "n") .
		" auf der Strecke.<br>\n";
	}
	print "</center>\n" unless $printmode;
	print "<hr>";

	my $line_fmt;
	if (!$bi->{'can_table'}) {
	    $with_comments = 0;
	    if ($bi->{'mobile_device'}) {
		$line_fmt = "%s %s %s (ges.:%s)\n";
	    } else {
		$line_fmt = "%-13s %-24s %-31s %-8s\n";
	    }
	    print "<pre>";
	} else {
	    # Ist width=... bei Netscape4 buggy? Das nachfolgende Attribut
	    # ignoriert font-family.
	    #   width=\"90%\"
	    print "<center>" unless $printmode;
	    print "<table class='routelist' ";
	    if ($printmode) {
		print ' style="border-style:solid; border-width:1px"';
		print " border=1";
		print " width=$printwidth";
	    } else {
		print " align=center";
		if (1 || !$bi->{'can_css'}) { # XXX siehe Kommentar oben (css...)
#		    print ' XXXbgcolor="#ffcc66" style="background-color:#ffcc66; border-style:solid; border:white; border-width:1px;" ';
		    print ' bgcolor="#ffcc66" ';
		}
	    }
	    print "><tr><th>${fontstr}Etappe$fontend</th><th>${fontstr}Richtung$fontend</th><th>${fontstr}Stra&szlig;e$fontend</th><th>${fontstr}Gesamt$fontend</th>";
	    if ($with_comments) {
		print "<th>${fontstr}Bemerkungen$fontend</th>";
	    }
	    print "</tr>\n";
	}

  	my $odd = 0;
	for my $etappe (@out_route) {
	    my($entf, $richtung, $strname, $ges_entf_s,
	       $etappe_comment) =
		   @{$etappe}{qw(DistString DirectionString Strname TotalDistString Comment)};
	    if (!$bi->{'can_table'}) {
		printf $line_fmt,
		  $entf, $richtung, string_kuerzen($strname, 31), $ges_entf_s;
	    } else {
		print "<tr class=" . ($odd ? "odd" : "even") . "><td nowrap>$fontstr$entf$fontend</td><td>$fontstr$richtung$fontend</td><td>$fontstr$strname$fontend</td><td nowrap>$fontstr$ges_entf_s$fontend</td>";
		$odd = 1-$odd;
		if ($with_comments && $comments_net) {
		    print "<td>$fontstr$etappe_comment$fontend</td>";
		}
		print "</tr>\n";
	    }
	}

	if ($bi->{'can_table'}) {
	    if (!$bi->{'text_browser'} && !$printmode) {
		my $qq = new CGI $q->query_string;
		$qq->param('output_as', "print");
		print
		    "<tr bgcolor=white><td></td><td></td><td></td>";
		if ($with_comments && $comments_net) {
		    print "<td></td>";
		}
		print "<td align=center bgcolor=white>",
		    "<a title=Druckvorlage target=printwindow href=\"$bbbike_script?" . $qq->query_string . "\">" .
		    "<img src=\"$bbbike_images/printer.gif\" " .
		    "width=16 height=16 border=0 alt=Druckvorlage></a>";
		if ($can_palmdoc) {
		    my $qq2 = new CGI $q->query_string;
		    $qq2->param('output_as', "palmdoc");
		    print "&nbsp;"x10;
		    my $href = $bbbike_script;
		    if ($ENV{SERVER_SOFTWARE} !~ /Roxen/) {
			# with Roxen there are mysterious overflow redirects...
			$href .= "/route.pdb";
		    }
		    print "<a href=\"$href?" . $qq2->query_string . "\">PalmDoc</a>";
		}
		print "</td></tr>";
	    }

	    print "</table>\n";
	    print "</center>\n" unless $printmode;
	}

	if ($printmode) {
	    print
	      "<hr><br>", $fontstr,
	      "BBBike by Slaven Rezic: ",
	      "<a href=\"$bbbike_url\">$bbbike_url</a><br>\n",
	      "<script type=\"text/javascript\"><!--\nprint();\n",
              "// --></script>\n";
	    goto END_OF_HTML;
	}

	if (!$bi->{'mobile_device'}) {
	    my $string_rep = $r->as_cgi_string;
	    my $kfm_bug = ($q->user_agent =~ m|^Konqueror/1.0|i);
	    if ($bi->{'can_javascript'}) {
		print <<EOF;
<script type="text/javascript"><!--
function show_map() {
    // show extra window for PDF && Netscape --- the .pdf is not embedded
    var frm = document.forms.showmap;
    if (frm && frm.imagetype.options[frm.imagetype.options.selectedIndex].value.indexOf('pdf') == 0 && !(navigator && navigator.appName && navigator.appName == "MSIE"))
	return true;
    var geom = "640x480";
    for (var i=0; i < document.showmap.geometry.length; i++) {
	if (document.showmap.geometry[i].checked) {
	    geom = document.showmap.geometry[i].value;
	    break;
	}
    }
    var addwindowparam = "";
    if (frm && (frm.imagetype.options[frm.imagetype.options.selectedIndex].value == 'ascii' || frm.imagetype.options[frm.imagetype.options.selectedIndex].value == 'mapserver'))
	addwindowparam += ",scrollbars";
    var x_y = geom.split("x");
// XXX height/width an aktuelle Werte anpassen
// XXX bei innerHeight/Width wird bei Netscape4 leider java gestartet?! (check!)
    var x = Math.floor(x_y[0])+15;
    var y = Math.floor(x_y[1])+15;
    // Menubar immer anzeigen ... damit Speichern und Drucken möglich ist
    y += 27;
    var menubar = "yes";

    var geometry_string = "";
    if (frm && frm.imagetype.options[frm.imagetype.options.selectedIndex].value != 'mapserver') {
        geometry_string = ",height=" + y + ",width=" + x;
    }
    var w = window.open("$bbbike_html/pleasewait.html", "BBBikeGrafik",
			"locationbar=no,menubar=" + menubar +
			",screenX=20,screenY=20" + addwindowparam +
                        geometry_string);
    w.focus();
    return true;
}
// --></script>
EOF
	    }
            # XXX Mit GET statt POST gibt es zwar einen häßlichen GET-String
	    # und vielleicht können lange Routen nicht gezeichnet werden,
	    # dafür gibt es keine Cache-Probleme mehr.
	    my $post_bug = 1; # XXX für alle aktivieren
	    #$post_bug = 1 if ($kfm_bug); # XXX war mal nur für kfm
	    print "<hr><form name=showmap method=" .
		($post_bug ? "get" : "post");

	    my(%c) = %persistent;

	    my $default_imagetype = (defined $c{"imagetype"} ? $c{"imagetype"} : "png");
	    if (($default_imagetype eq 'jpeg' && $cannot_jpeg) ||
		($default_imagetype =~ /^pdf/ && $cannot_pdf) ||
		($default_imagetype =~ /^svg$/ && $cannot_svg)) {
		$default_imagetype = "";
	    }
	    my $default_print = (defined $c{"outputtarget"} && $c{"outputtarget"} eq 'print' ? 1 : 0);
	    my $default_geometry = (defined $c{"geometry"} ? $c{"geometry"} : "640x480");
	    my $default_draw = [];
	    for (0..99) {
		if (defined $c{"draw$_"}) {
		    push @$default_draw, $c{"draw$_"};
		} else {
		    last;
		}
	    }
	    if (!@$default_draw) {
		$default_draw = ["str", "title"];
	    }
	    my %default_draw = map { ($_ => 1) } @$default_draw;

	    my $imagetype_checked = sub { my $val = shift;
					  'value="' . $val . '" ' .
					  ($default_imagetype eq $val ? "selected" : "")
				      };
	    my $geometry_checked = sub { my $val = shift;
					 'value="' . $val . '" ' .
					 ($default_geometry eq $val ? "checked" : "")
				      };


#XXX bei FCGI Grafik mit .cgi statt .fcgi zeichnen
# Dafür gibt es zwei Gründe:
# 1) wird (glaube ich) das Skript für andere Zugriffe blockiert, wenn
#    gerade die Bilderzeugung läuft, und das ist mittlerweile der einzige
#    zeitintensive Prozess
# 2) Gibt es einen Bug entweder in mod_fcgi oder in FCGI.pm, so dass
#    0-Bytes aus dem Stream entfernt werden. Ein GIF kann somit nicht
#    ausgegeben werden.
#
#	print " target=\"BBBikeGrafik\" action=\"$bbbike_script\"";
	    print " target=\"BBBikeGrafik\" action=\"$bbbike_script_cgi\"";
	    # scheint bei OS/2 nicht zu funktionieren
  	    if ($bi->{'user_agent_name'} =~ m;(Mozilla|MSIE);i &&
		$bi->{'user_agent_version'} =~ m;^[4-9]; &&
		$bi->{'user_agent_os'} !~ m|OS/2|) {
  		print " onsubmit='return show_map();'";
  	    }
	    print ">\n";
	    print "<input type=submit name=interactive value=\"Grafik zeichnen\"> <font size=-1>(neues Fenster wird ge&ouml;ffnet)</font>";
	    print " <input type=checkbox name=outputtarget value='print' " . ($default_print?"checked":"") . "> f&uuml;r Druck optimieren";
	    print "&nbsp;&nbsp; <span class=nobr>Ausgabe als: <select name=imagetype>\n";
	    print " <option " . $imagetype_checked->("png") . ">PNG\n" if $graphic_format eq 'png';
	    print " <option " . $imagetype_checked->("gif") . ">GIF\n" if $graphic_format eq 'gif' || $can_gif;
	    print " <option " . $imagetype_checked->("jpeg") . ">JPEG\n" unless $cannot_jpeg;
	    print " <option " . $imagetype_checked->("wbmp") . ">WBMP\n" if $can_wbmp;
	    print " <option " . $imagetype_checked->("pdf-auto") . ">PDF\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("pdf") . ">PDF (Längsformat)\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("pdf-landscape") . ">PDF (Querformat)\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("svg") . ">SVG\n" unless $cannot_svg;
	    print " <option " . $imagetype_checked->("mapserver") . ">MapServer\n" if $can_mapserver;
	    print " </select></span>\n";
	    print "<br>\n";

	    if ($sess) {
		$sess->{routestringrep} = $string_rep;
		print "<input type=hidden name=coordssession value=\"$sess->{_session_id}\">";
		untie %$sess;
 	    } else {
		print "<input type=hidden name=coords value=\"$string_rep\">";
	    }

	    print "<input type=hidden name=startname value=\"" .
		($kfm_bug ? CGI::escape($startname) : $startname) . "\">";
	    print "<input type=hidden name=zielname value=\"" .
		($kfm_bug ? CGI::escape($zielname) : $zielname) . "\">";
	    if (@weather_res) {
		eval {
		    local $SIG{'__DIE__'};
		    require Met::Wind;
		    print "<input type=hidden name=windrichtung value=\"" .
			$weather_res[4] . "\">";
		    print "<input type=hidden name=windstaerke value=\"" .
		      Met::Wind::wind_velocity([$weather_res[5], 'm/s'],
					       'beaufort')
			  . "\">";
		};
	    }

	    print <<EOF;
<script type="text/javascript"><!--
function all_checked() {
    var all_checked_flag = false;
    var elems = document.forms["showmap"].elements;
    for (var e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw" &&
	    elems[e].value == "all" &&
	    elems[e].checked) {
	    all_checked_flag = true;
	    break;
	}
    }
    for (var e = 0; e < elems.length; e++) {
	if (elems[e].name == "draw") {
	    if (all_checked_flag) {
		elems[e].checked = true;
	    } else {
		elems[e].checked = (elems[e].value == "str" ||
				    elems[e].value == "title");
	    }
	}
    }
}
// --></script>
EOF

	    print "<table><tr valign=top><td>$fontstr<b>Bildgr&ouml;&szlig;e:</b>$fontend<br><font size=-1>(nicht für PDF)</font></td>\n";
	    foreach my $geom ("400x300", "640x480", "800x600", "1024x768") {
		print
		    "<td><input type=radio name=geometry value=\"$geom\"",
		    ($geom eq $default_geometry ? " checked" : ""),
		    ">$fontstr $geom  $fontend</td>\n";
	    }
	    print "<tr><td>$fontstr<b>Details:</b>$fontend</td>";
	    my @draw_details =
		(['Stra&szlig;en',  'str',      $default_draw{"str"}],
		 ['S-Bahn',         'sbahn',    $default_draw{"sbahn"}],
		 ['U-Bahn',         'ubahn',    $default_draw{"ubahn"}],
		 ['Gew&auml;sser',  'wasser',   $default_draw{"wasser"}],
		 ['Fl&auml;chen',   'flaechen', $default_draw{"flaechen"}],
		 "-",
		 ['Ampeln',         'ampel',    $default_draw{"ampel"}],
		 );
	    if ($multiorte) {
		push @draw_details, ['Orte', 'ort', $default_draw{"ort"}];
	    }
	    push
		@draw_details,
		['Routendetails',  'strname',$default_draw{"strname"}],
		['Titel',          'title',  $default_draw{"title"}],
		['Alles',          'all',    $default_draw{"all"}];
	    foreach my $draw (@draw_details) {
		my $text;
		if ($draw eq '-') {
		    print "</tr>\n<tr><td></td>";
		    next;
		}
		if ($draw->[0] eq 'S-Bahn' && !$bi->{'text_browser'}) {
		    $text = "<img src=\"$bbbike_images/sbahn.gif\" width=15 height=15 border=0 alt=S>-Bahn";
		} elsif ($draw->[0] eq 'U-Bahn' && !$bi->{'text_browser'}) {
		    $text = "<img src=\"$bbbike_images/ubahn.gif\" width=15 height=15 border=0 alt=U>-Bahn";
		} else {
		    $text = $draw->[0];
		}
		print
		    "<td><span class=nobr><input type=checkbox name=draw value=$draw->[1]",
		    ($draw->[2] ? " checked" : ""),
		    ($draw->[1] eq 'all' ? " onclick=\"all_checked()\"" : ""),
		    ">$fontstr $text $fontend</span></td>\n";
	    }
	    print "</tr>\n";
	    if ($lstr || $multiorte) {
		print "<input type=hidden name=draw value=umland>\n";
	    }
	    print "</table>\n";
	    print "<p>";
	    print <<EOF;
<font size=-1>Die Dateigr&ouml;&szlig;e der Grafik beträgt je nach
Bildgr&ouml;&szlig;e, Bildformat und Detailreichtum 15 bis 50 kB. PDFs sind 100 bis 400 kB groß.
EOF
            print window_open("$bbbike_html/legende.html", "BBBikeLegende",
			      "dependent,height=392,resizable" .
			      "screenX=400,screenY=80,scrollbars,width=440")
		. "Legende.</a></font>\n";
	}

	print "</form>\n";

	print "<hr><form name=settings action=\"" . $q->self_url . "\">\n";
	foreach my $key ($q->param) {
	    next if $key =~ /^(pref_.*)$/;
	    print $q->hidden(-name=>$key,
			     -default=>[$q->param($key)])
	}
	print "<b>Einstellungen</b>:<p>\n";
	settings_html();
	print "<input type=submit value=\"Route mit ge&auml;nderten Einstellungen\">\n";
	print "</form>\n";

	print "<hr><form action=\"$bbbike_script\">\n";
	print "<input type=hidden name=startc value=\"$zielcoord\">";
	print "<input type=hidden name=zielc value=\"$startcoord\">";
	print "<input type=hidden name=startname value=\"$zielname\">";
	print "<input type=hidden name=zielname value=\"$startname\">";
	if (defined $viacoord && $viacoord ne '') {
	    print "<input type=hidden name=viac value=\"$viacoord\">";
	    print "<input type=hidden name=vianame value=\"$vianame\">";
	}
	foreach my $param ($q->param) {
	    if ($param =~ /^pref_/) {
		print "<input type=hidden name='$param' value=\"".
		    $q->param($param) ."\">";
	    }
	}
	print "<input type=submit value=\"R&uuml;ckweg\"><br>";
	hidden_smallform();

	my $button = sub {
	    my($label, $query) = @_;
	    my $url = $bbbike_script."?".$query;
	    if ($bi->{'can_javascript'} >= 1.1) {
		print "<input type=button value=\"$label\" " .
		    "onclick=\"location.href='$url';\"> ";
	    } else {
		print "<a href=\"$url\">$label</a> ";
	    }
	};

	if ($show_start_ziel_url) {
	    my $qq = new CGI $q->query_string;
	    foreach (qw(viac vianame alternative)) {
		$qq->delete($_);
	    }
	    foreach ($qq->param) {
		if (/^pref_/) {
		    $qq->delete($_);
		}
	    }

	    print " Neue Anfrage: ";

	    my $qqq = new CGI $qq->query_string;
	    foreach ($qqq->param) {
		if (/^ziel/) {
		    $qqq->delete($_);
		}
	    }
	    $button->("Start beibehalten", $qqq->query_string);

	    $qqq = new CGI $qq->query_string;
	    foreach ($qqq->param) {
		if (/^start/) {
		    $qqq->delete($_);
		}
	    }
	    $button->("Ziel beibehalten", $qqq->query_string);

	    $button->("Start und Ziel neu eingeben", "begin=1");

	    $qqq = new CGI $qq->query_string;
	    foreach (qw(c name plz)) {
		$qqq->param("start$_", $qqq->param("ziel$_"));
		$qqq->delete("ziel$_");
	    }
	    $button->("Ziel als Start", $qqq->query_string);

	    print "<br>";
	}

	print "</form>\n";

	print "<hr>\n";

	# Andere Alternativen ausgeben
	if (@r > 1) {
	    my $i;
	    print "Weitere Alternativen:<br><ul>\n";
	    for($i = 0; $i <= $#r; $i++) {
		print "<li>";
		my $len = sprintf "%.3f km", $r[$i]->len/1000;
		if ((defined $alternative  && $i == $alternative) ||
		    (!defined $alternative && $i == 0)) {
		    print "diese Strecke ($len)";
		} else {
		    my $qq = new CGI $q->query_string;
		    $qq->param('startc',    $startcoord);
		    $qq->param('startname', $startname);
		    $qq->param('viac',      $viacoord);
		    $qq->param('vianame',   $vianame);
		    $qq->param('zielc',     $zielcoord);
		    $qq->param('zielname',  $zielname);
		    $qq->param('alternative', $i);
		    print "<a href=\"$bbbike_script?" . $qq->query_string . "\">";
		    print
		      ($i == 0 ? "beste Alternative" : "Alternative $i");
		    print " ($len)</a>";
		}
		print "\n";
	    }
	    print "</ul><hr>\n";
	}

    }

    if (@weather_res) {
	my(@res) = @weather_res;
	print "<center><table border=0 bgcolor=\"#d0d0d0\">\n";
	print "<tr><td colspan=2>${fontstr}<b>" . link_to_met() . "Aktuelle Wetterdaten ($res[0], $res[1])</a></b>$fontend</td>";
	print "<tr><td>${fontstr}Temperatur:$fontend</td><td>${fontstr}$res[2] °C$fontend</td></tr>\n";
	print "<tr><td>${fontstr}Windrichtung:$fontend</td><td>${fontstr}$res[4]$fontend&nbsp;</td></tr>\n";
	my($kmh, $windtext);
	eval { local $SIG{'__DIE__'};
	       require Met::Wind;
	       $kmh      = Met::Wind::wind_velocity([$res[5], 'm/s'],
						    'km/h');
	       if ($kmh >= 5) {
		   $kmh = sprintf("%d",$kmh); # keine Pseudogenauigkeit, bitte
	       }
	       $windtext = Met::Wind::wind_velocity([$res[5], 'm/s'],
						    'text_de');
	   };
	print "<tr><td>${fontstr}Windgeschwindigkeit:$fontend</td><td>${fontstr}";
	if (defined $kmh) {
	    print "$kmh km/h";
	} else {
	    print "$res[5] m/s";
	}
	if (defined $windtext) {
	    print " ($windtext)";
	}
	print "$fontend</td></tr>\n";
	print "</table></center><hr>";
    }

    footer();

  END_OF_HTML:
    print $q->end_html;
}

sub user_agent_info {
    $bi = new BrowserInfo $q;
#    $bi->emulate("wap"); # XXX put your favourite emulation
    $fontstr = ($bi->{'can_css'} ? '' : "<font face=\"$font\">");
    $fontend = ($bi->{'can_css'} ? '' : "</font>");
    $bi->{'hfill'} = ($bi->is_browser_version("Mozilla", 5, 5.0999) ?
		      "class='hfill'" : "");
}

sub show_user_agent_info {
    print $bi->show_info('complete');
    print $bi->show_server_info;
}

sub coord_link {
    my($strname, $coords) = @_;
    $coords = CGI::escape($coords);
    "<a target=\"_blank\" href=\"$mapserver_address_url?coords=$coords\">$strname</a>";
}

sub stadtplan_link {
    my($strname, $plz, $is_ort, $hnr) = @_;
    return $strname if $is_ort;
    my $stadtplan_url = "http://www.berlin.de/stadtplan/explorer";
    my @aref;
    foreach my $s (split(m|/|, $strname)) {
	# Text in Klammern entfernen:
	(my $str_plain = $s) =~ s/\s+\(.*\)$//;
	$str_plain = CGI::escape($str_plain);
	push @aref,
	    "<a target=\"_blank\" href=\"$stadtplan_url?adr_street=$str_plain".
		(defined $plz ? "&amp;adr_zip=$plz" : "") .
		    (defined $hnr ? "&amp;adr_house=$hnr" : "") .
			"\">$s</a>";
    }
    join("/", @aref);
}

sub string_kuerzen {
    my($strname, $len) = @_;
    if (length($strname) <= $len) {
	$strname;
    } else {
	substr($strname, 0, $len-3)."...";
    }
}

sub overview_map {
    if (!defined $overview_map) {
	require BBBikeDraw;
	$overview_map = BBBikeDraw->new
	    (ImageType => 'dummy',
	     Geometry => ($xgridwidth*$xgridnr) . "x" . ($ygridwidth*$ygridnr),
	    );
	$overview_map->set_dimension($x0, $x0 + $xm*$xgridnr*$xgridwidth,
				     $y0 - $ym*$ygridnr*$ygridwidth, $y0,
				    );
	$overview_map->create_transpose;
    }
    $overview_map;
}

sub start_mapserver {
    require BBBikeMapserver;
    my $ms = BBBikeMapserver->new_from_cgi($q, -tmpdir => $tmp_dir);
    $ms->read_config("$0.config");
    $ms->{Coords} = ["8593,12243"]; # Brandenburger Tor
    $ms->start_mapserver(-route => 0,
			 -bbbikeurl => $bbbike_url,
			 -bbbikemail => $BBBike::EMAIL,
			);
    return;
}

sub draw_route {
    my(%args) = @_;
    my @cache = (exists $args{-cache} ? @{ $args{-cache} } : @no_cache);

    if (!defined $q->param("scope")) {
	$q->param("scope", ($use_umland_jwd ? 'wideregion' :
			    ($use_umland    ? 'region'     :
			     'city')));
    }

    my $draw;
    my $header_written;

    if (defined $q->param('coordssession') &&
	(my $sess = tie_session($q->param('coordssession')))) {
	$q->param(coords => $sess->{routestringrep});
    }

    my $cookie;
    %persistent = $q->cookie(-name => $cookiename);
    if (defined $q->param("interactive")) {
	foreach my $key (qw/outputtarget imagetype geometry/) {
	    $persistent{$key} = $q->param($key);
	}
	# draw is an array;
	my $i = 0;
	foreach ($q->param("draw")) {
	    $persistent{"draw$i"} = $_;
	    $i++;
	}
	$cookie = $q->cookie
	    (-name => $cookiename,
	     -value => { %persistent },
	     -expires => '+1y',
	    );
    }

    if (defined $q->param('imagetype') &&
	$q->param('imagetype') =~ /^mapserver/) {
	require BBBikeMapserver;
	my $ms = BBBikeMapserver->new_from_cgi($q, -tmpdir => $tmp_dir);
	$ms->read_config("$0.config");
	my $layers;
	if (grep { $_ eq 'all' } $q->param("draw")) {
	    $layers = [ $ms->all_layers ];
	} else {
	    $layers = [ "route",
			map {
			    my $out = +{
					str => "str", # always drawn
					ubahn => "bahn",
					sbahn => "bahn",
					wasser => "gewaesser",
					flaechen => "flaechen",
					ampel => "ampeln",
				       }->{$_};
			    if (!defined $out) {
				();
			    } else {
				$out;
			    }
			} $q->param('draw')
		      ];
	}
	$ms->start_mapserver
	    (-bbbikeurl => $bbbike_url,
	     -bbbikemail => $BBBike::EMAIL,
	     -scope => "all,city", # so switching between reference maps is possible
	     -externshape => 1,
	     -layers => $layers,
	     -cookie => $cookie,
	    );
	return;
    }

    my @header_args = @cache;
    if ($cookie) { push @header_args, "-cookie", $cookie }
    push @header_args, etag();

    # write content header for pdf as early as possible, because
    # output is already written before calling flush
    if (defined $q->param('imagetype') &&
	$q->param('imagetype') =~ /^pdf/) {
	print $q->header(-type => "application/pdf",
			 @header_args,
			);
	++$header_written;
	if ($q->param('imagetype') =~ /^pdf-(.*)/) {
	    $q->param('geometry', $1);
	    $q->param('imagetype', 'pdf');
	}
    }

    eval {
	local $SIG{'__DIE__'};
	require BBBikeDraw;
	BBBikeDraw->VERSION(2.26);
	$draw = new_from_cgi BBBikeDraw $q,
	    MakeNet => \&make_netz;
	die $@ if !$draw;
    };
    if ($@) {
	my $err = $@;
	print
	    $q->header(-type => 'text/html',
		       @no_cache,
		       etag(),
		      ),
	    "<body>Fehler in BBBikeDraw: $err</body>";
	exit 0;
    }

    unless ($header_written) {
	print $q->header(-type => $draw->mimetype,
			 @header_args,
			);
    }

    eval { $draw->pre_draw }; return if $@;
    $draw->draw_wind; # see comment in BBBikeDraw
    $draw->draw_map;
    $draw->draw_route;
    if ($q->param('imagetype') eq 'pdf') {
	require Route::PDF;
	require Route;
	my(@c) = map { [split /,/ ] } split /!/, $q->param("coords");
	Route::PDF::add_page_to_bbbikedraw
		(-bbbikedraw => $draw,
		 -net => make_netz(),
		 -route => Route->new_from_realcoords(\@c),
		);
    }
    $draw->flush;
}

sub draw_map {
    my(%args) = @_;
    my($part, @dim);
    my($x, $y);
    if (exists $args{'-x'} and exists $args{'-y'}) {
	($x, $y) = ($args{'-x'}, $args{'-y'});
	$part = sprintf("%02d-%02d", $x, $y);
	@dim  = xy_to_dim($x, $y);
    } else {
	die "No x/y set";
    }

    print $q->header(@weak_cache, etag()) unless $args{-quiet};

    if (!@dim) { die "No dim set" }

    my($img_url, $img_file);
    my $map_file = "$mapdir_fs/berlin_map_$part.map";

    my $create = 1;
    my $ext;

    my $set_img_name = sub {
	$img_file = "$mapdir_fs/berlin_map_$part.$ext";
	$img_url  = "$mapdir_url/berlin_map_$part.$ext";
    };

    if (!$args{'-force'}) {
	foreach (qw(png gif)) {
	    $ext = $_;
#XXX	    next if $ext eq 'png' and !$bi->{'can_png'};
	    $set_img_name->();
	    if (-s $img_file && -s $map_file) {
		my(@img_file_stat)   = stat($img_file);
		if (defined $img_file_stat[9]) {
		    my(@map_file_stat)   = stat($img_file);
		    if (defined $map_file_stat[9]) {
			my(@bbbike_cgi_stat) = stat($0);
			my(@strassen_stat)   = stat($str->{File});
			my $to_create_time =
			  min($img_file_stat[9], $map_file_stat[9]);
			my $check_time =
			  ($check_map_time == 0 ? 0 :
			   ($check_map_time == 1 ? $strassen_stat[9] :
			    max($bbbike_cgi_stat[9], $strassen_stat[9])
			   ));
			$create = ($to_create_time < $check_time);
			if ($debug) {
			    warn __LINE__ . ": time_exist=$to_create_time, " .
			      "check_time=$check_time, create=$create\n";
			}
		    } elsif ($debug) {
			warn __LINE__ . ": Can't stat $map_file: $!\n";
		    }
		} elsif ($debug) {
		    warn __LINE__ . ": Can't stat $img_file: $!\n";
		}
		last if (!$create);
	    } elsif ($debug) {
		warn __LINE__ .  ": $img_file or $img_url empty\n";
	    }
	}
    }

    if ($create) {
	$ext = $graphic_format;
	$set_img_name->();
    }

    if ($create || !-r $img_file || -z $img_file || !-r $map_file) {
	eval {
	    local $SIG{'__DIE__'};
	    require BBBikeDraw;
	    open(IMG, ">$img_file") or confess "Fehler: Die Karte $img_file konnte nicht erstellt werden.<br>\n";
	    chmod 0644, $img_file;
	    open(MAP, ">$map_file") or confess "Fehler: Die Map $map_file konnte nicht erstellt werden.<br>\n";
	    chmod 0644, $map_file;
	    $q->param('geometry', $detailwidth."x".$detailheight);
	    $q->param('draw', 'str', 'ubahn', 'sbahn', 'wasser');
	    $q->param('drawwidth', 1);
	    # XXX Argument sollte übergeben werden (wird sowieso noch nicht
	    # verwendet, bis auf Überprüfung des boolschen Wertes)
	    $q->param('strlabel', 'str:HH,H');#XXX if $args{-strlabel};
	    if (!$q->param('imagetype')) {
		if (!$can_gif) {
		    $q->param('imagetype', 'png');
		} else {
		    $q->param('imagetype', 'gif');
		}
	    }
	    $q->param('module', $args{-module}) if $args{-module};
	    my $draw = new_from_cgi BBBikeDraw($q, Fh => \*IMG);
	    $draw->set_dimension(@dim);
	    $draw->create_transpose();
	    print "Create $img_file...\n" if $args{-logging};
	    $draw->draw_map();
	    if ($create_imagemap) {
		$draw->make_imagemap(\*MAP);
	    }
	    $draw->flush();
	    $q->delete('draw');
	    $q->delete('geometry');
	    close MAP;
	    close IMG;
	};
	die __LINE__ . ": Warnung: $@<br>\n" if $@;
    }

    unless ($args{-quiet}) {

 	my $type = $q->param('type') || '';

	my $script = <<EOF;
function jump_to_map() {
    window.location.hash = "mapbegin";
}
EOF

        # XXX jump_to_map macht Probleme mit Opera und ist nervig mit anderen
        # Browsern.
	header(#-script => $script,
	       #-onLoad => 'jump_to_map()'
	      );
	print "<b><a name='mapbegin'>" .
	      ucfirst($type) . "-Kreuzung</a></b> ausw&auml;hlen:<br>\n";
	print "<form action=\"$bbbike_script\">\n";

	foreach ($q->param) {
	    unless ($_ eq 'type') {
		print "<input type=hidden name=$_ value=\""
		  . $q->param($_) . "\">\n";
	    }
	}
	print "<input type=hidden name=detailmapx value=\"$x\">\n";
	print "<input type=hidden name=detailmapy value=\"$y\">\n";
	print "<input type=hidden name=type value=\"$type\">\n";
	print "<center><table class=\"detailmap\">";

	# obere Zeile
	if ($y > 0) {
	    print "<tr><td align=right>";
	    if ($x > 0) {
		print "<input type=submit name=movemap value=\"Nordwest\">";
	    }
	    print "</td><td align=center><input type=submit name=movemap value=\"Nord\"></td>\n";
	    if ($x < $xgridnr-1) {
		print "<td align=left><input type=submit name=movemap value=\"Nordost\"></td>";
	    }
	    print "</tr>\n";
	}

	# mittlere Zeile
	print "<tr><td align=right>";
	if ($x > 0) {
	    print "<input type=submit name=movemap value=\"West\">";
 	}
	print
	  "</td><td><input type=image title='' name=detailmap ",
	  "src=\"$img_url\" alt=\"\" border=0 ",
	  ($use_imagemap ? "usemap=\"#map\" " : ""),
	  "align=middle width=$detailwidth height=$detailheight>",
	  "</td>\n";
	if ($x < $xgridnr-1) {
	    print "<td align=left><input type=submit name=movemap value=\"Ost\"></td>";
 	}
	print "</tr>\n";

	# untere Zeile
	if ($y < $ygridnr-1) {
	    print "<tr><td align=right>";
	    if ($x > 0) {
		print "<input type=submit name=movemap value=\"Südwest\">";
	    }
	    print "</td><td align=center><input type=submit name=movemap value=\"Süd\"></td>";
	    if ($x < $xgridnr-1) {
		print "<td align=left><input type=submit name=movemap value=\"Südost\"></td>";
	    }
	    print "</tr>\n";
 	}
	print "</table>";
	print "<input type=submit name=Dummy value=\"&lt;&lt; Zur&uuml;ck\">";
	print "</center>";
	print <<EOF;
<script type="text/javascript">
<!--
function s(text) {
  self.status=text;
  return true;
}
// -->
</script>
EOF
	if ($use_imagemap) {
	    open(MAP, $map_file)
	      or confess "Fehler: Die Map $map_file konnte nicht geladen werden.\n<br>";
	    while(<MAP>) {
		print $_;
	    }
	    close MAP;
	}
	footer();
	print "</form>\n";
	print $q->end_html;
    }
}

# Stellt für den x/y-Index der berlin_small-Karte die zugehörige
# Dimension für BBBikeDraw fest.
sub xy_to_dim {
    my($x, $y) = @_;
    ($x*$xgridwidth*$xm+$x0, ($x+1)*$xgridwidth*$xm+$x0,
     $y0-($y+1)*$ygridwidth*$ym, $y0-$y*$ygridwidth*$ym,
    );
}

# Für einen Punkt aus der Detailmap wird die am nächsten liegende
# Kreuzung festgestellt. Zurückgegeben wird die Koordinate der
# Kreuzung "(x,y)".
sub detailmap_to_coord {
    my($index_x, $index_y, $map_x, $map_y) = @_;
    my($x, $y) =
      ($index_x*$xgridwidth*$xm+$x0 + ($map_x*$xm*$xgridwidth)/$detailwidth,
       $y0-$index_y*$ygridwidth*$ym - ($map_y*$ym*$ygridwidth)/$detailheight,
      );
    new_kreuzungen(); # XXX needed for munich, here too?
    get_nearest_crossing_coords($x,$y);
}

sub all_crossings {
    if (scalar keys %$crossings == 0) {
	$crossings = $multistr->all_crossings(RetType => 'hash',
					      UseCache => 1);
    }
}

sub new_kreuzungen {
    if (!$kr) {
	all_crossings();
	$kr = new Kreuzungen(Hash => $crossings,
			     Strassen => $multistr);
	if ($lstr) {
	    my($lstr_crossings) = $lstr->all_crossings(RetType => 'hash',
						       UseCache => 1);
	    $kr->add(Hash => $lstr_crossings);
	}
	$kr->make_grid(UseCache => 1);
    }
    $kr;
}

sub new_trafficlights {
    if (!$ampeln) {
	eval {
	    my $lsa = new Strassen "ampeln";
	    $lsa->init;
	    while(1){
		my $ret = $lsa->next;
		last if !@{$ret->[1]};
		my($xy) = $ret->[1][0];
		$ampeln->{$xy}++;
	    }
	};
	warn $@ if $@;
    }
    $ampeln;
}

sub crossing_text {
    my $c = shift;
    all_crossings();
    if (exists $crossings->{$c}) {
	join("/", @{ $crossings->{$c} });
    } else {
	new_kreuzungen();
	my(@nearest) = $kr->nearest_coord($c);
	if (@nearest and exists $crossings->{$nearest[0]}) {
	    join("/", @{ $crossings->{$nearest[0]} });
	} else {
	    "???";
	}
    }
}

# Gibt den Straßennamen für type=start/via/ziel zurück --- entweder
# aus startname oder abgeleitet aus startc
sub name_from_cgi {
    my($q, $type) = @_;
    if (defined $q->param($type . "name") and
	$q->param($type . "name") ne '') {
	$q->param($type . "name");
    } elsif (defined $q->param($type . "c")) {
	crossing_text($q->param($type . "c"));
    } else {
	undef;
    }
}

sub make_time {
    my($h_dec) = @_;
    my $h = int($h_dec);
    my $m = int(($h_dec-$h)*60);
    sprintf "%d:%02d", $h, $m;
}

# falls die Koordinaten nicht exakt existieren, wird der nächste Punkt
# gesucht und gesetzt
sub fix_coords {
    my($startcoord, $viacoord, $zielcoord) = @_;
    foreach my $varref (\$startcoord, \$viacoord, \$zielcoord) {
	next if (!defined $$varref or
		 $$varref eq ''    or
		 exists $net->{Net}{$$varref});
	if (!defined $kr) {
	    new_kreuzungen();
	}
	my(@nearest) = $kr->nearest_coord($$varref);
	if (@nearest) {
	    $$varref = $nearest[0];
	}
    }
    ($startcoord, $viacoord, $zielcoord);
}

sub start_weather_proc {
    my(@stat) = stat("$tmp_dir/wettermeldung");
    if (!defined $stat[9] or $stat[9]+30*60 < time()) {
	my @weather_cmdline = (@weather_cmdline,
			       '-o', "$tmp_dir/wettermeldung");
	if ($^O eq 'MSWin32') { # XXX Austesten
	    eval q{
		require Win32::Process;
		unlink "$tmp_dir/wettermeldung";
		my $proc;
		Win32::Process::Create($proc,
				       $weather_cmdline[0],
				       @weather_cmdline,
				       0, Win32::Process::CREATE_NO_WINDOW,
				       $tmp_dir);
	    };
	} else {
	    eval {
		local $SIG{'__DIE__'};
		my $weather_pid = fork();
		if (defined $weather_pid and $weather_pid == 0) {
		    eval {
			require File::Spec;
			open STDIN, File::Spec->devnull;
			open STDOUT, '>' . File::Spec->devnull;
			open(STDERR, '>' . File::Spec->devnull);
			require POSIX;
			# Can't use `exists' (for 5.00503 compat):
			POSIX::setsid() if defined &POSIX::setsid;
		    }; warn $@ if $@;
		    unlink "$tmp_dir/wettermeldung";
		    exec @weather_cmdline;
		    exit 1;
		}
	    };
	}
    }
}

sub gather_weather_proc {
    my @res;
    my(@stat) = stat("$tmp_dir/wettermeldung");
    if (defined $stat[9] and $stat[9]+30*60 > time()) { # Aktualität checken
	if (open(W, "$tmp_dir/wettermeldung")) {
	    chomp(my $line = <W>);
	    @res = split(/\|/, $line);
	    close W;
	}
    }
    @res;
}

sub etag {
    my $lang = 'de'; # XXX
    my $rcsversion = $VERSION;
    my $browserversion = $q->user_agent;
    my $etag = "$lang-$rcsversion-$browserversion";
    $etag =~ s;[\s\[\]\(\)]+;_;g;
    $etag =~ s|[^a-z0-9-_./]||gi;
    $etag = qq{"$etag"};
    (-ETag => $etag);
}

sub header {
    my(%args) = @_;
    delete $args{-from}; # XXX
    if (!exists $args{-title}) {
	$args{-title} = "BBBike";
    }
    no strict;
    local *cgilink = ($CGI::VERSION <= 2.36
		      ? \&CGI::link
		      : \&CGI::Link);
    my $head = [];
    push @$head, $q->meta({-http_equiv => "Content-Script-Type",
			   -content => "text/javascript"});
    push @$head, "<base target='_top'>"; # Can't use -target option here
    push @$head, cgilink({-rel  => "shortcut icon",
#  			  -href => "$bbbike_images/favicon.ico",
#  			  -type => "image/ico",
			  -href => "$bbbike_images/srtbike16.gif",
			  -type => "image/gif",
			 });
    if ($bi->{'text_browser'} && !$smallform) {
	push @$head,
	    cgilink({-rel => 'Help',
		     -href => "$bbbike_script?info=1"}),
	    cgilink({-rel => 'Start',
		     -href => "$bbbike_script?begin=1"}),
	   (defined $args{-up}
	    ? cgilink({-rel => 'Up', -href => $args{-up}}) : ()),
		;
	if ($args{-contents}) {
	    push @$head, cgilink({-rel => 'Contents',
				  -href => $args{'-contents'}});
	}
    }
    delete @args{qw(-contents -up)};
    my $printmode = delete $args{-printmode};
    if ($bi->{'can_css'} && !exists $args{-style}) {
	$args{-style} = {-src => "$bbbike_html/" . ($printmode ? "bbbikeprint" : "bbbike") . ".css"};
#XXX del:
#  <<EOF;
#  $std_css
#  EOF
    }
    if (!$bi->{'can_javascript'}) {
	delete $args{-script};
	delete $args{-onload};
    }

    $args{-head} = $head if $head && @$head;

    if (!$smallform) {
	print $q->start_html
	    (%args,
	     -BGCOLOR => '#ffffff',
	     ($use_background_image && !$printmode ? (-BACKGROUND => "$bbbike_images/bg.jpg") : ()),
	     -meta=>{'keywords'=>'berlin fahrrad route bike karte suche cycling route routing',
		     'copyright'=>'(c) 1998-2003 Slaven Rezic',
		    },
	     -author => $BBBike::EMAIL,
	    );
	if ($bi->{'buggy_css'}) {
	    print "<font face=\"$font\">";
	}
	print "<h1>\n";
	if ($printmode) {
	    print "$args{-title}";
	    print "<img alt=\"\" src=\"$bbbike_images/srtbike.gif\" hspace=10>";
	} else {
	    my $use_ilayer = 0;
	    print "<ilayer left=200>" if $use_ilayer;
	    print "<a href='$bbbike_url?begin=1' title='Zurück zur Hauptseite' style='color:black;'>$args{-title}</a>";
	    print "</ilayer><ilayer left=175 top=5>" if $use_ilayer;
	    print "<a href='$bbbike_url?begin=1'><img alt=\"\" src=\"$bbbike_images/srtbike.gif\" hspace=10 border=0></a>";
	    print "</ilayer>" if $use_ilayer;
	}
	print "</h1>\n";
    } else {
	print $q->start_html;
	print "<h1>BBBike</h1>";
    }
}

sub footer { print footer_as_string() }

sub footer_as_string {
    my $s = "";
# ?begin anscheinend notwendig (Bug in Netscape3, Solaris2?)
    my $smallformstr = ($q->param('smallform')
			? '&smallform=' . $q->param('smallform')
			: '');
    $s .= "<center><table ";
    if (1 || !$bi->{'can_css'}) { # XXX siehe oben Kommentar am Anfang von "sub search_*" bzgl. css
	$s .= "bgcolor=\"#ffcc66\" ";
    }
    $s .= "cellpadding=3>\n";
    $s .= <<EOF;
<tr>
<td align=center>${fontstr}bbbike.cgi $VERSION${fontend}</td>
<td align=center>${fontstr} <a target="_top" href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike">E-Mail</a>${fontend}</td>
<td align=center>$fontstr<a target="_top" href="$bbbike_script?begin=1$smallformstr">Neue Anfrage</a>${fontend}</td>
EOF
    if ($use_miniserver) {
        $s .= <<EOF;
<td align=center>$fontstr<a target="_top" href="$bbbike_url">Kaltstart</a>${fontend}</td>
EOF
    }
    $s .= <<EOF;
<td align=center>$fontstr<a target="_top" href="$bbbike_script?info=1$smallformstr">Info &amp; Disclaimer</a>${fontend}</td>
EOF
    $s .= "<td align=center>$fontstr";
    $s .= complete_link_to_einstellungen();
    $s .= "${fontend}</td>\n";
    if ($can_mapserver) {
        $s .= "<td><a href=\"$bbbike_script?mapserver=1\">Mapserver</a></td>";
    } elsif (defined $mapserver_init_url) {
        $s .= "<td><a href=\"$mapserver_init_url\">Mapserver</a></td>";
    }
    $s .= <<EOF;
</table>
</center>
EOF
    if ($bi->{'css_buggy'}) {
	$s .= "</font>\n";
    }
    $s;
}

sub blind_image {
    my($w,$h) = @_;
    $w = 1 if !$w; $h = 1 if !$h;
    "<img src='$bbbike_images/px_1t.gif' alt='' width=$w height=$h border=0>"
}

sub complete_link_to_einstellungen {
    window_open("$bbbike_script?bikepower=1", "BikePower",
		"dependent,height=400,resizable," .
		"screenX=400,screenY=40,scrollbars,width=550") .
		  "Einstellungen</a>";
}

sub link_to_met {
    "<a href=\"http://www.met.fu-berlin.de/deutsch/Wetter/meldungen.html\">";
}

sub window_open {
    my($href, $winname, $settings) = @_;
    if ($bi->{'can_javascript'} && !$bi->{'window_open_buggy'}) {
	"<a href=\"$href\" target=\"$winname\" onclick='window.open(\"$href\", \"$winname\"" .
	  (defined $settings ? ", \"$settings\"" : "") .
	    "); return false;'>";
    } else {
	"<a href=\"$href\" target=\"$winname\">";
    }
}

sub call_bikepower {
    print $q->header(@no_cache, etag());
    eval q{
	require BikePower::HTML;
	print BikePower::HTML::code();
    };
    if ($@) {
	header();
	print
	  "<b>Sorry, BikePower ist anscheinend auf diesem System ",
	  "nicht installiert.</b><p>\n";
	footer();
    }
}

sub init_bikepower {
    my $q = shift;
    undef $bp_obj;
    eval {
	local $SIG{__DIE__};
	require BikePower;
	require BikePower::HTML;
	$bp_obj = BikePower::HTML::new_from_cookie($q);
	$bp_obj->given('P');
	init_wind();
    };
    # XXX warn __LINE__ .  ": Warnung: $@<br>\n" if $@;
    $bp_obj;
}

# XXX Doppelung mit bbbike-Code vermeiden
sub bikepwr_get_v { # Resultat in m/s
    my($wind, $power, $grade) = @_;
    $grade = 0 if !defined $grade; # $grade wird noch nicht verwendet XXX
    $bp_obj->grade($grade);
    $bp_obj->headwind($wind);
    $bp_obj->power($power);
    $bp_obj->calc();
    my $v = $bp_obj->velocity;
    $v;
}

sub choose_street_html {
    my($strasse, $plz_number, $type) = @_;
    if (!$plz) {
	require PLZ;
	PLZ->VERSION(1.26);
	$plz = new PLZ;
    }
    my $plz_re = $plz->make_plz_re($plz_number);
    my @res = $plz->look($plz_re, Noquote => 1);
    my @strres = $str->union(\@res);
    if (!@strres) {
	print "Keine Stra&szlig;en im PLZ-Gebiet $plz_number.<br>\n";
	print ucfirst($type) . ": <input type=text name=$type><br>\n";
    } else {
	print <<EOF;
<b>$strasse</b> ist nicht in der BBBike-Datenbank erfasst. Folgende
Stra&szlig;en sind im selben PLZ-Gebiet:<br>
EOF
        my @strname;
	for(my $i = 0; $i <= $#strres; $i++) {
	    push @strname, $str->get($strres[$i])->[0];
	    last if $i >= $max_plz_streets;
	}
	@strname = sort @strname;
	my $i = 0;
	my $strname;
	if ($use_select) {
	    print "<select $bi->{hfill} name=" . $type . "name>";
	}
	foreach $strname(@strname) {
	    if ($use_select) {
		print "<option value=\"$strname\">$strname\n";
	    } else {
		print "<input type=radio name=" . $type . "name";
		if ($i == 0) {
		    print " checked";
		}
		print " value=\"$strname\"> $strname<br>\n";
		if ($i >= $max_plz_streets && $i < $#strres) {
		    print "...<br>\n";
		    last;
		}
	    }
	    $i++;
	}
	if ($use_select) {
	    print "</select><br>\n";
	}
	print "<input type=radio name=" . $type .
	  "name value=\"\"> <input type=text name=" . $type;
	if ($bi->{'can_javascript'}) {
	    print " onFocus='document.BBBikeForm.${type}name[document.BBBikeForm.${type}name.length-1].checked = true;'";
	}
	print "><br>\n";
    }
}

sub choose_all_form {

    use locale;
    eval {
	local $SIG{'__DIE__'};
	require POSIX;
	foreach my $locale (qw(de de_DE de_DE.ISO8859-1 de_DE.ISO_8859-1)) {
	    last if (&POSIX::setlocale( &POSIX::LC_ALL, $locale));
	}
    };

    print $q->header(@weak_cache, etag());
    header(#too slow XXX -onload => "list_all_streets_onload()",
	   -script => {-src => $bbbike_html . "/bbbike_start.js",
		      },
	  );

    my @strlist;
    $str->init;
    while(1) {
	my $ret = $str->next;
	last if !@{$ret->[1]};
	push(@strlist, $ret->[0]);
    }
    @strlist = sort @strlist;
    my %initial = ('Ä' => 'A',
		   'Ö' => 'O',
		   'Ü' => 'U');
    my $last = "";
    my $last_initial = "A";

    print "<center>";
    for my $ch ('A' .. 'Z') {
	print "<a href=\"#$ch\">$ch</a> ";
    }
    print "</center><div id='list'>";

    for(my $i = 0; $i <= $#strlist; $i++) {
	next if ($strlist[$i] =~ /^\(/);
	next if $last eq $strlist[$i];
	$last = $strlist[$i];
	(my $strname = $strlist[$i]) =~ s/\s+/\240/g;
	my $initial = substr($strname, 0, 1);
	if (defined $last_initial and
	    $last_initial ne $initial and
	    (!defined $initial{$initial} or
	     $last_initial ne $initial{$initial})) {
	    print "<hr>";
	    $last_initial = ($initial{$initial} ? $initial{$initial} : $initial);
	    print "<a name=\"$last_initial\"><b>$last_initial</b></a><br>";
	}
	print "$strname<br>";
    }
    print "</div>";
    print $q->end_html;
}

sub nahbereich {
    my($startc, $zielc, $startname, $zielname) =
      ($q->param('startc'), $q->param('zielc'),
       $q->param('startname'),$q->param('zielname'));
    print $q->header(@weak_cache, etag());
    header();
    print "Kreuzung im Nahbereich angeben:<p>\n";
    new_kreuzungen();
    my($startx, $starty) = split(/,/, $startc);
    my($zielx,  $ziely)  = split(/,/, $zielc);
    print "<form action=\"$bbbike_script\">";
    print "<b>Start</b>:<br>\n";
    print "<input type=hidden name=startname value=\"$startname\">";
    my $i = 0;
    foreach ($kr->nearest_loop($startx, $starty)) {
	print "<input type=radio name=startc value=\"$_\"";
	if ($i++ == 0) {
	    print " checked";
	}
	print "> ", join("/", @{$crossings->{$_}}), "<br>\n";
    }
    print "<hr>";
    print "<input type=hidden name=zielname value=\"$zielname\">";
    print "<b>Ziel</b>:<br>\n";
    $i = 0;
    foreach ($kr->nearest_loop($zielx, $ziely)) {
	print "<input type=radio name=zielc value=\"$_\"";
	if ($i++ == 0) {
	    print " checked";
	}
	print "> ", join("/", @{$crossings->{$_}}), "<br>\n";
    }
    print "<hr>";
    suche_button();
    footer();
    print "</form>\n";
    print $q->end_html;
}

sub get_nearest_crossing_coords {
    my($x,$y) = @_;
    new_kreuzungen();
    my $xy;
    if ($use_exact_streetchooser) {
	my $ret = $multistr->nearest_point("$x,$y", FullReturn => 1);
	$xy = $ret->{Coord};
    } else {
	$xy = (($kr->nearest_loop($x,$y))[0]);
    }
    $xy;
}

sub draw_route_from_fh {
    my $fh = shift;

    my $file = "$tmp_dir/bbbike.cgi.upload.$$";
    open(OUT, ">$file") or die "Can't write to $file: $!";
    while(<$fh>) {
	print OUT $_;
    }
    close OUT;

    require Route;
    Route->VERSION(1.09);
    my $res;
    eval {
	$res = Route::load($file, { }, -fuzzy => 1);
    };
    my $err = $@;
    unlink $file;

    if ($res->{RealCoords}) {
	$q->param('draw', 'all');
	$q->param('scope', 'wideregion');
	$q->param('geometry', "800x600");
	# Separator war mal ";", aber CGI.pm behandelt diesen genau wie "&"
	$q->param('coords', join("!", map { "$_->[0],$_->[1]" }
				 @{ $res->{RealCoords} }));
	if (!$q->param("imagetype")) {
	    $q->param("imagetype", "png"); # XXX seems to be necessary
	}
	$q->delete('routefile');
	$q->delete('routefile_submit');
	draw_route();
    } else {
	print $q->header(@no_cache, etag());
	header();
	print "Dateiformat nicht erkannt: $err";
	upload_button_html();
	footer();
	print $q->end_html;
    }
}

sub upload_button {
    print $q->header(@no_cache, etag()); # wegen dummy
    header();
    upload_button_html();
    footer();
    print $q->end_html;
}

sub upload_button_html {
    # XXX warum ist dummy notwendig???
    print $q->start_multipart_form(-method => 'post',
				   -action => "$bbbike_url?dummy=@{[ time ]}"),
          "Anzuzeigende Route-Datei (GPSman-Tracks oder .bbr-Dateien):<br>\n",
	  $q->filefield(-name => 'routefile'),
	  "<br>\n",
	  # hier könnte noch ein maxdist-Feld stehen, um die maximale
	  # Entfernung anzugeben, bei der eine Route noch als
	  # "zusammenhängend" betrachtet wird XXX
	  "Bildformat: ",
	  $q->popup_menu(-name => "imagetype",
			 -values => ['png',
				     ($cannot_pdf ? () : ('pdf-auto')),
				     ($cannot_svg ? () : ('svg')),
				     ($cannot_jpeg ? () : ('jpeg')),
				     ($can_mapserver ? ('mapserver') : ()),
				    ],
			 -default => 'png',
			 -labels => {'png' => 'PNG',
				     'pdf-auto' => 'PDF',
				     'svg' => 'SVG',
				     'jpeg' => 'JPEG',
				     'mapserver' => 'Mapserver'},
			),
	  "<br>\n",
	  $q->submit(-name => 'routefile_submit',
		     -value => 'Anzeigen'),
	  $q->endform;
}

sub tie_session {
    my $id = shift;
    return unless $use_apache_session;

    if (!eval {require Apache::Session::DB_File}) {
	$use_apache_session = undef;
	warn $@ if $debug;
	return;
    }

    tie my %sess, 'Apache::Session::DB_File', $id,
	{ FileName => "/tmp/bbbike_sessions_" . $< . ".db", # XXX make configurable
	  LockDirectory => '/tmp',
	} or do {
	    $use_apache_session = undef;
	    warn $! if $debug;
	    return;
	};

    return \%sess;
}

sub limit_processes {
    dbmopen(%proc, "$tmp_dir/bbbike-limit", 0640);
    my $i;
  TRY: while(1) {
	for ($i = 0; $i < $max_proc; $i++) {
	    if (defined $proc{$i} && $proc{$i} ne '') {
		next if kill 0, $proc{$i};
	    }
	    $proc{$i} = $$;
	    last TRY;
	}

	(my $slow_cgi = $bbbike_url) =~ s/-fast//;
	undef $slow_cgi if ($slow_cgi eq $bbbike_url);

	if ($auto_switch_slow && $slow_cgi) {
	    print $q->redirect(-uri => $slow_cgi, @no_cache);
	    exit;
	}

	print $q->header(@no_cache, etag());
	header();
	print <<EOF;
Der Server ist überlastet. Bitte ein paar Minuten später versuchen
EOF
        if ($slow_cgi) {
	    print "oder das <a href=\"$slow_cgi\">langsamere Interface</a> benutzen";
        }
        print <<EOF;
!<p>
<small>Anzahl der erlaubten Prozesse: $max_proc</small>
<p>
EOF
        footer();
	print $q->end_html;
	exit;
    }
    dbmclose(%proc);
    $i;
}

sub set_process {
    my $slot = shift;
    dbmopen(%proc, "$tmp_dir/bbbike-limit", 0640);
    $proc{$slot} = $$;
    dbmclose(%proc);
}

######################################################################
#
# Information
#
sub show_info {
    print $q->header(@weak_cache, etag());
    header();
    my $perl_url = "http://www.perl.com/";
    my $cpan = "http://www.perl.com/CPAN";
    my $scpan = "http://search.cpan.org/search?mode=module&query=";
    print <<EOF;
<center><h2>Information</h2></center>
<ul>
 <li><a href="#tipps">Die Routensuche</a>
 <li><a href="#link">Link auf BBBike setzen</a>
 <li><a href="#resourcen">Weitere Möglichkeiten mit BBBike</a>
 <li><a href="@{[ $bbbike_html ]}/presse.html">Die Presse über BBBike</a>
 <li><a href="#hardsoftware">Hard- und Softwareinformation</a>
 <li><a href="#disclaimer">Disclaimer</a>
 <li><a href="#autor">Kontakt</a>
</ul>
<hr>

<a name="tipps"><h3>Die Routensuche</h3></a>
Das Programm versucht, den kürzesten Weg zwischen den gewählten Berliner
Straßen zu finden. Die Auswahl erfolgt entweder durch das Eintippen
in die Eingabefelder für Start und Ziel (Via ist optional), durch Auswahl
aus der Buchstabenliste oder durch Auswahl über die Berlin-Karte.
Straßennamen müssen nicht völlig korrekt eingegeben werden. Groß- und
Kleinschreibung wird ignoriert.
<p>
Bei der Suche wird auf Einbahnstraßen und zeitweilig gesperrte Straßen
geachtet; auf Steigungen und Verkehrsdichte (noch) nicht. Straßen mit
schlechter Oberfläche und/oder Hauptstraßen können geringer bewertet oder
von der Suche ganz ausgeschlossen werden.
<p>
<!-- XXX not yet
Wozu werden die Sucheinstellungen verwendet?
<dl>
 <dt>Bevorzugte Geschwindigkeit
 <dd>
 <dt>Bevorzugter Straßentyp
 <dd>
 <dt>Bevorzugter Straßenbelag
 <dd>
 <dt>Ampeln vermeiden
 <dd>
 <dt>Grüne Wege bevorzugen
 <dd>
</dl>
-->
EOF
    print
      "Falls die " . complete_link_to_einstellungen() . " ",
      "für BikePower ausgefüllt wurden, ",
      "kann mit der " . link_to_met() . "aktuellen Windgeschwindigkeit</a> die ",
      "Fahrzeit anhand von drei Leistungsstufen (50&nbsp;W, 100&nbsp;W und 200&nbsp;W) ",
      "berechnet werden.<p>\n";
    if ($use_miniserver) {
        print <<EOF;
Es gibt einen Timeout von $cgi->{'timeout'} Minuten pro Seite. Wenn
die Zeit abgelaufen ist, kann das Programm per "Kaltstart" neu
gestartet werden. Evtl. funktioniert das Programm nicht über einen
Proxy; sollte es Probleme geben, eine <a
href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike problems">E-Mail an mich</a>
schicken.<p>
EOF
    }
    print <<EOF;
Für die technisch Interessierten: als Suchalgorithmus wird
A<sup>*</sup> eingesetzt<sup> <a href="#footnote1">1</a></sup>.<p>

<hr>
<a name="link"><h3>Link auf BBBike setzen</h3></a>
Man kann einen Link auf BBBike mit einem
bereits vordefinierten Ziel setzen. Die Vorgehensweise sieht so aus:
<ul>
 <li>Eine beliebige Route mit dem gewünschten Zielort suchen lassen. Dabei
     darf die Auswahl für den Zielort nicht über die Berlin-Karte erfolgen,
     sondern der Zielort muss direkt eingegeben werden.
 <li>Wenn die Route gefunden wurde, klickt man den Link "Ziel beibehalten" an.
 <li>Die URL der neuen Seite kann nun auf die eigene Homepage aufgenommen werden. Die URL müsste ungefähr so aussehen:
<tt>$bbbike_url?zielname=Alexanderplatz;zielplz=10178;zielc=10923%2C12779</tt>
 <li>Auf Wunsch kann <tt>zielname</tt> verändert werden. Beispielsweise:
<tt>$bbbike_url?zielname=Weltzeituhr;zielc=10923%2C12779</tt><br>
     Dabei sollte <tt>zielplz</tt> gelöscht werden. Wenn im Namen Leerzeichen
     vorkommen, müssen sie durch <tt>+</tt> ersetzt werden.
</ul>
<hr>
<p>
EOF

    print <<EOF;
<a name="resourcen"><h3>Weitere Möglichkeiten und Tipps</h3></a>
Es gibt eine wesentlich komplexere Version von BBBike, dass als normales
Programm (mit Perl/Tk-Interface) unter Unix, Linux und Windows läuft.
<a href="@{[ $BBBike::BBBIKE_SF_WWW ]}">Hier</a>
bekommt man dazu mehr Informationen. Als Beispiel kann man sich einen
<a href="@{[ $BBBike::BBBIKE_SF_WWW ]}/images/bbbike-screenshot.png">Screenshot</a> der perl/Tk-Version angucken.
<p>
Es besteht die experimentelle Möglichkeit, sich <a href="@{[ $bbbike_url ]}?uploadpage=1">GPS-Tracks oder bbr-Dateien</a> anzeigen zu lassen.<p>
Das Programm wird auch in <a href="@{[ $BBBike::DIPLOM_URL ]}">meiner Diplomarbeit</a> behandelt.<p>
EOF
    if ($bi->is_browser_version("Mozilla", 5)) {
	print <<EOF;
<script type="text/javascript"><!--
function addSidebar(frm) {
    if (window && window.sidebar && window.sidebar.addPanel &&
	typeof window.sidebar.addPanel == 'function') {
	var query = "";
	if (frm) {
	    var q = [];
	    if (frm.elements.start.value != "") {
		q[q.length] = "home=" + escape(frm.elements.start.value);
	    }
	    if (frm.elements.ziel.value != "") {
		q[q.length] = "goal=" + escape(frm.elements.ziel.value);
	    }
	    query = "?" + q.join("&");
	}
	window.sidebar.addPanel("BBBike", "$bbbike_html/bbbike_sidebar.html"+query, null);
    }
    return false;
}
// --></script>
<form name="bbbike_add_sidebar">
<a href="#" onclick="return addSidebar(document.forms.bbbike_add_sidebar)"><img src="http://developer.netscape.com/docs/manuals/browser/sidebar/add-button.gif" alt="Add sidebar" border=0></a>, dabei folgende Adressen als Default verwenden:<br>
<img src="$bbbike_images/flag2_bl.gif" border=0 alt="Start"> <input size=10 name="start"><br>
<img src="$bbbike_images/flag_ziel.gif" border=0 alt="Ziel"> <input size=10 name="ziel"><br>
</form>
EOF
    }
    if ($can_palmdoc) {
	print <<EOF;
<p>Für den PalmDoc-Export benötigt man auf dem Palm einen entsprechenden
Viewer, z.B.
<a href="http://www.freewarepalm.com/docs/cspotrun.shtml">CSpotRun</a>.
Für eine komplette Liste siehe auch
<a href="http://www.freewarepalm.com/docs/docs_software.shtml">hier</a>.
EOF
    }
    print "<hr><p>\n";

    print "<a name='hardsoftware'><h3>Hard- und Software</h3></a>\n";
    # funktioniert nur auf dem CS-Server
    my $os;
    if (open(INFO, "/usr/INFO/Rechnertabelle")) {
	my $host;
	eval q{local $SIG{'__DIE__'};
	       require Sys::Hostname;
	       $host = Sys::Hostname::hostname();
	   };
	while(<INFO>) {
	    if (/^$host:/o) {
		print "Hardware: " . (split /:/)[2] . "<p>\n";
		$os = (split /:/)[3];
		last;
	    }
	}
	close INFO;
    }
    unless (defined $os or $^O eq 'MSWin32') {
	open UNAME, "-|" or exec qw(uname -sr);
	my $uname = <UNAME>;
	close UNAME;
	if ($uname) {
	    chomp($os = "$uname");
	}
    }
    # Config ist ungenau, weil perl evtl. für ein anderes Betriebssystem
    # compiliert wurde.
    unless (defined $os) {
	require Config;
        $os = "\U$Config::Config{'osname'} $Config::Config{'osvers'}\E";
    }
    if (defined $os) {
        print "Betriebssystem: $os\n";
        if ($os =~ /freebsd/i) {
	    print "<a href=\"http://www.freebsd.org/\"><img align=right src=\"";
	    if (-f "/cdrom/www/gifs/powerani.gif") {
		print "file:/cdrom/www/gifs/powerani.gif";
	    } else {
		print "http://www.freebsd.org/gifs/powerani.gif";
	    }
	    print "\" border=0></a>";
	} elsif ($os =~ /linux/i) {
	    print "<a href=\"http://www.linux.org/\"><img align=right src=\"";
	    print "http://lwn.net/images/linuxpower2.png";
	    print "\" border=0></a>";
	}
        print "<p>";
    }
    if (defined $ENV{'SERVER_SOFTWARE'}) {
	print "HTTP-Server: $ENV{'SERVER_SOFTWARE'}\n";
	if ($ENV{'SERVER_SOFTWARE'} =~ /apache/i) {
	    print "<a href=\"http://www.apache.org/\"><img align=right src=\"";
	    if (-f "/cdrom/www/gifs/apache.gif") {
		print "file:/cdrom/www/gifs/apache.gif";
	    } else {
		print "http://www.apache.org/images/apache_pb.gif";
	    }
	    print "\" border=0></a>";
	}
	print "<p>";
    }
    if ($ENV{SERVER_NAME} =~ /sourceforge/) {
	print <<EOF;
<A href="http://sourceforge.net"> <IMG align=right
src="http://sourceforge.net/sflogo.php?group_id=19142"
width="88" height="31" border="0" alt="SourceForge Logo"></A><p>
EOF
    }

    print <<EOF;
Verwendete Software:
<ul>
<li><a href="$perl_url">perl $]</a><a href="$perl_url"><img border=0 align=right src="$bbbike_images/PoweredByPerl.gif"></a>
<li>perl-Module:<a href="$cpan"><img border=0 align=right src="http://theoryx5.uwinnipeg.ca/images/cpan.jpg"></a>
<ul>
<li><a href="${scpan}CGI">CGI $CGI::VERSION</a>
EOF
    if (defined $Apache::VERSION) {
	print <<EOF;
<li><a href="${scpan}Apache">Apache $Apache::VERSION</a> (auch bekannt als "mod_perl")
EOF
    } elsif ($use_fcgi) {
        print <<EOF;
<li><a href="${scpan}FCGI">FCGI</a> bei der FastCGI-Version
EOF
    } else {
        print <<EOF;
<li><a href="${scpan}CGI::Base">CGI::Base, CGI::Request, CGI::MiniSvr</a> bei der MiniServer-Version
EOF
    }
    if ($can_palmdoc) {
	print <<EOF;
<li><a href="${scpan}Palm::PalmDoc">Palm::PalmDoc</a> für den PalmDoc-Export
EOF
    }
    print <<EOF;
<li><a href="${scpan}GD">GD</a> für das Erzeugen der GIF/PNG/JPEG-Grafik
<li><a href="${scpan}PDF::Create">PDF::Create</a> für das Erzeugen der PDF-Grafik
<li><a href="${scpan}SVG">SVG</a> für das Erzeugen von SVG-Dateien
<li><a href="${scpan}Storable">Storable</a>
<li><a href="${scpan}String::Approx">String::Approx</a> für approximatives Suchen von Straßennamen (anstelle von <a href="ftp://ftp.cs.arizona.edu/agrep/">agrep</a>)
</ul>
EOF
    if ($can_mapserver) {
        print <<EOF;
<li><a href="http://mapserver.gis.umn.edu/">Mapserver</a>
EOF
    }
    print <<EOF;
</ul>
<hr><p>
EOF

    if ($bi || eval { require BrowserInfo }) {
	print "<h3>Browserinformation</h3><pre>";
	$bi = BrowserInfo->new($q) if !$bi;
	print $bi->show_info();
	print "</pre><hr><p>\n";
    }

    print <<EOF;
<h3><a name="disclaimer">Disclaimer</a></h3>
Es wird keine Gewähr für die Inhalte dieser Site sowie verlinkter Sites
übernommen.
<hr>

EOF

    print <<EOF;
<h3><a name="autor">Kontakt</a></h3>
<center>
Autor: Slaven Rezic<br>
<a href="mailto:@{[ $BBBike::EMAIL ]}">E-Mail:</a> <a href="mailto:@{[ $BBBike::EMAIL ]}">@{[ $BBBike::EMAIL ]}</a><br>
<a href="@{[ $BBBike::HOMEPAGE ]}">Homepage:</a> <a href="@{[ $BBBike::HOMEPAGE ]}">@{[ $BBBike::HOMEPAGE ]}</a></a><br>
Telefon: @{[ CGI::escapeHTML("+49-0178-3737831") ]}<br>
</center>
<p>
EOF

    # XXX Wo gehören die Fußnoten am besten hin?
    print <<EOF;
<p><p><p><hr>
Fußnoten:<br>
<a name="footnote1"><sup>1</sup> R. Dechter and J. Pearl, Generalized
best-first search strategies and the optimality of A<sup>*</sup>,
Journal of the Association for Computing Machinery, Vol. 32, No. 3,
July 1985, Seiten 505-536.<hr><p>
EOF

    footer();

    print $q->end_html;
}

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (C) 1998-2003 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

bbbike(1).

=cut
