#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: basic.t,v 1.22 2009/02/01 18:50:54 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use ExtUtils::Manifest;
use Getopt::Long;
use File::Spec qw();

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my $do_skip = 1;
GetOptions("skip!" => \$do_skip)
    or die "usage: $0 [-noskip]";

chdir "$FindBin::RealBin/.." or die $!;

my $manifest = ExtUtils::Manifest::maniread();

my @files = (qw(bbbike cmdbbbike cbbbike smsbbbike),
	     grep { !m{/test.pl$} }
	     grep { !m{ext/Strassen-Inline2/t/common.pl$} }
	     grep { /(\.PL|\.pl|\.cgi|\.pm)$/ }
	     sort keys %$manifest);

my $tests_per_file = 2;
plan tests => $tests_per_file * scalar @files;

my $has_skips = 0;
sub myskip ($$) {
    my($why, $howmany) = @_;
    if ($do_skip) {
	$has_skips++;
	skip $why, $howmany;
    }
}

for my $f (@files) {
 SKIP: {
	skip "$f not ready for stand-alone test", $tests_per_file
	    if $f =~ m{^ (BBBikeWeather.pm) $}x;

	myskip "$f works only with installed StrassenNetz/CNetFilePerl.pm", $tests_per_file
	    if $f =~ m{StrassenNetz-CNetFile/CNetFile(Dist)?.pm$} && !eval { require StrassenNetz::CNetFilePerl };
	myskip "$f works only with installed PDF::Create", $tests_per_file
	    if $f =~ m{BBBikeDraw/PDF\.pm$} && !eval { require PDF::Create };
	myskip "$f needs Tk", $tests_per_file
	    if $f =~ m{^( lib/TkChange.pm
			| lib/AutoInstall/Tk.pm
                        | bbbike
		        | BBBikeAdvanced.pm
		        | BBBikeEdit.pm
		        | PointEdit.pm
			| GPS/GpsmanData/Tk.pm
 			)$}x && !eval { require Tk };
	myskip "$f needs Inline", $tests_per_file
	    if $f =~ m{ext/(Strassen-Inline|StrassenNetz-CNetFile).*} && !eval { require Inline::MakeMaker };
	myskip "$f needs 5.8.0 or better", $tests_per_file
	    if $f eq 'BBBikeDebug.pm' && $] < 5.008;;
	myskip "$f needs Imager", $tests_per_file
	    if $f eq 'BBBikeDraw/Imager.pm' && !eval { require Imager };
	myskip "$f needs Image::Magick", $tests_per_file
	    if $f eq 'BBBikeDraw/ImageMagick.pm' && !eval { require Image::Magick };
	myskip "$f needs SVG", $tests_per_file
	    if $f eq 'BBBikeDraw/SVG.pm' && !eval { require SVG };
	myskip "$f needs GD", $tests_per_file
	    if $f =~ m{^BBBikeDraw/GD.*\.pm$} && !eval { require GD };
	myskip "$f needs Tk::Wizard", $tests_per_file
	    if $f eq 'BBBikeImportWizard.pm' && !eval { require Tk::Wizard };
	myskip "$f needs GPS::Garmin", $tests_per_file
	    if $f =~ m{^GPS/(DirectGarmin|GpsmanConn).pm$} && !eval { require GPS::Garmin };
	myskip "$f needs Algorithm::Permute", $tests_per_file
	    if $f eq 'Salesman.pm' && !eval { require Algorithm::Permute; Algorithm::Permute->VERSION(0.06) };
	myskip "$f needs CDB_File", $tests_per_file
	    if $f eq 'Strassen/CDB.pm' && !eval { require CDB_File };
	myskip "$f needs Object::Realize::Later", $tests_per_file
	    if $f eq 'Strassen/Lazy.pm' && !eval { require Object::Realize::Later };
	myskip "$f needs DBD::Pg", $tests_per_file
	    if $f eq 'Strassen/Pg.pm' && !eval { require DBD::Pg };
	myskip "$f needs X11::Protocol", $tests_per_file
	    if $f eq 'lib/Tk/RotX11Font.pm' && !eval { require X11::Protocol };
	myskip "$f needs XML::LibXML", $tests_per_file
	    if $f =~ m{^( Strassen/Touratech.pm
			| Strassen/KML.pm
			| GPS/KML.pm
			)$}x && !eval { require XML::LibXML };
	myskip "$f needs XML::LibXML or XML::Twig", $tests_per_file
	    if $f =~ m{^( Strassen/GPX.pm
		        | GPS/GPX.pm
		      )$}x && !eval { require XML::LibXML } && !eval { require XML::Twig };
	myskip "$f needs XML::LibXML::Reader", $tests_per_file
	    if $f eq 'GPS/GpsmanData/SportsTracker.pm' && !eval { require XML::LibXML::Reader };
	myskip "$f needs XML::LibXSLT", $tests_per_file
	    if $f eq 'Strassen/Touratech.pm' && !eval { require XML::LibXSLT };
	myskip "$f needs Class::Accessor", $tests_per_file
	    if $f =~ m{^( BBBikeDraw/MapServer.pm
		        | ESRI/Shapefile.pm
		        | ESRI/Shapefile/.*.pm
		        | BBBikeESRI.pm
		        | Strassen/ESRI.pm
		        | ESRI/esri2bbd.pl
		      )$}x && !eval { require Class::Accessor };
	myskip "$f needs Template (Toolkit)", $tests_per_file
	    if $f =~ m{^( BBBikeDraw/MapServer.pm
		      )$}x && !eval { require Template; 1 };
	myskip "$f needs Archive::Zip", $tests_per_file
	    if $f =~ m{^( cgi/bbbike-data.cgi
		      )$}x && !eval { require Archive::Zip; 1 };
	myskip "$f needs MIME::Lite", $tests_per_file
	    if $f =~ m{^( cgi/mapserver_comment.cgi
		      )$}x && !eval { require MIME::Lite; 1 };
	myskip "$f does not work on Win32", $tests_per_file
	    if $f =~ m{^( lib/Tk/ContextHelp.pm
		      )$}x && $^O eq 'MSWin32';
	myskip "$f needs Text::LevenshteinXS", $tests_per_file
	    if $f =~ m{^( PLZ/Levenshtein.pm
		      )$}x && !eval { require Text::LevenshteinXS; 1 };
	myskip "$f needs JSON::XS", $tests_per_file
	    if $f =~ m{^( BBBikeCGIAPI.pm
		      )$}x && !eval { require JSON::XS; 1 };

	my @add_opt;
	if ($f =~ m{Tk/.*\.pm}) {
	    push @add_opt, "-MTk";
	}
	if ($f =~ /(.*)Heavy(.*)/) {
	    my $non_heavy = "$1$2";
	    $non_heavy =~ s{/\.pm$}{.pm};
	    $non_heavy =~ s{/}{::}g;
	    $non_heavy =~ s{\.pm$}{}g;
	    if ($non_heavy ne "BBBike") {
		push @add_opt, "-M$non_heavy";
	    }
	}
	*OLDERR = *OLDERR; # cease -w
	open(OLDERR, ">&STDERR") or die;
	my $diag_file = File::Spec->tmpdir . "/bbbike-basic.text";
	open(STDERR, ">$diag_file") or die "Can't write to $diag_file: $!";

	my $can_w = 1;
	if ($f =~ m{^( lib/Tk/FastSplash.pm # keep it small without peacifiers
		     | BBBikeVar.pm # having only one variable here is natural
		       # too lazy to fix warnings in the following ones...
		     | BBBikeHeavy.pm
		     | GIS/Globe.pm
		     | BBBikeLazy.pm
		     | lib/Win32Util.pm
		     | BBBikePersonal.pm
		     | BBBikeEditUtil.pm
		     | BBBikeSalesman.pm
		     | Strassen/Util.pm
		     | lib/TkCompat.pm
		     | cgi/bbbike-teaser.pl
		     | BBBikeDraw/GD.pm
		     | cgi/berlinmap.cgi
		     | lib/WWWBrowser.pm
		     | BBBikeScribblePlugin.pm
		     | Route.pm
		     | ext/VectorUtil-Inline/Inline.pm
		     | Strassen/StrassenNetzHeavy.pm
		     | lib/Tk/WidgetDump.pm
		     | ext/BBBikeXS/BBBikeXS.pm
		     | Geography/Muenchen_DE.pm
		     | lib/Tk/RotFont.pm
		     | PLZ.pm
		     | Karte/UTM.pm
		     | BBBikeRouting.pm
		     | BBBikeRuler.pm
		     | Strassen/MapInfo.pm
		     | lib/GD/Convert.pm
		     | lib/Tk/StippleLine.pm
		     | GPS/Unknown1.pm
		     | FURadar.pm
		     | MasterPunkte.pm
		     | Wizards.pm
		     | install.pl
		     | cgi/configure-bbbike.cgi
		     | BBBikeAdvanced.pm
		     | Karte/SatmapGIF.pm
		     | PointEdit.pm
		     | Strassen/Storable.pm
		     | BBBikeMenubar.pm
		     | BBBikeEdit.pm
		     | BBBikeStats.pm
		     | BBBikePlugin.pm
		     | Strassen/MultiBezStr.pm
		     | GPS/DirectGarmin.pm
		     | GPS/SerialStty.pm
		     | lib/AutoInstall/Tk.pm # this is because of warnings in CPAN.pm
		   )$}x) {
	    $can_w = 0;
	}

	$can_w = 0 if $] < 5.006; # too many additional warnings

	system($^X, ($can_w ? "-w" : ()), "-c", "-Ilib", @add_opt, "./$f");
	close STDERR;
	open(STDERR, ">&OLDERR") or die;
	die "Signal caught" if $? & 0xff;

	my $skip_no_tk;
	my $diag;
	if (open(DIAG, $diag_file)) {
	    local $/ = undef;
	    $diag = <DIAG>;
	    close DIAG;

	    if ($diag =~ /Can\'t locate Tk.pm/) {
		$skip_no_tk = 1;
	    }
	}

	skip "$f needs Tk", $tests_per_file if $skip_no_tk;

	is($?, 0, "Check $f")
	    or do {
		require Text::Wrap;
		print Text::Wrap::wrap("# ", "# ", $diag), "\n";
	    };

	if (defined $diag && $diag ne "") {
	    my $warn = "";
	    for (split /\n/, $diag) {
		next if / syntax OK/;
		# This one seen with ActivePerl 5.8.8
		next if $^O eq 'MSWin32' && /\QSet up gcc environment - 3.4.4 (cygming special, gdc 0.12, using dmd 0.125)/;
		next if $^O eq 'MSWin32' && /\QSet up gcc environment - 3.4.5 (mingw special)/;
		$warn .= $_;
	    }
	    is($warn, "", "Warnings " . ($can_w ? "" : "(only mandatory) ") . "in $f");
	}

	unlink $diag_file;
    }
}

if ($has_skips) {
    diag <<EOF;

There were skips because of missing modules or other prerequisites. You can
rerun this test with

    $^X $0 -noskip

to see failing tests because of these modules.
EOF
}

__END__
