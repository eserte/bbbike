# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011,2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDataDownloadCompat;

use strict;
use vars qw($VERSION);
$VERSION = '0.02';

use Apache2::Const qw(OK DECLINED);
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use HTTP::Date qw(time2str);

sub handler : method {
    my($class, $r) = @_;
    my $ua = $r->headers_in->{'User-Agent'};
    my $filename = $r->filename;
    if ($filename =~ m{/data/(?:strassen|landstrassen|landstrassen2)$} &&
	$ua =~ m{^bbbike/([\d.]+)}i && $1 < 3.17
       ) {
	if (my $if_modified_since = $r->headers_in->{'If-modified-since'}) {
	    my($mtime) = (stat($filename))[9];
	    # RFC 2616 14.25 allows this, see also Plack::Middleware::ConditionalGET
	    if ($if_modified_since eq time2str($mtime)) {
		$r->status(304);
		return OK;
	    }
	}

	# Debugging. Remove some day XXX
	warn qq{Doing "NH" fix in file <$filename> for <$ua>...\n};
	open my $fh, "<", $filename
	    or die "Can't open file <$filename> (should never happen): $!";
	$r->content_type('text/plain');
	$r->headers_out->{'X-BBBike-Hacks'} = 'NH';
	while(<$fh>) {
	    s{\tNH }{\tN };
	    $r->print($_);
	}
	OK;
    } elsif ($filename =~ m{/data/label$} &&
	     !-e $filename &&
	     $r->headers_in->{'If-modified-since'}) {
	# data/label was removed from MANIFEST some time ago, but some
	# clients maybe still access it
	# Debugging. Remove some day XXX
	warn qq{Faking <data/label> for <$ua>...\n};
	$r->status(304);
	OK;
    } else {
	$r->handler('default');
	DECLINED;
    }
}

1;

__END__
