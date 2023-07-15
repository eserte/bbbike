# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";

use Test::More 'no_plan';

use Algorithm::GooglePolylineEncoding;
use Route;
use Route::GPLE;
use Route::GPLEU;

{
    my @coords = ([13.52623,52.51012], [13.22072,52.53550]);
    my $r = Route->new_from_realcoords([@coords]);
    $r->set_coord_system('polar');

    my $gple = Route::GPLE::as_gple($r);
    ok $gple;
    
    my @gple_coords = Algorithm::GooglePolylineEncoding::decode_polyline($gple);
    my @got_coords = map { [$_->{lon}, $_->{lat} ] } @gple_coords;
    is_deeply \@got_coords, \@coords, 'Roundtrip as_gple -> decode_polyline';

    my $gpleu = gple_to_gpleu($gple);
    my $got_gple = gpleu_to_gple($gpleu);
    is $got_gple, $gple, 'Roundtrip gple -> gpleu -> gple';
}

__END__
