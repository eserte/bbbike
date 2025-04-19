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
    "Somewhere in Stra�e des 17. Juni is something",
    "Somewhere in Stra�e des 17. Juni",
    "Somewhere in Stra�e 42 is something",
    "Somewhere in Stra�e 42",
    "Einbahnstra�enregelung",
) {
    is BBBikeEdit::temp_blockings_editor_fmt_text($text), $text, "unchanged text '$text'";
}

for my $repl_def (
    ["Something in Dudenstra�e is something", "Something in Dudenstr. is something"],
    ["Methfesselstra�e gesperrt, Umleitung, hohe Staugefahr, mehr Text", "Methfesselstr. gesperrt, mehr Text"],
    ["Die Kreuzbergstra�e ist gesperrt, Umleitung ist ausgeschildert, mehr Text", "Die Kreuzbergstr. ist gesperrt, mehr Text"],
    ["Trailing space  ", "Trailing space"],
    ["L73, Luckenwalde, J�nickendorfer Stra�e Tiefbauarbeiten  Im angegebenen Zeitraum kommt es zu Einschr�nkungen des Verkehrsraumes mit wechselseitiger Verkehrsf�hrung in beiden Fahrtrichtungen.  Bitte beachten Sie die �rtliche Beschilderung und Verkehrsf�hrung. 07.04.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr",
     "L73, Luckenwalde, J�nickendorfer Str. Tiefbauarbeiten  Gegenverkehrsregelung. 07.04.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr"],
    ["Zossen: B96, Zossen, Cottbuser Stra�e Tiefbauarbeiten  Im angegebenen Zeitraum kommt es zu Einschr�nkungen des Verkehrsraumes mit wechselseitiger Verkehrsf�hrung in beiden Fahrtrichtungen.  Der Verkehr wird mithilfe einer Ampel geregelt.  Bitte beachten Sie die �rtliche Beschilderung und Verkehrsf�hrung. 12.03.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr",
     "Zossen: B96, Zossen, Cottbuser Str. Tiefbauarbeiten  Gegenverkehrsregelung mit Ampel. 12.03.2025 08:00 Uhr bis 18.04.2025 17:00 Uhr"],
) {
    my($in, $exp) = @$repl_def;
    is BBBikeEdit::temp_blockings_editor_fmt_text($in), $exp, "changed text '$in'";
}

__END__
