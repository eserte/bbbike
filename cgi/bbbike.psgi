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

builder {

    enable 'Head';
    enable "ConditionalGET";

    enable 'Rewrite', rules => sub {
	if (m{^/(?:\?.*)?$}) {
	    no warnings 'uninitialized'; # $1 may be undef
	    $_ = "/bbbike/cgi/bbbike.cgi$1";
	    return 301;
	}
    };

    enable "Plack::Middleware::Static",
	path => sub { s!^/bbbike/(html/opensearch/)!$1! }, root => $root, encoding => 'utf-8';

    enable "Plack::Middleware::Static",
	path => sub { s!^/bbbike/(html|images/)!$1! }, root => $root, encoding => 'iso-8859-1';

    my $app;
    for my $cgidef (
		    # first is the main file, rest is aliases via symlinks
		    ['bbbike.cgi', 'bbbike2.cgi'],
		    ['bbbike.en.cgi', 'bbbike2.en.cgi'],
		    ['bbbikegooglemap.cgi', 'bbbikegooglemap2.cgi'],
		    ['bbbikeleaflet.cgi', 'bbbikeleaflet.en.cgi'],
		    ['bbbike-data.cgi'],
		    ['bbbike-snapshot.cgi'],
		    ['bbbike-test.cgi', 'bbbike-test.en.cgi'],
		    ['bbbike-osm.cgi'],
		    ['mapserver_address.cgi'],
		    ['mapserver_comment.cgi'],
		    ['mapserver_setcoord.cgi'],
		    ['upload-track.cgi'],
		    ['wapbbbike.cgi'],
		   ) {
	for my $cgi (@$cgidef) {
	    my $fs_file = catfile($root, 'cgi', $cgi);
	    $app = mount "/bbbike/cgi/$cgi" => Plack::App::WrapCGI->new(
                script  => $fs_file,
	        execute => USE_FORK_NOEXEC ? 'noexec' : 1,
	    )->to_app;
	}
    }
    
    $app = mount "/bbbike/data" => BBBikeDataDownloadCompatPlack::get_app("$root/data");

    $app = mount "/bbbike" => Plack::App::File->new(root => $root, encoding => 'iso-8859-1')->to_app;

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
