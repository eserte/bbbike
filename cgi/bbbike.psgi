# -*- cperl -*-

use strict;
use warnings;
use FindBin;

use Plack::Builder;
use Plack::Middleware::Rewrite;
use Plack::Middleware::Static;
use Plack::App::WrapCGI;

use Config qw(%Config);
use Cwd 'realpath';
use File::Basename 'dirname';
use File::Spec::Functions 'catfile', 'catpath';

my $root;
BEGIN {
    # In this environments (e.g. within mod_perl) $FindBin::RealBin is
    # not useable; in these situations set the BBBIKE_ROOTDIR env var.
    $root = $ENV{BBBIKE_ROOTDIR} || dirname(realpath($FindBin::RealBin));
}

use lib $root;
use BBBikeDataDownloadCompatPlack ();

use constant USE_FORK_NOEXEC => $ENV{USE_FORK_NOEXEC};
use constant USE_NEW_DATA_DOWNLOAD => $ENV{BBBIKE_USE_NEW_DATA_DOWNLOAD};
use constant USE_CGI_BIN_LAYOUT => ($ENV{BBBIKE_URL_LAYOUT}||'') eq 'cgi-bin';
BEGIN {
    if (USE_FORK_NOEXEC) {
	warn "Preloading...\n";
	eval q<
	# Preloading
	use FindBin;
	use lib ("$FindBin::RealBin/../lib", "$FindBin::RealBin/..");
	use Apache::Session::Counted ();
	use Array::Heap ();
	use BBBikeApacheSessionCounted ();
	use BBBikeCGI::Util ();
	use BBBikeCalc ();
	use BBBikeDraw ();
	use BBBikeDraw::GD ();
	use BBBikeDraw::GDHeavy ();
	use BBBikeDraw::MapServer ();
	use BBBikeDraw::PDF ();
	use BBBikeDraw::PDFCairo ();
	use BBBikeDraw::PDFUtil ();
	use BBBikeDraw::SVG ();
	use BBBikeRouting ();
	use BBBikeUtil ();
	use BBBikeVar ();
	use BBBikeXS ();
	use BBBikeYAML ();
	use BikePower::HTML ();
	use BrowserInfo ();
	use CDB_File ();
	use CGI ();
	use CGI::Carp ();
	use CGI::Cookie ();
	use Digest::MD5 ();
	use File::Basename ();
	use File::Copy ();
	use Geography::Berlin_DE ();
	use HTML::Parser ();
	use MLDBM ();
	use MLDBM::Serializer::Storable ();
	use Met::Wind ();
	use PLZ ();
	use PLZ::Multi ();
	use PLZ::Result ();
	use Route ();
	use Strassen ();
	use Strassen::CoreHeavy ();
	use Strassen::Dataset ();
	use Strassen::GPX ();
	use Strassen::Heavy ();
	use Strassen::KML ();
	use Strassen::StrassenNetz ();
	use Strassen::StrassenNetzHeavy ();
	use String::Approx ();
	use Sys::Hostname ();
	use Tie::IxHash ();
	use VirtArray ();
	use XML::LibXML ();
	use XML::Simple ();
        >;
	die $@ if $@;
	warn "Preloading done...\n";
    }
}

my $cgidir = catpath $root, 'cgi';

# Force the current perl's path as first entry in PATH,
# so the CGI is executed with the same perl.
$ENV{PATH} = "$Config{bin}:$ENV{PATH}";

my $cgiurl    = USE_CGI_BIN_LAYOUT ? '/cgi-bin' : '/bbbike/cgi';
my $staticurl = USE_CGI_BIN_LAYOUT ? '/BBBike'  : '/bbbike';

