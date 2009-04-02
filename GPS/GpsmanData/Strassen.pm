# -*- perl -*-

#
# $Id: Strassen.pm,v 1.2 2009/04/02 20:29:16 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2008,2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::Strassen;

package GPS::GpsmanMultiData;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use Karte::Polar;
use Karte::Standard;
use Strassen::Core;

sub as_wpt_strassen {
    my($self) = @_;

    my $s = Strassen->new;

    for my $chunk (@{ $self->Chunks }) {
	for my $wpt (@{ $chunk->Track }) {
	    my $epoch = $wpt->Comment_to_unixtime($chunk);
	    my @t = gmtime($epoch); $t[4]++; $t[5]+=1900;
	    my $isodate = sprintf "%04d%02d%02dT%02d%02d%02d", @t[5,4,3,2,1,0];
	    my($x,$y) = $Karte::Standard::obj->trim_accuracy($Karte::Polar::obj->map2standard($wpt->Longitude, $wpt->Latitude));
	    # XXX rough estimate...
	    my $acc = ($wpt->Accuracy == 0 ? 10 :
		       $wpt->Accuracy == 1 ? 25 : 50);
	    $s->push(["$isodate acc=${acc}m", ["$x,$y"], "X"]);
	}
    }

    $s;
}

1;
