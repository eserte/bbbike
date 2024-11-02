#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Test::More;

plan skip_all => 'no IPC::Run' if !eval { require IPC::Run; 1 };

use Getopt::Long;
use File::Temp qw(tempdir);

use BBBikeUtil qw(bbbike_root);
use Geography::Berlin_DE;
use Strassen::Core;

GetOptions(
    "doit" => \my $doit,
    "keep" => \my $keep,
)
    or die "usage: $0 [--doit] [--keep]\n";

plan skip_all => '--doit option not set' if !$doit;
plan skip_all => 'no ~/.mapillary with token available' if !-r "$ENV{HOME}/.mapillary";
plan 'no_plan';

$File::Temp::KEEP_ALL = 1 if $keep;

my $tempdir = tempdir("mapillary_v4_fetch_t_XXXXXXXX", CLEANUP => 1, TMPDIR => 1);

my $test_date = "2024-09-30"; # a date which is known to have data in Berlin
my $bbox = join ',', @{ Geography::Berlin_DE->new->bbox_wgs84 };

my $script_path = bbbike_root . '/miscsrc/mapillary-v4-fetch';

{
    my $output_file = "$tempdir/$test_date.bbd";
    my @cmd = ($^X, $script_path, '--statistics', '--max-try=20', '--used-limit=999', '--allow-override', '-o', $output_file,
	       "--start-date=$test_date", "--end-date=$test_date", "--bbox=$bbox");
    my $success = IPC::Run::run(\@cmd, '2>', \my $stderr);
    ok $success, "$script_path successful"
	or diag "@cmd failed";

    like $stderr, qr{successful: (\d+)}, 'found statistics';

    ok -s $output_file, "non-empty output file";
    my $s = Strassen->new_stream($output_file);
    $s->read_stream(sub {
	my($r, $dir) = @_;
	my $name = $r->[Strassen::NAME];
	ok $name =~ m{start_captured_at=$test_date} || $name =~ m{end_captured_at=$test_date}, 'found expected start/end_captured_date' # assume that there are no sequences exceeding 24h
	    or diag $name;
	like $name, qr{creator=\S}, 'found a creator'
	    or diag $name;
	like $name, qr{make=\S}, 'found a make'
	    or diag $name;
	cmp_ok scalar(@{ $r->[Strassen::COORDS] }), '>', 0, 'found coordinates';
    });
}

__END__
