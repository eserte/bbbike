#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib (
	 "$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	 $FindBin::RealBin,
	);

use Cwd qw(realpath);
use File::Temp ();
use Test::More 'no_plan';

use BBBikeTest qw(using_bbbike_test_data xmllint_string xpath_checks);

my $bbd2osm = realpath("$FindBin::RealBin/../miscsrc/bbd2osm");
ok -x $bbd2osm;

using_bbbike_test_data;

for my $def (
    ['optimize for mapnik', ['--optimize-for=mapnik-bbbike', "$FindBin::RealBin/data-test"], 0],
    ['optimize for garmin', ['-experiment=mount', '-optimize-for=garmin', "$FindBin::RealBin/data-test"], 0],
    ($ENV{BBBIKE_LONG_TESTS} ? ['full bbbike data test (mapnik-bbbike)', ['--optimize-for=mapnik-bbbike'], 1] : ()),
) {
    my($testlabel, $opts, $skip_data_checks) = @$def;
    my @opts = @$opts;

    my $tmp = File::Temp->new(SUFFIX => '.osm', UNLINK => 1);
    my @cmd = ($^X, $bbd2osm, @opts);
    open my $fh, '-|', @cmd or die $!;
    local $/ = \8192;
    while(<$fh>) {
	print $tmp $_;
    }
    close $fh
	or die "Error while running @cmd: $!";
    close $tmp
	or die "Error while writing to $tmp: $!";
    ok -s "$tmp", "$testlabel: non-zero size of generated .osm file";
    my $osm_string = do { open my $fh, "$tmp" or die $!; local $/; <$fh> };
    xmllint_string($osm_string, "$testlabel: XML check");
    if (!$skip_data_checks) {
	xpath_checks $osm_string, 10, sub {
	    my $doc = shift;
	    like $doc->findvalue('/osm/@version'), qr{^\d+\.\d+$}, 'osm version looks like a version';
	    ok $doc->findnodes('/osm/bound/@box'), 'found a bound box';
	    my($way_node) = $doc->findnodes('/osm/way/tag[@k="name" and @v="Dudenstr."]/..');
	    ok $way_node, 'found Dudenstr in test data';
	    is $way_node->findvalue('./@visible'), 'true';
	    is $way_node->findvalue('./tag[@k="highway"]/@v'), 'secondary';
	    is $way_node->findvalue('./tag[@k="is_in:county"]/@v'), 'Berlin';
	    is $way_node->findvalue('./tag[@k="addr:city"]/@v'), 'Kreuzberg';
	    is $way_node->findvalue('./tag[@k="addr:country"]/@v'), 'DE';
	    ok $doc->findnodes('/osm/way/tag[@k="highway" and @v="cycleway"]'), 'found a cycleway in test data';
	    ok $doc->findnodes('/osm/way/tag[@k="FIXME" and @v="Fragezeichen1"]'), 'found a fragezeichen entry in test data';
	};
    }
}


__END__
