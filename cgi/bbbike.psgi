# -*- cperl -*-

use strict;
use warnings;
use FindBin;

use Plack::Builder;
use Plack::Middleware::Rewrite;
use Plack::Middleware::Static;
use Plack::App::WrapCGI;

use Cwd 'cwd', 'realpath';
use File::Basename 'dirname';
use File::Spec::Functions 'catfile', 'catpath';

my $root = dirname(realpath($FindBin::RealBin));
my $cgidir = catpath $root, 'cgi';

builder {

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
	        execute => 1,
	    )->to_app;
	}
    }

    mount "/bbbike" => Plack::App::File->new(root => $root, encoding => 'iso-8859-1');

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
		execute => 1,
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