builder {

    enable 'Head';
    enable "ConditionalGET";

    enable 'Rewrite', rules => sub {
	if (m{^/(?:\?.*)?$}) {
	    no warnings 'uninitialized'; # $1 may be undef
	    $_ = "$cgiurl/bbbike.cgi$1";
	    return 301;
	}
    };

    enable "Plack::Middleware::Static",
	path => sub { s!^$staticurl/(html/opensearch/)!$1! }, root => $root, encoding => 'utf-8';

    enable "Plack::Middleware::Static",
	path => sub { s!^$staticurl/(html|images/)!$1! }, root => $root, encoding => 'iso-8859-1';

    if (eval { require Plack::Middleware::Deflater; 1}) {
	enable "Deflater",
	    content_type => [qw(
				   application/vnd.google-earth.kml+xml application/gpx+xml image/svg+xml application/xml
				   application/json application/geo+json
				   text/html text/plain text/xml
				   text/css
				   application/x-javascript application/javascript application/ecmascript
				   DEFLATE application/rss+xml
			      )]
	    ;
    } else {
	warn "Plack::Middleware::Deflater could not be loader: compression not enabled\n";
    }

    my $app;
    for my $cgidef (
		    # first is the main file, rest is aliases via symlinks
		    ['bbbike.cgi', 'bbbike2.cgi'],
		    ['bbbike.en.cgi', 'bbbike2.en.cgi'],
		    ['bbbikegooglemap.cgi', 'bbbikegooglemap2.cgi'],
		    ['bbbikeleaflet.cgi', 'bbbikeleaflet.en.cgi'],
		    ['bbbike-data.cgi'],
		    ['bbbike-snapshot.cgi'],
		    ['bbbike-test.cgi', 'bbbike-test.en.cgi', 'bbbike2-test.cgi'],
		    ['bbbike-osm.cgi'],
		    ['mapserver_address.cgi'],
		    ['mapserver_comment.cgi'],
		    ['mapserver_setcoord.cgi'],
		    ['qrcode.cgi'],
		    ['upload-track.cgi'],
		    ['wapbbbike.cgi'],
		   ) {
	for my $cgi (@$cgidef) {
	    my $fs_file = catfile($root, 'cgi', $cgi);
	    $app = mount "$cgiurl/$cgi" => Plack::App::WrapCGI->new(
                script  => $fs_file,
	        execute => USE_FORK_NOEXEC ? 'noexec' : 1,
	    )->to_app;
	}
    }

    if (USE_NEW_DATA_DOWNLOAD) {
	my $new_data_download_app = do "$root/cgi/bbbike-data-download.psgi";
	$app = mount "$staticurl/data" => $new_data_download_app;
    } else {
	$app = mount "$staticurl/data" => BBBikeDataDownloadCompatPlack::get_app("$root/data");
    }

    $app = mount "$staticurl" => Plack::App::File->new(root => $root, encoding => 'iso-8859-1')->to_app;

    {
	my $mapserv_cgibin;
	if ($^O eq 'freebsd') { # needs graphics/mapserver to be installed
	    $mapserv_cgibin = '/usr/local/www/cgi-bin/mapserv';
	} elsif ($^O eq 'linux') { # on debian, needs cgi-mapserver to be installed
	    $mapserv_cgibin = '/usr/lib/cgi-bin/mapserv';
	}
	if ($mapserv_cgibin) {
	    $app = mount '/cgi-bin/mapserv' => Plack::App::WrapCGI->new(
		script => $mapserv_cgibin,
		execute => USE_FORK_NOEXEC ? 'noexec' : 1,
	    )->to_app;
	} else {
	    warn "WARN: Don't know how to run mapserver cgi";
	}
    }

    $app;

};

__END__

=head1 NAME

bbbike.psgi - Plack adapter for BBBike

=head1 SYNOPSIS

    plackup [options] bbbike.psgi

=head1 DESCRIPTION

If running under C<bbbike.psgi> with defaults, then BBBike is
available at L<http://localhost:5000/>.

=head1 PREREQUISITES

Plack 0.9981 (at least 0.9941 does not work)

CGI::Emulate::PSGI

CGI::Compile

=head1 SEE ALSO

L<plackup>.

=head1 AUTHOR

Slaven Rezic

=cut
