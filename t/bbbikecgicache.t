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

    my $cache_entry = $bc->get_entry(CGI->new({ %cgi_args }));
    isa_ok $cache_entry, 'BBBikeCGICache::Entry';

    ok !$cache_entry->exists_content, 'Test content does not exist already';
    ok $cache_entry->put_content($test_content, {key => "val"}), 'Putting test content';
    ok $cache_entry->exists_content, 'Now test content exists';
    my $meta = $cache_entry->get_meta;
    is_deeply $meta, {key => "val"}, 'Got meta';
    my $content;
    open my $content_ofh, ">", \$content or die $!;
    $cache_entry->stream_content($content_ofh);
    is $content, $test_content, 'Got content';

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

    ok $cache_entry->exists_content, 'Non-expired content still exists';
}

__END__
