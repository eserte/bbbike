#!/usr/bin/env perl
#!/usr/local/bin/perl
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 1998-2020,2022,2023,2024 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

=head1 NAME

bbbike.cgi - CGI interface to bbbike

=cut

BEGIN {
    $ENV{SERVER_NAME} ||= "";
    open(STDERR, ">/home/groups/b/bb/bbbike/bbbike.log")
	if $ENV{SERVER_NAME} =~ /sourceforge/ && -w "/home/groups/b/bb/bbbike";
    #$^W = 1 if $ENV{SERVER_NAME} =~ /herceg\.de/i;
}
use vars qw(@extra_libs);
BEGIN { delete $INC{"FindBin.pm"} } # causes warnings, maybe try FindBin->again if available?
use FindBin;
BEGIN {
    if ($ENV{MOD_PERL} && $ENV{MOD_PERL} =~ m{mod_perl/2}) {
	# Fix FindBin for ModPerl::Registry operation
	($FindBin::RealBin = __FILE__) =~ s{/[^/]+$}{};
    }
    {
	# Achtung: evtl. ist auch ~/lib/ f�r GD.pm notwendig (z.B. CS)
	@extra_libs =
	    (grep { -d }
	     #"/home/e/eserte/src/bbbike",
	     "$FindBin::RealBin/..", # falls normal installiert
	     "$FindBin::RealBin/../lib",
	     "$FindBin::RealBin/../BBBike", # falls in .../cgi-bin/... installiert
	     "$FindBin::RealBin/../BBBike/lib",
	     "$FindBin::RealBin/BBBike", # weitere Alternative
	     "$FindBin::RealBin/BBBike/lib",
	     "$FindBin::RealBin",
	    );
    }
}
use lib (@extra_libs);

use Strassen; # XXX => Core etc.?
use Strassen::Dataset;
#use Strassen::Lazy; # XXX mal sehen...
use BBBikeCalc;
use BBBikeVar;
use BBBikeUtil qw(is_in_path min max kmh2ms);
use BBBikeCGI::Util;
use File::Basename qw(dirname basename);
use CGI;
use CGI::Carp; # Nur zum Debuggen verwenden --- manche Web-Server machen bei den kleinsten Kleinigkeiten Probleme damit: qw(fatalsToBrowser);
use BrowserInfo 1.47;
use strict;
use vars qw($VERSION $VERBOSE
	    $debug $tmp_dir $mapdir_fs $mapdir_url $local_route_dir
	    $bbbike_root $bbbike_images $bbbike_url $bbbike2_url $is_secure $is_beta
	    $bbbike_html
	    $modperl_lowmem $detailmap_module
	    $q %persistent %c $got_cookie
	    $g_str $orte $orte2 $multiorte
	    $ampeln $qualitaet_net $handicap_net $handicap_directed_net
	    $strcat_net $radwege_strcat_net $radwege_net $routen_net $comments_net
	    $green_net $unlit_streets_net
	    $crossings $kr $culdesac_cached %cached_plz $net
	    $sperre_tragen $sperre_narrowpassage
	    $overview_map $city
	    $use_umland $use_umland_jwd $use_special_destinations
	    $use_fragezeichen $use_fragezeichen_routelist
	    $check_map_time $use_cgi_bin_layout
	    $show_weather $show_start_ziel_url @weather_cmdline
	    $bp_obj $bi $use_select
	    $graphic_format $use_exact_streetchooser
	    $use_module
	    $cannot_jpeg $cannot_pdf $cannot_svg $can_gif
	    $can_wbmp $can_palmdoc $can_gpx $can_kml
	    $can_google_maps
	    $can_mapserver $mapserver_address_url
	    $bbbikedraw_pdf_module
	    $mapserver_init_url $no_berlinmap $max_plz_streets $with_comments
	    $with_cat_display
	    $use_coord_link
	    @weak_cache @no_cache
	    $bbbike_script
	    $search_algorithm $use_background_image
	    $use_apache_session $now_use_apache_session $apache_session_module $cookiename
	    $bbbike_temp_blockings_file $bbbike_temp_blockings_optimized_file
	    @temp_blocking $temp_blocking_epoch
	    $use_cgi_compress_gzip $use_bbbikedraw_pdf_compress $max_matches
	    $use_winter_optimization $winter_hardness
	    $with_lang_switch
	    $newstreetform_encoding
	    $use_region_image
	    $include_outer_region @outer_berlin_places $outer_berlin_qr $outer_berlin_subplaces_qr
	    $warn_message $use_utf8 $data_is_wgs84 $osm_data
	    $bbbike_start_js_version $bbbike_css_version
	    $use_file_cache $cache_entry
	   );
# XXX This may be removed one day
use vars qw($use_cooked_street_data);

#XXX in mod_perl/Apache::Registry operation there are a lot of "shared
# variable" warnings. They seem to be not harmful, but I should get
# rid of them.

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

#$mapdir_url = '/~eserte/bbbike-tmp';

=item $mapdir_fs

The C<$mapdir_url> path in filesystem space.

=cut

#$mapdir_fs  = '/home/e/eserte/www/bbbike-tmp';

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

=item $local_route_dir

A directory where local route files are stored. These may be drawn
with the C<localroutefile> parameter.

=cut

undef $local_route_dir;

=item $use_file_cache

Cache some requests.

=cut

$use_file_cache = 0;

=back

=head2 External programs

=over

=item $ENV{PATH}

Some WWW servers set the PATH environment variable empty. Set this to
a sane value (e.g. /bin:/usr/bin) for some required external programs.

=cut

$ENV{PATH} = '' if !defined $ENV{PATH};
$ENV{PATH} = "/usr/bin:$ENV{PATH}" if $ENV{PATH} !~ m{/usr/bin}; # for Sys::Hostname

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

=item $modperl_lowmem

In the case of using the script in a  modperl environment: set this to
true, if global variables should be deleted after the end of a request.
This may help if there are memory leaks. Default: true if MOD_PERL.

=cut

$modperl_lowmem = $ENV{MOD_PERL};

=item $use_apache_session

Use an L<Apache::Session> class for storing the route coordinates.
This is useful for large routes which would overflow the URL capacity
of most browsers and web servers. Default: false.

=cut

$use_apache_session = 0;

=item $apache_session_module

The class of the L<Apache::Session> family to be used. Default is
L<Apache::Session::Counted>.

=cut

$apache_session_module = "Apache::Session::Counted";

=back

=head2 Graphic creation, export formats

=over

=item $detailmap_module

The L<BBBikeDraw> module to use for detailmap creation. By default
C<GD> is used.

=cut

$detailmap_module = undef;

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

=item $use_module

Use another drawing module instead of the default GD. Possible values
are ImageMagick or Imager.

=cut

undef $use_module;

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

=item $bbbikedraw_pdf_module

What L<BBBikeDraw> module for drawing PDFs should be used. Default:
C<undef> (for L<BBBikeDraw::PDF>). Alternative value is C<PDFCairo>
for L<BBBikeDraw::PDFCairo> (requires L<Cairo>, and L<Pango> is
recommended).

=cut

$bbbikedraw_pdf_module = undef;

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
L<Palm::PalmDoc> module (possible viewer: CSpotRun). Default: false.

=cut

$can_palmdoc = 0;

=item $can_gpx

Set this to a true value if you can produce GPX documents (needs
L<XML::LibXML>. Default: false.

=cut

$can_gpx = 0;

=item $can_kml

Set this to a true value if you can produce KML documents (needs
L<XML::LibXML>. Default: false.

=cut

$can_kml = 0;

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

$mapserver_init_url = $BBBike::BBBIKE_MAPSERVER_DIRECT;

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

The command line for the weather information fetching program. The
program must implement the C<-o> option to write down a file which
conforms to the "wettermeldung2" format as described in
F<miscsrc/icao_metar.pl>.

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

=item $with_cat_display

Include column for graphical category display. Only activated if
browser is able to display tables. Default is false.

=cut

$with_cat_display = 0;

=item $use_coord_link

Use an own exact coordinate link (i.e. to Mapserver) instead of a
"Stadtplan" link. Default: true.

=cut

$use_coord_link = 1;

=back

=head2 Data

=over

=item $city

The city/country key. Default is Berlin_DE. A same named module as
Geography::I<$city> should exist.

=cut

$city = "Berlin_DE";

=item $use_umland

NYI: search in the region. Default: false.

=cut

$use_umland = 0;

=item $use_umland_jwd

NYI: search in the wide region. Default: false.

=cut

$use_umland_jwd = 0;

=item $use_special_destinations

Set to a true value if special destinations like bikeshops, bankomats etc.
may be used. NOT YET USED.

=cut

$use_special_destinations = 0;

=item $use_fragezeichen

Set to true to allow the user to search unknown streets.

=cut

$use_fragezeichen = 0;

=item $use_fragezeichen_routelist

Set to true to show unknown streets in the route list.

=cut

$use_fragezeichen_routelist = 1;

=back

=head2 Misc

=over

=item $search_algorithm

Default search algorithm is (pure perl) A*, but may be set to C<C-A*> or
other.

=cut

$search_algorithm = undef;

=item $use_exact_streetchooser

Exact chooser for near coordinates ... somewhat slower, but more
exact. Default: true.

=cut

$use_exact_streetchooser = 1;

=item $VERBOSE

Set this to true for debugging purposes.

=cut

$VERBOSE = 0;

=item $bbbike_temp_blockings_file

Full path to a bbbike-temp-blockings.pl file. See @temp_blocking for
more information on the file format.

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

=item $use_utf8

Set to a true value if the C<utf-8> encoding should be used on the
generated HTML pages. Highly recommended for non-latin1 data.

=cut

$use_utf8 = 0;

=item $data_is_wgs84

Set to a true value if data is using wgs84 coordinates instead of
the home-brew bbbike format. Probably only useful for data converted
from OpenStreetMap.

=cut

$data_is_wgs84 = 0;

=item $osm_data

Set to a true value if data originates from OpenStreetMap.

=cut

$osm_data = 0;

=item $Strassen::Util::cacheprefix

Define a unique prefix if multiple bbbike.cgi installations with
different data sets are running on the same system. Typically this
should be a short string consisting of a city and country abbrev, e.g.
C<b_de> for Berlin in Germany.

=back

=cut

# XXX document: # show max n matches in start form
$max_matches = 20;

$newstreetform_encoding = "";

@outer_berlin_places = (qw(Potsdam Oranienburg Birkenwerder Kleinmachnow Stahnsdorf Teltow Bernau Strausberg Falkensee Mahlow Erkner
			   Dahlwitz-Hoppegarten Woltersdorf R�dersdorf Werder Hennigsdorf Schwanebeck H�now Ahrensfelde Gro�ziethen
		          ), "Hohen Neuendorf", "K�nigs Wusterhausen", "Sch�neiche bei Berlin", "Neuenhagen bei Berlin",
			"Petershagen bei Berlin", 'Dallgow-D�beritz', "Sch�nefeld", "Gosen", "Zepernick", "R�ntgental",
			"Glienicke/Nordbahn", "Dahlewitz",
		       );
$outer_berlin_qr = "^(?:" . join("|", map { quotemeta } @outer_berlin_places) . ")\$"; $outer_berlin_qr = qr{$outer_berlin_qr};
$outer_berlin_subplaces_qr = "^(?:" . join("|", map { quotemeta } @outer_berlin_places) . ")(-|\$)"; $outer_berlin_subplaces_qr = qr{$outer_berlin_subplaces_qr};

####################################################################

unshift(@Strassen::datadirs,
	"$FindBin::RealBin/../data",
	"$FindBin::RealBin/../BBBike/data",
       );

use vars qw($lang $config_master $msg $fake_time);

# These must not be permanent:
undef $msg;
undef $bbbike_root;
undef $bbbike_html;
undef $bbbike_images;
undef $warn_message;

$config_master = $0;
$lang = "";
if ($config_master =~ s{^(.*)\.(en)(\.cgi)$}{$1$3}) {
    $lang = $2;
}
# XXX hier require verwenden???
eval { local $SIG{'__DIE__'};
       #warn "$config_master.config";
       do "$config_master.config" };

if ($lang ne "") {
    $msg = eval { do "$FindBin::RealBin/msg/$lang" };
    if ($msg && ref $msg ne 'HASH') {
	undef $msg;
    }
}

sub M ($) {
    my $key = shift;

    if ($msg && exists $msg->{$key}) {
	$msg->{$key};
    } else {
        warn "Unknown translation: $key\n" if $VERBOSE && $msg;
	$key;
    }
}

if ($VERBOSE) {
    $StrassenNetz::VERBOSE    = $VERBOSE;
    $Strassen::VERBOSE        = $VERBOSE;
    $StrassenNetz::CNetFile::VERBOSE  = $VERBOSE;
    $Kreuzungen::VERBOSE      = $VERBOSE;
}

use vars qw($cgic); # Can't use my here!
sub my_exit {
    my $exit_code = shift;
    # Seems to be necessary for CGI::Compress::Gzip to flush the
    # output buffer.
    undef $cgic;
    exit $exit_code;
}

use vars qw($require_Karte);
$require_Karte = sub {
    require Karte;
    Karte::preload('Standard', 'Polar');
    $Karte::Standard::obj = $Karte::Standard::obj if 0; # cease -w
    undef $require_Karte;
};

$VERSION = '11.012';

use vars qw($delim);
$delim = '!'; # wegen Mac nicht � verwenden!

@weak_cache = ('-expires' => '+1d',
               # XXX ein bi�chen soll Netscape3 auch cachen k�nnen:
	       #'-pragma' => 'no-cache',
	       '-cache-control' => 'private',
              );
@no_cache = ('-expires' => 'now',
             '-pragma' => 'no-cache',
	     '-cache-control' => 'no-cache',
            );
#XXX shared variable ! my $header_written;
use vars qw($header_written);

if (%Apache::) {
    # workaround for "use lib" problem with Apache::Registry
    'lib'->import(@extra_libs);
}

use vars qw($xgridwidth $ygridwidth $xgridnr $ygridnr $xm $ym $x0 $y0
	    $detailwidth $detailheight $nice_berlinmap $nice_abcmap
	    $need_zoom_hack $hack_scalefactor
	    $start_bgcolor $via_bgcolor $ziel_bgcolor @pref_keys);
# Konstanten f�r die Imagemaps
# Die Werte (bis auf $ym) werden mit small_berlinmap.pl ausgegeben.
use vars qw($berlin_small_width $berlin_small_height $berlin_small_suffix);
if (!$use_region_image) {
    $berlin_small_width = $berlin_small_height = 200;
    $berlin_small_suffix = "";
    $xm = 228.58;
    $ym = 228.58;
    $x0 = -10849;
    $y0 = 34282.5;
} elsif (0) {
    $berlin_small_width = $berlin_small_height = 240;
    $berlin_small_suffix = "_240";
    $xm = 223.6375;
    $ym = 223.6375;
    $x0 = -19716;
    $y0 = 38448.5;
} else {
    $berlin_small_width  = 280;
    $berlin_small_height = 240;
    $berlin_small_suffix = "_280x240";
    $xm = 247.057142857143;
    $ym = 247.057142857143;
    $x0 = -25901;
    $y0 = 41258.8571428572;
}
# Die n�chsten beiden Variablen m�ssen auch in bbbike_start.js ge�ndert werden.
$xgridwidth = 20; # 20 * 10 = 200: Breite und H�he von berlin_small.gif
$ygridwidth = 20;
$xgridnr = $berlin_small_width / $xgridwidth;
$ygridnr = $berlin_small_height / $ygridwidth;
## sch�n gro�, aber passt nicht auf Seite
#$detailwidth  = 600; # mu� quadratisch sein!
#$detailheight = 600;
$detailwidth  = 500; # mu� quadratisch sein!
$detailheight = 500;
$nice_berlinmap = 0;
$nice_abcmap    = 0;
$need_zoom_hack = undef; # will be defined in _zoom_hack_init

$bbbike_start_js_version = '1.25';
$bbbike_css_version = '1.02';

use vars qw(@b_and_p_plz_multi_files %is_usable_without_strassen %same_single_point_optimization);
@b_and_p_plz_multi_files = 
    #  File                   Data fmt   Usable without being in strassen
    #                                        same single point optimization
    #                                           optional
    (["Berlin.coords.data",   "PLZ",      0, 0, 0],
     ["Potsdam.coords.data",  "PLZ",      0, 0, 0],
     ["plaetze",              "Strassen", 0, 1, 0], # because there are also some "sehenswuerdigkeiten" in
     ["oldnames",             "PLZ",      0, 0, 1],
     # not yet: ["sehenswuerdigkeit_bp", "Strassen", 1, 1], # generated, see below
    );
for my $i (0 .. $#b_and_p_plz_multi_files) {
    $is_usable_without_strassen{$i}     = $b_and_p_plz_multi_files[$i]->[2];
    $same_single_point_optimization{$i} = $b_and_p_plz_multi_files[$i]->[3];
}

$start_bgcolor = '';
$via_bgcolor   = '';
$ziel_bgcolor  = '';
if (!$use_background_image) {
    $start_bgcolor = '#f0f8ff';
    $via_bgcolor   = '#ecf4ff';
    $ziel_bgcolor  = '#e8f0ff';
}
use vars qw($speed_default);
$speed_default = 20;

use vars qw(%handicap_speed);
%handicap_speed = ("q4" => 5, # hardcoded f�r Fu�g�ngerzonen
		   "q3" => 13,
		   "q2" => 18,
		   "q1" => 25,
		   'Q'  => 8, # XXX this is for ferries, and should probably be finer granulated
		  );

@pref_keys = qw/speed cat quality ampel green specialvehicle unlit ferry winter fragezeichen/;

CGI->import('-no_xhtml');

$q = new CGI;
# Used for $use_utf8=1
eval{BBBikeCGI::Util::decode_possible_utf8_params($q);};warn $@ if $@;

{
    # Don't use RealBin here
    my $f = "$FindBin::Bin/Botchecker_BBBike.pm";
    if (-r $f) {
	eval {
	    local $SIG{'__DIE__'};
	    do $f;
	    Botchecker_BBBike::run($q);
	};
	warn $@ if $@;
    }
}

undef $g_str; # XXX because it may already contain landstrassen etc.
undef $net; # dito
undef $kr;
undef $comments_net; # XXX because it may or may not contain qualitaet_l

# reset per request
$now_use_apache_session = $use_apache_session;

#$str = new Strassen "strassen" unless defined $str;
#$str = new Strassen::Lazy "strassen" unless defined $str;
$cookiename = "bbbike";
#get_streets($use_umland_jwd ? "wideregion" : $use_umland ? "region" : "city");

# Maximale Anzahl der angezeigten Stra�en, wenn eine Auswahl im PLZ-Gebiet
# gezeigt wird.
$max_plz_streets = 25;

# die originale URL (f�r den Kaltstart)
$bbbike_url = BBBikeCGI::Util::my_url($q);
$is_secure = $bbbike_url =~ m{^https://};
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
$is_beta = $bbbike_url =~ m{bbbike\d(-test)?(\.en)?\.cgi}; # bbbike2.cgi ...
$bbbike2_url = $bbbike_url;
if (!$is_beta) {
    local $^W; # $1 may be undef
    $bbbike2_url =~ s{bbbike(-test)?(\.en)?\.cgi}{bbbike2$1$2.cgi};
}

$bbbike_script = $bbbike_url;

use vars qw($is_m $is_printable);
$is_m = $q->virtual_host =~ m{^m\.}; # e.g. m.bbbike.de
$is_printable = !$is_m;

if (!$mapdir_url && !$mapdir_fs) {
    $mapdir_url = "$bbbike_script?tmp=";
    $mapdir_fs  = "$FindBin::RealBin/../tmp/www"; # hmmm, too much assuming about position of cgi
}

if (defined $mapdir_fs && !-d $mapdir_fs) {
    # unter der Voraussetzung, dass das Parent-Verzeichnis schon existiert
    mkdir $mapdir_fs, 0755;
}

# $mapdir_url absolut machen
if (defined $mapdir_url && $mapdir_url !~ m{^https?://}) {
    $mapdir_url = "http://" . BBBikeCGI::Util::my_server_name($q) . ($q->server_port != 80 ? ":" . $q->server_port : "") . $mapdir_url;
}

use vars qw($smallform);
$smallform = 0;

$header_written = 0;

if ($q->path_info ne "") {
    my $q2 = CGI->new(substr($q->path_info, 1));
    foreach my $k ($q2->param) {
	$q->param($k, BBBikeCGI::Util::my_multi_param($q2, $k));
    }
}

if ($q->param("tmp")) {
    my $file = $q->param("tmp");
    $file =~ s{/+}{}g; # one leading slash is expected
    $file = $mapdir_fs . "/" . $file;
    my($ext) = $file =~ m{\.([^\.]+)$};
    http_header(-type => "image/$ext",
		@no_cache);
    binmode STDOUT;
    open TMP, $file or die "Can't open file $file: $!";
    local $/ = \8192;
    while(<TMP>) {
	print $_;
    }
    close TMP;
    my_exit(0);
}

# Bei Verwendung von Apache mu� die User-Info immer neu
# festgestellt werden
user_agent_info();

# Die nervigen Java-Robots... wenn sie wenigstens korrekt crawlen
# w�rden und robots.txt beachten w�rden...
if ($q->user_agent =~ m{^Java/1\.} && ($q->query_string||'') eq '') {
    print $q->redirect("$bbbike_html/bbbike_small.html");
    my_exit(0);
}

undef $bp_obj;
init_bikepower($q);

use vars qw($wettermeldung_file);
$wettermeldung_file = "$tmp_dir/wettermeldung-$<";
if (defined $Strassen::Util::cacheprefix) {
    $wettermeldung_file .= "-" . $Strassen::Util::cacheprefix;
}
# Wettermeldungen so fr�h wie m�glich versuchen zu holen
if ($show_weather || $bp_obj) {
    start_weather_proc();
}

$smallform = $q->param('smallform') || $bi->{'mobile_device'} || $is_m;
$got_cookie = 0;
%c = ();

if (defined $q->param('api')) {
    require BBBikeCGI::API;
    BBBikeCGI::API::action(scalar $q->param('api'), $q);
    my_exit(0);
}

if ($q->param('_hack_scalefactor')) {
    $hack_scalefactor = $q->param('_hack_scalefactor');
    $q->delete('_hack_scalefactor');
} else {
    undef $hack_scalefactor;
}

$fake_time = $q->param('fake_time');

foreach my $type (qw(start via ziel)) {
    if (defined $q->param($type . "charimg.x") and
	$q->param($type . "charimg.x") ne ""   and
	defined $q->param($type . "charimg.y") and
	$q->param($type . "charimg.y") ne "") {
	_apply_hack_scalefactor($type . "charimg");
	my($x, $y) = (int(($q->param($type . "charimg.x")-2)/30),
		      int(($q->param($type . "charimg.y")-2)/30));
	my $ch = $x + $y*9 + ord("A");
	$ch = ($ch > ord("Z") ? 'Z' : ($ch < ord("A") ? 'A' : chr($ch)));
	$q->param($type . "char", $ch);
	$q->delete($type . "charimg.x");
	$q->delete($type . "charimg.y");
    } elsif (defined $q->param($type . 'c_wgs84') and
	     $q->param($type . 'c_wgs84') ne '') {
	my @new_params;
	for my $old_param (BBBikeCGI::Util::my_multi_param($q, $type . 'c_wgs84')) {
	    my($lon,$lat) = split /,/, $old_param;
	    if ($lon == 0 && $lat == 0) {
		send_error(reason => "Highly probably wrong coordinate $lon/$lat in '$type', refusing to continue work.");
	    }
	    my($x,$y) = convert_wgs84_to_data($lon,$lat);
	    push @new_params, "$x,$y";
	}
	$q->param($type . 'c', @new_params);
	$q->delete($type . 'c_wgs84');
    }

    # normalize (undefined = unset)
    if (defined $q->param($type . 'c') and $q->param($type . 'c') eq '') {
	$q->delete($type . 'c');
    }
}

{
    my($dx,$dy);
 TRY_MOVEMAP: {
	for my $ns_direction_def (['n', -1],
				  ['s', +1],
				  ['',   0],
				 ) {
	    my($ns_direction, $_dy) = @$ns_direction_def;
	    for my $ew_direction_def (['',  0 ],
				      ['e', +1],
				      ['w', -1],
				     ) {
		my($ew_direction, $_dx) = @$ew_direction_def;
		my $param_name = "movemap_" . $ns_direction . $ew_direction;
		if ($q->param($param_name)) {
		    $q->delete($param_name);
		    $dx = $_dx;
		    $dy = $_dy;
		    last TRY_MOVEMAP;
		}
	    }
	}
    }

    if ($dx || $dy) {
	my($x, $y) = (scalar $q->param('detailmapx'),
		      scalar $q->param('detailmapy'));
	$q->delete('detailmapx');
	$q->delete('detailmapy');
	$x += $dx;
	$y += $dy;
	draw_map('-x' => $x,
		 '-y' => $y);
	goto REQUEST_DONE;
    }
}

foreach my $type (qw(start via ziel)) {
    if (defined $q->param($type . "mapimg.x") and
	$q->param($type . "mapimg.x") ne ""   and
	defined $q->param($type . "mapimg.y") and
	$q->param($type . "mapimg.y") ne "") {
	_apply_hack_scalefactor($type . "mapimg");
	my($x, $y) = (int($q->param($type . 'mapimg.x')/$xgridwidth),
		      int($q->param($type . 'mapimg.y')/$ygridwidth));
	$q->param('type', $type);
	$q->delete($type . "mapimg.x");
	$q->delete($type . "mapimg.y");
	draw_map('-x' => $x,
		 '-y' => $y);
	goto REQUEST_DONE;
    }
}

if (defined $q->param('detailmapx') and
    defined $q->param('detailmapy') and
    defined $q->param('detailmap.x') and
    defined $q->param('detailmap.y')
   ) {
    _apply_hack_scalefactor("detailmap");
    my $c = detailmap_to_coord(scalar $q->param('detailmapx'),
			       scalar $q->param('detailmapy'),
			       scalar $q->param('detailmap.x'),
			       scalar $q->param('detailmap.y'));
    if (defined $c) {
	$q->param($q->param('type') . 'c', $c);
    } else {
	$warn_message = M("F�r diese Koordinaten konnte keine Kreuzung gefunden werden.");
    }
    $q->delete('detailmapx');
    $q->delete('detailmapy');
    $q->delete('detailmap.x');
    $q->delete('detailmap.y');
    $q->delete('type');
}

# Params for opensearch
if (defined $q->param("ossp") && $q->param("ossp") !~ m{^\s*$}) {
    (my $ossp = $q->param("ossp")) =~ s{^\s*}{};
    $ossp =~ s{\s*$}{};
    my @args;
    if (eval { require Text::ParseWords; 1 }) {
	@args = Text::ParseWords::shellwords($ossp);
    } else {
	warn $@;
	@args = split /\s+/, $ossp;
    }
    if (@args == 1) {
	$q->param('start', $args[0]);
    } elsif (@args == 2) {
	$q->param('start', $args[0]);
	$q->param('ziel', $args[1]);
    } elsif (@args >= 3) {
	$q->param('start', $args[0]);
	$q->param('via', $args[1]);
	$q->param('ziel', $args[2]);
	# more params will be ignored
    }
}

# Try cache?
if ($use_file_cache) {
    my $file_cache;
    my $output_as = $q->param('output_as');
    if ($output_as && $output_as =~ m{^(kml-track|gpx-track|gpx-route|json|json-short)$}) {
	$file_cache = _get_weekly_filecache();
    } else {
	my $imagetype = $q->param('imagetype');
	if ($imagetype && $imagetype =~ m{^pdf}) {
	    $file_cache = _get_hourly_filecache();
	}
    }
    if ($file_cache) {
	$cache_entry = $file_cache->get_entry($q);
	if ($cache_entry->exists_content) {
	    my $meta = $cache_entry->get_meta;
	    if ($meta) {
		if (1) { # $debug) {
		    warn "DEBUG: Cache hit for " . $q->query_string . "\n";
		    http_req_logging();
		}
		http_header(@{ $meta->{headers} || [] }, '-X-bbbike-file-cache' => 'HIT');
		$cache_entry->stream_content;
		my_exit(0);
	    }
	}
    }
}

# Check if startc is valid and delete if not
# scvf=startcvalidfor
if ($q->param('startc') && $q->param('scvf') && $q->param('scvf') ne $q->param('start')) {
    $q->delete('startc');
}

if (defined $q->param('begin')) {
    # The begin=1 parameter was introduced for buggy ancient browsers
    # (Netscape3, Solaris2?)
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
} elsif (defined $q->param('mapserver')) {
    start_mapserver();
} elsif (defined $q->param('routefile') and
	 $q->param('routefile') ne "") {
    draw_route_from_fh($q->upload('routefile'));
} elsif (defined $q->param('localroutefile') &&
	 defined $local_route_dir) {
    (my $local_route_file = $q->param('localroutefile')) =~ s/[^A-Za-z0-9._-]//g;
    die "No \$local_route_dir specified in bbbike.cgi.config" if !defined $local_route_dir;
    $local_route_file = "$local_route_dir/$local_route_file";
    open(FH, $local_route_file)
	or die "Can't open $local_route_file: $!";
    draw_route_from_fh(\*FH);
} elsif (defined $q->param('localroutefilelist') &&
	 defined $local_route_dir) {
    (my $local_route_file = $q->param('localroutefilelist')) =~ s/[^A-Za-z0-9._-]//g;
    $local_route_file = "$local_route_dir/$local_route_file";
    show_routelist_from_file($local_route_file);
} elsif (defined $q->param('coords') || defined $q->param('coordssession') || $q->param('gple') || $q->param('gpleu')) {
    if ($q->param('showroutelist')) {
	# XXX note: coordssession+showroutelist is not implemented
	show_routelist_from_coords();
    } else {
	draw_route();
    }
} elsif (defined $q->param('create_all_maps')) {
    http_header(-type => 'text/plain',
		@no_cache,
	       );
    $| = 1;
    $check_map_time = 1;
    for my $x (0 .. $xgridnr-1) {
	for my $y (0 .. $ygridnr-1) {
	    print "x=$x y=$y ...\n";
	    create_map('-x' => $x,
		       '-y' => $y,
		       '-quiet'    => 1,
		       '-logging'  => 1,
		       '-strlabel' => 1,
		       '-force'    => 0,
		      );
	}
    }
    my_exit(0);
} elsif (defined $q->param('clean_expired_cache')) {
    http_header(-type => 'text/plain',
		@no_cache,
	       );
    for my $def (
		 ['weekly filecache (e.g. for kml-track)', _get_weekly_filecache(), [only_synced => 1]],
		 ['hourly filecache (e.g. for pdf files)', _get_hourly_filecache(), []],
		) {
	my($label, $file_cache, $extra_args) = @$def;
	my $res = $file_cache->clean_expired_cache(@$extra_args);
	print "DONE. $res->{count_success} directory/ies deleted in $label, $res->{count_errors} error/s";
	if (defined $res->{count_skip_unsynced}) {
	    print ", skipped $res->{count_skip_unsynced} unsynced directories";
	}
	print "\n";
    }
    my_exit(0);
} elsif (defined $q->param('drawmap')) {
    my($x,$y) = split /,/, $q->param('drawmap');
    my %res = create_map('-x' => $x, '-y' => $y, -strlabel => 1, -force => 0);
    print CGI->redirect(-uri => $res{imgurl});
    exit 0;
} elsif (defined $q->param('startchar')) {
    choose_ch_form(scalar $q->param('startchar'), 'start', scalar $q->param('startort'));
} elsif (defined $q->param('viachar')) {
    choose_ch_form(scalar $q->param('viachar'), 'via', scalar $q->param('viaort'));
} elsif (defined $q->param('zielchar')) {
    choose_ch_form(scalar $q->param('zielchar'), 'ziel', scalar $q->param('zielort'));
} elsif (defined $q->param('startc') and
	 defined $q->param('zielc')) {
    if (!$q->param('pref_seen')) {
	# zuerst die Einstellungen f�r die Suche eingeben lassen
	get_kreuzung();
    } else {
	# und erst dann suchen
	search_coord();
    }
} elsif (((defined $q->param('startname') and $q->param('startname') ne '')
	  or
	  (defined $q->param('startc')))
	 and
	 ((defined $q->param('zielname')  and $q->param('zielname')  ne '')
	  or
	  (defined $q->param('zielc')))
	 and
	 via_not_needed()
	) {
    get_kreuzung();
} elsif (defined $q->param('browser')) {
    show_user_agent_info();
} elsif (defined $q->param('init_environment')) {
    http_header(-type => 'text/plain', @no_cache);
    if ($apache_session_module eq 'Apache::Session::Counted') {
	require Apache::Session::Counted;
	# XXX make configurable, see below
	Apache::Session::CountedStore->tree_init("/tmp/bbbike-sessions-$<","1");
    }
    my_exit(0);
} else {
    choose_form();
}

undef $cgic;

REQUEST_DONE:
if ($modperl_lowmem) {
    undef $q;
    undef $g_str;
    undef $orte;
    undef $orte2;
    undef $multiorte;
    %cached_plz = ();
    undef $net;
}

my_exit 0;

sub abc_link {
    my($type, %args) = @_;

    if ($bi->{'mobile_device'}) {
	# we don't need any extras
    } elsif ($bi->{'text_browser'}) {
	# This is disabled for now --- it is too cumbersome to navigate
	# to the via and goal entry fields with this link list. Maybe just
	# provide a separate link to this link list.
	if (0) {
	    for my $ch ('A' .. 'Z') {
		print "<input type=submit name="
		    . $type . "char value=" . $ch . ">";
	    }
	    print "<br>\n";
	}
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
	_zoom_hack_init();
	print "<input type=image name=" . $type
	  . "charimg src=\"$bbbike_images/abc.gif\" class=\"charmap\" alt=\"A..Z\"";
	if ($need_zoom_hack) {
	    _zoom_hack_onclick_code();
	}
	print ">";
    }
}

sub _zoom_hack_init {
    return if defined $need_zoom_hack && !$need_zoom_hack;
    if (   $bi->is_browser_version("MSIE", 8.0)  # mit 8.0 und 10.0 getestet
	|| $bi->is_browser_version("Edge")       # XXX untested, assume same problems as with MSIE 8.0+++
       ) {
	$need_zoom_hack = 1;
    } else {
	$need_zoom_hack = 0;
	return;
    }
    print qq{<input type="hidden" id="_hack_scalefactor" name="_hack_scalefactor" value="1">};
}

sub _zoom_hack_onclick_code {
    print qq{ onclick="get_scale_factor_MSIE10('_hack_scalefactor'); return true;"};
}

sub _apply_hack_scalefactor {
    if ($hack_scalefactor) {
	my $input_param_prefix = shift;
	for my $axis ('x', 'y') {
	    my $input_param = $input_param_prefix . '.' . $axis;
	    my $val = $q->param($input_param);
	    $val /= $hack_scalefactor;
	    $q->param($input_param, $val);
	}
    }
}

sub _outer_berlin_hack {
    my($street, $bezirk) = @_;
    (my $normalized_bezirk = $bezirk) =~ s{[^A-Za-z]}{_}g;
    $normalized_bezirk = lc $normalized_bezirk;
    my $outer_berlin_file = "$tmp_dir/" . $Strassen::Util::cacheprefix . "_" . $< . "_" . $normalized_bezirk . "_strassen";
    my $outer_berlin_str = eval { Strassen->new($outer_berlin_file) };
    my $landstr0 = Strassen->new("landstrassen", NoRead => 1);
    my $plaetze0 = Strassen->new("plaetze", NoRead => 1);
    if (!$outer_berlin_str || -M $outer_berlin_file > -M $landstr0->file || -M $outer_berlin_file > -M $plaetze0->file) {
	$outer_berlin_str = Strassen->new;
	my $landstr = MultiStrassen->new("landstrassen", "plaetze");
	$landstr->init;
	while(1) {
	    my $r = $landstr->next;
	    last if !@{ $r->[Strassen::COORDS] };
	    if ($r->[Strassen::NAME] =~ /\s+\(\Q$bezirk\E\)/) {
		$outer_berlin_str->push($r);
	    }
	}
	$outer_berlin_str->write($outer_berlin_file);
    }
    my $pos = $outer_berlin_str->choose_street($street, $bezirk);
    my $name;
    if (defined $pos) {
	$name = $outer_berlin_str->get($pos)->[Strassen::NAME];
	upgrade_scope("region");
#XXX del?
# 	my $scope = $q->param("scope");
# 	if (!$scope || $scope eq "city") {
# 	    $q->param("scope", "region"); # XXX increment_scope?
# 	}
    }
    $name;
}

sub choose_form {
    my $startname = $q->param('startname') || '';
    my $start2    = $q->param('start2')    || '';
    my $start     = $q->param('start')     || '';
    my $startplz  = $q->param('startplz')  || '';
    my $starthnr  = $q->param('starthnr')  || '';
    my $startc    = $q->param('startc')    || '';
    my $startort  = $q->param('startort')  || '';

    my $vianame   = $q->param('vianame')   || '';
    my $via2      = $q->param('via2')      || '';
    my $via       = $q->param('via')       || '';
    my $viaplz    = $q->param('viaplz')    || '';
    my $viahnr    = $q->param('viahnr')    || '';
    my $viac      = $q->param('viac')      || '';
    my $viaort    = $q->param('viaort')    || '';

    my $zielname  = $q->param('zielname')  || '';
    my $ziel2     = $q->param('ziel2')     || '';
    my $ziel      = $q->param('ziel')      || '';
    my $zielplz   = $q->param('zielplz')   || '';
    my $zielhnr   = $q->param('zielhnr')   || '';
    my $zielc     = $q->param('zielc')     || '';
    my $zielort   = $q->param('zielort')   || '';

    my $nl = sub {
	if ($bi->{'can_table'}) {
	    print "<tr><td>&nbsp;</td></tr>\n";
	} else {
	    print "<p>\n";
	}
    };
    my $tbl_center_under_inputs = sub {
	my $text = shift;
	my $align = shift || "center";
	if ($bi->{'can_table'}) {
	    print "<tr><td colspan=2 align=$align>$text</td></tr>\n";
	} else {
	    print "<center>$text</center>\n";
	}
    };

    # This is needed if the user first types a street name and then
    # chooses the detailmap:
    undef $start if $startc;
    undef $via   if $viac;
    undef $ziel  if $zielc;

    # Leerzeichen am Anfang und Ende l�schen
    # �berfl�ssige Leerzeichen in der Mitte l�schen
    if (defined $start) {
	$start =~ s/^\s+//; $start =~ s/\s+$//; $start =~ s/\s{2,}/ /g;
    }	
    if (defined $via) {
	$via   =~ s/^\s+//; $via   =~ s/\s+$//; $via   =~ s/\s{2,}/ /g;
    }
    if (defined $ziel) {
	$ziel  =~ s/^\s+//; $ziel  =~ s/\s+$//; $ziel  =~ s/\s{2,}/ /g;
    }

    foreach ([\$startname, \$start2, 'start'],
	     [\$vianame,   \$via2,   'via'],
	     [\$zielname,  \$ziel2,  'ziel'],
	) {
	my  (  $nameref,    $tworef,  $type) = @$_;
	# �berpr�fen, ob eine in PLZ vorhandene Stra�e auch in
	# Strassen vorhanden ist und ggfs. $....name setzen
	if ($$nameref eq '' && $$tworef ne '') {
	    my($strasse, $bezirk, $plz) = split(/$delim/o, $$tworef);
	    warn "W�hle $type-Stra�e f�r $strasse/$bezirk (1st)\n" if $debug;
	    if ($bezirk =~ $outer_berlin_qr || $bezirk =~ $outer_berlin_subplaces_qr) {
		my $name = _outer_berlin_hack($strasse, $bezirk);
		if ($name) {
		    $$nameref = $name;
		    $q->param($type . 'plz', $plz);
		}
	    } else {
		my $str = get_streets();
		my $pos = $str->choose_street($strasse, $bezirk);
		if (!defined $pos) {
		    # Can't use upgrade_scope here:
		    if ($str->{Scope} eq 'city') {
			warn "Enlarge streets for umland\n" if $debug;
			$q->param("scope", "region");
			$str = get_streets_rebuild_dependents(); # XXX maybe wideregion too?
		    }
		    $pos = $str->choose_street($strasse, $bezirk);
		}
		if (defined $pos) {
		    $$nameref = $str->get($pos)->[0];
		    $q->param($type . 'plz', $plz);
		}
	    }
	}
    }

    # Es ist alles vorhanden, keine Notwendigkeit f�r ein Formular.
  TRY: {
	if ((defined $startname && $startname ne '') &&
	    (defined $zielname  && $zielname ne '')) {
	    last TRY if (((defined $via2 && $via2 ne '') ||
			  (defined $via  && $via  ne '' && $via ne 'NO')) &&
			 (!defined $vianame || $vianame eq ''));

	    # Previously here was a jump to search_coord() if
	    # startc+zielc was defined. Now get_kreuzung() is
	    # always called, because this is the page containing
	    # the preference form.
	    warn "W�hle Kreuzung f�r $startname und $zielname (1st)\n"
		if $debug;
	    get_kreuzung($startname, $vianame, $zielname);
	    return;
	}
    }

    my $prefer_png = 0;
    # Activate only for tested platforms
    # XXX what about Opera?
    if ($bi->{'can_dhtml'} && !$bi->{'dhtml_buggy'} &&
	$bi->{'can_javascript'} && !$bi->{'text_browser'}) {
	if (($bi->is_browser_version("Mozilla", 4.5, 4.9999) &&
	     $bi->{'user_agent_os'} =~ /(freebsd|linux|windows|winnt)/i) ||
	    $bi->is_browser_version('Firefox') ||
	    (defined $bi->{'gecko_version'} &&
	     ($bi->{'gecko_version'} >= 20020000 ||
	      $bi->{'gecko_version'} == 0))
	   ) {
	    $nice_berlinmap = $nice_abcmap = 1;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("MSIE", 5.0, 8.999999)) { # mit IE 8 getestet
	    $nice_berlinmap = $nice_abcmap = 1;
	    # png was for long time unsupported by IE, so don't set $prefer_png
	} elsif ($bi->is_browser_version("MSIE", 9.0)) { # mit 9.0 und 10.0 getestet, $nice_... geht nicht (versetzte Kacheln), sollte gefixt werden XXX
	    $nice_berlinmap = $nice_abcmap = 0;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("Edge")) { # XXX untested, assume same problems as MSIE 9.0...
	    $nice_berlinmap = $nice_abcmap = 0;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("Opera", 9.0)) { # mit 9.80 getestet
	    $nice_berlinmap = $nice_abcmap = 0; # the multiple street chooser would work, but cannot be set separately from $nice_berlinmap; XXX modern webkit-based (?) Opera versions not tested
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("Opera", 7.0, 7.9999)) { # Mit 8.x wird nur einmalig beim Enter gehighlighted
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("Konqueror", 3.0, 3.9999)) { # still broken with 3.5
	    $nice_berlinmap = $nice_abcmap = 0;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version("Safari", 2.0)) {
	    $nice_berlinmap = $nice_abcmap = 1;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version('Chrome')) {
	    $nice_berlinmap = $nice_abcmap = 1;
	    $prefer_png = 1;
	} elsif ($bi->is_browser_version('AppleWebKit')) { # probably should not appear as this, but rather as Chrome, Safari etc.
	    $nice_berlinmap = $nice_abcmap = 1;
	    $prefer_png = 1;
	}
    }

    my(@start_matches, @via_matches, @ziel_matches);
    my($start_oldname_match, $via_oldname_match, $ziel_oldname_match);
 MATCH_STREET:
    foreach ([\$startname,\$start,\$start2,\@start_matches,'start',\$startplz, $startort, \$start_oldname_match],
	     [\$vianame,  \$via,  \$via2,  \@via_matches,  'via',  \$viaplz,   $viaort,   \$via_oldname_match],
	     [\$zielname, \$ziel, \$ziel2, \@ziel_matches, 'ziel', \$zielplz,  $zielort,  \$ziel_oldname_match],
	    ) {
	my  (  $nameref,  $oneref,$tworef, $matchref,      $type,  $zipref,    $ort,      $oldname_match_ref)=@$_;
	local $^W = 0; # too many defined checks missing...

	# Darstellung eines Vias nicht erw�nscht
	next if ($type eq 'via' and $$oneref eq 'NO');

## The idea behind this block: if only the place was selected (without
## a particular street), then choose the center of the place.
## Unfortunately this breaks currently the "Zur�ck zum
## Eingabeformular" from a abc page, so it's commented out currently.
## XXX
# 	if ($$nameref eq '' && $$oneref eq '' && defined $ort && $ort =~ $outer_berlin_qr) {
# 	    my $orte = get_orte();
# 	    my $coords;
# 	    eval {
# 		$orte->grepstreets(sub {
# 				       my($name) = $_->[Strassen::NAME] =~ m{^([^|]+)};
# 				       if ($name eq $ort) {
# 					   $coords = $_->[Strassen::COORDS][0];
# 					   die "break loop";
# 				       }
# 				   });
# 	    };
# 	    if ($coords) {
# 		$q->param($type.'c', $coords);
# 		$$nameref = $ort;
# 		next;
# 	    }
# 	}

	# �berpr�fen, ob eine Stra�e in PLZ vorhanden ist.
	if ($$nameref eq '' && $$oneref ne '') {
	    my $plz_scope = (defined $ort && $ort =~ $outer_berlin_qr ? $ort : "Berlin/Potsdam");
	    my $plz_obj = init_plz(scope => $plz_scope);
	    if (!$plz_obj) {
		# Notbehelf. PLZ sollte m�glichst installiert sein.
		my $str = get_streets();
		my @res = $str->agrep($$oneref);
		if (@res) {
		    $$nameref = $res[0];
		}
		next;
	    }

	    warn "Suche $$oneref in der PLZ-DB.\n" if $debug;

	    # check for given crossings
	    my $crossing_street;
	    # XXX is it OK to change the referred value?
	    ($$oneref, $crossing_street) = Strasse::split_crossing($$oneref);

	    my @extra;
	    if ($$zipref ne '') {
		push @extra, Citypart => [ split /\s*,\s*/, $$zipref ];
	    }
	    next if $$oneref =~ /^\s*$/;
	    $$oneref = PLZ::norm_street($$oneref);
	    my @look_loop_args = (PLZ::split_street($$oneref),
				  @extra,
				  Max => $max_plz_streets,
				  MultiZIP => 1, # introduced because of Hauptstr./Friedenau vs. Hauptstr./Sch�neberg problem
				  MultiCitypart => 1, # works good with the new combine method
				  Agrep => 'default',
				  AsObjects => 1,
				 );
	    #warn "\$plz_obj->look_loop(@look_loop_args)\n";
	    my($retref, $matcherr) = $plz_obj->look_loop(@look_loop_args);
	    #require Data::Dumper; warn Data::Dumper->new([$retref, $matcherr],[qw()])->Indent(1)->Useqq(1)->Dump;

	    @$matchref = grep { my $coord = $_->get_coord; defined $coord && length $coord } @$retref;
	    @$matchref = map { $_->combined_elem_to_string_form } $plz_obj->combine(@$matchref);
	    {
		my %seen;
		@$matchref = grep {
		    my $file_index = $_->get_field('i');
		    $file_index = '' if !defined $file_index;
		    if ($same_single_point_optimization{$file_index}) {
			my $coord = $_->get_coord;
			if ($seen{$coord}) {
			    0;
			} else {
			    $seen{$coord}++;
			    1;
			}
		    } else {
			1;
		    }
		} @$matchref;
	    }
	    if (@$matchref == 0 && $plz_scope eq 'Berlin/Potsdam') {
		# Nichts gefunden. In folgenden Dateien nachschauen (aber nur f�r Berlin/Potsdam)
		#   Pl�tze-Datei
		#   Strassen-Datei (weil einige Stra�en nicht in der PLZ-Datei stehen)
		#
		for my $def (
			     [sub { Strassen->new("plaetze") }, "Pl�tze-Datei"],
			     [sub { get_streets() }, "Stra�en-Datei"],
			    ) {
		    my($producer, $label) = @$def;
		    if (my $str = $producer->()) {
			warn "Suche $$oneref in der $label.\n" if $debug;
			my @res = $str->agrep($$oneref);
			if (@res) {
			    my @matches;
			    for my $res (@res) {
				my $ret = $str->get_by_name($res);
				if ($ret) {
				    my($street, $citypart) = Strasse::split_street_citypart($res);
				    push @matches, $plz_obj->make_result([$street, $citypart, undef, $ret->[1][0]]);
				}
			    }
			    if (@matches == 1) {
				$$nameref = $matches[0]->get_name;
				$q->param($type . 'c', $matches[0]->get_coord);
			    } else {
				@$matchref = @matches;
			    }

			    if (@matches) {
				last;
			    }
			}
		    }
		}

		next MATCH_STREET;
	    }

	    # If this is a crossing, then get the exact point, but don't fail
	    if (defined $crossing_street) {
		# first: get all matching Strasse objects (first part)
		my $rx = "^(" . join("|", map { quotemeta($_->get_name) } @$matchref) . ")";
		my $str = get_streets();
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
					$$nameref = Strasse::nice_crossing_name(@{$crossings->{$c}});
					$q->param($type . 'c', $c);
					next MATCH_STREET;
				    }
				}
			    }
			}
		    }
		}
	    }

	    if ($multiorte) {
		my @orte = $multiorte->agrep($$oneref, Agrep => $matcherr);
		if (@orte) {
		    use constant MATCHREF_ISORT_INDEX => 5;
		    push @$matchref, map { [$_, undef, undef, undef, undef, 1] } @orte;
		}
	    }

	    if (@$matchref == 1
		&& $plz_scope eq 'Berlin/Potsdam' # important: %is_usable_without_strassen only valid for Berlin/Potsdam!
		&& do {
		     my $first_rec_file_index = $matchref->[0]->get_field("i");
		     $first_rec_file_index = '' if !defined $first_rec_file_index;
		     $is_usable_without_strassen{$first_rec_file_index}
		 }
	       ) {
		$$nameref = $matchref->[0]->get_name;
		$$tworef = _match_to_cgival($matchref->[0]);
		$q->param($type . 'c', $matchref->[0]->get_coord);
	    } elsif (@$matchref == 1) {
		my $match = $matchref->[0];
		my $matchtype = $match->get_field('type') || '';
		if ($matchtype eq 'oldname') {
		    $$oldname_match_ref = $match;
		    $match = _oldname_to_newname($match);
		}
		my($strasse, $bezirk) = ($match->get_name,
					 $match->get_citypart);
		warn "W�hle $type-Stra�e f�r $strasse/$bezirk (2nd)\n"
		    if $debug;
		if ($bezirk =~ $outer_berlin_subplaces_qr) {
		    my $name = _outer_berlin_hack($strasse, $bezirk);
		    if ($name) {
			$$nameref = $name;
			$q->param($type . 'plz', $match->get_zip);
		    } else {
			$$tworef = _match_to_cgival($match);
		    }
		} else {
		    my $str = get_streets();
		    my $pos = $str->choose_street($strasse, $bezirk);
		    if (!defined $pos) {
			# Can't use upgrade_scope here
			if ($str->{Scope} eq 'city') {
			    warn "Enlarge streets for umland\n" if $debug;
			    $q->param("scope", "region");
			    $str = get_streets_rebuild_dependents(); # XXX maybe wideregion too?
			}
			$pos = $str->choose_street($strasse, $bezirk);
		    }
		    if (defined $pos) {
			$$nameref = $str->get($pos)->[0];
			$q->param($type . 'plz', $match->get_zip);
		    } else {
			$$tworef = _match_to_cgival($match);
		    }
		}
	    }
	}
    }

    # Es ist alles vorhanden, keine Notwendigkeit f�r ein Formular.
  TRY: {
	if ($startname ne '' && $zielname ne '') {
	    last TRY if (((defined $via2 && $via2 ne '') ||
			  (defined $via  && $via  ne '')) &&
			 (!defined $vianame || $vianame eq ''));
	    warn "W�hle Kreuzung f�r $startname und $zielname (2nd)\n"
	      if $debug;
	    get_kreuzung($startname, $vianame, $zielname, $start_oldname_match, $via_oldname_match, $ziel_oldname_match);
	    return;
	}
    }

    my %header_args = @weak_cache;
    $header_args{-expires} = '+1d';
    http_header(%header_args);
    my @extra_headers;

    if ($bi->{'can_javascript'}) {
	my $onloadscript = "";
	if ($nice_berlinmap || $nice_abcmap) {
	    $onloadscript .= "init_hi(); window.onresize = init_hi; "
	}
	$onloadscript .= "focus_first(); ";
	if (!$bi->{'geolocation.secure_context_required'} || $is_secure) {
	    $onloadscript .= "check_locate_me(); ";
	}
	push @extra_headers, -onLoad => $onloadscript,
	    -script => [{-src => $bbbike_html . "/bbbike_start.js?v=$bbbike_start_js_version"},
			($nice_berlinmap
			 ? {-code => qq{set_bbbike_images_dir('$bbbike_images')}}
			 : ()
			),
		       ];
    }

    my $show_introduction;
    {
	local $^W = 0;
	$show_introduction = ($start eq ''  && $ziel eq '' &&
			      $start2 eq '' && $ziel2 eq '' &&
			      $startname eq '' && $zielname eq '' &&
			      $startc eq '' && $zielc eq '' &&
			      !$smallform &&
			      !$warn_message);
    }
    header(@extra_headers, -from => $show_introduction ? "chooseform-start" : "chooseform");

    print <<EOF if ($bi->{'can_table'});
