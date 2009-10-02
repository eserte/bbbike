# -*- perl -*-

#
# $Id: Radwege.pm,v 1.21 2008/07/05 10:34:03 eserte Exp $
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

$VERSION = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);

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
use vars qw(%category_code %code_category %category_name %category_plural
	    %bez @category_order @bbbike_category_order $rw_qr);

my @category =
  ("radweg"    => ["RW1", M"Radweg", M"Radwege"],
   "pflicht"   => ["RW2", M"benutzungspflichtiger Radweg", M"benutzungspflichtige Radwege"],
   "suggestiv" => ["RW3", M"Schutzstreifen"], # auch "Angebotsstreifen" oder "Suggestivstreifen" genannt
   "spur"      => ["RW4", M"Radstreifen"],
   "bus"       => ["RW5", M"Busspur", M"Busspuren"],
   "ruhig"     => ["RW6", M"verkehrsberuhigt"],
   "radstr"    => ["RW7", M"Fahrradstraße", M"Fahrradstraßen"],
   "zweigegenpflicht" => ["RW8", M"Zweirichtungsradweg (Gegenrichtung, benutzungspflichtig)", M"Zweirichtungsradwege (Gegenrichtung, benutzungspflichtig)"],
   "zweigegen" => ["RW9", M"Zweirichtungsradweg (Gegenrichtung)", M"Zweirichtungsradwege (Gegenrichtung)"],
   "neben"     => ["RW10", M"Nebenstraße vorhanden", M"Nebenstraßen vorhanden"], # Nebenfahrbahn
   "kein"      => ["RW0", M"kein Radweg", M"keine Radwege"],
   "nichtkat"  => ["RW", M"Radweg (ohne Kategorisierung)", M"Radwege (ohne Kategorisierung)"],
   "unknown"   => ["RW?", M"Radweg (unbekannte Kategorie)", M"Radwege (unbekannte Kategorie)"],
   # Der Unterschied zwischen RW und RW?: bei RW? sollte ein User
   # explizit nach der Kategorisierung gefragt werden, bei RW kann der
   # User gefragt werden. Könnte eigentlich auch mit einer
   # add_fragezeichen-Direktive gemacht werden
  );

$rw_qr = qr{^RW(?:\d*|\?)$};

%category_code = ();		# "radweg" => "RW0"
%code_category = ();		# "RW0" => "radweg"
%category_name = ();		# "radweg" => "Radweg"
%category_plural = ();		# "radweg" => "Radwege"
@category_order = ();		# ("radweg", "pflicht" ...)
@bbbike_category_order = ();	# ("RW0", "RW1", ...)

init();

sub init {
    for (my $i=0; $i<$#category; $i+=2) {
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
	$code_category{$bbbike_cat} = $rw_cat;
	push @bbbike_category_order, $bbbike_cat;
    }
}

sub code2name { $category_name{$code_category{$_[0]}} }

1;
