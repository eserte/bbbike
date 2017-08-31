#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

use strict;

our $IMPL = 'Imager';
our $DEBUG = 0;

sub debug ($) {
    return if !$DEBUG;
    warn "$_[0]\n";
}

sub gd_qrcode_png {
    my $url = shift;
    require GD::Barcode::QRcode;
    GD::Barcode::QRcode->new($url, { Ecc => 'L', Version=>12, ModuleSize => 4})->plot->png;
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
    my $q = CGI->new;
    binmode STDOUT;
    print $q->header('image/png');
    my $url_arg = $q->self_url;
    $url_arg =~ s{/qrcode\.cgi(?:/(\.l|\.h))?}{};
    if ($1) {
	my $host = (
		    $1 eq '.l' ? 'bbbike.de' :
		    $1 eq '.h' ? 'bbbike.v.timesink.de' :
		    die "UNEXPECTED ERROR ($1)"
		   );
	debug "Requested change of host to '$host'";
	require URI;
	my $u = URI->new($url_arg);
	$u->host($host);
	$url_arg = $u->as_string;
    }
    debug "Transformed URL: '$url_arg'";
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
