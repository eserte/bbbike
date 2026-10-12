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

BEGIN {
    if (!eval { require Tie::IxHash; 1 }) {
        print "1..0 # SKIP Tie::IxHash is required for bbd2osm\n";
        exit 0;
    }
}

use File::Temp qw(tempfile);
use Test::More 'no_plan';
use BBBikeTest qw(xpath_checks);

my $bbd2osm = "$FindBin::RealBin/../miscsrc/bbd2osm";

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

    xpath_checks $out, 4, sub {
	my $doc = shift;
	is $doc->findvalue('//node[tag[@k="name"]/@v="Station Abandoned"]/tag[@k="abandoned"]/@v'), 'yes',
	    'Station with R0 and osm.abandoned: yes directive gets abandoned=yes';
	is $doc->findnodes('//node[tag[@k="name"]/@v="Station Abandoned"]/tag[@k="disused"]')->size, 0,
	    'Station with R0 and osm.abandoned: yes directive does not get disused=yes';

	is $doc->findvalue('//node[tag[@k="name"]/@v="Station Disused"]/tag[@k="disused"]/@v'), 'yes',
	    'Station with R0 without osm.abandoned directive gets disused=yes';
	is $doc->findnodes('//node[tag[@k="name"]/@v="Station Disused"]/tag[@k="abandoned"]')->size, 0,
	    'Station with R0 without osm.abandoned directive does not get abandoned=yes';
    };
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

    xpath_checks $out, 4, sub {
	my $doc = shift;
	is $doc->findvalue('//node[tag[@k="name"]/@v="Station Abandoned Block"]/tag[@k="abandoned"]/@v'), 'yes',
	    'Block directive osm.abandoned: yes gives abandoned=yes';
	is $doc->findnodes('//node[tag[@k="name"]/@v="Station Abandoned Block"]/tag[@k="disused"]')->size, 0,
	    'Block directive osm.abandoned: yes does not give disused=yes';

	is $doc->findvalue('//node[tag[@k="name"]/@v="Station Disused Block"]/tag[@k="disused"]/@v'), 'yes',
	    'Station outside block directive gets disused=yes';
	is $doc->findnodes('//node[tag[@k="name"]/@v="Station Disused Block"]/tag[@k="abandoned"]')->size, 0,
	    'Station outside block directive does not get abandoned=yes';
    };
}