<table>
<tr>
EOF

    if ($show_introduction) {
	load_teaser();
	# use "make count-streets" in ../data
	print <<EOF if ($bi->{'can_table'});
<td valign="top">@{[ blind_image(420,1) ]}<br>
EOF
	# Eine Addition aller aktuellen Stra�en, die bei luise-berlin
	# aufgef�hrt sind, ergibt als Summe 10129
	# Da aber auch einige "unoffizielle" Wege in der DB sind, d�rften es an die 11000 werden
	# ---> es sind aber mehr als 11000. Am besten, ich lasse $all_bln_str weg...
        # ---> es sind doch weniger als 11000, ich runde aber trotzdem auf
	my($bln_str, $pdm_str) = (11000, 550);
	# XXX Use format number to get a comma in between.
	if ($lang eq 'en') {
	    print <<EOF;
This is a route planner for cyclists in Berlin.
More than $bln_str streets in Berlin are available for searching, also
$pdm_str streets in Potsdam.
<b>Please do not enter street numbers or postal codes.</b>
EOF
	} else {
	    print <<EOF;
Dieses Programm sucht (Fahrrad-)Routen in Berlin.
Es sind ca. $bln_str Berliner Stra&szlig;en
sowie ca. $pdm_str Potsdamer Stra&szlig;en erfasst.
<b>Stra�en bitte ohne Hausnummern oder Postleitzahlen eingeben.</b>
EOF
	}
	print "<br><br>";
	print <<EOF if ($bi->{'can_table'});
</td>
<td rowspan="3" valign="top" @{[ $start_bgcolor ? "bgcolor=$start_bgcolor" : "" ]}>@{[ defined &teaser && !$bi->{'css_buggy'} ? teaser() : "" ]}</td>
</tr><tr>
EOF

	print "<td>" if ($bi->{'can_table'});

        if ($bi->{'text_browser'}) {
	    if ($lang eq 'en') {
		print "Choose ";
	    }
            printf q{<a name="navig"></a><a href="#start">%s</a>}, M("Start-");
            unless ($via eq 'NO') {
		printf q{, <a href="#via">%s</a> }, M("Via- (optional)");
	    }
	    if (defined $lang && $lang eq 'en') {
		print <<EOF;
and <a href="#ziel">Destination street</a>
and then <a href="#weiter">go on</a>:<p>
EOF
	    } else {
		print <<EOF;
und <a href="#ziel">Zielstra&szlig;e</a>
der Route ausw&auml;hlen und dann <a href="#weiter">weiter</a>:<p>
EOF
	    }
        } else {
	    if ($nice_berlinmap) {
		print "<noscript>" . M("Die Aktivierung von Javascript und CSS ist empfehlenswert, aber nicht notwendig.") . "<p></noscript>\n";
	    }
            print "&nbsp;" . M("Start- und Zielstra&szlig;e der Route ausw&auml;hlen");
	    unless ($via eq 'NO') { print " (" . M("Via ist optional") . ")" }
	    print ": <p>\n";
        }

	print "</td></tr><tr>" if ($bi->{'can_table'});

    }

    if ($warn_message) {
	print "<div class='error'>".CGI::escapeHTML($warn_message)."</div>\n";
    }

    print "<td>" if ($bi->{'can_table'});
    print "<form action=\"$bbbike_script\" name=BBBikeForm>\n";

    # Hack for browsers which use the first button, regardless whether it's
    # image or button, for firing in a <Return> event
    # XXX Does not work for Opera; Safari, Chrome, MSIE, Edge and modern Opera are untested...
    if ($bi->{user_agent_name} =~ /^(konqueror|safari|chrome|opera|msie|edge)/i) {
	print <<EOF;
<input type="submit" value="@{[ M("Weiter") ]}" style="text-align:center;visibility:hidden"/>
EOF
    }

    print "<table id=inputtable>\n" if ($bi->{'can_table'});

    my $shown_unknown_street_helper = 0;

    foreach
      ([\$startname, \$start, \$start2, \@start_matches, 'start',
	$start_bgcolor, \$startort, \$start_oldname_match],
       [\$vianame,   \$via,   \$via2,   \@via_matches,   'via',
	$via_bgcolor,   \$viaort,   \$via_oldname_match],
       [\$zielname,  \$ziel,  \$ziel2,  \@ziel_matches,  'ziel',
	$ziel_bgcolor,  \$zielort,  \$ziel_oldname_match]) {
	my($nameref,  $oneref, $tworef,  $matchref,       $type,
	   $bgcolor,    $ortref,    $oldname_match_ref) = @$_;
	my $bgcolor_s = $bgcolor ne '' ? "bgcolor=$bgcolor" : '';
	my $coord     = $q->param($type . "c");
	my $has_init_map_js;

	# Darstellung eines Vias nicht erw�nscht
	if ($type eq 'via' and $$oneref eq 'NO') {
	    print "<input type=hidden name=via value=NO>";
	    next;
	}

	my $printtype = ucfirst($type);
	my $imagetype = "$bbbike_images/" . M($type) . "." . ($prefer_png ? "png" : "gif");
	my $tryempty  = 0;
	my $no_td     = 0;

	if ($bi->{'can_table'}) {
	    print qq{<tr id=${type}tr $bgcolor_s><td align=center valign=middle width=40><a name="$type"><img } . (!$bi->{'css_buggy'} ? qq{style="padding-bottom:8px;" } : "") . qq{src="$imagetype" border=0 alt="} . M($printtype) . qq{"></a></td>};
	} else {
	    print "<a name=\"$type\"><b>" . M($printtype) . "</b></a>: ";
	}
	if ((defined $$nameref and $$nameref ne '') ||
	    (defined $coord and $coord ne '')) {
	    print "<td valign=middle>" if $bi->{'can_table'};
	    if (defined $coord) {
		print qq{<input type=hidden name=${type}c value="@{[ CGI::escapeHTML($coord) ]}">\n};
	    }
	    if ($q->param($type . "isort")) {
		print qq{<input type=hidden name=${type}isort value=1>};
	    }
	    if (defined $coord and (!defined $$nameref or $$nameref eq '')) {
		print CGI::escapeHTML(crossing_text($coord));
	    } else {
		print "$$nameref";
		if ($$oldname_match_ref) {
		    print _display_oldname($$oldname_match_ref);
		}
		if ($$ortref &&
		    index(reverse($$nameref), reverse("$$ortref)")) != 0 # this means: $$ortref is not at the end of $$nameref (but this seems always the case in bbbike.de/beta)
		   ) {
		    print " (" . CGI::escapeHTML($$ortref) . ") ";
		}
		print "\n";
	    }
	    print qq{<input type=hidden name=${type}name value="@{[ CGI::escapeHTML($$nameref) ]}">\n};
	    if ($$ortref) {
		print qq{"<input type=hidden name=${type}ort value="@{[ CGI::escapeHTML($$ortref) ]}">\n};
	    }
	    if (defined $q->param($type . "plz")) {
		print qq{<input type=hidden name=${type}plz value="@{[ CGI::escapeHTML(scalar $q->param($type . "plz")) ]}">\n};
	    }
	    if (defined $q->param($type . "hnr")) {
		print qq{<input type=hidden name=${type}hnr value="@{[ CGI::escapeHTML(scalar $q->param($type . "hnr")) ]}">\n};
	    }

	    print "</td>\n" if $bi->{'can_table'};

	    if ($nice_berlinmap && $bi->{'can_table'}) {
		print "<td>";
		if (!@$matchref) { # XXX why?
		    require PLZ;
		    $matchref = [ PLZ->new->make_result([$$nameref, undef, undef, $coord]) ];
		}
		berlinmap_with_choices($type, $matchref);
		$has_init_map_js++;
		print "</td>";
	    }

	} elsif ($$oneref ne '' && @$matchref == 0) {
	    print "<td>" if $bi->{'can_table'};
	    print "<i>" . CGI::escapeHTML($$oneref) . "</i> ";
	    if ($$ortref && $$ortref ne 'Berlin/Potsdam') {
		print "in <i>" . CGI::escapeHTML($$ortref) . "</i> ";
	    }
	    print M("ist nicht bekannt") . ".<br>\n";
	    my $geo = get_geography_object();
	    if (!$geo || !$geo->is_osm_source) {
		if (!$shown_unknown_street_helper) {
		    # Check if the given streetname is completely
		    # unusable and very unlikely to contain a new
		    # street.
		    my $is_maybe_usable = ($$oneref !~ m{\b\d{5}\b} # keine PLZ
					   && $$oneref !~ m{\b(?:Berlin|Potsdam)\b}i
					   && $$oneref !~ m{,}
					  );
		    if ($lang eq 'en') {
			print <<EOF;
<p>
Checklist:
<ul>
<li>Check the correct spelling of the street name.
<li>Do not use house numbers, postcodes, place and suburb names!
<li>The BBBike database only contains streets from Berlin and Potsdam.
<li>Only most important Berlin sights are available through this interface.
</ul>
<p>
EOF
			if ($is_maybe_usable) {
			    print <<EOF;
<p>
Nothing applies? Then use the email link below and contribute information
for this street.
</p>
EOF
			}
		    } else {
			print <<EOF;
<p>
Checkliste:
<ul>
<li>Wurde der Stra�enname richtig geschrieben?
<li>Hausnummern, Bezirksnamen, Postleitzahlen und Ortsnamen d�rfen nicht angegeben werden!
<li>In der Datenbank befinden sich nur Berliner und Potsdamer Stra�en!
<li>Nur die wichtigsten Berliner Sehensw�rdigkeiten k�nnen verwendet werden.
</ul>
</p>
EOF
			if ($is_maybe_usable) {
			    print <<EOF;
<p>
Ansonsten: Informationen zu dieser Stra�e �ber den E-Mail-Link unten melden.
</p>
EOF
			}
		    }
		    $shown_unknown_street_helper = 1;
		}

		if (0) {
		    # Don't show anymore the newstreetform link in
		    # this situation, too many false entries. The user
		    # can use the contact link if he thinks otherwise.

		    my $qs = CGI->new({strname => $$oneref,
				       ($$ortref ? (ort => $$ortref) : ()),
				      })->query_string;
		    print qq{<a target="newstreetform" href="$bbbike_html/newstreetform${newstreetform_encoding}.html?$qs">} . M("Diese Stra�e neu in die BBBike-Datenbank eintragen") . qq{</a><br><br>\n};
		    print M(qq{Oder einen anderen Stra�ennamen versuchen}) . qq{:<br>\n};
		} else {
		    #warn "*** Avoid unusable newstreetform mail for <$$oneref>\n";
		    print M(qq{Einen anderen Stra�ennamen versuchen}) . qq{:<br>\n};
		}
	    } else {
		print M(qq{Einen anderen Stra�ennamen versuchen}) . qq{:<br>\n};
	    }
	    $no_td = 1;
	    $tryempty = 1;
	} elsif ($$tworef ne '') {
	    my($strasse, $bezirk, $plz, $xy, $index) = split(/$delim/o, $$tworef);
	    if ($bezirk =~ m{^Potsdam(?:-|$)}) { # XXX or use better $outer_berlin_qr + $outer_berlin_subplaces_qr?
		upgrade_scope("region");
		get_streets_rebuild_dependents();
	    }
	    print "<td>" if $bi->{'can_table'};
	    if (defined $xy && $xy !~ /^\s*$/) {
		new_kreuzungen();
		my($best) = get_nearest_crossing_coords(split(/,/, $xy));
		my $cr = crossing_text(defined $best ? $best : $xy);
		my $qs = CGI->new({strname => $strasse,
				   bezirk => $bezirk,
				   plz => $plz,
				   coord => $xy,
				  })->query_string;
		my $report_nearest = _is_real_street($strasse) && !$is_usable_without_strassen{$index||""};
		if ($report_nearest) {
		    print qq{<i>$strasse</i> } . M("ist nicht bekannt") . qq{ (<a target="newstreetform" href="$bbbike_html/newstreetform${newstreetform_encoding}.html?$qs">} . M("diese Stra�e eintragen") . qq{</a>).<br>\n};
		} else {
		    print qq{<i>$strasse</i><br>\n};
		}
		print M("Die n�chste") . " " . ($report_nearest ? M("bekannte") . " " : "") . M("Kreuzung ist") . qq{:<br>\n};
		print '<i>' . coord_or_stadtplan_link($cr, defined $best ? $best : $xy, $plz) . '</i>';
		if ($report_nearest) {
		    print qq{<br>\n} . M("und wird f�r die Suche verwendet") . ".";
		}
		print qq{<br>\n};
		print qq{<input type=hidden name=${type}c value="@{[ CGI::escapeHTML($best) ]}">};
		print qq{<input type=hidden name=${type}name value="@{[ CGI::escapeHTML($cr) ]}">};
	    } else {
		choose_street_html($strasse,
				   $plz,
				   $type);
	    }
	    print "</td>" if $bi->{'can_table'};
	    # show point in the overview map, too
	    if ($nice_berlinmap && $bi->{'can_table'}) {
		print "<td>";
		if (!@$matchref) { # XXX why?
		    require PLZ;
		    $matchref = [ PLZ->new->make_result([$strasse, $bezirk, $plz, $xy])];
		}
		berlinmap_with_choices($type, $matchref);
		$has_init_map_js++;
		print "</td>";
	    }
	} elsif (@$matchref == 1) {
# XXX wann kommt man hierher?
	    print "<td>" if $bi->{'can_table'};
	    choose_street_html($matchref->[0][0],
			       $matchref->[0][2],
			       $type);
	    print "</td>" if $bi->{'can_table'};
	} elsif (@$matchref > 1) {
	    print "<td>" if $bi->{'can_table'};
	    if ($lang eq 'en') {
		print "Choose exact <b>" . M("${printtype}stra&szlig;e") . "</b>:<br>\n";
	    } else {
		print "Genaue <b>" . M("${printtype}stra&szlig;e") . "</b> ausw&auml;hlen:<br>\n";
	    }

	    # Sort Potsdam streets to the end:
	    @$matchref = map { $_->[1] } sort {
		if ($a->[0] =~ m{^Potsdam} && $b->[0] !~ m{^Potsdam}) {
		    return +1;
		} elsif ($a->[0] !~ m{^Potsdam} && $b->[0] =~ m{^Potsdam}) {
		    return -1;
		} else {
		    return 0;
		}
	    } map { [$_->get_citypart, $_ ] } @$matchref;

	    my $s;
	    my $checked = 0;
	    my $out_i = 0;
	    foreach $s (@$matchref) {
		last if ++$out_i > $max_matches;
		my $strasse2val;
		my $is_oldname = ($s->get_field('type')||'') eq 'oldname';
		my $oldname_s;
		my $is_ort = 0; # XXX currently very probably broken --- $s->[MATCHREF_ISORT_INDEX];
		print "<label><input";
		if ($nice_berlinmap) {
		    print " onclick='set_street_in_berlinmap(\"$type\", $out_i);'";
		}
		print " type=radio name=" . $type . "2";
		if ($is_ort && $multiorte) {
		    my($ret) = $multiorte->get_by_name($s->get_name);
		    my $xy;
		    if ($ret) {
			$xy = $ret->[1][0];
		    }
		    $strasse2val = join($delim, $s->get_name, "#ort", $xy);
		    $s->[0] =~ s/\|/ /; # Zusatzbezeichnung von Orten
		} else {
		    if ($is_oldname) {
			$oldname_s = $s;
			$s = _oldname_to_newname($s);
		    }
		    $strasse2val = _match_to_cgival($s);
		}
		print " value=\"$strasse2val\"";
		if (!$checked) {
		    print " checked";
		    $checked++;
		}
		print "> " . $s->get_name;
		if ($oldname_s) {
		    print _display_oldname($oldname_s);
		}
		if ((defined $s->get_citypart && $s->get_citypart ne "") ||
		    (defined $s->get_zip && $s->get_zip ne "")) {
		    my @cp;
		    for ('citypart', 'zip') {
			my $method = 'get_' . $_;
			push @cp, $s->$method if (defined $s->$method && $s->$method ne "");
		    }
		    print " (<span style='font-size:smaller;'>" . join(", ", @cp) . "</span>)";
		}
		print "</label>";
		print "<br>\n";
	    }

	    if (defined $q->param($type . "hnr")) {
		print qq{<input type=hidden name=${type}hnr value="@{[ CGI::escapeHTML(scalar $q->param($type . "hnr")) ]}">\n};
	    }

	    if ($bi->{'can_table'}) {
		print "</td><td>";

		# show choices in the overview map, too
		if ($nice_berlinmap) {
		    berlinmap_with_choices($type, $matchref);
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
	    if ($include_outer_region) {
		print <<EOF;
 <select name="${type}ort">
  <option value="">Berlin/Potsdam</option>
EOF
		for my $place (sort @outer_berlin_places) {
		    next if $place eq 'Potsdam'; # special case, Potsdam dualism
		    my $selectedhtml = defined $$ortref && $place eq $$ortref ? ' selected' : '';
		    print <<EOF;
  <option value="$place"$selectedhtml>$place</option>
EOF
		}
		print <<EOF;
 </select>
EOF
	    }
	    print "<br>";
	    if (!$smallform) {
		abc_link($type, -nice => 1);

		# XXX not translated
		if ($use_special_destinations) {
		    if ($type eq 'via') {
			print "<br>";
			print qq{<select $bi->{hfill} name="${type}special">
<option value="">oder ...
<option value="viabikeshop">Fahrradladen auf der Strecke
<option value="viabankomat">Geldautomat auf der Strecke
<option value="">Stra�e
</select>
};
		    } elsif ($type eq 'ziel') {
			print "<br>";
			print qq{<select $bi->{hfill} name="${type}special">
<option value="">oder ...
<option value="nextbikeshop">n�chster Fahrradladen
<option value="nextbankomat">n�chster Geldautomat
<option value="">Stra�e
</select>
};
		    }
		}
	    }

	    if ($type eq 'start' && $bi->{'can_css'}) {
		my $transpose_dot_func = "transpose_dot_func = " . overview_map()->{TransposeJS};
		print <<EOF;
<div id="locateme" style="visibility:hidden;">
  <a href="javascript:locate_me()">@{[ M("Aktuelle Position verwenden") ]}</a>
  <img id="locateme_wait" src="$bbbike_images/loading.gif" alt="" style="visibility:hidden;">
EOF
		print help_link('geolocation');
		print <<EOF;
</div>
<div id="locateme_marker" style="position:absolute; visibility:hidden;"><img src="$bbbike_images/bluedot.png" alt="" border=0 width=8 height=8></div>
<script type="text/javascript"><!--
 $transpose_dot_func
// --></script>
<input type=hidden name="startc">
<input type=hidden name="scvf">
EOF
	    }

	    if (!$smallform) {
		print "</td><td>" if $bi->{'can_table'};
		if ($nice_berlinmap && !$no_berlinmap) {
		    print <<"EOF";
<input type=hidden name="${type}mapimg.x" value="">
<input type=hidden name="${type}mapimg.y" value="">
<div id=${type}mapbelow style="position:relative;visibility:hidden;">
 <img src="$bbbike_images/berlin_small$berlin_small_suffix.gif" border=0 width=$berlin_small_width height=$berlin_small_height alt="">
</div>
<div id=${type}mapabove style="position:absolute;visibility:hidden;">
 <img src="$bbbike_images/berlin_small_hi$berlin_small_suffix.gif" border=0 width=$berlin_small_width height=$berlin_small_height alt="">
</div>

<script type="text/javascript"><!--
function $ {type}map_init() { return any_init("${type}map"); }
function $ {type}map_highlight(Evt) { return any_highlight("${type}map", Evt); }
function $ {type}map_byebye(Evt) { return any_byebye("${type}map", Evt); }
function $ {type}map_detail(Evt) { return any_detail("${type}map", Evt); }
// --></script>
EOF
		} elsif (!$bi->{'text_browser'} && !$no_berlinmap) {
		    _zoom_hack_init();
		    print "<input type=image name=" . $type
		      . "mapimg src=\"$bbbike_images/berlin_small$berlin_small_suffix.gif\" class=\"citymap\" style=\"width:${berlin_small_width}px; height:${berlin_small_height}px\" alt=\"\"";
		    if ($need_zoom_hack) {
			_zoom_hack_onclick_code();
		    }
		    print ">";
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
	    $button_str .= qq{<input type=button value="&lt;&lt; } . M("Zur�ck") . qq{" onclick="history.back(1);">&nbsp;&nbsp;};
	}
	$button_str .= qq{<a name="weiter"><input};
	if ($nice_berlinmap || $nice_abcmap) {
	    $button_str .= qq{ onclick='cleanup_special_click()'};
	}
	$button_str .= qq{ type=submit value="} . M("Weiter") . qq{ &gt;&gt;"></a>};
	$tbl_center_under_inputs->($button_str);
    }

    print "</table>\n" if $bi->{'can_table'};

    print qq{<input type=hidden name=scope value="@{[ (defined $q->param("scope") ? CGI::escapeHTML(scalar $q->param("scope")) : "") ]}">};

    print "</form>\n";
    print "</td></tr></table>\n" if $bi->{'can_table'};

    print "<hr>";

    if (!$smallform) {
	my $cityname;
	my $list_all_size;
	my $geo = get_geography_object();
	if ($geo) {
	    if ($geo->can("cityname")) {
		$cityname = $geo->cityname;
		if ($cityname eq 'Berlin') {
		    # special case:
		    $cityname = "Berlin " . M("und") . " Potsdam";
		}
	    }
	    if ($geo->can("cgi_list_all_size")) {
		$list_all_size = $geo->cgi_list_all_size;
	    }
	}
	print q{<div style="text-align:right;">};
	print window_open("$bbbike_script?all=1", "BBBikeAll",
			  "dependent,height=500,resizable," .
			  "screenX=500,screenY=30,scrollbars,width=250")
	    . M("Liste aller bekannten Stra&szlig;en") . ($cityname ? " " . M("in") . " " . $cityname : "") ."</a>" .
		($list_all_size ? " $list_all_size" : '');
	print q{</div>};
	print "<hr>";
    }

    print footer_as_string();

    print $q->end_html;
}

sub berlinmap_with_choices {
    return if $no_berlinmap;

    my($type, $matchref) = @_;
    print "<div id=${type}mapbelow style=\"position:relative;visibility:hidden;\">";
    print "<img src=\"$bbbike_images/berlin_small$berlin_small_suffix.gif\" border=0 width=$berlin_small_width height=$berlin_small_height alt=\"\">";
    print "</div>";

    my $js = "";
    my $match_nr = 0;

    my $out_i = 0;
    foreach my $s (@$matchref) {
	last if ++$out_i > $max_matches;
	$match_nr++;
 	next if $s->get_field('isort'); # XXX was [MATCHREF_ISORT_INDEX];
	my $xy = $s->get_coord;
	next if !defined $xy;
	my($tx,$ty) = map { int $_ } overview_map()->{Transpose}->(split /,/, $xy);
	$tx -= 4; $ty -= 4; # center reddot.gif
	my $divid = $type . "match" . $match_nr;
	my $matchimgid = $type . "matchimg" . $match_nr;
	my($a_start, $a_end) = ("", "");
	if (@$matchref > 1) {
	    $a_start = <<EOF;
<a href="#" onclick="return set_street_from_berlinmap('${type}', $match_nr);">
EOF
	    $a_end   = "</a>";
	}
	my $alt = ($s->get_name||"") . "(" . ($s->get_citypart||"") . ")";
	print <<EOF;
<div id="$divid" style="position:absolute; visibility:visible;">$a_start<img id="$matchimgid" src="$bbbike_images/bluedot.png" border=0 width=8 height=8 alt="$alt">$a_end</div>
EOF
	$js .= "pos_rel(\"$divid\", \"${type}mapbelow\", $tx, $ty);\nvis(\"$divid\", \"show\");\n";
    }

    print <<EOF;
<script type="text/javascript"><!--
function $ {type}map_init() {
  vis("${type}mapbelow", "show");
  $js
  set_street_in_berlinmap("$type", 1);
}
// --></script>
EOF
}

sub choose_ch_form {
    my($search_char, $search_type, $search_ort) = @_;
    my $use_javascript = ($bi->{'can_javascript'} &&
			  !$bi->{'javascript_incomplete'});
    my $printtype = ucfirst($search_type);
    my $per_char_filtering = 0;
    if (!defined $search_ort || ($search_ort eq '' || $search_ort eq 'Berlin/Potsdam')) {
	undef $search_ort;
	$per_char_filtering = 1;
    }

    http_header(@weak_cache);
    header();

    print "<b>" . M($printtype) . "</b>";
    if ($per_char_filtering) {
	print " (" . M("Anfangsbuchstabe") . " <b>$search_char</b>)";
    }
    print "<br>\n";

    print "<form action=\"$bbbike_script\" name=Charform>\n";
    if (!$use_javascript) {
	print qq{<input type=submit value="} . M("Weiter") . qq{ &gt;&gt;"><br>};
    }
    for my $key ($q->param) {
	unless ($key eq 'startchar' || $key eq 'viachar' || $key eq 'zielchar' || $key eq $search_type) {
	    # Lynx-Bug (oder Feature?): hidden-Variable werden nicht von
	    # der nachfolgenden Radio-Liste �berschrieben
	    next if ($key =~ /^$search_type/);
	    print qq{<input type=hidden name="@{[ CGI::escapeHTML($key) ]}" value="@{[ CGI::escapeHTML(scalar $q->param($key)) ]}">\n};
	}
    }

    my $regex_char = "^" . ($search_char eq 'A'
			    ? '[A�]'
			    : ($search_char eq 'O'
			       ? '[O�]'
			       : ($search_char eq 'U'
				  ? '[U�]'
				  : $search_char)));
    my @strlist;
    if (defined $search_ort) {
	# Pick streets outside of Berlin/Potsdam. Show whole list, do
	# not filter by $search_char
	eval {
	    my $landstr = MultiStrassen->new('landstrassen', 'landstrassen2');
	    $landstr->init;
	    eval q{ # eval wegen /o
	    while(1) {
		my $ret = $landstr->next;
	        last if !@{$ret->[1]};
	        my $name = $ret->[0];
		next if $name !~ s{\s+\(
				     \Q$search_ort\E # search for the place
				     (?:     # without any subparts
                                      |-(.*) # or with a subpart
				     )
				   \)}{}ox;
		my $longname = defined $1 ? "$name ($1)" : undef;
		if (defined $longname) {
		    # remove Bundesstra�en name in the long name
		    $longname =~ s{\s+\(B\d+\)}{};
		}
		push @strlist, defined $longname ? { short => $name, long => $longname } : $name;
	    }
	};
	};
	warn $@ if $@;
    } else {
	{
	    # Pick streets in Berlin (or the main city) only, filtered
	    # by $search_char
	    my $str = get_streets();
	    $str->init;
	    eval q{ # eval wegen /o
	    while(1) {
	        my $ret = $str->next;
	        last if !@{$ret->[1]};
	        my $name = $ret->[0];
	        push @strlist, $name if $name =~ /$regex_char/oi;
	    }
        };
	}
	eval {
	    # Include Potsdam streets
	    # XXX Special case, look for another solution in other cities!
	    my $landstr = Strassen->new("landstrassen");
	    $landstr->init;
	    eval q{ # eval wegen /o
	    while(1) {
		my $ret = $landstr->next;
	        last if !@{$ret->[1]};
	        my $name = $ret->[0];
		next if $name !~ m{\(Potsdam(?:-.*?)?\)};
		if ($name =~ /$regex_char/oi) {
		    # remove Bundesstra�en name here:
		    $name =~ s{\s+\(B\d+\)}{};
		    push @strlist, $name;
		}
	    }
	};
	};
	warn $@ if $@;
    }

    @strlist =
	map { $_->[1] }
	    sort { $a->[0] cmp $b->[0] }
		map { [BBBikeUtil::german_locale_xfrm(ref $_ ? $_->{short} : $_), $_] }
		    @strlist;

    print
      "<label><input type=radio name=" . $search_type . "name value=\"\"" ,
      ($use_javascript ? " onclick=\"document.Charform.submit()\"" : ""),
      "> ",
      ($use_javascript ? "(" . M("Zur�ck zum Eingabeformular") . ")" : "(" . M("nicht gesetzt") . ")"),
      "</label><br>\n";

    my $seen_anchor;
    my $last_name;
    for(my $i = 0; $i <= $#strlist; $i++) {
	my $name = $strlist[$i];
	my $longname;
	if (ref $name) {
	    ($name, $longname) = @{$name}{qw(short long)};
	}
	if (defined $last_name and $name eq $last_name) {
	    next;
	} else {
	    $last_name = $name;
	}
	my $html_name = BBBikeCGI::Util::my_escapeHTML($name);
	my $html_longname;
	if (defined $longname) {
	    $html_longname = BBBikeCGI::Util::my_escapeHTML($longname);
	}	    
	if (!$per_char_filtering && !$seen_anchor && uc(substr($name,0,1)) ge $search_char) {
	    print '<a name="start"></a>';
	    $seen_anchor++;
	}
	print
	  "<label><input type=radio name=" . $search_type . "name value=\"$html_name\"",
	  ($use_javascript ? " onclick=\"document.Charform.submit()\"" : ""),
	  "> ",
	  (defined $html_longname ? $html_longname : $html_name),
	  "</label><br>\n";
    }

    print "<br>";
    if (!$use_javascript) {
	print qq{<input type=submit value="} . M("Weiter") . qq{ &gt;&gt;"><br><br>\n};
    }
    if ($per_char_filtering) {
	print M("andere") . " " . M($printtype . "stra&szlig;e") . ":<br>\n";
	abc_link($search_type);
    }
    footer();
    print qq{<input type=hidden name=scope value="@{[ (defined $q->param("scope") ? CGI::escapeHTML(scalar $q->param("scope")) : "") ]}">};
    if (defined $search_ort) {
	print qq{<input type=hidden name=${search_type}ort value="@{[ CGI::escapeHTML($search_ort) ]}">\n};
    }
    print "</form>\n";
    if ($use_javascript && $seen_anchor) {
	print <<EOF;
<script type="text/javascript"><!--
location.hash = "start";
// --></script>
EOF
    }
    print $q->end_html;
}

sub get_kreuzung {
    my($start_str, $via_str, $ziel_str,
       $start_oldname_match, $via_oldname_match, $ziel_oldname_match,
      ) = @_;
    if (!defined $start_str) {
	$start_str = $q->param('startname');
    }
    if (!defined $via_str) {
	$via_str = $q->param('vianame');
    }
    if (defined $via_str && $via_str =~ /^\s*$/) {
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

    # Make sure scope is incremented to "region" if any Potsdam street
    # is used here. This may happen for instance if choosing a Potsdam
    # street from the street list.
    for my $str ($start_str, $via_str, $ziel_str) {
	next if !defined $str;
	my($str_normed, $citypart) = Strasse::split_street_citypart($str);
	if ($citypart && $citypart =~ m{^Potsdam}) { # XXX or better check for outer_berlin_qr + outer_berlin_subplaces_qr?
	    upgrade_scope("region");
	    last;
	}
    }

    my $str = get_streets();
    $str->init;
    # Abbruch kann hier nicht fr�her erfolgen, da Stra�en unterbrochen
    # sein k�nnen
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

    if ((!defined $start and !defined $start_c) ||
	(!defined $ziel  and !defined $ziel_c)) {
	local $^W = 0;
	## In the past, I emitted a warning if this happen. But
	## it seems that there are half-legal use cases, like specifying
	## a link with just a zielname, so don't warn anymore
	##
	#if (!defined $start and !defined $start_c) {
	#    warn "Fehler: Start <$start_str/position $start> kann nicht zugeordnet werden.\n";
	#}
	#if (!defined $ziel and !defined $ziel_c) {
	#    warn "Fehler: Ziel <$ziel_str/position $ziel> kann nicht zugeordnet werden.\n";
	#}

	# Mostly this error comes from mistyped user input, so try to do
	# the best and redirect to the start page:
	$q->param('start', $start_str);
	$q->param('via', $via_str);
	$q->param('ziel', $ziel_str);
	$q->delete($_) for (qw(startname vianame zielname));
	return choose_form();
    }

    if (0) {
	# XXX nearly good enough, just:
	#   cache $nearest_orte
	#   cache everything necessary in outside_berlin_and_potsdam
	#   do it earlier, not here!
	#   check if the crossing is nearer than the place
	#   maybe use the distinction in/bei like in bbbike/Perl/Tk
	for my $def ([\$start_c, \$start_str],
		     [\$via_c,   \$via_str],
		     [\$ziel_c,   \$ziel_str],
		    ) {
	    my($c_ref, $str_ref) = @$def;
	    next if !$$c_ref;
	    next if !outside_berlin_and_potsdam($$c_ref);
	    warn "do something with $$c_ref";
	    my $nearest_orte = Kreuzungen->new_from_strassen(Strassen => get_orte());
	    $nearest_orte->make_grid;
	    my($nearest_ort_xy) = $nearest_orte->nearest_loop(split(/,/, $$c_ref),
							      IncludeDistance => 1);
	    if ($nearest_ort_xy) {
		my $ort = $nearest_orte->get_first($nearest_ort_xy->[0]);
		warn $nearest_ort_xy->[1];
		$$str_ref = $ort;
	    }							  
	}
    }

    if (@start_coords == 1 and @ziel_coords == 1 and
	(@via_coords == 1 or !defined $via)) {
	# nur eine Kreuzung f�r alle Punkte vorhanden
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
	# my_exit(0);
    }

    http_header(@weak_cache);
    my %header_args;
    $header_args{-script} = bbbike_result_js();
    header(%header_args);

    if ((!$start_c && @start_coords != 1) ||
	(!$ziel_c  && @ziel_coords != 1) ||
	(@via_coords && !$via_c)) {
	print M("Genaue Kreuzung angeben") . ":<p>\n";
    }

    all_crossings();

    print "<form action=\"$bbbike_script\">";

    print "<table>\n" if ($bi->{'can_table'});

    foreach ([$start_str, \@start_coords, $start_plz, $start_c, 'start',
	      $start_bgcolor, $start_oldname_match],
	     [$via_str,   \@via_coords,   $via_plz,   $via_c,   'via',
	      $via_bgcolor,   $via_oldname_match],
	     [$ziel_str,  \@ziel_coords,  $ziel_plz,  $ziel_c,  'ziel',
	      $ziel_bgcolor,  $ziel_oldname_match],
	    ) {
	my($strname,      $coords_ref,    $plz,       $c,       $type,
	   $bgcolor,          $oldname_match) = @$_;
	my $bgcolor_s = $bgcolor ne '' ? "bgcolor=$bgcolor" : '';
	my @coords = @$coords_ref;
	next if !@coords and !$c; # kann bei nicht definiertem Via vorkommen
	my $printtype = ucfirst($type);

	if ($bi->{'can_table'}) {
	    print "<tr $bgcolor_s><td";
	    if (!$use_select) {
		print qq{ valign="top"}
	    }
	    print ">";
	}
	print "<b>" . ucfirst(M($printtype)) . "</b>: "; # Force uppercase here
	print "</td><td>"
	    if ($bi->{'can_table'});

	if (@coords == 1) {
	    $c = $coords[0];
	}
	my $crossing_choose_html;
	if (!defined $c) {
	    $crossing_choose_html = make_crossing_choose_html($strname, $type, \@coords);
	    if (!$crossing_choose_html) {
		# cannot find meaningful crossings, fallback to middle coord
		$c = $coords[@coords/2];
	    }
	}
	if (defined $c) {
	    print qq{<input type=hidden name=${type}c value="@{[ CGI::escapeHTML($c) ]}">};
	}
	if (defined $c and (not defined $strname or $strname eq '')) {
	    print CGI::escapeHTML(crossing_text($c)) . "<br>\n";
	} else {
	    if (defined $plz and $plz eq '') {
		print $strname;
	    } else {
		print coord_or_stadtplan_link($strname, $c || $coords[0], $plz, $is_ort{$type});
	    }
	}
	if (defined $q->param($type."hnr") && $q->param($type."hnr") ne "") {
	    print " " . $q->param($type . "hnr");
	}
	if ($oldname_match) {
	    print _display_oldname($oldname_match);
	}
	# Parameter durchschleifen...
	if (defined $strname) {
	    print qq{<input type=hidden name=${type}name value="@{[ CGI::escapeHTML($strname) ]}">};
	}
	if (defined $q->param($type . "plz")) {
	    print qq{<input type=hidden name=${type}plz value="@{[ CGI::escapeHTML(scalar $q->param($type . "plz")) ]}">\n};
	}
	if (defined $q->param($type."hnr") && $q->param($type."hnr") ne "") {
	    print qq{<input type=hidden name=${type}hnr value="@{[ CGI::escapeHTML(scalar $q->param($type . "hnr")) ]}">\n};
	}
	if ($is_ort{$type}) {
	    print "<input type=hidden name=" . $type . "isort value=1>\n";
	}
	print $crossing_choose_html if $crossing_choose_html;
	if ($bi->{'can_table'}) {
	    print "</td></tr>\n";
	} else {
	    print "" . ($type ne 'ziel' ? '<hr>' : '<br><br>') . "\n";
	}
    }

    print "</table>\n" if ($bi->{'can_table'});

    hidden_smallform();


    print "<hr><p><b>" . M("Einstellungen") . "</b>:\n";
    #reset_html();
    print "</p>";
    settings_html();
    print "<hr>\n";

    suche_button();
    footer();
    print qq{<input type=hidden name=scope value="@{[ (defined $q->param("scope") ? CGI::escapeHTML(scalar $q->param("scope")) : "") ]}">};
    print "</form>";
    print $q->end_html;
}

#XXX hmmm... muss gr�ndlicher �berlegt werden.
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
#  	my_exit 0;
#      } else {
#  	return "$mapdir_url/$basefile";
#      }
#  }

# For a given $strname, $type (start, ziel, ...) and array ref of
# coordinates return a html snippet with either a radiobutton list or
# a select listbox with the selectable crossings. Unusable crossings
# (i.e. those with a concise name) are stripped out. If a crossed
# street has no name, then it will given the pseudo name "(street
# without name)". If no usable crossing was found, an empty string is
# returned. In this case the caller is responsible to use some
# alternative, e.g. choosing one (i.e. the middle) of the available
# coordinates automatically.
sub make_crossing_choose_html {
    my($strname, $type, $coords_ref) = @_;

    my $culdesac = get_culdesac_hash();

    my $html = "";

    my $i = 0;
    my %used;
    my $ecke_printed = 0;
    for my $c (@$coords_ref) {
	if ($used{$c}) {
	    next;
	} else {
	    $used{$c}++;
	}
	my @kreuzung;
	# If there's a culdesac entry, then use it
	if ($culdesac && exists $culdesac->{$c}) {
	    my $culdesac_name = $culdesac->{$c};
	    if (!defined $culdesac_name || !length $culdesac_name) {
		$culdesac_name = M('Sackgassenende');
	    }
	    push @kreuzung, $culdesac_name;
	}
	if (@kreuzung == 0) {
	    # Most common case: a normal crossing
	    if (exists $crossings->{$c}) {
		for my $crossing (@{$crossings->{$c}}) {
		    if ($crossing ne $strname) {
			push(@kreuzung, $crossing);
		    }
		}
	    }
	    if (@kreuzung == 0) {
		# Still nothing, ignore this coord
		next;
	    }
	}

	{
	    for my $kreuzung (@kreuzung) {
		if ($kreuzung =~ m{^\s*$}) {
		    $kreuzung = '(' . M("Stra�e ohne Namen") . ')';
		}
	    }
	    {
		my %seen; # make unique
		@kreuzung = grep { !$seen{$_}++ } @kreuzung;
	    }

	    unless ($ecke_printed) {
		if ($use_select) {
		    $html .= " <i>" . M("Ecke") . " </i>";
		    if ($bi->{'can_table'} && !$is_m) { # $is_m: may use an additional linebreak here
			$html .= "</td><td>";
		    }
		    $html .= "<select $bi->{hfill} name=" . $type . "c>";
		} else {
		    $html .= " " . M("Ecke") . " ...<br>\n";
		}
		$ecke_printed++;
	    }

	    if ($use_select) {
		$html .= "<option value=\"$c\">";
	    } else {
		$html .= "<label>";
		$html .=
		    "<input type=radio name=" . $type . "c " .
			"value=\"$c\"";
		if ($i++ == 0) {
		    $html .= " checked";
		}
		$html .= "> ";
	    }
	    $html .= join("/", Strasse::nice_crossing_name(@kreuzung));
	    $html .= "</label><br>" unless $use_select;
	    $html .= "\n";
	}
    }
    $html .= "</select>" if $use_select && $ecke_printed;

    $html;
}

sub get_global_cookie {
    if (!$got_cookie) {
	%c = get_cookie();
	$got_cookie = 1;
    }
}

sub get_cookie {
    $q->cookie(-name => $cookiename,
# XXX cookie seems only to be set if doing some action from the search site, not a page before. Check it!
# XXX dirname okay with backward compatibility?
	       -path => dirname(BBBikeCGI::Util::my_url($q, -absolute => 1)),
	      );
}

sub set_cookie {
    my($href) = @_;
    # Create a dirname and a non-dirname cookie (both for backward compat):
    [$q->cookie
     (-name => "$cookiename-dir",
      -value => $href,
      -expires => '+1y',
      -path => dirname(BBBikeCGI::Util::my_url($q, -absolute => 1)),
     ),
     $q->cookie
     (-name => $cookiename,
      -value => $href,
      -expires => '+1y',
      -path => BBBikeCGI::Util::my_url($q, -absolute => 1),
     ),
    ];
}

use vars qw($default_speed $default_cat $default_quality
	    $default_ampel $default_routen $default_green $default_specialvehicle
	    $default_unlit $default_ferry $default_winter
	    $default_fragezeichen);

sub get_settings_defaults {
    get_global_cookie();

    $default_speed   = (defined $c{"pref_speed"} && $c{"pref_speed"} != 0 ? $c{"pref_speed"}+0 : $speed_default);
    $default_cat     = (defined $c{"pref_cat"}     ? $c{"pref_cat"}     : "");
    $default_quality = (defined $c{"pref_quality"} ? $c{"pref_quality"} : "");
    $default_ampel   = (defined $c{"pref_ampel"} && $c{"pref_ampel"} eq 'yes' ? 1 : 0);
    $default_routen  = (defined $c{"pref_routen"}  ? $c{"pref_routen"}  : "");
    $default_green   = (defined $c{"pref_green"}   ? $c{"pref_green"}   : "");
    # Backward compatibility:
    if ($default_green eq 'yes') {
	$default_green = 2;
    }
    $default_specialvehicle = (defined $c{"pref_specialvehicle"} ? $c{"pref_specialvehicle"} : '');
    $default_unlit   = (defined $c{"pref_unlit"}   ? $c{"pref_unlit"}   : "");
    $default_ferry   = (defined $c{"pref_ferry"}   ? $c{"pref_ferry"}   : "");
    $default_winter  = (defined $c{"pref_winter"}  ? $c{"pref_winter"}  : "");
    $default_fragezeichen = (defined $c{"pref_fragezeichen"} ? $c{"pref_fragezeichen"} : "");
}

## XXX "Reset" is too confusing. It would be better to have a select box with
##     some predefined settings, like "Grundeinstellung" (as on 1st use),
##     "zuletzt benutzt" (from cookie) and some other common settings, e.g.
##     f�r Rennrunde, gem�tlicher Familienausflug etc. It could also be used
##     for different saved user settings.
##
##     The code below could probably be partially reused.
#sub reset_html {
#    if ($bi->{'can_javascript'}) {
#	my(%strcat)    = ("" => 0, "N1" => 1, "N2" => 2, "H1" => 3, "H2" => 4);
#	my(%strqual)   = ("" => 0, "Q0" => 1, "Q2" => 2);
#	my(%strrouten) = ("" => 0, "RR" => 1);
#	my(%strgreen)  = ("" => 0, "GR1" => 1, "GR2" => 2);
#	my(%strspecialvehicle) = ('' => 0, 'trailer' => 1, 'childseat' => 2);
#	my(%strunlit)  = ("" => 0, "NL" => 1);
#	my(%strferry)  = ("" => 0, "use" => 1);
#	my(%strwinter) = ("" => 0, "WI1" => 1, "WI2" => 2);
#
#	get_settings_defaults();
#
#	print join(" ", 
#		   qq'<input class="settingsreset" type=button value="Reset" onclick="reset_form(',
#		   qq'@{[defined $default_speed ? $default_speed : "null" ]},',
#		   qq'@{[defined $strcat{$default_cat} ? $strcat{$default_cat} : 0]},',
#		   qq'@{[defined $strqual{$default_quality} ? $strqual{$default_quality}: 0]},',
#		   qq'@{[defined $strrouten{$default_routen} ? $strrouten{$default_routen} : 0]},',
#		   qq'@{[ $default_ampel?"true":"false" ]},',
#		   qq'@{[defined $strgreen{$default_green} ? $strgreen{$default_green} : 0]},',
#		   qq'@{[defined $strspecialvehicle{$default_specialvehicle} ? $strspecialvehicle{$default_specialvehicle} : 0]},',
#		   qq'@{[defined $strunlit{$default_unlit} ? $strunlit{$default_unlit} : 0]},',
#		   qq'@{[defined $strferry{$default_ferry} ? $strferry{$default_ferry} : 0]},',
#		   qq'@{[defined $strwinter{$default_winter} ? $strwinter{$default_winter} : 0]}',
#		   qq'); enable_settings_buttons(); return false;">',
#		  );
#    }
#}

sub settings_html {
    get_global_cookie();

    if ($q->param("pref_seen")) {
	foreach my $key (@pref_keys) {
	    $c{"pref_$key"} = $q->param("pref_$key");
	}
    }

    get_settings_defaults();

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
    my $green_checked = sub { my $val = shift;
			      'value="' . $val . '" ' .
			      ($default_green eq $val ? "selected" : "")
			};
    my $specialvehicle_checked = sub { my $val = shift;
				       'value="' . $val . '" ' .
				       ($default_specialvehicle eq $val ? "selected" : "")
				   };
    my $unlit_checked = sub { my $val = shift;
			      'value="' . $val . '" ' .
			      ($default_unlit eq $val ? "selected" : "")
			};
    my $ferry_checked = sub { my $val = shift;
			      'value="' . $val . '" ' .
			      ($default_ferry eq $val ? "selected" : "")
			  };
    my $winter_checked = sub { my $val = shift;
			      'value="' . $val . '" ' .
			      ($default_winter eq $val ? "selected" : "")
			};

    print <<EOF;
<input type=hidden name="pref_seen" value=1>
<table>
<tr><td>@{[ M("Bevorzugte Geschwindigkeit") ]}:</td><td><input type=text maxlength=2 size=4 name="pref_speed" value="$default_speed"> km/h</td></tr>
<tr><td>@{[ M("Bevorzugter Stra�entyp") ]}:</td><td><select $bi->{hfill} name="pref_cat">
<option @{[ $cat_checked->("") ]}>@{[ M("egal") ]}
<option @{[ $cat_checked->("N1") ]}>@{[ M("Nebenstra�en bevorzugen") ]}
<option @{[ $cat_checked->("N2") ]}>@{[ M("nur Nebenstra�en benutzen") ]}
<option @{[ $cat_checked->("H1") ]}>@{[ M("Hauptstra�en bevorzugen") ]}
<option @{[ $cat_checked->("H2") ]}>@{[ M("nur Hauptstra�en benutzen") ]}
<option @{[ $cat_checked->("N_RW") ]}>@{[ M("Hauptstra�en ohne Radwege/Busspuren meiden") ]}
<option @{[ $cat_checked->("N_RW1") ]}>@{[ M("Hauptstra�en ohne Radwege meiden") ]}
</select></td></tr>
<tr><td>@{[ M("Bevorzugter Stra�enbelag") ]}:</td><td><select $bi->{hfill} name="pref_quality">
<option @{[ $qual_checked->("") ]}>@{[ M("egal") ]}
<option @{[ $qual_checked->("Q2") ]}>@{[ M("Kopfsteinpflaster und schlechte Fahrbahnen vermeiden") ]}
<option @{[ $qual_checked->("Q0") ]}>@{[ M("nur sehr gute Bel�ge bevorzugen (rennradtauglich)") ]}
</select></td></tr>
EOF
#  <!--
#  <tr><td>@{[ M("Ausgeschilderte Fahrradrouten bevorzugen") ]}:</td><td><select $bi->{hfill} name="pref_routen">
#  <option @{[ $routen_checked->("") ]}>@{[ M("egal") ]}
#  <option @{[ $routen_checked->("RR") ]}>@{[ M("ja") ]}
#  </select></td></tr>
#  -->
#  <!--XXX implement <tr><td>@{[ M("Radwege") ]}:</td><td><select $bi->{hfill} name="pref_rw">
#  <option value="">@{[ M("egal") ]}
#  <option value="R0">@{[ M("nur Radwege verwenden") ]}
#  <option value="R1">@{[ M("Hauptstra�en mit Radweg bevorzugen") ]}
#  <option value="R2">@{[ M("benutzungspflichtige Radwege vermeiden") ]}
#  </select></td></tr>-->
    print <<EOF;
<tr><td><label for="pref_ampel">@{[ M("Ampeln vermeiden") ]}:</label></td><td><input type=checkbox name="pref_ampel" id="pref_ampel" value="yes" @{[ $default_ampel?"checked":"" ]}></td>
EOF
    if ($include_outer_region) {
	print <<EOF;
<td style="font-size:smaller;">@{[ M("(nur in Berlin/Potsdam erfasst)") ]}</td>
EOF
    }
    if (1) {
	print <<EOF;
<tr><td><label for="pref_unlit">@{[ M("Unbeleuchtete Wege vermeiden") ]}:</label></td><td><input type=checkbox name="pref_unlit" id="pref_unlit" value="NL" @{[ $default_unlit?"checked":"" ]}></td>
EOF
	if ($include_outer_region) {
	    print <<EOF;
<td style="font-size:smaller;">@{[ M("(nur in Berlin/Potsdam erfasst)") ]}</td>
EOF
	}
    } else {
	print <<EOF;
<input type="hidden" name="pref_unlit" value="">
EOF
    }
    print <<EOF;
<tr><td>@{[ M("Gr�ne Wege") ]}:</td><td><select $bi->{hfill} name="pref_green">
<option @{[ $green_checked->("") ]}>@{[ M("egal") ]}
<option @{[ $green_checked->("GR1") ]}>@{[ M("bevorzugen") ]}
<option @{[ $green_checked->("GR2") ]}>@{[ M("stark bevorzugen") ]} <!-- expr? -->
</select></td></tr>
EOF
    print <<EOF;
<tr><td>@{[ M("Unterwegs mit") ]}:</td><td><select $bi->{hfill} name="pref_specialvehicle">
<option @{[ $specialvehicle_checked->("")          ]}>@{[ M("nichts weiter") ]} <!-- expr? XXX -->
<option @{[ $specialvehicle_checked->("trailer")   ]}>@{[ M("Anh�nger") ]}
<option @{[ $specialvehicle_checked->("childseat") ]}>@{[ M("Kindersitz mit Kind") ]}
</select></td></tr>
EOF
    if (!$osm_data || do {
	my $geo = get_geography_object();
	$geo && !$geo->skip_feature('faehren')
    }) {
	print <<EOF;
<tr><td><label for="pref_ferry">@{[ M("F�hren benutzen") ]}:</label></td><td><input type=checkbox name="pref_ferry" id="pref_ferry" value="use" @{[ $default_ferry?"checked":"" ]}></td></tr>
EOF
    }
    if ($use_winter_optimization) {
	print <<EOF;
<tr>
 <td>@{[ M("Winteroptimierung") ]}</td><td><select $bi->{hfill} name="pref_winter" @{[ $bi->{'can_javascript'} ? "onchange='enable_settings_buttons()'" : "" ]}>
<option @{[ $winter_checked->("") ]}>@{[ M("nein") ]}
<option @{[ $winter_checked->("WI1") ]}>@{[ M("schwach") ]}
<option @{[ $winter_checked->("WI2") ]}>@{[ M("stark") ]}
</select></td>
EOF
	if (!$is_m) {
	    print <<EOF;
 <td style="vertical-align:bottom">@{[ experimental_label() ]}<small><a target="BBBikeHelp" href="$bbbike_html/help.html#winteroptimization" onclick="show_help@{[ $lang ? "_$lang" : "" ]}('winteroptimization'); return false;">@{[ M("Was ist das?") ]}</a></small></td>
EOF
	}
	print <<EOF;
</tr>
EOF
    }
    if ($use_fragezeichen) {
	print <<EOF;
<tr>
 <td><label for="pref_fragezeichen">@{[ M("Unbekannte Stra�en mit einbeziehen") ]}:</label></td>
 <td><input type=checkbox name="pref_fragezeichen" id="pref_fragezeichen" value=yes @{[ $default_fragezeichen?"checked":"" ]}></td>
EOF
	if (!$is_m) {
	    print <<EOF;
 <td style="vertical-align:bottom"><small><a target="BBBikeHelp" href="$bbbike_html/help.html#fragezeichen" onclick="show_help@{[ $lang ? "_$lang" : "" ]}('fragezeichen'); return false;">@{[ M("Was ist das?") ]}</a></small></td>
EOF
	}
	print <<EOF;
</tr>
EOF
    }
    print <<EOF;
</table>
EOF
}

sub suche_button {
    if ($bi->{'can_javascript'}) {
	print qq{<input type=button value="&lt;&lt; } . M("Zur�ck") . qq{" onclick="history.back(1);">&nbsp;&nbsp;};
    }
    print qq{<input type=submit value="} . M("Route zeigen") . qq{ &gt;&gt;">\n};
}

sub help_link {
    my($topic) = @_;
    my $s = '';
    if (!$is_m) {
	$s .= <<EOF;
  <a class="yellowbox" style="text-decoration:none" target="BBBikeHelp" href="$bbbike_html/help.html#$topic">?</a>
EOF
    }
    $s;
}

sub hidden_smallform {
    # Hier die Query-Variable statt der Perl-Variablen benutzen...
    if ($q->param('smallform')) {
	print qq{<input type=hidden name=smallform value="@{[ CGI::escapeHTML(scalar $q->param('smallform')) ]}">\n};
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
	my $special_vehicle = defined $q->param('pref_specialvehicle') ? $q->param('pref_specialvehicle') : '';
	my $str = get_streets();
	$net = new StrassenNetz $str;
	# XXX This change should also go into radlstadtplan.cgi!!!
	if (defined $search_algorithm && $search_algorithm eq 'C-A*-2') {
	    $net->use_data_format($StrassenNetz::FMT_MMAP);
	    # make_net with initial -blocked is more performant
	    $net->make_net(-blocked => "gesperrt",
			   -blockedtype => [qw(einbahn sperre)],
			  );
	    $net->make_sperre('gesperrt',
			      Type => [qw(wegfuehrung)],
			      SpecialVehicle => $special_vehicle,
			      # XXX What about $special_vehicle? Is it correct here, or not possible because of the static net?
			     );
	} else {
	    # XXX �berpr�fen, ob sich der Cache lohnt...
	    # evtl. mit IPC::Shareable arbeiten (Server etc.)
	    $net->make_net(UseCache => 1);
	    if (!$lite) {
		$net->make_sperre('gesperrt',
				  Type => [qw(einbahn sperre wegfuehrung)],
				  SpecialVehicle => $special_vehicle,
				 );
	    }
	}
    }
    $net;
}

sub search_coord {
    my $startcoord  = $q->param('startc');
    my $zielcoord   = $q->param('zielc');
    my($viacoord, @more_viacoords) = BBBikeCGI::Util::my_multi_param($q, 'viac');
    my(@custom)     = BBBikeCGI::Util::my_multi_param($q, 'custom');
    my %custom      = map { ($_ => 1) } @custom;

    my $via_array = (defined $viacoord && $viacoord ne ''
		     ? [$viacoord, @more_viacoords]
		     : []);

    # Technically more correct it would be to adjust the scope
    # after fix_coords. But fix_coords already needs a built net,
    # so we ignore the hopefully small fix by fix_coords.
    #
    # adjust_scope_for_search adjust $q->param("scope")
    adjust_scope_for_search([$startcoord, @$via_array, $zielcoord]);

    my $scope = $q->param("scope") || "city";

    make_netz();

    ($startcoord, $zielcoord, @$via_array)
	= fix_coords($startcoord, $zielcoord, @$via_array);

    my %extra_args;
    if (@$via_array) {
	$extra_args{Via} = $via_array;
    }

    # Tragen vermeiden
    $extra_args{Tragen} = 1;
    my $velocity_kmh = $q->param("pref_speed");
    ($velocity_kmh) = $velocity_kmh =~ m{(\d+(?:\.\d+)?)}; # input validation
    $velocity_kmh += 0; # protect from things like "00"
    $velocity_kmh ||= $speed_default;
    $q->param("pref_speed", $velocity_kmh); # possibly correct query param
    $extra_args{Velocity} = $velocity_kmh/3.6; # convert to m/s
    # XXX Anzahl der Tragestellen z�hlen...

    my @penalty_subs;

    my $disable_other_optimizations = 0;

    # Winteroptimierung
    if (defined $q->param('pref_winter') && $q->param('pref_winter') ne '') {
	if ($use_winter_optimization) {
	    $winter_hardness ||= 'snowy'; # some default
	    require Storable;
	    my $penalty;
	    for my $try (1 .. 2) {
		for my $dir ("$FindBin::RealBin/../tmp", @Strassen::datadirs) {
		    my $f = "$dir/winter_optimization.$winter_hardness.st";
		    if (-r $f && -s $f) {
			$penalty = Storable::retrieve($f);
			last;
		    }
		}
		if (!$penalty) {
		    if ($try == 2) {
			die "Can't find winter_optimization.$winter_hardness.st in @Strassen::datadirs and cannot build...";
		    } else {
			system("$FindBin::RealBin/../miscsrc/winter_optimization.pl", "-winter-hardness", $winter_hardness, "-one-instance");
		    }
		} else {
		    last;
		}
	    }

	    my $koeff = 1;
	    if ($q->param('pref_winter') eq 'WI1') {
		$koeff = 0.5;
	    }

	    push @penalty_subs, sub {
		my($pen, $next_node, $last_node) = @_;
		if (exists $penalty->{$last_node.",".$next_node}) {
		    my $this_penalty = $penalty->{$last_node.",".$next_node};
		    $this_penalty = $koeff * $this_penalty + (100-$koeff*100)
			if $koeff != 1;
		    if ($this_penalty < 1) {
			$this_penalty = 1;
		    }		# avoid div by zero or negative values
		    $pen *= (100 / $this_penalty);
		}
		$pen;
	    };
	    #XXX $disable_other_optimizations = 1;
	} else {
	    # ignore pref_winter
	}
    }

    # Ampeloptimierung
    if (!$disable_other_optimizations && defined $q->param('pref_ampel') && $q->param('pref_ampel') eq 'yes') {
	if (new_trafficlights()) {
	    $extra_args{Ampeln} = {Net     => $ampeln,
				   Penalty => 100};
	}
    }

    # Haupt/Freizeitrouten-Optimierung
    if (!$disable_other_optimizations && defined $q->param('pref_routen') && $q->param('pref_routen') ne '') { # 'RR'
	if (!$routen_net) {
	    $routen_net =
		new StrassenNetz(Strassen->new("radrouten"));
	    $routen_net->make_net;
	}
	push @penalty_subs, sub {
	    my($p, $next_node, $last_node) = @_;
	    if (!$routen_net->{Net}{$last_node}{$next_node}) {
		$p *= 2; # XXX differenzieren?
	    }
	    $p;
	};
    }

    # UserDefPenaltySubs
    if (@penalty_subs) {
	# Note: the @penalty_subs should only multiply $p, not add to
	# if there are more than one penalty sub!
	$extra_args{UserDefPenaltySub} = sub {
	    my($p, $next_node, $last_node) = @_;
	    for my $sub (@penalty_subs) {
		$p = $sub->($p, $next_node, $last_node);
	    }
	    $p;
	};
    }

    # Optimierung der gr�nen Wege
    if (!$disable_other_optimizations && defined $q->param('pref_green') && $q->param('pref_green') ne '') {
	if (!$green_net) {
	    $green_net = new StrassenNetz(Strassen->new("green"));
	    $green_net->make_net_cat;
	}
	my $penalty = ($q->param('pref_green') eq 'GR1'
		       ? { "green0" => 2,
			   "green1" => 1.5,
			   "green2" => 1,
			 }
		       : { "green0" => 3,
			   "green1" => 2,
			   "green2" => 1,
		       });
	$extra_args{Green} =
	    {Net => $green_net,
	     Penalty => $penalty,
	    };
    }

    # Optimierung der beleuchteten Wegen
    if (!$disable_other_optimizations && defined $q->param('pref_unlit') && $q->param('pref_unlit') ne '') {
	if (!$unlit_streets_net) {
	    $unlit_streets_net = new StrassenNetz(Strassen->new("nolighting"));
	    $unlit_streets_net->make_net_cat;
	}
	my $penalty = { "NL" => 4,
		      };
	$extra_args{UnlitStreets} =
	    {Net => $unlit_streets_net,
	     Penalty => $penalty,
	    };
    }

    # Handicap-Optimierung ...
    # Zurzeit nur Fu�g�ngerzonenoptimierung automatisch.
    # sowie Daten aus temp_blockings (wird unten ge-merge-t).
    # Diese Optimierung ist immer eingeschaltet, auch wenn die
    # Winteroptimierung aktiv ist (haupts�chlich wegen temp_blockings)
    if (1) {
	if (!$handicap_net) {
	    my @in_files = ('handicap_s');
	    if ($scope eq 'region' || $scope eq 'wideregion') {
		push @in_files, 'handicap_l';
	    }
	    if ($q->param('pref_ferry') && $q->param('pref_ferry') eq 'use') {
		push @in_files, 'faehren';
	    }
	    if (@in_files == 1) {
		$handicap_net = StrassenNetz->new(Strassen->new(@in_files));
	    } else {
		$handicap_net = StrassenNetz->new(MultiStrassen->new(@in_files));
	    }
	    $handicap_net->make_net_cat;
	}
	my $penalty = {};
	for my $q_cat (keys %handicap_speed) {
	    $penalty->{$q_cat} = $velocity_kmh/$handicap_speed{$q_cat};
	}
	for my $q (0 .. 4) {
	    my $q_cat = "q$q";
	    $penalty->{$q_cat} = 1 if !exists $penalty->{$q_cat} || $penalty->{$q_cat} < 1;
	}
	require Strassen::CatUtil;
	Strassen::CatUtil::apply_tendencies_in_penalty($penalty, quiet => 1); # quiet because of the ferry category entry ("Q")
	$extra_args{Handicap} =
	    {Net => $handicap_net,
	     Penalty => $penalty,
	    };

    }

    # handicap_directed XXX not yet enabled
    if (0) {
	if (!$handicap_directed_net) {
	    if (-f "$Strassen::datadirs[0]/handicap_directed") { # XXX may be missing for osm data
		require Strassen::StrassenNetz::DirectedHandicap;
		my $special_vehicle = $q->param('pref_specialvehicle') || '';
		$handicap_directed_net = Strassen::StrassenNetz::DirectedHandicap->new(
										       Strassen->new('handicap_directed'),
										       speed   => $velocity_kmh,
										       vehicle => $special_vehicle,
										       handicap_speed => \%handicap_speed,
										      )->make_net;
	    }
	}
	if ($handicap_directed_net) {
	    $extra_args{DirectedHandicap} = $handicap_directed_net;
	} else {
	    if (!$osm_data) {
		warn "WARN: No handicap_directed data file available (looked in '$Strassen::datadirs[0]').\n";
	    }
	}
    }

    # Qualit�tsoptimierung
    if (!$disable_other_optimizations && defined $q->param('pref_quality') && $q->param('pref_quality') ne '') {
	# XXX landstra�en?
	if (!$qualitaet_net) {
	    if ($scope eq 'region' || $scope eq 'wideregion') {
		$qualitaet_net =
		    new StrassenNetz(MultiStrassen->new("qualitaet_s",
							"qualitaet_l"));
	    } else {
		$qualitaet_net =
		    new StrassenNetz(Strassen->new("qualitaet_s"));
	    }
	    $qualitaet_net->make_net_cat;
	}
	my %penalty;
	my %max_limit;
	if ($q->param('pref_quality') eq 'Q0') {
	    %penalty = ( "Q0" => 1,
			 "Q1" => 1.2,
			 "Q2" => 1.6,
			 "Q3" => 2 );
	    %max_limit = ( Q1 => $velocity_kmh / 25,
			   Q2 => $velocity_kmh / 16,
			   Q3 => $velocity_kmh / 10 );
	} else {
	    %penalty = ( "Q0" => 1,
			 "Q1" => 1,
			 "Q2" => 1.5,
			 "Q3" => 1.8 );
	    %max_limit = ( Q1 => $velocity_kmh / 25,
			   Q2 => $velocity_kmh / 18,
			   Q3 => $velocity_kmh / 13 );
	}
	require Strassen::CatUtil;
	Strassen::CatUtil::apply_tendencies_in_penalty(\%penalty);
	Strassen::CatUtil::apply_tendencies_in_speed(\%max_limit);
	my $min_limit = $velocity_kmh / 5;
	for my $q (keys %max_limit) {
	    if ($penalty{$q} < $max_limit{$q}) {
		$penalty{$q} = $max_limit{$q};
	    }
	}
	if ($velocity_kmh > 5) {
	    for my $q (keys %penalty) {
		if ($penalty{$q} > $min_limit) {
		    $penalty{$q} = $min_limit;
		}
	    }
	}
	$extra_args{Qualitaet} =
	    {Net => $qualitaet_net,
	     Penalty => \%penalty,
	    };

    }

    # Kategorieoptimierung
    if (!$disable_other_optimizations && defined $q->param('pref_cat') && $q->param('pref_cat') ne '') {
	my $penalty;
	my $pref_cat = $q->param('pref_cat');
	if ($pref_cat =~ m{^N_RW1?$}) {
	    if (!$radwege_strcat_net) {
		my $str = get_streets();
		$radwege_strcat_net = StrassenNetz->new($str);
		$radwege_strcat_net->make_net_cyclepath
		    (get_cyclepath_streets(), UseCache => 1);
	    }
	    $penalty = { "H"     => 4,
			 "H_Bus" => ($pref_cat eq 'N_RW1' ? 4 : 1),
			 "H_RW"  => 1,
			 "N"     => 1,
			 "N_Bus" => 1,
			 "N_RW"  => 1,
		       };
	    $extra_args{RadwegeStrcat} =
		{Net => $radwege_strcat_net,
		 Penalty => $penalty,
		};
	} else {
	    if (!$strcat_net) {
		my $str = get_streets();
		$strcat_net = new StrassenNetz $str;
		$strcat_net->make_net_cat(-usecache => 1);
	    }
	    if ($pref_cat eq 'N2') {
		$penalty = { "B"  => 4,
			     "HH" => 4,
			     "H"  => 4,
			     "NH" => 2,
			     "N"  => 1,
			     "NN" => 1 };
	    } elsif ($pref_cat eq 'N1') {
		$penalty = { "B"  => 1.5,
			     "HH" => 1.5,
			     "H"  => 1.5,
			     "NH" => 1,
			     "N"  => 1,
			     "NN" => 1 };
	    } elsif ($pref_cat eq 'H1') {
		$penalty = { "B"  => 1,
			     "HH" => 1,
			     "H"  => 1,
			     "NH" => 1,
			     "N"  => 1.5,
			     "NN" => 1.5 };
	    } elsif ($pref_cat eq 'H2') {
		$penalty = { "B"  => 1,
			     "HH" => 1,
			     "H"  => 1,
			     "NH" => 2,
			     "N"  => 4,
			     "NN" => 4 };
	    }
	    if ($penalty) {
		$extra_args{Strcat} =
		    {Net => $strcat_net,
		     Penalty => $penalty,
		    };
	    }
	}
    }

    if (defined $search_algorithm) {
	$extra_args{Algorithm} = $search_algorithm;
    }

    my $is_test_mode = (defined $q->param("test") && grep { /^(?:custom|temp)[-_]blocking/ } BBBikeCGI::Util::my_multi_param($q, 'test'));
    load_temp_blockings(-test => $is_test_mode || $fake_time);

    my(%custom_s, @current_temp_blocking);
    {
	my $t = $fake_time || time;
	my $index = -1;
	for my $tb (@temp_blocking) {
	    $index++;
	    next if !$tb; # undefined entry
	    if (((!defined $tb->{from} || $t >= $tb->{from}) &&
		 (!defined $tb->{until} || $t <= $tb->{until})) ||
		$is_test_mode
		) {
		push @current_temp_blocking, $tb;
		$tb->{'index'} = $index;
	    }
	}
	if (@current_temp_blocking) {
	    local @Strassen::datadirs = @Strassen::datadirs;
	    push @Strassen::datadirs,
		"$FindBin::RealBin/../BBBike/data/temp_blockings",
		"$FindBin::RealBin/../data/temp_blockings",
		;
	    for(my $i = 0; $i <= $#current_temp_blocking; $i++) {
		my $tb = $current_temp_blocking[$i];
		my $strobj;
		if (!eval {
		    if ($tb->{file}) {
			$strobj = Strassen->new($tb->{file});
		    } elsif ($tb->{data}) {
			$strobj = Strassen->new_from_data_string($tb->{data});
## XXX Funktioniert nicht so gut:
# 			if ($bbbike_temp_blockings_file) {
# 			    $strobj->{DependentFiles} = [ $bbbike_temp_blockings_file ];
# 			}
		    } else {
			die "Neither file nor data found in entry";
		    }
		}) {
		    warn $@ if $@;
		    splice @current_temp_blocking, $i, 1;
		    $i--;
		    next;
		}

		$tb->{strobj} = $strobj;
		if (@custom) {
		    if (exists $custom{'temp-blocking-' . $tb->{'index'}}) {
			my %strobj_per_type;
			$strobj->init;
			while(1) {
			    my $r = $strobj->next;
			    last if !@{ $r->[Strassen::COORDS] };
			    my $type;
			    if ($r->[Strassen::CAT] =~ m{^q}) {
				$type = 'handicap';
			    } else {
				$type = 'gesperrt';
			    }
			    if (!$strobj_per_type{$type}) {
				$strobj_per_type{$type} = Strassen->new;
			    }
			    $strobj_per_type{$type}->push($r);
			}
			while(my($type, $strobj_per_type) = each %strobj_per_type) {
			    push @{ $custom_s{$type} }, $strobj_per_type;
			}
		    }
		}
		{
		    my $strobj_3    = $strobj->grepstreets(sub { $_->[Strassen::CAT] =~ /^3($|:)/ });
		    my $strobj_non3 = $strobj->grepstreets(sub { $_->[Strassen::CAT] !~ /^3($|:)/ });
		    my $tb_net = $tb->{net} = StrassenNetz->new($strobj_non3);
		    $tb_net->make_net_cat(-onewayhack => 1);
		    $tb_net->make_sperre($strobj_3, Type => ['wegfuehrung']);
		    # XXX What about $special_vehicle? Should it be used here?
		}
	    }

	    if (@custom) {
		while(my($type, $list) = each %custom_s) {
		    $custom_s{$type} = MultiStrassen->new(@$list);

		    if ($type eq 'gesperrt' && $custom_s{$type}) {
			$net->make_sperre($custom_s{$type}, Type => 'all');
		    } elsif ($type eq 'handicap' && $custom_s{$type}) {
			if (!$handicap_net) {
			    warn "No net for handicap defined, ignoring temp_blocking=handicap";
			} else {
			    $handicap_net->merge_net_cat($custom_s{$type});
			}
		    } else {
			warn "Unhandled temp blocking type `$type'";
		    }
		}
	    }
	}
    }

    my($r) = $net->search($startcoord, $zielcoord,
			  AsObj => 1,
			  %extra_args);
    if ((!$r || !$r->path_list) && $r->nearest_node) {
	my $nearest_node = $r->nearest_node;
	warn "Search again with nearest node <" . $nearest_node . "> instead of wanted goal <" . $zielcoord . ">\n";
	($r) = $net->search($startcoord, $nearest_node,
			    AsObj => 1,
			    %extra_args);
	# Remember that we found just a route to the nearest node
	$r->set_to($zielcoord);
	$r->set_nearest_node($nearest_node);
    }

    display_route($r, -custom => { custom		 => \@custom,
				   custom_s		 => \%custom_s,
				   current_temp_blocking => \@current_temp_blocking,
				 });
}

sub display_route {
    my($r, %args) = @_;

    my $startcoord = $r->{From};
    my $viacoord   = $r->{Via} && @{ $r->{Via} } ? $r->{Via}[0] : undef;
    my $zielcoord  = $r->{To};

    # XXX may calculate start and ziel from route if none is provided
    my $startname   = name_from_cgi($q, 'start');
    my $vianame     = name_from_cgi($q, 'via');
    my $zielname    = name_from_cgi($q, 'ziel');

    my $real_zielname;
    if ($r && $r->nearest_node) {
	$real_zielname = crossing_text($r->nearest_node);
    } else {
	$real_zielname = $zielname;
    }

    my $routetitle  = $q->param('routetitle');

    my $starthnr    = $q->param('starthnr');
    my $viahnr      = $q->param('viahnr');
    my $zielhnr     = $q->param('zielhnr');

    my $output_as   = $q->param('output_as');
    my $printmode   = defined $output_as && $output_as eq 'print';

    my $scope = $q->param("scope") || "city";

    my $velocity_kmh = $q->param("pref_speed") || $speed_default;

    my $printwidth      = 400;
    my $printtablewidth = 400;
    if ($printmode && $q->param("printvariant") && $q->param("printvariant") eq 'normal') {
	$printtablewidth = '100%';
    }

    my @custom;
    my %custom_s;
    my @current_temp_blocking;
    if ($args{-custom}) {
	@custom                = @{ $args{-custom}->{custom} };
	%custom_s              = %{ $args{-custom}->{custom_s} };
	@current_temp_blocking = @{ $args{-custom}->{current_temp_blocking} };
    }

    my $show_settings = !$args{-hidesettings};
    my $show_wayback  = !$args{-hidewayback};

    my $in_error_condition;

    make_netz();

    if (defined $output_as && $output_as eq 'palmdoc') {
	require BBBikePalm;
	my $filename = filename_from_route($startname, $zielname) . ".pdb";
	http_header
	    (-type => "application/x-palm-database",
	     -Content_Disposition => "attachment; filename=$filename",
	    );
	print BBBikePalm::route2palm(-net => $net, -route => $r,
				     -startname => $startname,
				     -zielname => $zielname);
	return;
    }

    my $route_to_strassen_object = sub {
	my $bbd_line;
	if ($r->path && @{ $r->path }) {
	    $bbd_line = "$startname - $zielname\tX " .
		join(" ", map { "$_->[0],$_->[1]" }
		     @{ $r->path || [] }) . "\n";
	} else {
	    $bbd_line = '';
	}
	Strassen->new_from_data($bbd_line);
    };

    if (defined $output_as && $output_as eq 'gpx-track') {
	require Strassen::GPX;
	my $filename = filename_from_route($startname, $zielname, "track") . ".gpx";
	my @headers =
	    (-type => "application/gpx+xml",
	     -Content_Disposition => "attachment; filename=$filename",
	    );
	http_header(@headers);
	my $s = $route_to_strassen_object->();
	my $s_gpx = Strassen::GPX->new($s);
	$s_gpx->{"GlobalDirectives"}->{"map"}[0] = "polar" if $data_is_wgs84;
	my $gpx_output = $s_gpx->bbd2gpx(-as => "track");
	print $gpx_output;
	if ($cache_entry) {
	    $cache_entry->put_content($gpx_output, {_additional_filecache_info($q), headers => \@headers});
	}
	return;
    }

    if (defined $output_as && $output_as eq 'kml-track') {
	require Strassen::KML;
	my $filename = filename_from_route($startname, $zielname, "track") . ".kml";
	my @headers =
	    (-type => "application/vnd.google-earth.kml+xml",
	     -Content_Disposition => "attachment; filename=$filename",
	     @weak_cache,
	    );
	http_header(@headers);
	my $s = $route_to_strassen_object->();
	my $s_kml = Strassen::KML->new($s);
	$s_kml->{"GlobalDirectives"}->{"map"}[0] = "polar" if $data_is_wgs84;
	my $kml_output = $s_kml->bbd2kml(startgoalicons => 1);
	print $kml_output;
	if ($cache_entry) {
	    $cache_entry->put_content($kml_output, {_additional_filecache_info($q), headers => \@headers});
	}
	return;
    }

    if (defined $output_as && $output_as eq 'mapserver') {
	if ($r->path) {
	    $q->param('coords', join("!", map { "$_->[0],$_->[1]" }
				     @{ $r->path }));
	}
	$q->param("imagetype", "mapserver");
	draw_route();
	return;
    }

    my(@weather_res);
    if ($show_weather || $bp_obj) {
	@weather_res = gather_weather_proc();
    }

    my $sess = tie_session(undef);

    my $has_fragezeichen_routelist;
    my $fragezeichen_net;
    if ($use_fragezeichen_routelist) {
	eval {
	    my $s = Strassen->new("fragezeichen");
	    $fragezeichen_net = StrassenNetz->new($s);
	    $fragezeichen_net->make_net;
	};
	warn $@ if $@;
	$has_fragezeichen_routelist = 1 if $fragezeichen_net;
    }

    my(@power) = (50, 100, 200);
    my @speeds = qw(10 15 20 25);
    if ($q->param('pref_speed')) {
	if (!grep { $_ == $q->param('pref_speed') } @speeds) {
	    push @speeds, scalar $q->param('pref_speed');
	    @speeds = sort { $a <=> $b } @speeds;
	    if ($q->param('pref_speed') > 17) {
		shift @speeds;
	    } else {
		pop @speeds;
	    }
	}
    }

    my @out_route;
    my %speed_map;
    my %power_map;
    my @strnames;
    my @path;
 CALC_ROUTE_TEXT: {
	last CALC_ROUTE_TEXT if (!$r || !$r->path_list);

	my $penalty_lost = 0;

	my @bikepwr_time = (0, 0, 0);
	#use vars qw($wind_dir $wind_v %wind_dir $wind); # XXX oben definieren
	if ($bp_obj && @weather_res && exists $BBBikeCalc::wind_dir{lc($weather_res[4])}) {
	    BBBikeCalc::analyze_wind_dir($weather_res[4]);
	    # XXX del: $wind = 1;
	    my $wind_v = $weather_res[7];
	    my(@path) = $r->path_list;
	    for(my $i = 0; $i < $#path; $i++) {
		my($x1, $y1) = @{$path[$i]};
		my($x2, $y2) = @{$path[$i+1]};
		my($deltax, $deltay) = ($x1-$x2, $y1-$y2);
		my $etappe = sqrt(BBBikeUtil::sqr($deltax) + BBBikeUtil::sqr($deltay));
		next if $etappe == 0;
# XXX feststellen, warum hier ein Minus stehen mu�...
		my $hw = -BBBikeCalc::head_wind($deltax, $deltay);
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
		    # XXX H�henberechnung nicht vergessen
		    # XXX Doppelung mit bbbike-Code vermeiden
		    my $bikepwr_time_etappe =
		      ( $etappe / bikepwr_get_v($wind, $power[$i]));
		    $bikepwr_time[$i] += $bikepwr_time_etappe;
		}
	    }
	}

	@strnames = $net->route_to_name($r->path);

	foreach my $speed (@speeds) {
	    if ($speed == 0) {
		$speed = $speed_default; # sane default
	    }
	    my $def = {};
	    $def->{Pref} = ($q->param('pref_speed') && $speed == $q->param('pref_speed')) ? "1" : "";
	    my $time;
	    if ($handicap_net) {
		$time = 0;
		my @realcoords = @{ $r->path };
		for(my $ii=0; $ii<$#realcoords; $ii++) {
		    my $s = Strassen::Util::strecke($realcoords[$ii],$realcoords[$ii+1]);
		    my @etappe_speeds = $speed;
## XXX warum ist das hier nicht aktiviert, sieht mir sinnvoll aus?
## XXX Aus dem RCS log: das hier war nie aktiv, kein Kommentar.
## XXX Antwort: weil qualitaet_s_speed nicht definiert ist
#		    if ($qualitaet_net && (my $cat = $qualitaet_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
#		    push @etappe_speeds, $qualitaet_s_speed{$cat}
#			if defined $qualitaet_s_speed{$cat};
#		}
		    if ($handicap_net && (my $cat = $handicap_net->{Net}{join(",",@{$realcoords[$ii]})}{join(",",@{$realcoords[$ii+1]})})) {
			push @etappe_speeds, $handicap_speed{$cat}
			    if defined $handicap_speed{$cat};
		    }
		    $time += ($s/1000)/min(@etappe_speeds);
		}
	    } else {
		$time = $r->len/1000/$speed;
	    }
	    $def->{_RawTime} = $time; # raw time without lost time due to penalties and trafficlights
	    $speed_map{$speed} = $def;
	}

	if ($bp_obj and $bikepwr_time[0]) {
	    for my $i (0 .. $#power) {
		$power_map{$power[$i]} = {_RawTime => $bikepwr_time[$i]/3600};
	    }
	}

	if (!defined $r->trafficlights && new_trafficlights()) {
	    $r->add_trafficlights($ampeln);
	}

	if ($with_comments) {
	    if (!$comments_net) {
		my @s;
		my @comment_files = qw(comments qualitaet_s);
		if ($scope eq 'region' || $scope eq 'wideregion') {
		    push @comment_files, "qualitaet_l";
		}
		if (@custom && grep { $_ =~ /^temp-blocking-/ } @custom &&
		    $custom_s{"handicap"}) {
		    push @s, $custom_s{"handicap"};
		} else {
		    push @comment_files, "handicap_s";
		    if ($scope eq 'region' || $scope eq 'wideregion') {
			push @comment_files, "handicap_l";
		    }
		}

		for my $s (@comment_files) {
		    eval {
			if ($s eq 'comments') {
			    for my $comment_file (map { "comments_$_" } grep { $_ ne "kfzverkehr" } @Strassen::Dataset::comments_types) {
				if ($comment_file eq 'comments_ferry') {
				    if ($q->param('pref_ferry') && $q->param('pref_ferry') eq 'use') {
					push @s, Strassen->new($comment_file, UseLocalDirectives => 1);
				    }
				} elsif ($comment_file eq 'comments_route') {
				    push @s, Strassen->new($comment_file, UseLocalDirectives => 1);
				} else {
				    push @s, Strassen->new($comment_file);
				}
			    }
			} elsif ($s =~ /^(qualitaet|handicap)/) {
			    my $old_s = Strassen->new($s);
			    my $new_s = $old_s->grepstreets
				(sub { $_->[Strassen::CAT] !~ /^[qQ]0/ },
				 -idadd => "q1234");
			    push @s, $new_s;
			} else {
			    push @s, Strassen->new($s);
			}
		    };
		    warn "$s: $@" if $@;
		}

		if (@s) {
		    $comments_net = StrassenNetz->new(MultiStrassen->new(@s));
		    $comments_net->make_net_cat(-obeydir => 1,
						-net2name => 1,
						-multiple => 1);
		}
	    }

	    if (!$sperre_tragen || !$sperre_narrowpassage) {
		eval {
		    my $special_vehicle = $q->param('pref_specialvehicle') || '';
		    $sperre_tragen = {};
		    $sperre_narrowpassage = {};
		    StrassenNetz::make_sperre_tragen('gesperrt', $special_vehicle, $sperre_tragen, $sperre_narrowpassage, -extended => 1);
		};
		warn $@ if $@;
	    }
	    @path = $r->path_list;
	}

	my($next_entf, $ges_entf_s, $next_winkel, $next_richtung, $next_richtung_html, $next_extra)
	    = (0, "", undef, "", "", undef);

	my $ges_entf = 0;
	for(my $i = 0; $i <= $#strnames; $i++) {
	    my $strname;
	    my $etappe_comment = '';
	    my $etappe_comment_html = '';
	    my $fragezeichen_comment = '';
	    my $entf_s = '';
	    my $raw_direction;
	    my $route_inx;
	    my $important_angle_crossing_name;
	    my($entf, $winkel, $richtung, $richtung_html, $extra)
		= ($next_entf, $next_winkel, $next_richtung, $next_richtung_html, $next_extra);
	    ($strname, $next_entf, $next_winkel, $next_richtung,
	     $route_inx, $next_extra) = @{$strnames[$i]};
	    $strname = Strasse::strip_bezirk_perfect($strname, $city);
	    if ($i > 0) {
		if (!$winkel) { $winkel = 0 }
		$winkel = int($winkel/10)*10;
		my $same_streetname_important_angle =
		    @out_route && $out_route[-1]->{Strname} eq $strname && $extra && $extra->{ImportantAngleCrossingName};
		if ($winkel < 30 && (!$extra || !$extra->{ImportantAngle})) {
		    $richtung = $richtung_html = "";
		    $raw_direction = "";
		} else {
		    if ($winkel >= 160 && $winkel <= 200) { # +/- 20� from 180�
			$richtung = $richtung_html = M('umdrehen');
			$raw_direction = 'u';
		    } else {
			$raw_direction =
			    ($winkel <= 45 ? 'h' : '') .
				($richtung eq 'l' ? 'l' : 'r');
			$richtung =
			    ($winkel <= 45 ? M('halb') : '') .
				($richtung eq 'l' ? M('links') : M('rechts')) .
				    " ($winkel�) ";
			if ($lang eq 'en') {
			    $richtung .= "-&gt;";
			} else {
			    if ($same_streetname_important_angle) {
				$richtung .= "weiter " . Strasse::de_artikel_dativ($strname);
			    } else {
				$richtung .= Strasse::de_artikel($strname);
			    }
			}
		    }
		    if ($is_m && !$bi->{cannot_unicode_arrows}) {
			$richtung_html = {'l'  => '&#x21d0;',
					  'hl' => '&#x21d6;',
					  'hr' => '&#x21d7;',
					  'r'  => '&#x21d2;',
					  'u'  => '&#x21b6;',
					 }->{$raw_direction};
		    } else {
			$richtung_html = $richtung;
		    }
		}
		if ($same_streetname_important_angle) {
		    $important_angle_crossing_name = Strasse::strip_bezirk($extra->{ImportantAngleCrossingName});
		}
		$ges_entf += $entf;
		$ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
		$entf_s = sprintf "%s%.2f km", ($is_m ? '' : M("nach") . " "), $entf/1000;
	    } elsif ($#{ $r->path } >= 1) {
		my($x1,$y1) = @{ $r->path->[0] };
		my($x2,$y2) = @{ $r->path->[1] };
		$raw_direction =
		    uc(BBBikeCalc::line_to_canvas_direction
		       ($x1,$y1,$x2,$y2));
		{
		    my $lang = $lang eq '' ? "de" : $lang;
		    if ($is_m) {
			$richtung =
			    BBBikeCalc::localize_direction_abbrev($raw_direction, $lang);
		    } else {
			$richtung = ($lang eq 'en' ? "towards" : "nach") . " " .
			    BBBikeCalc::localize_direction($raw_direction, $lang);
		    }
		}
		$richtung_html = $richtung;
	    }

	    if ($with_comments && $comments_net) {
		my @comment_objs;
		my %seen_comments_in_this_etappe;
		my %comments_in_whole_etappe;
		my %comments_at_beginning;
		my $is_first = 1;
		for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		    my @etappe_comment_inxs = $comments_net->get_point_comment(\@path, $i, undef, AsIndex => 1);

		    my %etappe_comments;
		    if (@etappe_comment_inxs) {
			my @etappe_comment_objs;
			for my $inx (@etappe_comment_inxs) {
			    my $etappe_comment_obj = $comments_net->{Strassen}->get($inx);
			    (my $name = $etappe_comment_obj->[Strassen::NAME()]) =~ s/^.+?:\s+//; # strip street;
			    my $dir = $comments_net->{Strassen}->get_directive($inx);
			    #                           Name   Object               URL (only first one)
			    push @etappe_comment_objs, [$name, $etappe_comment_obj, $dir->{url} ? $dir->{url}[0] : undef];
			}
			%etappe_comments = map {($_->[0],1)} @etappe_comment_objs;
			foreach my $etappe_comment_obj (@etappe_comment_objs) {
			    if (!exists $seen_comments_in_this_etappe{$etappe_comment_obj->[0]}) {
				push @comment_objs, $etappe_comment_obj;
				$seen_comments_in_this_etappe{$etappe_comment_obj->[0]}++;
			    }
			}
		    }
		    if ($is_first) {
			%comments_in_whole_etappe = %etappe_comments;
			%comments_at_beginning = %etappe_comments;
			$is_first = 0;
		    } else {
			while(my($k,$v) = each %comments_in_whole_etappe) {
			    if (!exists $etappe_comments{$k}) {
				delete $comments_in_whole_etappe{$k};
			    }
			}
		    }
		}

		for (@comment_objs) {
		    # Alle Kommentare, die sich nur auf Teilstrecken
		    # beziehen, bekommen ein Anh�ngsel. Ausnahme:
		    # PI-Anweisungen. Eigentlich m�sste alles, was
		    # sich in comments_path befindet, ausgenommen
		    # werden, aber ich bekomme zurzeit die Info nicht
		    # heraus.
		    if (!exists $comments_in_whole_etappe{$_->[0]}) {
			my $cat = $_->[1]->[Strassen::CAT()];
			if (#XXX del: ($cat =~ /^CP2/ && !exists $comments_at_beginning{$_->[0]}) || #XXX this looks simply too ugly (poin comment and (Teilstrecke), but I need to review all of comments_* to have good names instead, esp. including the crossing name at point
			    $cat !~ /^(CP2|PI|CP$|CP;)/) {
			    $_->[0] .= " (" . M("Teilstrecke") . ")";
			}
		    }
		}

		my @comments = map { $_->[0] } @comment_objs;
		my @comments_html = map {
		    if ($_->[2]) {
			'<a href="' . $_->[2] . '">' . $_->[0] . '</a>';
		    } else {
			$_->[0];
		    }
		} @comment_objs;

		{
		    my @penalty_comments_name;
		    my %penalty_comments_penalty;
		    my %penalty_comments_count;
		    for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
			my $point = join ",", @{ $path[$i] };
			for my $sperre_hash ($sperre_tragen, $sperre_narrowpassage) {
			    if (exists $sperre_hash->{$point}) {
				my($name, $penalty) = @{ $sperre_hash->{$point} };
				push @penalty_comments_name, $name;
				$penalty_comments_penalty{$name} += $penalty;
				$penalty_comments_count{$name}++;
				last; # anyway, no point should appear in tragen AND narrowpassage
			    }
			}
		    }

		    my %seen_penalty_name;
		    for my $penalty_name (@penalty_comments_name) {
			next if $seen_penalty_name{$penalty_name};
			$seen_penalty_name{$penalty_name} = 1;

			my $label = $penalty_name;
			if ($penalty_comments_count{$penalty_name} >= 2) {
			    $label .= ' (' . $penalty_comments_count{$penalty_name} . 'x)';
			}

			my $penalty = $penalty_comments_penalty{$penalty_name};
			if ($penalty == 0) {
			    $label .= " (" . M("kein Zeitverlust") . ")";
			} elsif ($penalty == 1) {
			    $label .= " (" . M("ca. eine Sekunde Zeitverlust") . ")";
			} elsif ($penalty < 120) {
			    $label .= " (" . sprintf(M("ca. %s Sekunden Zeitverlust"), $penalty) . ")";
			} else {
			    $label .= " (" . sprintf(M("ca. %s Minuten Zeitverlust"), int($penalty/60+0.5)) . ")";
			}
			push @comments, $label;
			push @comments_html, $label;
			$penalty_lost += $penalty;
		    }
		}
		# XXX Leere Kommentartexte explizit entfernen. Diese
		# gibt es z.B. in comments_cyclepath. Siehe auch
		# "comments_cyclepath handling" in TODO-bbbike.
		$etappe_comment = join("; ", grep { $_ ne "" } @comments) if @comments;
		$etappe_comment_html = join("; ", grep { $_ ne "" } @comments_html) if @comments_html;
	    }

	    if ($has_fragezeichen_routelist) {
		my @comments;
		my %seen_comments_in_this_etappe;
		for my $i ($strnames[$i]->[4][0] .. $strnames[$i]->[4][1]) {
		    my($from, $to) = (join(",", @{$path[$i]}),
				      join(",", @{$path[$i+1]}));
		    if (exists $fragezeichen_net->{Net}{$from}{$to}) {
			my($etappe_comment) = $fragezeichen_net->get_street_record($from, $to)->[Strassen::NAME()];
			if (!exists $seen_comments_in_this_etappe{$etappe_comment}) {
			    push @comments, $etappe_comment;
			    $seen_comments_in_this_etappe{$etappe_comment} = 1;
			}
		    }
		}
		$fragezeichen_comment = join("; ", @comments) if @comments;
	    }

	    my $hop_info =
		{
		 Dist => $entf,
		 DistString => $entf_s,
		 TotalDist => $ges_entf,
		 TotalDistString => $ges_entf_s,
		 Direction => $raw_direction,
		 DirectionString => $richtung,
		 DirectionHtml => $richtung_html,
		 Angle => $winkel,
		 Strname => $strname,
		 ImportantAngleCrossingName => $important_angle_crossing_name,
		 ($with_comments && $comments_net ?
		  (Comment => $etappe_comment,
		   CommentHtml => $etappe_comment_html,
		  ) : ()
		 ),
		 ($has_fragezeichen_routelist ?
		  (FragezeichenComment => $fragezeichen_comment) : () # XXX key label may change!
		 ),
		 Coord => join(",", @{$r->path->[$route_inx->[0]]}),
		 PathIndex => $route_inx->[0],
		};
	    push @out_route, $hop_info;
	}
	$ges_entf += $next_entf;
	$ges_entf_s = sprintf "%.1f km", $ges_entf/1000;
	my $entf_s = sprintf "%s%.2f km", ($is_m ? '' : M("nach") . " "), $next_entf/1000;
	push @out_route, {
			  Dist => $next_entf,
			  DistString => $entf_s,
			  TotalDist => $ges_entf,
			  TotalDistString => $ges_entf_s,
			  DirectionString => M("angekommen") . "!",
			  DirectionHtml => ($is_m ? "" : M("angekommen") . "!"), # save column space in m.bbbike.de
			  Strname => $real_zielname,
			  Comment => '',
			  CommentHtml => '',
			  Coord => join(",", @{$r->path->[-1]}),
			  PathIndex => $#{$r->path},
			 };

	my $ampel_lost = (defined $r->trafficlights
			  ? $r->trafficlights * 15 # XXX do not hardcode 15s here!
			  : 0
			 );

	# Adjust _RawTime -> Time
	while(my($k,$v) = each %speed_map) {
	    $v->{Time} = $v->{_RawTime} + $ampel_lost/3600 + $penalty_lost/3600;
	    delete $v->{_RawTime};
	}
	if (%power_map) {
	    while(my($k,$v) = each %power_map) {
		$v->{Time} = $v->{_RawTime} + $ampel_lost/3600 + $penalty_lost/3600;
		delete $v->{_RawTime};
	    }
	}
    }

    my @affecting_blockings;
    if (@current_temp_blocking && !$printmode) {
    TEMP_BLOCKING:
	for my $tb (@current_temp_blocking) {
	    my $net         = $tb->{net}{Net};
	    my $wegfuehrung = $tb->{net}{Wegfuehrung};

	    my(@path) = $r->path_list;
	    for(my $i = 0; $i < $#path; $i++) {
		my($x1, $y1) = @{$path[$i]};
		my($x2, $y2) = @{$path[$i+1]};
		my $xy1 = "$x1,$y1";
		my $xy2 = "$x2,$y2";

		# Handling "1"/"2" and "qX" types
		if ($net->{$xy1}{$xy2}) {
		    push @affecting_blockings, $tb;
		    $tb->{lost_time}{$velocity_kmh} = lost_time($r, $tb, $velocity_kmh);
		    $tb->{hop} = [$xy1, $xy2];
		    next TEMP_BLOCKING;
		}

		# Handling "3" (wegfuehrung) types
		if ($wegfuehrung && exists $wegfuehrung->{$xy2}) {
		    for my $wegfuehrung (@{ $wegfuehrung->{$xy2} }) {
		    CHECK_WEGFUEHRUNG: {
			    for(my $j=0; $j<$#$wegfuehrung; $j++) {
				last CHECK_WEGFUEHRUNG
				    if ($j > $i || join(",",@{$path[$i-$j]}) ne $wegfuehrung->[$#$wegfuehrung-1-$j]);
			    }
			    push @affecting_blockings, $tb;
			    $tb->{hop} = [$xy1, $xy2];
			    next TEMP_BLOCKING;
			}
		    }
		}
	    }
	}
    }

 OUTPUT_DISPATCHER:
    if (defined $output_as && $output_as =~ /^(xml|yaml|yaml-short|json|json-short|geojson|geojson-short|perldump|gpx-route)$/) {
	for my $tb (@affecting_blockings) {
	    $tb->{longlathop} = [ map { join ",", convert_data_to_wgs84(split /,/, $_) } @{ $tb->{hop} || [] } ];
	}
	for my $route_item (@out_route) {
	    my $coord = $route_item->{Coord};
	    if ($coord) {
		$route_item->{LongLatCoord} = join ",", convert_data_to_wgs84(split /,/, $coord);
	    }
	}

	my $res;
	if ($r && $r->path) {
	    # remove Net and Strassen objects here, keep only essentials
	    my @affecting_blockings_essentials = map {
		+{
		  Text       => $_->{text},
		  Index      => $_->{index},
		  Type       => $_->{type},
		  LongLatHop => { XY => $_->{longlathop} },
		  Recurring  => $_->{recurring} ? 1 : 0,
		 }
	    } @affecting_blockings;

	    $res = {
		   Route => \@out_route,
		   Len   => $r->len, # in meters
		   Trafficlights => $r->trafficlights,
		   Speed => \%speed_map,
		   Power => \%power_map,
		   ($sess ? (Session => $sess->{_session_id}) : ()),
		   Path => [ map { join ",", @$_ } @{ $r->path }],
		   LongLatPath => [ map {
		       join ",", convert_data_to_wgs84(@$_)
		   } @{ $r->path }],
		   AffectingBlockings => \@affecting_blockings_essentials,
		  };
	} else {
	    $res = {
		    Error => 'No route found',
		    LongLatPath => [],
		  };
	}
	if ($output_as eq 'perldump') {
	    require Data::Dumper;
	    my $filename = filename_from_route($startname, $zielname) . ".txt";
	    http_header
		(-type => "text/plain",
		 @weak_cache,
		 -Content_Disposition => "attachment; filename=$filename",
		);
	    print Data::Dumper->new([$res], ['route'])->Dump;
	} elsif ($output_as =~ /^yaml(.*)/) {
	    require BBBikeYAML;
	    my $is_short = $1 eq "-short";
	    my $yaml_dump = sub { BBBikeYAML::Dump(@_) };
	    my $filename = filename_from_route($startname, $zielname) . ".yml";
	    http_header
		(-type => "application/x-yaml",
		 @weak_cache,
		 -Content_Disposition => "attachment; filename=$filename",
		);
	    if ($is_short) {
		my $short_res = {LongLatPath => $res->{LongLatPath}};
		print $yaml_dump->($short_res);
	    } else {
		print $yaml_dump->($res);
	    }
	} elsif ($output_as =~ /^json(.*)/) {
	    my $is_short = $1 eq '-short';
	    require JSON::XS;
	    my @headers =
		(-type => "application/json",
		 @weak_cache,
		 cors_handling(),
		);
	    http_header(@headers);
	    my $json_output;
	    if ($is_short) {
		my $short_res = {LongLatPath => $res->{LongLatPath}};
		# XXX I think a temp_blockings-containing object might
		# go into the dump, which would cause JSON::XS to
		# fail. Maybe I should create a TO_JSON converter, or
		# just leave it as is (that is, allow the blessed
		# object to be converted to null)
		$json_output = JSON::XS->new->utf8->allow_blessed(1)->encode($short_res);
	    } else {
		$json_output = JSON::XS->new->utf8->allow_blessed(1)->encode($res);
	    }
	    print $json_output;
	    if ($cache_entry) {
		$cache_entry->put_content($json_output, {_additional_filecache_info($q), headers => \@headers});
	    }
	} elsif ($output_as =~ m{^geojson(-short)?$}) {
	    my $is_short = !!$1;
	    http_header
		(-type => "application/json",
		 @weak_cache,
		 cors_handling(),
		);
	    require BBBikeGeoJSON;
	    print BBBikeGeoJSON::bbbikecgires_to_geojson_json($res, short => $is_short);
	} elsif ($output_as eq 'gpx-route') {
	    require Strassen::GPX;
	    my $filename = filename_from_route($startname, $zielname) . ".gpx";
	    my @headers =
		(-type => "application/gpx+xml",
		 -Content_Disposition => "attachment; filename=$filename",
		);
	    http_header(@headers);
	    my @data;
	    my $gps_routenamelength = 36; # good for modern devices XXX should this be configurable?
	    my $gps_routename = $zielname . ' ' . ($lang eq 'en' ? 'from' : 'von') . ' ' . $startname; # XXX Msg
	    $gps_routename = substr($gps_routename, 0, $gps_routenamelength-3).'...' if length $gps_routename > $gps_routenamelength;
	    my $s = Strassen->new_from_data_string(
						   "#: title: $gps_routename\n\n" .
						   join('', map { $_->{Strname} . "\tX " . $_->{Coord} . "\n" } @out_route)
						  );
	    my $s_gpx = Strassen::GPX->new($s);
	    $s_gpx->{"GlobalDirectives"}->{"map"}[0] = "polar" if $data_is_wgs84;
	    my $gpx_output = $s_gpx->bbd2gpx(-as => "route");
	    print $gpx_output;
	    if ($cache_entry) {
		$cache_entry->put_content($gpx_output, {_additional_filecache_info($q), headers => \@headers});
	    }
	} else { # xml
	    require XML::Simple;
	    my $filename = filename_from_route($startname, $zielname) . ".xml";
	    http_header
		(-type => 'application/xml',
		 @weak_cache,
		 -Content_Disposition => "attachment; filename=$filename",
		 cors_handling(),
		);
	    my $new_res = {};
	    while(my($k,$v) = each %$res) {
		if ($k eq 'Path' || $k eq 'LongLatPath') {
		    $new_res->{$k} = { XY => $v };
		} elsif ($k eq 'Route') {
		    $new_res->{$k} = { Point => $v };
		} elsif ($k eq 'AffectingBlockings') {
		    # just a rename from plural to singular
		    $new_res->{"AffectingBlocking"} = $v;
		} else {
		    $new_res->{$k} = $v;
		}
	    }

	    my $xml_encoding = 'iso-8859-1';
            if ($use_utf8) {
	        binmode STDOUT, ":utf8";
		$xml_encoding = 'UTF-8';
            }

	    print XML::Simple->new
		(NoAttr => 1,
		 RootName => "BBBikeRoute",
		 XMLDecl => "<?xml version='1.0' encoding='$xml_encoding' standalone='yes'?>",
		 SuppressEmpty => 1, # e.g. Trafficlights may be undefined
		)->XMLout($new_res);
	}
	return;
    }

    %persistent = get_cookie();
    foreach my $key (@pref_keys) {
	$persistent{"pref_$key"} = $q->param("pref_$key");
	if (!defined $persistent{"pref_$key"}) {
	    #$persistent{"pref_$key"} = "";
	    delete $persistent{"pref_$key"};
	}
    }
    my $cookie = set_cookie({ %persistent });

    http_header(@weak_cache,
		-cookie => $cookie,
	       );
    my %header_args;
##XXX die Idee hierbei war: table.background ist bei Netscape der Hintergrund
## ohne cellspacing, w�hrend es beim IE mit cellspacing ist. Also f�r
## jedes td bgcolor setzen. Oder besser mit Stylesheets arbeiten. Nur wie,
## wenn man nicht f�r jedes td die Klasse setzen will?
#     if ($can_css) {
# 	$header_args{'-style'} = <<EOF;
# <!--
# $std_css
# td { background:#ffcc66; }
# -->
# EOF
#     }
    $header_args{-script} = bbbike_result_js();
    $header_args{-printmode} = 1 if $printmode;
    header(%header_args, -onLoad => "init_search_result()");

 ROUTE_HEADER:
    if (!@out_route) {
	if (@custom) {
	    print "<center>";
	    print M("Es existiert keine Ausweichroute.")."\n";
	    my $qq = CGI->new($q->query_string);
	    $qq->delete('custom');
	    print qq{<a href="$bbbike_script?} . $qq->query_string . qq{">} . M("Zur�ck") . qq{</a>\n};
	    print "</center>\n";
	} else {
	    print M("Keine Route gefunden").".\n";
	    warn "Fehler: keine Route zwischen <$startname>" . ($vianame ? ", <$vianame>" : "") . " und <$zielname> gefunden, sollte niemals passieren";
	}
	$in_error_condition = 1;
    } else {
	if (@affecting_blockings) {
	    my $hidden = "";
	    foreach my $key ($q->param) {
		$hidden .= $q->hidden(-name => $key,
				      -default => [BBBikeCGI::Util::my_multi_param($q, $key)]);
	    }
	    print qq{<form class="altroutebox" name="Ausweichroute" action="} .
		BBBikeCGI::Util::my_url($q) . qq{" } . (@affecting_blockings > 1 ? qq{onSubmit="return test_temp_blockings_set()"} : "") . qq{>};
	    print $hidden;
	    if ($sess) {
		print $q->hidden(-name    => 'oldcs',
				 -default => $sess->{_session_id},
				);
	    }
	    print "<b>" . M("Ereignisse, die die Route betreffen k&ouml;nnen") . "</b>:<br>";
	    for my $tb (@affecting_blockings) {
		my $lost_time_info = $tb->{lost_time}{$velocity_kmh};
		print qq{<input};
		if (@affecting_blockings > 1) {
		    print qq{ type="checkbox" checked};
		} else {
		    print qq{ type="hidden"}
		};
		print qq{ name="custom" value="temp-blocking-$tb->{'index'}"> };
		print _linkify($tb->{text});
		if ($lost_time_info && $lost_time_info->{lost_time_string_de}) {
		    print " ($lost_time_info->{lost_time_string_de})";
		}
		print "<br>";
	    }
	    print <<EOF;
<input type=submit value="@{[ M("Ausweichroute suchen") ]}">
</form><p>
EOF
	}
	if (@custom && !$printmode) {
	    print "<center>";
	    my $diff_info = diff_from_old_route($r);
	    if ($diff_info->{different}) {
		print M("M�gliche Ausweichroute") . " ";
		print $diff_info->{difference} if $diff_info->{difference};
	    } else {
		print M("Eine bessere Ausweichroute wurde nicht gefunden");
	    }
	    print "</center>\n";
	}

    ROUTE_TABLE:
	print "<center>" unless $printmode;
	print qq{<table id="routehead" bgcolor="#ffcc66"};
	if ($printmode) {
	    print " width='$printwidth'";
	}
	my $can_jslink = $can_mapserver && !$printmode && $bi->{'can_javascript'};
	print "><tr><td>";
	if ($routetitle) {
	    print "<b>" . CGI::escapeHTML($routetitle) . "</b>";
	} elsif (!$zielname) {
	    if (!$startname) {
		print "<b>" . M("Route") . "</b>";
	    } else {
		print "<b>" . CGI::escapeHTML($startname) . "</b>";
	    }
	} else {
	    print M("Route von") . " <b>" .
		coord_or_stadtplan_link($startname, $startcoord,
					$q->param('startplz')||"",
					$q->param('startisort')?1:0,
					(defined $starthnr && $starthnr ne '' ? $starthnr : undef),
					-jslink => $can_jslink,
				       )
		    . "</b> ";
	    if (defined $vianame && $vianame ne '') {
		print M("&uuml;ber") . " <b>" .
		    coord_or_stadtplan_link($vianame, $viacoord,
					    $q->param('viaplz')||"",
					    $q->param('viaisort')?1:0,
					    (defined $viahnr && $viahnr ne '' ? $viahnr : undef),
					    -jslink => $can_jslink,
					   )
			. "</b> ";
	    }
	    print M("bis") . " ";
	    if ($r && $r->nearest_node) {
		print "<b>" . coord_or_stadtplan_link($real_zielname, $r->nearest_node,
						      "", 0, undef,
						      -jslink => $can_jslink,
						     ) . "</b>";
		# XXX richtigen Artikel statt => einsetzen
		print " (" . M("Entfernung") . " => $zielname: " . int(Strassen::Util::strecke_s($zielcoord, $r->nearest_node)) . "m)";
	    } else {
		print "<b>" . coord_or_stadtplan_link($real_zielname, $zielcoord,
						      $q->param('zielplz')||"",
						      $q->param('zielisort')?1:0,
						      (defined $zielhnr && $zielhnr ne '' ? $zielhnr : undef),
						      -jslink => $can_jslink,
						     ) . "</b>";
	    }
	}
	print "</td></tr></table><br>\n";
	print "<table";
	if ($printmode) {
	    print " width='$printwidth'";
	}
	print ">\n";
	printf "<tr><td>@{[ M('L&auml;nge') ]}:</td><td>%.2f km</td>\n", $r->len/1000;
	print
	  "<tr><td>@{[ M('Fahrzeit') ]}:</td>";

	my $ampel_count;
	if (defined $r->trafficlights) {
	    $ampel_count = $r->trafficlights;
	}
	{
	    my $i = 0;
	    my @speeds = sort { $a <=> $b } keys %speed_map;
	    for my $speed (@speeds) {
		my $def = $speed_map{$speed};
		my $bold = $def->{Pref};
		my $time = $def->{Time};
		print "<td>" . make_time($time)
		    . "h (" . ($bold ? "<b>" : "") . M("bei")." $speed km/h" . ($bold ? "</b>" : "") . ")";
		print "," if $speed != $speeds[-1];
		print "</td>";
		if ($i == 1) {
		    print "</tr><tr><td></td>";
		}
		$i++;
	    }
	}
	print "</tr>\n";
	if (%power_map) {
	    print "<tr><td></td>";
	    my $is_first = 1;
	    for my $power (sort { $a <=> $b } keys %power_map) {
		my $def = $power_map{$power};
		my $time = $def->{Time};
		print "<td>";
		if (!$is_first) {
		    print ",";
		} else {
		    $is_first = 0;
		}
		print make_time($time) . "h (" . M("bei") . " $power W)", "</td>"
	    }
	    print "</tr>\n";
	}
	print "</table>\n";
	if (defined $ampel_count) {
	    if ($ampel_count == 0) {
		print M("Keine Ampeln");
	    } else {
		print $ampel_count . " " . M("Ampel" . ($ampel_count == 1 ? "" : "n"));
	    }
	    print " " . M("auf der Strecke");
	    if ($ampel_count) {
		print " (" . M("in die Fahrzeit einbezogen") . ")";
	    }
	    print ".<br>\n";
	}
	print "</center>\n" unless $printmode;
	print "<hr>";

	my $line_fmt;
	if (!$bi->{'can_table'}) {
	    $with_comments = 0;
	    if ($bi->{'mobile_device'}) {
		$line_fmt = "%s %s %s (ges.:%s)\n";
	    } else {
		$line_fmt = "%-13s %-24s %-31s %-8s";
##XXX does not work:
# 		if ($has_fragezeichen_routelist && !$printmode) {
# 		    $line_fmt .= " %s";
# 		}
		$line_fmt .= "\n";
	    }
	    print "<pre>";
	} else {
	    # Ist width=... bei Netscape4 buggy? Das nachfolgende Attribut
	    # ignoriert font-family.
	    #   width=\"90%\"
	    print q{<center>} unless $printmode;
	    print q{<table cellspacing="0" cellpadding="0" class='routelist};
	    #print q{<table  class='routelist};
	    if ($printmode) {
		print " print";
	    }
	    print "' id='routelist' ";
	    if ($printmode) {
#		print ' style="border: 1px solid black;"';
#		print " border=1"; # XXX ohne geht's leider nicht
		print " width='$printtablewidth'";
	    } else {
		print " align=center";
		if (1 || !$bi->{'can_css'}) { # XXX siehe Kommentar oben (css...)
#		    print ' XXXbgcolor="#ffcc66" style="background-color:#ffcc66; border-style:solid; border:white; border-width:1px;" ';
		    print ' bgcolor="#ffcc66" ';
		}
	    }
	    print "><tr><th>" . M("Etappe") . "</th><th>" . ($is_m ? M("Richt.") : M("Richtung")) . "</th><th>" . M("Stra&szlig;e") . "</th><th>" . M("Gesamt") . "</th>";
	    if ($with_comments) {
		print "<th" . ($with_cat_display && !$printmode ? " colspan=4" : "") .
	              ">" . M("Bemerkungen") . "</th>";
	    }
	    if ($has_fragezeichen_routelist && !$printmode) {
		print "<th></th>"; # no header for Fragezeichen
	    }
	    print "</tr>\n";
	}

	if ($with_cat_display && !$radwege_net) {
	    $radwege_net = new StrassenNetz get_cyclepath_streets();
	    $radwege_net->make_net_cat;
	}

	my %cat_to_title = ( NN => M("Weg ohne Kfz"),
			     N  => M("Nebenstra�e"),
			     NH => M("wichtige Nebenstra�e"),
			     H  => M("Hauptstra�e"),
			     HH => M("wichtige Hauptstra�e"),
			     B  => M("Bundesstra�e"),
			     fz => M("unbekannte Strecke"),
			     Q  => M("F�hre"),
			   );
	my %rw_to_title = ( RW => M("Radweg"),
			    RS => M("Radspur"),
			    FS => M("Fahrradstra�e"),
			    BS => M("Busspur"),
			    NF => M("Nebenfahrbahn"),
			  );

  	my $odd = 0;
	my $etappe_i = -1;
	for my $etappe (@out_route) {
	    $etappe_i++;
	    my($entf, $richtung_html, $strname, $important_angle_crossing_name, $ges_entf_s,
	       $etappe_comment_html, $fragezeichen_comment, $path_index) =
		   @{$etappe}{qw(DistString DirectionHtml Strname ImportantAngleCrossingName TotalDistString CommentHtml FragezeichenComment PathIndex)};
	    my $last_path_index;
	    if ($etappe_i < $#out_route) {
		$last_path_index = $out_route[$etappe_i+1]->{PathIndex} - 1;
	    }
	    if (!$bi->{'can_table'}) {
		printf $line_fmt,
		    $entf, $richtung_html, string_kuerzen($strname, 31), $ges_entf_s;
	    } else {
		print "<tr class=" . ($odd ? "odd" : "even") . "><td nowrap>$entf</td><td" . ($is_m ? " align='center'" : "") . ">$richtung_html</td><td>";
		print "<a class=ms href='#' onclick='return ms($etappe->{Coord})'>"
		    if $can_jslink;
		print $strname;
		if ($important_angle_crossing_name && $important_angle_crossing_name ne $strname) {
		    print " (" . M("Ecke") . " " . $important_angle_crossing_name . ")";
		}
		print "</a>"
		    if $can_jslink;
		print "</td><td nowrap>$ges_entf_s</td>";
		$odd = 1-$odd;
		if ($with_comments && $comments_net) {
		    if ($with_cat_display && !$printmode) {
			# Es wird jeweils die l�ngste
			# Stra�en/Radwegekategorie f�r die Anzeige
			# verwendet.
			my($cat, $rw);
			if (defined $last_path_index) {
			    my %cat_length; # str_cat -> length
			    my %rw_length;  # rw_cat -> length
			    for my $path_i ($path_index .. $last_path_index) {
				my $p1 = join(",", @{$r->path->[$path_i]});
				my $p2 = join(",", @{$r->path->[$path_i+1]});
				my $len = Strassen::Util::strecke_s($p1, $p2);
				my $rec = $net->get_street_record($p1, $p2);
				if ($rec) {
				    my $cat = $rec ? $rec->[Strassen::CAT] : '';
				    if ($cat =~ /^\?/) {
					$cat = 'fz';
				    }
				    $cat_length{$cat} += $len;
				}
				if ($radwege_net) {
				    my $rw;
				    my $rw_rec = $radwege_net->{Net}->{$p1}->{$p2};
				    if ($rw_rec) {
					if ($rw_rec =~ /^RW([1289])?$/) {
					    $rw = "RW";
					} elsif ($rw_rec =~ m{^RW[34]$}) {
					    $rw = "RS";
					} elsif ($rw_rec eq 'RW7') {
					    $rw = 'FS';
					} elsif ($rw_rec eq 'RW5') {
					    $rw = "BS"; # Busspur
					} elsif ($rw_rec eq 'RW10') {
					    $rw = "NF"; # Nebenfahrbahn
					}
				    }
				    $rw_length{$rw} += $len;
				}
			    }
			    ($cat) = sort { $cat_length{$b} <=> $cat_length{$a} } keys %cat_length;
			    ($rw)  = sort { $rw_length{$b}  <=> $rw_length{$a}  } keys %rw_length;
			}
			if ($cat) {
			    my $cat_title = $cat_to_title{$cat};
			    my $rw_title;
			    if ($rw) {
				$rw_title = $rw_to_title{$rw};
			    }
			    my $title = $cat_title;
			    if ($rw_title) {
				$title .= ", $rw_title";
			    }
			    print "<td></td><td title='$title' class='cat$cat catcell$rw'></td><td></td>";
			} else {
			    print "<td></td><td></td><td></td>";
			}
		    }
		    print "<td>$etappe_comment_html</td>";
		}
		if ($has_fragezeichen_routelist && !$printmode) {
		    if (defined $fragezeichen_comment && $fragezeichen_comment ne "") {

			# unbekannt oder unvollst�ndig
			my $is_unknown = 1;
			my $rec;
			if ($path_index < $#{ $r->path }) {
			    $rec = $net->get_street_record(join(",", @{$r->path->[$path_index]}),
							   join(",", @{$r->path->[$path_index+1]}));
			}
			if ($rec && $rec->[Strassen::CAT] !~ /^\?/) {
			    $is_unknown = 0;
			}			

			my $qs = CGI->new({strname => $fragezeichen_comment,
					   strname_html => CGI::escapeHTML($fragezeichen_comment),
					   supplied_coord => join(",", @{$r->path->[$path_index]}),
					  })->query_string;
			print qq{<td><a target="newstreetform" href="$bbbike_html/shortfragezeichenform${newstreetform_encoding}.html?$qs">};
			if ($is_unknown) {
			    print qq{Unbekannte Stra�e};
			} else {
			    print qq{Unvollst�ndige Daten};
			}
			print qq{, Kommentar eintragen</a></td>};
		    } else {
			print qq{<td>&nbsp;</td>};
		    }
		}
		print "</tr>\n";
	    }
	}

	if ($bi->{'can_table'}) {
	    print "</table>\n";
	    print "</center>\n" unless $printmode;
	}

	my($bbbikeleaflet_url, $bbbikeleaflet_loc_url);
	if (!$printmode && $sess && $apache_session_module eq 'Apache::Session::Counted') {
	    my $href = _bbbikeleaflet_url();
	    $bbbikeleaflet_url     = $href . '?' . CGI->new({coordssession => $sess->{_session_id}})->query_string;
	    $bbbikeleaflet_loc_url = $href . '?' . CGI->new({coordssession => $sess->{_session_id}, loc => 1})->query_string;
	}

	if (!$printmode) {
	    my $col_i = 0;
	    my $maybe_do_table_br = sub {
		return if !$is_m;
		$col_i++;
		if ($col_i >= 3) {
		    print table_br();
		    $col_i = 1;
		}
	    };

	    print qq{<div class="box" style="font-size:smaller;">};
	    print qq{<table} . (!$is_m ? qq{ class="routeas"} : "") . qq{><tr>};
	    print qq{<td><b style="font-size:larger;">} . M("Route als") . ":</b></td>";
	    $maybe_do_table_br->();

	    if ($is_printable) {
		print "<td>";
		{
		    my $qq_normal = CGI->new($q->query_string);
		    $qq_normal->param('output_as', "print");
		    $qq_normal->param('printvariant', "normal");
		    print
			"<a style='padding-right:10px;' title='" . M("Druckvorlage normal") . "' target=printwindow href=\"$bbbike_script?" . $qq_normal->query_string . "\">" .
			"<img src=\"$bbbike_images/printer.gif\" " .
			"width=16 height=16 border=0 alt='" . M("Druckvorlage normal") . "'></a>";
		}
		{
		    my $qq_narrow = CGI->new($q->query_string);
		    $qq_narrow->param('output_as', "print");
		    print
			"<a title='" . M("Druckvorlage schmal") . "' target=printwindow href=\"$bbbike_script?" . $qq_narrow->query_string . "\">" .
			"<img src=\"$bbbike_images/printer_narrow.gif\" " .
			"width=16 height=16 border=0 alt='" . M("Druckvorlage schmal") . "'></a>";
		}
		print "</td>";
		$maybe_do_table_br->();
	    }
	    if ($can_gpx) {
		print "<td>";
		{
		    my $qq2 = CGI->new($q->query_string);
		    $qq2->param('output_as', "gpx-route");
		    my $href = $bbbike_script . '?' . $qq2->query_string;
		    print qq{<a href="$href">GPX (Route)</a>};
		    if ($is_beta) {
			print add_qrcode_html($href, 'GPX Route');
		    }
		}
		print "</td>";
		$maybe_do_table_br->();
		print "<td>";
		{
		    my $qq2 = CGI->new($q->query_string);
		    $qq2->param('output_as', "gpx-track");
		    my $href = $bbbike_script . '?' . $qq2->query_string;
		    print qq{<a href="$href">GPX (Track)</a>};
		    if ($is_beta) {
			print add_qrcode_html($href, 'GPX Track');
		    }
		}
		print "</td>";
		$maybe_do_table_br->();
	    }
	    if ($can_kml) {
		print "<td>";
		my $qq2 = CGI->new($q->query_string);
		$qq2->param('output_as', "kml-track");
		my $href = $bbbike_script . '?' . $qq2->query_string;
		print qq{<a title="view route with Google Earth" href="$href">KML (Google Earth)</a>};
		if ($is_beta) {
		    print add_qrcode_html($href, 'KML');
		}
		print "</td>";
		$maybe_do_table_br->();
	    }
	    if ($can_palmdoc && !$is_m && $bi->{'user_agent_os'} !~ m{^(iOS)$}) {
		print "<td>";
		my $qq2 = new CGI $q->query_string;
		$qq2->param('output_as', "palmdoc");
		my $href = $bbbike_script;
	        print qq{<a href="$href?} . $qq2->query_string . qq{">PalmDoc</a>};
		print "</td>";
		$maybe_do_table_br->();
	    }
	    if ($bbbikeleaflet_url) {
		print "<td>";
	        print qq{<a href="$bbbikeleaflet_url">Leaflet<img style="vertical-align:bottom;" src="$bbbike_images/bbbike_leaflet_16.png" border="0" alt=""></a>};
		if ($is_beta) {
		    print add_qrcode_html($bbbikeleaflet_loc_url, 'BBBikeLeaflet');
		}
		print "</td>";
		$maybe_do_table_br->();
	    }
	    if (0) { # XXX not yet
		print "<td>";
		my $qq2 = CGI->new({});
		$qq2->param("query", $q->query_string);
		my $href = "bbbike_comment.cgi";
		print qq{<a target="BBBikeComment" href="$href?} . $qq2->query_string . qq{">Kommentar zur Route</a>};
		print "</td>";
		$maybe_do_table_br->();
	    }
	    print qq{</tr></table></div>};
	}

	if ($printmode) {
	    print
	      "<hr><br>", 
	      "BBBike by Slaven Rezic: ",
	      "<a href=\"$bbbike_url\">$bbbike_url</a><br>\n",
	      "<script type=\"text/javascript\"><!--\nprint();\n",
              "// --></script>\n";
	    goto END_OF_HTML;
	}

	if (!$bi->{'mobile_device'}) {
	    my $string_rep = $r->as_cgi_string;
            # XXX Mit GET statt POST gibt es zwar einen h��lichen GET-String
	    # und vielleicht k�nnen lange Routen nicht gezeichnet werden,
	    # daf�r gibt es keine Cache-Probleme mehr.
	    # (M�glicher Fix: timestamp mitschicken)
	    # Weiterer Vorteil: die Ergebnisse werden auch im accesslog
	    # aufgezeichnet. Ansonsten muesste ich ein weiteres Logfile
	    # anlegen.
	    my $post_bug = 1; # XXX f�r alle aktivieren
	    #print "<hr>";
	    print qq{<div class="box">};
	    print "<form name=showmap method=" .
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


	    if (!$bi->{'no_new_windows'}) {
		print " target=\"_blank\"";
	    }
	    print " action=\"$bbbike_script\"";
	    if ($bbbikeleaflet_url) {
  		print " onsubmit='return show_map({leaflet_url:\"$bbbikeleaflet_url\"});'";
  	    }
	    print ">\n";
	    print "<input type=hidden name=center value=''>\n";
#XXX not yet	    print "<input type=hidden name='as_attachment' value=''>\n";
	    print qq{<input type=submit name=interactive value="@{[ M("Karte zeigen") ]}">};
	    if (!$is_m) {
		print qq{ <span style="font-size:smaller;">(@{[ M("neues Fenster wird ge&ouml;ffnet") ]})</span>};
	    }
	    if ($is_printable) {
	        print " <label><input type=checkbox name=outputtarget value='print' " . ($default_print?"checked":"") . "> " . M("f&uuml;r Druck optimieren") . "</label>";
	    }
#XXX not yet	    print " <input type=checkbox name='cb_attachment'> als Download";
	    print "&nbsp;&nbsp; <span class=nobr>" . M("Ausgabe als") . ": <select name=imagetype " . ($bi->{'can_javascript'} ? "onchange='enable_size_details_buttons()'" : "") . ">\n";
	    print " <optgroup label=\"" . M("Statische Karte") . ":\">\n";
	    print " <option " . $imagetype_checked->("png") . ">PNG\n" if $graphic_format eq 'png';
	    print " <option " . $imagetype_checked->("gif") . ">GIF\n" if ($graphic_format eq 'gif' || $can_gif) && !$is_m;
	    print " <option " . $imagetype_checked->("jpeg") . ">JPEG\n" if !$cannot_jpeg && !$is_m;
	    print " <option " . $imagetype_checked->("wbmp") . ">WBMP\n" if $can_wbmp && !$is_m;
	    print " <option " . $imagetype_checked->("pdf-auto") . ">PDF\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("pdf") . ">PDF (" . M("L�ngsformat") . ")\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("pdf-landscape") . ">PDF (" . M("Querformat") . ")\n" unless $cannot_pdf;
	    print " <option " . $imagetype_checked->("svg") . ">SVG\n" if !$cannot_svg && !$is_m;
	    #XXX print " <option " . $imagetype_checked->("googlemapsstatic") . ">Google Maps (static)\n" if 1;#XXXXXXXXXXXXXXXXXX
	    print " </optgroup>\n";
	    print " <optgroup label=\"" . M("Interaktive Karte") . ":\">\n";
	    print " <option " . $imagetype_checked->('leaflet') . ">BBBike/OSM (Leaflet)\n" if $bbbikeleaflet_url;
	    print " <option " . $imagetype_checked->("mapserver") . ">MapServer\n" if $can_mapserver;
	    print " <option " . $imagetype_checked->("googlemaps") . ">Google Maps\n" if $can_google_maps;
	    print " </optgroup>\n";
	    print " </select></span>\n";
	    print "<br>\n";

	    if ($sess) {
		$sess->{routestringrep} = $string_rep;
		$sess->{route} = \@out_route;
		print "<input type=hidden name=coordssession value=\"$sess->{_session_id}\">";
		my $sessdir = "/var/tmp/coordssession";
		mkdir $sessdir if !-d $sessdir;
		chmod 0777, $sessdir;
		if (open(SESS, ">> $sessdir/" . $sess->{_session_id})) {
		    require Data::Dumper;
		    print SESS Data::Dumper::Dumper
			({ date           => scalar(localtime),
			   time           => time,
			   routestringrep => $string_rep,
			   route          => \@out_route,
			   remote_ip      => $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR},
			   user_agent     => $ENV{HTTP_USER_AGENT},
			   prefs          => { map { ($_ => scalar $q->param($_)) } grep { /^pref_/ } $q->param },
			 });
		    close SESS;
		}
		untie %$sess;
		if (defined $q->param('oldcs')) {
		    print $q->hidden(-name    => 'oldcs',
				     -default => scalar $q->param('oldcs'));
		}
 	    } else {
		print "<input type=hidden name=coords value=\"$string_rep\">";
	    }

	    print "<input type=hidden name=startname value=\"" .
		CGI::escapeHTML($startname) . "\">";
	    print "<input type=hidden name=zielname value=\"" .
		CGI::escapeHTML($zielname)  . "\">";
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

            my @not_for;
	    push @not_for, "PDF" if !$cannot_pdf;
	    push @not_for, "SVG" if !$cannot_svg;
	    push @not_for, "Mapserver" if $can_mapserver;
	    print "<table><tr valign=top><td><b>" . M("Bildgr&ouml;&szlig;e") . ":</b></td>\n";
	    my @geoms = ("400x300",
			 "640x480",
			 ($is_m ? "-" : ()),
			 "800x600",
			 "1024x768",
			);
	    foreach my $geom (@geoms) {
		if ($geom eq '-') {
		    print table_br();
		    next;
		}
		print
		    qq{<td><label><input type="radio" name="geometry" value="$geom"},
		    ($geom eq $default_geometry ? " checked" : ""),
		    qq{> $geom </label></td>\n};
	    }
	    if (!$is_m) {
	        if (@not_for) {
		    print "<td valign=bottom><small>(" . M("nicht f�r") . ": " . join(", ", @not_for) . ")</small></td>";
		}
	    }
	    print "</tr></table>\n";

	    print "<table><tr><td><b>" . M("Details") . ":</b></td>";
	    my @draw_details =
		([M('Stra&szlig;en'),  'str',      $default_draw{"str"}],
		 [M('S-Bahn'),         'sbahn',    $default_draw{"sbahn"}],
		 [M('U-Bahn'),         'ubahn',    $default_draw{"ubahn"}],
		 [M('Gew&auml;sser'),  'wasser',   $default_draw{"wasser"}],
		 [M('Fl&auml;chen'),   'flaechen', $default_draw{"flaechen"}],
		 [M('Ampeln'),         'ampel',    $default_draw{"ampel"}],
		 );
	    if ($multiorte) {
		push @draw_details, [M('Orte'), 'ort', $default_draw{"ort"}];
	    }
	    push
		@draw_details,
		[M('Routendetails'),  'strname',$default_draw{"strname"}],
		[M('Titel'),          'title',  $default_draw{"title"}],
		[M('Alles'),          'all',    $default_draw{"all"}];
	    {
		my $cols = $is_m ? 2 : 5;
		for(my $i=$#draw_details-1; $i>=0; $i--) {
		    if ($i % $cols == $cols-1) {
			splice @draw_details, $i+1, 0, '-';
		    }
		}
	    }
	    foreach my $draw (@draw_details) {
		if ($draw eq '-') {
		    print table_br();
		    next;
		}
		my $text;
		if ($draw->[0] eq 'S-Bahn' && !$bi->{'text_browser'}) {
		    $text = "<img src=\"$bbbike_images/sbahn.gif\" width=15 height=15 border=0 alt=S>-Bahn";
		} elsif ($draw->[0] eq 'U-Bahn' && !$bi->{'text_browser'}) {
		    $text = "<img src=\"$bbbike_images/ubahn.gif\" width=15 height=15 border=0 alt=U>-Bahn";
		} else {
		    $text = $draw->[0];
		}
		my $id = "draw_" . $draw->[1];
		print
		    qq{<td><span class=nobr><input id="$id" type="checkbox" name="draw" value="$draw->[1]"},
		    ($draw->[2] ? " checked" : ""),
		    ($draw->[1] eq 'all' ? qq{ onclick="all_checked()"} : ""),
		    qq{> <label for="$id">$text</label> </span></td>\n};
	    }
	    print "</tr>\n";
##XXX Fix this without using $str
#  	    if ($str->{Scope} ne "cityXXX" || $multiorte) {
#  		# XXX scope instead???
#  		print "<input type=hidden name=draw value=umland>\n";
#  	    }
	    print "</table>\n";
	    if (!$is_m) {
	        print qq{<div class="graphfootnote">};
	        printf M(<<EOF), 15, 200, 50, 3000;
Die Dateigr&ouml;&szlig;e der Grafik betr�gt je nach
Bildgr&ouml;&szlig;e, Bildformat und Detailreichtum %s bis %s kB. PDFs sind %s bis %s kB gro�.
EOF
	    }
            print window_open("$bbbike_html/legende.html", "BBBikeLegende",
			      "dependent,height=392,resizable" .
			      "screenX=400,screenY=80,scrollbars,width=440")
		. M("Legende") . ".</a>\n";
	    print "</div>";
	}

	print qq{<input type=hidden name=scope value="@{[ ($scope ne 'city' ? CGI::escapeHTML($scope) : "") ]}">};
	print "</form>\n";
	print qq{</div>};

	if ($show_settings) {
	    #print "<hr>";
	    print qq{<div class="box">};
	    print "<form name=settings action=\"" . BBBikeCGI::Util::my_self_url($q) . "\">\n";
	    foreach my $key ($q->param) {
		next if $key =~ /^(pref_.*)$/;
		print $q->hidden(-name=>$key,
				 -default=>[BBBikeCGI::Util::my_multi_param($q, $key)])
	    }
	    print "<b>" . M("Einstellungen") . ":</b>";
	    #reset_html();
	    print "<p>\n";
	    settings_html();
	    print qq{<input type=submit value="} . M("Route mit ge&auml;nderten Einstellungen") . qq{">\n};
	    print "</form>\n";
	    print qq{</div>};
	}

	if ($show_wayback) {
	    print <<"EOF";
<div class="box">
 <form name='search' action="@{[ CGI::escapeHTML($bbbike_script) ]}">
  <input type=hidden name=startc value="@{[ CGI::escapeHTML($zielcoord) ]}">
  <input type=hidden name=zielc  value="@{[ CGI::escapeHTML($startcoord) ]}">
  <input type=hidden name=startname value="@{[ CGI::escapeHTML($zielname) ]}">
  <input type=hidden name=zielname  value="@{[ CGI::escapeHTML($startname) ]}">
EOF
	    if (defined $viacoord && $viacoord ne '') {
		print <<"EOF";
  <input type=hidden name=viac value="@{[ CGI::escapeHTML($viacoord) ]}">
  <input type=hidden name=vianame value="@{[ CGI::escapeHTML($vianame) ]}">
EOF
	    }
	    for my $param ($q->param) {
		if ($param =~ /^pref_/) {
		    print <<"EOF";
  <input type=hidden name="$param" value="@{[ CGI::escapeHTML(scalar $q->param($param)) ]}">
EOF
		}
	    }
	    print qq{  <input type=submit value="} . M("R&uuml;ckweg") . qq{"><br>};
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
		foreach (qw(viac vianame)) {
		    $qq->delete($_);
		}
		foreach ($qq->param) {
		    if (/^pref_/) {
			$qq->delete($_);
		    }
		}

		print " " . M("Neue Anfrage") . ": ";

		my $qqq = new CGI $qq->query_string;
		foreach ($qqq->param) {
		    if (/^ziel/) {
			$qqq->delete($_);
		    }
		}
		$button->(M("Start beibehalten"), $qqq->query_string);

		$qqq = new CGI $qq->query_string;
		foreach ($qqq->param) {
		    if (/^start/) {
			$qqq->delete($_);
		    }
		}
		$button->(M("Ziel beibehalten"), $qqq->query_string);

		$button->(M("Start und Ziel neu eingeben"), "begin=1");

		$qqq = new CGI $qq->query_string;
		foreach (qw(c name plz)) {
		    $qqq->param("start$_", BBBikeCGI::Util::my_multi_param($qqq, "ziel$_"));
		    $qqq->delete("ziel$_");
		}
		$button->(M("Ziel als Start"), $qqq->query_string);

		print "<br>";
	    }

	    print "</form>\n";
	    print qq{</div>};
	}

    }

    if (@weather_res && !$in_error_condition) {
	my(@res) = @weather_res;
	print "<center><table border=0 bgcolor=\"#d0d0d0\">\n";
	print "<tr><td colspan=2><b>" . link_to_met() . M("Aktuelle Wetterdaten") . " ($res[0], $res[1])</a></b></td>";
	print "<tr><td>" . M("Temperatur") . ":</td><td>$res[2] �C</td></tr>\n";
	my $wind_dir = $res[4];
	if ($lang eq 'en') {
	    $wind_dir =~ s{O$}{E}; # the only difference between de and en: east/ost
	}
	print "<tr><td>" . M("Windrichtung") . ":</td><td>$wind_dir&nbsp;</td></tr>\n";
	my $wind_unit_label;
	my $wind_val = $res[5];
	if (defined $wind_val && length $wind_val) {
	    $wind_unit_label = M("Windspitzen");
	} elsif (defined $res[7] && length $res[7]) {
	    $wind_val = $res[7];
	    $wind_unit_label = M("mittlere Windgeschwindigkeit");
	}
	if (!defined $wind_val) {
	    print "<tr><td></td><td>";
	} else {
	    my($kmh, $windtext);
	    eval { local $SIG{'__DIE__'};
		   require Met::Wind;
		   $kmh      = Met::Wind::wind_velocity([$wind_val, 'm/s'],
							'km/h');
		   if ($kmh >= 5) {
		       $kmh = sprintf("%d",$kmh); # keine Pseudogenauigkeit, bitte
		   }
		   $windtext = Met::Wind::wind_velocity([$wind_val, 'm/s'],
							$lang eq 'en' ? 'text_en' : 'text_de');
	    };
	    print "<tr><td>$wind_unit_label:</td><td>";
	    if (defined $kmh) {
		print "$kmh km/h";
	    } else {
		print "$wind_val m/s";
	    }
	    if (defined $windtext) {
		print " ($windtext)";
	    }
	}
	print "</td></tr>\n";
	print "</table></center><hr>";
    }

    footer();

  END_OF_HTML:
    print $q->end_html;
}

sub user_agent_info {
    $bi = new BrowserInfo $q;
#    $bi->emulate("wap"); # XXX put your favourite emulation
    $bi->emulate_if_validator("mozilla");
    $bi->{'hfill'} = ($bi->is_browser_version("Mozilla", 5, 5.0999) ?
		      "class='hfill'" : "");
}

sub show_user_agent_info {
    http_header(-type => 'text/html', @no_cache);
    print $bi->show_info('complete');
    print $bi->show_server_info;
}

sub coord_or_stadtplan_link {
    my($strname, $coords, $plz, $is_ort, $hnr, %args) = @_;
    if (defined $coords && $use_coord_link) {
	coord_link($strname, $coords, %args);
    } else {
	stadtplan_link($strname, $plz, $is_ort, $hnr);
    }
}

sub coord_link {
    my($strname, $coords, %args) = @_;
    my $coords_esc = CGI::escape($coords);
    my $strname_esc = CGI::escapeHTML($strname);
    if ($data_is_wgs84) {
	return $strname_esc; # XXX currently not useful with wgs84 data
    }
    my $jslink = $args{-jslink};
    my $out = qq{<a };
    if ($jslink) {
	$out .= qq{ class="ms" onclick="return ms($coords)"};
    }
    $out .= qq{ target="_blank" href="$mapserver_address_url?coords=$coords_esc">$strname_esc</a>};
    $out;
}

sub stadtplan_link {
    my($strname, $plz, $is_ort, $hnr) = @_;
    return $strname if $is_ort;
    my $stadtplan_url = "https://www.openstreetmap.org/search";
    my @aref;
    foreach my $s (split(m|/|, $strname)) {
	# Text in Klammern entfernen:
	my $str_plain;
	my @cityparts;
	if (($str_plain = $s) =~ s/\s+\((.*)\)$//) {
	    push @cityparts, split /\s*,\s*/, $1;
	}
	my @query_words = $str_plain;
	push @query_words, $hnr if defined $hnr;
	push @query_words, $plz if defined $plz;
	push @query_words, $cityparts[0] if @cityparts; # putting more than one citypart here would probably confuse nominatim
	push @query_words, "Berlin" if $city eq 'Berlin_DE';
	my $query_words_html = CGI::escapeHTML(join(" ", @query_words));
	push @aref, qq{<a target="_blank" href="$stadtplan_url?query=$query_words_html">@{[ CGI::escapeHTML($s) ]}</a>};
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

# Create a table "break" and indent one column
sub table_br {
    "</tr>\n<tr><td></td>";
}

sub overview_map {
    if (!defined $overview_map) {
	require BBBikeDraw;
	$overview_map = BBBikeDraw->new
	    (ImageType => 'dummy',
	     Geometry => ($xgridwidth*$xgridnr) . "x" . ($ygridwidth*$ygridnr),
	     Lang => $lang,
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
    $ms->read_config("$config_master.config");
    $ms->set_coords("8593,12243"); # Brandenburger Tor
    $ms->start_mapserver(-route => 0,
			 -bbbikeurl => $bbbike_url,
			 -bbbikemail => $BBBike::EMAIL,
			);
    return;
}

sub draw_route {
    my(%args) = @_;
    my @cache = @no_cache;

    my $draw;
    my $route; # optional Route object

    if (defined $q->param('coordssession')) {
	if (my $sess = tie_session(scalar $q->param('coordssession'))) {
	    # Note: the session data specified by coordssession could
	    # already be deleted. In this case all session data would be
	    # empty, especially the coords. The error will happen later,
	    # in BBBikeDraw.
	    $q->param(coords => $sess->{routestringrep});
	    $route = $sess->{route};
	    # We can hopefully safely cache if a session id was involved.
	    @cache = @weak_cache;
	} else {
	    return show_session_expired_error();
	}
    }

    if (defined $q->param('oldcs') &&
	(my $oldsess = tie_session(scalar $q->param('oldcs')))) {
	$q->param(oldcoords => $oldsess->{routestringrep});
    }

    if (defined $q->param('gple') || defined $q->param('gpleu')) {
	my $gple = defined $q->param('gpleu') ? do {
	    require Route::GPLEU;
	    Route::GPLEU::gpleu_to_gple(scalar $q->param('gpleu'));
	} : scalar $q->param('gple');
	require Algorithm::GooglePolylineEncoding;
	my @polyline = Algorithm::GooglePolylineEncoding::decode_polyline($gple);
	my @coords = map { join ',', convert_wgs84_to_data($_->{lon}, $_->{lat}) } @polyline;
	$q->param(coords => join("!", @coords));
    }

    my $cookie;
    %persistent = get_cookie();
    if (defined $q->param("interactive")) {
	foreach my $key (qw/outputtarget imagetype geometry/) {
	    $persistent{$key} = $q->param($key);
	}
	# draw is an array;
	my $i = 0;
	foreach (BBBikeCGI::Util::my_multi_param($q, 'draw')) {
	    $persistent{"draw$i"} = $_;
	    $i++;
	}
	$cookie = set_cookie({ %persistent });
    }

    # XXX move to BBBikeDraw::Mapserver!
    # XXX init() does first part, flush() does start_mapserver
    # XXX and set: sub module_handles_all_cgi { 1 }
    if (defined $q->param('imagetype') &&
	$q->param('imagetype') =~ /^mapserver/) {
	require BBBikeMapserver;
	my $ms = BBBikeMapserver->new_from_cgi($q, -tmpdir => $tmp_dir);
	$ms->read_config("$config_master.config");
	my $layers;
	if (defined $q->param("layer")) { # Mapserver styled parameters
	    $layers = [ "route", BBBikeCGI::Util::my_multi_param($q, 'layer') ];
	} elsif (grep { $_ eq 'all' } BBBikeCGI::Util::my_multi_param($q, 'draw')) {
	    $layers = [ $ms->all_layers ];
	} else {
	    $layers = [ "route",
			map {
			    my $out = +{
					str => "str", # always drawn
					ubahn => "bahn",
					sbahn => "bahn",
					wasser => ["gewaesser", "faehren"],
					flaechen => "flaechen",
					ampel => "ampeln",
					fragezeichen => "fragezeichen",
					ort => "orte",
					grenzen => "grenzen",
				       }->{$_};
			    if (!defined $out) {
				();
			    } elsif (ref $out eq 'ARRAY') {
				@$out;
			    } else {
				$out;
			    }
			} BBBikeCGI::Util::my_multi_param($q, 'draw')
		      ];
	}
	$layers = [ grep { $_ ne "route" } @$layers ]
	    if !$ms->has_coords;

	my $scope = "all,narrowest";
	my $has_center = (defined $q->param("center") && $q->param("center") ne "");
	if ($has_center) {
	    my $width  = $q->param("width");
	    my $height = $q->param("height");
	    if (!outside_berlin_and_potsdam(scalar $q->param("center"))) {
		$q->param("width",  1000) if !defined $width  || $width eq '';
		$q->param("height", 1000) if !defined $height || $height eq '';
	    } else {
		$q->param("width",  5000) if !defined $width  || $width eq '';
		$q->param("height", 5000) if !defined $height || $height eq '';
	    }
	}

	$ms->start_mapserver
	    (-bbbikeurl => $bbbike_url,
	     -bbbikemail => $BBBike::EMAIL,
	     -scope => $scope,
	     -layers => $layers,
	     -cookie => $cookie,
	     (defined $q->param("mapext")
	      ? (-mapext => scalar $q->param("mapext"))
	      : ()
	     ),
	     ($has_center
	      ? (-center => scalar $q->param("center"),
		 -markerpoint => scalar $q->param("center"),
		)
	      : ()
	     ),
	     defined $q->param("width")  ? (-width  => scalar $q->param("width")) : (),
	     defined $q->param("height") ? (-height => scalar $q->param("height")) : (),
	     defined $q->param("padx")   ? (-padx   => scalar $q->param("padx")) : (),
	     defined $q->param("pady")   ? (-pady   => scalar $q->param("pady")) : (),
	    );
	return;
    }

    my %bbbikedraw_args;

    if (defined $q->param('imagetype')) {
	if ($q->param('imagetype') eq 'googlemaps') {
	    $bbbikedraw_args{Module} = "BBBikeGoogleMaps";
	    $bbbikedraw_args{BBBikeRoute} = $route;
	    if ($is_beta) {
		if (0) { # cease -w
		    $BBBikeDraw::BBBikeGoogleMaps::bbbike_googlemaps_url = $BBBikeDraw::BBBikeGoogleMaps::bbbike_googlemaps_url;
		    $BBBikeDraw::BBBikeGoogleMaps::maptype = $BBBikeDraw::BBBikeGoogleMaps::maptype;
		}
		$BBBikeDraw::BBBikeGoogleMaps::bbbike_googlemaps_url = _bbbikegooglemap_url();
		$BBBikeDraw::BBBikeGoogleMaps::maptype = "BBBike";
	    }
	} elsif ($q->param('imagetype') eq 'leaflet') {
	    $bbbikedraw_args{Module} = 'BBBikeLeaflet';
	    $bbbikedraw_args{BBBikeRoute} = $route;
	    $bbbikedraw_args{Conf} = { BBBikeLeafletUrl => _bbbikeleaflet_url() };
	} elsif ($q->param('imagetype') eq 'googlemapsstatic') {
	    $bbbikedraw_args{Module} = "GoogleMapsStatic";
	    $q->param('imagetype', 'png'); # XXX hacky...
	} elsif ($q->param('imagetype') =~ m{^(gif|png)$}) {
	    # XXX Outline=1 looks good with smale scales, but very bad
	    # with large scales (try Friedrichshain -> Potsdam). Maybe
	    # I should introduce something like Outline=>best?
	    # $bbbikedraw_args{Outline} = 1;
	}
    }

    my @header_args = @cache;
    if ($cookie) { push @header_args, "-cookie", $cookie }

    my $cache_file;

    # write content header for pdf as early as possible, because
    # output is already written before calling flush
    if (defined $q->param('imagetype') &&
	$q->param('imagetype') =~ /^pdf/) {
	my($startname, $zielname);
	if ($route) {
	    $startname = Strasse::strip_bezirk($route->[0]->{Strname});
	    $zielname  = Strasse::strip_bezirk($route->[-1]->{Strname});
	}
	my $filename = ($startname && $zielname ? filename_from_route($startname, $zielname, "bbbike") : "bbbike");
	if ($q->param('imagetype') =~ /^pdf-(.*)/) {
	    $q->param('geometry', $1);
	    $q->param('imagetype', 'pdf');
	}
	my @headers = (
		       -type => "application/pdf",
		       -charset => '', # CGI 3.52..3.55 writes charset for non text/* stuff, see https://rt.cpan.org/Public/Bug/Display.html?id=67100
		       @header_args,
		       -Content_Disposition => "inline; filename=$filename.pdf",
		      );
	if ($cache_entry) {
	    $cache_file = $cache_entry->get_content_filename;
	    $cache_entry->put_content(undef, {_additional_filecache_info($q), headers => \@headers});
	}
	http_header(@headers);

	if (defined $bbbikedraw_pdf_module && !$bbbikedraw_args{Module}) {
	    $bbbikedraw_args{Module} = $bbbikedraw_pdf_module;
	}
	if ($use_bbbikedraw_pdf_compress && !defined $bbbikedraw_args{Module}) {
	    # assume that BBBikeDraw::PDF is used
	    $bbbikedraw_args{Compress} = 1;
	}
    } else {
	# for non-pdf
	if (defined $use_module && !$bbbikedraw_args{Module}) {
	    $bbbikedraw_args{Module} = $use_module;
	}
    }

    eval {
	local $SIG{'__DIE__'};
	require BBBikeDraw;
	BBBikeDraw->VERSION(2.26);
	# Auch hier sieht dunkler besser aus:
	$draw = BBBikeDraw->new_from_cgi($q,
					 MakeNet => \&make_netz,
					 Bg => '#c5c5c5',
					 Lang => $lang,
					 Geo => get_geography_object(),
					 %bbbikedraw_args,
					 ($cache_file ? (Filename => $cache_file) : ()),
					);
	die $@ if !$draw;
    };
    if ($@) {
	my $err = "Fehler in BBBikeDraw: $@";
	if (!$header_written) {
	    http_header(-type => 'text/html',
			@no_cache,
		       );
	    print "<body>$err</body>";
	} # else just die
	die $err;
    }

    if (!$header_written && !$draw->module_handles_all_cgi) {
	http_header
	    (-type => $draw->mimetype,
	     @header_args,
	     -Content_Disposition => "inline; filename=bbbike.".$draw->suffix,
	    );
    }

    eval {
	$draw->pre_draw
	    if $draw->can("pre_draw");
	$draw->draw_map    if $draw->can("draw_map");
	$draw->draw_wind   if $draw->can("draw_wind");
	$draw->draw_route  if $draw->can("draw_route");
	$draw->add_route_descr(-net => make_netz(),
			       -lang => $lang)
	    if $draw->can("add_route_descr");
	$draw->flush;
	if ($cache_entry) {
	    $cache_entry->stream_content;
	}
    };
    if ($@) {
	die $@;
    }
}

sub create_map {
    my(%args) = @_;

    my($part, @dim);
    my($x, $y);
    if (exists $args{'-x'} and exists $args{'-y'}) {
	($x, $y) = ($args{'-x'}, $args{'-y'});
	$part = sprintf("%02d-%02d", $x, $y);
	$part .= $berlin_small_suffix;
	@dim  = xy_to_dim($x, $y);
    } else {
	die "No x/y set";
    }

    if (!@dim) { die "No dim set" }

    my($img_url, $img_file);

    my $create = 1;
    my $ext;

    my $set_img_name = sub {
	$img_file = "$mapdir_fs/berlin_map_$part.$ext";
	$img_url  = "$mapdir_url/berlin_map_$part.$ext";
    };

    if (!$args{'-force'}) {
	my $str = get_streets();
	foreach (qw(png gif)) {
	    $ext = $_;
#XXX	    next if $ext eq 'png' and !$bi->{'can_png'};
	    $set_img_name->();
	    if (-s $img_file) {
		my(@img_file_stat)   = stat($img_file);
		if (defined $img_file_stat[9]) {
		    my(@bbbike_cgi_stat) = stat($0); # use always the "main" lang version
		    for my $str_file ($str->dependent_files) {
			my(@strassen_stat)   = stat($str_file);
			my $to_create_time = $img_file_stat[9];
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
			last if $create;
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

    if ($create || !-r $img_file || -z $img_file) {
	eval {
	    local $SIG{'__DIE__'};

	    $ext = $q->param('imagetype') || $graphic_format;
	    if ($ext eq 'gif' && !$can_gif) {
		$ext = 'png';
	    }
	    $set_img_name->();

	    require BBBikeDraw;
	    open(IMG, "> $img_file~") or do {
		print STDERR "Error code: $!\n";
		confess "Fehler: Die Karte $img_file~ konnte nicht erstellt werden.<br>\n";
	    };
	    chmod 0644, "$img_file~";
	    $q->param('geometry', $detailwidth."x".$detailheight);
	    $q->param('draw', 'str', 'ubahn', 'sbahn', 'wasser', 'flaechen', 'ort', 'berlin');
#XXX del?	    $q->param('drawwidth', 1);
	    # XXX Argument sollte �bergeben werden (wird sowieso noch nicht
	    # verwendet, bis auf �berpr�fung des boolschen Wertes)
	    $q->param('strlabel', 'str:HH,H');#XXX if $args{-strlabel};
	    $q->param('imagetype', $ext);
	    if ($args{-module}) {
		$q->param('module', $args{-module});
	    } elsif ($detailmap_module) {
		$q->param('module', $detailmap_module);
	    }
	    $q->param("scope", "region");
	    # #c5c5c5 ist ein guter Kompromiss zwischen
	    # dem Default (#b4b4b4, schmale Wasserstra�en kaum zu erkennen)
	    # und #e1e1e1 (zu heller Hintergrund, Nebenstra�en auf einem
	    # LCD-Monitor kaum zu erkennen).
	    my $draw = BBBikeDraw->new_from_cgi($q,
						Fh => \*IMG,
						Bg => '#c5c5c5',
						Lang => $lang,
						Geo => get_geography_object(),
					       );
	    $draw->set_dimension(@dim);
	    $draw->create_transpose();
	    print "Create $img_file~...\n" if $args{-logging};
	    $draw->draw_map();
	    $draw->flush();
	    $q->delete('draw');
	    $q->delete('geometry');
	    close IMG;

	    if (-z "$img_file~") {
		confess "Fehler: die erzeugte Datei $img_file~ ist 0 Bytes gro�.\n";
	    }
	    rename "$img_file~", $img_file
		or confess "Fehler: Die Datei $img_file~ konnte nicht umbenannt werden ($!).<br>\n";

	};
	die __LINE__ . ": Warnung: $@<br>\n" if $@;
    }

    (imgurl  => $img_url);
}

sub draw_map {
    my(%args) = @_;
    http_header(@weak_cache);

    my %res = create_map(%args);
    my($img_url) = @res{qw(imgurl)};
#require bbbikecgi_experiments;exit drawmap_with_open_layers(%args);#XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    my($x, $y) = ($args{'-x'}, $args{'-y'});

    my $type = $q->param('type') || '';

    header(-from => 'map',
	   -script => {-src => $bbbike_html . "/bbbike_start.js?v=$bbbike_start_js_version",
		      },
	  );
    if ($lang eq 'en') {
	print "Choose <b><a name='mapbegin'>" . M(ucfirst($type)) . "</a></b>:<br>\n";
    } else {
	print "<b><a name='mapbegin'>" . ucfirst($type) . "-Kreuzung</a></b> ausw&auml;hlen:<br>\n";
    }
    print "<form action=\"$bbbike_script\">\n";

    for my $key ($q->param) {
	unless ($key eq 'type') {
	    print qq{<input type=hidden name="@{[ CGI::escapeHTML($key) ]}" value="@{[ CGI::escapeHTML(scalar $q->param($key)) ]}">\n};
	}
    }
    print qq{<input type=hidden name=detailmapx value="$x">\n};
    print qq{<input type=hidden name=detailmapy value="$y">\n};
    print qq{<input type=hidden name=type value="@{[ CGI::escapeHTML($type) ]}">\n};
    print qq{<center><table class="detailmap">};

    # obere Zeile
    if ($y > 0) {
	print "<tr><td align=right>";
	if ($x > 0) {
	    print qq{<input type=submit name=movemap_nw value="} . M("Nordwest") . qq{">};
	}
	print qq{</td><td align=center><input type=submit name=movemap_n value="} . M("Nord") . qq{"></td>\n};
	if ($x < $xgridnr-1) {
	    print qq{<td align=left><input type=submit name=movemap_ne value="} . M("Nordost") . qq{"></td>};
	}
	print "</tr>\n";
    }

    # mittlere Zeile
    print "<tr><td align=right>";
    if ($x > 0) {
	print qq{<input type=submit name=movemap_w value="} . M("West") . qq{">};
    }
    print "</td><td>";
    _zoom_hack_init();
    print "<input type=image title='' name=detailmap ",
	"src=\"$img_url\" alt=\"\" border=0 ",
	"align=middle width=$detailwidth height=$detailheight";
    if ($need_zoom_hack) {
	_zoom_hack_onclick_code();
    }
    print ">";
    print "</td>\n";
    if ($x < $xgridnr-1) {
	print qq{<td align=left><input type=submit name=movemap_e value="} . M("Ost") . qq{"></td>};
    }
    print "</tr>\n";

    # untere Zeile
    if ($y < $ygridnr-1) {
	print "<tr><td align=right>";
	if ($x > 0) {
	    print qq{<input type=submit name=movemap_sw value="} . M("S�dwest") . qq{">};
	}
	print qq{</td><td align=center><input type=submit name=movemap_s value="} . M("S�d") . qq{"></td>};
	if ($x < $xgridnr-1) {
	    print qq{<td align=left><input type=submit name=movemap_se value="} . M("S�dost") . qq{"></td>};
	}
	print "</tr>\n";
    }
    print "</table>";
    print qq{<input type=button value="&lt;&lt; } . M("Zur�ck") . qq{" onclick="history.back(1);">};
    print "</center>";
    footer();
    print "</form>\n";
    print $q->end_html;
}

# Stellt f�r den x/y-Index der berlin_small-Karte die zugeh�rige
# Dimension f�r BBBikeDraw fest.
sub xy_to_dim {
    my($x, $y) = @_;
    ($x*$xgridwidth*$xm+$x0, ($x+1)*$xgridwidth*$xm+$x0,
     $y0-($y+1)*$ygridwidth*$ym, $y0-$y*$ygridwidth*$ym,
    );
}

# F�r einen Punkt aus der Detailmap wird die am n�chsten liegende
# Kreuzung festgestellt. Zur�ckgegeben wird die Koordinate der
# Kreuzung "(x,y)".
sub detailmap_to_coord {
    my($index_x, $index_y, $map_x, $map_y) = @_;
    my($x, $y) =
      ($index_x*$xgridwidth*$xm+$x0 + ($map_x*$xm*$xgridwidth)/$detailwidth,
       $y0-$index_y*$ygridwidth*$ym - ($map_y*$ym*$ygridwidth)/$detailheight,
      );
    if (outside_berlin("$x,$y")) { # XXX should this be done generally in get_nearest_crossing_coords?
	upgrade_scope("region");
    }
    new_kreuzungen(); # XXX needed for munich, here too?
    get_nearest_crossing_coords($x,$y);
}

sub get_cyclepath_streets {
    my($scope) = shift || $q->param("scope") || "city";
    if ($scope eq 'city') {
	Strassen->new("radwege_exact");
    } else {
	MultiStrassen->new("radwege_exact", "comments_cyclepath");
    }
}

sub get_streets {
    my($scope) = shift || $q->param("scope") || "city";
    $scope =~ s/^all,//;
    if ($g_str && $g_str->{Scope} eq $scope) {
	return $g_str;
    }
    my @f = ("strassen",
	     ($scope =~ /region/ ? "landstrassen" : ()),
	     ($scope eq 'wideregion' ? "landstrassen2" : ()),
	    );

    if ($q->param("addnet")) {
	for my $addnet ($q->param("addnet")) {
	    if ($addnet =~ /^(?:  )$/x) { # no addnet support for now
		push @f, $addnet;
	    }
	}
    }

    # XXX do not use Strassen::StrassenNetz::add_faehre, so better
    # display in route list is possible
    if (defined $q->param('pref_ferry') && $q->param('pref_ferry') eq 'use') {
	push @f, 'faehren';
    }

    # Should be last:
    if (defined $q->param("pref_fragezeichen") && $q->param("pref_fragezeichen") eq 'yes') {
	push @f, "fragezeichen";
    }

    my $use_cooked_street_data = $use_cooked_street_data;
    while(1) {
	my @f = @f;
	if ($use_cooked_street_data) {
	    @f = map {
		# Note: no "cooked" version for faehren available
		$_ eq "faehren" ? $_ : "$_-cooked"
	    } @f;
	}
	eval {
	    if (@f == 1) {
		$g_str = new Strassen $f[0];
	    } else {
		$g_str = new MultiStrassen @f;
	    }
	};
	if ($@) {
	    if ($use_cooked_street_data) {
		warn qq{Maybe the "cooked" version for <@f> is missing? Try again the normal version...};
		$use_cooked_street_data = 0;
		next;
	    } else {
		die $@;
	    }
	}
	last;
    }
    $g_str->{Scope} = $scope;

    if (!$use_cooked_street_data) {
	my $i_s;
	eval { $i_s = new Strassen "inaccessible_strassen" };
	if ($i_s) {
	    $g_str = $g_str->new_with_removed_points($i_s);
	    $g_str->{Scope} = $scope;
	}
    }

    undef $crossings;

    $g_str;
}

sub get_streets_rebuild_dependents {
    $g_str = get_streets();

    if ($crossings) {
	undef $crossings;
	all_crossings();
    }
    if ($kr) {
	undef $kr;
	new_kreuzungen();
    }
    if ($net) {
	undef $net;
	make_netz();
    }

    if ($use_umland || $use_umland_jwd) {
	get_orte();
    }

    $g_str;
}

sub get_orte {
    return $multiorte if $multiorte;

    # Orte
    my @o;
    $orte = new Strassen "orte" unless defined $orte;
    push @o, $orte;
    if ($use_umland_jwd) {
	$orte2 = new Strassen "orte2" unless defined $orte2;
	push @o, $orte2;
    }
    $multiorte = new MultiStrassen @o;
    $multiorte;
}

sub all_crossings {
    if (!$crossings) {
	my $str = get_streets();
	$crossings = $str->all_crossings(RetType => 'hash',
					 UseCache => 1);
    }
}

sub get_culdesac_hash {
    # $culdesac_cached: defined but false: no culdesac file available
    if (!defined $culdesac_cached) {
	eval {
	    $culdesac_cached = Strassen->new('culdesac')->get_hashref;
	};
	if (!$culdesac_cached || $@) {
	    warn "WARN: culdesac data could not be loaded: $@";
	    $culdesac_cached = 0;
	}
    }
    $culdesac_cached;
}

sub new_kreuzungen {
    if (!$kr) {
	all_crossings();
	my $str = get_streets();
	$kr = new Kreuzungen(Hash => $crossings,
			     Strassen => $str);
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

# XXX scope => "all" is wrongly implemented
# XXX but it is not yet used at all
sub init_plz {
    my(%args) = @_;
    my $scope = $args{scope} || "all";
    return $cached_plz{$scope} if $cached_plz{$scope};

    if (1) { # XXX introduce flag? (i.e. for other cities!!!)
	my $other_place_coords_data;
	if ($scope eq 'all' || $scope =~ $outer_berlin_qr) {
	    (my $file_scope = $scope) =~ s{[^A-Za-z]}{_}g;
	    $other_place_coords_data = "$tmp_dir/" . $Strassen::Util::cacheprefix . "_" . $< . "_" . $file_scope . ".coords.data";
	    my $landstr0 = Strassen->new("landstrassen", NoRead => 1);
	    if (!-r $other_place_coords_data ||
		(-r $other_place_coords_data && -M $other_place_coords_data > -M $landstr0->file)
	       ) {
		if (open(OFH, "> $other_place_coords_data")) {
		    my $landstr = Strassen->new("landstrassen");
		    $landstr->init;
		    while(1) {
			my $ret = $landstr->next;
			last if !@{$ret->[1]};
			my $name = $ret->[0];
			next if $name !~ m{(.*)\s+\(($scope(?:-[^\)]+)?)\)};
			print OFH join("|", $1, $2, "", $ret->[1][0]), "\n";
		    }
		    close OFH;
		} else {
		    warn "Cannot write to $other_place_coords_data: $!";
		}
	    }
	}
	my @files;
	if ($scope eq 'all' || $scope eq 'Berlin/Potsdam') {
	    for my $def (@b_and_p_plz_multi_files) {
		my($name, $type, undef, undef, $optional) = @$def;
		if ($name eq 'sehenswuerdigkeit_bp') {
		    my $sehenswuerdigkeit_bp_file = "$tmp_dir/" . $Strassen::Util::cacheprefix . "_" . $< . "_" . "sehenswuerdigkeit_bp";
		    my $sehenswuerdigkeit = Strassen->new("sehenswuerdigkeit", NoRead => 1);
		    if (!(-r $sehenswuerdigkeit_bp_file &&
			  -M $sehenswuerdigkeit_bp_file < -M $sehenswuerdigkeit->file)) {
			my $new_s = Strassen->new;
			$sehenswuerdigkeit->read_data(UseLocalDirectives => 1);
			$sehenswuerdigkeit->init;
			while(1) {
			    my $r = $sehenswuerdigkeit->next;
			    last if !@{ $r->[Strassen::COORDS()] };
			    my $dir = $sehenswuerdigkeit->get_directives;
			    my $section = $dir->{"section"};
			    next if $section && $section->[0] !~ m{^(Berlin|Potsdam)$};
			    my $aliases = $dir->{"alias"};
			    if ($aliases) {
				for my $alias (@$aliases) {
				    $new_s->push([$alias, $r->[Strassen::COORDS()], $r->[Strassen::CAT()]]);
				}
			    }
			    $new_s->push($r);
			}
			$new_s->write("$sehenswuerdigkeit_bp_file~");
			rename "$sehenswuerdigkeit_bp_file~", $sehenswuerdigkeit_bp_file
			    or die "Can't rename to $sehenswuerdigkeit_bp_file: $!";
		    }
		    push @files, Strassen->new($sehenswuerdigkeit_bp_file);
		} elsif ($type eq 'Strassen') {
		    push @files, Strassen->new($name);
		} else {
		    if ($optional) {
			if (-r "$Strassen::datadirs[0]/$name") {
			    push @files, $name;
			}
		    } else {
			push @files, $name;
		    }
		}
	    }
	}
	if (($scope eq 'all' || $scope =~ $outer_berlin_qr) &&
	    $other_place_coords_data && -r $other_place_coords_data) {
	    push @files, $other_place_coords_data;
	}
	if (@files) {
	    require PLZ::Multi;
	    $cached_plz{$scope} = PLZ::Multi->new(@files, -cache => 1, -addindex => 1, -preferfirst => 1, '-usefmtext');
	} else {
	    warn "No input files";
	    return;
	}
    } else {
	require PLZ;
	PLZ->VERSION(1.26);
	$cached_plz{$scope} = new PLZ;
    }
    $cached_plz{$scope};
}

sub load_temp_blockings {
    my(%args) = @_;
    my $test_mode = $args{-test};
    if (@temp_blocking && ($temp_blocking_epoch + 3600 < time || $test_mode)) {
	warn "Invalidate cached temp_blocking...\n" if $debug;
	@temp_blocking = ();
	$temp_blocking_epoch = undef;
    }

    if (!@temp_blocking && defined $bbbike_temp_blockings_file) {
	@temp_blocking = ();
	my $use_file;
	if (!$test_mode &&
	    defined $bbbike_temp_blockings_optimized_file &&
	    -r $bbbike_temp_blockings_optimized_file &&
	    (!-r $bbbike_temp_blockings_file || -M $bbbike_temp_blockings_optimized_file < -M $bbbike_temp_blockings_file)) {
	    $use_file = $bbbike_temp_blockings_optimized_file;
	} else {
	    $use_file = $bbbike_temp_blockings_file;
	}
	do $use_file;
	if (!@temp_blocking) {
	    warn "Could not load $use_file or file is empty: $@";
	} else {
	    $temp_blocking_epoch = time;
	}
    }
}

# The combination of Strassen->nearest_point and crossing_text may
# lead to some unexpected results. Take for instance T�binger Str.
# (approx. 5426,8148): nearest_point will return a point at
# Bundesallee (5360,8197). crossing_text will calculate the nearest
# crossing from this point which would be Bundesallee/Durlacher Str.
# But the nearest crossing from 5426,8148 is actually
# Bundesallee/Wexstr.!
sub crossing_text {
    my $c = shift;
    all_crossings();
 TRY_SCOPES: {
	if (!exists $crossings->{$c}) {
	    new_kreuzungen();
	    my(@nearest) = $kr->nearest_coord($c);
	    if (!@nearest || !exists $crossings->{$nearest[0]}) {
		my $new_scope = increment_scope();
		if (!$new_scope) {
		    # Last resort, probably far away
		    my $crossing_text = eval {
			my($px,$py) = convert_data_to_wgs84(split /,/, $c);
			"N $py / O $px";
		    };
		    if ($@) {
			warn $@;
			$crossing_text = "???";
		    }
		    return $crossing_text;
		}
		get_streets_rebuild_dependents();
		goto TRY_SCOPES;
	    } else {
		$c = $nearest[0];
	    }
	}
    }
    Strasse::nice_crossing_name(@{ $crossings->{$c} });
}

# Gibt den Stra�ennamen f�r type=start/via/ziel zur�ck --- entweder
# aus startname oder abgeleitet aus startc
sub name_from_cgi {
    my($q, $type) = @_;
    if (defined $q->param($type . "name") and
	$q->param($type . "name") ne '') {
	$q->param($type . "name");
    } elsif (defined $q->param($type . "c")) {
	crossing_text(scalar $q->param($type . "c"));
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

sub get_next_scopes {
    my $scope = shift;
    if (!defined $scope || $scope eq "" || $scope =~  /\bcity\b/) {
	return (qw(region wideregion));
    } elsif ($scope =~ /\bregion\b/) {
	return (qw(wideregion));
    } else {
	return ();
    }
}

# Increment scope and return the new scope, or undef if the largest scope
# is already used. Call get_streets_rebuild_dependents after.
sub increment_scope {
    my $scope = $q->param("scope");
    if ($scope eq "" || $scope eq "city") {
	$scope = "region";
    } elsif ($scope eq "region") {
	$scope = "wideregion";
    } else {
	return undef;
    }
    $q->param("scope", $scope);
    $scope;
}

# Should be called before a get_streets() call
sub upgrade_scope {
    my($target_scope) = @_;
    my $scope = $q->param("scope") || "city";
    for my $check_scope (qw(wideregion region)) {
	return if ($scope eq $check_scope);
	if ($target_scope eq $check_scope) {
	    $q->param("scope", $check_scope);
	    return;
	}
    }
}

# NOTE: this is only valid for city=b_de. Other cities should use other
# border files (XXX -> Geography::....)
sub adjust_scope_for_search {
    return if $osm_data;

    my($coordsref) = @_;
    return if $q->param("scope") && $q->param("scope") ne 'city'; # already bigger scope

    if (!eval { require VectorUtil; 1 }) {
	warn $@;
	return;
    }

    my $city_border = eval { MultiStrassen->new("berlin", "upgrade_scope_hint") };
    if (!$city_border) {
	warn "Cannot get border file (berlin and/or upgrade_scope_hint)";
	return;
    }

    my @border_polylines;
    $city_border->init;
    while() {
	my $r = $city_border->next;
	last if !@{ $r->[Strassen::COORDS()] };
	push @border_polylines, $r->[Strassen::COORDS()];
    }

    for my $i (1 .. $#$coordsref) {
	my($xfrom,$yfrom,$xto,$yto) = (split(/,/,$coordsref->[$i-1]),
				       split(/,/,$coordsref->[$i]));
	for my $border_polyline (@border_polylines) {
	    for my $pt_i (1..$#$border_polyline) {
		my($x1,$y1,$x2,$y2) = (split(/,/,$border_polyline->[$pt_i-1]),
				       split(/,/,$border_polyline->[$pt_i]));
		if (VectorUtil::intersect_lines($xfrom,$yfrom,$xto,$yto,
						$x1,$y1,$x2,$y2)) {
		    upgrade_scope("region");
		    return;
		}
	    }
	}
    }

    if (!$q->param("scope")) {
	for my $coord (@$coordsref) {
	    if (outside_berlin($coord)) {
		upgrade_scope("region");
		return;
	    }
	}
    }

}

# falls die Koordinaten nicht exakt existieren, wird der n�chste Punkt
# gesucht und gesetzt
sub fix_coords {
    my(@coords) = @_;

    foreach my $varref (\(@coords)) {
	next if (!defined $$varref or
		 $$varref eq ''    or
		 exists $net->{Net}{$$varref});
	if ($$varref !~ /,/) {
	    send_error(reason => "Invalid coordinate format in '$$varref', missing comma", quiet => 1);
	}
	if (!defined $kr) {
	    new_kreuzungen();
	}

    TRY: {
	    if ($use_exact_streetchooser) {
		my $str = get_streets();
		my $ret = $str->nearest_point($$varref, FullReturn => 1);
		if ($ret && $ret->{Dist} < 50) {
		    $$varref = $ret->{Coord};
		    last TRY;
		} else {
		    # Try to enlarge search region
		    my @scopes = get_next_scopes(scalar $q->param("scope"));
		    if (@scopes) {
			for my $scope (@scopes) {
			    $q->param("scope", $scope); # XXX "all," gets lost
			    my $str = get_streets_rebuild_dependents();
			    my $ret = $str->nearest_point($$varref, FullReturn => 1);
			    if ($ret) {
				$$varref = $ret->{Coord};
				last TRY;
			    }
			}
		    }
		}
	    }

	    # Fallback to old, non-exact chooser
	    #
	    # This is for now buggy, because we should really use
	    # AllPoints in Kreuzungen->new and all_crossings.
	    #
	    my(@nearest) = $kr->nearest_coord($$varref, IncludeDistance => 1);
	    if (@nearest && $nearest[0]->[1] < 50) {
		$$varref = $nearest[0]->[0];
	    } else {
		# Try to enlarge search region
		$q->param("scope", "city") if !$q->param("scope");
		my @scopes = get_next_scopes(scalar $q->param("scope"));
		if (@scopes) {
		    for my $scope (@scopes) {
			$q->param("scope", $scope); # XXX "all," gets lost
			get_streets_rebuild_dependents();
			@nearest = $kr->nearest_loop_coord($$varref);
			if (@nearest) {
			    $$varref = $nearest[0];
			    last TRY;
			}
		    }
		} else {
		    @nearest = $kr->nearest_loop_coord($$varref);
		    if (@nearest) {
			$$varref = $nearest[0];
			last TRY;
		    }
		}
	    }

	    my $appid = $q->param('appid');
	    warn "Can't find nearest for $$varref. Either try to enlarge search space or add some grids for nearest_coord searching" . (defined $appid ? " (appid=$appid)" : '');
	}
    }
    @coords;
}

sub start_weather_proc {
    my(@stat) = stat($wettermeldung_file);
    if (!defined $stat[9] or $stat[9]+30*60 < time()) {
	my @weather_cmdline = (@weather_cmdline,
			       '-o', $wettermeldung_file);
	if ($^O eq 'MSWin32') { # XXX Austesten
	    eval q{
		require Win32::Process;
		unlink $wettermeldung_file;
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
			my $devnull = File::Spec->can("devnull") ? File::Spec->devnull : "/dev/null";
			open STDIN, $devnull;
			open STDOUT, '>' . $devnull;
			open(STDERR, '>' . $devnull);
			require POSIX;
			# Can't use `exists' (for 5.00503 compat):
			POSIX::setsid() if defined &POSIX::setsid;
		    }; warn $@ if $@;
		    unlink $wettermeldung_file;
		    exec @weather_cmdline or my_exit 1;
		}
	    };
	}
    }
}

sub gather_weather_proc {
    my @res;
    my(@stat) = stat($wettermeldung_file);
    if (defined $stat[9] and $stat[9]+30*60 > time()) { # Aktualit�t checken
	if (open(W, $wettermeldung_file)) {
	    chomp(my $line = <W>);
	    @res = split(/\|/, $line);
	    close W;
	}
    }
    @res;
}

sub bbbike_result_js {
    [
     { -src => $bbbike_html . "/bbbike_result.js?v=1.17" },
     { -code => qq{set_bbbike_images_dir_in_bbbike_result('$bbbike_images')} },
    ];
}

# Write a HTTP header (always with Vary) and maybe enabled compression
sub http_header {
    my(%header_args) = @_;

    my $need_utf8_encoding;
    if ($use_utf8) {
	if (!$header_args{"-type"}) {
	    $header_args{"-type"} = "text/html";
	    $header_args{"-charset"} = "utf-8";
	    $need_utf8_encoding = 1;
	}
    }
    if (!$header_args{"-charset"} && $header_args{"-type"} && $header_args{"-type"} !~ m{^text/}) {
	$header_args{"-charset"} = ''; # CGI 3.52..3.63 writes charset for non text/* stuff, see https://rt.cpan.org/Public/Bug/Display.html?id=67100
    }

    my @add_header_args;
    push @add_header_args, (-Vary => "User-Agent");
    if ($q->param("as_attachment")) {
	push @add_header_args, -Content_Disposition => "attachment;file=" . $q->param("as_attachment");
    }
    if ($use_cgi_compress_gzip &&
	eval { require CGI::Compress::Gzip;
	       CGI::Compress::Gzip->VERSION(0.22);
	       package MyCGICompressGzip;
	       @MyCGICompressGzip::ISA = 'CGI::Compress::Gzip';
	       sub isCompressibleType {
		   my($self, $type) = @_;
		   # XXX removed application/pdf| because BBBikeDraw::PDF
		   # and CGI::Compress::Gzip does not work well together
		   # (the latter does not handle "print $fh" calls)
		   return $type =~ m{^(text/.*|image/svg\+xml)$};
	       }
	       1;
	   }) {
	$CGI::Compress::Gzip::global_give_reason =
	    $CGI::Compress::Gzip::global_give_reason = $debug;
	$cgic = MyCGICompressGzip->new;
	print $cgic->header(%header_args, @add_header_args);
    } else {
	print $q->header(%header_args, @add_header_args);
    }
    $header_written = 1;
    if ($need_utf8_encoding) {
	binmode STDOUT, ':utf8';
    }
}

# CORS handling - additionally allow requests from localhost, e.g. for JSCover tests
# also allow requests between bbbike.de and bbbike.org
sub cors_handling {
    my $origin = $q->http('origin');
    if ($origin && $origin =~ m{^https?://
				(?: localhost
				|   bbbike-pps
				|   (?:.*\.)?bbbike\.de
				|   (?:.*\.)?bbbike\.org
				|   (?:.*\.)?herceg\.de
				)(?::\d+)?$}x) {
	(-Access_Control_Allow_Origin => $origin);
    } else {
	();
    }
}

sub header {
    my(%args) = @_;
    my $from = delete $args{-from};
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
    push @$head, $q->meta({-name => "language",
			   -content => $lang ? $lang : "de"});
    if ($city eq 'Berlin_DE') {
	push @$head, $q->meta({-name => "description",
			       -content => ($lang eq 'en'
					    ? 'BBBike is a route planner for cyclists in Berlin'
					    : 'BBBike ist ein Fahrradroutenplaner f�r Berlin')
			      });
    }
    push @$head, $q->meta({-name => 'DC.title',
			   -content => "BBBike - Routenplaner f�r Radfahrer in Berlin und Brandenburg"});
    # ^^^
    # Hint for search engines, to canonify the start URL
    # This handles the ?begin=1 case and bbbike.de vs. www.bbbike.de
    if (defined $from && $from eq 'chooseform-start' &&
	BBBikeCGI::Util::my_server_name($q) =~ m{^(
						   \Qwww.bbbike.de\E
					       |
						   \Qbbbike.de\E
					       )$}x) {
	push @$head, cgilink({-rel => 'canonical',
			      -href => 'http://www.bbbike.de',
			     });
    }
    push @$head, "<base target='_top'>"; # Can't use -target option here
    push @$head, cgilink({-rel  => "shortcut icon",
  			  -href => "$bbbike_images/srtbike1.ico",
  			  -type => "image/x-icon", # according to wikipedia official IANA type is image/vnd.microsoft.icon
#			  -href => "$bbbike_images/srtbike16.gif",
#			  -type => "image/gif",
			 });
    # apple touch icons
    push @$head, cgilink({-rel  => 'apple-touch-icon',
			  -href => "$bbbike_images/srtbike57.png",
			 });
    push @$head, cgilink({-rel   => 'apple-touch-icon',
			  -sizes => '72x72',
			  -href  => "$bbbike_images/srtbike72.png",
			 });
    push @$head, cgilink({-rel   => 'apple-touch-icon',
			  -sizes => '114x114',
			  -href  => "$bbbike_images/srtbike114.png",
			 });
    push @$head, cgilink({-rel   => 'apple-touch-icon',
			  -sizes => '120x120',
			  -href  => "$bbbike_images/srtbike120.png",
			 });
    push @$head, cgilink({-rel   => 'apple-touch-icon',
			  -sizes => '152x152',
			  -href  => "$bbbike_images/srtbike152.png",
			 });
    push @$head, cgilink({-rel   => 'apple-touch-icon',
			  -sizes => '180x180',
			  -href  => "$bbbike_images/srtbike180.png",
			 });
    # safari pinned tab icon
    push @$head, cgilink({-rel   => 'mask-icon',
			  -href  => "$bbbike_images/srtbike_logo_black.svg",
			  -color => 'blue',
			 });
    ## for android chrome
    ## unfortunately this sets also the standard firefox favicon, but this
    ## icon here has no transparent background --- so currently disabled
    #push @$head, cgilink({-rel   => 'icon',
    #			  -sizes => '192x192',
    #			  -href  => "$bbbike_images/srtbike192.png",
    #			  -type  => 'image/png',
    #			 });

    my($bbbike_de_script, $bbbike_en_script);
    if ($lang eq 'en') {
	($bbbike_de_script = $bbbike_script) =~ s{\.en\.cgi}{.cgi};
	$bbbike_en_script = $bbbike_script;
    } else {
	($bbbike_en_script = $bbbike_script) =~ s{\.cgi}{.en.cgi};
	$bbbike_de_script = $bbbike_script;
    }
    if (!$smallform) {
	push @$head,
	    cgilink({-rel => 'Help',
		     -href => "$bbbike_script?info=1"}),
	    cgilink({-rel => 'Home',
		     -href => "$bbbike_script?begin=1"}),
	    cgilink({-rel => 'Start',
		     -hreflang => 'de',
		     -href => "$bbbike_de_script?begin=1"}),
	    cgilink({-rel => 'Start',
		     -hreflang => 'en',
		     -href => "$bbbike_en_script?begin=1"}),
	    cgilink({-rel => 'Author',
		     -href => "mailto:@{[ $BBBike::EMAIL ]}"}),
	   (defined $args{-up}
	    ? cgilink({-rel => 'Up', -href => $args{-up}}) : ()),
		;
	if ($args{-contents}) {
	    push @$head, cgilink({-rel => 'Contents',
				  -href => $args{'-contents'}});
	}
    }
    if (0 && $is_beta) {
	push @$head, cgilink({-rel => 'search',
			      -title => 'BBBike',
			      -href => "$bbbike_html/opensearch/bbbike-opensearch-" . ($lang eq 'en ' ? $lang : 'de') . ".xml",
			      -type => 'application/opensearchdescription+xml',
			     });
    }
    delete @args{qw(-contents -up)};
    my $printmode = delete $args{-printmode};
    if ($bi->{'can_css'} && !exists $args{-style}) {
	$args{-style} = {-src => "$bbbike_html/" . ($printmode ? "bbbikeprint" : "bbbike") . ".css?v=" . $bbbike_css_version};
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

    my %meta = (
		'keywords'  => 'berlin fahrrad route bike karte suche cycling route routing routenplaner routenplanung fahrradroutenplaner radroutenplaner entfernungsrechner',
		'copyright' => '(c) 1998-2015 Slaven Rezic',
	       );
    if ($is_m) {
	$meta{'viewport'} = 'width=320; initial-scale=1.0, max-scale=1.0, user-scalable=no';
    }
    # MSIE11 pinned site metadata
    $meta{'application-name'} = 'BBBike' . ($is_beta ? ' (beta)' : '');
    $meta{'msapplication-config'} = "$bbbike_html/msapp/browserconfig_" . ($use_cgi_bin_layout ? "cgilayout" : "bbbikelayout") . ".xml";
    $meta{'msapplication-starturl'} = $bbbike_script;

    print $q->start_html
	(%args,
	 -lang => 'de-DE',
	 -BGCOLOR => '#ffffff',
	 ($use_background_image && !$printmode ? (-BACKGROUND => "$bbbike_images/bg.jpg") : ()),
	 -meta => \%meta,
	 -author => $BBBike::EMAIL,
	);
    if (!$smallform) {
	print "<h1>\n";
	if ($printmode) {
	    print "$args{-title}";
	    print "<img alt=\"\" src=\"$bbbike_images/srtbike.gif\" hspace=\"10\" width=\"41\" height=\"39\">";
	} else {
	    my $use_css = !$bi->{'css_buggy'};
	    my $title = $args{-title};
	    if ($is_beta) {
		$title = "BB<span style='font-style:italic;'>&#x03B2;</span>ike</a>";
	    }
	    print "<a href='$bbbike_url?begin=1' title='" . M("Zur�ck zur Hauptseite") . "' style='text-decoration:none; color:black;'>$title";
	    print "<img";
	    if ($use_css) {
		print ' style="position:relative; top:15px; left:-15px;"';
	    }
	    print " alt=\"\" src=\"$bbbike_images/srtbike.gif\" border=\"0\" width=\"41\" height=\"39\">";
	    print "</a>";
	}
	print "</h1>\n";
    } else {
	print "<h1>BBBike</h1>";
    }
    if ($with_lang_switch && (!defined $from || $from !~ m{^(info|map)$})) {
        my $query_string = $q->query_string;
	$query_string = '?' . $query_string if $query_string;

	print qq{<div style="position:absolute; top:5px; right:10px;">};
	my $img_attribs = 'width="48" height="24"';
	if ($lang eq 'en') {
	    print <<EOF;
<a href="$bbbike_de_script$query_string"><img class="unselectedflag" src="$bbbike_images/de_flag.png" alt="Deutsch" title="Deutsch" border="0" $img_attribs></a>
<img class="selectedflag" src="$bbbike_images/gb_flag.png" alt="English" title="English" border="0" $img_attribs>
EOF
	} else {
	    print <<EOF;
<img class="selectedflag" src="$bbbike_images/de_flag.png" alt="Deutsch" title="Deutsch" border="0" $img_attribs>
<a href="$bbbike_en_script$query_string"><img class="unselectedflag" src="$bbbike_images/gb_flag.png" alt="English" title="English" border="0" $img_attribs></a>
EOF
	}
	print qq{</div>\n};
    }

    if ($ENV{SERVER_NAME} =~ /cs\.tu-berlin\.de/ &&
	open(U, "$FindBin::RealBin/bbbike-umzug.html")) {
	while(<U>) { print }
	close U;
    }
}

sub footer { print footer_as_string() }

sub footer_as_string {
    my $s = "";
    my $smallformstr = ($q->param('smallform') ? '&smallform=' . $q->param('smallform') : '');
    $s .= <<EOF;
<table class="footer" cellpadding="3">
 <tr>
  <td>bbbike.cgi $VERSION</td>
EOF
    if (!$is_m) {
	$s .= <<EOF;
  <td><a target="_top" href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike">@{[ M("E-Mail") ]}</a></td>
EOF
    }
    $s .= <<EOF;
  <td><a target="_top" href="$bbbike_script?begin=1$smallformstr">@{[ M("Neue Anfrage") ]}</a></td>
  <td><a target="_top" href="$bbbike_script?info=1$smallformstr">@{[ M("Kontakt, Info &amp; Disclaimer") ]}</a></td>
EOF
    if (!$is_m) {
	$s .= "  <td>" . complete_link_to_einstellungen() . "</td>\n";
	if ($can_mapserver) {
	    $s .= "  <td><a href=\"$bbbike_script?mapserver=1\">Mapserver</a></td>\n";
	} elsif (defined $mapserver_init_url) {
	    $s .= "  <td><a href=\"$mapserver_init_url\">Mapserver</a></td>\n";
	}
	if ($can_google_maps) {
	    $s .= qq{  <td><a href="@{[ _bbbikegooglemap_url() ]}?mapmode=search;maptype=hybrid">BBBike &amp; Google Maps</a></td>\n};
	}
    }
    if (1) {
	$s .= qq{  <td><a href="@{[ _bbbikeleaflet_url() ]}">BBBike &amp; Leaflet</a></td>\n};
    }
    $s .= <<EOF;
 </tr>
</table>
EOF
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
		    M("Einstellungen") . "</a>";
}

sub link_to_met {
    qq{<a href="http://www.met.fu-berlin.de/de/wetter/">};
}

sub window_open {
    my($href, $winname, $settings) = @_;
    if ($bi->{'no_new_windows'}) {
	"<a href=\"$href\">";
    } elsif ($bi->{'can_javascript'} && !$bi->{'window_open_buggy'}) {
	"<a href=\"$href\" target=\"$winname\" onclick='window.open(\"$href\", \"$winname\"" .
	  (defined $settings ? ", \"$settings\"" : "") .
	    "); return false;'>";
    } else {
	"<a href=\"$href\" target=\"$winname\">";
    }
}

sub call_bikepower {
    http_header(@no_cache);
    eval q{
	require BikePower::HTML;
	# XXX no support for css in BikePower::HTML
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
	if ($bp_obj->can("make_valid")) {
	    $bp_obj->make_valid;
	} else {
	    warn "*** Cannot find make_valid method in BikePower, please consider to upgrade BikePower.pm! ***";
	}
	$bp_obj->given('P');
	BBBikeCalc::init_wind();
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
    my $plz_obj = init_plz(scope => "all");
    my $plz_pcre = $plz_obj->make_plz_pcre($plz_number);
    my @res = $plz_obj->look($plz_pcre, Noextern => 1, Noquote => 1);
    my $str = get_streets();
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
    http_header(@weak_cache);
    header(#too slow XXX -onload => "list_all_streets_onload()",
	   -script => {-src => $bbbike_html . "/bbbike_start.js?v=$bbbike_start_js_version",
		      },
	  );

    my @strlist;
    my $str = get_streets();
    $str->init;
    while(1) {
	my $ret = $str->next;
	last if !@{$ret->[1]};
	push(@strlist, $ret->[0]);
    }
    @strlist =
	map  { $_->[1] }
	    sort { $a->[0] cmp $b->[0] }
		map { [BBBikeUtil::german_locale_xfrm($_), $_] }
		    @strlist;

    my $last = "";
    my $last_initial = "";

    print "<center>";
    for my $ch ('A' .. 'Z') {
	print "<a href=\"#$ch\">$ch</a> ";
    }
#     for my $type (qw(s u)) {
# 	print qq{<a href="#${type}bhf">} . uc($type) . qq{-Bahnh�fe</a> };
#     }
    print "</center><div id='list'>";

    my %trans = %BBBikeUtil::uml_german_locale;
    for(my $i = 0; $i <= $#strlist; $i++) {
	next if ($strlist[$i] =~ /^\(/);
	next if $last eq $strlist[$i];
	$last = $strlist[$i];
	(my $strname = $strlist[$i]) =~ s/\s+/\240/g;
	my $initial = substr($strname, 0, 1);
	if (defined $last_initial and
	    $last_initial ne $initial and
	    (!defined $trans{$initial} or
	     $last_initial ne $trans{$initial})) {
	    print "<hr>";
	    $last_initial = ($trans{$initial} ? $trans{$initial} : $initial);
	    print "<a name=\"$last_initial\"><b>$last_initial</b></a><br>";
	}
	my $html_strname = BBBikeCGI::Util::my_escapeHTML($strname);
	print "$html_strname<br>";
    }

#     for my $type (qw(s u)) {
# 	my $s = Strassen->new($type . "bahnhof");
# 	my @bhf;
# 	$s->init;
# 	while(1) {
# 	    my $r = $s->next;
# 	    last if !@{ $r->[Strassen::COORDS()] };
# 	    push @bhf, $r->[Strassen::NAME()] if $r->[Strassen::CAT()] !~ /0$/;
# 	}
# 	@bhf = sort @bhf;
# 	print "<hr>\n";
# 	print qq{<a name="${type}bhf"><b>} . uc($type) . qq{-Bahnh�fe</b></a><br>\n};
# 	print join("<br>\n", map { uc($type) . " " . $_ } @bhf), "\n";
#     }

    print "</div>";

    print $q->end_html;
}

sub get_nearest_crossing_coords {
    my($x,$y) = @_;
    new_kreuzungen();
    my $xy;
    while (1) {
	if ($use_exact_streetchooser) {
	    my $str = get_streets();
	    my $ret = $str->nearest_point("$x,$y", FullReturn => 1);
	    $xy = $ret->{Coord};
	    if ($xy && !$kr->crossing_exists($xy)) {
		# This may happen, because nearest_point does also return Kurvenpointe,
		# whereas $kr has only real Kreuzungen. Find a real Kreuzung...
		my @street_coords = @{ $ret->{StreetObj}->[Strassen::COORDS()] || [] };
		# find this point in @street_coords
		my $start_index = 0;
		for(; $start_index <= $#street_coords; $start_index++) {
		    last if ($street_coords[$start_index] eq $xy);
		}
		if ($start_index > $#street_coords) {
		    # This may happen if there's really no "nearest point".
		    # Hopefully we'll get one after incrementing the scope,
		    # see below.
		} else {
		    my $before_xy;
		    my $after_xy;
		    for(my $i=$start_index-1; $i >= 0; $i--) {
			if ($kr->crossing_exists($street_coords[$i])) {
			    $before_xy = $street_coords[$i];
			    last;
			}
		    }
		    for(my $i=$start_index+1; $i <= $#street_coords; $i++) {
			if ($kr->crossing_exists($street_coords[$i])) {
			    $after_xy = $street_coords[$i];
			    last;
			}
		    }
		    if (!$before_xy && !$after_xy) {
			warn "Harmless? Cannot find any real crossing in <@street_coords>, input coords were $x,$y, scope is <@{[ scalar $q->param('scope') ]}>";
		    } else {
			if ($after_xy && $before_xy) {
			    # choose nearest
			    if (Strassen::Util::strecke_s("$x,$y", $before_xy) < Strassen::Util::strecke_s("$x,$y", $after_xy)) {
				$xy = $before_xy;
			    } else {
				$xy = $after_xy;
			    }
			} elsif ($before_xy) {
			    $xy = $before_xy;
			} elsif ($after_xy) {
			    $xy = $after_xy;
			}
		    }
		}

	    }
	} else {
	    $xy = (($kr->nearest_loop($x,$y))[0]);
	}
	last if defined $xy;
	my $new_scope = increment_scope();
	last if !defined $new_scope;
	get_streets_rebuild_dependents();
    }
    $xy;
}

sub show_routelist_from_file {
    my $file = shift;

    require Route;
    my $res = eval { Route::load($file, { }, -fuzzy => 1) };
    my $err = $@;
    if ($res->{RealCoords}) {
	my $r = Route->new_from_realcoords($res->{RealCoords});
	if (!$q->param("startname")) {
	    my $base = basename($file);
	    $base =~ s{\.[^.]+$}{};
	    $q->param("startname", $base);
	}
	return display_route($r, -hidesettings => 1, -hidewayback => 1);
    }
    die $err;
}

# XXX should also implement coordssession param
#
# XXX gple is implemented but due to floating point inaccuracies
# XXX coordinates are not exactly as expected, so mapping to
# XXX streets only works partially. Best is to use gple only for
# XXX coordinate only formats (e.g. gpx-track). See also
# XXX t/cgi-test.t for a related $TODO test.
sub show_routelist_from_coords {
    require Route;
    my @coords;
    my(@gpleu) = BBBikeCGI::Util::my_multi_param($q, 'gpleu');
    my @gple;
    if (@gpleu) {
	require Route::GPLEU;
	@gple = map { Route::GPLEU::gpleu_to_gple($_) } @gpleu;
    } else {
	@gple = BBBikeCGI::Util::my_multi_param($q, 'gple');
    }
    if (@gple) {
	require Algorithm::GooglePolylineEncoding;
	for my $gple (@gple) {
	    my @polyline = Algorithm::GooglePolylineEncoding::decode_polyline($gple);
	    push @coords, map { join ',', convert_wgs84_to_data($_->{lon}, $_->{lat}) } @polyline;
	}
    }
    if (!@coords) {
	@coords = BBBikeCGI::Util::my_multi_param($q, 'coords');
    }
    my $r = Route->new_from_cgi_string(join("!", @coords));
    display_route($r, -hidesettings => 1, -hidewayback => 1);
}

sub draw_route_from_fh {
    my $fh = shift;

    my $file = "$tmp_dir/bbbike.cgi.upload.$$." . time;
    open(OUT, ">$file") or die "Can't write to $file: $!";
    while(<$fh>) {
	print OUT $_;
    }
    close OUT;
    close $fh;

    require Route;
    Route->VERSION(1.09);
    my $res;
    eval {
	$res = Route::load($file, { }, -fuzzy => 1);
    };
    my $err = $@;
    unlink $file;

    if (@{ $res->{RealCoords} || [] }) {
	$q->param('draw', 'all');
	$q->param('scope', 'wideregion');
	$q->param('geometry', "800x600") if !defined $q->param("geometry");
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
	http_header(@no_cache);
	header();
	print "Dateiformat nicht erkannt: $err";
	upload_button_html();
	footer();
	print $q->end_html;
    }
}

sub upload_button {
    http_header(@no_cache); # wegen dummy
    header();
    upload_button_html();
    footer();
    print $q->end_html;
}

sub upload_button_html {
    # XXX warum ist dummy notwendig???
    print $q->start_multipart_form(-method => 'post',
				   -action => "$bbbike_url?dummy=@{[ time ]}"),
          "Anzuzeigende Route-Datei (.gpx-, .ovl- oder .bbr-Dateien oder GPSman-Tracks):<br>\n",
	  q{<input type="file" name="routefile" accept=".gpx, .ovl, .bbr, .trk, .rte, .wpt"/>},
	  "<p>\n",
	  # hier k�nnte noch ein maxdist-Feld stehen, um die maximale
	  # Entfernung anzugeben, bei der eine Route noch als
	  # "zusammenh�ngend" betrachtet wird XXX
	  "Bildformat: ",
	  $q->popup_menu(-name => "imagetype",
			 -values => ['png',
				     ($cannot_pdf ? () : ('pdf-auto')),
				     ($cannot_svg ? () : ('svg')),
				     ($cannot_jpeg ? () : ('jpeg')),
				     ($can_mapserver ? ('mapserver') : ()),
				     'leaflet',
				    ],
			 -default => 'png',
			 -labels => {'png' => 'PNG',
				     'pdf-auto' => 'PDF',
				     'svg' => 'SVG',
				     'jpeg' => 'JPEG',
				     'mapserver' => 'Mapserver',
				     'leaflet' => 'Leaflet map',
				    },
			),
	  "<p>\n",
	  "Bildgr��e: <small>(nicht f�r PDF, SVG, Mapserver und Leaflet)</small><br>\n",
	  $q->radio_group(-name => "geometry",
			  -values => ["400x300", "640x480", "800x600",
				      "1024x768", "1200x1024", "1600x1200",
				     ],
			  -linebreak => "true",
			  -default => (defined $q->param("geometry")
				       ? scalar $q->param("geometry")
				       : "1024x768"),
			 ),
	  "<p>\n",
	  $q->checkbox(-name => "outputtarget",
		       -value => 'print',
		       -label => "f�r Druck optimieren",
		      ),
	  "<p>\n",
	  $q->submit(-name => 'routefile_submit',
		     -value => 'Anzeigen'),
	  $q->end_form;
}

sub tie_session {
    my $id = shift;
    return unless $now_use_apache_session;

    if (!eval qq{ require $apache_session_module }) {
	$now_use_apache_session = $use_apache_session = undef; # permanent error
	warn $@ if $debug;
	return;
    }

    if ($apache_session_module eq 'Apache::Session::Counted') {
	return tie_session_counted($id);
    }

    my %sess;
    eval {
	tie %sess, $apache_session_module, $id,
	    { FileName => "/tmp/bbbike_sessions_" . $< . ".db", # XXX make configurable
	      LockDirectory => '/tmp',
	    } or do {
		$use_apache_session = undef; # possibly transient error
		warn $! if $debug;
		return;
	    };
    };
    if ($@) {
	if (!defined $id) {
	    # this is fatal
	    die "Cannot create new session: $@";
	} else {
	    # may happen for old sessions, e.g. in links, so
	    # do not die
	    warn "Cannot load old session, maybe already garbage-collected: $@";
	}
    }

    return \%sess;
}

sub tie_session_counted {
    my $id = shift;
    require BBBikeApacheSessionCounted;
    my $sess = BBBikeApacheSessionCounted::tie_session($id);
    if (!$sess) {
	$use_apache_session = undef; # possibly transient error
    }
    return $sess;
}

sub load_teaser {
    eval { local $SIG{'__DIE__'};
	   my $teaser_file = "$FindBin::RealBin/bbbike-teaser.pl";
	   if ((defined $BBBikeCGI::teaser_file_modtime &&
		(stat($teaser_file))[9] > $BBBikeCGI::teaser_file_modtime) ||
	       !defined &teaser) {
	       do $teaser_file;
	       $BBBikeCGI::teaser_file_modtime = (stat($teaser_file))[9];
	   }
       }; warn $@ if $@;
}

sub filename_from_route {
    my($startname, $zielname, $type) = @_;
    for ($startname, $zielname) {
	$_ = lc BBBikeUtil::umlauts_to_german($_);
	s{[^a-z0-9_]}{}g;
    }
    $type = "route" if !$type;
    if (!$startname || !$zielname) {
	$type; # fallback
    } else {
	$type . "_" . $startname . "_" . $zielname;
    }
}

sub outside_berlin_and_potsdam {
    return if $osm_data;
    my($c) = @_;
    my $result = 0;
    eval {
	require VectorUtil;
	my $berlin = Strassen->new("berlin");
	$berlin->count == 1 or die "Record count of berlin is not 1";
	$berlin->init;
	my $potsdam = Strassen->new("potsdam");
	$potsdam->count == 1 or die "Record count of potsdam is not 1";
	$potsdam->init;
	my $berlin_border = [ map { [split /,/] } @{ $berlin->next->[Strassen::COORDS()] } ];
	my $potsdam_border = [ map { [split /,/] } @{ $potsdam->next->[Strassen::COORDS()] } ];
	my $p = [split /,/, $c];
	$result = 1 if (!VectorUtil::point_in_polygon($p,$berlin_border) &&
			!VectorUtil::point_in_polygon($p,$potsdam_border));

    };
    warn $@ if $@;
    $result;
}

sub outside_berlin {
    return if $osm_data;
    my($c) = @_;
    my $result = 0;
    eval {
	require VectorUtil;
	my $berlin = Strassen->new("berlin");
	$berlin->count == 1 or die "Record count of berlin is not 1";
	$berlin->init;
	my $berlin_border = [ map { [split /,/] } @{ $berlin->next->[Strassen::COORDS()] } ];
	my $p = [split /,/, $c];
	$result = 1 if (!VectorUtil::point_in_polygon($p,$berlin_border));

    };
    warn $@ if $@;
    $result;
}

sub get_geography_object {
    my $maybe_meta_file = "$Strassen::datadirs[0]/meta.dd";
    if (-r $maybe_meta_file) {
	my $geo = eval {
	    require Geography::FromMeta;
	    Geography::FromMeta->load_meta($maybe_meta_file);
	};
	warn $@ if $@;
	return $geo if $geo;
    }

    return if !defined $city;

    my $geo_mod = "Geography::" . $city;
    if (eval qq{ require $geo_mod; }) {
	$geo_mod->new;
    } else {
	undef;
    }
}

# XXX This could be refactored and partially go to Route::Heavy
sub lost_time {
    my($r, $tb, $velocity_kmh) = @_;
    return if $tb->{type} ne 'handicap';
    return if $tb->{is_pseudo_handicap}; # XXX quick COVID-19 hack (Maskenpflicht should not appear as with "Zeitverlust"), but should be used for optimizing route
    my $lost_time_s = 0;
    my $ms = kmh2ms($velocity_kmh);
    my(@path) = $r->path_list;
    for(my $i = 0; $i < $#path; $i++) {
	my($x1, $y1) = @{$path[$i]};
	my($x2, $y2) = @{$path[$i+1]};
	my $cat = $tb->{net}{Net}{"$x1,$y1"}{"$x2,$y2"};
	if ($cat && $handicap_speed{$cat}) {
	    my $handicap_speed_ms = kmh2ms($handicap_speed{$cat});
	    if ($handicap_speed_ms < $ms) {
		my $len = Strassen::Util::strecke([$x1,$y1],[$x2,$y2]);
		my $normal_time = $len / $ms;
		my $handicapped_time = $len / $handicap_speed_ms;
		$lost_time_s += ($handicapped_time - $normal_time);
	    }
	}
    }
    my $lost_time_string_de = "";
    if ($lost_time_s >= 5) {
	my $rounded_lost_time_s = $lost_time_s;
	my $mod;
	if ($lost_time_s < 55) {
	    $mod = 15;
	} else {
	    $mod = 60;
	}
	$rounded_lost_time_s += $mod/2;
	$rounded_lost_time_s /= $mod;
	$rounded_lost_time_s = int $rounded_lost_time_s;
	$rounded_lost_time_s *= $mod;
	if ($rounded_lost_time_s < 60) {
	    $lost_time_string_de = sprintf "Zeitverlust ca. %d Sekunden", $rounded_lost_time_s;
	} else {
	    my $rounded_lost_time_min = int($rounded_lost_time_s/60);
	    $lost_time_string_de = sprintf "Zeitverlust ca. %d Minute%s", $rounded_lost_time_min, $rounded_lost_time_min==1?"":"n";
	}
    }
    if (!$lost_time_s) {
	$lost_time_string_de = "kein Zeitverlust zu erwarten";
    } elsif ($lost_time_s < 5) {
	$lost_time_string_de = "kaum Zeitverlust";
    }
    return { lost_time_s         => $lost_time_s,
	     lost_time_string_de => $lost_time_string_de,
	   };
}

# XXX This could be refactored and partially go to Route::Heavy
sub diff_from_old_route {
    my($r) = @_;
    my $diff = { different => 1, old_session_not_found => 1 };
    return $diff if !$q->param('oldcs');
    my $sess = tie_session(scalar $q->param('oldcs'));
    return $diff if !$sess; # could not find old coords session, assume old one was different
    delete $diff->{old_session_not_found};
    my @path = $r->path_list;
    my $old_r = Route->new_from_cgi_string($sess->{routestringrep});
    my @old_path = $old_r->path_list;
    my $len = $r->len;
    my $old_len = $old_r->len;
    if (int($old_len) == int($len)) {
	$diff->{difference} = "(" . M("kein Unterschied in der Entfernung") . ")";
    } elsif (abs($old_len - $len) < 20) {
	$diff->{difference} = "(" . M("unbedeutender Unterschied in der Entfernung") . ")";
    } elsif ($old_len < $len) {
	$diff->{difference} = sprintf "(".M("um %d Meter l�nger").")", int($len - $old_len);
    } elsif ($old_len >= $len) {
	$diff->{difference} = sprintf "(".M("um %d Meter k�rzer").")", int($old_len - $len);
    }
    return $diff if @path != @old_path;
    for my $i (0 .. $#path) {
	return $diff if $path[$i][0] != $old_path[$i][0];
	return $diff if $path[$i][1] != $old_path[$i][1];
    }
    $diff->{different} = 0;
    return $diff;
}

sub experimental_label {
    qq{<span class="experimental">} . M("Experimentell") . qq{</span>};
}

# Make sure the supplied "data" coordinates are converted to wgs84
# coordinates
sub convert_data_to_wgs84 {
    my($x,$y) = @_;
    if ($data_is_wgs84) {
	($x,$y);
    } else {
	$require_Karte->() if $require_Karte;
	$Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($x,$y));
    }
}

# Make sure the supplied wgs84 coordinates are converted to "data"
# coordinates
sub convert_wgs84_to_data {
    my($x,$y) = @_;
    if ($data_is_wgs84) {
	($x,$y);
    } else {
	$require_Karte->() if $require_Karte;
	$Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($x,$y));
    }
}

# Is this a real street, which might is reportable via newstreetform?
sub _is_real_street {
    my $street = shift;
    require PLZ;
    # XXX hack: get_street_type needs a look result
    my $look_result = PLZ->new->make_result([$street]);
    my $type = $look_result->get_street_type;
    $type eq 'street' || $type eq 'projected street';
}

sub _bbbikeleaflet_url {
    (my $href = $bbbike_script) =~ s{/bbbike2?(\.en)?\.cgi}{/bbbikeleaflet$1.cgi};
    $href;
}

sub _bbbikegooglemap_url {
    (my $href = $bbbike_script) =~ s{/bbbike2?(\.en)?\.cgi}{"/bbbikegooglemap" . ($is_beta ? "2" : "") . ".cgi"}e;
    $href;
}

sub _oldname_to_newname {
    my($match) = @_;
    my $newname = $match->clone;
    my $ref = $match->get_field('ref');
    if ($ref) {
	my($strasse, $bezirk) = Strasse::split_street_citypart($ref);
	$newname->set_name($strasse);
	if ($bezirk) {
	    $newname->set_citypart($bezirk);
	}
    } else {
	warn "Should not happen: type=oldname without a ref field";
    }
    $newname;
}

sub _display_oldname {
    my($oldname_s) = @_;
    my $timespan = $oldname_s->get_field('timespan');
    qq{ <span style='font-size:smaller;'}
	. ($timespan ? qq{ title="@{[ M("alter Name g�ltig") ]}: @{[ BBBikeCGI::Util::my_escapeHTML($timespan) ]}"} : '')
	    . qq{>}
		. qq{(@{[ M("alter Name") ]}: @{[ BBBikeCGI::Util::my_escapeHTML($oldname_s->get_name) ]})}
		    . qq{</span>};
}

sub _match_to_cgival {
    my $s = shift;
    join($delim, $s->get_name, $s->get_citypart, $s->get_zip, $s->get_coord);
}

sub _get_weekly_filecache { require BBBikeCGI::Cache; BBBikeCGI::Cache->new($Strassen::datadirs[0], _get_cache_prefix() . '_weekly', 'weekly') }
sub _get_hourly_filecache { require BBBikeCGI::Cache; BBBikeCGI::Cache->new($Strassen::datadirs[0], _get_cache_prefix() . '_hourly', 'hourly') }
sub _get_cache_prefix { $Strassen::Util::cacheprefix . ($is_beta ? '_beta' : '') . ($lang ? "_$lang" : '') }

sub _additional_filecache_info {
    my $q = shift;
    my @info;
    if ($q->query_string) {
	push @info, query_string => scalar $q->query_string;
    }
    if ($q->user_agent) {
	push @info, user_agent => scalar $q->user_agent;
    }
    if ($q->remote_addr) {
	push @info, remote_addr => scalar $q->remote_addr;
    }
    @info;
}

sub http_req_logging {
    eval {
	require JSON::XS;
	warn "DEBUG: " . JSON::XS::encode_json({ map { ($_ => $q->http($_)) } $q->http }) . "\n";
    };
    warn $@ if $@;
}

sub send_error {
    my(%args) = @_;
    my $reason = delete $args{reason} || 'Unknown error';
    my $quiet = delete $args{quiet};
    die "Unhandled args: " . join(" ", %args) if %args;
    my $output_as = $q->param('output_as');
    if ($output_as && $output_as eq 'json') {
	require JSON::XS;
	http_header
	    (-type => "application/json",
	     @weak_cache,
	    );
	print JSON::XS->new->utf8->allow_blessed(1)->encode({error => $reason});
    } else {
	http_header
	    (-type => "text/plain",
	     -status => "400 Bad Request",
	     @weak_cache,
	    );
	print "Error: $reason\n";
    }
    unless ($quiet) {
	warn "DEBUG: Error page sent for " . $q->query_string . ", reason: $reason\n";
	http_req_logging();
    }
    my_exit 0;
}

sub show_session_expired_error {
    http_header
	(-type => 'text/html',
	 @no_cache,
	);
    header(-title => M('Fehler: Sitzung ist abgelaufen'));
    print <<EOF;
<a href="$bbbike_script?begin=1"><b>@{[ M("Neue Anfrage") ]}</b></a><p>
EOF
    footer();
    warn "Cannot draw image because session is expired";
}

######################################################################
#
# Information
#
sub show_info {
    http_header(@weak_cache);
    header(-from => 'info');
    my $perl_url = "https://www.perl.org/";
    my $cpan = "https://www.cpan.org/";
    #my $scpan = "http://search.cpan.org/search?mode=module&amp;query=";
    my $scpan = "https://metacpan.org/pod/";
    print <<EOF;
<center><h2>Information</h2></center>
<ul>
 <li><a href="#tipps">Die Routensuche</a>
 <li><a href="#data">Daten</a>
 <li><a href="#link">Link auf BBBike setzen</a>
 <li><a href="#resourcen">Weitere M�glichkeiten mit BBBike</a>
  <ul>
   <li><a href="#perltk">Perl/Tk-Version</a>
   <li><a href="#beta">Beta-Version</a>
   <li><a href="#mobile">Mobile Version</a>
   <li><a href="#gpsupload">GPS-Upload</a>
   <li><a href="#opensearch">Suchplugin f�r Firefox und IE</a>
   <li><a href="#leaflet">BBBike &amp; Leaflet</a>
   <li><a href="#googlemaps">@{[ $can_google_maps ? qq{BBBike auf Google Maps} : qq{Wo ist Google Maps?} ]}</a>
@{[ $can_palmdoc ? qq{<li><a href="#palmexport">Palm-Export</a>} : qq{} ]}
  </ul>
 <li><a href="@{[ $bbbike_html ]}/presse.html">Die Presse �ber BBBike</a>
 <li><a href="http://bbbike.sourceforge.net/bbbike/doc/links.html">Links</a>
 <li><a href="#hardsoftware">Hard- und Softwareinformation</a>
 <li><a href="#disclaimer">Disclaimer</a>
 <li><a href="#autor">Kontakt</a>
</ul>
<hr>

<h3 id="tipps">Die Routensuche</h3>
Das Programm sucht den k�rzesten oder schnellsten Weg zwischen den gew�hlten Berliner Stra�en. Die Auswahl erfolgt entweder durch das Eintippen
in die Eingabefelder f�r Start und Ziel (Via ist optional), durch Auswahl
aus der Buchstabenliste oder durch Auswahl �ber die Berlin-Karte.
Stra�ennamen m�ssen nicht v�llig korrekt eingegeben werden. Gro�- und
Kleinschreibung wird ignoriert.
<p>
Bei der Suche wird auf Einbahnstra�en und zeitweilig gesperrte Stra�en
geachtet; auf Steigungen und Verkehrsdichte (noch) nicht. Stra�en mit
schlechter Oberfl�che und/oder Hauptstra�en k�nnen geringer bewertet oder
von der Suche ganz ausgeschlossen werden.
<p>
<!-- XXX not yet
Wozu werden die Sucheinstellungen verwendet?
<dl>
 <dt>Bevorzugte Geschwindigkeit
 <dd>
 <dt>Bevorzugter Stra�entyp
 <dd>
 <dt>Bevorzugter Stra�enbelag
 <dd>
 <dt>Ampeln vermeiden
 <dd>
 <dt>Gr�ne Wege bevorzugen
 <dd>
</dl>
-->
EOF
    print
      "Falls die " . complete_link_to_einstellungen() . " ",
      "f�r BikePower ausgef�llt wurden, ",
      "kann mit der " . link_to_met() . "aktuellen Windgeschwindigkeit</a> die ",
      "Fahrzeit anhand von drei Leistungsstufen (50&nbsp;W, 100&nbsp;W und 200&nbsp;W) ",
      "berechnet werden.<p>\n";
    print <<EOF;
F�r die technisch Interessierten: als Suchalgorithmus wird
A<sup>*</sup> eingesetzt<sup> <a class="pseudolink" title="@{[ footnote(1) ]}" href="#footnote1">1</a></sup>.<p>
EOF

    print <<EOF;
<hr>
<h3 id="data">Daten</h3>

Die Daten auf dem aktuellen Stand zu halten ist in einer Stadt wie
Berlin f�r einen Einzelnen eine schwere Aufgabe. Deshalb freue ich
mich �ber Feedback: neue Stra�en, ver�nderte Gegebenheiten, sowohl in
Berlin als auch im Brandenburger Umland. Anregungen bitte als <a
href="mailto:$BBBike::EMAIL">Mail</a> schicken oder <a
href="$bbbike_html/newstreetform${newstreetform_encoding}.html?frompage=info">dieses Formular</a> benutzen.

<hr>
<h3 id="link">Link auf BBBike setzen</h3>
Man kann einen Link auf BBBike mit einem
bereits vordefinierten Ziel setzen. Die Vorgehensweise sieht so aus:
<ul>
 <li>Eine beliebige Route mit dem gew�nschten Zielort suchen lassen. Dabei
     darf die Auswahl f�r den Zielort nicht �ber die Berlin-Karte erfolgen,
     sondern der Zielort muss direkt eingegeben werden.
 <li>Wenn die Route gefunden wurde, klickt man den Link "Ziel beibehalten" an.
 <li>Die URL der neuen Seite kann nun auf die eigene Homepage aufgenommen werden. Die URL m�sste ungef�hr so aussehen:
<tt>$bbbike_url?zielname=Alexanderplatz;zielplz=10178;zielc=10923%2C12779</tt>
 <li>Auf Wunsch kann <tt>zielname</tt> ver�ndert werden. Beispielsweise:
<tt>$bbbike_url?zielname=Weltzeituhr;zielc=10923%2C12779</tt><br>
     Dabei sollte <tt>zielplz</tt> gel�scht werden. Wenn im Namen Leerzeichen
     vorkommen, m�ssen sie durch <tt>+</tt> ersetzt werden.
</ul>
F�r einen vordefinierten Startort geht man genauso vor, lediglich werden alle Vorkommen von <tt>ziel</tt> durch <tt>start</tt> ersetzt.

<!-- XXX DEL:
<h4 id="mambo">BBBike-Modul f�r Mambo</h4>
F�r das CMS Mambo gibt es auf mamboforge ein <a href="http://mamboforge.net/frs/?group_id=1094">BBBike-Modul</a> von Ramiro G&#243;mez.
-->
<hr>
<p>
EOF

    print <<EOF;
<h3 id="resourcen">Weitere M�glichkeiten und Tipps</h3>
<h4 id="perltk">Perl/Tk-Version</h4>
Es gibt eine wesentlich komplexere Version von BBBike mit interaktiver Karte, mehr Kontrollm�glichkeiten �ber die Routensuche, GPS-Anbindung und den kompletten Daten. Diese Version l�uft als normales Programm (mit Perl/Tk-Interface) unter Unix, Linux, Mac OS X und Windows.
<a href="@{[ $BBBike::BBBIKE_SF_WWW ]}">Hier</a>
bekommt man dazu mehr Informationen. Als Beispiel kann man sich
<a href="@{[ $BBBike::BBBIKE_SF_WWW ]}/screenshots.de.html">Screenshots</a> der Perl/Tk-Version angucken.
<p>
Die aktuellen Daten f�r die Perl/Tk-Version k�nnen <a href="@{[ $BBBike::BBBIKE_UPDATE_DATA_CGI ]}">hier</a> heruntergeladen werden oder �ber den Men�punkt <i>Einstellungen</i> &gt; <i>Daten-Update �ber das Internet</i> aus dem Programm heraus.
<p>
Der aktuellen Snapshot der Perl/Tk-Version kann <a href="@{[ $BBBike::BBBIKE_UPDATE_DIST_CGI ]}">hier</a> heruntergeladen werden. <b>Achtung</b>: es ist m�glich, dass die Snapshotversion nicht lauff�hig ist oder Fehler enth�lt.

<h4 id="beta">Beta-Version von bbbike.de</h4>
Zuk�nftige BBBike-Features k�nnen <a href="$bbbike2_url">hier</a> getestet werden.
<h4 id="mobile">Mobile Version</h4>
Unter der Adresse <a href="@{[ $BBBike::BBBIKE_MOBILE ]}">@{[ $BBBike::BBBIKE_MOBILE ]}</a> existiert eine Version von BBBike, die f�r mobile Ger�te optimiert ist.
<h4 id="gpsupload">GPS-Upload</h4>
Es besteht die experimentelle M�glichkeit, sich <a href="@{[ $bbbike_url ]}?uploadpage=1">GPS-Tracks oder bbr-Dateien</a> anzeigen zu lassen.<p>
<h4 id="diplom">Diplomarbeit</h4>
Das Programm wird auch in <a href="@{[ $BBBike::DIPLOM_URL ]}">meiner Diplomarbeit</a> behandelt.<p>
EOF
    if ($bi->is_browser_version("Mozilla", 5) ||
	$bi->is_browser_version("Firefox")) {
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
<h4 id="opensearch">Suchplugin f�r Firefox und IE</h4>
Installation des <a href="$bbbike_html/opensearch/opensearch.html">Suchplugins</a>
<h4>Mozilla-Sidebar</h4>
<form name="bbbike_add_sidebar" action="#">
<a href="#" onclick="return addSidebar(document.forms.bbbike_add_sidebar)"><!-- img src="http://developer.netscape.com/docs/manuals/browser/sidebar/add-button.gif" alt="Add sidebar" border=0 -->Add sidebar</a>, dabei folgende Adressen optional als Default verwenden:<br>
<table>
<tr><td><img src="$bbbike_images/flag2_bl.gif" border=0 alt="Start"> Start:</td><td> <input size=10 name="start"></td></tr>
<tr><td><img src="$bbbike_images/flag_ziel.gif" border=0 alt="Ziel"> Ziel:</td><td> <input size=10 name="ziel"></td></tr>
</table>
</form>
EOF
    }
    {
	my $href = _bbbikeleaflet_url();
	print <<EOF;
<h4 id="leaflet">BBBike &amp; Leaflet</h4>
Noch in Entwicklung: 
BBBike-Routen auf einer <a href="$href">Leaflet-Karte</a> suchen.<br>
Um Start- und Zielpunkt zu setzen, einfach Doppel-Klicks oder -Taps machen.
EOF
    }
    if ($can_google_maps) {
	print <<EOF;
<h4 id="googlemaps">BBBike auf Google Maps</h4>
Noch in Entwicklung: 
BBBike-Routen auf <a href="@{[ _bbbikegooglemap_url() ]}?mapmode=search;maptype=hybrid">Google Maps</a> suchen
EOF
    } else {
	print <<EOF;
<h4 id="googlemaps">Wo ist Google Maps?</h4>

Die Verwendung der Google Maps-Karte in eigenen Websites ist seit
Herbst 2018 nicht mehr frei m�glich. Auf BBBike wurde deshalb die
M�glichkeit der Routen-Anzeige auf Google Maps ausgeschaltet. Die
Alternative ist nun die Leaflet-API, die als Kartenmaterial entweder
eine BBBike-Karte oder eine OpenStreetMap-Karte verwendet.
EOF
    }
    if ($can_palmdoc) {
	print <<EOF;
<h4 id="palmexport">Palm-Export</h4>
<p>F�r den PalmDoc-Export ben�tigt man auf dem Palm einen entsprechenden
Viewer, z.B.
<a href="http://www.freewarepalm.com/docs/cspotrun.shtml">CSpotRun</a>.
F�r eine komplette Liste kompatibler Viewer siehe auch
<a href="http://www.freewarepalm.com/docs/docs_software.shtml">hier</a>.
EOF
    }
    print "<hr><p>\n";

    print "<h3 id='hardsoftware'>Hard- und Software</h3>\n";
    my $os;
    unless (defined $os || $^O eq 'MSWin32') {
	open UNAME, "-|" or exec qw(uname -sr);
	my $uname = <UNAME>;
	close UNAME;
	if ($uname) {
	    chomp($os = "$uname");
	}
    }
    # Config ist ungenau, weil perl evtl. f�r ein anderes Betriebssystem
    # compiliert wurde.
    unless (defined $os) {
	require Config;
        $os = "\U$Config::Config{'osname'} $Config::Config{'osvers'}\E";
    }

    my $cgi_date = eval { require POSIX; POSIX::strftime("%F", localtime((stat($0))[9])) };
    my $data_date;
    for (@Strassen::datadirs) {
	if (my(@s) = stat "$_/.modified") {
	    my @l = localtime $s[9];
	    $data_date = sprintf "%04d-%02d-%02d", $l[5]+1900,$l[4]+1,$l[3];
	    last;
	}
    }
    $data_date = "unbekannt" if !defined $data_date;
    print <<EOF;
Version des Programms bbbike.cgi: $VERSION ($cgi_date)<br>
Stand der Daten: $data_date<br>
bbbike.cgi ist Bestandteil von <a href="$BBBike::BBBIKE_SF_WWW">BBBike</a> Release $BBBike::VERSION<br><br>
EOF

    if (defined $os) {
        print "Betriebssystem: $os\n";
        if ($os =~ /freebsd/i) {
	    print "<a href=\"http://www.freebsd.org/\"><img align=right src=\"";
	    print "https://www.freebsd.org/gifs/powerani.gif";
	    print "\" border=0 alt='FreeBSD'></a>";
	} elsif ($os =~ /linux/i) {
	    print "<a href=\"http://www.linux.org/\"><img align=right src=\"";
	    print "https://static.lwn.net/images/linuxpower2.png";
	    print "\" border=0 alt='Linux'></a>";
	    if (-e "/etc/debian_version" || -e "/etc/debian-release") {
		print "<a href=\"http://www.debian.org/\"><img align=right src=\"";
		print "https://www.debian.org/logos/openlogo-nd-25.png";
		print "\" border=0 alt='Debian'></a>";
	    }
	}
        print "<p>";
    }
    if (defined $ENV{'SERVER_SOFTWARE'}) {
	print "HTTP-Server: $ENV{'SERVER_SOFTWARE'}\n";
	if ($ENV{'SERVER_SOFTWARE'} =~ /apache/i) {
	    print "<a href=\"http://www.apache.org/\"><img align=right src=\"";
	    print "https://httpd.apache.org/apache_pb.gif";
	    print "\" alt=\"apache httpd\" border=0></a>";
	} elsif ($ENV{'SERVER_SOFTWARE'} =~ /lighttpd/i) {
	    print "<a href=\"http://www.lighttpd.net/\"><img align=right src=\"";
	    print "https://www.lighttpd.net/light_button.png";
	    print "\" alt=\"lighttpd\" border=0></a>";
	}
	print "<p>";
    }
    if ($ENV{SERVER_NAME} =~ /sourceforge/) {
	print <<EOF;
<A href="http://sourceforge.net"> <IMG align=right
src="https://sourceforge.net/sflogo.php?group_id=19142"
width="88" height="31" border="0" alt="SourceForge"></A><p>
EOF
    }

    print <<EOF;
Verwendete Software:
<ul>
<li><a href="$perl_url">perl $]</a><a href="$perl_url"><img border=0 align=right src="https://www.perlfoundation.org/uploads/1/0/6/6/106663517/powered-by-perl-135px_orig.png" alt="Perl"></a>
<li>perl-Module:<a href="$cpan"><img border=0 align=right src="https://www.cpan.org/misc/images/cpan.png" alt="CPAN"></a>
<ul>
<li><a href="${scpan}CGI">CGI $CGI::VERSION</a>
EOF
    if (defined $Apache::VERSION) {
	print <<EOF;
<li><a href="${scpan}Apache">Apache $Apache::VERSION</a> (auch bekannt als <a href="http://perl.apache.org">mod_perl</a>)
EOF
    }
    print <<EOF;
<li><a href="${scpan}GD">GD</a> f�r das Erzeugen der GIF/PNG/JPEG-Grafik
EOF
    if ($bbbikedraw_pdf_module && $bbbikedraw_pdf_module eq 'PDFCairo') {
	print <<EOF;
<li><a href="${scpan}Cairo">Cairo</a> und <a href="${scpan}Pango">Pango</a> f�r das Erzeugen der PDF-Grafik
EOF
    } else {
	print <<EOF;
<li><a href="${scpan}PDF::Create">PDF::Create</a> f�r das Erzeugen der PDF-Grafik
EOF
    }
    print <<EOF;
<li><a href="${scpan}SVG">SVG</a> f�r das Erzeugen von SVG-Dateien
<li><a href="${scpan}Storable">Storable</a> f�r das Caching
<li><a href="${scpan}String::Approx">String::Approx</a> f�r approximatives Suchen von Stra�ennamen (anstelle von <a href="ftp://ftp.cs.arizona.edu/agrep/">agrep</a>)
<li><a href="${scpan}XML::LibXML">XML::LibXML</a> (und libxml2) zum Parsen und Erzeugen von XML
EOF
    if ($can_palmdoc) {
	print <<EOF;
<li><a href="${scpan}Palm::PalmDoc">Palm::PalmDoc</a> f�r den PalmDoc-Export
EOF
    }
    print <<EOF;
<li>u.v.a.
</ul>
EOF
    if ($can_mapserver) {
        print <<EOF;
<li><a href="https://mapserver.org/">Mapserver</a>
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
<h3 id="disclaimer">Disclaimer</h3>
Es wird keine Gew�hr f�r die Inhalte dieser Site sowie verlinkter Sites �bernommen.
<hr>

EOF

    print <<EOF;
<h3 id="autor">Kontakt</h3>
<center>
Autor: Slaven Rezic<br>
<a href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike">E-Mail:</a> <a href="mailto:@{[ $BBBike::EMAIL ]}?subject=BBBike">@{[ $BBBike::EMAIL ]}</a><br>
<a href="@{[ $BBBike::HOMEPAGE ]}">Homepage:</a> <a href="@{[ $BBBike::HOMEPAGE ]}">@{[ $BBBike::HOMEPAGE ]}</a><br>
Telefon: @{[ CGI::escapeHTML("+49-172-1661969") ]}<br>
Slaven Rezi&#x107; (Tomi&#x107;)<br>Donji Crna&#x10d;, BiH-88220 &#x160;iroki Brijeg<br>Seumestr. 31, 10245 Berlin<br>
</center>
<p>
EOF

    # XXX Wo geh�ren die Fu�noten am besten hin?
    print <<EOF;
<p><p><p><hr>
Fu�noten:<br>
<sup id="footnote1">1</sup> @{[ footnote(1) ]}<hr><p>
EOF

    footer();

    print $q->end_html;
}

sub footnote {
    my($nr) = @_;
    if ($nr == 1) {
	<<EOF;
R. Dechter and J. Pearl, Generalized
best-first search strategies and the optimality of A<sup>*</sup>,
Journal of the Association for Computing Machinery, Vol. 32, No. 3,
July 1985, Seiten 505-536.
EOF
    } else {
	"";
    }
}

sub add_qrcode_cgi {
    my $url = shift;
    $url =~ s{(/cgi(-bin)?/)}{$1qrcode.cgi/};
    $url;
}

sub add_qrcode_html {
    my($href, $title) = @_;
    my $qrcode_href = add_qrcode_cgi($href);
    $title = CGI::escapeHTML($title);
    qq{<a href="$qrcode_href" onclick='return show_single_image(this.href);' title="QR Code - $title"><img style="vertical-align:bottom; padding-left:2px;" src="$bbbike_images/QR_icon_16x16.png" width="16" height="16" border="0" alt="QR Code - $title"></a>};
}

sub _linkify {
    my $text = shift;
    $text =~ s{\b(https:\S+)}{<a href="$1">$1</a>}g;
    $text;
}

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=head1 COPYRIGHT

Copyright (C) 1998-2020,2022 Slaven Rezic. All rights reserved.
This is free software; you can redistribute it and/or modify it under the
terms of the GNU General Public License, see the file COPYING.

=head1 SEE ALSO

bbbike(1).

=cut

