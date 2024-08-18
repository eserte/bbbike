#!/usr/bin/perl
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;

use File::Temp 'tempdir';
use Test::More 'no_plan';

use BBBikeTest qw(eq_or_diff);

my $org2bbd = "$FindBin::RealBin/../miscsrc/org2bbd";

my $tmpdir = tempdir("org2bbd.t-XXXXXXXX", TMPDIR => 1, CLEANUP => 1);

SKIP: {
    skip "Does not work on Windows", 1
	if $^O eq 'MSWin32';
    ok -x $org2bbd, "$org2bbd is executable";
}

SKIP: {
    skip "Need IPC::Run for further testing", 11
	if !eval { require IPC::Run; 1};

    my $expected_bbd = <<"EOF";
#: encoding: utf-8
#: map: polar
#: 
# Converted from __FILE__ at __TIME__
# 
OpenStreetMap\tX 13.45051,52.50109
My Location\tX 13.45051,52.50109
My Location\tX -43.18420,-22.97291
EOF

    {
	open my $ofh, '>:encoding(utf-8)', "$tmpdir/test.org" or die $!;
	print $ofh <<EOF;
Ignored location without headline: [[geo:52.50109,13.45051?z=19]]
* TODO My Location
Here is my location: [[geo:52.50109,13.45051?z=19][OpenStreetMap]]
[[geo:52.50109,13.45051]]
[[geo:-22.97291,-43.18420?z=17]]
* TODO Without Location
* DONE Location but already resolved
Here is my location: [[geo:52.50109,13.45051?z=19][Wrong]]
EOF
	close $ofh or die $!;

	ok IPC::Run::run([$^X, $org2bbd, "$tmpdir/test.org"], '>', \my $bbd_out, '2>', \my $stderr), 'org2bbd with single file runs ok';
	unlike $stderr, qr{No locations found in}, 'no unexpected stderr';
	like $bbd_out, qr{Converted from.*\Qtest.org}, 'found source file in comment';
	$bbd_out =~ s{Converted from .* at .*}{Converted from __FILE__ at __TIME__};
	eq_or_diff $bbd_out, $expected_bbd, 'bbd as expected';
    }

    {
	open my $ofh1, '>:encoding(utf-8)', "$tmpdir/test1.org" or die $!;
	print $ofh1 <<EOF;
* TODO My Location
Here is my location: [[geo:52.50109,13.45051?z=19][OpenStreetMap]]
[[geo:52.50109,13.45051]]
EOF
	close $ofh1 or die $!;

	open my $ofh2, '>:encoding(utf-8)', "$tmpdir/test2.org" or die $!;
	print $ofh2 <<EOF;
* TODO My Location
[[geo:-22.97291,-43.18420?z=17]]
EOF
	close $ofh2 or die $!;

	ok IPC::Run::run([$^X, $org2bbd, "$tmpdir/test1.org", "$tmpdir/test2.org"], '>', \my $bbd_out, '2>', \my $stderr), 'org2bbd with multiple files runs ok';
	unlike $stderr, qr{No locations found in}, 'no unexpected stderr';
	like $bbd_out, qr{Converted from.*test1.org.*test2.org}, 'found noth source files in comment';
	$bbd_out =~ s{Converted from .* at .*}{Converted from __FILE__ at __TIME__};
	eq_or_diff $bbd_out, $expected_bbd, 'bbd as expected';
    }

    {
	open my $ofh, '>:encoding(utf-8)', "$tmpdir/test-no-loc.org" or die $!;
	print $ofh <<EOF;
Ignored location without headline: [[geo:52.50109,13.45051?z=19]]
* DONE Location but already resolved
Here is my location: [[geo:52.50109,13.45051?z=19][Wrong]]
EOF
	close $ofh or die $!;

	ok !IPC::Run::run([$^X, $org2bbd, "$tmpdir/test-no-loc.org"], '>', \my $bbd_out, '2>', \my $stderr), 'org2bbd expected to fail';
	like $stderr, qr{No locations found in}, 'expected stderr';
	is $bbd_out, '', 'no bbd output';
    }
}

__END__
