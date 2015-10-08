# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2015 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::QualityDE;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

sub is_paved {
    my($name) = @_;
    # XXX This regexp should be named or a function
    if ($name =~ m{^(?:.*)?:\s*(.*)}) {	$name = $1 }
    # First check for the worse
    if ($name =~ m{(?:
		       \bunbefestigt(?:e|er)?\b
		   |   \bwassergebundene(?:r)?\s+Decke\b
		   |   \bParkweg\b
		   |   \bWaldweg\b
		   |   \bFeldweg\b
		   |   \bKiesweg\b
		   |   \bFahrweg\b
		   |   \bAscheweg\b
		   |   \bSchotter(weg|straße)\b
		   |   \bFeinschotter(weg|straße)\b
		   |   \bSand(weg|straße)\b
		   |   \bGras\b
		   |   \bFeinschotter\b
		   |   \bSchotter\b
		   |   \bPfad\b
		   |   \bTrampelpfad\b
		   |   \bWaldpfad\b
		   |   \bSandbelag\b
		   |   \bSand\b
		   |   \bSandpiste\b
		   |   \bZuckersand\b
		   |   \bsandig(?:e|er)?\b
		   |   \bKies\b
		   |   \bErde\b
		   |   \bErdboden\b
		   |   \bRasengittersteine\b
		   |   \bKunststoffrasengitter\b
	           )}x) {
	0;
    } elsif ($name =~ m{(?:
			    \bAsphalt\b
			|   \bAsphaltdecke\b
			|   \bAsphaltstreifen\b
			|   \basphaltiert(?:e|er)?\b
			|   \basphaltähnlich(?:e|er)?\b
			|   \bgeteert\b
			|   \bAsphaltbeton\b
			|   \bBeton\b
			|   \bBetonstraße\b
			|   \bBetonweg\b
			|   \bbetoniert(?:e|er)?\b
			|   \bBetonplatten\b
			|   \bPlatten\b
			|   \bPlattenweg\b
			|   \bBetonplattenweg\b
			|   \bGehwegplatten\b
			|   \bGehwegpflasterung\b
			|   \bBetonpflaster\b
			|   \bBetonsteinpflaster\b
			|   \bVerbundsteinpflaster\b
			|   \bVerbundsteinpflasterradweg\b
			|   \bVerbundsteine\b
			|   \bBasaltpflaster\b
			|   \bGranitpflaster\b
			|   \bNatursteinpflaster\b
			|   \bKopfsteinpflaster\b
			|   \bFeldstein-Belag\b
			|   \bKleinsteinpflaster\b
			|   \bKleinkopfsteinpflaster\b
			|   \bKleinpflastersteine\b
			|   \bKleinpflaster\b
			|   \bMosaikpflaster\b
			|   \bgepflastert\b
			|   \bPflaster\b
			|   \bPflasterung\b
			|   \bHolzbohlen\b
			|   \bHolzbohlenweg\b
			|   \bHolzbohlenbrücke\b
			|   \bHolzbohlensteg\b
			|   \bHolzbrücke\b
			|   \bGitterbrücke\b
			|   \bMetallrampe\b
			)}x) {
	1;
    } else {
	undef;
    }
}

1;

__END__

=head1 NAME

Strassen::QualityDE - utility for handling with data in qualitaet* files

=head1 DESCRIPTION

=head2 C<is_paved(I<name>)>

Guess by name if the way is paved.

Return 1 if it is paved, 0 if it is unpaved, C<undef> if unknown.

=head1 EXAMPLE

Call C<is_paved> on the data in F<qualitaet_s>:

    perl -Ilib -MStrassen::QualityDE -MStrassen::Core -e 'Strassen->new_stream("data/qualitaet_s")->read_stream(sub{my($r)=@_;(my $q = $r->[Strassen::NAME]) =~ s{^[^:]+:\s+}{}; print Strassen::QualityDE::is_paved($q)," ",$q,"\n" })'

=cut
