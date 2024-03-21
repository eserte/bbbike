#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib "$FindBin::RealBin/..";

use Data::Dumper;
use File::Temp qw(tempfile);

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

plan tests => 25;

use Geography::Berlin_DE;
use Geography::FromMeta;

{
    my $geo = Geography::Berlin_DE->new;
    isa_ok($geo, "Geography::Berlin_DE");

    is($geo->cityname, "Berlin");
    like($geo->center, qr{^-?\d+,-?\d+$});
    like($geo->center_wgs84, qr{^-?[\d\.]+,-?[\d\.]+$});

    ok(grep { $_ eq 'Spandau' } $geo->supercityparts);
    ok(grep { $_ eq 'Kreuzberg' } $geo->cityparts);
    ok(grep { $_ eq 'Rosenthal' } $geo->subcityparts);
    ok((grep { $_ eq 'Kreuzberg' } $geo->subcityparts), 'Kreuzberg ist ein Ortsteil und ein Altbezirk');

    is($geo->get_supercitypart_for_citypart("Kreuzberg"),
       "Friedrichshain-Kreuzberg");
    is($geo->get_supercitypart_for_any("Gatow"), "Spandau");
    is($geo->get_supercitypart_for_any("Kreuzberg"), "Friedrichshain-Kreuzberg");
    is($geo->get_supercitypart_for_any("Friedrichshain-Kreuzberg"), "Friedrichshain-Kreuzberg");

    my @sp = $geo->get_all_subparts("Pankow");
    is(scalar(@sp), 13)
	or diag "@sp";

    roundtrip_coords($geo, 0, 0);
}

{
    my $meta = { coordsys => 'wgs84',
		 mapname => 'Kleinkleckersdorf',
		 center => [ 7, 50 ],
		 bbox => [ 6.899, 49.864, 7.737, 50.429 ],
		 bbox_wgs84 => [ 6.899, 49.864, 7.737, 50.429 ],
	       };
    my($meta_fh, $meta_file) = tempfile(SUFFIX => '_meta.dd', UNLINK => 1);
    print $meta_fh Data::Dumper->new([$meta],[qw(meta)])->Indent(1)->Useqq(1)->Dump;
    close $meta_fh
	or die "Can't write to $meta_file: $!";

    my $geo = Geography::FromMeta->load_meta($meta_file);
    isa_ok($geo, 'Geography::FromMeta');

    is($geo->cityname, "Kleinkleckersdorf");
    like($geo->center, qr{^-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?$});
    like($geo->center_wgs84, qr{^-?[\d\.]+,-?[\d\.]+$});

    my $bbox = $geo->bbox;
    is scalar(@$bbox), 4, 'for elements in bbox';
    is $bbox->[-1], 50.429;

    my $bbox_wgs84 = $geo->bbox_wgs84;
    is scalar(@$bbox_wgs84), 4, 'for elements in bbox_wgs84';
    is $bbox_wgs84->[-1], 50.429;

    roundtrip_coords($geo, 13.5, 52.5);
}

# tests: 2
sub roundtrip_coords {
    my($geo, $x, $y) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my($sx,$sy) = $geo->coord_to_standard($x,$y);
    is_deeply([$geo->standard_to_coord($sx,$sy)], [$x,$y], "Roundtrip check for " . ref $geo);

    my $sxy = $geo->coord_to_standard_s("$x,$y");
    is($geo->standard_to_coord_s($sxy), "$x,$y", qq{Roundtrip check for } . ref($geo) . qq{, "s" variant});
}

__END__
