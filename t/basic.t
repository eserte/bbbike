#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: basic.t,v 1.13 2006/08/26 14:53:46 eserte Exp $
# Author: Slaven Rezic
#

use strict;
use FindBin;
use ExtUtils::Manifest;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

chdir "$FindBin::RealBin/.." or die $!;

my $manifest = ExtUtils::Manifest::maniread();

my @files = (qw(bbbike cmdbbbike cbbbike smsbbbike),
	     grep { !m{/test.pl$} }
	     grep { !m{ext/Strassen-Inline2/t/common.pl$} }
	     grep { /(\.PL|\.pl|\.cgi|\.pm)$/ }
	     sort keys %$manifest);

my $tests_per_file = 2;
plan tests => $tests_per_file * scalar @files;

for my $f (@files) {
 SKIP: {
	skip "$f not ready for stand-alone test", $tests_per_file
	    if $f =~ m{^ (BBBikeWeather.pm | BBBikePrint.pm) $}x;

	skip "$f works only with installed StrassenNetz/CNetFilePerl.pm", $tests_per_file
	    if $f =~ m{StrassenNetz-CNetFile/CNetFile(Dist)?.pm$} && !eval { require StrassenNetz::CNetFilePerl };
	skip "$f needs Tk", $tests_per_file
	    if $f =~ m{^( lib/TkChange.pm
			| lib/AutoInstall/Tk.pm
                        | bbbike
		        | BBBikeAdvanced.pm
		        | BBBikeEdit.pm
		        | PointEdit.pm
 			)$}x && !eval { require Tk };
	skip "$f needs Inline", $tests_per_file
	    if $f =~ m{ext/(Strassen-Inline|StrassenNetz-CNetFile).*} && !eval { require Inline::MakeMaker };
	skip "$f needs 5.8.0 or better", $tests_per_file
	    if $f eq 'BBBikeDebug.pm' && $] < 5.008;;
	skip "$f needs Imager", $tests_per_file
	    if $f eq 'BBBikeDraw/Imager.pm' && !eval { require Imager };
	skip "$f needs Image::Magick", $tests_per_file
	    if $f eq 'BBBikeDraw/ImageMagick.pm' && !eval { require Image::Magick };
	skip "$f needs SVG", $tests_per_file
	    if $f eq 'BBBikeDraw/SVG.pm' && !eval { require SVG };
	skip "$f needs GD", $tests_per_file
	    if $f =~ m{^BBBikeDraw/GD.*\.pm$} && !eval { require GD };
	skip "$f needs Tk::Wizard", $tests_per_file
	    if $f eq 'BBBikeImportWizard.pm' && !eval { require Tk::Wizard };
	skip "$f needs GPS::Garmin", $tests_per_file
	    if $f =~ m{^GPS/(DirectGarmin|GpsmanConn).pm$} && !eval { require GPS::Garmin };
	skip "$f needs Algorithm::Permute", $tests_per_file
	    if $f eq 'Salesman.pm' && !eval { require Algorithm::Permute; Algorithm::Permute->VERSION(0.06) };
	skip "$f needs CDB_File", $tests_per_file
	    if $f eq 'Strassen/CDB.pm' && !eval { require CDB_File };
	skip "$f needs Object::Realize::Later", $tests_per_file
	    if $f eq 'Strassen/Lazy.pm' && !eval { require Object::Realize::Later };
	skip "$f needs DBD::Pg", $tests_per_file
	    if $f eq 'Strassen/Pg.pm' && !eval { require DBD::Pg };
	skip "$f needs X11::Protocol", $tests_per_file
	    if $f eq 'lib/Tk/RotX11Font.pm' && !eval { require X11::Protocol };
	skip "$f needs XML::LibXML", $tests_per_file
	    if $f =~ m{^( Strassen/Touratech.pm
			)$}x && !eval { require XML::LibXML };
	skip "$f needs XML::LibXML or XML::Twig", $tests_per_file
	    if $f =~ m{^( Strassen/GPX.pm
		      )$}x && !eval { require XML::LibXML } && !eval { require XML::Twig };
	skip "$f needs XML::LibXSLT", $tests_per_file
	    if $f eq 'Strassen/Touratech.pm' && !eval { require XML::LibXSLT };
	skip "$f needs Class::Accessor", $tests_per_file
	    if $f =~ m{^( BBBikeDraw/MapServer.pm
		        | ESRI/Shapefile.pm
		        | ESRI/Shapefile/.*.pm
		        | BBBikeESRI.pm
		        | Strassen/ESRI.pm
		      )$}x && !eval { require Class::Accessor };

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
	my $diag_file = "/tmp/bbbike-basic.text";
	open(STDERR, ">$diag_file") or die $!;

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
		$warn .= $_;
	    }
	    is($warn, "", "Warnings " . ($can_w ? "" : "(only mandatory) ") . "in $f");
	}

	unlink $diag_file;
    }
}

__END__
