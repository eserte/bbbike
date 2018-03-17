# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015,2018 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeDataDownloadCompatPlack;

use strict;
use vars qw($VERSION);
$VERSION = '0.04';

use Cwd ();
use HTTP::Date qw(time2str str2time);
use Plack::Request ();
use Plack::Util ();

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
		    my @stat = stat $filename;
		    my $writer = $respond->([200, [
						   'Content-Type' => 'text/plain',
						   'Last-Modified' => HTTP::Date::time2str($stat[9]),
						   'X-BBBike-Hacks' => 'NH',
						  ]
					    ]);
		    # Calling ->write is very expensive with Plack. So
		    # buffer manually to reduce the number of ->write
		    # calls.
		    my $buf = '';
		    my $flush = sub {
			$writer->write($buf);
			$buf = '';
		    };
		    while(<$fh>) {
			s{\tNH }{\tN };
			$buf .= $_;
			$flush->() if length $buf >= 4096;
		    }
		    $flush->();
		    $writer->close;
		};
	    }
	} elsif ($filename =~ m{/data/(label|multi_bez_str)$} && !-e $filename) {
	    if ($h->header('If-modified-since')) {
		# data/label & multi_bez_str was removed from MANIFEST some time ago, but some
		# clients maybe still access it
		# Debugging. Remove some day XXX
		warn qq{Faking <$filename> for <$ua>...\n};
		return $req->new_response(304)->finalize;
	    }
	}

	open my $fh, "<:raw", $filename
	    or return $req->new_response(403)->finalize;

	my @stat = stat $filename;
	Plack::Util::set_io_path($fh, Cwd::realpath($filename));

	my $content_type = ($filename =~ m{\.gif$} ? 'image/gif' :
			    $filename =~ m{\.png$} ? 'image/png' :
			    'text/plain');

	return [
		200,
		[
		 'Content-Type'   => $content_type,
		 'Content-Length' => $stat[7],
		 'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
		],
		$fh,
	       ];
    };
}

sub _not_modified {
    my($h, $filename) = @_;
    if (my $if_modified_since = $h->header('If-modified-since')) {
	my($mtime) = (stat($filename))[9];
	if (defined $mtime && str2time($if_modified_since) >= $mtime) {
	    return 1;
	}
    }
    0;
}

1;

__END__
