#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Find possible candidates for cul-de-sac/dead end/exit=no streets.

use strict;
use FindBin;
use lib ("$FindBin::RealBin/..",
	 "$FindBin::RealBin/../lib",
	);

use Getopt::Long;

use Strassen::Core;
use Strassen::Kreuzungen;
use Strassen::MultiStrassen;
use Strassen::StrassenNetz;

my $only_berlin;
GetOptions("only-berlin" => \$only_berlin)
    or die "usage: $0 [-only-berlin]";

# need to find border ends
my $cr_landstrassen;
if ($only_berlin) {
    my $l = Strassen->new("landstrassen");
    $cr_landstrassen = Kreuzungen->new(UseCache => 1, AllPoints => 1, Strassen => $l);
}

my $cm_s = Strassen->new("comments_misc-orig"); # culdesac records currently only in the -orig variant
my $culdesac_s = $cm_s->grepstreets(sub { my $r = $_;
					  $_->[Strassen::CAT] eq 'culdesac';
				      });
my $culdesac = $culdesac_s->get_hashref;

my $s = MultiStrassen->new("strassen",
			   ($only_berlin ? () : ("landstrassen", "landstrassen2")),
			   "fragezeichen",
			  );
my $net = StrassenNetz->new($s);
$net->make_net_cat(UseCache => 1);
my $cr = Kreuzungen->new(UseCache => 1, AllPoints => 1, Strassen => $s);
while(my($k1,$v1) = each %{ $net->{Net} }) {
    if (keys %$v1 == 1) {
	next if exists $culdesac->{$k1};
	my($cat) = values %$v1;
	if ($cat ne '?' && (!$cr_landstrassen || !$cr_landstrassen->crossing_exists($k1))) {
	    print join("/", @{ $cr->get($k1) }), "\tX $k1\n";
	}
    }
}

__END__
