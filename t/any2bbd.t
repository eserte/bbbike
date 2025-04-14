#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use File::Temp ();
use Test::More;

BEGIN {
    if (!eval q{ use IPC::Run qw(run); 1 }) {
	plan skip_all => 'IPC::Run not available';
    }
}

plan 'no_plan';

my $any2bbd = "$FindBin::RealBin/../miscsrc/any2bbd";
my @basecmd = ($^X, $any2bbd);

{
ok !run [@basecmd], '2>', \my $err;
like $err , qr{^Missing option -o for output file, use -o - for stdout at };
}

{
my $tmp = File::Temp->new(SUFFIX => '_any2bbd.trk');
$tmp->print(<<'EOF');
% Written by /home/e/eserte/src/bbbike/miscsrc/gpx2gpsman [GPS::GpsmanData] 2015-08-02 22:16:45 +0200

!Format: DDD 2 WGS 84
!Creation: no

!T:	2015-08-01 09:43:12 Tag	srt:device=eTrex 30	colour=#000000
	01-Aug-2015 09:43:12	N52.5078067929	E13.4600815549	87.14
	01-Aug-2015 09:43:23	N52.5080102216	E13.4595810715	86.66
EOF
$tmp->close;

ok run [@basecmd, $tmp, '-o', '-'], '>', \my $out, '2>', \my $err;
is $out, <<'EOF';
2015-08-01 09:43:12 Tag	#000080 14219,11413 14185,11435
EOF
like $err, qr{.*_any2bbd\.trk\.\.\. OK \(Strassen::Gpsman\)};
}

{
    my $tmp = File::Temp->new(SUFFIX => '_any2bbd.geojson');
    $tmp->print(<<'EOF');
{
    "type": "FeatureCollection",
    "name": "baustellen",
    "features": [
        {
            "type": "Feature",
            "properties": {
                "street": "A100 (Stadtring)"
            },
            "geometry": {
                "type": "GeometryCollection",
                "geometries": [
                    {
                        "type": "Point",
                        "coordinates": [
                            13.341823026264,
                            52.47875402447307
                        ]
                    }
                ]
            }
        }
    ]
}
EOF
    $tmp->close;

    {
	ok !run [@basecmd, '-geojson-name', 'wrongpath', $tmp, '-o', '-'], '>', \my $out, '2>', \my $err;
	like $err, qr{\Q-geojson-name has to be a path (e.g. .properties.street)}, 'expected error message';
    }

    {
	ok run [@basecmd, '-geojson-name', '.not.existing', $tmp, '-o', '-'], '>', \my $out, '2>', \my $err;
	like $err, qr{\Qgeojson-name: path not existing cannot be resolved, feature <undef> is not a HASH}, 'expected warning message';
	is $out, <<"EOF", 'expected geojson -> bbd conversion result (-geojson-name not used)';
#: map: polar
#: encoding: utf-8
#:
\tX 13.341823026264,52.4787540244731
EOF
    }

    ok run [@basecmd, '-geojson-name', '.properties.street', $tmp, '-o', '-'], '>', \my $out, '2>', \my $err;
    is $out, <<"EOF", 'expected geojson -> bbd conversion result';
#: map: polar
#: encoding: utf-8
#:
A100 (Stadtring)\tX 13.341823026264,52.4787540244731
EOF
    like $err, qr{.*_any2bbd\.geojson\.\.\. OK \(Strassen::GeoJSON\)}, 'expected diagnostics';
}

__END__
