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

use BBBikeCGI::Cache;
use CGI qw();
use File::Basename qw(dirname);

plan 'no_plan';

{
    my $bc = eval { BBBikeCGI::Cache->new("$FindBin::RealBin/data") };
    like $@, qr{cacheprefix is missing};
}

{
    my @warnings;
    my $bc = do {
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	BBBikeCGI::Cache->new("$FindBin::RealBin/data", "test_b_de");
    };
    isa_ok $bc, 'BBBikeCGI::Cache';
    like "@warnings", qr{Cannot open .*/\.modified .*, fallback to '0'}, 'Expected warning'; # because test data are lacking the .modified file

    # Not reusing an CGI object!
    my %cgi_args = (output_as => "kml", key => "val");
    my $test_content = "test content\näöü";

    $bc->clean_cache;

    my $cache_entry = $bc->get_entry(CGI->new({ %cgi_args }));
    isa_ok $cache_entry, 'BBBikeCGI::Cache::Entry';

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
    my($expireddir, $clean_res);

    # First set on clean_expired_cache tests: with only_synced
    $expireddir = _create_expired_content($updir);

    $clean_res = $bc->clean_expired_cache(only_synced => 1);
    ok -e $expireddir, "Expired directory was not removed (because of only_synced)";
    is $clean_res->{count_skip_unsynced}, 1;
    is $clean_res->{count_success}, 0;
    is $clean_res->{count_errors}, 0;

    { open my $fh, ">", "$expireddir/.synced" or die $! }
    utime time-86400, time-86400, "$expireddir/.synced";
    $clean_res = $bc->clean_expired_cache(only_synced => 1);
    ok -e $expireddir, "Expired directory was not removed (because of .synced too old)";
    is $clean_res->{count_skip_unsynced}, 1;
    is $clean_res->{count_success}, 0;
    is $clean_res->{count_errors}, 0;

    utime time-2*86400, time-2*86400, "$expireddir/testcontent";
    $clean_res = $bc->clean_expired_cache(only_synced => 1);
    ok !-e $expireddir, "Expired directory was removed (because .synced is newer)";
    is $clean_res->{count_skip_unsynced}, 0;
    is $clean_res->{count_success}, 1;
    is $clean_res->{count_errors}, 0;

    # Second set on clean_expired_cache tests: without only_synced
    $expireddir = _create_expired_content($updir);
    
    $clean_res = $bc->clean_expired_cache;
    ok !-e $expireddir, "Expired directory was removed";
    is $clean_res->{count_skip_unsynced}, 0;
    is $clean_res->{count_success}, 1;
    is $clean_res->{count_errors}, 0;

    ok $cache_entry->exists_content, 'Non-expired content still exists';
}

sub _create_expired_content {
    my $updir = shift;
    my $expireddir = $updir . "/expired";
    if (!-d $expireddir) {
	mkdir $expireddir or die $!;
    }
    open my $ofh, ">", "$expireddir/testcontent"
	or die $!;
    print $ofh "test\n";
    close $ofh
	or die $!;

    $expireddir;
}

__END__
