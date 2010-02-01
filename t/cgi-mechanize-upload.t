#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize-upload.t,v 1.9 2008/08/22 18:27:54 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize 1.12; # images method (1.08), _image_from_token fix (1.12)
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More and/or WWW::Mechanize modules or outdated versions\n";
	exit;
    }
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib", # for enum.pm
	);
use BBBikeTest;
use File::Basename qw(basename);
use File::Temp qw(tempfile);

BEGIN {
    if ($] < 5.006) {
	$INC{"warnings.pm"} = 1;
	*warnings::import = sub { };
	*warnings::unimport = sub { };
    }
}

my @gps_types = ("trk", "ovl", "bbr",
		 "bbr-generated", "ovl-generated", "trk-generated",
		);
my $png_tests = 2;
my $pdf_tests = 2;
my $mapserver_tests = 5;
my $gpsman_tests = $png_tests + $pdf_tests + $mapserver_tests;
my $only;

use Getopt::Long;

if (!GetOptions(get_std_opts("cgiurl", "xxx", "display", "debug"),
		"only=s" => \$only,
	       )) {
    die "usage: $0 [-cgiurl url] [-xxx] [-display] [-debug] [-only type]";
}

if (defined $only) {
    @gps_types = grep { $_ eq $only } @gps_types;
}

my $sample_coords = do {
    no warnings 'qw';
    [map { [split/,/] } qw(8982,8781 9076,8783 9229,8785 9227,8890 9801,8889)];
};

plan tests => 3 + $gpsman_tests * @gps_types;

{
    my $agent = WWW::Mechanize->new();
    set_user_agent($agent);

    $agent->get($cgiurl);
    like($agent->content, qr{BBBike}, "Startpage $cgiurl is not empty");

    $agent->follow_link(text_regex => qr{Info});
    like($agent->content, qr{Information}, "Information page found");

    $agent->follow_link(text_regex => qr{GPS-Tracks});
    like($agent->content, qr{Anzuzeigende Route-Datei}, "Upload page found");

    for my $gps_type (@gps_types) {
    SKIP: {
	    my $filename;
	    my $testname;

	    if ($gps_type eq 'trk') {
		# Find a random gpsman track
		my $gpsman_data_dir = "$FindBin::RealBin/../misc/gps_data";
		skip("No gps_data directory available", $gpsman_tests)
		    if !-d $gpsman_data_dir;
		my @trk = glob("$gpsman_data_dir/2???????.trk");
		skip("No tracks available", $gpsman_tests)
		    if !@trk;
		$filename = $trk[rand(@trk)];
	    } elsif ($gps_type eq 'ovl') {
		my $ovl_data_dir = "$FindBin::RealBin/../misc/download_tracks";
		skip("No ovl directory available", $gpsman_tests)
		    if !-d $ovl_data_dir;
		my @ovl = glob("$ovl_data_dir/*.{ovl,OVL}");
		skip("No overlays available", $gpsman_tests)
		    if !@ovl;
		$filename = $ovl[rand(@ovl)];
	    } elsif ($gps_type eq 'bbr') {
		my $bbr_data_dir = "$ENV{HOME}/.bbbike/route";
		skip("No bbbike route directory available", $gpsman_tests)
		    if !-d $bbr_data_dir;
		my @bbr = glob("$bbr_data_dir/*.bbr");
		skip("No bbbike route files available", $gpsman_tests)
		    if !@bbr;
		$filename = $bbr[rand(@bbr)];
	    } elsif ($gps_type eq 'bbr-generated') {
		(undef, $filename) = tempfile(UNLINK => !$debug,
					      SUFFIX => ".bbr");
		my $route = {RealCoords => $sample_coords,
			     Type => "bbr"};
		require Route;
		Route::save(-object => $route,
			    -file => $filename);
		$testname = "bbr-generated from sample coords";
	    } elsif ($gps_type eq 'ovl-generated') {
		my $fh;
		($fh, $filename) = tempfile(UNLINK => !$debug,
					    SUFFIX => ".ovl");
		print $fh <<'EOF';
[Symbol 1]
Typ=3
Group=1
Col=3
Zoom=1
Size=103
Art=1
Punkte=75
XKoord0=13.4337486
YKoord0=52.5100654
XKoord1=13.4305501
YKoord1=52.5113623
XKoord2=13.4302192
YKoord2=52.5102429
XKoord3=13.4277053
YKoord3=52.5076669
XKoord4=13.4257345
YKoord4=52.5059382
[Overlay]
Symbols=1
EOF
		close $fh;
		$testname = "ovl-generated from sample data";
	    } elsif ($gps_type eq 'trk-generated') {
		(undef, $filename) = tempfile(UNLINK => !$debug,
					      SUFFIX => ".trk");
		require GPS::GpsmanData;
		require Route;
		my $route = Route->new_from_realcoords($sample_coords);
		my $trk = GPS::GpsmanData->new;
		$trk->convert_from_route($route);
		$trk->write($filename);
		$testname = "trk-generated from sample coords";
	    }
	    
	    if ($do_xxx) {
		goto XXX;
	    }

	    $testname = basename $filename if !$testname;

	SKIP: {
		my $form = $agent->current_form;
		$form->value("routefile", $filename);
		eval { $form->value("imagetype", "png") };
		skip("Cannot do png imagetype", $png_tests) if $@;
		
		$agent->submit;

		is($agent->ct, "image/png", "It's a png (from $testname)")
		    or diag "Tried to upload $filename";
		my $content = $agent->content;
		cmp_ok($content, "ne", "", "Non-empty content");
		if ($do_display) {
		    do_display(\$content, "png");
		}
		
		$agent->back;
	    }

	SKIP: {
		my $form = $agent->current_form;
		$form->value("routefile", $filename);
		eval { $form->value("imagetype", "pdf-auto") };
		skip("Cannot do pdf imagetype", $pdf_tests) if $@;
		
		$agent->submit;
		
		is($agent->ct, "application/pdf", "It's a pdf (from $testname)");
		my $content = $agent->content;
		cmp_ok($content, "ne", "", "Non-empty content");
		if ($do_display) {
		    do_display(\$content, "pdf");
		}
		
		$agent->back;
	    }

	XXX: 1;
	    
	SKIP: {
		my $form = $agent->current_form;
		$form->value("routefile", $filename);
		eval { $form->value("imagetype", "mapserver") };
		skip("Cannot do mapserver imagetype", $mapserver_tests) if $@;
		
		$agent->submit;
		
		is($agent->ct, "text/html", "It's a html file (from $testname)");
		my $content = $agent->content;
		cmp_ok($content, "ne", "", "Non-empty content");
		
		my $img_href;
		my(@images) = $agent->images;
		for (@images) {
		    if ($_->name eq "img") {
			$img_href = $_->url;
			last;
		    }
		}
		ok($img_href, "Image URL found") or
		    diag "No image among " . scalar(@images) . " image objects";
		
		$agent->get($img_href);
		like($agent->ct, qr{^image/}, "It's an image (png or gif) (from $testname)");
		my $image_content = $agent->content;
		cmp_ok($image_content, "ne", "", "Non-empty content");
		if ($do_display) {
		    # Hopefully a png viewer can display gifs as well...
		    do_display(\$image_content, "png");
		}
		
		$agent->back;
		$agent->back;
	    }
	}
    }
}

