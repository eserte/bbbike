#!/usr/bin/perl

# Krass ungenau, diese Koordinaten!

use strict;

use HTML::LinkExtor;
use LWP::Simple;
use CGI;

use FindBin;
use lib "$FindBin::RealBin/..";
use Karte;
Karte::preload(":all");

my $url = "http://www.indexmundi.com/zl/gm/"; # german lakes

my $index_page = get($url);
my $p = HTML::LinkExtor->new(undef, $url);
$p->parse($index_page);
my @links;
for my $def ($p->links) {
    for my $link (@$def) {
	if (UNIVERSAL::isa($link, "URI")) {
	    my $link_s = $link->as_string;
	    push @links, $link_s if $link_s =~ qr{^\Q$url\E\d};
	}
    }
}

my @geoobjs;
for my $l (@links) {
    my $page = get($l);
    my $p = HTML::LinkExtor->new(undef, $l);
    $p->parse($page);
    for my $def ($p->links) {
	for my $link (@$def) {
	    if (UNIVERSAL::isa($link, "URI")) {
		my $link_s = $link->as_string;
		my $deg = qr{[-+\d\.]+};
		if ($link_s =~ /\?(lat=.*)/) {
		    my $q = CGI->new($1);
		    push @geoobjs, { lat => $q->param("lat"),
				     lon => $q->param("lon"),
				     p   => $q->param("p"),
				   };
		}
	    }
	}
    }
}

for my $geoobj (@geoobjs) {
    my($x,$y) = map { int } $Karte::Polar::obj->map2standard($geoobj->{lon},
							     $geoobj->{lat});
    print "$geoobj->{p}\tX $x,$y\n";
}
