# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDataDownloadCompatPlack;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use Plack::Request ();
use HTTP::Date qw(time2str);

sub get_app {
    my($datadir) = @_;

    return sub {
	my $env = shift;

	my $req = Plack::Request->new($env);
	my $h = $req->headers;
	my $ua = $h->header('User-Agent');
	my $filename = $datadir . $req->path_info;

	if (_not_modified($h, $filename)) {
	    return $req->new_response(304)->finalize;
	}

	if ($filename =~ m{/data/(?:strassen|landstrassen|landstrassen2)$}) {
	    if ($ua =~ m{^bbbike/([\d.]+)}i && $1 < 3.17) {
		return sub {
		    my $respond = shift;
		    # Debugging. Remove some day XXX
		    warn qq{Doing "NH" fix in file <$filename> for <$ua>...\n};
		    open my $fh, '<', $filename
			or die "Can't open file <$filename> (should never happen): $!";
		    my $writer = $respond->([200, [
						   'Content-Type' => 'text/plain',
						   'X-BBBike-Hacks' => 'NH',
						  ]
					    ]);
		    while(<$fh>) {
			s{\tNH }{\tN };
			$writer->write($_);
		    }
		    $writer->close;
		};
	    }
	} elsif ($filename =~ m{/data/label$} && !-e $filename) {
	    if ($h->header('If-modified-since')) {
		# data/label was removed from MANIFEST some time ago, but some
		# clients maybe still access it
		# Debugging. Remove some day XXX
		warn qq{Faking <data/label> for <$ua>...\n};
		return $req->new_response(304)->finalize;
	    }
	}

	open my $fh, '<', $filename
	    or die "Can't open file <$filename> (can this ever happen?): $!";
	my $res = $req->new_response(200);
	if ($filename =~ m{\.gif$}) {
	    $res->content_type('image/gif');
	} else {
	    $res->content_type('text/plain');
	}
	$res->header('Last-Modified', time2str((stat($filename))[9]));
	$res->body($fh);
	return $res->finalize;
    };
}

sub _not_modified {
    my($h, $filename) = @_;
    if (my $if_modified_since = $h->header('If-modified-since')) {
	my($mtime) = (stat($filename))[9];
	# RFC 2616 14.25 allows this, see also Plack::Middleware::ConditionalGET
	if ($if_modified_since eq time2str($mtime)) {
	    return 1;
	}
    }
    0;
}

1;

__END__
