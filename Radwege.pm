# -*- perl -*-

#
# $Id: Radwege.pm,v 1.14 2003/06/02 23:21:41 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1998 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: eserte@cs.tu-berlin.de
# WWW:  http://user.cs.tu-berlin.de/~eserte/
#

package Radwege;

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

use strict;
use vars qw(%category_code %category_name %category_plural
	    %bez @category_order @bbbike_category_order);

my @category =
  ("radweg"    => ["RW1", M"Radweg", M"Radwege"],
   "pflicht"   => ["RW2", M"benutzungspflichtig", M"benutzungspflichtige Radwege"],
   "suggestiv" => ["RW3", M"Suggestivstreifen"], # auch "Angebotsstreifen" genannt
   "spur"      => ["RW4", M"Radstreifen"],
   "bus"       => ["RW5", M"Busspur", M"Busspuren"],
   "ruhig"     => ["RW6", M"verkehrsberuhigt"],
   "radstr"    => ["RW7", M"Fahrradstraße", M"Fahrradstraßen"],
   "zweigegenpflicht" => ["RW8", M"Zweirichtungsradweg (Gegenrichtung, benutzungspflichtig)", M"Zweirichtungsradwege (Gegenrichtung, benutzungspflichtig)"],
   "zweigegen" => ["RW9", M"Zweirichtungsradweg (Gegenrichtung)", M"Zweirichtungsradwege (Gegenrichtung)"],
   "kein"      => ["RW0", M"kein Radweg", M"keine Radwege"],
  );

undef %category_code;         # "radweg" => "RW0"
undef %category_name;         # "radweg" => "Radweg"
undef %category_plural;       # "radweg" => "Radwege"
undef @category_order;        # ("radweg", "pflicht" ...)
undef @bbbike_category_order; # ("RW0", "RW1", ...)

for(my $i=0; $i<$#category; $i+=2) {
    my $rw_cat     = $category[$i];
    my $bbbike_cat = $category[$i+1]->[0];
    my $bez        = $category[$i+1]->[1];
    my $plural     = $category[$i+1]->[2] || $bez;
    $category_name{$rw_cat} = $bez
	if defined $bez;
    if (defined $plural) {
	$category_plural{$rw_cat} = $plural;
    }
    push @category_order, $rw_cat;
    $bez{$bbbike_cat} = $bez;
    $category_code{$rw_cat} = $bbbike_cat;
    push @bbbike_category_order, $bbbike_cat;
}

1;
