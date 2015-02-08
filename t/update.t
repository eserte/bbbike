#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);
use File::Temp qw(tempdir);
use Getopt::Long;
use Test::More;

use BBBikeUtil qw(is_in_path bbbike_root);
use BBBikeVar ();

use BBBikeTest qw(check_cgi_testing $htmldir eq_or_diff);

check_cgi_testing;

my $doit;
GetOptions("doit!" => \$doit)
    or die "usage: $0 [-doit]\n";

if (!$doit) {
    plan skip_all => 'Please specify -doit to run this test';
}
if (!is_in_path('rsync')) {
    plan skip_all => 'No rsync available';
}
plan 'no_plan';

use Update;

{
    package MockProgress;
    use vars qw(@calls);
    sub new    { bless {}, shift }
    sub Init   { push @calls, ['Init',   @_] }
    sub Update { push @calls, ['Update', @_] }
    sub Finish { push @calls, ['Finish', @_] }
}

my $rootdir = tempdir("BBBike-Update-Test-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);
{
    my @cmd = ('rsync', '-a', bbbike_root . '/data/', $rootdir . '/data/');
    system @cmd;
    die "Command '@cmd' failed" if $? != 0;
}

my($files, $modified, $md5) = Update::load_modified($rootdir);

ok $modified->{'data/comments_scenic'}, 'expected data file'
    or die "FATAL ERROR: unexpected missing file data/comments_scenic";

my $original_modified = $modified->{'data/comments_scenic'};

# for faking status_message calls
my @status_message_calls;
sub status_message { push @status_message_calls, [@_] }
# for faking Tk progress
$main::progress = MockProgress->new;
# for user-agent name
$main::progname = 'bbbike';
$main::VERSION = $BBBike::VERSION;
$main::os = $^O;

my $run_update_http = sub {
    Update::update_http(-dest => $rootdir,
			-root => $htmldir,
			-files => $files,
			-modified => $modified,
			-md5 => $md5,
		       );
    Update::create_modified(-dest => $rootdir,
			    -files => $files,
			   );
};

######################################################################
# Update, no changes expected
{
    $run_update_http->();

    eq_or_diff \@status_message_calls, [], 'no error expected';
}

######################################################################
# Update, one change expected
{
    @status_message_calls = ();
    $modified->{'data/comments_scenic'} -= 3600;

    $run_update_http->();

    (undef, $modified, undef) = Update::load_modified($rootdir);
    cmp_ok $modified->{'data/comments_scenic'}, '>=', $original_modified, 'file was updated';
}

######################################################################
# Update, error expected
{
    @status_message_calls = ();
    $modified->{'data/comments_scenic'} = $original_modified - 3600;

    chmod 0555, "$rootdir/data"
	or die "Can't chmod data directory: $!";

    my $stderr;
    my $captured;
    if (eval { require Capture::Tiny; 1 }) {
	$stderr = Capture::Tiny::capture_stderr($run_update_http);
	$captured = 1;
    } else {
	$run_update_http->();
    }
					  
    like $status_message_calls[0]->[0], qr{Fehler beim Übertragen der Datei}, 'error expected';
    if ($captured) {
	like $stderr, qr{X-Died: Can't write to.*scenic}, 'stderr message';
    }
}

__END__
