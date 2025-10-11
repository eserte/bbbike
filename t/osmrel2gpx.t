#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin, "$FindBin::RealBin/..";
use utf8;

use Getopt::Long;
use Test::More;

use BBBikeUtil qw(bbbike_root);
use BBBikeTest qw(eq_or_diff gpxlint_string);
use Strassen::Util ();

BEGIN {
    my $builder = Test::More->builder;
    binmode $builder->output,         ":encoding(utf8)";
    binmode $builder->failure_output, ":encoding(utf8)";
    binmode $builder->todo_output,    ":encoding(utf8)";
}

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

my $doit;
my $keep;
GetOptions(
    "doit" => \$doit,
    "keep" => \$keep,
)
    or die "usage: $0 [--doit] [--keep]\n";

if (!$doit) {
    plan skip_all => "Skip expensive tests (may overwhelm overpass-api server, enable with --doit";
}
plan 'no_plan';

my $osmrel2gpx = bbbike_root . '/miscsrc/osmrel2gpx';

for my $test_case (
    [   9030, undef, 'Berliner Mauerweg', '13.3114700,52.6275917', undef], # XXX incomplete track, relation member problems around Oberbaumbrücke
    [ 335268, undef, 'Spreeradweg [Beeskow-Berlin]', '14.2486957,52.1753471', undef], # XXX incomplete track, relation member problems around Oberbaumbrücke
    [  27727, undef, 'Berlin-Usedom', '13.400738,52.516311', '13.772893,54.135781'],
    [2262839, undef, 'Oder-Neiße-Radweg [MV]', '14.1912112,53.9332517', '14.2619276,53.2766402'],
    [2262515, undef, 'Oder-Neiße-Radweg [BRB]', '14.2619276,53.2766402', '14.7317531,51.5873829'],
    [1069748, undef, 'Uckermärkischer Radrundweg', '13.9994783,53.0150285', '13.9994783,53.0150285'], # start/end in Angermünde
    [4784783, undef, 'Elberadweg [Tangermünde-Magdeburg]', '11.973961,52.542651', '11.642163,52.129183'],
) {
    my($rel_id, $extra_args, $name, $exp_start_coord, $exp_end_coord) = @$test_case;
    my $cache_file = "/tmp/osmrel2gpx_response_${rel_id}.xml";
    my @cache_args = -r $cache_file ? ('--in-xml', $cache_file) : ('--cache');
    my @cmd = ($^X, $osmrel2gpx, @cache_args, '--id', $rel_id, $extra_args ? @$extra_args: ());
    my $success = run \@cmd, '>', \my $out, '2>', \my $err;
    ok $success, "Running '@cmd' for $name was successful"
	or diag "Stderr: $err";
    gpxlint_string $out, "Result for $name is valid gpx";
    if ($keep) {
	open my $ofh, ">", "/tmp/osmrel2gpx_${rel_id}.gpx" or die $!;
	print $ofh $out;
	close $ofh or die $!;
    }
    my($first_lat, $first_lon) = $out =~   m{<trkpt lat="([^"]+)" lon="([^"]+)"};
    my($last_lat,  $last_lon)  = $out =~ m{.*<trkpt lat="([^"]+)" lon="([^"]+)"}s;
    if (defined $exp_start_coord) {
	my $start_dist = Strassen::Util::strecke_s_polar($exp_start_coord, "$first_lon,$first_lat");
	cmp_ok $start_dist, "<=", 1000, "expected start coord within 1000m from $exp_start_coord, got $first_lon,$first_lat (dist is $start_dist)";
    }
    if (defined $exp_end_coord) {
	my $end_dist =  Strassen::Util::strecke_s_polar($exp_end_coord,   "$last_lon,$last_lat");
	cmp_ok $end_dist,   "<=", 1000, "expected end coord within 1000m from $exp_end_coord, got $last_lon,$last_lat (dist is $end_dist)";
    }
}

__END__
