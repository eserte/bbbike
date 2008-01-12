# -*- perl -*-

#
# $Id: Zuerich_CH.pm,v 1.5 2008/01/12 21:34:49 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Geography::Zuerich_CH;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub new { bless {}, shift }

sub cityname { "Zürich" }

sub center { "0,0" } # Grossmünster
#sub center { "-308200,-565917" } # N 47°22'13.8" E 8°32'39.7", Grossmünster
#sub scrollregion { (-358200,-605917,-258200,-505917) }

sub datadir {
    require File::Basename;
    require File::Spec;
    my $root = File::Basename::dirname(File::Basename::dirname(File::Spec->rel2abs(__FILE__)));
    if (-d "$root/data_zuerich_ch") {
	"$root/data_zuerich_ch"
    } else {
	warn "NOTE: assuming native Zuerich/CH build...\n";
	"$root/data";
    }
}

sub skip_features {
    qw(landstrassen orte u-bahn s-bahn hoehe nolighting green vorfahrt radroute vbb wasserumland);
}

{
    require Karte::Polar;
    require Karte::Standard;

    my($c_lon,$c_lat) = (8.54488,47.37006);
    my($dx,$dy) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($c_lon,$c_lat));

    sub standard_to_polar {
	my($self, $sx, $sy) = @_;
	$sx+=$dx;
	$sy+=$dy;
	$Karte::Polar::obj->trim_accuracy($Karte::Polar::obj->standard2map($sx,$sy));
    }
}

1;

__END__

=pod

To download osm map, use:

    cd ~/src/bbbike/misc/download/osm/zuerich_ch
    ~/src/bbbike/miscsrc/downloadosm 8.271 47.176 8.86 47.546

To convert osm maps to bbd data for bbbike, use:

    ~/src/bbbike/miscsrc/osm2bbd -v -f -encoding iso-8859-1 -map bbbike -center 8.54488,47.37006 -o ~/src/bbbike/data_zuerich_ch ~/src/bbbike/misc/download/osm/zuerich_ch/*.osm

After converting, some additional steps are necessary:

    cd ~/src/bbbike/data_zuerich_ch
    ../miscsrc/convert_radwege -noconv < radwege_exact | ../miscsrc/combine_streets.pl - > radwege

Patch the bbbike script. Replace

		 "$FindBin::RealBin/images/bbbike_splash.xpm",

with
		 "$FindBin::RealBin/misc/zuerich_splash.xpm",

=cut
