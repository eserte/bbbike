#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use vars qw($tests);

use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../data",
	 "$FindBin::RealBin/../lib");
use Config;
use Strassen;
use Strassen::Build;
use Strassen::Util;
use StrassenNetz::CNetFile;
use Storable;
eval 'use BBBikeXS';

BEGIN {
    if (!eval q{
	use Test;
	1;
    }) {
	print "# tests only work with installed Test module\n";
	print "1..1\n";
	print "ok 1\n";
	exit;
    }

    $tests = 12;
}

BEGIN { plan tests => $tests }

# this is unix-only
if ($^O eq 'MSWin32') {
    for (1..$tests) {
	skip(1,1);
    }
}

# To not interfere with the "real" net as created by
# StrassenNetz-CNetFile.
$Strassen::Util::cacheprefix = "b_de_strassen_build_test";

my $tmpdir = "$FindBin::RealBin/tmp/strassen-build";
mkdir $tmpdir, 0755 if !-d $tmpdir;

my $prefix = "$tmpdir/strassen";

my $coord2ptr_file = "$tmpdir/strassen_coord2ptr.st";
my $mmap_net_file = "$tmpdir/strassen_net_$Config{byteorder}.mmap";

unlink $coord2ptr_file;
unlink $mmap_net_file;

my $net = StrassenNetz->new(Strassen->new("strassen"));
ok($net->isa("StrassenNetz"), 1);
$net->use_data_format($StrassenNetz::FMT_MMAP);
ok($net->isa("StrassenNetz::CNetFile"), 1);

# Make sure CODE reference gets not interpreted...
ok(!!$net->can("filename_c_net_mmap"));

ok($net->filename_c_net_mmap($prefix), $mmap_net_file);

ok($net->create_mmap_net($prefix), 1);

ok(-f $mmap_net_file, 1);

ok(defined $StrassenNetz::CNetFile::MAGIC, 1);
die if !defined $StrassenNetz::CNetFile::MAGIC;
ok(defined $StrassenNetz::CNetFile::FILE_VERSION, 1);
die if !defined $StrassenNetz::CNetFile::FILE_VERSION;

my $mmap_buf = StrassenNetz::CNetFile::mmap_net_file($net, $mmap_net_file);
ok(!!$mmap_buf, 1);
die if !$mmap_buf;

ok($StrassenNetz::CNetFile::MAGIC, $net->{CNetMagic});
ok($StrassenNetz::CNetFile::FILE_VERSION, $net->{CNetFileVersion});
ok($mmap_buf, $net->{CNetMmap});

{
    if (0) { # no access to internal $coord2ptr possible anymore --- do not test, maybe delete?
	# get last coord from $net->{Net}
	my $last_coord = (keys %{ $net->{Net} })[-1];
	ok($net->reachable($last_coord));
	my $coord2ptr;
	my $last_coord_ptr = $coord2ptr->{$last_coord};
	ok(defined $last_coord_ptr, 1);
	die if !$last_coord_ptr;
	my($x,$y,$no_succ,@succ) = StrassenNetz::CNetFile::get_coord_struct
	    (StrassenNetz::CNetFile::translate_pointer($net, $last_coord_ptr));
	ok(defined $x, 1);
	die if !defined $x;
	ok("$x,$y", $last_coord);
	ok($no_succ, keys %{ $net->{Net}{$last_coord} });

	my $ok = 1;
	while(my($succ,$dist) = each %{ $net->{Net}{$last_coord} }) {
	    my($c_succ, $c_dist) = (shift @succ, shift @succ);
	    die if !defined $c_succ;
	    my($succ_x, $succ_y) = StrassenNetz::CNetFile::get_coord_struct
		(StrassenNetz::CNetFile::translate_pointer($net, $c_succ));
	    if ("$succ_x,$succ_y" ne $succ || $c_dist != $dist) {
		$ok = 0;
		last;
	    }
	}
	ok($ok);
    }
}

__END__
