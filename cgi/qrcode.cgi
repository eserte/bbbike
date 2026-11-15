#!/usr/bin/env perl
#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017,2026 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# WWW:  https://github.com/eserte/bbbike
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..";
use BBBikeCGI::Util ();

our $IMPL = 'Imager'; # or 'GD'
our $DEBUG = 0;

sub debug ($) {
    return if !$DEBUG;
    warn "$_[0]\n";
}

sub gd_qrcode_png {
    my $url = shift;
    require GD::Barcode::QRcode;
    GD::Barcode::QRcode->new($url, { Ecc => 'L', ModuleSize => 4})->plot->png; # maximum is about 350 bytes
}

sub imager_qrcode_png {
    my $url = shift;
    require Imager::QRCode;
    my $img = Imager::QRCode->new(casesensitive => 1)->plot($url);
    my $data;
    $img->write(data => \$data, type => 'png')
	or die $img->errstr;
    $data;
}

sub cgi {
    require CGI;
    local $CGI::DISABLE_UPLOADS = 1;
    my $q = CGI->new;
    binmode STDOUT;
    my $url_arg = BBBikeCGI::Util::my_url($q, -path_info => 1, -query => 1);
    $url_arg =~ s{/qrcode\.cgi(?:/(\.l|\.p))?}{};
    if ($1) {
	my $host = (
		    $1 eq '.l' ? 'bbbike.de' :
		    $1 eq '.p' ? 'bbbike-pps-bookworm' :
		    die "UNEXPECTED ERROR ($1)"
		   );
	debug "Requested change of host to '$host'";
	require URI;
	my $u = URI->new($url_arg);
	$u->host($host);
	$url_arg = $u->as_string;
    }

    # according to https://www.qrcode.com/en/about/version.html limit
    # for version 40 is 2953 bytes, however the actual limit for the
    # Imager implementation is somewhat lower
    if (length $url_arg > ($IMPL eq 'Imager' ? 2938 : 2953)) {
	warn "qrcode.cgi: URL too long (" . length($url_arg) . " bytes), return 414 response.\n";
	print $q->header(-status => '414 URI Too Long', -type => 'text/plain'), "URL too long\n";
	return;
    }

    debug "Transformed URL: '$url_arg'";
    print $q->header(
	-type => 'image/png',
	'-x-qrcode-url' => $url_arg,
	'-cache-control' => 'public, max-age=' . (7*24*3600),
    );
    if ($IMPL eq 'Imager') {
	debug 'Use Imager implementation';
	print imager_qrcode_png($url_arg);
    } else {
	debug 'Use GD implementation';
	print gd_qrcode_png($url_arg);
    }
}

cgi();

__END__
