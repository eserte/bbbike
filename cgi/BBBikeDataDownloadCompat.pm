# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDataDownloadCompat;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Apache2::Const qw(OK DECLINED);
use Apache2::RequestRec ();
use Apache2::RequestIO ();

sub handler : method {
    my($class, $r) = @_;
    my $ua = $r->headers_in->{'User-Agent'};
    my $filename = $r->filename;
    if ($filename =~ m{/data/(?:strassen|landstrassen|landstrassen2)$} &&
	$ua =~ m{^bbbike/([\d.]+)}i && $1 < 3.17
       ) {
	# Debugging. Remove some day XXX
	warn qq{Doing "NH" fix in file <$filename> for <$ua>...\n};
	open my $fh, "<", $filename
	    or die "Can't open file <$filename> (should never happen): $!";
	$r->content_type('text/plain');
	while(<$fh>) {
	    s{\tNH }{\tN };
	    $r->print($_);
	}
	OK;
    } else {
	$r->handler('default');
	DECLINED;
    }
}

1;

__END__
