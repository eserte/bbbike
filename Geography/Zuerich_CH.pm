# -*- perl -*-

#
# $Id: Zuerich_CH.pm,v 1.8 2008/01/21 23:23:17 eserte Exp $
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
$VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use base qw(Geography::Base);

sub cityname { "Zürich" }

sub center { "0,0" } # Grossmünster
#sub center { "-308200,-565917" } # N 47°22'13.8" E 8°32'39.7", Grossmünster
#sub scrollregion { (-358200,-605917,-258200,-505917) }
sub center_name { "Zürich" }

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

    $Karte::Standard::obj = $Karte::Standard::obj if 0; # cease -w

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

Preparing a windows distribution:

    cd ~/src/bbbike/ports/windows
    make BBBIKEVER=3.16-DEVEL
    cd /tmp/BBBike-3.16-DEVEL-Windows/bbbike
    rsync -a ~/src/bbbike/data_zuerich_ch/ data_zuerich_ch/
    cp -f ~/src/bbbike/misc/zuerich_splash.xpm images/bbbike_splash.xpm
    cp -f ~/src/bbbike/Geography/Zuerich_CH.pm Geography
    chmod -R o+r data
    chmod 644 images/bbbike_splash.xpm
    chmod 644 Geography/Zuerich_CH.pm

Add a new file bbbike/bbbike_0.config with the content:

    $city = "zuerich";
    $init_str_draw{"w"} = 1;
    $init_str_draw{"f"} = 1;
    $init_str_draw{"r"} = 1;

(Only the first line is really mandatory)

=cut
