#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: cgi-mechanize-upload.t,v 1.4 2005/03/23 22:01:56 eserte Exp $
# Author: Slaven Rezic
#

use strict;

BEGIN {
    if (!eval q{
	use WWW::Mechanize 1.08; # images method
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More and/or WWW::Mechanize modules or outdated versions\n";
	exit;
    }
}

use FindBin;
use lib ("$FindBin::RealBin",
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib", # for enum.pm
	);
use BBBikeTest;
use File::Temp qw(tempfile);

# See also: https://rt.cpan.org/NoAuth/Bug.html?id=9268
sub WWW::Mechanize::_image_from_token {
    my $self = shift;
    my $token = shift;
    my $parser = shift;

    my $tag = $token->[0];
    my $attrs = $token->[1];

    if ( $tag eq "input" ) {
        my $type = $attrs->{type} or return;
        return unless $type =~ /^(?:submit|image)$/;
    }

    require WWW::Mechanize::Image;
    return
        WWW::Mechanize::Image->new({
            tag     => $tag,
            base    => $self->base,
            url     => $attrs->{src},
            name    => $attrs->{name},
            height  => $attrs->{height},
            width   => $attrs->{width},
            alt     => $attrs->{alt},
        });
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

my $sample_coords = [[8982,8781], [9050,8783], [9222,8787],
		     [9227,8890], [9796,8905], [9799,8962]];

plan tests => 3 + $gpsman_tests * @gps_types;

{
    my $agent = WWW::Mechanize->new();
    set_user_agent($agent);

    $agent->get($cgiurl);
    like($agent->content, qr{BBBike}, "Startpage $cgiurl is not empty");

    $agent->follow(qr{Info});
    like($agent->content, qr{Information}, "Information page found");

    $agent->follow(qr{GPS-Tracks});
    like($agent->content, qr{Anzuzeigende Route-Datei}, "Upload page found");

    for my $gps_type (@gps_types) {
    SKIP: {
	    my $filename;

	    if ($gps_type eq 'trk') {
		# Find a random gpsman track
		my $gpsman_data_dir = "$FindBin::RealBin/../misc/gps_data";
		skip("No gps_data directory available", $gpsman_tests)
		    if !-d $gpsman_data_dir;
		my @trk = glob("$gpsman_data_dir/*.trk");
		skip("No tracks available", $gpsman_tests)
		    if !@trk;
		$filename = $trk[rand(@trk)];
	    } elsif ($gps_type eq 'ovl') {
		my $ovl_data_dir = "$FindBin::RealBin/../misc/ovl_resources/ulamm";
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
	    } elsif ($gps_type eq 'trk-generated') {
		(undef, $filename) = tempfile(UNLINK => !$debug,
					      SUFFIX => ".ovl");
		require GPS::GpsmanData;
		require Route;
		my $route = Route->new_from_realcoords($sample_coords);
		my $trk = GPS::GpsmanData->new;
		$trk->convert_from_route($route);
		$trk->write($filename);
	    }
	    
	    if ($do_xxx) {
		goto XXX;
	    }
	
	SKIP: {
		my $form = $agent->current_form;
		$form->value("routefile", $filename);
		eval { $form->value("imagetype", "png") };
		skip("Cannot do png imagetype", $png_tests) if $@;
		
		$agent->submit;

		is($agent->ct, "image/png", "It's a png")
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
		
		is($agent->ct, "application/pdf", "It's a pdf");
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
		
		is($agent->ct, "text/html", "It's a html file");
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
		like($agent->ct, qr{^image/}, "It's an image (png or gif)");
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

