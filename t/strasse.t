#!/usr/bin/perl -w
# -*- perl -*-

#
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
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

my @split_street_citypart =
    (["Heerstr. (Spandau, Charlottenburg)" =>
      ["Heerstr.", "Spandau", "Charlottenburg"]],
     ["Heerstr. (Spandau)" =>
      ["Heerstr.", "Spandau"]],
     ["Heerstr." =>
      ["Heerstr."]],
     ["Potsdam, Schopenhauerstr." =>
      ["Schopenhauerstr.", "Potsdam"]],
     ["Gustav-müller-str, 16" =>
      ["Gustav-müller-str, 16"]],
     ["(Fenchelweg (KGA Foobar))" =>
      ["(Fenchelweg (KGA Foobar))"]],
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
     ["(Fenchelweg (KGA Foobar))" => "(Fenchelweg (KGA Foobar))"],
     ["F2.2: Geltow - Wildpark West" =>
      "F2.2: (Geltow -) Wildpark West", "F2.2: (Wildpark West -) Geltow"],
     ["F2.2: Werderscher Damm (Wildpark West - Kuhfort)" => 
      "F2.2: Werderscher Damm ((Wildpark West -) Kuhfort)",
      "F2.2: Werderscher Damm ((Kuhfort -) Wildpark West)"],
     ["B179: Berlin - Märkisch-Buchholz" =>
      "B179: (Berlin -) Märkisch-Buchholz", "B179: (Märkisch-Buchholz -) Berlin"],
     ["Müncheberg - Prötzel (B168)" =>
      "(Müncheberg -) Prötzel (B168)", "(Prötzel -) Müncheberg (B168)"],
     ["Ferch - Geltow (F1)" =>
      "(Ferch -) Geltow (F1)", "(Geltow -) Ferch (F1)"],
     ["Geltow - Fähre (Caputher Chaussee) (F1)" =>
      "(Geltow -) Fähre (Caputher Chaussee) (F1)", "(Fähre -) Geltow (Caputher Chaussee) (F1)"],
     ["Werderscher Damm (Wildpark West - Kuhfort)" =>
      "Werderscher Damm ((Wildpark West -) Kuhfort)", "Werderscher Damm ((Kuhfort -) Wildpark West)"],
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
      "((Möllendorffstr. -) Karl-Lade-Str.)",
      "((Karl-Lade-Str. -) Möllendorffstr.)"],
     ["Tiergarten (Hardenbergplatz - S-Bhf. Tiergarten)" =>
      "Tiergarten ((Hardenbergplatz -) S-Bhf. Tiergarten)",
      "Tiergarten ((S-Bhf. Tiergarten -) Hardenbergplatz)",
     ],
     ["(Möllendorffstr. - Karl-Lade-Str., Extra-Kommentar)" =>
      "((Möllendorffstr. -) Karl-Lade-Str., Extra-Kommentar)",
      "((Karl-Lade-Str. -) Möllendorffstr., Extra-Kommentar)"],
     ["Möllendorffstr. - Karl-Lade-Str., Extra-Kommentar" =>
      "(Möllendorffstr. -) Karl-Lade-Str., Extra-Kommentar",
      "(Karl-Lade-Str. -) Möllendorffstr., Extra-Kommentar"],

     # eckige Klammern
     ["Hausvogteiplatz [Taubenstr. - Niederwallstr.]" =>
      "Hausvogteiplatz [(Taubenstr. -) Niederwallstr.]",
      "Hausvogteiplatz [(Niederwallstr. -) Taubenstr.]"],
     ["Hausvogteiplatz [Taubenstr.]" =>
      "Hausvogteiplatz [Taubenstr.]",
      "Hausvogteiplatz [Taubenstr.]"],
    );

if ($] >= 5.008) {
    eval q{
push @beautify_landstrasse,
     ["B104 - Milow - Schönwerder - B198" =>
      "(B104 \x{2192} Milow \x{2192} Schönwerder \x{2192}) B198",
      "(B198 \x{2192} Schönwerder \x{2192} Milow \x{2192}) B104", undef, "can_unicode"],
;
};
    die $@ if $@;
}

my @street_type_nr =
    (["B1: Potsdam - Brandenburg",	"B", "1"],
     ["B96a: Birkenwerder - Berlin",	"B", "96a"],
     ["B107 (Pritzwalk - Genthin)",	"B", "107"],
     ["Müncheberg - Prötzel (B168)",	"B", "168"],
     ["BAB100",				"BAB", "100"],
     ["BAB100 (Britzer Tunnel)",	"BAB", "100"],
     ["B101n",				"B", "101n"],
     #["Ortsumfahrung Müncheberg (B1/B5)" -> ?
     ["B96neu",				"B", "96neu"],
     ["F1 (Potsdam)",			"F", "1"],
     ["F2.2 (Potsdam)",			"F", "2.2"],
     ["Straße 645",			undef, undef],
     ["Straße des 17. Juni",		undef, undef],
     ["(Kolonie Bornholm 1 und 2)",	undef, undef],
     ["Straße 229 (Mariendorf)",	undef, undef],
    );

