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
	 "$FindBin::RealBin/../miscsrc",
	);
use File::Temp 'tempdir';
use Getopt::Long;
use Test::More 'no_plan';

use ReverseGeocoding;

my $geocoder = 'bbbike';
GetOptions("geocoder=s" => \$geocoder)
    or die <<EOF;
usage: $0 [-geocoder bbbike|osm]

Or alternatively with prove:
       prove t/reverse-geocoding.t :: -geocoder osm
EOF

my $rg = ReverseGeocoding->new($geocoder);
isa_ok $rg, 'ReverseGeocoding';

{
    my $res = $rg->find_closest("13.5,52.5", "road");
    like $res, qr{^Sewanstr(\.|aße)$}, 'find road';
}

{
    my $res = $rg->find_closest("-13.5,-52.5", "road");
    is $res, undef, 'do not find road';
}

{
    my $res = $rg->find_closest("13.236871,52.754177", "area");
    is $res, 'Oranienburg', 'find area';
}

{
    my $res = $rg->find_closest("-13.236871,-52.754177", "area");
    is $res, undef, 'do not find area';
}

SKIP: {
    skip "No Captury::Tiny available" if !eval { require Capture::Tiny; 1 };

    my($stdout, $stderr, $exit) = Capture::Tiny::capture(sub { $rg->find_closest("13.5,52.5", "road", debug => 1) });
    if ($geocoder eq 'bbbike') {
	like $stderr, qr{VAR.*StreetObj.*Sewanstr}sm, 'debug option generates debugging output (bbbike variant)';
    } elsif ($geocoder eq 'osm') {
	like $stderr, qr{VAR.*address.*Sewanstr}sm, 'debug option generates debugging output (osm variant)';
    } else {
	die "SHOULD NOT HAPPEN: geocoer '$geocoder' not expected here";
    }
}

{
    no warnings 'once';
    my $datadir = tempdir('reverse-geocoding-t-XXXXXXXX', CLEANUP => 1, TMPDIR => 1);
    local @Strassen::datadirs = ($datadir);

    { open my $fh, '>', "$datadir/orte" or die $! };
    eval { ReverseGeocoding->new->find_closest('13.5,52.5', 'area') };
    like $@, qr{ERROR: file 'orte2' cannot be loaded}, 'error if mandatory orte2 file is missing';

    { open my $fh, '>', "$datadir/orte2" or die $! };
    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	ReverseGeocoding->new->find_closest('13.5,52.5', 'area');
	like "@warnings", qr{INFO: file 'berlin_ortsteile' is optional and not available, skipping}, 'warning if optional file is missing';
    }

    { open my $fh, '>', "$datadir/berlin_ortsteile" or die $! };
    {
	my @warnings;
	local $SIG{__WARN__} = sub { push @warnings, @_ };
	ReverseGeocoding->new->find_closest('13.5,52.5', 'area');
	is_deeply \@warnings, [], 'no warnings if all orte-style files are there';
    }    
}

__END__
