#!/usr/bin/perl -w
# -*- perl -*-

#
# $Id: strasse.t,v 1.4 2005/03/01 23:45:11 eserte Exp $
# Author: Slaven Rezic
#

use strict;

use FindBin;
use lib ("$FindBin::RealBin/..", "$FindBin::RealBin/../data", "$FindBin::RealBin/../lib");
use Strassen::Strasse;

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip: no Test::More module\n";
	exit;
    }
}

my @split_street_citypart =
    (["Heerstr. (Spandau, Charlottenburg)" =>
      ["Heerstr.", "Spandau", "Charlottenburg"]],
     ["Heerstr. (Spandau)" =>
      ["Heerstr.", "Spandau"]],
     ["Heerstr." => ["Heerstr."]],
    );

my @beautify_landstrasse =
    (["Dudenstr." => "Dudenstr."],
     ["Heerstr. (Spandau)" => "Heerstr. (Spandau)"],
     ["Karl-Kunger-Str." => "Karl-Kunger-Str."],
     ["Karl-Kunger-Str. (Treptow)" => "Karl-Kunger-Str. (Treptow)"],
     ["B1: Berlin - Potsdam" =>
      "B1: (Berlin -) Potsdam", "B1: (Potsdam -) Berlin"],
     ["Am Neuen Palais (F2.2)" =>
      "Am Neuen Palais (F2.2)"],
     ["F2.2: Geltow - Wildpark West" =>
      "F2.2: (Geltow -) Wildpark West", "F2.2: (Wildpark West -) Geltow"],
     ["F2.2: Werderscher Damm (Wildpark West - Kuhfort)" => 
      "F2.2: Werderscher Damm ((Wildpark West -) Kuhfort)",
      "F2.2: Werderscher Damm ((Kuhfort -) Wildpark West)", "XXX"],
     ["B179: Berlin - Märkisch-Buchholz" =>
      "B179: (Berlin -) Märkisch-Buchholz", "B179: (Märkisch-Buchholz -) Berlin"],
     ["Müncheberg - Prötzel (B168)" =>
      "(Müncheberg -) Prötzel (B168)", "(Prötzel -) Müncheberg (B168)"],
     ["Ferch - Geltow (F1)" =>
      "(Ferch -) Geltow (F1)", "(Geltow -) Ferch (F1)"],
     ["Geltow - Fähre (Caputher Chaussee) (F1)" =>
      "(Geltow -) Fähre (Caputher Chaussee) (F1)", "(Fähre -) Geltow (Caputher Chaussee) (F1)"],
     ["Werderscher Damm (Wildpark West - Kuhfort)" =>
      "Werderscher Damm ((Wildpark West -) Kuhfort)", "Werderscher Damm ((Kuhfort -) Wildpark West)", "XXX"],
     ["Sybelstr. Ost - Lewishamstr.: Verbindung?" =>
      "(Sybelstr. Ost -) Lewishamstr.: Verbindung?", "(Lewishamstr. -) Sybelstr. Ost: Verbindung?"],
     ["Berlin - Altlandsberg - Strausberg" =>
      "(Berlin - Altlandsberg -) Strausberg", "(Strausberg - Altlandsberg -) Berlin"],
     ["B112: Manschnow - Lebus - Frankfurt" =>
      "B112: (Manschnow - Lebus -) Frankfurt", "B112: (Frankfurt - Lebus -) Manschnow"],
     ["B104 - Milow - Schönwerder - B198" =>
      "(B104 - Milow - Schönwerder -) B198", "(B198 - Schönwerder - Milow -) B104"],
     ["Alt-Golm - Saarow" =>
      "(Alt-Golm -) Saarow", "(Saarow -) Alt-Golm"],
     ["(Möllendorffstr. - Karl-Lade-Str.)" =>
      "((Möllendorffstr. -) Karl-Lade-Str.)", "(Karl-Lade-Str. -) Möllendorffstr.)", "XXX"],
    );

plan tests => scalar(@split_street_citypart) + scalar(@beautify_landstrasse)*2;

for my $s (@split_street_citypart) {
    my($str, @expected) = ($s->[0], @{ $s->[1] });
    my(@res) = Strasse::split_street_citypart($str);
    is(join("#", @res), join("#", @expected), "Split $str");
}

for my $s (@beautify_landstrasse) {
    my($str, $expected_forward, $expected_backward, $todo) = @$s;
    if (!defined $expected_backward) {
	$expected_backward = $expected_forward;
    }
    local $TODO = $todo;
    is(Strasse::beautify_landstrasse($str), $expected_forward, "$str forward");
    is(Strasse::beautify_landstrasse($str, 1), $expected_backward, "$str backward");
}

__END__
