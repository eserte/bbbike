# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2009 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

# Hmmm... XXXX

package BBBikeCGIAPI;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use JSON::XS qw();

require Karte::Polar;
require Karte::Standard;

sub action {
    my($action, $q) = @_;
    if ($action !~ m{^(revgeocode)$}) {
	die "Invalid action $action";
    }
    my $func = "action_$action";
    no strict 'refs';
    &{$func}($q);
}

sub action_revgeocode {
    my $q = shift;
    my($lon) = $q->param('lon');
    $lon eq '' and die "lon is missing";
    my($lat) = $q->param('lat');
    $lat eq '' and die "lat is missing";

    no warnings 'once';
    my($x,$y) = $Karte::Polar::obj->map2standard($lon,$lat);
    # XXX Die Verwendung von main::... bricht, wenn bbbike.cgi als
    # Apache::Registry-Skript ausgeführt wird, da das Package dann ein
    # anderes ist! -> beste Lösung: alle Funktionen von bbbike.cgi
    # müssen in ein Package überführt werden
    my $xy = main::get_nearest_crossing_coords($x,$y);
    my @cr = split m{/}, main::crossing_text($xy);
    @cr = @cr[0,1] if @cr > 2; # bbbike.cgi can deal only with A/B
    my $cr = join("/", @cr);
    print $q->header('text/plain');
    print JSON::XS->new->ascii->encode({ crossing => $cr,
					 bbbikepos => $xy,
				       });
}

1;

__END__