my @crossing_tests =
    (
     ["Nocrossing" => "Nocrossing"],
     ['Schönhauser/Bornholmer' => "Schönhauser", "Bornholmer"],
     ['Schönhauser  /  Bornholmer' => "Schönhauser", "Bornholmer"],
     ['Schönhauser\Bornholmer' => "Schönhauser", "Bornholmer"],
     [undef, ()],
    );

my @parse_street_type_nr_tests =
    (
     ["Berliner Mauer-Radweg", "M", undef, 1],
    );

my @de_artikel_tests =
    (
     ['Dudenstr.', 'in die'],
     ['Mehringdamm', 'in den'],
     ['Rue Diderot', 'in die'],
     ['Via Tilia', 'in die'],
    );

my @de_artikel_dativ_tests =
    (
     ['Dudenstr.', 'auf der'],
     ['Mehringdamm', 'auf dem'],
     ['Rue Diderot', 'auf der'],
     ['Via Tilia', 'auf der'],
    );

my $strip_bezirk_tests = 7;
plan tests => (scalar(@split_street_citypart) +
	       scalar(@beautify_landstrasse)*2 +
	       scalar(@street_type_nr)*2 +
	       $strip_bezirk_tests +
	       scalar(@crossing_tests) +
	       3*scalar(@parse_street_type_nr_tests) +
	       scalar(@de_artikel_tests) +
	       scalar(@de_artikel_dativ_tests)
	      );

for my $s (@split_street_citypart) {
    my($str, @expected) = ($s->[0], @{ $s->[1] });
    my(@res) = Strasse::split_street_citypart($str);
    is(join("#", @res), join("#", @expected), "Split $str -> $expected[0] ...");
}

for my $s (@beautify_landstrasse) {
    my($str, $expected_forward, $expected_backward, $todo, $can_unicode) = @$s;
    if (!defined $expected_backward) {
	$expected_backward = $expected_forward;
    }
    local $TODO = $todo;
    is(Strasse::beautify_landstrasse($str, 0, -unicode => $can_unicode),
       $expected_forward, "$str forward" . ($can_unicode ? " with unicode" : ""));
    is(Strasse::beautify_landstrasse($str, 1, -unicode => $can_unicode),
       $expected_backward, "$str backward" . ($can_unicode ? " with unicode" : ""));
}

my $city = "Berlin_DE";
is(Strasse::strip_bezirk("Dudenstr. (Kreuzberg, Tempelhof)"),
   "Dudenstr.",
   "strip_bezirk simple");
is(Strasse::strip_bezirk_perfect("Dudenstr. (Kreuzberg, Tempelhof)", $city),
   "Dudenstr.",
   "strip_bezirk_perfect simple");
is(Strasse::strip_bezirk("Dudenstr. (foobar) (Kreuzberg, Tempelhof)"),
   "Dudenstr. (foobar)",
   "only last component is stripped");
is(Strasse::strip_bezirk_perfect("Dudenstr. (foobar) (Kreuzberg, Tempelhof)", $city),
   "Dudenstr. (foobar)",
   "only bezirke are stripped");
is(Strasse::strip_bezirk("Dudenstr. (foobar)"), "Dudenstr.",
   "non-bezirk incorrectly stripped");
is(Strasse::strip_bezirk_perfect("Dudenstr. (foobar)", $city),
   "Dudenstr. (foobar)",
   "non-bezirk not stripped");
is(Strasse::strip_bezirk("Zanderweg (Oranienburg-Schmachtenhagen (OT Bernöwe))"), "Zanderweg",
   "hack for parens in parens");

for my $s (@street_type_nr) {
    my($str, $type, $nr) = @$s;
    my($got_type, $got_nr) = Strasse::parse_street_type_nr($str);
    is($got_type, $type, "Type for $str");
    is($got_nr, $nr, "Number for $str");
}

{
    require Geography::Berlin_DE;
    my $city_obj = Geography::Berlin_DE->new;
    for my $def (@parse_street_type_nr_tests) {
	my($strname, $exp_type, $exp_nr, $exp_do_round) = @$def;
	my($type,$nr,$do_round);
	($type,$nr) = Strasse::parse_street_type_nr($strname);
	# Extra routes in and outer Berlin:
	if (!defined $type && $city_obj && $city_obj->can("parse_street_type_nr")) {
	    ($type, $nr, $do_round) = $city_obj->parse_street_type_nr($strname);
	}
	is($type, $exp_type, "Type of street");
	is($nr, $exp_nr, "Number of street");
	is($do_round, $exp_do_round, "Make round sign");
    }
}

for my $def (@crossing_tests) {
    my($text, @exp_crossings) = @$def;
    my $display_text = $text || "(undef)";
    my @crossings = Strasse::split_crossing($text);
    is_deeply(\@crossings, \@exp_crossings, "Crossing split on $display_text");
}

for my $def (@de_artikel_tests) {
    my($street, $artikel) = @$def;
    is Strasse::de_artikel($street), $artikel, "de_artikel for $street";
}

for my $def (@de_artikel_dativ_tests) {
    my($street, $artikel) = @$def;
    is Strasse::de_artikel_dativ($street), $artikel, "de_artikel for $street";
}

__END__
