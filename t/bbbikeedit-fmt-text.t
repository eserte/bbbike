#!/usr/bin/perl -w
# -*- cperl -*-

#
# Author: Slaven Rezic
#

use strict;
use warnings;
use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../lib");

use Test::More 'no_plan';

use BBBikeEdit;

for my $text (
    "Normal text",
    "Somewhere in Straße des 17. Juni is something",
    "Somewhere in Straße des 17. Juni",
    "Somewhere in Straße 42 is something",
    "Somewhere in Straße 42",
    "Einbahnstraßenregelung",
) {
    is BBBikeEdit::temp_blockings_editor_fmt_text($text), $text, "unchanged text '$text'";
}

for my $repl_def (
    ["Something in Dudenstraße is something", "Something in Dudenstr. is something"],
    ["Methfesselstraße gesperrt, Umleitung, hohe Staugefahr, mehr Text", "Methfesselstr. gesperrt, mehr Text"],
    ["Die Kreuzbergstraße ist gesperrt, Umleitung ist ausgeschildert, mehr Text", "Die Kreuzbergstr. ist gesperrt, mehr Text"],
    ["Trailing space  ", "Trailing space"],
    ["L73, Luckenwalde, Jänickendorfer Straße Tiefbauarbeiten  Im angegebenen Zeitraum kommt es zu Einschränkungen des Verkehrsraumes mit wechselseitiger Verkehrsführung in beiden Fahrtrichtungen.  Bitte beachten Sie die örtliche Beschilderung und Verkehrsführung. 07.04.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr",
     "L73, Luckenwalde, Jänickendorfer Str. Tiefbauarbeiten  Gegenverkehrsregelung. 07.04.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr"],
    ["Zossen: B96, Zossen, Cottbuser Straße Tiefbauarbeiten  Im angegebenen Zeitraum kommt es zu Einschränkungen des Verkehrsraumes mit wechselseitiger Verkehrsführung in beiden Fahrtrichtungen.  Der Verkehr wird mithilfe einer Ampel geregelt.  Bitte beachten Sie die örtliche Beschilderung und Verkehrsführung. 12.03.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr",
     "Zossen: B96, Zossen, Cottbuser Str. Tiefbauarbeiten  Gegenverkehrsregelung mit Ampel. 12.03.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr"],
) {
    my($in, $exp) = @$repl_def;
    is BBBikeEdit::temp_blockings_editor_fmt_text($in), $exp, "changed text '$in'";
}

__END__
