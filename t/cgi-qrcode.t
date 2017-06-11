#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

BEGIN {
    if (!eval q{
	use LWP::UserAgent;
	use Test::More;
	1;
    }) {
	print "1..0 # skip no LWP::UserAgent, and/or Test::More modules\n";
	exit;
    }
}

use strict;
use FindBin;
use lib ($FindBin::RealBin, "$FindBin::RealBin/..");

use CGI qw();

use BBBikeTest qw(check_cgi_testing $cgidir image_ok);

check_cgi_testing;

plan 'no_plan';

my $qrcode_cgi = "$cgidir/qrcode.cgi";
my $ua = LWP::UserAgent->new(keep_alive => 1);
$ua->agent("BBBike-Test/1.0");
$ua->env_proxy;

{
    my $resp = $ua->get("$qrcode_cgi/bbbike.cgi?info=1");
    ok $resp->is_success;
    is $resp->content_type, 'image/png';
    my $data = $resp->decoded_content;
    image_ok(\$data);
    is_barcode($resp, type => "QR-Code", like_data => qr{^https?://.*\Q/bbbike.cgi?info=1\E$});
}

{
    my $resp = $ua->get("$qrcode_cgi/.l/bbbike.cgi?info=1");
    ok $resp->is_success, 'forcing live host';
    # In the error log should appear (if $DEBUG is on):
    #     Requested change of host to 'bbbike.de'
    is $resp->content_type, 'image/png';
    my $data = $resp->decoded_content;
    image_ok(\$data);
    is_barcode($resp, type => "QR-Code", is_data => q{http://bbbike.de/bbbike/cgi/bbbike.cgi?info=1});
}

sub is_barcode {
    my($http_resp, %checks) = @_;
    my $number_of_checks = 1 + scalar keys %checks;
    my $image_data = $http_resp->decoded_content;
    (my $image_type = $http_resp->content_type) =~ s{^image/}{};
 SKIP: {
	skip "Need Barcode::ZBar for thorough QRCode tests", $number_of_checks
	    if !eval { require Barcode::ZBar; 1 };
	skip "Need Imager or Image::Magick for thorough QRCode tests", $number_of_checks
	    if !eval { require Imager; 1 } && !eval { require Image::Magick; 1 };
	my $barcode_scanner = Barcode::ZBar::ImageScanner->new;
	my($raw, $width, $height, $converted_with);
	if (defined &Imager::new) {
	    my $imager = Imager->new(data => $image_data, type => $image_type)
		or die Imager->errstr();
	    ($width, $height) = ($imager->getwidth, $imager->getheight);
	    # transform to gray
	    my $gray = $imager->convert(matrix => [[1,0,0]])->to_rgb8;
	    $gray->write(data => \$raw, type => 'raw');
	    $converted_with = 'Imager';
	} else {
	    my $magick = Image::Magick->new;
	    $magick->Read(blob => $image_data);
	    ($width, $height) = $magick->Get(qw(columns rows));
	    $raw = $magick->ImageToBlob(magick => 'GRAY', depth => 8);
	    $converted_with = 'Image::Magick';
	}
	my $barcode_image = Barcode::ZBar::Image->new;
	$barcode_image->set_format('Y800');
	$barcode_image->set_size($width, $height);
	$barcode_image->set_data($raw);
	my $n = $barcode_scanner->scan_image($barcode_image);

	is $n, 1, "expect exactly one barcode image (converted with $converted_with)";
	my $symbol = ($barcode_image->get_symbols)[0];
	for my $check (keys %checks) {
	    if ($check eq 'type') {
		is $symbol->get_type, $checks{$check}, "expected type";
	    } elsif ($check eq 'like_data') {
		like $symbol->get_data, $checks{$check}, "expected data (regexp check)";
	    } elsif ($check eq 'is_data') {
		is $symbol->get_data, $checks{$check}, "expected data (exact check)";
	    } else {
		die "Unhandled check '$check' (only type, like_data, and is_data is allowed)";
	    }
	}
    }
}

__END__
