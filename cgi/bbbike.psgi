# -*- cperl -*-

use strict;
use warnings;
use FindBin;

use Plack::Builder;
use Plack::Middleware::Static;
use Plack::App::WrapCGI;

use Cwd 'cwd', 'realpath';
use File::Basename 'dirname';
use File::Spec::Functions 'catfile', 'catpath';

my $root = dirname(realpath($FindBin::RealBin));
my $cgidir = catpath $root, 'cgi';

builder {

    mount '/' => sub {
	my $env = shift;
	require Plack::Response;
	my $res = Plack::Response->new;
	$res->redirect("http://$env->{HTTP_HOST}/bbbike/cgi/bbbike.cgi");
	$res->finalize;
    };

    enable "Plack::Middleware::Static",
	path => sub { s!^/BBBike/!! }, root => $root, encoding => 'iso-8859-1';

    enable "Plack::Middleware::Static",
	path => sub { s!^/bbbike/(html/opensearch/)!$1! }, root => $root, encoding => 'utf-8';

    enable "Plack::Middleware::Static",
	path => sub { s!^/bbbike/(html|images/)!$1! }, root => $root, encoding => 'iso-8859-1';

    my $app;
    for my $cgidef (
		    # first is the physical file and the primary URL basename, rest is aliases
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
	my $fs_file = $cgidef->[0];
	$fs_file = catfile($root, 'cgi', $fs_file);
	for my $cgi (@$cgidef) {
	    $app = mount "/bbbike/cgi/$cgi" => Plack::App::WrapCGI->new(
                script  => $fs_file,
	        execute => 1,
	    )->to_app;
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
