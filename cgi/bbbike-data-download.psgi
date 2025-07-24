package BBBikeDataDownload;

# Alternative to BBBikeDataDownloadCompat.pm and
# BBBikeDataDownloadCompatPlack.pm.
#
# Requires the bbbike/tmp/old-bbbike-data directory to
# be populated --- may be created by running
#     ./doit.pl old_bbbike_data
# in the data directory.
#
# httpd.conf.tpl is using this psgi by default if mod_perl and
# Plack::Handler::Apache2 are available.

use strict;
use warnings;

use Cwd qw(realpath);
use File::Basename qw(dirname);
use File::Glob qw(bsd_glob);
use HTTP::Date qw(time2str str2time);
use Plack::Request ();
use Plack::Util ();

use constant DEBUG => $ENV{BBBIKE_DEBUG};
BEGIN { *debug = DEBUG ? sub ($) { warn "DEBUG: $_[0]\n" } : sub ($) {} }

my $bbbike_rootdir  = dirname(dirname(__FILE__));
debug "bbbike_rootdir=$bbbike_rootdir";

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

my $app = sub {
    my $env = shift;

    my $req = Plack::Request->new($env);
    my $h = $req->headers;
    my $ua = $h->header('User-Agent');
    my $filename = $req->request_uri;

    my $old_data_dir    = "$bbbike_rootdir/tmp/old-bbbike-data";
    my $normal_data_dir = "$bbbike_rootdir/data";

    my $use_data_dir;
    if (my($bbbike_ver) = $ua =~ m{bbbike/([\d.]+)}i) {
	if (-d "$old_data_dir/$bbbike_ver") {
	    $use_data_dir = "$old_data_dir/$bbbike_ver";
	} else {
	    my @available_ver = sort { $a <=> $b } map { s{.*/}{}; $_ } bsd_glob("$old_data_dir/[0-9]*");
	    if (@available_ver) {
		if ($bbbike_ver < $available_ver[0]) {
		    $use_data_dir = "$old_data_dir/$available_ver[0]";
		} else {
		    for my $try_ver (reverse @available_ver) {
			if ($bbbike_ver >= $try_ver) {
			    $use_data_dir = "$old_data_dir/$try_ver";
			    last;
			}
		    }
		}
	    }
	}
    }
    if (!$use_data_dir) {
	$use_data_dir = $normal_data_dir;
    }
    debug "use_data_dir=$use_data_dir for ua=$ua";

    $filename =~ s{.*/data/}{};
    my $path = "$use_data_dir/$filename";

    my $std_new_response = sub {
	my $status = shift;
	my $headers = shift // {};
	$headers->{'X-Tag'} = 'rm.data.download';
	$req->new_response($status, $headers, @_)->finalize;
    };

    if (_not_modified($h, $path)) {
	return $std_new_response->(304);
    }

    if ($filename =~ m{^(label|multi_bez_str)$}) {
	if ($h->header('If-modified-since')) {
	    warn qq{Faking <$filename> for <$ua>...\n};
	    return $std_new_response->(304);
	}
    }
    open my $fh, '<:raw', $path
	or do {
	    my $msg = "File $path cannot be read: $!";
	    warn "$msg (for <$ua>)\n";
	    return $std_new_response->(404);
	};

    my @stat = stat $path;
    Plack::Util::set_io_path($fh, realpath($path));

    my $content_type = (
			$filename =~ m{\.gif$} ? 'image/gif' :
			$filename =~ m{\.png$} ? 'image/png' :
			'text/plain' # XXX maybe be more specific: .modified is text/tab-separated-values, the bbd files application/x-bbbike-data
		       );
    my %extra_headers;
    if ($use_data_dir =~ m{/3\.16$} && $filename =~ m{^(strassen|landstrassen|landstrassen2)$}) {
	$extra_headers{'X-BBBike-Hacks'} = 'NH';
    }

    return $std_new_response->
	(
	 200,
	 {
	  'Content-Type'   => $content_type,
	  'Content-Length' => $stat[7],
	  'Last-Modified'  => HTTP::Date::time2str($stat[9]),
	  %extra_headers,
	 },
	 $fh,
	);
};
