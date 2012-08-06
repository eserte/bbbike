#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeCGICache;
use CGI qw();
use File::Basename qw(dirname);

plan 'no_plan';

{
    my $bc = eval { BBBikeCGICache->new("$FindBin::RealBin/data") };
    like $@, qr{cacheprefix is missing};
}

{
    my @warnings;
    my $bc = do {
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	BBBikeCGICache->new("$FindBin::RealBin/data", "test_b_de");
    };
    isa_ok $bc, 'BBBikeCGICache';
    like "@warnings", qr{Cannot open .*/\.modified .*, fallback to '0'}, 'Expected warning'; # because test data are lacking the .modified file

    # Not reusing an CGI object!
    my %cgi_args = (output_as => "kml", key => "val");
    my $test_content = "test content\näöü";

    $bc->clean_cache;
    ok !$bc->exists_content(CGI->new({ %cgi_args })), 'Test content does not exist already';
    ok $bc->put_content(CGI->new({ %cgi_args }), $test_content, {key => "val"}), 'Putting test content';
    my($content, $meta) = $bc->get_content(CGI->new({ %cgi_args }));
    is $content, $test_content, 'Got content';
    is_deeply $meta, {key => "val"}, 'Got meta';

    my $updir = dirname $bc->rootdir;
    my $expireddir = $updir . "/expired";
    if (!-d $expireddir) {
	mkdir $expireddir or die $!;
    }
    open my $ofh, ">", "$expireddir/testcontent"
	or die $!;
    print $ofh "test\n";
    close $ofh
	or die $!;

    $bc->clean_expired_cache;
    ok !-e $expireddir, "Expired directory was removed";

    ok $bc->exists_content(CGI->new({ %cgi_args })), 'Non-expired content still exists';
}

__END__
