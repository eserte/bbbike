#!/usr/bin/perl -w
# -*- mode:cperl; coding:iso-8859-1 -*-

use strict;
use FindBin;
use lib (
    "$FindBin::RealBin/..",
    "$FindBin::RealBin/../lib",
    "$FindBin::RealBin/../miscsrc",
    $FindBin::RealBin,
);

use File::Temp qw(tempfile);
use Test::More tests => 8;

my $bbd2osm = "$FindBin::RealBin/../miscsrc/bbd2osm";

sub get_node_xml {
    my($xml, $node_name) = @_;
    if ($xml =~ m{(<node [^>]*>(?:(?!</node>).)*?<tag k="name" v="\Q$node_name\E"\s*/>(?:(?!</node>).)*?</node>)}s) {
        return $1;
    }
    return '';
}

{
    my($fh, $fname) = tempfile(UNLINK => 1, SUFFIX => '.bbd');
    print $fh <<'EOF';
#: encoding: utf-8
#:
#: osm.abandoned: yes
Station Abandoned	R0 13.0,52.0
Station Disused	R0 13.1,52.1
EOF
    close $fh;

    my $out = `$^X -I"$FindBin::RealBin/.." -I"$FindBin::RealBin/../lib" -I"$FindBin::RealBin/../miscsrc" $bbd2osm -single $fname -type railway_stations`;

    my $node_abandoned = get_node_xml($out, 'Station Abandoned');
    like $node_abandoned, qr{<tag k="abandoned" v="yes"\s*/>},
	'Station with R0 and osm.abandoned: yes directive gets abandoned=yes';
    unlike $node_abandoned, qr{<tag k="disused" v="yes"\s*/>},
	'Station with R0 and osm.abandoned: yes directive does not get disused=yes';

    my $node_disused = get_node_xml($out, 'Station Disused');
    like $node_disused, qr{<tag k="disused" v="yes"\s*/>},
	'Station with R0 without osm.abandoned directive gets disused=yes';
    unlike $node_disused, qr{<tag k="abandoned" v="yes"\s*/>},
	'Station with R0 without osm.abandoned directive does not get abandoned=yes';
}

{
    my($fh, $fname) = tempfile(UNLINK => 1, SUFFIX => '.bbd');
    print $fh <<'EOF';
#: encoding: utf-8
#:
#: osm.abandoned: yes vvv
Station Abandoned Block	R0 13.2,52.2
#: osm.abandoned ^^^
Station Disused Block	R0 13.3,52.3
EOF
    close $fh;

    my $out = `$^X -I"$FindBin::RealBin/.." -I"$FindBin::RealBin/../lib" -I"$FindBin::RealBin/../miscsrc" $bbd2osm -single $fname -type railway_stations`;

    my $node_abandoned = get_node_xml($out, 'Station Abandoned Block');
    like $node_abandoned, qr{<tag k="abandoned" v="yes"\s*/>},
	'Block directive osm.abandoned: yes gives abandoned=yes';
    unlike $node_abandoned, qr{<tag k="disused" v="yes"\s*/>},
	'Block directive osm.abandoned: yes does not give disused=yes';

    my $node_disused = get_node_xml($out, 'Station Disused Block');
    like $node_disused, qr{<tag k="disused" v="yes"\s*/>},
	'Station outside block directive gets disused=yes';
    unlike $node_disused, qr{<tag k="abandoned" v="yes"\s*/>},
	'Station outside block directive does not get abandoned=yes';
}
