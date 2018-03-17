# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2015,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDataDownloadCompat;

use strict;
use vars qw($VERSION);
$VERSION = '0.04';

use Apache2::Const qw(OK DECLINED);
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use HTTP::Date qw(time2str str2time);

sub handler : method {
    my($class, $r) = @_;
    my $ua = $r->headers_in->{'User-Agent'};
    my $filename = $r->filename;
    if ($filename =~ m{/data/(?:strassen|landstrassen|landstrassen2)$} &&
	$ua =~ m{^bbbike/([\d.]+)}i && $1 < 3.17
       ) {
	if (my $if_modified_since = $r->headers_in->{'If-modified-since'}) {
	    my($mtime) = (stat($filename))[9];
	    if (str2time($if_modified_since) >= $mtime) {
		$r->status(304);
		return OK;
	    }
	}

	# Debugging. Remove some day XXX
	warn qq{Doing "NH" fix in file <$filename> for <$ua>...\n};
	open my $fh, "<", $filename
	    or die "Can't open file <$filename> (should never happen): $!";
	$r->content_type('text/plain');
	my($mtime) = (stat($filename))[9];
	$r->headers_out->{'Last-Modified'} = time2str($mtime);
	$r->headers_out->{'X-BBBike-Hacks'} = 'NH';
	while(<$fh>) {
	    s{\tNH }{\tN };
	    $r->print($_);
	}
	OK;
    } elsif ($filename =~ m{/data/(label|multi_bez_str)$} &&
	     !-e $filename &&
	     $r->headers_in->{'If-modified-since'}) {
	# data/label & multi_bez_str was removed from MANIFEST some time ago, but some
	# clients maybe still access it
	# Debugging. Remove some day XXX
	warn qq{Faking <$filename> for <$ua>...\n};
	$r->status(304);
	OK;
    } else {
	$r->handler('default');
	DECLINED;
    }
}

1;

__END__
